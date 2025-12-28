//+------------------------------------------------------------------+
//| Reverse-DCA Trend Scanner EA (MT5 Hedging)                       |
//| Implements D1 trend filter and H4 entries with pyramiding logic  |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- timeframes
input ENUM_TIMEFRAMES InpTrendTF            = PERIOD_D1;      // Trend timeframe (D1)
input ENUM_TIMEFRAMES InpEntryTF            = PERIOD_H4;      // Entry timeframe (H4)

//--- scanner & filters
input int    InpScanIntervalSec             = 15;             // Timer scan interval (seconds)
input bool   InpUseMarketWatchOnly          = true;           // Use Market Watch symbols only
input string InpExcludeSymbols              = "";             // Comma-separated exclusions
input double InpMaxSpreadPoints             = 40;             // Max spread (points)
input double InpMinAtrPoints                = 50;             // Min ATR on entry TF (points)

//--- trend filters (D1)
input int    InpEmaTrendPeriod              = 50;             // EMA period for trend
input bool   InpUseAdxFilter                = false;          // Enable ADX filter on D1
input int    InpAdxPeriod                   = 14;             // ADX period
input double InpAdxMin                      = 20.0;           // Minimum ADX value

//--- entry logic (H4)
enum EntryMode { ENTRY_BREAKOUT = 0, ENTRY_PULLBACK = 1, ENTRY_BOTH = 2 };
input bool        InpEnableBuy              = true;           // Allow BUY campaigns
input bool        InpEnableSell             = true;           // Allow SELL campaigns
input EntryMode   InpEntryMode              = ENTRY_BREAKOUT; // Entry mode
input int         InpBreakoutN              = 20;             // Highest/Lowest breakout lookback
input int         InpEmaPullbackPeriod      = 20;             // EMA pullback period (H4)
input double      InpPullbackBufferAtr      = 0.2;            // ATR buffer for pullback
input double      InpAtrPeriod              = 14;             // ATR period (H4)
input bool        InpUseMarketOrder         = true;           // Market order (true) or stop (false)
input double      InpMaxSlippagePoints      = 25;             // Max slippage (points)

//--- add logic
input int         InpMaxAdds                = 3;              // Max adds (excluding entry1)
input double      InpAddStepAtr             = 0.8;            // ATR multiples between adds
input double      InpMinProfitToAddAtr      = 0.2;            // Minimum profit in ATR before add
enum AddSizeMode { ADD_MULTIPLIER = 0, ADD_FIXED = 1, ADD_RISK_DECAY = 2 };
input AddSizeMode InpAddSizingMode          = ADD_MULTIPLIER; // Add sizing mode
input string      InpAddMultipliers         = "1.0,0.6,0.4,0.25"; // Multipliers list
input double      InpFixedAddLot            = 0.10;           // Fixed lot size for adds
input double      InpRiskDecay              = 0.7;            // Risk decay factor (mode 2)

//--- SL & trailing
enum InitialSLMode { SL_ATR = 0, SL_SWING = 1 };
input InitialSLMode InpInitialSLMode        = SL_SWING;       // Initial SL mode
input double        InpSL_ATR_Multiplier    = 2.5;            // ATR multiplier for SL
input int           InpSwingLookbackBars    = 20;             // Swing lookback bars
input double        InpSwingBufferAtr       = 0.2;            // Swing buffer ATR
input double        InpBE_TriggerAtr        = 1.0;            // BE trigger in ATR
input double        InpBE_BufferAtr         = 0.1;            // BE buffer ATR
input bool          InpTrailBySwing         = true;           // Trail by swing structure
input bool          InpTrailByAtr           = false;          // Trail by ATR
input double        InpTrailAtr             = 2.0;            // ATR multiple for trailing

//--- exit
input bool   InpExitByTrendBreak            = true;           // Exit on D1 trend break
input bool   InpExitByChannel               = false;          // Exit on H4 channel break
input int    InpExitM                       = 10;             // Channel lookback for exit

//--- risk
input double InpRiskPerCampaignPct          = 0.7;            // Risk % per campaign
input double InpMaxCampaignRiskPct          = 1.2;            // Max risk % per campaign
input double InpMaxTotalOpenRiskPct         = 2.5;            // Max portfolio open risk %
input int    InpMaxConcurrentCampaigns      = 5;              // Max active campaigns total

