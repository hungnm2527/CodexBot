#property copyright ""
#property link      ""
#property version   "1.000"
#property strict
/*
 XAU Execution-Guard Scalper (M5/M15)
 ------------------------------------
 - Attach to: XAUUSD recommended, works on any symbol.
 - Timeframe: M5 or M15 recommended.
 - Core idea: only execute trades when execution conditions are clean: spread guard, liquidity filters, cooldowns.
 - Key inputs: risk (Lots or RiskPercent), spread controls, liquidity filters (tick volume/range/tick-rate), sessions/news block, cooldowns, ATR-based SL/TP.
*/
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "General"
input int      MagicNumber               = 880088;
input double   Lots                      = 0.10; // Used if RiskPercent <=0
input double   RiskPercent               = 0.0;  // Percent risk per trade (0 = fixed Lots)
input int      DeviationPoints           = 30;
input int      MaxOpenPositions          = 1;

input group "Spread Control"
input bool     UseDynamicSpread          = true;
input int      MaxSpreadPoints           = 350; // 0 = ignore hard cap
input int      SpreadLookbackSeconds     = 120;
input double   SpreadSpikeMultiplier     = 1.8;

input group "Liquidity Filters"
input int      MinTickVolume             = 200;
input int      MinRangePoints            = 300; // if 0, ignored
input int      MinATRPoints              = 200; // if 0, ignored
input int      TickRateWindowSeconds     = 30;
input int      MinTicksInWindow          = 10;

input group "Session / News"
input bool     EnableSessions            = false;
input int      StartHour                 = 7;  // server time
input int      EndHour                   = 22; // server time
input int      BlockNewsMinutes          = 5;  // avoid first N minutes each hour as placeholder

input group "Cooldowns"
input int      CooldownAfterSpreadSpikeSeconds = 60;
input int      CooldownAfterTradeSeconds      = 120;

input group "Risk Guards"
input int      MaxTradesPerDay           = 6;
input double   MaxDailyLossMoney         = 0.0; // 0 = off
input double   MaxFloatingDDMoney        = 0.0; // 0 = off

input group "Stops / Targets"
input bool     UseATRStops               = true;
input int      ATRPeriod                 = 14;
input double   SL_ATR_Mult               = 1.8;
input double   TP_ATR_Mult               = 2.5;
input int      ClampMinSLPoints          = 200;
input int      ClampMaxSLPoints          = 2500;
input int      ClampMinTPPoints          = 200;
input int      ClampMaxTPPoints          = 3500;

input group "Signal"
input int      EMAPeriodFast             = 9;
input int      EMAPeriodSlow             = 21;
input int      BreakoutBufferPoints      = 100;

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CTrade trade;
int    handleEMAfast = INVALID_HANDLE;
int    handleEMAslow = INVALID_HANDLE;
int    handleATR     = INVALID_HANDLE;
datetime nextAllowedTradeTime = 0;
string lastGuardReason = "";
datetime lastGuardPrint = 0;

struct SpreadSample
{
   datetime time;
   double   spread;
};
SpreadSample spreadSamples[256];
int spreadCount = 0;

struct TickStamp
{
   datetime time;
};
TickStamp tickTimes[256];
int tickCount = 0;

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
double GetSpreadPoints()
{
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   return(spread);
}

void UpdateSpreadStats()
{
   double spread = GetSpreadPoints();
   datetime now = TimeCurrent();
   if(spreadCount < 256)
   {
      spreadSamples[spreadCount].time = now;
      spreadSamples[spreadCount].spread = spread;
      spreadCount++;
   }
   else
   {
      // shift left
      for(int i=1;i<256;i++)
         spreadSamples[i-1]=spreadSamples[i];
      spreadSamples[255].time = now;
      spreadSamples[255].spread = spread;
   }
   // remove old samples
   int i=0;
   while(i<spreadCount)
   {
      if((now - spreadSamples[i].time) > SpreadLookbackSeconds)
      {
         for(int j=i+1;j<spreadCount;j++)
            spreadSamples[j-1]=spreadSamples[j];
         spreadCount--;
      }
      else
         i++;
   }
}

double ComputeMedianSpread()
{
   if(spreadCount==0)
      return(GetSpreadPoints());
   int count=spreadCount;
   double temp[256];
   for(int i=0;i<count;i++) temp[i]=spreadSamples[i].spread;
   ArraySort(temp,count);
   if(count%2==1)
      return(temp[count/2]);
   return((temp[count/2-1]+temp[count/2])/2.0);
}

