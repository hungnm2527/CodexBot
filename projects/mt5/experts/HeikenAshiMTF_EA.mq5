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
input int    MinPullbackCandles      = 2;               // Minimum opposite HA candles in pullback
input double RiskPercent             = 1.0;             // Risk % per trade
input int    MaxPositionsPerSymbol   = 1;               // Max positions per symbol
input int    MaxSpreadPoints         = 60;              // Max spread in points
input int    SessionStartHour        = 7;               // Trading session start (server hour)
input int    SessionEndHour          = 20;              // Trading session end (server hour)
input bool   EnableConfirmStrength   = true;            // Enable HA body vs ATR confirmation
input int    ConfirmAtrPeriod        = 14;              // ATR period for confirmation (H1)
input double MinConfirmBodyAtr       = 0.35;            // Min HA body as ATR multiple
input bool   EnableEmaFilter         = true;            // Enable EMA trend filter on H1
input int    EmaPeriod               = 200;             // EMA period
input ENUM_APPLIED_PRICE EmaAppliedPrice = PRICE_CLOSE; // EMA applied price
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
input bool   EnableMartingale             = true;
input double MartingaleMultiplier         = 2.0;   // factor per loss
input int    MaxMartingaleSteps           = 3;     // max consecutive losses before cooldown
input int    CooldownMinutesAfterMaxSteps = 240;   // pause trading for this symbol after max steps reached
input double MaxMartingaleLots            = 5.0;   // absolute lots cap after scaling (safety)
input double MaxMartingaleRiskPercent     = 2.0;   // cap effective risk % for a single trade after scaling (0 = disabled)
input bool   FreezeSlTpDuringStreak       = true;  // keep SL/TP distance constant (points) during loss streak
input bool   ResetOnBreakeven             = true;  // if profit >=0 resets streak/factor

struct SymbolState
  {
   string   name;
   datetime lastH1Processed;
   int      confirmAtrHandle;
   int      emaHandle;
   int      lossStreak;
   double   mgFactor;
   datetime lastDealCloseTime;
   datetime cooldownUntil;
   double   fixedSlPoints;
   double   fixedTpPoints;
   double   candidateSlPoints;
   double   candidateTpPoints;
  };

CTrade      trade;
SymbolState g_symbols[];
int         g_symbolTotal = 0;