//--- identification
input ulong  InpBaseMagic                   = 880100;         // Base magic number
input string InpCommentPrefix               = "RDCA";         // Comment prefix

//--- helper structs
struct SymbolContext
  {
   string   name;
   datetime lastH4Bar;
   datetime lastD1Bar;
  };

//--- globals
CTrade        trade;
SymbolContext g_symbols[];
int           g_symbolTotal = 0;

enum TrendDirection { TREND_NONE = 0, TREND_UP = 1, TREND_DOWN = -1 };

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetDeviationInPoints((int)InpMaxSlippagePoints);
   if(!BuildSymbolList())
      return(INIT_FAILED);

   EventSetTimer(InpScanIntervalSec);
   PrintFormat("ReverseDCAEA initialized for %d symbols", g_symbolTotal);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Timer handler                                                    |
//+------------------------------------------------------------------+
void OnTimer()
  {
   for(int i=0; i<g_symbolTotal; ++i)
     {
      ProcessSymbol(g_symbols[i]);
     }
  }

//+------------------------------------------------------------------+
//| Build symbol list                                                |
//+------------------------------------------------------------------+
bool BuildSymbolList()
  {
   ArrayFree(g_symbols);
   g_symbolTotal = 0;

   string excludeClean = InpExcludeSymbols;
   StringReplace(excludeClean, " ", "");
   string exclusions[];
   int exclCount = StringSplit(excludeClean, (ushort)',', exclusions);

   int total = SymbolsTotal(!InpUseMarketWatchOnly);
   for(int i=0; i<total; ++i)
     {
      string symbol = SymbolName(i, !InpUseMarketWatchOnly);
      if(symbol == "")
         continue;

      if(IsExcluded(symbol, exclusions, exclCount))
         continue;

      ArrayResize(g_symbols, g_symbolTotal+1);
      g_symbols[g_symbolTotal].name      = symbol;
      g_symbols[g_symbolTotal].lastH4Bar = 0;
      g_symbols[g_symbolTotal].lastD1Bar = 0;
      ++g_symbolTotal;
     }

   if(g_symbolTotal == 0)
     {
      Print("ReverseDCAEA: no symbols to process");
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Process a symbol                                                 |
//+------------------------------------------------------------------+
void ProcessSymbol(SymbolContext &ctx)
  {
   string symbol = ctx.name;
   if(!EnsureTradable(symbol))
      return;

   long spreadInt = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_SPREAD, spreadInt))
      return;
   double spreadPoints = (double)spreadInt;
   if(spreadPoints <= 0 || spreadPoints > InpMaxSpreadPoints)
      return;

   double atrH4 = RequestATR(symbol, InpEntryTF, InpAtrPeriod, 1);
   if(atrH4 < InpMinAtrPoints * _Point)
      return;

   datetime lastH4Close = GetLastClosedBarTime(symbol, InpEntryTF);
   if(lastH4Close == 0 || lastH4Close == ctx.lastH4Bar)
      return;

   datetime lastD1Close = GetLastClosedBarTime(symbol, InpTrendTF);
   bool newD1 = (lastD1Close != 0 && lastD1Close != ctx.lastD1Bar);
   if(newD1)
      ctx.lastD1Bar = lastD1Close;

   TrendDirection trend = EvaluateTrend(symbol);
   if(trend == TREND_NONE)
     {
      ctx.lastH4Bar = lastH4Close;
      return;
     }

   // exits for active campaigns
   if(InpExitByTrendBreak && newD1)
      CheckTrendBreakExit(symbol, trend);
   if(InpExitByChannel)
      CheckChannelExit(symbol);

   // manage campaigns (adds/trailing)
   ManageCampaign(symbol, trend, atrH4);

   // entry check
   AttemptEntry(symbol, trend, atrH4, lastH4Close);

   ctx.lastH4Bar = lastH4Close;
  }

//+------------------------------------------------------------------+
//| Trend evaluation (D1)                                            |
//+------------------------------------------------------------------+

