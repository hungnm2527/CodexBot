//+------------------------------------------------------------------+
//| MeanReversionEA.mq5                                             |
//| High-probability mean reversion Expert Advisor                  |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input string SymbolsList            = "EURUSD,GBPUSD,USDJPY"; // Comma-separated custom symbols
input bool   IncludeChartSymbol     = true;                    // Include chart symbol automatically
input ENUM_TIMEFRAMES SignalTF      = PERIOD_M15;              // Signal timeframe
input int    RsiPeriod              = 14;                      // RSI period
input double RsiBuyThreshold        = 32.0;                    // RSI level considered oversold
input double RsiSellThreshold       = 68.0;                    // RSI level considered overbought
input int    BandsPeriod            = 20;                      // Bollinger Band period
input double BandsDeviation         = 2.0;                     // Bollinger deviation
input int    AtrPeriod              = 14;                      // ATR lookback period
input double StopAtrMultiplier      = 1.8;                     // SL distance in ATR multiples
input double TakeAtrMultiplier      = 1.1;                     // TP distance in ATR multiples
input double RiskPercent            = 1.0;                     // % of balance risked per trade
input ulong  MagicNumber            = 770170;                  // Magic number for tracking
input int    SlippagePoints         = 20;                      // Maximum slippage (points)

struct SymbolState
  {
   string   name;
   datetime lastProcessed;
  };

CTrade        trade;
SymbolState   g_symbols[];
int           g_symbolTotal = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber((int)MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   if(!BuildSymbolList())
      return(INIT_FAILED);

   PrintFormat("MeanReversionEA initialized for %d symbols", g_symbolTotal);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   for(int i=0; i<g_symbolTotal; ++i)
      EvaluateSymbol(g_symbols[i]);
  }

