#ifndef XAGUSD_STACK_CONFIG_MQH
#define XAGUSD_STACK_CONFIG_MQH

//=== Enums ===
enum ENUM_EA_MODE
  {
   MODE_AUTO_TRADE = 0,
   MODE_SIGNAL_ONLY = 1
  };

enum ENUM_RISK_MODE
  {
   RISK_FIXED_LOT = 0,
   RISK_PERCENT = 1
  };

enum ENUM_RANGE_TP_TARGET
  {
   RANGE_TP_MID = 0,
   RANGE_TP_OPPOSITE = 1
  };

enum ENUM_RANGE_SL_MODE
  {
   RANGE_SL_ATR = 0,
   RANGE_SL_BAND_ATR = 1
  };

//=== Inputs ===
input ENUM_EA_MODE      InpMode                = MODE_AUTO_TRADE;
input ENUM_TIMEFRAMES   InpEntryTF             = PERIOD_CURRENT;
input ENUM_TIMEFRAMES   InpContextTF           = PERIOD_H1;
input ulong             InpMagicNumber         = 25012025;
input string            InpTradeComment        = "XAGUSD_IndicatorStack";
input int               InpDeviationPoints     = 30;
input bool              InpAllowHedge          = false;

// Indicator toggles
input bool              InpUseTrendModule      = true;
input bool              InpUseRangeModule      = true;
input bool              InpUseStoch            = false;
input bool              InpUseBands            = true;
input bool              InpUseSqueeze          = false;
input bool              InpUseSuperTrendTrail  = false;

// Indicator periods
input int               InpEMA200Period        = 200;
input int               InpEMA50Period         = 50;
input int               InpEMA20Period         = 20;
input int               InpADXPeriod           = 14;
input int               InpATRPeriod           = 14;
input int               InpRSIPeriod           = 14;
input int               InpStochKPeriod        = 14;
input int               InpStochDPeriod        = 3;
input int               InpStochSlowing        = 3;
input int               InpBBPeriod            = 20;
input double            InpBBDev               = 2.0;
input double            InpKCATRMultiplier     = 1.5;
input double            InpSuperTrendMult      = 3.0;

// Thresholds
input double            InpADXTrendThreshold   = 25.0;
input double            InpRSIBuyLevel         = 50.0;
input double            InpRSISellLevel        = 50.0;
input double            InpRSIOversold         = 30.0;
input double            InpRSIOverbought       = 70.0;
input double            InpStochOversold       = 20.0;
input double            InpStochOverbought     = 80.0;
input int               InpSqueezeBars         = 5;

// Market filters
input int               InpMaxSpreadPoints     = 40;
input int               InpMinATRPoints        = 25;
input bool              InpUseSessionFilter    = true;
input int               InpSessionStartHour    = 13; // server time
input int               InpSessionEndHour      = 17; // server time
input string            InpBlock1Start         = ""; // HH:MM
input string            InpBlock1End           = "";
input string            InpBlock2Start         = "";
input string            InpBlock2End           = "";

// Risk management
input ENUM_RISK_MODE    InpRiskMode            = RISK_PERCENT;
input double            InpRiskPercent         = 0.5;
input double            InpFixedLot            = 0.01;
input int               InpMaxOpenPositions    = 1;
input int               InpMaxTradesPerDay     = 3;
input double            InpDailyLossLimit      = 0.0; // currency, 0=disabled
input int               InpCooldownMinutes     = 30;

// Stops & targets
input double            InpSL_ATR_Mult         = 1.5;
input double            InpRR                  = 1.5;
input int               InpMinSLPoints         = 50;
input bool              InpUseBreakEven        = true;
input double            InpTrailATRMult        = 1.2;
input double            InpTrailStartRR        = 1.0;
input ENUM_RANGE_TP_TARGET InpRangeTPTarget    = RANGE_TP_MID;
input ENUM_RANGE_SL_MODE  InpRangeSLMode       = RANGE_SL_ATR;

// Alerts
input bool              InpAlertPopup          = false;
input bool              InpAlertSound          = false;
input bool              InpAlertPush           = false;
input bool              InpAlertEmail          = false;

// UI
input bool              InpUIEnabled           = true;
input color             InpPanelBgColor        = clrBlack;
input color             InpPanelTextColor      = clrWhite;
input int               InpPanelFontSize       = 9;

#endif // XAGUSD_STACK_CONFIG_MQH
