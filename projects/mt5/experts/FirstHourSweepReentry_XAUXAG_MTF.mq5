//+------------------------------------------------------------------+
//| FirstHourSweepReentry_XAUXAG_MTF.mq5                              |
//| README: Trades XAUUSD/XAGUSD mean-reversion using the first-hour  |
//| server-time range (00:00-01:00). The range is only valid after    |
//| the 00:00 H1 candle closes. Backtest with "Every tick based on    |
//| real ticks" and confirm timeframe M15. Day boundaries follow      |
//| server time, including any broker time shifts.                   |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>

enum LotMode
{
   LotModeFixedLot,
   LotModeRiskPercent
};

enum TPMode
{
   MidRange,
   OppositeEdge,
   FixedRR
};

enum RunnerTPMode
{
   DailyOpen,
   RunnerTP_RR2,
   RunnerTP_None
};

enum SweepState
{
   SWEEP_NONE,
   SWEEP_UP,
   SWEEP_DOWN
};

// Inputs
input string SymbolsList = "XAUUSD,XAGUSD";
input bool IncludeChartSymbol = true;
input ENUM_TIMEFRAMES ConfirmTF = PERIOD_M15;
input int MagicNumber = 26012201;
input bool VerboseLog = true;

input int EntryStartHour = 1;
input int EntryStartMinute = 5;
input int EntryEndHour = 23;
input int EntryEndMinute = 50;

input LotMode lotMode = LotModeRiskPercent;
input double FixedLot = 0.01;
input double RiskPercent = 1.0;
input double MinLot = 0.01;
input double MaxLot = 10.0;

input bool UseTP = true;
input TPMode tpMode = MidRange;
input double RR = 1.2;

input bool UsePartial = false;
input double PartialPercent = 60.0;
input bool MoveSLToBE_AfterPartial = true;
input RunnerTPMode runnerMode = DailyOpen;
input double RR2 = 2.0;

input bool UseBreakeven = true;
input int BE_TriggerPoints = 120;
input int BE_LockPoints = 10;

input bool OneTradePerDay = true;
input int CooldownBarsAfterTrade = 8;
input int MaxConfirmBars = 12;
input bool UseADXFilter = true;
input ENUM_TIMEFRAMES ADX_TF = PERIOD_H1;
input int ADXPeriod = 14;
input double ADX_TrendThreshold = 28.0;
input bool UseYesterdayBreakoutFilter = true;
input int YesterdayBreakoutPoints = 120;
input bool UseWickFilter = true;
input double MinWickRatio = 0.45;

input int MaxDeviationPoints = 30;
input int MinSLPoints = 80;

input int Default_SweepBufferPoints = 30;
input int Default_ConfirmInsidePoints = 0;
input int Default_SL_BufferPoints = 60;
input int Default_FallbackSLPoints = 120;
input int Default_MaxSpreadPoints = 60;
input int Default_MinRangePoints = 150;
input int Default_MaxRangePoints = 2000;
input int Default_MinSweepDistancePoints = 60;

input int XAU_SweepBufferPoints = 40;
input int XAU_ConfirmInsidePoints = 10;
input int XAU_SL_BufferPoints = 90;
input int XAU_FallbackSLPoints = 180;
input int XAU_MaxSpreadPoints = 90;
input int XAU_MinRangePoints = 250;
input int XAU_MaxRangePoints = 3500;
input int XAU_MinSweepDistancePoints = 120;

input int XAG_SweepBufferPoints = 25;
input int XAG_ConfirmInsidePoints = 6;
input int XAG_SL_BufferPoints = 60;
input int XAG_FallbackSLPoints = 140;
input int XAG_MaxSpreadPoints = 80;
input int XAG_MinRangePoints = 120;
input int XAG_MaxRangePoints = 2500;
input int XAG_MinSweepDistancePoints = 80;

struct SymbolParams
{
   int sweepBufferPoints;
   int confirmInsidePoints;
   int slBufferPoints;
   int fallbackSLPoints;
   int maxSpreadPoints;
   int minRangePoints;
   int maxRangePoints;
   int minSweepDistancePoints;
};

struct SymbolState
{
   string symbol;
   int dayKey;
   bool rangeReady;
   double rangeHigh;
   double rangeLow;
   double rangeMid;
   double rangeSizePoints;
   bool tradedToday;
   SweepState sweepState;
   datetime sweepStartTime;
   int confirmBarsSinceSweep;
   double sweepExtremeHigh;
   double sweepExtremeLow;
   datetime lastProcessedConfirmBarCloseTime;
   datetime lastDayResetTime;
   bool skipDay;
   int confirmBarsSinceTrade;
   ulong positionTicket;
   double initialVolume;
   bool partialDone;
   bool beDone;
   int adxHandle;
};