//+------------------------------------------------------------------+
//| Build symbol tracking list                                       |
//+------------------------------------------------------------------+
bool BuildSymbolList()
  {
   ArrayFree(g_symbols);
   g_symbolTotal = 0;

   if(IncludeChartSymbol)
     {
      ArrayResize(g_symbols, g_symbolTotal+1);
      g_symbols[g_symbolTotal].name          = _Symbol;
      g_symbols[g_symbolTotal].lastProcessed = 0;
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
      g_symbols[g_symbolTotal].name          = parts[i];
      g_symbols[g_symbolTotal].lastProcessed = 0;
      ++g_symbolTotal;
     }

   if(g_symbolTotal == 0)
     {
      Print("MeanReversionEA: no valid symbols to process.");
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Evaluate trade conditions for one symbol                         |
//+------------------------------------------------------------------+
void EvaluateSymbol(SymbolState &state)
  {
   string symbol = state.name;

   if(!EnsureSymbol(symbol))
      return;

   MqlRates rates[3];
   if(CopyRates(symbol, SignalTF, 0, 3, rates) < 3)
      return;

   datetime lastClosedTime = rates[1].time;
   if(lastClosedTime == state.lastProcessed)
      return;

   double rsiValue;
   if(!GetRSI(symbol, rsiValue))
      return;

   double upperBand, lowerBand;
   if(!GetBollinger(symbol, upperBand, lowerBand))
      return;

   double atrValue;
   if(!GetATR(symbol, atrValue))
      return;

   double closePrice = rates[1].close;
   double openPrice  = rates[1].open;

   bool bullishSignal = (rsiValue <= RsiBuyThreshold && closePrice <= lowerBand && closePrice > openPrice);
   bool bearishSignal = (rsiValue >= RsiSellThreshold && closePrice >= upperBand && closePrice < openPrice);

   if(!bullishSignal && !bearishSignal)
      return;

   if(HasExposure(symbol))
      return;

   double entryPrice = bullishSignal ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(symbol, SYMBOL_BID);
   if(entryPrice <= 0.0)
      return;

   double stopDistance = atrValue * StopAtrMultiplier;
   double takeDistance = atrValue * TakeAtrMultiplier;

   if(stopDistance <= 0.0 || takeDistance <= 0.0)
      return;

   double sl = bullishSignal ? entryPrice - stopDistance : entryPrice + stopDistance;
   double tp = bullishSignal ? entryPrice + takeDistance : entryPrice - takeDistance;

   double volume = CalculateVolume(symbol, entryPrice, sl);
   if(volume <= 0.0)
      return;

   bool placed = false;
   if(bullishSignal)
      placed = trade.Buy(volume, symbol, entryPrice, sl, tp, "MR_BUY");
   else
      placed = trade.Sell(volume, symbol, entryPrice, sl, tp, "MR_SELL");

   if(placed)
     {
      state.lastProcessed = lastClosedTime;
      PrintFormat("%s signal executed: %s %.2f lots at %.5f", symbol, bullishSignal ? "BUY" : "SELL", volume, entryPrice);
     }
   else
     {
      PrintFormat("Trade failed on %s: %d", symbol, GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Ensure market info for symbol                                    |
//+------------------------------------------------------------------+
bool EnsureSymbol(const string symbol)
  {
   if(SymbolInfoInteger(symbol, SYMBOL_SELECT))
      return(true);

   if(SymbolSelect(symbol, true))
      return(true);

   PrintFormat("MeanReversionEA: failed to select symbol %s", symbol);
   return(false);
  }

//+------------------------------------------------------------------+
//| Check for open position or pending order                         |
//+------------------------------------------------------------------+
bool HasExposure(const string symbol)
  {
   if(PositionSelect(symbol))
     {
      if((ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return(true);
     }

   for(int i=0; i<OrdersTotal(); ++i)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) == symbol && (ulong)OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Calculate position size based on SL distance                     |
//+------------------------------------------------------------------+
double CalculateVolume(const string symbol, const double entryPrice, const double slPrice)
  {
   double riskMoney  = AccountBalance() * RiskPercent * 0.01;
   double tickSize   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double volumeMin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double volumeMax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   double stopDistance = MathAbs(entryPrice - slPrice);
   if(stopDistance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return(0.0);

   double stopTicks = stopDistance / tickSize;
   double rawVolume = riskMoney / (stopTicks * tickValue);

   rawVolume = MathMax(volumeMin, MathMin(volumeMax, rawVolume));
   rawVolume = MathFloor(rawVolume / volumeStep) * volumeStep;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_VOLUME_DIGITS);
   return(NormalizeDouble(rawVolume, digits));
  }

//+------------------------------------------------------------------+
//| Indicator helpers                                                 |
//+------------------------------------------------------------------+
bool GetRSI(const string symbol, double &value)
  {
   int handle = iRSI(symbol, SignalTF, RsiPeriod, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: failed to create RSI handle", symbol);
      return(false);
     }

   double buffer[];
   if(CopyBuffer(handle, 0, 1, 1, buffer) <= 0)
     {
      PrintFormat("%s: failed to copy RSI data", symbol);
      IndicatorRelease(handle);
      return(false);
     }

   value = buffer[0];
   IndicatorRelease(handle);
   return(true);
  }

bool GetBollinger(const string symbol, double &upper, double &lower)
  {
   int handle = iBands(symbol, SignalTF, BandsPeriod, 0, MODE_SMA, PRICE_CLOSE, BandsDeviation);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: failed to create Bollinger handle", symbol);
      return(false);
     }

   double upperBuf[], lowerBuf[];
   if(CopyBuffer(handle, 0, 1, 1, upperBuf) <= 0 || CopyBuffer(handle, 2, 1, 1, lowerBuf) <= 0)
     {
      PrintFormat("%s: failed to copy Bollinger data", symbol);
      IndicatorRelease(handle);
      return(false);
     }

   upper = upperBuf[0];
   lower = lowerBuf[0];
   IndicatorRelease(handle);
   return(true);
  }

bool GetATR(const string symbol, double &value)
  {
   int handle = iATR(symbol, SignalTF, AtrPeriod);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: failed to create ATR handle", symbol);
      return(false);
     }

   double buffer[];
   if(CopyBuffer(handle, 0, 1, 1, buffer) <= 0)
     {
      PrintFormat("%s: failed to copy ATR data", symbol);
      IndicatorRelease(handle);
      return(false);
     }

   value = buffer[0];
   IndicatorRelease(handle);
   return(true);
  }
//+------------------------------------------------------------------+