TrendDirection EvaluateTrend(const string symbol)
  {
   double emaPrev = RequestEMA(symbol, InpTrendTF, InpEmaTrendPeriod, 2);
   double emaCurr = RequestEMA(symbol, InpTrendTF, InpEmaTrendPeriod, 1);
   double close1  = RequestClose(symbol, InpTrendTF, 1);

   if(emaPrev == 0 || emaCurr == 0 || close1 == 0)
      return(TREND_NONE);

   if(InpUseAdxFilter)
     {
      double adx = RequestADX(symbol, InpTrendTF, InpAdxPeriod, 1);
      if(adx < InpAdxMin)
         return(TREND_NONE);
     }

   bool up   = (close1 > emaCurr && emaCurr > emaPrev);
   bool down = (close1 < emaCurr && emaCurr < emaPrev);

   if(up)
      return(TREND_UP);
   if(down)
      return(TREND_DOWN);
   return(TREND_NONE);
  }

//+------------------------------------------------------------------+
//| Entry handler                                                    |
//+------------------------------------------------------------------+
void AttemptEntry(const string symbol, const TrendDirection trend, const double atrH4, const datetime lastH4Close)
  {
   if(trend == TREND_UP && !InpEnableBuy)
      return;
   if(trend == TREND_DOWN && !InpEnableSell)
      return;

   int direction = (trend == TREND_UP) ? 1 : -1;
   int magic = BuildMagic(symbol, direction);

   if(IsCampaignActive(symbol, magic))
      return;

   if(CountCampaigns() >= InpMaxConcurrentCampaigns)
      return;

   if(GetTotalOpenRiskPct() >= InpMaxTotalOpenRiskPct)
      return;

   if(!HasEntrySignal(symbol, direction, atrH4))
      return;

   double entryPrice = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(symbol, SYMBOL_BID);
   if(entryPrice <= 0)
      return;

   double sl = CalculateInitialSL(symbol, direction, atrH4);
   if(sl <= 0 || !ValidateSLDistance(symbol, direction, entryPrice, sl))
      return;

   double volume = CalculateVolumeByRisk(symbol, direction, entryPrice, sl, InpRiskPerCampaignPct);
   if(volume <= 0)
      return;

   string comment = BuildComment(symbol, direction);
   bool placed = (direction == 1)
      ? trade.Buy(volume, symbol, entryPrice, sl, 0.0, comment)
      : trade.Sell(volume, symbol, entryPrice, sl, 0.0, comment);

   if(placed)
      PrintFormat("[ENTRY] %s %s %.2f lots at %.5f SL %.5f", symbol, direction==1?"BUY":"SELL", volume, entryPrice, sl);
   else
      PrintFormat("[ENTRY-FAIL] %s %s error %d", symbol, direction==1?"BUY":"SELL", GetLastError());
  }

//+------------------------------------------------------------------+
//| Add & trailing management                                        |
//+------------------------------------------------------------------+
void ManageCampaign(const string symbol, const TrendDirection trend, const double atrH4)
  {
   // manage both directions separately
   ManageCampaignDirection(symbol, 1, trend, atrH4);
   ManageCampaignDirection(symbol, -1, trend, atrH4);
  }

void ManageCampaignDirection(const string symbol, const int direction, const TrendDirection trend, const double atrH4)
  {
   int magic = BuildMagic(symbol, direction);
   if(!IsCampaignActive(symbol, magic))
      return;

   // exit if trend flipped against campaign
   if(InpExitByTrendBreak && ((direction == 1 && trend != TREND_UP) || (direction == -1 && trend != TREND_DOWN)))
     {
      CloseCampaign(symbol, magic, "TrendBreak");
      return;
     }

   // attempt add
   AttemptAdd(symbol, direction, magic, atrH4);

   // trailing & BE
   UpdateStops(symbol, direction, magic, atrH4);
  }