CTrade trade;
SymbolState states[];

int GetDayKey(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

datetime DayStart(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

bool IsInEntryWindow(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int minutes = dt.hour * 60 + dt.min;
   int startMinutes = EntryStartHour * 60 + EntryStartMinute;
   int endMinutes = EntryEndHour * 60 + EntryEndMinute;
   return (minutes >= startMinutes && minutes <= endMinutes);
}

void Log(string message)
{
   if(VerboseLog)
      Print(message);
}

SymbolParams GetParamsForSymbol(const string symbol)
{
   string upper = symbol;
   StringToUpper(upper);
   SymbolParams p;
   if(StringFind(upper, "XAU") >= 0)
   {
      p.sweepBufferPoints = XAU_SweepBufferPoints;
      p.confirmInsidePoints = XAU_ConfirmInsidePoints;
      p.slBufferPoints = XAU_SL_BufferPoints;
      p.fallbackSLPoints = XAU_FallbackSLPoints;
      p.maxSpreadPoints = XAU_MaxSpreadPoints;
      p.minRangePoints = XAU_MinRangePoints;
      p.maxRangePoints = XAU_MaxRangePoints;
      p.minSweepDistancePoints = XAU_MinSweepDistancePoints;
      return p;
   }
   if(StringFind(upper, "XAG") >= 0)
   {
      p.sweepBufferPoints = XAG_SweepBufferPoints;
      p.confirmInsidePoints = XAG_ConfirmInsidePoints;
      p.slBufferPoints = XAG_SL_BufferPoints;
      p.fallbackSLPoints = XAG_FallbackSLPoints;
      p.maxSpreadPoints = XAG_MaxSpreadPoints;
      p.minRangePoints = XAG_MinRangePoints;
      p.maxRangePoints = XAG_MaxRangePoints;
      p.minSweepDistancePoints = XAG_MinSweepDistancePoints;
      return p;
   }
   p.sweepBufferPoints = Default_SweepBufferPoints;
   p.confirmInsidePoints = Default_ConfirmInsidePoints;
   p.slBufferPoints = Default_SL_BufferPoints;
   p.fallbackSLPoints = Default_FallbackSLPoints;
   p.maxSpreadPoints = Default_MaxSpreadPoints;
   p.minRangePoints = Default_MinRangePoints;
   p.maxRangePoints = Default_MaxRangePoints;
   p.minSweepDistancePoints = Default_MinSweepDistancePoints;
   return p;
}

bool TradeAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;
   return true;
}

void ResetStateForDay(SymbolState &state, int newDayKey)
{
   state.dayKey = newDayKey;
   state.rangeReady = false;
   state.rangeHigh = 0.0;
   state.rangeLow = 0.0;
   state.rangeMid = 0.0;
   state.rangeSizePoints = 0.0;
   state.tradedToday = false;
   state.sweepState = SWEEP_NONE;
   state.sweepStartTime = 0;
   state.confirmBarsSinceSweep = 0;
   state.sweepExtremeHigh = 0.0;
   state.sweepExtremeLow = 0.0;
   state.lastProcessedConfirmBarCloseTime = 0;
   state.lastDayResetTime = TimeCurrent();
   state.skipDay = false;
   state.confirmBarsSinceTrade = 1000000;
   state.positionTicket = 0;
   state.initialVolume = 0.0;
   state.partialDone = false;
   state.beDone = false;
}

bool EnsureRange(SymbolState &state)
{
   datetime now = TimeCurrent();
   datetime dayStart = DayStart(now);
   if(now < dayStart + 3600)
      return false;

   MqlRates rates[];
   int copied = CopyRates(state.symbol, PERIOD_H1, dayStart, 1, rates);
   if(copied != 1)
   {
      Log(state.symbol + ": missing first-hour H1 bar, skipping day.");
      return false;
   }
   if(rates[0].time != dayStart)
   {
      Log(state.symbol + ": first-hour H1 bar time mismatch, skipping day.");
      return false;
   }
   state.rangeHigh = rates[0].high;
   state.rangeLow = rates[0].low;
   state.rangeMid = (state.rangeHigh + state.rangeLow) / 2.0;
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);
   state.rangeSizePoints = (state.rangeHigh - state.rangeLow) / point;
   state.rangeReady = true;
   Log(state.symbol + ": range ready H=" + DoubleToString(state.rangeHigh, (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS)) +
       " L=" + DoubleToString(state.rangeLow, (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS)) +
       " size=" + DoubleToString(state.rangeSizePoints, 1) + " points.");
   return true;
}

