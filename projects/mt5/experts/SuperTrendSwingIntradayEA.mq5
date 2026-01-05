//+------------------------------------------------------------------+
//| SuperTrendSwingIntradayEA.mq5                                    |
//| Accuracy-first swing intraday EA using SuperTrend + ATR          |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

enum SLMode
  {
   ST_BASED = 0,
   ATR_BASED = 1
  };

enum TPMode
  {
   RR = 0,
   ATR_MULT = 1
  };

enum TrailingMode
  {
   ST_FAST = 0,
   ATR = 1
  };

input string           Symbols                            = "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD,NZDUSD,EURJPY,GBPJPY,XAUUSD,XAGUSD";
input ENUM_TIMEFRAMES  TrendTF                            = PERIOD_H4;
input ENUM_TIMEFRAMES  EntryTF                            = PERIOD_H1;

input int              ST_Slow_ATR                        = 14;
input double           ST_Slow_Mult                       = 3.5;
input int              ST_Fast_ATR                        = 10;
input double           ST_Fast_Mult                       = 2.5;

input bool             UseMetalsPreset                    = true;
input string           MetalsSymbols                      = "XAUUSD,XAGUSD";
input double           Metals_ST_Slow_Mult                = 4.0;
input double           Metals_ST_Fast_Mult                = 3.0;

input double           MaxSpreadPips_Forex                = 1.8;
input double           MaxSpreadPips_JPY                  = 2.2;
input double           MaxSpreadPips_XAU                  = 3.5;
input double           MaxSpreadPips_XAG                  = 4.0;

input double           SL_BufferPips_Forex                = 0.6;
input double           SL_BufferPips_JPY                  = 0.8;
input double           SL_BufferPips_XAU                  = 1.2;
input double           SL_BufferPips_XAG                  = 1.5;

input double           RiskPercent                        = 0.50;
input int              MaxTradesPerDayPerSymbol           = 1;
input int              MaxOpenPositionsTotal              = 4;
input double           DailyLossLimitPercent              = 2.0;
input bool             OnePositionPerSymbol               = true;
input bool             AllowHedgingSameSymbol             = false;
input long             MagicNumber                        = 20260105;

input SLMode           StopLossMode                       = ST_BASED;
input TPMode           TakeProfitMode                     = RR;
input double           TakeProfitRR                       = 1.4;
input double           SL_ATR_Mult                        = 2.2;
input double           TP_ATR_Mult                        = 2.2;

input bool             ATR_Filter_Enable                  = true;
input int              ATR_Filter_Period                  = 14;
input int              ATR_MA_Period                      = 20;
input double           ATR_ThresholdK                     = 1.0;

input bool             ChopFilter_Enable                  = true;
input int              FlipCount_WindowBars               = 40;
input int              MaxFlipsAllowed                    = 2;

input bool             Session_Enable                     = true;
input string           Session1                           = "07:00-12:00";
input string           Session2                           = "13:00-20:00";
input bool             AvoidRollover_Enable               = true;
input string           AvoidRollover                      = "23:00-00:30";

input bool             BreakEven_Enable                   = true;
input double           BreakEven_TriggerR                 = 1.0;
input double           BreakEven_BufferPips               = 0.2;

input bool             Trailing_Enable                    = true;
input TrailingMode     Trailing_Mode                      = ST_FAST;
input bool             Trail_OnlyAfterBE                  = true;

input bool             ExitOnFastFlip                     = true;
input bool             ExitOnH4TrendFlip                  = true;

input bool             EnableCSVLog                       = true;
input string           LogFileName                        = "EA_SuperTrend_SwingIntraday_Log.csv";

//--- constants
const int              MAX_RETRIES                        = 3;
const int              RETRY_DELAY_MS                     = 250;
const int              ATR_EXTRA_BARS                     = 200;

//--- structures
struct SymbolState
  {
   string   name;
   datetime lastEntryBarTime;
   int      tradesToday;
   datetime tradeDay;
  };

struct SuperTrendResult
  {
   double value;
   int    direction; // 1 = uptrend, -1 = downtrend
  };

//--- globals
CTrade        g_trade;
SymbolState   g_symbols[];
double        g_dayStartEquity = 0.0;
datetime      g_dayAnchor      = 0;
bool          g_stopTradingToday = false;
int           g_lastLogDay = -1;