//+------------------------------------------------------------------+
//| Add order logic                                                  |
//+------------------------------------------------------------------+
void AttemptAdd(const string symbol, const int direction, const int magic, const double atrH4)
  {
   int positions = CountCampaignPositions(symbol, magic);
   if(positions == 0)
      return;
   if(positions-1 >= InpMaxAdds)
      return;

   double wap = CampaignWAP(symbol, magic);
   double lastPrice = LastAddPrice(symbol, magic);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = (direction == 1) ? bid : ask;
   if(wap == 0 || lastPrice == 0 || price == 0)
      return;

   double minProfit = InpMinProfitToAddAtr * atrH4;
   if((direction == 1 && price < wap + minProfit) || (direction == -1 && price > wap - minProfit))
      return;

   double step = InpAddStepAtr * atrH4;
   if((direction == 1 && price < lastPrice + step) || (direction == -1 && price > lastPrice - step))
      return;

   double currentSL = CampaignStop(symbol, magic, direction);
   if(currentSL == 0)
      return;

   double entryPrice = (direction == 1) ? ask : bid;
   double projectedRisk = EstimateCampaignRiskPctWithAdd(symbol, magic, direction, entryPrice, currentSL);
   if(projectedRisk > InpMaxCampaignRiskPct || GetTotalOpenRiskPct() + projectedRisk - CurrentCampaignRiskPct(symbol, magic, direction) > InpMaxTotalOpenRiskPct)
      return;

   double volume = CalculateAddVolume(symbol, magic, direction, entryPrice, currentSL, positions);
   if(volume <= 0)
      return;

   string comment = BuildComment(symbol, direction);
   bool placed = (direction == 1)
      ? trade.Buy(volume, symbol, entryPrice, currentSL, 0.0, comment)
      : trade.Sell(volume, symbol, entryPrice, currentSL, 0.0, comment);

   if(placed)
      PrintFormat("[ADD] %s %s add #%d vol %.2f @%.5f SL %.5f", symbol, direction==1?"BUY":"SELL", positions, volume, entryPrice, currentSL);
   else
      PrintFormat("[ADD-FAIL] %s %s error %d", symbol, direction==1?"BUY":"SELL", GetLastError());
  }

//+------------------------------------------------------------------+
//| Stop updates                                                     |
//+------------------------------------------------------------------+
void UpdateStops(const string symbol, const int direction, const int magic, const double atrH4)
  {
   int total = PositionsTotal();
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double price = (direction == 1) ? bid : ask;
   double wap = CampaignWAP(symbol, magic);
   if(total == 0 || price == 0 || wap == 0)
      return;

   double candidateBE = 0.0;
   if((direction == 1 && price >= wap + InpBE_TriggerAtr * atrH4) ||
      (direction == -1 && price <= wap - InpBE_TriggerAtr * atrH4))
     {
      candidateBE = (direction == 1) ? (wap + InpBE_BufferAtr * atrH4)
                                     : (wap - InpBE_BufferAtr * atrH4);
     }

   double swingSL = 0.0;
   if(InpTrailBySwing)
      swingSL = TrailBySwing(symbol, direction, atrH4);

   double atrTrail = 0.0;
   if(InpTrailByAtr)
      atrTrail = (direction == 1) ? (price - InpTrailAtr * atrH4)
                                  : (price + InpTrailAtr * atrH4);

   double newSL = CampaignStop(symbol, magic, direction);
   if(candidateBE != 0.0)
      newSL = (direction == 1) ? MathMax(newSL, candidateBE) : MathMin(newSL, candidateBE);
   if(swingSL != 0.0)
      newSL = (direction == 1) ? MathMax(newSL, swingSL) : MathMin(newSL, swingSL);
   if(atrTrail != 0.0)
      newSL = (direction == 1) ? MathMax(newSL, atrTrail) : MathMin(newSL, atrTrail);

   if(newSL == 0.0)
      return;

   // apply SL to all positions in campaign
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      double current = PositionGetDouble(POSITION_SL);
      if(direction == 1 && newSL > current + _Point)
        {
         trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
      if(direction == -1 && (current == 0.0 || newSL < current - _Point))
        {
         trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
     }
  }

//+------------------------------------------------------------------+
//| Exit logic                                                       |
//+------------------------------------------------------------------+
void CheckTrendBreakExit(const string symbol, const TrendDirection trend)
  {
   if(trend == TREND_UP)
      CloseCampaign(symbol, BuildMagic(symbol, -1), "TrendBreak");
   else if(trend == TREND_DOWN)
      CloseCampaign(symbol, BuildMagic(symbol, 1), "TrendBreak");
  }

void CheckChannelExit(const string symbol)
  {
   double close = RequestClose(symbol, InpEntryTF, 1);
   if(close == 0.0)
      return;

   double highest = HighestHigh(symbol, InpEntryTF, InpExitM, 2);
   double lowest  = LowestLow(symbol, InpEntryTF, InpExitM, 2);

   if(highest == 0.0 || lowest == 0.0)
      return;

   if(close < lowest)
      CloseCampaign(symbol, BuildMagic(symbol, 1), "ChannelExit");
   else if(close > highest)
      CloseCampaign(symbol, BuildMagic(symbol, -1), "ChannelExit");
  }

void CloseCampaign(const string symbol, const int magic, const string reason)
  {
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      trade.PositionClose(ticket);
   }
   PrintFormat("[EXIT] %s magic %d reason %s", symbol, magic, reason);
  }

