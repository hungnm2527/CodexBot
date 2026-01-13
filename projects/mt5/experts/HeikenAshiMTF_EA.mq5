//+------------------------------------------------------------------+
//| HeikenAshiMTF_EA.mq5                                            |
//| Heiken Ashi multi-timeframe EA for XAUUSD/XAGUSD                |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

enum ENUM_SL_MODE
  {
   SL_Swing = 0,
   SL_ATR   = 1
  };

enum ENUM_TRAIL_MODE
  {
   TRAIL_ATR   = 0,
   TRAIL_Swing = 1
  };

input string SymbolsList             = "XAUUSD,XAGUSD"; // Comma-separated symbols
input bool   IncludeChartSymbol      = true;            // Include chart symbol
input int    TrendBars               = 3;               // H4 HA candles for trend
input int    PullbackBars            = 8;               // H1 pullback lookback
input double RiskPercent             = 1.0;             // Risk % per trade
input int    MaxPositionsPerSymbol   = 1;               // Max positions per symbol
input int    MaxSpreadPoints         = 60;              // Max spread in points
input int    SessionStartHour        = 7;               // Trading session start (server hour)
input int    SessionEndHour          = 20;              // Trading session end (server hour)
input ENUM_SL_MODE StopLossMode      = SL_Swing;        // SL mode
input int    SwingLookback           = 10;              // Swing SL lookback bars (H1)
input int    BufferPoints            = 50;              // Swing SL buffer (points)
input int    AtrPeriod               = 14;              // ATR period (H1)
input double AtrMultiplier           = 1.5;             // ATR SL multiplier
input double RewardRiskRatio         = 1.8;             // TP = RR * SL distance
input double BreakevenAtR            = 1.0;             // Move SL to BE at this R
input bool   EnableTrailing          = false;           // Enable trailing
input ENUM_TRAIL_MODE TrailMode      = TRAIL_ATR;       // Trailing mode
input int    TrailSwingLookback      = 6;               // Trailing swing lookback
input double TrailAtrMultiplier      = 1.2;             // Trailing ATR multiplier
input int    SlippagePoints          = 20;              // Max slippage (points)
input ulong  MagicBase               = 771100;          // Magic base

struct SymbolState
  {
   string   name;
   datetime lastH1Processed;
  };

CTrade      trade;
SymbolState g_symbols[];
int         g_symbolTotal = 0;

bool SelectPositionByIndex(const int index);

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetDeviationInPoints(SlippagePoints);

   if(!BuildSymbolList())
      return(INIT_FAILED);

   PrintFormat("HeikenAshiMTF_EA initialized for %d symbols", g_symbolTotal);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   for(int i=0; i<g_symbolTotal; ++i)
     {
      ManagePositions(g_symbols[i].name);
      EvaluateSymbol(g_symbols[i]);
     }
  }

