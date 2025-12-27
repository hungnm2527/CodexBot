//+------------------------------------------------------------------+
//| PrecisionGoldEA.mq5                                             |
//| High-accuracy XAU/USD expert advisor for the M15 timeframe      |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input string TradeSymbol        = "XAUUSD";    // Target symbol (XAU/USD)
input double RiskPerTrade       = 1.0;          // Risk per trade (% of balance)
input double RewardToRisk       = 1.8;          // Take profit reward-to-risk ratio
input double MaxSpreadPoints    = 400.0;        // Maximum allowed spread in points
input int    FastEMAPeriod      = 50;           // Fast EMA period
input int    SlowEMAPeriod      = 200;          // Slow EMA period
input int    RSIPeriod          = 14;           // RSI period
input int    RSIEntryThreshold  = 55;           // RSI level to confirm momentum
input int    RSIPullbackLevel   = 48;           // RSI level to identify pullbacks
input int    ATRPeriod          = 14;           // ATR period for stop/TP sizing
input double ATRStopMultiplier  = 2.2;          // Stop distance in ATR multiples
input ulong  MagicNumber        = 880015;       // Magic number for the EA

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(_Period != PERIOD_M15)
     {
      Print("PrecisionGoldEA is designed for M15 charts. Please switch timeframe.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(StringCompare(_Symbol, TradeSymbol) != 0)
     {
      PrintFormat("Attach to %s chart for consistent tick data.", TradeSymbol);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Main tick handler                                                |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(StringCompare(_Symbol, TradeSymbol) != 0)
      return;

   if(!IsNewBar())
      return;

   if(HasOpenPosition())
      return;

   if(!SpreadIsAcceptable())
      return;

   double priceBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double priceAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double emaFast = iMA(_Symbol, _Period, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(_Symbol, _Period, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double rsi     = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE, 0);
   double atr     = iATR(_Symbol, _Period, ATRPeriod, 0);

   if(emaFast == 0.0 || emaSlow == 0.0 || atr <= 0.0)
      return;

   // Determine directional bias
   bool bullishBias = emaFast > emaSlow;
   bool bearishBias = emaFast < emaSlow;

   // Pullback filters using RSI
   bool bullishPullback = bullishBias && rsi >= RSIPullbackLevel && rsi <= RSIEntryThreshold;
   bool bearishPullback = bearishBias && rsi <= (100 - RSIPullbackLevel) && rsi >= (100 - RSIEntryThreshold);

   if(bullishPullback && rsi > RSIEntryThreshold)
      bullishPullback = false;
   if(bearishPullback && rsi < (100 - RSIEntryThreshold))
      bearishPullback = false;

   double stopDistance = ATRStopMultiplier * atr;
   double slPrice, tpPrice;

   if(bullishPullback && priceAsk > emaFast)
     {
      slPrice = priceBid - stopDistance;
      tpPrice = priceAsk + stopDistance * RewardToRisk;
      ExecuteTrade(ORDER_TYPE_BUY, priceAsk, slPrice, tpPrice);
     }
   else if(bearishPullback && priceBid < emaFast)
     {
      slPrice = priceAsk + stopDistance;
      tpPrice = priceBid - stopDistance * RewardToRisk;
      ExecuteTrade(ORDER_TYPE_SELL, priceBid, slPrice, tpPrice);
     }
  }

//+------------------------------------------------------------------+
//| Execute trade with risk-based position sizing                    |
//+------------------------------------------------------------------+
void ExecuteTrade(const ENUM_ORDER_TYPE orderType, const double entry, const double sl, const double tp)
  {
   if(sl <= 0.0 || tp <= 0.0)
      return;

   double volume = CalculateRiskVolume(entry, sl);
   if(volume <= 0.0)
      return;

   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.type     = orderType;
   request.volume   = volume;
   request.price    = entry;
   request.sl       = sl;
   request.tp       = tp;
   request.deviation= 30;
   request.magic    = MagicNumber;
   request.type_filling = ORDER_FILLING_FOK;
   request.comment  = "PrecisionGoldEA";

   if(!OrderSend(request, result))
     {
      PrintFormat("OrderSend failed: %d - %s", GetLastError(), result.comment);
      return;
     }

   if(result.retcode != TRADE_RETCODE_DONE)
      PrintFormat("Trade not confirmed: %d - %s", result.retcode, result.comment);
  }

//+------------------------------------------------------------------+
//| Check acceptable spread                                          |
//+------------------------------------------------------------------+
bool SpreadIsAcceptable()
  {
   double spreadPoints = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   return(spreadPoints <= MaxSpreadPoints);
  }

//+------------------------------------------------------------------+
//| Calculate volume based on risk percent                           |
//+------------------------------------------------------------------+
double CalculateRiskVolume(const double entryPrice, const double slPrice)
  {
   double stopPoints = MathAbs(entryPrice - slPrice) / _Point;
   if(stopPoints < 1.0)
      return(0.0);

   double riskMoney = AccountBalance() * (RiskPerTrade / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tickValue <= 0.0 || tickSize <= 0.0)
      return(0.0);

   double stopValuePerLot = (stopPoints * tickValue) / (_Point / tickSize);
   if(stopValuePerLot <= 0.0)
      return(0.0);

   double rawLots = riskMoney / stopValuePerLot;
   rawLots = MathMax(minLot, MathMin(maxLot, rawLots));
   rawLots = MathFloor(rawLots / lotStep) * lotStep;

   int volumeDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME_DIGITS);
   return(NormalizeDouble(rawLots, volumeDigits));
  }

//+------------------------------------------------------------------+
//| Determine if there is open exposure on the symbol                |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(!PositionSelectByIndex(i))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Detect new bar to avoid duplicate signals                        |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   static datetime lastTime = 0;
   datetime current = iTime(_Symbol, _Period, 0);
   if(current == 0)
      return(false);

   if(lastTime == current)
      return(false);

   lastTime = current;
   return(true);
  }
//+------------------------------------------------------------------+