//+------------------------------------------------------------------+
//| Entry signal evaluation                                          |
//+------------------------------------------------------------------+
bool HasEntrySignal(const string symbol, const int direction, const double atrH4)
  {
   bool breakoutOk = false;
   bool pullbackOk = false;

   double close1 = RequestClose(symbol, InpEntryTF, 1);
   if(close1 == 0.0)
      return(false);

   if(InpEntryMode == ENTRY_BREAKOUT || InpEntryMode == ENTRY_BOTH)
     {
      if(direction == 1)
         breakoutOk = (close1 > HighestHigh(symbol, InpEntryTF, InpBreakoutN, 2));
      else
         breakoutOk = (close1 < LowestLow(symbol, InpEntryTF, InpBreakoutN, 2));
     }

   if(InpEntryMode == ENTRY_PULLBACK || InpEntryMode == ENTRY_BOTH)
     {
      double ema20 = RequestEMA(symbol, InpEntryTF, InpEmaPullbackPeriod, 1);
      if(ema20 != 0.0)
        {
         double low1 = RequestLow(symbol, InpEntryTF, 1);
         if(direction == 1)
            pullbackOk = (low1 <= ema20 + InpPullbackBufferAtr * atrH4 && close1 > ema20);
         else
            pullbackOk = (RequestHigh(symbol, InpEntryTF, 1) >= ema20 - InpPullbackBufferAtr * atrH4 && close1 < ema20);
        }
     }

   return(breakoutOk || pullbackOk);
  }

//+------------------------------------------------------------------+
//| Initial SL calculation                                           |
//+------------------------------------------------------------------+
double CalculateInitialSL(const string symbol, const int direction, const double atrH4)
  {
   if(InpInitialSLMode == SL_ATR)
     {
      double entry = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(symbol, SYMBOL_BID);
      if(entry == 0.0)
         return(0.0);
      return((direction == 1) ? (entry - InpSL_ATR_Multiplier * atrH4)
                              : (entry + InpSL_ATR_Multiplier * atrH4));
     }

   // swing-based
   double swing = (direction == 1) ? RecentSwingLow(symbol) : RecentSwingHigh(symbol);
   double buffer = InpSwingBufferAtr * atrH4;
   if(swing == 0.0)
     {
      double entry = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(symbol, SYMBOL_BID);
      return((direction == 1) ? (entry - InpSL_ATR_Multiplier * atrH4)
                              : (entry + InpSL_ATR_Multiplier * atrH4));
     }

   return((direction == 1) ? (swing - buffer) : (swing + buffer));
  }

//+------------------------------------------------------------------+
//| Risk-based sizing                                                |
//+------------------------------------------------------------------+
double CalculateVolumeByRisk(const string symbol, const int direction, const double entryPrice, const double slPrice, const double riskPct)
  {
   double riskMoney = AccountEquity() * (riskPct * 0.01);
   double tickSize  = 0.0;
   double tickValue = 0.0;
   double volumeMin = 0.0;
   double volumeMax = 0.0;
   double step      = 0.0;
   if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tickSize))   return(0.0);
   if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tickValue)) return(0.0);
   if(!GetSymbolDouble(symbol, SYMBOL_VOLUME_MIN, volumeMin))       return(0.0);
   if(!GetSymbolDouble(symbol, SYMBOL_VOLUME_MAX, volumeMax))       return(0.0);
   if(!GetSymbolDouble(symbol, SYMBOL_VOLUME_STEP, step))           return(0.0);

   double stopDistance = MathAbs(entryPrice - slPrice);
   if(stopDistance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return(0.0);

   double stopTicks = stopDistance / tickSize;
   double rawVolume = riskMoney / (stopTicks * tickValue);
   rawVolume = MathMax(volumeMin, MathMin(volumeMax, rawVolume));
   rawVolume = MathFloor(rawVolume / step) * step;
   long volDigits = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_VOLUME_DIGITS, volDigits))
      return(0.0);
   return(NormalizeDouble(rawVolume, (int)volDigits));
  }