bool PassSpreadFilter(const SymbolState &state, const SymbolParams &params)
{
   int spread = (int)SymbolInfoInteger(state.symbol, SYMBOL_SPREAD);
   return spread <= params.maxSpreadPoints;
}

bool PassRangeFilter(const SymbolState &state, const SymbolParams &params)
{
   return (state.rangeSizePoints >= params.minRangePoints && state.rangeSizePoints <= params.maxRangePoints);
}

bool CheckADXFilter(SymbolState &state)
{
   if(!UseADXFilter)
      return true;
   if(state.adxHandle == INVALID_HANDLE)
   {
      Log(state.symbol + ": ADX handle invalid.");
      return false;
   }
   double buffer[];
   if(CopyBuffer(state.adxHandle, 0, 1, 1, buffer) != 1)
   {
      Log(state.symbol + ": ADX buffer unavailable.");
      return false;
   }
   if(buffer[0] >= ADX_TrendThreshold)
   {
      Log(state.symbol + ": ADX trend filter triggered, skipping day.");
      state.skipDay = true;
      return false;
   }
   return true;
}

bool CheckYesterdayBreakout(SymbolState &state)
{
   if(!UseYesterdayBreakoutFilter)
      return true;
   MqlRates rates[];
   if(CopyRates(state.symbol, PERIOD_D1, 1, 1, rates) != 1)
   {
      Log(state.symbol + ": missing yesterday D1 bar, skipping day.");
      state.skipDay = true;
      return false;
   }
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(state.symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(state.symbol, SYMBOL_ASK);
   if(ask > rates[0].high + YesterdayBreakoutPoints * point || bid < rates[0].low - YesterdayBreakoutPoints * point)
   {
      Log(state.symbol + ": yesterday breakout filter triggered, skipping day.");
      state.skipDay = true;
      return false;
   }
   return true;
}

bool GetConfirmBar(const SymbolState &state, MqlRates &confirmBar)
{
   MqlRates rates[];
   if(CopyRates(state.symbol, ConfirmTF, 0, 2, rates) != 2)
      return false;
   confirmBar = rates[1];
   return true;
}

bool PassWickFilter(const MqlRates &bar, bool forSell)
{
   if(!UseWickFilter)
      return true;
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return false;
   double upperWick = bar.high - MathMax(bar.open, bar.close);
   double lowerWick = MathMin(bar.open, bar.close) - bar.low;
   double ratio = forSell ? upperWick / range : lowerWick / range;
   return ratio >= MinWickRatio;
}

bool SelectPositionByIndex(const int index)
{
   ulong ticket = PositionGetTicket(index);
   if(ticket == 0)
      return false;
   return PositionSelectByTicket(ticket);
}

bool HasExistingPosition(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!SelectPositionByIndex(i))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      return true;
   }
   return false;
}

ulong GetExistingPositionTicket(const string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!SelectPositionByIndex(i))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      return (ulong)PositionGetInteger(POSITION_TICKET);
   }
   return 0;
}

void InitializeExistingPosition(SymbolState &state)
{
   ulong ticket = GetExistingPositionTicket(state.symbol);
   if(ticket == 0)
      return;
   if(!PositionSelectByTicket(ticket))
      return;
   state.positionTicket = ticket;
   state.initialVolume = PositionGetDouble(POSITION_VOLUME);
   state.partialDone = true;
   state.beDone = false;
   Log(state.symbol + ": existing position detected; partial close disabled for safety.");
}

bool ComputeSLTP(SymbolState &state, const SymbolParams &params, bool isBuy, double entryPrice, double &sl, double &tp, double &slDistancePoints)
{
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);
   double fallback = isBuy ? (state.rangeLow - params.fallbackSLPoints * point) : (state.rangeHigh + params.fallbackSLPoints * point);
   double candidate = fallback;
   if(isBuy && state.sweepExtremeLow > 0.0)
      candidate = state.sweepExtremeLow - params.slBufferPoints * point;
   if(!isBuy && state.sweepExtremeHigh > 0.0)
      candidate = state.sweepExtremeHigh + params.slBufferPoints * point;

   sl = candidate;
   if(isBuy)
      slDistancePoints = (entryPrice - sl) / point;
   else
      slDistancePoints = (sl - entryPrice) / point;

   if(slDistancePoints < MinSLPoints)
   {
      slDistancePoints = MinSLPoints;
      sl = isBuy ? (entryPrice - slDistancePoints * point) : (entryPrice + slDistancePoints * point);
   }

   int digits = (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);

   tp = 0.0;
   if(UseTP)
   {
      if(tpMode == MidRange)
         tp = state.rangeMid;
      else if(tpMode == OppositeEdge)
         tp = isBuy ? state.rangeHigh : state.rangeLow;
      else if(tpMode == FixedRR)
         tp = isBuy ? (entryPrice + slDistancePoints * point * RR) : (entryPrice - slDistancePoints * point * RR);
      tp = NormalizeDouble(tp, digits);
   }
   return true;
}

