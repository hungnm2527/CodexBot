#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input string   InpAlertFileName      = "AlertRelay.log";    // File under \Files or common folder
input bool     InpUseCommonFiles     = true;                 // Monitor common files directory
input bool     InpStartFromFileEnd   = true;                 // Ignore historical content on start
input int      InpPollingSeconds     = 2;                    // Timer interval for file polling
input double   InpLots               = 0.10;                 // Trade volume
input int      InpATRPeriod          = 14;                   // ATR period
input double   InpATRMultiplier      = 1.5;                  // ATR multiplier for SL distance
input double   InpRiskReward         = 2.0;                  // Take-profit to stop-loss ratio
input bool     InpUseSignalTimeframe = true;                 // Use timeframe from alert for ATR
input ENUM_TIMEFRAMES InpFallbackATRTimeframe = PERIOD_M15;  // Fallback ATR timeframe

CTrade         trade;
long           g_lastPositionBytes = 0;
bool           g_fileCursorReady   = false;
int            g_lastErrorLogged   = 0;

//--- helpers
string Trim(const string value)
{
   string result = value;
   while(StringLen(result) > 0)
   {
      ushort c = StringGetCharacter(result, 0);
      if(c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '(')
         result = StringSubstr(result, 1);
      else
         break;
   }
   while(StringLen(result) > 0)
   {
      int lastIndex = StringLen(result) - 1;
      ushort c = StringGetCharacter(result, lastIndex);
      if(c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ')')
         result = StringSubstr(result, 0, lastIndex);
      else
         break;
   }
   return result;
}

bool ParseTimeframe(const string tfText, ENUM_TIMEFRAMES &tf)
{
   string upper = StringToUpper(tfText);
   if(upper == "M1")   { tf = PERIOD_M1;  return true; }
   if(upper == "M5")   { tf = PERIOD_M5;  return true; }
   if(upper == "M15")  { tf = PERIOD_M15; return true; }
   if(upper == "M30")  { tf = PERIOD_M30; return true; }
   if(upper == "H1")   { tf = PERIOD_H1;  return true; }
   if(upper == "H4")   { tf = PERIOD_H4;  return true; }
   if(upper == "D1")   { tf = PERIOD_D1;  return true; }
   if(upper == "W1")   { tf = PERIOD_W1;  return true; }
   if(upper == "MN1")  { tf = PERIOD_MN1; return true; }
   return false;
}

bool ParseAlertLine(const string line, string &symbol, int &direction, double &price, ENUM_TIMEFRAMES &signalTf)
{
   string trimmed = Trim(line);
   if(trimmed == "")
      return false;

   int slashPos = StringFind(trimmed, "/");
   if(slashPos < 0)
      return false;

   int tfStart = StringFind(trimmed, "<<", slashPos);
   if(tfStart < 0)
      return false;

   int tfEnd = StringFind(trimmed, ">>", tfStart);
   if(tfEnd < 0)
      return false;

   symbol = Trim(StringSubstr(trimmed, slashPos + 1, tfStart - (slashPos + 1)));
   int bracketPos = StringFind(symbol, "(");
   if(bracketPos >= 0)
      symbol = Trim(StringSubstr(symbol, 0, bracketPos));

   string tfText = Trim(StringSubstr(trimmed, tfStart + 2, tfEnd - (tfStart + 2)));
   if(!ParseTimeframe(tfText, signalTf))
      signalTf = InpFallbackATRTimeframe;

   int plusPos  = StringFind(trimmed, "+OB");
   int minusPos = StringFind(trimmed, "-OB");
   if(plusPos < 0 && minusPos < 0)
      return false;
   direction = (plusPos >= 0 && (minusPos < 0 || plusPos < minusPos)) ? 1 : -1;

   int equalsPos = StringFind(trimmed, "=");
   if(equalsPos < 0)
      return false;
   string pricePart = Trim(StringSubstr(trimmed, equalsPos + 1));
   price = StringToDouble(pricePart);
   if(price <= 0)
      price = 0;

   return symbol != "";
}

double RequestATR(const string symbol, ENUM_TIMEFRAMES tf)
{
   int handle = iATR(symbol, tf, InpATRPeriod);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[AlertRelayEA] Failed to create ATR handle for %s %s", symbol, EnumToString(tf));
      return 0.0;
   }
   double buffer[];
   if(CopyBuffer(handle, 0, 0, 1, buffer) != 1)
   {
      PrintFormat("[AlertRelayEA] CopyBuffer ATR failed for %s", symbol);
      IndicatorRelease(handle);
      return 0.0;
   }
   IndicatorRelease(handle);
   return buffer[0];
}