double CalculateAddVolume(const string symbol, const int magic, const int direction, const double entryPrice, const double slPrice, const int positions)
  {
   if(InpAddSizingMode == ADD_FIXED)
      return(InpFixedAddLot);

   if(InpAddSizingMode == ADD_RISK_DECAY)
     {
      double baseVolume = CalculateVolumeByRisk(symbol, direction, entryPrice, slPrice, InpRiskPerCampaignPct * MathPow(InpRiskDecay, positions-1));
      return(baseVolume);
     }

   // multiplier mode
   string multiplierParts[];
   int count = StringSplit(InpAddMultipliers, (ushort)',', multiplierParts);
   double factor = 1.0;
   if(count > 0)
     {
      int idx = MathMin(positions-1, count-1);
      factor = StringToDouble(multiplierParts[idx]);
      if(factor <= 0.0)
         factor = 1.0;
     }

   // entry1 volume used as baseline
   double baseVolume = CampaignFirstVolume(symbol, magic);
   if(baseVolume <= 0.0)
      baseVolume = CalculateVolumeByRisk(symbol, direction, entryPrice, slPrice, InpRiskPerCampaignPct);

   double vol = baseVolume * factor;
   double step = 0.0;
   if(!GetSymbolDouble(symbol, SYMBOL_VOLUME_STEP, step))
      return(0.0);
   vol = MathFloor(vol / step) * step;
   double volumeMin = 0.0;
   double volumeMax = 0.0;
   if(!GetSymbolDouble(symbol, SYMBOL_VOLUME_MIN, volumeMin)) return(0.0);
   if(!GetSymbolDouble(symbol, SYMBOL_VOLUME_MAX, volumeMax)) return(0.0);
   vol = MathMax(volumeMin, MathMin(volumeMax, vol));
   long volDigits = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_VOLUME_DIGITS, volDigits))
      return(0.0);
   return(NormalizeDouble(vol, (int)volDigits));
  }

//+------------------------------------------------------------------+
//| Helpers: campaign metrics                                        |
//+------------------------------------------------------------------+
int CountCampaignPositions(const string symbol, const int magic)
  {
   int count = 0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol && (int)PositionGetInteger(POSITION_MAGIC) == magic)
         ++count;
     }
   return(count);
  }

bool IsCampaignActive(const string symbol, const int magic)
  {
   return(CountCampaignPositions(symbol, magic) > 0);
  }

double CampaignWAP(const string symbol, const int magic)
  {
   double volSum = 0.0;
   double pvSum  = 0.0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol || (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      volSum += vol;
      pvSum  += vol * price;
     }

   return(volSum > 0.0 ? pvSum / volSum : 0.0);
  }

double LastAddPrice(const string symbol, const int magic)
  {
   datetime latest = 0;
   double price = 0.0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol || (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      datetime time = (datetime)PositionGetInteger(POSITION_TIME);
      if(time >= latest)
        {
         latest = time;
         price = PositionGetDouble(POSITION_PRICE_OPEN);
        }
     }
   return(price);
  }

double CampaignStop(const string symbol, const int magic, const int direction)
  {
   double result = 0.0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol || (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      double sl = PositionGetDouble(POSITION_SL);
      if(sl == 0.0)
         continue;
      if(result == 0.0)
         result = sl;
      else
         result = (direction == 1) ? MathMax(result, sl) : MathMin(result, sl);
     }
   return(result);
  }

double CampaignFirstVolume(const string symbol, const int magic)
  {
   datetime earliest = (datetime)2147483647;
   double vol = 0.0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol || (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      datetime time = (datetime)PositionGetInteger(POSITION_TIME);
      if(time <= earliest)
        {
         earliest = time;
         vol = PositionGetDouble(POSITION_VOLUME);
        }
     }
   return(vol);
  }