double NormalizeVolume(const string symbol, double volume)
{
   double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double normalized = MathMax(volume, minVol);
   normalized = MathMin(normalized, maxVol);
   normalized = MathMax(normalized, MinLot);
   normalized = MathMin(normalized, MaxLot);
   normalized = MathFloor(normalized / step) * step;
   normalized = NormalizeDouble(normalized, 2);
   if(normalized < minVol)
      normalized = minVol;
   return normalized;
}

double CalculateLotSize(const string symbol, double slDistancePoints)
{
   double volume = FixedLot;
   if(lotMode == LotModeRiskPercent)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * (RiskPercent / 100.0);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickValue <= 0.0 || tickSize <= 0.0)
         return NormalizeVolume(symbol, FixedLot);
      double valuePerPoint = tickValue / tickSize * point;
      double riskPerLot = slDistancePoints * valuePerPoint;
      if(riskPerLot <= 0.0)
         volume = FixedLot;
      else
         volume = riskMoney / riskPerLot;
   }
   return NormalizeVolume(symbol, volume);
}

bool PlaceOrder(SymbolState &state, const SymbolParams &params, bool isBuy, double entryPrice, double sl, double tp, double slDistancePoints)
{
   if(!TradeAllowed())
   {
      Log(state.symbol + ": trade not allowed.");
      return false;
   }
   if(HasExistingPosition(state.symbol))
   {
      Log(state.symbol + ": position already exists, skipping entry.");
      return false;
   }
   double volume = CalculateLotSize(state.symbol, slDistancePoints);
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxDeviationPoints);

   bool result = false;
   if(isBuy)
      result = trade.Buy(volume, state.symbol, entryPrice, sl, tp, "FHSR");
   else
      result = trade.Sell(volume, state.symbol, entryPrice, sl, tp, "FHSR");

   if(result)
   {
      state.tradedToday = true;
      state.confirmBarsSinceTrade = 0;
      state.positionTicket = trade.ResultOrder();
      state.initialVolume = volume;
      state.partialDone = false;
      state.beDone = false;
      Log(state.symbol + ": entry placed volume=" + DoubleToString(volume, 2));
      return true;
   }
   Log(state.symbol + ": order failed. ret=" + IntegerToString(trade.ResultRetcode()));
   return false;
}

