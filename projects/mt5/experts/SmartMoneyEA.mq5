//+------------------------------------------------------------------+
//| SmartMoneyEA.mq5                                                 |
//| Example Expert Advisor based on simple Smart Money Concepts      |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input double  RiskPerTrade      = 1.0;    // Risk per trade (% of balance)
input double  RewardToRisk      = 2.0;    // Reward-to-risk ratio
input int     SwingLookback     = 5;      // Swing size for structure points
input int     StructureDepth    = 40;     // Bars used to evaluate market structure
input int     OrderBlockLookback= 60;     // Lookback bars to locate order blocks
input double  EntryBufferPoints = 10;     // Extra points beyond order block for stop loss
input bool    UseFairValueGap   = true;   // Require confluence with a fair value gap
input int     FvgLookback       = 30;     // Lookback bars to find a fair value gap

CTrade trade;

struct OrderBlock
  {
   datetime time;
   double   high;
   double   low;
   bool     bullish;
  };

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars(_Symbol,PERIOD_CURRENT) < MathMax(StructureDepth+SwingLookback, OrderBlockLookback+5))
      return;

   if(HasSymbolExposure())
      return;

   int bias = MarketStructureBias(StructureDepth, SwingLookback);
   if(bias == 0)
      return;

   OrderBlock block;
   if(!FindOrderBlock(bias > 0, OrderBlockLookback, block))
      return;

   double entryPrice = (block.high + block.low) * 0.5;
   double slPrice    = block.bullish ? block.low - EntryBufferPoints * _Point
                                     : block.high + EntryBufferPoints * _Point;
   double tpPrice    = block.bullish ? entryPrice + (entryPrice - slPrice) * RewardToRisk
                                     : entryPrice - (slPrice - entryPrice) * RewardToRisk;

   if(UseFairValueGap)
     {
      double fvgUpper, fvgLower;
      if(!FindFairValueGap(block.bullish, FvgLookback, fvgUpper, fvgLower))
         return;

      if(entryPrice < fvgLower || entryPrice > fvgUpper)
         return;
     }

   double lots = CalculateVolume(entryPrice, slPrice);
   if(lots <= 0.0)
      return;

   if(block.bullish)
     {
      // Wait for price to trade back into the order block
      if(SymbolInfoDouble(_Symbol, SYMBOL_BID) > entryPrice)
         PlacePending(ORDER_TYPE_BUY_LIMIT, entryPrice, slPrice, tpPrice, lots, "SMC_BUY");
     }
   else
     {
      if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) < entryPrice)
         PlacePending(ORDER_TYPE_SELL_LIMIT, entryPrice, slPrice, tpPrice, lots, "SMC_SELL");
     }
  }

//+------------------------------------------------------------------+
//| Place a pending order with basic validation                      |
//+------------------------------------------------------------------+
void PlacePending(const ENUM_ORDER_TYPE orderType, const double price, const double sl,
                  const double tp, const double volume, const string comment)
  {
   MqlTradeRequest  request;
   MqlTradeResult   result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_PENDING;
   request.symbol   = _Symbol;
   request.type     = orderType;
   request.volume   = volume;
   request.price    = price;
   request.sl       = sl;
   request.tp       = tp;
   request.deviation= 20;
   request.magic    = 51001;
   request.comment  = comment;

   if(!OrderSend(request, result))
     {
      PrintFormat("OrderSend failed: %d - %s", GetLastError(), result.comment);
      return;
     }

   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
      PrintFormat("OrderSend returned %d - %s", result.retcode, result.comment);
  }

//+------------------------------------------------------------------+
//| Calculate position size based on stop distance                   |
//+------------------------------------------------------------------+
double CalculateVolume(const double entryPrice, const double slPrice)
  {
   double riskMoney  = AccountBalance() * RiskPerTrade * 0.01;
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopPoints = MathAbs(entryPrice - slPrice) / tickSize;

   if(stopPoints <= 1.0 || tickValue <= 0.0)
      return(0.0);

   double rawLots = riskMoney / (stopPoints * tickValue);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   rawLots = MathMax(minLot, MathMin(maxLot, rawLots));
   rawLots = MathFloor(rawLots / stepLot) * stepLot;

   return(NormalizeDouble(rawLots, (int)SymbolInfoInteger(_Symbol, SYMBOL_VOLUME_DIGITS)));
  }