double CurrentCampaignRiskPct(const string symbol, const int magic, const int direction)
  {
   double riskMoney = 0.0;
   double equity = AccountEquity();
   if(equity <= 0.0)
      return(0.0);

   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol || (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      double sl = PositionGetDouble(POSITION_SL);
      if(sl == 0.0)
         continue;
      double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double tickValue = 0.0;
      double tickSize  = 0.0;
      if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tickValue)) continue;
      if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tickSize))   continue;
      double distance  = (direction == 1) ? (priceOpen - sl) : (sl - priceOpen);
      if(distance <= 0.0)
         continue;
      riskMoney += distance / tickSize * tickValue * volume;
     }
   return(riskMoney / equity * 100.0);
  }

double EstimateCampaignRiskPctWithAdd(const string symbol, const int magic, const int direction, const double entryPrice, const double slPrice)
  {
   double riskMoney = 0.0;
   double equity = AccountEquity();
   double tickValue = 0.0;
   double tickSize  = 0.0;
   if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tickValue)) return(0.0);
   if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tickSize))   return(0.0);
   if(equity <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return(0.0);

   // existing
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol || (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double distance = (direction == 1) ? (priceOpen - sl) : (sl - priceOpen);
      if(distance > 0.0)
         riskMoney += distance / tickSize * tickValue * vol;
     }

   // projected add
   double addVolume = CalculateAddVolume(symbol, magic, direction, entryPrice, slPrice, CountCampaignPositions(symbol, magic)+1);
   double distance  = (direction == 1) ? (entryPrice - slPrice) : (slPrice - entryPrice);
   if(distance > 0.0)
      riskMoney += distance / tickSize * tickValue * addVolume;

   return(riskMoney / equity * 100.0);
  }

double GetTotalOpenRiskPct()
  {
   double equity = AccountEquity();
   if(equity <= 0.0)
      return(0.0);

   double riskMoney = 0.0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      double sl = PositionGetDouble(POSITION_SL);
      if(sl == 0.0)
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      int direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double tickValue = 0.0;
      double tickSize  = 0.0;
      if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tickValue)) continue;
      if(!GetSymbolDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tickSize))   continue;
      double distance  = (direction == 1) ? (priceOpen - sl) : (sl - priceOpen);
      if(distance <= 0.0 || tickSize <= 0.0)
         continue;
      riskMoney += distance / tickSize * tickValue * vol;
     }
   return(riskMoney / equity * 100.0);
  }

int CountCampaigns()
  {
   int count = 0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, InpCommentPrefix) == 0)
         ++count;
     }
   return(count);
  }

//+------------------------------------------------------------------+
//| Indicator helpers                                                |
//+------------------------------------------------------------------+
double RequestATR(const string symbol, ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE)
      return(0.0);
   double buffer[];
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
     {
      IndicatorRelease(handle);
      return(0.0);
     }
   double value = buffer[0];
   IndicatorRelease(handle);
   return(value);
  }

double RequestEMA(const string symbol, ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   int handle = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return(0.0);
   double buffer[];
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
     {
      IndicatorRelease(handle);
      return(0.0);
     }
   double value = buffer[0];
   IndicatorRelease(handle);
   return(value);
  }

double RequestADX(const string symbol, ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   int handle = iADX(symbol, tf, period);
   if(handle == INVALID_HANDLE)
      return(0.0);
   double buffer[];
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
     {
      IndicatorRelease(handle);
      return(0.0);
     }
   double value = buffer[0];
   IndicatorRelease(handle);
   return(value);
  }

double RequestClose(const string symbol, ENUM_TIMEFRAMES tf, const int shift)
  {
   double price[];
   if(CopyClose(symbol, tf, shift, 1, price) != 1)
      return(0.0);
   return(price[0]);
  }

double RequestLow(const string symbol, ENUM_TIMEFRAMES tf, const int shift)
  {
   double price[];
   if(CopyLow(symbol, tf, shift, 1, price) != 1)
      return(0.0);
   return(price[0]);
  }

double RequestHigh(const string symbol, ENUM_TIMEFRAMES tf, const int shift)
  {
   double price[];
   if(CopyHigh(symbol, tf, shift, 1, price) != 1)
      return(0.0);
   return(price[0]);
  }