//+------------------------------------------------------------------+
//| Build symbol list                                                |
//+------------------------------------------------------------------+
bool BuildSymbolList()
  {
   ArrayFree(g_symbols);
   g_symbolTotal = 0;

   if(IncludeChartSymbol)
     {
      ArrayResize(g_symbols, g_symbolTotal+1);
      g_symbols[g_symbolTotal].name            = _Symbol;
      g_symbols[g_symbolTotal].lastH1Processed = 0;
      ++g_symbolTotal;
     }

   string cleaned = SymbolsList;
   StringReplace(cleaned, " ", "");
   string parts[];
   int count = StringSplit(cleaned, ',', parts);

   for(int i=0; i<count; ++i)
     {
      if(parts[i] == "")
         continue;

      if(IncludeChartSymbol && parts[i] == _Symbol)
         continue;

      ArrayResize(g_symbols, g_symbolTotal+1);
      g_symbols[g_symbolTotal].name            = parts[i];
      g_symbols[g_symbolTotal].lastH1Processed = 0;
      ++g_symbolTotal;
     }

   if(g_symbolTotal == 0)
     {
      Print("HeikenAshiMTF_EA: no valid symbols to process.");
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Evaluate trade conditions                                        |
//+------------------------------------------------------------------+
void EvaluateSymbol(SymbolState &state)
  {
   string symbol = state.name;

   if(!EnsureSymbol(symbol))
      return;

   int h1Needed = PullbackBars + 3;
   MqlRates h1Rates[];
   ArrayResize(h1Rates, h1Needed);
   if(CopyRates(symbol, PERIOD_H1, 0, h1Needed, h1Rates) < h1Needed)
      return;

   datetime lastClosedH1 = h1Rates[1].time;
   if(lastClosedH1 == state.lastH1Processed)
      return;

   state.lastH1Processed = lastClosedH1;

   string skipReason = "";

   if(!IsWithinSession())
      skipReason = "outside session";
   else if(GetSpreadPoints(symbol) > MaxSpreadPoints)
      skipReason = "spread too high";
   else if(CountSymbolPositions(symbol, SymbolMagic(symbol)) >= MaxPositionsPerSymbol)
      skipReason = "max positions reached";

   if(skipReason != "")
     {
      PrintFormat("%s skip: %s", symbol, skipReason);
      return;
     }

   int trend = GetTrendDirection(symbol);
   if(trend == 0)
     {
      PrintFormat("%s skip: NoTrade trend", symbol);
      return;
     }

   bool pullback = HasPullback(h1Rates, trend);
   if(!pullback)
     {
      PrintFormat("%s skip: no pullback", symbol);
      return;
     }

   if(!IsEntrySignal(h1Rates, trend))
     {
      PrintFormat("%s skip: no entry trigger", symbol);
      return;
     }

   double entryPrice = (trend > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(symbol, SYMBOL_BID);
   if(entryPrice <= 0.0)
      return;

   double sl = 0.0;
   if(!CalculateStopLoss(symbol, trend, entryPrice, sl))
      return;

   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance <= 0.0)
      return;

   double tp = (trend > 0) ? entryPrice + slDistance * RewardRiskRatio
                           : entryPrice - slDistance * RewardRiskRatio;

   double volume = CalculateVolume(symbol, slDistance);
   if(volume <= 0.0)
      return;

   trade.SetExpertMagicNumber((int)SymbolMagic(symbol));

   bool placed = false;
   if(trend > 0)
      placed = trade.Buy(volume, symbol, entryPrice, sl, tp, "HA_BUY");
   else
      placed = trade.Sell(volume, symbol, entryPrice, sl, tp, "HA_SELL");

   if(placed)
      PrintFormat("%s trade placed: %s %.2f lots at %.5f", symbol, trend > 0 ? "BUY" : "SELL", volume, entryPrice);
   else
      PrintFormat("%s trade failed: %d", symbol, GetLastError());
  }

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManagePositions(const string symbol)
  {
   ulong magic = SymbolMagic(symbol);

   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      if(!SelectPositionByIndex(i))
         continue;

      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != symbol)
         continue;

      ulong posMagic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(posMagic != magic)
         continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      long   type  = PositionGetInteger(POSITION_TYPE);

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double current = (type == POSITION_TYPE_BUY) ? bid : ask;

      double risk = MathAbs(entry - sl);
      if(risk > 0.0)
        {
         double profitDistance = (type == POSITION_TYPE_BUY) ? (current - entry) : (entry - current);
         if(profitDistance >= risk * BreakevenAtR)
           {
            double newSL = entry;
            if((type == POSITION_TYPE_BUY && newSL > sl) || (type == POSITION_TYPE_SELL && newSL < sl))
               trade.PositionModify(symbol, newSL, tp);
           }
        }

      if(EnableTrailing)
        {
         double trailSL = 0.0;
         if(CalculateTrailingStop(symbol, type, trailSL))
           {
            if(type == POSITION_TYPE_BUY && trailSL > sl && trailSL < current)
               trade.PositionModify(symbol, trailSL, tp);
            else if(type == POSITION_TYPE_SELL && trailSL < sl && trailSL > current)
               trade.PositionModify(symbol, trailSL, tp);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
bool CalculateStopLoss(const string symbol, const int trend, const double entry, double &sl)
  {
   if(StopLossMode == SL_ATR)
     {
      double atrValue = 0.0;
      if(!GetATR(symbol, atrValue))
         return(false);

      double distance = atrValue * AtrMultiplier;
      if(distance <= 0.0)
         return(false);

      sl = (trend > 0) ? entry - distance : entry + distance;
      return(true);
     }

   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_H1, 1, SwingLookback, rates) < SwingLookback)
      return(false);

   double swing = (trend > 0) ? rates[0].low : rates[0].high;
   for(int i=1; i<SwingLookback; ++i)
     {
      if(trend > 0)
         swing = MathMin(swing, rates[i].low);
      else
         swing = MathMax(swing, rates[i].high);
     }

   double buffer = BufferPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
   sl = (trend > 0) ? (swing - buffer) : (swing + buffer);
   return(true);
  }

//+------------------------------------------------------------------+
//| Calculate trailing stop                                          |
//+------------------------------------------------------------------+
bool CalculateTrailingStop(const string symbol, const long type, double &sl)
  {
   if(TrailMode == TRAIL_ATR)
     {
      double atrValue = 0.0;
      if(!GetATR(symbol, atrValue))
         return(false);

      double distance = atrValue * TrailAtrMultiplier;
      if(distance <= 0.0)
         return(false);

      double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                                 : SymbolInfoDouble(symbol, SYMBOL_ASK);
      sl = (type == POSITION_TYPE_BUY) ? price - distance : price + distance;
      return(true);
     }

   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_H1, 1, TrailSwingLookback, rates) < TrailSwingLookback)
      return(false);

   double swing = (type == POSITION_TYPE_BUY) ? rates[0].low : rates[0].high;
   for(int i=1; i<TrailSwingLookback; ++i)
     {
      if(type == POSITION_TYPE_BUY)
         swing = MathMin(swing, rates[i].low);
      else
         swing = MathMax(swing, rates[i].high);
     }

   sl = swing;
   return(true);
  }