void AddTickStamp()
{
   datetime now = TimeCurrent();
   if(tickCount < 256)
   {
      tickTimes[tickCount].time = now;
      tickCount++;
   }
   else
   {
      for(int i=1;i<256;i++)
         tickTimes[i-1]=tickTimes[i];
      tickTimes[255].time = now;
   }
   // prune
   int i=0;
   while(i<tickCount)
   {
      if((now - tickTimes[i].time) > TickRateWindowSeconds)
      {
         for(int j=i+1;j<tickCount;j++)
            tickTimes[j-1]=tickTimes[j];
         tickCount--;
      }
      else
         i++;
   }
}

bool IsTickRateOk()
{
   datetime now=TimeCurrent();
   int cnt=0;
   for(int i=0;i<tickCount;i++)
   {
      if((now - tickTimes[i].time) <= TickRateWindowSeconds)
         cnt++;
   }
   if(MinTicksInWindow<=0) return(true);
   return(cnt>=MinTicksInWindow);
}

bool IsSpreadOk(string &reason)
{
   double curSpread = GetSpreadPoints();
   double median = ComputeMedianSpread();
   bool ok = true;
   if(UseDynamicSpread)
   {
      if(curSpread > median * SpreadSpikeMultiplier)
      {
         reason = "Spread spike";
         nextAllowedTradeTime = TimeCurrent() + CooldownAfterSpreadSpikeSeconds;
         ok=false;
      }
   }
   if(ok && MaxSpreadPoints>0 && curSpread > MaxSpreadPoints)
   {
      reason = "Spread > max";
      ok=false;
   }
   return(ok);
}

bool GetLatestRates(MqlRates &prev, MqlRates &curr)
{
   MqlRates rates[3];
   if(CopyRates(_Symbol,_Period,1,2,rates)!=2)
      return(false);
   curr = rates[0]; // bar 1 (just closed)
   prev = rates[1]; // bar 2
   return(true);
}

bool IsLiquidityOk(string &reason)
{
   MqlRates prev,curr;
   if(!GetLatestRates(prev,curr))
   {
      reason = "No rates";
      return(false);
   }
   if(MinTickVolume>0 && (curr.tick_volume < (long)MinTickVolume))
   {
      reason = "Low tick vol";
      return(false);
   }
   double rangePoints = (curr.high - curr.low)/_Point;
   if(MinRangePoints>0 && rangePoints < MinRangePoints)
   {
      reason = "Range low";
      return(false);
   }
   if(MinATRPoints>0 && handleATR!=INVALID_HANDLE)
   {
      double atrVal[2];
      if(CopyBuffer(handleATR,0,1,1,atrVal)==1)
      {
         double atrPoints = atrVal[0]/_Point;
         if(atrPoints < MinATRPoints)
         {
            reason = "ATR low";
            return(false);
         }
      }
   }
   if(!IsTickRateOk())
   {
      reason = "Tick rate low";
      return(false);
   }
   return(true);
}

bool IsInTradingSession()
{
   if(!EnableSessions) return(true);
   datetime now=TimeCurrent();
   MqlDateTime t; TimeToStruct(now,t);
   int hour=t.hour;
   if(StartHour<=EndHour)
      return(hour>=StartHour && hour<EndHour);
   // overnight window
   return(hour>=StartHour || hour<EndHour);
}

bool IsInBlockedNewsWindow()
{
   if(BlockNewsMinutes<=0) return(false);
   datetime now=TimeCurrent();
   MqlDateTime t; TimeToStruct(now,t);
   if(t.min < BlockNewsMinutes)
      return(true);
   return(false);
}

int CountTradesToday()
{
   datetime from=TimeCurrent() - 24*60*60;
   datetime to=TimeCurrent();
   HistorySelect(from,to);
   int total=0;
   uint deals=HistoryDealsTotal();
   for(uint i=0;i<deals;i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC)==MagicNumber)
         total++;
   }
   return(total);
}

double GetTodayPnL()
{
   datetime from=TimeCurrent() - 24*60*60;
   datetime to=TimeCurrent();
   HistorySelect(from,to);
   double pnl=0.0;
   uint deals=HistoryDealsTotal();
   for(uint i=0;i<deals;i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC)==MagicNumber)
      {
         double profit=HistoryDealGetDouble(ticket, DEAL_PROFIT)+HistoryDealGetDouble(ticket, DEAL_SWAP)+HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         pnl+=profit;
      }
   }
   return(pnl);
}