void UpdatePositionManagement(SymbolState &state)
{
   ulong ticket = GetExistingPositionTicket(state.symbol);
   if(ticket == 0)
      return;
   if(!PositionSelectByTicket(ticket))
      return;

   int type = (int)PositionGetInteger(POSITION_TYPE);
   bool isBuy = (type == POSITION_TYPE_BUY);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(state.symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(state.symbol, SYMBOL_ASK);

   if(UseBreakeven && !state.beDone)
   {
      double movePoints = isBuy ? (bid - entry) / point : (entry - ask) / point;
      if(movePoints >= BE_TriggerPoints)
      {
         double newSL = isBuy ? entry + BE_LockPoints * point : entry - BE_LockPoints * point;
         if(isBuy && (sl == 0.0 || newSL > sl))
         {
            trade.PositionModify(state.symbol, NormalizeDouble(newSL, (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS)), tp);
            state.beDone = true;
            Log(state.symbol + ": breakeven moved.");
         }
         if(!isBuy && (sl == 0.0 || newSL < sl))
         {
            trade.PositionModify(state.symbol, NormalizeDouble(newSL, (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS)), tp);
            state.beDone = true;
            Log(state.symbol + ": breakeven moved.");
         }
      }
   }

   if(UsePartial && !state.partialDone)
   {
      double tp1 = 0.0;
      if(tpMode == MidRange)
         tp1 = state.rangeMid;
      else if(tpMode == OppositeEdge)
         tp1 = isBuy ? state.rangeHigh : state.rangeLow;
      else if(tpMode == FixedRR)
      {
         double slDistancePoints = MathAbs(entry - sl) / point;
         tp1 = isBuy ? (entry + slDistancePoints * point * RR) : (entry - slDistancePoints * point * RR);
      }
      bool reached = isBuy ? (bid >= tp1 && tp1 > 0.0) : (ask <= tp1 && tp1 > 0.0);
      if(reached)
      {
         double closeVolume = NormalizeVolume(state.symbol, volume * PartialPercent / 100.0);
         if(closeVolume > 0.0 && closeVolume < volume)
         {
            if(trade.PositionClosePartial(state.symbol, closeVolume))
            {
               state.partialDone = true;
               Log(state.symbol + ": partial close executed.");
               if(MoveSLToBE_AfterPartial)
               {
                  double newSL = entry;
                  trade.PositionModify(state.symbol, NormalizeDouble(newSL, (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS)), tp);
               }

               double newTP = 0.0;
               if(runnerMode == DailyOpen)
               {
                  MqlRates rates[];
                  if(CopyRates(state.symbol, PERIOD_D1, 0, 1, rates) == 1)
                  {
                     double dailyOpen = rates[0].open;
                     if(isBuy && dailyOpen > entry)
                        newTP = dailyOpen;
                     if(!isBuy && dailyOpen < entry)
                        newTP = dailyOpen;
                  }
               }
               else if(runnerMode == RunnerTP_RR2)
               {
                  double slDistancePoints = MathAbs(entry - sl) / point;
                  newTP = isBuy ? (entry + slDistancePoints * point * RR2) : (entry - slDistancePoints * point * RR2);
               }
               if(newTP > 0.0)
               {
                  trade.PositionModify(state.symbol, sl, NormalizeDouble(newTP, (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS)));
               }
               else if(runnerMode == RunnerTP_None)
               {
                  trade.PositionModify(state.symbol, sl, 0.0);
               }
            }
         }
      }
   }
}

void EvaluateSymbol(SymbolState &state)
{
   datetime now = TimeCurrent();
   int currentDayKey = GetDayKey(now);
   if(state.dayKey != currentDayKey)
      ResetStateForDay(state, currentDayKey);

   SymbolParams params = GetParamsForSymbol(state.symbol);

   if(!state.rangeReady)
   {
      if(!EnsureRange(state))
         return;
      if(!PassRangeFilter(state, params))
      {
         Log(state.symbol + ": range size filter triggered, skipping day.");
         state.skipDay = true;
      }
      if(!CheckADXFilter(state))
         return;
   }

   if(state.skipDay)
      return;

   if(!CheckYesterdayBreakout(state))
      return;

   if(!PassSpreadFilter(state, params))
      return;

   UpdatePositionManagement(state);

   MqlRates confirmBar;
   if(!GetConfirmBar(state, confirmBar))
      return;

   bool isNewConfirmBar = confirmBar.time > state.lastProcessedConfirmBarCloseTime;
   if(isNewConfirmBar)
   {
      state.lastProcessedConfirmBarCloseTime = confirmBar.time;
      if(state.sweepState != SWEEP_NONE)
      {
         state.confirmBarsSinceSweep++;
         if(state.confirmBarsSinceSweep > MaxConfirmBars)
         {
            state.sweepState = SWEEP_NONE;
            state.sweepStartTime = 0;
            state.confirmBarsSinceSweep = 0;
            state.sweepExtremeHigh = 0.0;
            state.sweepExtremeLow = 0.0;
            Log(state.symbol + ": sweep expired.");
         }
      }
      if(!OneTradePerDay)
         state.confirmBarsSinceTrade++;
   }

   MqlTick tick;
   if(!SymbolInfoTick(state.symbol, tick))
      return;
   double ask = tick.ask;
   double bid = tick.bid;
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);

   if(state.sweepState == SWEEP_UP)
   {
      if(ask > state.sweepExtremeHigh)
         state.sweepExtremeHigh = ask;
   }
   if(state.sweepState == SWEEP_DOWN)
   {
      if(bid < state.sweepExtremeLow || state.sweepExtremeLow == 0.0)
         state.sweepExtremeLow = bid;
   }

   if(state.sweepState == SWEEP_NONE)
   {
      if(!state.rangeReady)
         return;
      if(OneTradePerDay && state.tradedToday)
         return;
      if(!OneTradePerDay && state.confirmBarsSinceTrade < CooldownBarsAfterTrade)
         return;
      if(ask > state.rangeHigh + params.sweepBufferPoints * point)
      {
         state.sweepState = SWEEP_UP;
         state.sweepStartTime = now;
         state.confirmBarsSinceSweep = 0;
         state.sweepExtremeHigh = ask;
         state.sweepExtremeLow = 0.0;
         Log(state.symbol + ": sweep up detected.");
      }
      else if(bid < state.rangeLow - params.sweepBufferPoints * point)
      {
         state.sweepState = SWEEP_DOWN;
         state.sweepStartTime = now;
         state.confirmBarsSinceSweep = 0;
         state.sweepExtremeLow = bid;
         state.sweepExtremeHigh = 0.0;
         Log(state.symbol + ": sweep down detected.");
      }
      return;
   }

   if(!isNewConfirmBar)
      return;

   if(!IsInEntryWindow(now))
      return;

   if(state.sweepState == SWEEP_UP)
   {
      double sweepDistancePoints = (state.sweepExtremeHigh - state.rangeHigh) / point;
      if(sweepDistancePoints < params.minSweepDistancePoints)
      {
         Log(state.symbol + ": sweep up distance too small.");
         state.sweepState = SWEEP_NONE;
         return;
      }
      double confirmLevel = state.rangeHigh - params.confirmInsidePoints * point;
      if(confirmBar.close <= confirmLevel && PassWickFilter(confirmBar, true))
      {
         double sl = 0.0;
         double tp = 0.0;
         double slDistancePoints = 0.0;
         ComputeSLTP(state, params, false, bid, sl, tp, slDistancePoints);
         if(PlaceOrder(state, params, false, bid, sl, tp, slDistancePoints))
         {
            state.sweepState = SWEEP_NONE;
         }
      }
   }
   else if(state.sweepState == SWEEP_DOWN)
   {
      double sweepDistancePoints = (state.rangeLow - state.sweepExtremeLow) / point;
      if(sweepDistancePoints < params.minSweepDistancePoints)
      {
         Log(state.symbol + ": sweep down distance too small.");
         state.sweepState = SWEEP_NONE;
         return;
      }
      double confirmLevel = state.rangeLow + params.confirmInsidePoints * point;
      if(confirmBar.close >= confirmLevel && PassWickFilter(confirmBar, false))
      {
         double sl = 0.0;
         double tp = 0.0;
         double slDistancePoints = 0.0;
         ComputeSLTP(state, params, true, ask, sl, tp, slDistancePoints);
         if(PlaceOrder(state, params, true, ask, sl, tp, slDistancePoints))
         {
            state.sweepState = SWEEP_NONE;
         }
      }
   }
}