//+------------------------------------------------------------------+
//| Trend direction using H4 HA                                      |
//+------------------------------------------------------------------+
int GetTrendDirection(const string symbol)
  {
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_H4, 1, TrendBars, rates) < TrendBars)
      return(0);

   double haOpen[], haClose[];
   if(!CalculateHeikenAshi(rates, TrendBars, haOpen, haClose))
      return(0);

   bool allBull = true;
   bool allBear = true;
   for(int i=0; i<TrendBars; ++i)
     {
      bool bullish = (haClose[i] > haOpen[i]);
      allBull &= bullish;
      allBear &= !bullish;
     }

   if(allBull)
      return(1);
   if(allBear)
      return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Pullback check                                                   |
//+------------------------------------------------------------------+
bool HasPullback(MqlRates &rates[], const int trend)
  {
   int total = ArraySize(rates);
   if(total < PullbackBars + 2)
      return(false);

   double haOpen[], haClose[];
   if(!CalculateHeikenAshi(rates, PullbackBars + 2, haOpen, haClose))
      return(false);

   for(int i=1; i<=PullbackBars; ++i)
     {
      bool bullish = (haClose[i] > haOpen[i]);
      if(trend > 0 && !bullish)
         return(true);
      if(trend < 0 && bullish)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Entry trigger check                                              |
//+------------------------------------------------------------------+
bool IsEntrySignal(MqlRates &rates[], const int trend)
  {
   double haOpen[], haClose[];
   if(!CalculateHeikenAshi(rates, 3, haOpen, haClose))
      return(false);

   bool lastBull = (haClose[1] > haOpen[1]);
   bool prevBull = (haClose[2] > haOpen[2]);

   if(trend > 0)
      return(lastBull && !prevBull);

   return((!lastBull) && prevBull);
  }

//+------------------------------------------------------------------+
//| Heiken Ashi calculation                                          |
//+------------------------------------------------------------------+
bool CalculateHeikenAshi(MqlRates &rates[], const int count, double &haOpen[], double &haClose[])
  {
   if(count <= 0)
      return(false);

   ArrayResize(haOpen, count);
   ArrayResize(haClose, count);

   for(int i=count-1; i>=0; --i)
     {
      double close = (rates[i].open + rates[i].high + rates[i].low + rates[i].close) / 4.0;
      if(i == count-1)
        {
         double open = (rates[i].open + rates[i].close) / 2.0;
         haOpen[i] = open;
         haClose[i] = close;
        }
      else
        {
         haOpen[i] = (haOpen[i+1] + haClose[i+1]) / 2.0;
         haClose[i] = close;
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| ATR helper                                                       |
//+------------------------------------------------------------------+
bool GetATR(const string symbol, double &atrValue)
  {
   int handle = iATR(symbol, PERIOD_H1, AtrPeriod);
   if(handle == INVALID_HANDLE)
      return(false);

   double buffer[];
   if(CopyBuffer(handle, 0, 1, 1, buffer) < 1)
     {
      IndicatorRelease(handle);
      return(false);
     }

   atrValue = buffer[0];
   IndicatorRelease(handle);
   return(atrValue > 0.0);
  }

//+------------------------------------------------------------------+
//| Volume calculation                                               |
//+------------------------------------------------------------------+
double CalculateVolume(const string symbol, const double slDistance)
  {
   if(slDistance <= 0.0)
      return(0.0);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return(0.0);

   double riskPerLot = (slDistance / tickSize) * tickValue;
   if(riskPerLot <= 0.0)
      return(0.0);

   double volume = riskAmount / riskPerLot;

   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   volume = MathMax(minLot, MathMin(volume, maxLot));
   volume = MathFloor(volume / stepLot) * stepLot;

   if(volume < minLot)
      return(0.0);

   return(volume);
  }

//+------------------------------------------------------------------+
//| Ensure symbol selected                                           |
//+------------------------------------------------------------------+
bool EnsureSymbol(const string symbol)
  {
   if(SymbolInfoInteger(symbol, SYMBOL_SELECT))
      return(true);

   if(SymbolSelect(symbol, true))
      return(true);

   PrintFormat("HeikenAshiMTF_EA: failed to select %s", symbol);
   return(false);
  }

//+------------------------------------------------------------------+
//| Select position by index                                         |
//+------------------------------------------------------------------+
bool SelectPositionByIndex(const int index)
  {
   ulong ticket = PositionGetTicket(index);
   if(ticket == 0)
      return(false);

   return(PositionSelectByTicket(ticket));
  }

//+------------------------------------------------------------------+
//| Count positions for symbol                                       |
//+------------------------------------------------------------------+
int CountSymbolPositions(const string symbol, const ulong magic)
  {
   int count = 0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(!SelectPositionByIndex(i))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ++count;
     }

   return(count);
  }

//+------------------------------------------------------------------+
//| Spread in points                                                 |
//+------------------------------------------------------------------+
double GetSpreadPoints(const string symbol)
  {
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(0.0);

   return((ask - bid) / point);
  }

//+------------------------------------------------------------------+
//| Session filter                                                   |
//+------------------------------------------------------------------+
bool IsWithinSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   if(SessionStartHour == SessionEndHour)
      return(true);

   if(SessionStartHour < SessionEndHour)
      return(hour >= SessionStartHour && hour < SessionEndHour);

   return(hour >= SessionStartHour || hour < SessionEndHour);
  }

//+------------------------------------------------------------------+
//| Symbol magic                                                     |
//+------------------------------------------------------------------+
ulong SymbolMagic(const string symbol)
  {
   int hash = 0;
   for(int i=0; i<StringLen(symbol); ++i)
      hash += StringGetCharacter(symbol, i);

   return(MagicBase + (ulong)(hash % 1000));
  }