double GetFloatingPnL()
{
   double pnl=0.0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      if(PositionSelectByIndex(i))
      {
         if((int)PositionGetInteger(POSITION_MAGIC)==MagicNumber)
            pnl+=PositionGetDouble(POSITION_PROFIT);
      }
   }
   return(pnl);
}

int CountOpenPositions()
{
   int count=0;
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
   {
      if(PositionSelectByIndex(i))
      {
         if((int)PositionGetInteger(POSITION_MAGIC)==MagicNumber)
            count++;
      }
   }
   return(count);
}

bool CanTrade(string &reason)
{
   if(!IsInTradingSession())
   {
      reason = "Outside session";
      return(false);
   }
   if(IsInBlockedNewsWindow())
   {
      reason = "News window";
      return(false);
   }
   if(TimeCurrent() < nextAllowedTradeTime)
   {
      reason = "Cooldown";
      return(false);
   }
   if(MaxOpenPositions>0 && CountOpenPositions()>=MaxOpenPositions)
   {
      reason = "Max open";
      return(false);
   }
   if(MaxTradesPerDay>0 && CountTradesToday()>=MaxTradesPerDay)
   {
      reason = "Max trades today";
      return(false);
   }
   double pnlToday=GetTodayPnL();
   if(MaxDailyLossMoney>0 && pnlToday<=-MathAbs(MaxDailyLossMoney))
   {
      reason = "Daily loss limit";
      return(false);
   }
   double floating=GetFloatingPnL();
   if(MaxFloatingDDMoney>0 && floating<=-MathAbs(MaxFloatingDDMoney))
   {
      reason = "Floating DD";
      return(false);
   }
   return(true);
}

bool GetSignal(int &direction)
{
   direction=0;
   double emaFast[2], emaSlow[2];
   if(handleEMAfast==INVALID_HANDLE || handleEMAslow==INVALID_HANDLE)
      return(false);
   if(CopyBuffer(handleEMAfast,0,1,1,emaFast)!=1) return(false);
   if(CopyBuffer(handleEMAslow,0,1,1,emaSlow)!=1) return(false);
   MqlRates prev,curr;
   if(!GetLatestRates(prev,curr)) return(false);
   double prevHigh=prev.high;
   double prevLow=prev.low;
   double close=curr.close;
   if(emaFast[0]>emaSlow[0] && close > (prevHigh + BreakoutBufferPoints*_Point))
      direction=1;
   else if(emaFast[0]<emaSlow[0] && close < (prevLow - BreakoutBufferPoints*_Point))
      direction=-1;
   return(direction!=0);
}

double NormalizeLot(double lot)
{
   double minLot=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot=MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot/step)*step;
   lot = NormalizeDouble(lot, (int)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME_DIGITS));
   return(lot);
}

double CalculateStopLossPoints()
{
   double slPoints=ClampMinSLPoints;
   if(UseATRStops && handleATR!=INVALID_HANDLE)
   {
      double atrVal[2];
      if(CopyBuffer(handleATR,0,1,1,atrVal)==1)
      {
         slPoints = atrVal[0]/_Point * SL_ATR_Mult;
      }
   }
   slPoints = MathMax(slPoints, ClampMinSLPoints);
   if(ClampMaxSLPoints>0) slPoints = MathMin(slPoints, ClampMaxSLPoints);
   return(slPoints);
}

double CalculateTakeProfitPoints()
{
   double tpPoints=ClampMinTPPoints;
   if(UseATRStops && handleATR!=INVALID_HANDLE)
   {
      double atrVal[2];
      if(CopyBuffer(handleATR,0,1,1,atrVal)==1)
      {
         tpPoints = atrVal[0]/_Point * TP_ATR_Mult;
      }
   }
   tpPoints = MathMax(tpPoints, ClampMinTPPoints);
   if(ClampMaxTPPoints>0) tpPoints = MathMin(tpPoints, ClampMaxTPPoints);
   return(tpPoints);
}

double CalculateRiskLot(double stopPoints)
{
   if(RiskPercent<=0) return(NormalizeLot(Lots));
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=balance*RiskPercent/100.0;
   double tickValue=SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize=SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0) return(NormalizeLot(Lots));
   double moneyPerLotPerPoint = tickValue / (_Point/tickSize);
   if(stopPoints<=0 || moneyPerLotPerPoint<=0) return(NormalizeLot(Lots));
   double lot = riskMoney/(stopPoints*moneyPerLotPerPoint);
   return(NormalizeLot(lot));
}