void ExecuteSignal(const string symbol, const int direction, const double alertPrice, const ENUM_TIMEFRAMES signalTf)
{
   if(symbol == "")
      return;

   if(!SymbolSelect(symbol, true))
   {
      PrintFormat("[AlertRelayEA] Unable to select symbol %s", symbol);
      return;
   }

   ENUM_TIMEFRAMES atrTf = InpUseSignalTimeframe ? signalTf : InpFallbackATRTimeframe;
   double atr = RequestATR(symbol, atrTf);
   if(atr <= 0)
   {
      PrintFormat("[AlertRelayEA] ATR unavailable for %s (%s)", symbol, EnumToString(atrTf));
      return;
   }

   double slDistance = atr * InpATRMultiplier;
   double tpDistance = slDistance * InpRiskReward;
   if(slDistance <= 0 || tpDistance <= 0)
   {
      Print("[AlertRelayEA] Invalid SL/TP distance");
      return;
   }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   double entryPrice = (direction > 0 ? ask : bid);
   double sl = (direction > 0 ? entryPrice - slDistance : entryPrice + slDistance);
   double tp = (direction > 0 ? entryPrice + tpDistance : entryPrice - tpDistance);

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   bool result = (direction > 0) ? trade.Buy(InpLots, symbol, entryPrice, sl, tp) : trade.Sell(InpLots, symbol, entryPrice, sl, tp);
   if(!result)
   {
      PrintFormat("[AlertRelayEA] OrderSend failed for %s (%s), retcode=%d", symbol, (direction > 0 ? "BUY" : "SELL"), trade.ResultRetcode());
   }
   else
   {
      if(alertPrice > 0)
         PrintFormat("[AlertRelayEA] %s order placed on %s at %.5f (alert %.5f, SL %.5f / TP %.5f)", (direction > 0 ? "BUY" : "SELL"), symbol, entryPrice, alertPrice, sl, tp);
      else
         PrintFormat("[AlertRelayEA] %s order placed on %s at %.5f (SL %.5f / TP %.5f)", (direction > 0 ? "BUY" : "SELL"), symbol, entryPrice, sl, tp);
   }
}

void PollAlertFile()
{
   int flags = FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   int handle = FileOpen(InpAlertFileName, flags);
   if(handle == INVALID_HANDLE)
   {
      int err = GetLastError();
      if(err != g_lastErrorLogged)
      {
         PrintFormat("[AlertRelayEA] Unable to open %s (error %d)", InpAlertFileName, err);
         g_lastErrorLogged = err;
      }
      return;
   }
   g_lastErrorLogged = 0;

   long fileSize = FileSize(handle);
   if(!g_fileCursorReady)
   {
      g_lastPositionBytes = InpStartFromFileEnd ? fileSize : 0;
      g_fileCursorReady = true;
   }
   else if(fileSize < g_lastPositionBytes)
   {
      g_lastPositionBytes = 0;
   }

   FileSeek(handle, g_lastPositionBytes, SEEK_SET);
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle, '\n');
      g_lastPositionBytes = FileTell(handle);
      if(line == "")
         continue;

      string symbol;
      int direction = 0;
      double price = 0.0;
      ENUM_TIMEFRAMES signalTf = InpFallbackATRTimeframe;
      if(ParseAlertLine(line, symbol, direction, price, signalTf))
      {
         ExecuteSignal(symbol, direction, price, signalTf);
      }
      else
      {
         PrintFormat("[AlertRelayEA] Unable to parse alert: %s", line);
      }
   }
   FileClose(handle);
}

int OnInit()
{
   if(InpPollingSeconds <= 0)
   {
      Print("[AlertRelayEA] Polling seconds must be greater than zero");
      return(INIT_PARAMETERS_INCORRECT);
   }
   EventSetTimer(InpPollingSeconds);
   Print("[AlertRelayEA] Initialized. Monitoring alerts from file: ", InpAlertFileName);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTick()
{
   // Trading logic is timer-driven to avoid missing alerts.
}

void OnTimer()
{
   PollAlertFile();
}