void ParseSymbols()
{
   string list = SymbolsList;
   StringReplace(list, " ", "");
   string symbols[];
   int count = StringSplit(list, ',', symbols);
   ArrayResize(states, 0);

   for(int i = 0; i < count; ++i)
   {
      if(symbols[i] == "")
         continue;
      if(!SymbolSelect(symbols[i], true))
         continue;
      SymbolState state;
      state.symbol = symbols[i];
      state.dayKey = 0;
      state.adxHandle = INVALID_HANDLE;
      ArrayResize(states, ArraySize(states) + 1);
      states[ArraySize(states) - 1] = state;
   }

   if(IncludeChartSymbol)
   {
      string chartSymbol = _Symbol;
      bool exists = false;
      for(int i = 0; i < ArraySize(states); ++i)
      {
         if(states[i].symbol == chartSymbol)
         {
            exists = true;
            break;
         }
      }
      if(!exists)
      {
         SymbolState state;
         state.symbol = chartSymbol;
         state.dayKey = 0;
         state.adxHandle = INVALID_HANDLE;
         ArrayResize(states, ArraySize(states) + 1);
         states[ArraySize(states) - 1] = state;
      }
   }
}

int OnInit()
{
   ParseSymbols();
   for(int i = 0; i < ArraySize(states); ++i)
   {
      states[i].adxHandle = iADX(states[i].symbol, ADX_TF, ADXPeriod);
      ResetStateForDay(states[i], GetDayKey(TimeCurrent()));
      InitializeExistingPosition(states[i]);
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   for(int i = 0; i < ArraySize(states); ++i)
   {
      if(states[i].adxHandle != INVALID_HANDLE)
         IndicatorRelease(states[i].adxHandle);
   }
}

void OnTick()
{
   for(int i = 0; i < ArraySize(states); ++i)
      EvaluateSymbol(states[i]);
}