void PrintGuard(const string reason)
{
   datetime now=TimeCurrent();
   if(reason!=lastGuardReason || (now-lastGuardPrint)>30)
   {
      Print("NoTrade: ",reason);
      lastGuardReason=reason;
      lastGuardPrint=now;
   }
}

bool ExecuteTrade(int direction)
{
   double stopPoints=CalculateStopLossPoints();
   double tpPoints=CalculateTakeProfitPoints();
   double lot=CalculateRiskLot(stopPoints);
   double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl=0,tp=0,price=0;
   if(direction>0)
   {
      price=ask;
      sl=price - stopPoints*_Point;
      tp=price + tpPoints*_Point;
   }
   else
   {
      price=bid;
      sl=price + stopPoints*_Point;
      tp=price - tpPoints*_Point;
   }
   sl=NormalizeDouble(sl,_Digits);
   tp=NormalizeDouble(tp,_Digits);
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(DeviationPoints);
   bool result=false;
   if(direction>0)
      result = trade.Buy(lot,NULL,price,sl,tp,"XAU ExecGuard Buy");
   else
      result = trade.Sell(lot,NULL,price,sl,tp,"XAU ExecGuard Sell");
   if(result)
   {
      Print("Trade opened: ",(direction>0?"BUY":"SELL")," lot=",DoubleToString(lot,2)," SL=",DoubleToString(sl,_Digits)," TP=",DoubleToString(tp,_Digits)," spread=",DoubleToString(GetSpreadPoints(),1));
      nextAllowedTradeTime = TimeCurrent() + CooldownAfterTradeSeconds;
   }
   else
   {
      Print("Order send failed: ",_LastError);
   }
   return(result);
}

//+------------------------------------------------------------------+
//| Event Handlers                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   handleEMAfast = iMA(_Symbol,_Period,EMAPeriodFast,0,MODE_EMA,PRICE_CLOSE);
   handleEMAslow = iMA(_Symbol,_Period,EMAPeriodSlow,0,MODE_EMA,PRICE_CLOSE);
   if(UseATRStops)
      handleATR = iATR(_Symbol,_Period,ATRPeriod);
   else
      handleATR = INVALID_HANDLE;

   if(handleEMAfast==INVALID_HANDLE || handleEMAslow==INVALID_HANDLE)
   {
      Print("Failed to create EMA handles");
      return(INIT_FAILED);
   }
   if(UseATRStops && handleATR==INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }
   spreadCount=0;
   tickCount=0;
   nextAllowedTradeTime=TimeCurrent();
   lastGuardReason="";
   lastGuardPrint=0;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(reason==REASON_CHARTCHANGE || reason==REASON_PROGRAM) { /* acknowledge */ }
   if(handleEMAfast!=INVALID_HANDLE) { IndicatorRelease(handleEMAfast); handleEMAfast=INVALID_HANDLE; }
   if(handleEMAslow!=INVALID_HANDLE) { IndicatorRelease(handleEMAslow); handleEMAslow=INVALID_HANDLE; }
   if(handleATR!=INVALID_HANDLE) { IndicatorRelease(handleATR); handleATR=INVALID_HANDLE; }
}

void OnTick()
{
   AddTickStamp();
   UpdateSpreadStats();

   string reason="";
   if(!CanTrade(reason)) { PrintGuard(reason); return; }
   if(!IsSpreadOk(reason)) { PrintGuard(reason); return; }
   if(!IsLiquidityOk(reason)) { PrintGuard(reason); return; }

   int dir=0;
   if(!GetSignal(dir))
   {
      PrintGuard("No signal");
      return;
   }
   ExecuteTrade(dir);
}

void OnTradeTransaction(const MqlTradeTransaction& trans,const MqlTradeRequest& request,const MqlTradeResult& result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD || trans.type==TRADE_TRANSACTION_ORDER_ADD)
   {
      nextAllowedTradeTime = TimeCurrent() + CooldownAfterTradeSeconds;
   }
   if(result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED)
   {
      PrintFormat("Trade transaction retcode=%u for %s",result.retcode,request.symbol);
   }
}
//+------------------------------------------------------------------+