double HighestHigh(const string symbol, ENUM_TIMEFRAMES tf, const int lookback, const int shift)
  {
   double highs[];
   int copied = CopyHigh(symbol, tf, shift, lookback, highs);
   if(copied < lookback)
      return(0.0);
   double highest = highs[0];
   for(int i=1; i<copied; ++i)
      highest = MathMax(highest, highs[i]);
   return(highest);
  }

double LowestLow(const string symbol, ENUM_TIMEFRAMES tf, const int lookback, const int shift)
  {
   double lows[];
   int copied = CopyLow(symbol, tf, shift, lookback, lows);
   if(copied < lookback)
      return(0.0);
   double lowest = lows[0];
   for(int i=1; i<copied; ++i)
      lowest = MathMin(lowest, lows[i]);
   return(lowest);
  }

double RecentSwingLow(const string symbol)
  {
   MqlRates rates[];
   int copied = CopyRates(symbol, InpEntryTF, 1, InpSwingLookbackBars+1, rates);
   if(copied <= 0)
      return(0.0);

   double lowest = rates[0].low;
   for(int i=1; i<copied; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return(lowest);
  }

double RecentSwingHigh(const string symbol)
  {
   MqlRates rates[];
   int copied = CopyRates(symbol, InpEntryTF, 1, InpSwingLookbackBars+1, rates);
   if(copied <= 0)
      return(0.0);

   double highest = rates[0].high;
   for(int i=1; i<copied; ++i)
      highest = MathMax(highest, rates[i].high);
   return(highest);
  }

double TrailBySwing(const string symbol, const int direction, const double atrH4)
  {
   if(direction == 1)
      return(RecentSwingLow(symbol) - InpSwingBufferAtr * atrH4);
   else
      return(RecentSwingHigh(symbol) + InpSwingBufferAtr * atrH4);
  }

datetime GetLastClosedBarTime(const string symbol, ENUM_TIMEFRAMES tf)
  {
   MqlRates rates[2];
   if(CopyRates(symbol, tf, 0, 2, rates) < 2)
      return(0);
   return(rates[1].time);
  }

//+------------------------------------------------------------------+
//| Utility helpers                                                  |
//+------------------------------------------------------------------+
bool EnsureTradable(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return(false);

   long tradeMode = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeMode))
      return(false);
   return(tradeMode == SYMBOL_TRADE_MODE_FULL || tradeMode == SYMBOL_TRADE_MODE_LONGONLY || tradeMode == SYMBOL_TRADE_MODE_SHORTONLY);
  }

bool ValidateSLDistance(const string symbol, const int direction, const double entry, const double sl)
  {
   long stopLevelInt = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL, stopLevelInt))
      return(false);
   double stopLevel = stopLevelInt * _Point;
   if(stopLevel <= 0)
      return(true);

   double distance = MathAbs(entry - sl);
   return(distance > stopLevel);
  }

bool IsExcluded(const string symbol, string &exclusions[], const int count)
  {
   string symbolUpper = StringToUpper(symbol);
   for(int i=0; i<count; ++i)
     {
      string exUpper = StringToUpper(exclusions[i]);
      if(symbolUpper == exUpper)
         return(true);
     }
   return(false);
  }

int BuildMagic(const string symbol, const int direction)
  {
   uint hash = 0;
   for(int i=0; i<StringLen(symbol); ++i)
      hash = (hash * 31 + StringGetCharacter(symbol, i)) & 0xFFFFFF;
   return((int)(InpBaseMagic + hash + (direction==1 ? 1 : 2)));
  }

string BuildComment(const string symbol, const int direction)
  {
   return(StringFormat("%s|%s|%s|v1", InpCommentPrefix, symbol, direction==1?"BUY":"SELL"));
  }

bool IsCampaignTicket(const ulong ticket, const string symbol, const int magic)
  {
   if(ticket == 0)
      return(false);
   if(PositionSelectByTicket(ticket))
     {
      return(PositionGetString(POSITION_SYMBOL) == symbol && (int)PositionGetInteger(POSITION_MAGIC) == magic);
     }
   return(false);
  }

// helper for safer symbol property access
bool GetSymbolDouble(const string symbol, const ENUM_SYMBOL_INFO_DOUBLE prop, double &value)
  {
   return(SymbolInfoDouble(symbol, prop, value));
  }