bool SelectPositionByIndex(const int index);
bool EnsureIndicatorHandles(SymbolState &state);
bool GetConfirmAtr(SymbolState &state, double &atrValue);
bool GetEmaValue(SymbolState &state, double &emaValue);
string MgKey(const string symbol, const string field);
void LoadMartingaleState(SymbolState &state);
void SaveMartingaleState(const SymbolState &state);
bool UpdateMartingaleFromHistory(SymbolState &state);
double NormalizeVolume(const string symbol, const double vol);
bool GetFixedDistancesFromHistory(const ulong positionId, const string symbol, const ulong magic, double &slPoints, double &tpPoints);

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetDeviationInPoints(SlippagePoints);

   if(!BuildSymbolList())
      return(INIT_FAILED);

   if(MinPullbackCandles < 1)
      Print("HeikenAshiMTF_EA: MinPullbackCandles must be >= 1. Using 1.");

   if(MinConfirmBodyAtr < 0.0)
      Print("HeikenAshiMTF_EA: MinConfirmBodyAtr must be >= 0. Using 0.");

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
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i=0; i<g_symbolTotal; ++i)
     {
      if(g_symbols[i].confirmAtrHandle != INVALID_HANDLE)
        {
         IndicatorRelease(g_symbols[i].confirmAtrHandle);
         g_symbols[i].confirmAtrHandle = INVALID_HANDLE;
        }

      if(g_symbols[i].emaHandle != INVALID_HANDLE)
        {
         IndicatorRelease(g_symbols[i].emaHandle);
         g_symbols[i].emaHandle = INVALID_HANDLE;
        }

      if(EnableMartingale)
         SaveMartingaleState(g_symbols[i]);
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
      g_symbols[g_symbolTotal].confirmAtrHandle = INVALID_HANDLE;
      g_symbols[g_symbolTotal].emaHandle        = INVALID_HANDLE;
      g_symbols[g_symbolTotal].lossStreak       = 0;
      g_symbols[g_symbolTotal].mgFactor         = 1.0;
      g_symbols[g_symbolTotal].lastDealCloseTime = 0;
      g_symbols[g_symbolTotal].cooldownUntil     = 0;
      g_symbols[g_symbolTotal].fixedSlPoints     = 0.0;
      g_symbols[g_symbolTotal].fixedTpPoints     = 0.0;
      g_symbols[g_symbolTotal].candidateSlPoints = 0.0;
      g_symbols[g_symbolTotal].candidateTpPoints = 0.0;
      if(EnableMartingale)
         LoadMartingaleState(g_symbols[g_symbolTotal]);
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
      g_symbols[g_symbolTotal].confirmAtrHandle = INVALID_HANDLE;
      g_symbols[g_symbolTotal].emaHandle        = INVALID_HANDLE;
      g_symbols[g_symbolTotal].lossStreak       = 0;
      g_symbols[g_symbolTotal].mgFactor         = 1.0;
      g_symbols[g_symbolTotal].lastDealCloseTime = 0;
      g_symbols[g_symbolTotal].cooldownUntil     = 0;
      g_symbols[g_symbolTotal].fixedSlPoints     = 0.0;
      g_symbols[g_symbolTotal].fixedTpPoints     = 0.0;
      g_symbols[g_symbolTotal].candidateSlPoints = 0.0;
      g_symbols[g_symbolTotal].candidateTpPoints = 0.0;
      if(EnableMartingale)
         LoadMartingaleState(g_symbols[g_symbolTotal]);
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

   if(!EnsureIndicatorHandles(state))
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

   if(EnableMartingale)
      UpdateMartingaleFromHistory(state);

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

   int pullbackCount = 0;
   bool pullback = HasPullback(h1Rates, trend, pullbackCount);
   int minRequired = (MinPullbackCandles <= 1) ? 1 : MinPullbackCandles;
   if(!pullback)
     {
      PrintFormat("%s skip: pullback count=%d < MinPullbackCandles=%d", symbol, pullbackCount, minRequired);
      return;
     }

   if(!IsEntrySignal(h1Rates, trend))
     {
      PrintFormat("%s skip: no entry trigger", symbol);
      return;
     }

   if(EnableConfirmStrength)
     {
      double haOpen[], haClose[];
      if(!CalculateHeikenAshi(h1Rates, 3, haOpen, haClose))
         return;

      double bodySize = MathAbs(haClose[1] - haOpen[1]);
      double atrValue = 0.0;
      if(!GetConfirmAtr(state, atrValue))
         return;

      double minBodyRatio = (MinConfirmBodyAtr < 0.0) ? 0.0 : MinConfirmBodyAtr;
      if(bodySize < minBodyRatio * atrValue)
        {
         PrintFormat("%s skip: confirm body %.5f < %.5f (ATR %.5f * %.2f)", symbol, bodySize, minBodyRatio * atrValue, atrValue, minBodyRatio);
         return;
        }
     }

   if(EnableEmaFilter)
     {
      double emaValue = 0.0;
      if(!GetEmaValue(state, emaValue))
         return;

      double closeValue = h1Rates[1].close;
      if(trend > 0 && closeValue <= emaValue)
        {
         PrintFormat("%s skip: close %.5f <= EMA %.5f", symbol, closeValue, emaValue);
         return;
        }
      if(trend < 0 && closeValue >= emaValue)
        {
         PrintFormat("%s skip: close %.5f >= EMA %.5f", symbol, closeValue, emaValue);
         return;
        }
     }

   double entryPrice = (trend > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(symbol, SYMBOL_BID);
   if(entryPrice <= 0.0)
      return;

   double sl = 0.0;
   double tp = 0.0;
   bool useFrozenStops = false;
   if(EnableMartingale && FreezeSlTpDuringStreak && state.lossStreak > 0 && state.fixedSlPoints > 0.0 && state.fixedTpPoints > 0.0)
     {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return;

      int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minPoints = (stopLevel > 0) ? (double)stopLevel : 0.0;

      double slPoints = MathMax(state.fixedSlPoints, minPoints);
      double tpPoints = MathMax(state.fixedTpPoints, minPoints);

      if(trend > 0)
        {
         sl = entryPrice - slPoints * point;
         tp = entryPrice + tpPoints * point;
        }
      else
        {
         sl = entryPrice + slPoints * point;
         tp = entryPrice - tpPoints * point;
        }

      if(sl > 0.0 && tp > 0.0)
        {
         useFrozenStops = true;
         PrintFormat("%s MG freeze SL/TP: slPts=%.1f, tpPts=%.1f", symbol, slPoints, tpPoints);
        }
     }

   if(!useFrozenStops)
     {
      if(!CalculateStopLoss(symbol, trend, entryPrice, sl))
         return;

      double slDistance = MathAbs(entryPrice - sl);
      if(slDistance <= 0.0)
         return;

      tp = (trend > 0) ? entryPrice + slDistance * RewardRiskRatio
                       : entryPrice - slDistance * RewardRiskRatio;
     }

   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance <= 0.0)
      return;

   double baseVolume = CalculateVolume(symbol, slDistance);
   if(baseVolume <= 0.0)
      return;

   double volume = baseVolume;
   if(EnableMartingale)
     {
      if(TimeCurrent() < state.cooldownUntil)
        {
         PrintFormat("%s skip: martingale cooldown active until %s", symbol, TimeToString(state.cooldownUntil));
         return;
        }

      double factor = (state.lossStreak > 0) ? state.mgFactor : 1.0;
      double scaled = baseVolume * factor;
      if(MaxMartingaleLots > 0.0)
         scaled = MathMin(scaled, MaxMartingaleLots);

      if(MaxMartingaleRiskPercent > 0.0)
        {
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         if(tickValue > 0.0 && tickSize > 0.0 && balance > 0.0)
           {
            double riskPerLot = (slDistance / tickSize) * tickValue;
            if(riskPerLot > 0.0)
              {
               double maxRiskAmount = balance * (MaxMartingaleRiskPercent / 100.0);
               double maxLots = maxRiskAmount / riskPerLot;
               if(maxLots > 0.0)
                  scaled = MathMin(scaled, maxLots);
              }
           }
        }

      volume = NormalizeVolume(symbol, scaled);
      if(volume <= 0.0)
         return;

      PrintFormat("%s MG apply: streak=%d factor=%.2f baseLot=%.2f finalLot=%.2f", symbol, state.lossStreak, factor, baseVolume, volume);
     }

   trade.SetExpertMagicNumber((int)SymbolMagic(symbol));

   bool placed = false;
   if(trend > 0)
      placed = trade.Buy(volume, symbol, entryPrice, sl, tp, "HA_BUY");
   else
      placed = trade.Sell(volume, symbol, entryPrice, sl, tp, "HA_SELL");

   if(placed)
     {
      PrintFormat("%s trade placed: %s %.2f lots at %.5f", symbol, trend > 0 ? "BUY" : "SELL", volume, entryPrice);
      if(EnableMartingale && state.lossStreak == 0)
        {
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(point > 0.0)
           {
            state.candidateSlPoints = slDistance / point;
            state.candidateTpPoints = MathAbs(tp - entryPrice) / point;
           }
        }
     }
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
bool HasPullback(MqlRates &rates[], const int trend, int &pullbackCount)
  {
   int total = ArraySize(rates);
   if(total < PullbackBars + 2)
      return(false);

   double haOpen[], haClose[];
   if(!CalculateHeikenAshi(rates, PullbackBars + 2, haOpen, haClose))
      return(false);

   pullbackCount = 0;
   for(int i=1; i<=PullbackBars; ++i)
     {
      bool bullish = (haClose[i] > haOpen[i]);
      if(trend > 0 && !bullish)
         ++pullbackCount;
      if(trend < 0 && bullish)
         ++pullbackCount;
     }

   int minRequired = (MinPullbackCandles <= 1) ? 1 : MinPullbackCandles;
   return(pullbackCount >= minRequired);
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
//| Ensure indicator handles                                         |
//+------------------------------------------------------------------+
bool EnsureIndicatorHandles(SymbolState &state)
  {
   if(EnableConfirmStrength && state.confirmAtrHandle == INVALID_HANDLE)
     {
      state.confirmAtrHandle = iATR(state.name, PERIOD_H1, ConfirmAtrPeriod);
      if(state.confirmAtrHandle == INVALID_HANDLE)
        {
         PrintFormat("%s: failed to create confirm ATR handle", state.name);
         return(false);
        }
     }

   if(EnableEmaFilter && state.emaHandle == INVALID_HANDLE)
     {
      state.emaHandle = iMA(state.name, PERIOD_H1, EmaPeriod, 0, MODE_EMA, EmaAppliedPrice);
      if(state.emaHandle == INVALID_HANDLE)
        {
         PrintFormat("%s: failed to create EMA handle", state.name);
         return(false);
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Confirmation ATR helper                                          |
//+------------------------------------------------------------------+
bool GetConfirmAtr(SymbolState &state, double &atrValue)
  {
   if(state.confirmAtrHandle == INVALID_HANDLE)
      return(false);

   double buffer[];
   if(CopyBuffer(state.confirmAtrHandle, 0, 1, 1, buffer) < 1)
      return(false);

   atrValue = buffer[0];
   return(atrValue > 0.0);
  }

//+------------------------------------------------------------------+
//| EMA helper                                                       |
//+------------------------------------------------------------------+
bool GetEmaValue(SymbolState &state, double &emaValue)
  {
   if(state.emaHandle == INVALID_HANDLE)
      return(false);

   double buffer[];
   if(CopyBuffer(state.emaHandle, 0, 1, 1, buffer) < 1)
      return(false);

   emaValue = buffer[0];
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

//+------------------------------------------------------------------+
//| Martingale state helpers                                         |
//+------------------------------------------------------------------+
string MgKey(const string symbol, const string field)
  {
   return("HA_MG_" + symbol + "_" + field);
  }

void LoadMartingaleState(SymbolState &state)
  {
   string symbol = state.name;
   if(GlobalVariableCheck(MgKey(symbol, "streak")))
      state.lossStreak = (int)GlobalVariableGet(MgKey(symbol, "streak"));
   if(GlobalVariableCheck(MgKey(symbol, "factor")))
      state.mgFactor = GlobalVariableGet(MgKey(symbol, "factor"));
   if(GlobalVariableCheck(MgKey(symbol, "lastClose")))
      state.lastDealCloseTime = (datetime)GlobalVariableGet(MgKey(symbol, "lastClose"));
   if(GlobalVariableCheck(MgKey(symbol, "cooldown")))
      state.cooldownUntil = (datetime)GlobalVariableGet(MgKey(symbol, "cooldown"));
   if(GlobalVariableCheck(MgKey(symbol, "slp")))
      state.fixedSlPoints = GlobalVariableGet(MgKey(symbol, "slp"));
   if(GlobalVariableCheck(MgKey(symbol, "tpp")))
      state.fixedTpPoints = GlobalVariableGet(MgKey(symbol, "tpp"));

   if(state.lossStreak < 0)
      state.lossStreak = 0;
   if(state.mgFactor <= 0.0)
      state.mgFactor = 1.0;
  }

void SaveMartingaleState(const SymbolState &state)
  {
   string symbol = state.name;
   GlobalVariableSet(MgKey(symbol, "streak"), (double)state.lossStreak);
   GlobalVariableSet(MgKey(symbol, "factor"), state.mgFactor);
   GlobalVariableSet(MgKey(symbol, "lastClose"), (double)state.lastDealCloseTime);
   GlobalVariableSet(MgKey(symbol, "cooldown"), (double)state.cooldownUntil);
   GlobalVariableSet(MgKey(symbol, "slp"), state.fixedSlPoints);
   GlobalVariableSet(MgKey(symbol, "tpp"), state.fixedTpPoints);
  }

bool GetFixedDistancesFromHistory(const ulong positionId, const string symbol, const ulong magic, double &slPoints, double &tpPoints)
  {
   slPoints = 0.0;
   tpPoints = 0.0;
   if(positionId == 0)
      return(false);

   int ordersTotal = HistoryOrdersTotal();
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(false);

   for(int i=ordersTotal-1; i>=0; --i)
     {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != symbol)
         continue;

      if((ulong)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;

      if((ulong)HistoryOrderGetInteger(ticket, ORDER_POSITION_ID) != positionId)
         continue;

      long type = HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(type != ORDER_TYPE_BUY && type != ORDER_TYPE_SELL)
         continue;

      double openPrice = HistoryOrderGetDouble(ticket, ORDER_PRICE_OPEN);
      double sl = HistoryOrderGetDouble(ticket, ORDER_SL);
      double tp = HistoryOrderGetDouble(ticket, ORDER_TP);
      if(openPrice <= 0.0 || sl <= 0.0 || tp <= 0.0)
         continue;

      slPoints = MathAbs(openPrice - sl) / point;
      tpPoints = MathAbs(tp - openPrice) / point;
      if(slPoints > 0.0 && tpPoints > 0.0)
         return(true);
     }

   return(false);
  }

bool UpdateMartingaleFromHistory(SymbolState &state)
  {
   if(!EnableMartingale)
      return(false);

   datetime now = TimeCurrent();
   datetime from = now - (180 * 86400);
   if(!HistorySelect(from, now))
      return(false);

   int dealsTotal = HistoryDealsTotal();
   ulong latestDeal = 0;
   datetime latestTime = 0;
   double latestProfit = 0.0;
   ulong positionId = 0;
   ulong magic = SymbolMagic(state.name);

   for(int i=0; i<dealsTotal; ++i)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != state.name)
         continue;

      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;

      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(closeTime <= latestTime)
         continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);

      latestTime = closeTime;
      latestDeal = ticket;
      latestProfit = profit + commission + swap;
      positionId = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
     }

   if(latestDeal == 0 || latestTime <= state.lastDealCloseTime)
      return(false);

   state.lastDealCloseTime = latestTime;

   if(latestProfit > 0.0 || (ResetOnBreakeven && latestProfit >= 0.0))
     {
      state.lossStreak = 0;
      state.mgFactor = 1.0;
      state.cooldownUntil = 0;
      state.fixedSlPoints = 0.0;
      state.fixedTpPoints = 0.0;
      state.candidateSlPoints = 0.0;
      state.candidateTpPoints = 0.0;
      PrintFormat("%s MG reset after win, profit=%.2f, factor=1", state.name, latestProfit);
      SaveMartingaleState(state);
      return(true);
     }

   if(latestProfit < 0.0)
     {
      state.lossStreak += 1;
      state.mgFactor *= MartingaleMultiplier;
      if(state.mgFactor < 1.0)
         state.mgFactor = 1.0;
      if(MaxMartingaleLots > 0.0)
         state.mgFactor = MathMin(state.mgFactor, MaxMartingaleLots);

      if(state.lossStreak == 1 && FreezeSlTpDuringStreak)
        {
         double slPoints = 0.0;
         double tpPoints = 0.0;
         if(GetFixedDistancesFromHistory(positionId, state.name, magic, slPoints, tpPoints))
           {
            state.fixedSlPoints = slPoints;
            state.fixedTpPoints = tpPoints;
           }
         else if(state.candidateSlPoints > 0.0 && state.candidateTpPoints > 0.0)
           {
            state.fixedSlPoints = state.candidateSlPoints;
            state.fixedTpPoints = state.candidateTpPoints;
           }
         else
           {
            state.fixedSlPoints = 0.0;
            state.fixedTpPoints = 0.0;
           }
        }

      if(state.lossStreak >= MaxMartingaleSteps && MaxMartingaleSteps > 0)
        {
         state.cooldownUntil = TimeCurrent() + CooldownMinutesAfterMaxSteps * 60;
         PrintFormat("%s MG reached max steps=%d, cooldown until %s", state.name, state.lossStreak, TimeToString(state.cooldownUntil));
        }

      PrintFormat("%s MG loss streak=%d, factor=%.2f, profit=%.2f", state.name, state.lossStreak, state.mgFactor, latestProfit);
      SaveMartingaleState(state);
      return(true);
     }

   SaveMartingaleState(state);
   return(false);
  }

double NormalizeVolume(const string symbol, const double vol)
  {
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      return(0.0);

   double volume = MathMax(minLot, MathMin(vol, maxLot));
   volume = MathFloor(volume / stepLot) * stepLot;

   if(volume < minLot)
      return(0.0);

   return(volume);
  }