//+------------------------------------------------------------------+
//| Check if there is any open position or pending order for symbol  |
//+------------------------------------------------------------------+
bool HasSymbolExposure()
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      if(!PositionSelectByIndex(i))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return(true);
     }

   for(int j=0; j<OrdersTotal(); j++)
     {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Determine market structure bias                                  |
//+------------------------------------------------------------------+
int MarketStructureBias(const int depth, const int swing)
  {
   int lastHigh = -1, lastLow = -1;
   for(int i=swing; i<depth; i++)
     {
      if(lastHigh==-1 && IsSwingHigh(i, swing))
         lastHigh = i;
      if(lastLow==-1 && IsSwingLow(i, swing))
         lastLow = i;
      if(lastHigh!=-1 && lastLow!=-1)
         break;
     }

   if(lastHigh==-1 || lastLow==-1)
      return(0);

   int nextHigh = -1, nextLow = -1;
   for(int i=lastHigh+1; i<depth; i++)
     {
      if(IsSwingHigh(i, swing))
         { nextHigh = i; break; }
     }
   for(int i=lastLow+1; i<depth; i++)
     {
      if(IsSwingLow(i, swing))
         { nextLow = i; break; }
     }

   bool bullishStructure = (nextHigh!=-1 && High[nextHigh] > High[lastHigh]) || (nextLow!=-1 && Low[nextLow] > Low[lastLow]);
   bool bearishStructure = (nextHigh!=-1 && High[nextHigh] < High[lastHigh]) || (nextLow!=-1 && Low[nextLow] < Low[lastLow]);

   if(bullishStructure && !bearishStructure)
      return(1);
   if(bearishStructure && !bullishStructure)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Find the most recent order block                                 |
//+------------------------------------------------------------------+
bool FindOrderBlock(const bool bullish, const int lookback, OrderBlock &block)
  {
   for(int i=1; i<=lookback; i++)
     {
      double openC = Open[i];
      double closeC= Close[i];
      double highC = High[i];
      double lowC  = Low[i];

      if(bullish)
        {
         if(closeC < openC && Close[i-1] > Open[i-1] && Close[i-1] > highC)
           {
            block.time    = Time[i];
            block.high    = highC;
            block.low     = lowC;
            block.bullish = true;
            return(true);
           }
        }
      else
        {
         if(closeC > openC && Close[i-1] < Open[i-1] && Close[i-1] < lowC)
           {
            block.time    = Time[i];
            block.high    = highC;
            block.low     = lowC;
            block.bullish = false;
            return(true);
           }
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Swing detection helpers                                          |
//+------------------------------------------------------------------+
bool IsSwingHigh(const int index, const int swing)
  {
   double currentHigh = High[index];
   for(int i=1; i<=swing; i++)
     {
      if(High[index - i] >= currentHigh || High[index + i] >= currentHigh)
         return(false);
     }
   return(true);
  }

bool IsSwingLow(const int index, const int swing)
  {
   double currentLow = Low[index];
   for(int i=1; i<=swing; i++)
     {
      if(Low[index - i] <= currentLow || Low[index + i] <= currentLow)
         return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Locate a fair value gap                                          |
//+------------------------------------------------------------------+
bool FindFairValueGap(const bool bullish, const int lookback, double &upper, double &lower)
  {
   for(int i=1; i<lookback && i+2 < Bars; i++)
     {
      double high1 = High[i+2];
      double low1  = Low[i+2];
      double high3 = High[i];
      double low3  = Low[i];

      if(bullish)
        {
         if(low1 > high3)
           {
            upper = low1;
            lower = high3;
            return(true);
           }
        }
      else
        {
         if(high1 < low3)
           {
            upper = high3;
            lower = high1;
            return(true);
           }
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