//--- helpers forward declarations
bool   ParseSymbols();
bool   EnsureSymbol(const string symbol);
bool   IsNewBar(SymbolState &state, ENUM_TIMEFRAMES timeframe);
double GetPipSize(const string symbol);
string GetGroupForSymbol(const string symbol);
bool   CalcATR(const string symbol, ENUM_TIMEFRAMES tf, const int period, const int shift, double &value);
bool   CalcSuperTrend(const string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, double mult, int shift, SuperTrendResult &result);
bool   CalcSuperTrendWithPrev(const string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, double mult, int shift, SuperTrendResult &current, SuperTrendResult &previous);
int    CountFlipsSTFast(const string symbol, ENUM_TIMEFRAMES tf, int windowBars, int atrPeriod, double mult);
bool   InSession(const string timeRange, datetime serverTime);
bool   CheckSessions(datetime serverTime);
bool   CheckAvoidRollover(datetime serverTime);
bool   CheckFilters(const string symbol, double atrH1, double atrMa, int flipCount, double spreadPips, int stFastDir, int stFastPrevDir);
bool   GetATRMA(const string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, int maPeriod, int shift, double &atrValue, double &atrMa);
double GetSpreadInPips(const string symbol, double pip);
bool   CalcStops(const string symbol, bool isBuy, double entryPrice, double stSlowH1, double stFastH1, double atrH1, double pip, double &sl, double &tp, double &slDistance);
bool   AdjustStopsForLevels(const string symbol, bool isBuy, double &sl, double &tp, double pip);
double CalcLot(const string symbol, double entryPrice, double slPrice, double riskPct);
bool   OpenTrade(const string symbol, bool isBuy, double entryPrice, double sl, double tp, double volume);
int    CountOpenPositionsTotal();
bool   HasOpenPosition(const string symbol);
bool   HasOppositePosition(const string symbol, bool isBuy);
void   ManagePositions();
void   EvaluateSymbol(SymbolState &state);
void   LogEvent(const string symbol, const string action, const string reason, double entry, double sl, double tp, double lots, double spread, double atrH1, double stFast, double stSlow, int trendH4);
void   EnsureLogHeader();
void   ResetDailyStateIfNeeded();
bool   IsMetalsSymbol(const string symbol);
double GetMaxSpreadSetting(const string symbol);
double GetSLBufferPips(const string symbol);
datetime DateOf(datetime t);

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetExpertMagicNumber((int)MagicNumber);
   g_trade.SetDeviationInPoints(20);

   if(!ParseSymbols())
      return(INIT_FAILED);

   g_dayAnchor      = DateOf(TimeCurrent());
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_stopTradingToday = false;
   g_lastLogDay     = -1;

   if(EnableCSVLog)
      EnsureLogHeader();

   PrintFormat("SuperTrendSwingIntradayEA initialized. Tracking %d symbols.", ArraySize(g_symbols));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("SuperTrendSwingIntradayEA deinitialized");
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   ResetDailyStateIfNeeded();
   ManagePositions();

   for(int i=0; i<ArraySize(g_symbols); ++i)
     {
      EvaluateSymbol(g_symbols[i]);
     }
  }

//+------------------------------------------------------------------+
//| Parse user-defined symbols                                       |
//+------------------------------------------------------------------+
bool ParseSymbols()
  {
   ArrayFree(g_symbols);
   string cleaned = Symbols;
   StringReplace(cleaned, " ", "");
   string parts[];
   int count = StringSplit(cleaned, ',', parts);
   for(int i=0; i<count; ++i)
     {
      if(parts[i] == "")
         continue;
      ArrayResize(g_symbols, ArraySize(g_symbols)+1);
      int idx = ArraySize(g_symbols)-1;
      g_symbols[idx].name            = parts[i];
      g_symbols[idx].lastEntryBarTime= 0;
      g_symbols[idx].tradesToday     = 0;
      g_symbols[idx].tradeDay        = 0;
     }

   if(ArraySize(g_symbols) == 0)
     {
      Print("No valid symbols found in input list.");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Ensure symbol is selected                                        |
//+------------------------------------------------------------------+
bool EnsureSymbol(const string symbol)
  {
   if(SymbolInfoInteger(symbol, SYMBOL_SELECT))
      return(true);
   return(SymbolSelect(symbol, true));
  }

//+------------------------------------------------------------------+
//| New bar detection on EntryTF                                     |
//+------------------------------------------------------------------+
bool IsNewBar(SymbolState &state, ENUM_TIMEFRAMES timeframe)
  {
   datetime times[];
   if(CopyTime(state.name, timeframe, 1, 1, times) != 1)
      return(false);

   if(times[0] != state.lastEntryBarTime)
     {
      state.lastEntryBarTime = times[0];
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Pip size helper                                                  |
//+------------------------------------------------------------------+
double GetPipSize(const string symbol)
  {
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pip    = (digits == 3 || digits == 5) ? 10.0 * point : point;
   return(pip);
  }

//+------------------------------------------------------------------+
//| Determine instrument group                                       |
//+------------------------------------------------------------------+
string GetGroupForSymbol(const string symbol)
  {
   string upper = StringUpper(symbol);
   if(StringFind(upper, "XAU") != -1)
      return("XAU");
   if(StringFind(upper, "XAG") != -1)
      return("XAG");
   if(StringFind(upper, "JPY") != -1)
      return("JPY");
   return("FOREX");
  }

//+------------------------------------------------------------------+
//| ATR calculation                                                  |
//+------------------------------------------------------------------+
bool CalcATR(const string symbol, ENUM_TIMEFRAMES tf, const int period, const int shift, double &value)
  {
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE)
      return(false);

   double buffer[];
   int copied = CopyBuffer(handle, 0, shift, 1, buffer);
   IndicatorRelease(handle);
   if(copied != 1)
      return(false);

   value = buffer[0];
   return(true);
  }

//+------------------------------------------------------------------+
//| SuperTrend calculation                                           |
//+------------------------------------------------------------------+
bool CalcSuperTrend(const string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, double mult, int shift, SuperTrendResult &result)
  {
   int barsNeeded = atrPeriod + ATR_EXTRA_BARS + shift + 5;
   MqlRates rates[];
   int bars = CopyRates(symbol, tf, 0, barsNeeded, rates);
   if(bars <= atrPeriod + shift + 5)
      return(false);

   ArraySetAsSeries(rates, false);

   int atrHandle = iATR(symbol, tf, atrPeriod);
   if(atrHandle == INVALID_HANDLE)
      return(false);

   double atrBuffer[];
   if(CopyBuffer(atrHandle, 0, 0, bars, atrBuffer) != bars)
     {
      IndicatorRelease(atrHandle);
      return(false);
     }
   IndicatorRelease(atrHandle);

   ArraySetAsSeries(atrBuffer, false);

   double basicUpper[], basicLower[], finalUpper[], finalLower[];
   ArrayResize(basicUpper, bars);
   ArrayResize(basicLower, bars);
   ArrayResize(finalUpper, bars);
   ArrayResize(finalLower, bars);
   double stValue[];
   int trend[];
   ArrayResize(stValue, bars);
   ArrayResize(trend, bars);

   for(int i=0; i<bars; ++i)
     {
      double hl2 = (rates[i].high + rates[i].low) * 0.5;
      basicUpper[i] = hl2 + mult * atrBuffer[i];
      basicLower[i] = hl2 - mult * atrBuffer[i];
     }

   for(int i=0; i<bars; ++i)
     {
      if(i == 0)
        {
         finalUpper[i] = basicUpper[i];
         finalLower[i] = basicLower[i];
         trend[i]      = 1;
         stValue[i]    = finalLower[i];
         continue;
        }

      finalUpper[i] = (basicUpper[i] < finalUpper[i-1] || rates[i-1].close > finalUpper[i-1]) ? basicUpper[i] : finalUpper[i-1];
      finalLower[i] = (basicLower[i] > finalLower[i-1] || rates[i-1].close < finalLower[i-1]) ? basicLower[i] : finalLower[i-1];

      if(trend[i-1] == 1)
        {
         if(rates[i].close < finalLower[i])
            trend[i] = -1;
         else
            trend[i] = 1;
        }
      else
        {
         if(rates[i].close > finalUpper[i])
            trend[i] = 1;
         else
            trend[i] = -1;
        }

      stValue[i] = (trend[i] == 1) ? finalLower[i] : finalUpper[i];
     }

   int idx = bars - 1 - shift;
   if(idx < 0 || idx >= bars)
      return(false);

   result.value     = stValue[idx];
   result.direction = trend[idx];
   return(true);
  }

//+------------------------------------------------------------------+
//| SuperTrend with previous direction                               |
//+------------------------------------------------------------------+
bool CalcSuperTrendWithPrev(const string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, double mult, int shift, SuperTrendResult &current, SuperTrendResult &previous)
  {
   SuperTrendResult cur, prev;
   if(!CalcSuperTrend(symbol, tf, atrPeriod, mult, shift, cur))
      return(false);
   if(!CalcSuperTrend(symbol, tf, atrPeriod, mult, shift+1, prev))
      return(false);
   current  = cur;
   previous = prev;
   return(true);
  }

//+------------------------------------------------------------------+
//| Count SuperTrend fast flips                                      |
//+------------------------------------------------------------------+
int CountFlipsSTFast(const string symbol, ENUM_TIMEFRAMES tf, int windowBars, int atrPeriod, double mult)
  {
   int barsNeeded = MathMax(windowBars + 5, atrPeriod + ATR_EXTRA_BARS);
   MqlRates rates[];
   int bars = CopyRates(symbol, tf, 0, barsNeeded, rates);
   if(bars <= windowBars + 2)
      return(0);

   ArraySetAsSeries(rates, false);

   int atrHandle = iATR(symbol, tf, atrPeriod);
   if(atrHandle == INVALID_HANDLE)
      return(0);

   double atrBuffer[];
   if(CopyBuffer(atrHandle, 0, 0, bars, atrBuffer) != bars)
     {
      IndicatorRelease(atrHandle);
      return(0);
     }
   IndicatorRelease(atrHandle);
   ArraySetAsSeries(atrBuffer, false);

   double basicUpper[], basicLower[], finalUpper[], finalLower[];
   ArrayResize(basicUpper, bars);
   ArrayResize(basicLower, bars);
   ArrayResize(finalUpper, bars);
   ArrayResize(finalLower, bars);
   int trend[];
   ArrayResize(trend, bars);

   for(int i=0; i<bars; ++i)
     {
      double hl2 = (rates[i].high + rates[i].low) * 0.5;
      basicUpper[i] = hl2 + mult * atrBuffer[i];
      basicLower[i] = hl2 - mult * atrBuffer[i];
     }

   for(int i=0; i<bars; ++i)
     {
      if(i == 0)
        {
         finalUpper[i] = basicUpper[i];
         finalLower[i] = basicLower[i];
         trend[i]      = 1;
         continue;
        }
      finalUpper[i] = (basicUpper[i] < finalUpper[i-1] || rates[i-1].close > finalUpper[i-1]) ? basicUpper[i] : finalUpper[i-1];
      finalLower[i] = (basicLower[i] > finalLower[i-1] || rates[i-1].close < finalLower[i-1]) ? basicLower[i] : finalLower[i-1];

      if(trend[i-1] == 1)
         trend[i] = (rates[i].close < finalLower[i]) ? -1 : 1;
      else
         trend[i] = (rates[i].close > finalUpper[i]) ? 1 : -1;
     }

   int flips = 0;
   int startIdx = bars - windowBars - 1;
   if(startIdx < 1)
      startIdx = 1;
   for(int i=startIdx; i<bars; ++i)
     {
      if(trend[i] != trend[i-1])
         ++flips;
     }
   return(flips);
  }

//+------------------------------------------------------------------+
//| Session check                                                    |
//+------------------------------------------------------------------+
bool InSession(const string timeRange, datetime serverTime)
  {
   if(timeRange == "")
      return(false);

   string parts[];
   if(StringSplit(timeRange, '-', parts) != 2)
      return(false);

   string startParts[];
   string endParts[];
   if(StringSplit(parts[0], ':', startParts) != 2)
      return(false);
   if(StringSplit(parts[1], ':', endParts) != 2)
      return(false);

   int startH = (int)StringToInteger(startParts[0]);
   int startM = (int)StringToInteger(startParts[1]);
   int endH   = (int)StringToInteger(endParts[0]);
   int endM   = (int)StringToInteger(endParts[1]);

   int currentMinutes = TimeHour(serverTime) * 60 + TimeMinute(serverTime);
   int startMinutes   = startH * 60 + startM;
   int endMinutes     = endH * 60 + endM;

   if(startMinutes <= endMinutes)
      return(currentMinutes >= startMinutes && currentMinutes <= endMinutes);

   // overnight range
   return(currentMinutes >= startMinutes || currentMinutes <= endMinutes);
  }

bool CheckSessions(datetime serverTime)
  {
   if(!Session_Enable)
      return(true);
   return(InSession(Session1, serverTime) || InSession(Session2, serverTime));
  }

bool CheckAvoidRollover(datetime serverTime)
  {
   if(!AvoidRollover_Enable)
      return(true);
   return(!InSession(AvoidRollover, serverTime));
  }

//+------------------------------------------------------------------+
//| ATR filter helper                                                |
//+------------------------------------------------------------------+
bool GetATRMA(const string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, int maPeriod, int shift, double &atrValue, double &atrMa)
  {
   int handle = iATR(symbol, tf, atrPeriod);
   if(handle == INVALID_HANDLE)
      return(false);

   int barsNeeded = maPeriod + shift + 2;
   double atrBuffer[];
   if(CopyBuffer(handle, 0, shift, barsNeeded, atrBuffer) != barsNeeded)
     {
      IndicatorRelease(handle);
      return(false);
     }
   IndicatorRelease(handle);

   double sum = 0.0;
   for(int i=0; i<maPeriod; ++i)
      sum += atrBuffer[i];

   atrValue = atrBuffer[0];
   atrMa    = sum / maPeriod;
   return(true);
  }

//+------------------------------------------------------------------+
//| Spread in pips                                                   |
//+------------------------------------------------------------------+
double GetSpreadInPips(const string symbol, double pip)
  {
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return(1000.0);
   return((ask - bid) / pip);
  }

//+------------------------------------------------------------------+
//| Filters                                                          |
//+------------------------------------------------------------------+
bool CheckFilters(const string symbol, double atrH1, double atrMa, int flipCount, double spreadPips, int stFastDir, int stFastPrevDir)
  {
   (void)stFastDir;
   (void)stFastPrevDir;

   datetime now = TimeCurrent();
   if(!CheckSessions(now))
      return(false);
   if(!CheckAvoidRollover(now))
      return(false);

   double maxSpread = GetMaxSpreadSetting(symbol);
   if(spreadPips > maxSpread)
      return(false);

   if(ATR_Filter_Enable && atrH1 < atrMa * ATR_ThresholdK)
      return(false);

   if(ChopFilter_Enable && flipCount > MaxFlipsAllowed)
      return(false);

   // Flip detection done at evaluation level using directions
   return(true);
  }

//+------------------------------------------------------------------+
//| Stops calculation                                                |
//+------------------------------------------------------------------+
bool CalcStops(const string symbol, bool isBuy, double entryPrice, double stSlowH1, double stFastH1, double atrH1, double pip, double &sl, double &tp, double &slDistance)
  {
   double bufferPips = GetSLBufferPips(symbol);
   double bufferPrice = bufferPips * pip;

   if(StopLossMode == ST_BASED)
     {
      double ref = isBuy ? MathMin(stSlowH1, stFastH1) : MathMax(stSlowH1, stFastH1);
      sl = isBuy ? ref - bufferPrice : ref + bufferPrice;
     }
   else
     {
      double distance = atrH1 * SL_ATR_Mult;
      sl = isBuy ? entryPrice - distance : entryPrice + distance;
     }

   slDistance = MathAbs(entryPrice - sl);
   if(slDistance <= 0.0)
      return(false);

   double tpDistance = 0.0;
   if(TakeProfitMode == RR)
      tpDistance = slDistance * TakeProfitRR;
   else
      tpDistance = atrH1 * TP_ATR_Mult;

   tp = isBuy ? entryPrice + tpDistance : entryPrice - tpDistance;
   return(AdjustStopsForLevels(symbol, isBuy, sl, tp, pip));
  }

//+------------------------------------------------------------------+
//| Adjust stops for broker constraints                               |
//+------------------------------------------------------------------+
bool AdjustStopsForLevels(const string symbol, bool isBuy, double &sl, double &tp, double pip)
  {
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stopsLvl  = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freezeLvl = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   double minDist   = MathMax(stopsLvl, freezeLvl);

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return(false);

   double price = isBuy ? ask : bid;

   if(isBuy)
     {
      if((price - sl) < minDist)
         sl = price - (minDist + 2 * pip);
      if((tp - price) < minDist)
         tp = price + (minDist + 2 * pip);
     }
   else
     {
      if((sl - price) < minDist)
         sl = price + (minDist + 2 * pip);
      if((price - tp) < minDist)
         tp = price - (minDist + 2 * pip);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Position sizing                                                  |
//+------------------------------------------------------------------+
double CalcLot(const string symbol, double entryPrice, double slPrice, double riskPct)
  {
   double riskMoney  = AccountInfoDouble(ACCOUNT_EQUITY) * riskPct * 0.01;
   double tickSize   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double volumeMin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double volumeMax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   int    volDigits  = (int)SymbolInfoInteger(symbol, SYMBOL_VOLUME_DIGITS);

   if(tickSize <= 0.0 || tickValue <= 0.0)
      return(0.0);

   double slDistance = MathAbs(entryPrice - slPrice);
   if(slDistance <= 0.0)
      return(0.0);

   double stopTicks = slDistance / tickSize;
   double rawVolume = riskMoney / (stopTicks * tickValue);

   rawVolume = MathMax(volumeMin, MathMin(volumeMax, rawVolume));
   rawVolume = MathFloor(rawVolume / volumeStep) * volumeStep;
   return(NormalizeDouble(rawVolume, volDigits));
  }

//+------------------------------------------------------------------+
//| Trade opener                                                     |
//+------------------------------------------------------------------+
bool OpenTrade(const string symbol, bool isBuy, double entryPrice, double sl, double tp, double volume)
  {
   double margin = 0.0;
   if(!OrderCalcMargin(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, symbol, volume, entryPrice, margin))
     {
      PrintFormat("OrderCalcMargin failed on %s", symbol);
      return(false);
     }
   if(margin > AccountInfoDouble(ACCOUNT_FREEMARGIN))
     {
      PrintFormat("Not enough margin for %s", symbol);
      return(false);
     }

   bool success = false;
   for(int attempt=0; attempt<MAX_RETRIES && !success; ++attempt)
     {
      if(isBuy)
         success = g_trade.Buy(volume, symbol, entryPrice, sl, tp, "STSI_BUY");
      else
         success = g_trade.Sell(volume, symbol, entryPrice, sl, tp, "STSI_SELL");

      if(!success)
        {
         int err = GetLastError();
         if(err == TRADE_RETCODE_REQUOTE || err == TRADE_RETCODE_REJECT || err == TRADE_RETCODE_TRADE_CONTEXT_BUSY)
            Sleep(RETRY_DELAY_MS);
         else
            break;
        }
     }
   return(success);
  }

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositionsTotal()
  {
   int total = 0;
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionSelectByIndex(i))
        {
         if((long)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            ++total;
        }
     }
   return(total);
  }

//+------------------------------------------------------------------+
//| Check open position by symbol                                    |
//+------------------------------------------------------------------+
bool HasOpenPosition(const string symbol)
  {
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionSelectByIndex(i))
        {
         if(PositionGetString(POSITION_SYMBOL) == symbol && (long)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            return(true);
        }
     }
   return(false);
  }

bool HasOppositePosition(const string symbol, bool isBuy)
  {
   for(int i=0; i<PositionsTotal(); ++i)
     {
      if(PositionSelectByIndex(i))
        {
         if(PositionGetString(POSITION_SYMBOL) == symbol && (long)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if((isBuy && type == POSITION_TYPE_SELL) || (!isBuy && type == POSITION_TYPE_BUY))
               return(true);
           }
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Daily reset                                                      |
//+------------------------------------------------------------------+
void ResetDailyStateIfNeeded()
  {
   datetime now = TimeCurrent();
   datetime today = DateOf(now);
   if(today != g_dayAnchor)
     {
      g_dayAnchor      = today;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_stopTradingToday = false;
      for(int i=0; i<ArraySize(g_symbols); ++i)
        {
         g_symbols[i].tradesToday = 0;
         g_symbols[i].tradeDay    = today;
        }
     }

   double dd = 0.0;
   if(g_dayStartEquity > 0.0)
      dd = (g_dayStartEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / g_dayStartEquity * 100.0;
   if(dd >= DailyLossLimitPercent)
      g_stopTradingToday = true;
  }

//+------------------------------------------------------------------+
//| Check if symbol is in metals preset                              |
//+------------------------------------------------------------------+
bool IsMetalsSymbol(const string symbol)
  {
   if(!UseMetalsPreset)
      return(false);
   string cleaned = MetalsSymbols;
   StringReplace(cleaned, " ", "");
   string parts[];
   int cnt = StringSplit(cleaned, ',', parts);
   for(int i=0; i<cnt; ++i)
     {
      if(StringUpper(parts[i]) == StringUpper(symbol))
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Spread & buffer settings                                         |
//+------------------------------------------------------------------+
double GetMaxSpreadSetting(const string symbol)
  {
   string group = GetGroupForSymbol(symbol);
   if(group == "JPY")
      return(MaxSpreadPips_JPY);
   if(group == "XAU")
      return(MaxSpreadPips_XAU);
   if(group == "XAG")
      return(MaxSpreadPips_XAG);
   return(MaxSpreadPips_Forex);
  }

double GetSLBufferPips(const string symbol)
  {
   string group = GetGroupForSymbol(symbol);
   if(group == "JPY")
      return(SL_BufferPips_JPY);
   if(group == "XAU")
      return(SL_BufferPips_XAU);
   if(group == "XAG")
      return(SL_BufferPips_XAG);
   return(SL_BufferPips_Forex);
  }

//+------------------------------------------------------------------+
//| Evaluate entry logic                                             |
//+------------------------------------------------------------------+
void EvaluateSymbol(SymbolState &state)
  {
   string symbol = state.name;
   if(!EnsureSymbol(symbol))
      return;

   if(!IsNewBar(state, EntryTF))
      return;

   if(g_stopTradingToday)
      return;

   if(CountOpenPositionsTotal() >= MaxOpenPositionsTotal)
      return;

   datetime today = DateOf(TimeCurrent());
   if(state.tradeDay != today)
     {
      state.tradeDay    = today;
      state.tradesToday = 0;
     }

   if(state.tradesToday >= MaxTradesPerDayPerSymbol)
      return;

   double pip = GetPipSize(symbol);
   double spreadPips = GetSpreadInPips(symbol, pip);

   double atrH1, atrMa;
   if(!GetATRMA(symbol, EntryTF, ATR_Filter_Period, ATR_MA_Period, 1, atrH1, atrMa))
      return;

   double atrEntry;
   if(!CalcATR(symbol, EntryTF, ATR_Filter_Period, 1, atrEntry))
      return;

   double stSlowMult = IsMetalsSymbol(symbol) ? Metals_ST_Slow_Mult : ST_Slow_Mult;
   double stFastMult = IsMetalsSymbol(symbol) ? Metals_ST_Fast_Mult : ST_Fast_Mult;

   SuperTrendResult stSlowH4, stSlowH4Prev, stSlowH1, stSlowH1Prev, stFastH1, stFastPrev;
   if(!CalcSuperTrendWithPrev(symbol, TrendTF, ST_Slow_ATR, stSlowMult, 1, stSlowH4, stSlowH4Prev))
      return;
   if(!CalcSuperTrendWithPrev(symbol, EntryTF, ST_Slow_ATR, stSlowMult, 1, stSlowH1, stSlowH1Prev))
      return;
   if(!CalcSuperTrendWithPrev(symbol, EntryTF, ST_Fast_ATR, stFastMult, 1, stFastH1, stFastPrev))
      return;

   int flipCount = CountFlipsSTFast(symbol, EntryTF, FlipCount_WindowBars, ST_Fast_ATR, stFastMult);
   if(!CheckFilters(symbol, atrH1, atrMa, flipCount, spreadPips, stFastH1.direction, stFastPrev.direction))
      return;

   if(OnePositionPerSymbol && HasOpenPosition(symbol))
      return;
   if(!AllowHedgingSameSymbol && HasOppositePosition(symbol, stFastH1.direction == 1))
      return;

   MqlRates rates[];
   if(CopyRates(symbol, EntryTF, 0, 3, rates) < 3)
      return;
   ArraySetAsSeries(rates, true);
   double lastClose = rates[1].close;

   bool flipUp   = (stFastPrev.direction == -1 && stFastH1.direction == 1 && lastClose > stFastH1.value);
   bool flipDown = (stFastPrev.direction == 1 && stFastH1.direction == -1 && lastClose < stFastH1.value);

   bool allowBuy = (stSlowH4.direction == 1 && stSlowH1.direction == 1 && flipUp);
   bool allowSell= (stSlowH4.direction == -1 && stSlowH1.direction == -1 && flipDown);

   if(!allowBuy && !allowSell)
      return;

   double entryPrice = allowBuy ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   double sl, tp, slDistance;
   if(!CalcStops(symbol, allowBuy, entryPrice, stSlowH1.value, stFastH1.value, atrEntry, pip, sl, tp, slDistance))
      return;

   double volume = CalcLot(symbol, entryPrice, sl, RiskPercent);
   if(volume <= 0.0)
      return;

   if(OpenTrade(symbol, allowBuy, entryPrice, sl, tp, volume))
     {
      state.tradesToday++;
      LogEvent(symbol, allowBuy ? "OPEN_BUY" : "OPEN_SELL", "entry_signal", entryPrice, sl, tp, volume, spreadPips, atrEntry, stFastH1.value, stSlowH1.value, stSlowH4.direction);
     }
  }

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      if(!PositionSelectByIndex(i))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isBuy = (type == POSITION_TYPE_BUY);

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double volume= PositionGetDouble(POSITION_VOLUME);
      double pip   = GetPipSize(symbol);

      double price = isBuy ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double riskDistance = isBuy ? (entry - sl) : (sl - entry);
      if(riskDistance <= 0.0)
         continue;

      double currentGain = isBuy ? (price - entry) : (entry - price);
      double rMultiple   = currentGain / riskDistance;

      SuperTrendResult stFast, stFastPrev, stSlowH4;
      double atrH1;
      if(!CalcSuperTrendWithPrev(symbol, EntryTF, ST_Fast_ATR, IsMetalsSymbol(symbol) ? Metals_ST_Fast_Mult : ST_Fast_Mult, 1, stFast, stFastPrev))
         continue;
      if(!CalcSuperTrend(symbol, TrendTF, ST_Slow_ATR, IsMetalsSymbol(symbol) ? Metals_ST_Slow_Mult : ST_Slow_Mult, 1, stSlowH4))
         continue;
      if(!CalcATR(symbol, EntryTF, ATR_Filter_Period, 1, atrH1))
         continue;

      bool modified = false;
      double newSL = sl;
      double newTP = tp;

      // Break-even
      if(BreakEven_Enable && rMultiple >= BreakEven_TriggerR)
        {
         double beBuffer = BreakEven_BufferPips * pip;
         double beSL = isBuy ? entry + beBuffer : entry - beBuffer;
         if(isBuy && beSL > newSL)
           {
            newSL = beSL;
            modified = true;
            LogEvent(symbol, "MOVE_BE", "break_even", entry, newSL, tp, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
           }
         else if(!isBuy && beSL < newSL)
           {
            newSL = beSL;
            modified = true;
            LogEvent(symbol, "MOVE_BE", "break_even", entry, newSL, tp, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
           }
        }

      bool beReached = (isBuy ? (newSL >= entry - pip * 0.1) : (newSL <= entry + pip * 0.1));

      // Trailing
      if(Trailing_Enable && (!Trail_OnlyAfterBE || beReached))
        {
         if(Trailing_Mode == ST_FAST)
           {
            double trailSL = isBuy ? stFast.value - GetSLBufferPips(symbol) * pip : stFast.value + GetSLBufferPips(symbol) * pip;
            if(isBuy && trailSL > newSL)
              {
               newSL = trailSL;
               modified = true;
               LogEvent(symbol, "TRAIL_ST", "st_fast_trailing", entry, newSL, tp, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
              }
            else if(!isBuy && trailSL < newSL)
              {
               newSL = trailSL;
               modified = true;
               LogEvent(symbol, "TRAIL_ST", "st_fast_trailing", entry, newSL, tp, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
              }
           }
         else
           {
            double distance = atrH1 * SL_ATR_Mult;
            double trailSL = isBuy ? price - distance : price + distance;
            if(isBuy && trailSL > newSL)
              {
               newSL = trailSL;
               modified = true;
               LogEvent(symbol, "TRAIL_ATR", "atr_trailing", entry, newSL, tp, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
              }
            else if(!isBuy && trailSL < newSL)
              {
               newSL = trailSL;
               modified = true;
               LogEvent(symbol, "TRAIL_ATR", "atr_trailing", entry, newSL, tp, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
              }
           }
        }

      // Exit conditions
      bool closeNow = false;
      if(ExitOnFastFlip)
        {
         if(isBuy && stFast.direction == -1 && stFastPrev.direction == 1)
            closeNow = true;
         if(!isBuy && stFast.direction == 1 && stFastPrev.direction == -1)
            closeNow = true;
        }

      if(ExitOnH4TrendFlip)
        {
         if(isBuy && stSlowH4.direction == -1)
            closeNow = true;
         if(!isBuy && stSlowH4.direction == 1)
            closeNow = true;
        }

      if(closeNow)
        {
         g_trade.PositionClose(symbol);
         LogEvent(symbol, "CLOSE_EXIT", "trend_flip", entry, newSL, newTP, volume, GetSpreadInPips(symbol, pip), atrH1, stFast.value, 0.0, stSlowH4.direction);
         continue;
        }

      if(modified)
        {
         if(!AdjustStopsForLevels(symbol, isBuy, newSL, newTP, pip))
            continue;
         g_trade.PositionModify(symbol, newSL, newTP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void EnsureLogHeader()
  {
   if(!EnableCSVLog)
      return;
   if(FileIsExist(LogFileName, FILE_COMMON))
      return;
   int handle = FileOpen(LogFileName, FILE_COMMON|FILE_WRITE|FILE_CSV|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;
   FileWrite(handle, "time","symbol","action","reason","entry","sl","tp","lots","spread_pips","atrH1","stFast","stSlow","trendH4","equity","balance");
   FileClose(handle);
  }

void LogEvent(const string symbol, const string action, const string reason, double entry, double sl, double tp, double lots, double spread, double atrH1, double stFast, double stSlow, int trendH4)
  {
   if(!EnableCSVLog)
      return;

   int flags = FILE_COMMON|FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_APPEND;
   int handle = FileOpen(LogFileName, flags);
   if(handle == INVALID_HANDLE)
      return;

   datetime now = TimeCurrent();
   if(TimeDay(now) != g_lastLogDay)
      g_lastLogDay = TimeDay(now);

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, TimeToString(now, TIME_DATE|TIME_SECONDS), symbol, action, reason,
             DoubleToString(entry, _Digits), DoubleToString(sl, _Digits), DoubleToString(tp, _Digits),
             DoubleToString(lots, 2), DoubleToString(spread, 1), DoubleToString(atrH1, 5),
             DoubleToString(stFast, 5), DoubleToString(stSlow, 5), trendH4,
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Utility                                                          |
//+------------------------------------------------------------------+
datetime DateOf(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = dt.min = dt.sec = 0;
   return(StructToTime(dt));
  }

//+------------------------------------------------------------------+
//| End of file                                                      |
//+------------------------------------------------------------------+
