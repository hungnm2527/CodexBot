#property strict

#include <Trade/Trade.mqh>
#include "Include/config.mqh"
#include "Include/utils.mqh"
#include "Include/indicators.mqh"
#include "Include/risk.mqh"
#include "Include/ui.mqh"

CTrade trade;
IndicatorHandles g_handles;

ENUM_TIMEFRAMES g_entry_tf;
ENUM_TIMEFRAMES g_ctx_tf;

datetime g_last_entry_bar = 0;
datetime g_last_ctx_bar = 0;

datetime g_last_signal_time = 0;
string g_last_signal_text = "NO TRADE";

int g_today_trades = 0;
double g_today_pnl = 0.0;

datetime g_last_trade_time = 0;

enum ENUM_REGIME { REGIME_TREND = 0, REGIME_RANGE = 1 };

struct RegimeState
  {
   ENUM_REGIME regime;
   string bias;
   double adx;
   double ema200;
   double close;
  };

int OnInit()
  {
   g_entry_tf = (InpEntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpEntryTF;
   g_ctx_tf = (InpContextTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpContextTF;

   if(!InitIndicators(g_handles, g_entry_tf, g_ctx_tf, InpEMA200Period, InpEMA50Period, InpEMA20Period,
                      InpADXPeriod, InpATRPeriod, InpRSIPeriod, InpStochKPeriod, InpStochDPeriod,
                      InpStochSlowing, InpBBPeriod, InpBBDev))
     {
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber((long)InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ReleaseIndicators(g_handles);
   if(InpUIEnabled)
      DeleteUIPanel(0);
  }

bool GetRegimeState(RegimeState &state)
  {
   double adx_now = 0.0;
   double adx_prev = 0.0;
   double ema200 = 0.0;
   double close = iClose(_Symbol, g_ctx_tf, 0);

   if(!CopyIndicatorValue(g_handles.adx_ctx, 0, 0, adx_now))
      return false;
   if(!CopyIndicatorValue(g_handles.adx_ctx, 0, 1, adx_prev))
      return false;
   if(!CopyIndicatorValue(g_handles.ema200_ctx, 0, 0, ema200))
      return false;

   bool adx_rising = adx_now > adx_prev;
   if(adx_now >= InpADXTrendThreshold && adx_rising)
     {
      state.regime = REGIME_TREND;
      state.bias = (close > ema200) ? "LONG" : "SHORT";
     }
   else
     {
      state.regime = REGIME_RANGE;
      state.bias = (close > ema200) ? "LONG" : "SHORT";
     }

   state.adx = adx_now;
   state.ema200 = ema200;
   state.close = close;
   return true;
  }

bool GetEntryIndicators(double &ema200, double &ema50, double &ema20, double &adx, double &atr, double &rsi,
                        double &stoch_k, double &stoch_d,
                        double &bb_upper, double &bb_mid, double &bb_lower)
  {
   if(!CopyIndicatorValue(g_handles.ema200_entry, 0, 1, ema200)) return false;
   if(!CopyIndicatorValue(g_handles.ema50_entry, 0, 1, ema50)) return false;
   if(!CopyIndicatorValue(g_handles.ema20_entry, 0, 1, ema20)) return false;
   if(!CopyIndicatorValue(g_handles.adx_entry, 0, 1, adx)) return false;
   if(!CopyIndicatorValue(g_handles.atr_entry, 0, 1, atr)) return false;
   if(!CopyIndicatorValue(g_handles.rsi_entry, 0, 1, rsi)) return false;

   if(!CopyIndicatorValue(g_handles.stoch_entry, 0, 1, stoch_k)) return false;
   if(!CopyIndicatorValue(g_handles.stoch_entry, 1, 1, stoch_d)) return false;

   if(!CopyIndicatorValue(g_handles.bands_entry, 0, 1, bb_upper)) return false;
   if(!CopyIndicatorValue(g_handles.bands_entry, 1, 1, bb_mid)) return false;
   if(!CopyIndicatorValue(g_handles.bands_entry, 2, 1, bb_lower)) return false;

   return true;
  }

bool CheckSqueeze(const double kc_mult, const int bars)
  {
   double bb_upper[];
   double bb_lower[];
   double ema20[];
   double atr[];
   int count = bars;

   if(!CopyIndicatorValues(g_handles.bands_entry, 0, 1, count, bb_upper)) return false;
   if(!CopyIndicatorValues(g_handles.bands_entry, 2, 1, count, bb_lower)) return false;
   if(!CopyIndicatorValues(g_handles.ema20_entry, 0, 1, count, ema20)) return false;
   if(!CopyIndicatorValues(g_handles.atr_entry, 0, 1, count, atr)) return false;

   for(int i = 0; i < count; i++)
     {
      double kc_upper = ema20[i] + kc_mult * atr[i];
      double kc_lower = ema20[i] - kc_mult * atr[i];
      if(!(bb_upper[i] < kc_upper && bb_lower[i] > kc_lower))
         return false;
     }
   return true;
  }

bool TrendSignal(const string bias, const double ema50, const double ema20, const double rsi, bool &is_buy)
  {
   double close_curr = iClose(_Symbol, g_entry_tf, 1);
   double close_prev = iClose(_Symbol, g_entry_tf, 2);
   double low_prev = iLow(_Symbol, g_entry_tf, 2);
   double high_prev = iHigh(_Symbol, g_entry_tf, 2);

   double rsi_curr = 0.0;
   double rsi_prev = 0.0;
   if(!CopyIndicatorValue(g_handles.rsi_entry, 0, 1, rsi_curr)) return false;
   if(!CopyIndicatorValue(g_handles.rsi_entry, 0, 2, rsi_prev)) return false;

   bool rsi_confirm_buy = (rsi_prev < InpRSIBuyLevel && rsi_curr > InpRSIBuyLevel) || (rsi_curr < 40.0 && rsi_curr > rsi_prev);
   bool rsi_confirm_sell = (rsi_prev > InpRSISellLevel && rsi_curr < InpRSISellLevel) || (rsi_curr > 60.0 && rsi_curr < rsi_prev);

   bool pullback_buy = (low_prev <= ema50 || close_prev <= ema50) && (close_curr > ema50);
   bool pullback_sell = (high_prev >= ema50 || close_prev >= ema50) && (close_curr < ema50);

   if(InpUseStoch)
     {
      double k_curr = 0.0, k_prev = 0.0, d_curr = 0.0, d_prev = 0.0;
      if(!CopyIndicatorValue(g_handles.stoch_entry, 0, 1, k_curr)) return false;
      if(!CopyIndicatorValue(g_handles.stoch_entry, 0, 2, k_prev)) return false;
      if(!CopyIndicatorValue(g_handles.stoch_entry, 1, 1, d_curr)) return false;
      if(!CopyIndicatorValue(g_handles.stoch_entry, 1, 2, d_prev)) return false;

      bool stoch_buy = (k_prev < d_prev && k_curr > d_curr && k_curr < InpStochOversold);
      bool stoch_sell = (k_prev > d_prev && k_curr < d_curr && k_curr > InpStochOverbought);

      if(bias == "LONG" && pullback_buy && stoch_buy)
        {
         is_buy = true;
         return true;
        }
      if(bias == "SHORT" && pullback_sell && stoch_sell)
        {
         is_buy = false;
         return true;
        }
     }
   else
     {
      if(bias == "LONG" && pullback_buy && rsi_confirm_buy)
        {
         is_buy = true;
         return true;
        }
      if(bias == "SHORT" && pullback_sell && rsi_confirm_sell)
        {
         is_buy = false;
         return true;
        }
     }

   return false;
  }

bool RangeSignal(const double bb_upper, const double bb_mid, const double bb_lower, const double rsi, bool &is_buy, double &tp_price, double &sl_price)
  {
   double close_prev = iClose(_Symbol, g_entry_tf, 2);
   double close_curr = iClose(_Symbol, g_entry_tf, 1);
   double low_prev = iLow(_Symbol, g_entry_tf, 2);
   double high_prev = iHigh(_Symbol, g_entry_tf, 2);
   double atr = 0.0;
   if(!CopyIndicatorValue(g_handles.atr_entry, 0, 1, atr))
      return false;

   bool buy_signal = (low_prev <= bb_lower || close_prev <= bb_lower) && close_curr > bb_lower && rsi < InpRSIOversold;
   bool sell_signal = (high_prev >= bb_upper || close_prev >= bb_upper) && close_curr < bb_upper && rsi > InpRSIOverbought;

   if(buy_signal)
     {
      is_buy = true;
      tp_price = (InpRangeTPTarget == RANGE_TP_MID) ? bb_mid : bb_upper;
      if(InpRangeSLMode == RANGE_SL_ATR)
         sl_price = close_curr - atr * InpSL_ATR_Mult;
      else
         sl_price = bb_lower - atr * InpSL_ATR_Mult;
      return true;
     }
   if(sell_signal)
     {
      is_buy = false;
      tp_price = (InpRangeTPTarget == RANGE_TP_MID) ? bb_mid : bb_lower;
      if(InpRangeSLMode == RANGE_SL_ATR)
         sl_price = close_curr + atr * InpSL_ATR_Mult;
      else
         sl_price = bb_upper + atr * InpSL_ATR_Mult;
      return true;
     }

   return false;
  }

bool CheckFilters(const double atr_points)
  {
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > InpMaxSpreadPoints)
      return false;
   if(atr_points < InpMinATRPoints)
      return false;

   datetime now = TimeCurrent();
   if(!IsWithinSession(now, InpUseSessionFilter, InpSessionStartHour, InpSessionEndHour))
      return false;
   if(IsManualBlocked(now, InpBlock1Start, InpBlock1End, InpBlock2Start, InpBlock2End))
      return false;

   return true;
  }

void SendSignalAlert(const string text)
  {
   if(InpAlertPopup)
      Alert(text);
   if(InpAlertSound)
      PlaySound("alert.wav");
   if(InpAlertPush)
      SendNotification(text);
   if(InpAlertEmail)
      SendMail("XAGUSD Signal", text);
  }

void UpdateUI(const RegimeState &state, const double ema200, const double ema50, const double adx, const double atr, const double rsi,
              const double sl_points, const double tp_points, const double lot)
  {
   if(!InpUIEnabled)
      return;
   string mode_txt = (InpMode == MODE_AUTO_TRADE) ? "AUTO" : "SIGNAL";
   string header = StringFormat("%s %s | Entry %s Context %s | %s", _Symbol, EnumToString(_Period), EnumToString(g_entry_tf), EnumToString(g_ctx_tf), mode_txt);
   string line1 = StringFormat("Regime: %s | Bias: %s | ADX: %.2f", state.regime == REGIME_TREND ? "TREND" : "RANGE", state.bias, state.adx);
   string line2 = StringFormat("EMA200: %.2f EMA50: %.2f | ATR: %.2f", ema200, ema50, atr);
   string line3 = StringFormat("RSI: %.2f | Spread: %.1f", rsi, (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point);
   string line4 = StringFormat("SL pts: %.1f TP pts: %.1f | Lot: %.2f", sl_points, tp_points, lot);
   string line5 = StringFormat("Daily Trades: %d | PnL: %.2f", g_today_trades, g_today_pnl);
   string line6 = StringFormat("Last Signal: %s", g_last_signal_text);
   string line7 = StringFormat("Signal Time: %s", g_last_signal_time == 0 ? "-" : TimeToStringShort(g_last_signal_time));

   UpdateUIPanel(0, InpPanelTextColor, InpPanelFontSize, header, line1, line2, line3, line4, line5, line6, line7);
  }

void ManageOpenPositions(const double atr)
  {
   if(PositionsTotal() == 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double risk = MathAbs(entry - sl);

      double trail_start = entry + (type == POSITION_TYPE_BUY ? risk * InpTrailStartRR : -risk * InpTrailStartRR);
      bool can_trail = (type == POSITION_TYPE_BUY) ? (price > trail_start) : (price < trail_start);

      double new_sl = sl;
      if(can_trail)
        {
         if(InpUseSuperTrendTrail)
           {
            double hl2 = (iHigh(_Symbol, g_entry_tf, 1) + iLow(_Symbol, g_entry_tf, 1)) / 2.0;
            double st = (type == POSITION_TYPE_BUY) ? hl2 - atr * InpSuperTrendMult : hl2 + atr * InpSuperTrendMult;
            new_sl = st;
           }
         else
           {
            new_sl = (type == POSITION_TYPE_BUY) ? price - atr * InpTrailATRMult : price + atr * InpTrailATRMult;
           }
        }

      if(InpUseBreakEven)
        {
         if(type == POSITION_TYPE_BUY && price >= entry + risk)
            new_sl = MathMax(new_sl, entry);
         if(type == POSITION_TYPE_SELL && price <= entry - risk)
            new_sl = MathMin(new_sl, entry);
        }

      if((type == POSITION_TYPE_BUY && new_sl > sl) || (type == POSITION_TYPE_SELL && new_sl < sl))
        {
         trade.PositionModify(_Symbol, new_sl, tp);
         DrawHLine(0, UI_PREFIX + "TRAIL", new_sl, clrYellow, "Trail");
        }
     }
  }

bool CanTradeNow()
  {
   if(InpMode != MODE_AUTO_TRADE)
      return false;

   if(CountOpenPositions(_Symbol, InpMagicNumber) >= InpMaxOpenPositions)
      return false;

   DailyStats stats;
   if(GetTodayStats(InpMagicNumber, stats))
     {
      g_today_trades = stats.trades;
      g_today_pnl = stats.pnl;
     }

   if(InpMaxTradesPerDay > 0 && g_today_trades >= InpMaxTradesPerDay)
      return false;

   if(InpDailyLossLimit > 0 && g_today_pnl <= -InpDailyLossLimit)
      return false;

   if(g_last_trade_time > 0 && (TimeCurrent() - g_last_trade_time) < InpCooldownMinutes * 60)
      return false;

   return true;
  }

void PlaceTrade(const bool is_buy, double sl_price, const double tp_price, const string comment)
  {
   double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl_points = MathAbs(price - sl_price) / _Point;
   if(sl_points < InpMinSLPoints)
     {
      sl_points = InpMinSLPoints;
      sl_price = is_buy ? price - sl_points * _Point : price + sl_points * _Point;
     }

   double lot = 0.0;
   if(!CalculateLotSize(_Symbol, InpRiskMode, InpRiskPercent, InpFixedLot, sl_points, lot))
      return;

   bool result = false;
   if(is_buy)
      result = trade.Buy(lot, _Symbol, price, sl_price, tp_price, comment);
   else
      result = trade.Sell(lot, _Symbol, price, sl_price, tp_price, comment);

   if(result)
     {
      g_last_trade_time = TimeCurrent();
      DrawHLine(0, UI_PREFIX + "SL", sl_price, clrRed, "SL");
      DrawHLine(0, UI_PREFIX + "TP", tp_price, clrLime, "TP");
     }
   else
     {
      PrintFormat("Order failed: %d", GetLastError());
     }
  }

void OnTick()
  {
   double atr = 0.0;
   if(!CopyIndicatorValue(g_handles.atr_entry, 0, 1, atr))
      return;

   ManageOpenPositions(atr);

   bool new_entry_bar = IsNewBar(g_entry_tf, g_last_entry_bar);
   bool new_ctx_bar = IsNewBar(g_ctx_tf, g_last_ctx_bar);
   if(!(new_entry_bar || new_ctx_bar))
      return;

   RegimeState state;
   if(!GetRegimeState(state))
      return;

   double ema200 = 0.0, ema50 = 0.0, ema20 = 0.0, adx = 0.0, rsi = 0.0;
   double stoch_k = 0.0, stoch_d = 0.0;
   double bb_upper = 0.0, bb_mid = 0.0, bb_lower = 0.0;
   if(!GetEntryIndicators(ema200, ema50, ema20, adx, atr, rsi, stoch_k, stoch_d, bb_upper, bb_mid, bb_lower))
      return;

   double sl_points = atr / _Point * InpSL_ATR_Mult;
   double tp_points = sl_points * InpRR;
   double lot_preview = 0.0;
   CalculateLotSize(_Symbol, InpRiskMode, InpRiskPercent, InpFixedLot, sl_points, lot_preview);
   UpdateUI(state, ema200, ema50, adx, atr, rsi, sl_points, tp_points, lot_preview);

   if(!new_entry_bar)
      return;

   double atr_points = atr / _Point;
   if(!CheckFilters(atr_points))
      return;

   bool signal = false;
   bool is_buy = false;
   double sl_price = 0.0;
   double tp_price = 0.0;
   string module = "";

   if(state.regime == REGIME_TREND && InpUseTrendModule)
     {
      if(TrendSignal(state.bias, ema50, ema20, rsi, is_buy))
        {
         signal = true;
         module = "Trend";
         double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         sl_price = is_buy ? price - atr * InpSL_ATR_Mult : price + atr * InpSL_ATR_Mult;
         tp_price = is_buy ? price + atr * InpSL_ATR_Mult * InpRR : price - atr * InpSL_ATR_Mult * InpRR;
        }
     }
   else if(state.regime == REGIME_RANGE && InpUseRangeModule && InpUseBands)
     {
      if(RangeSignal(bb_upper, bb_mid, bb_lower, rsi, is_buy, tp_price, sl_price))
        {
         signal = true;
         module = "Range";
        }
     }

   if(InpUseSqueeze && InpUseBands && CheckSqueeze(InpKCATRMultiplier, InpSqueezeBars))
     {
      double close_curr = iClose(_Symbol, g_entry_tf, 1);
      if(close_curr > bb_upper)
        {
         g_last_signal_text = "SQUEEZE BREAKOUT BUY";
         g_last_signal_time = TimeCurrent();
         SendSignalAlert(StringFormat("%s Squeeze BUY", _Symbol));
        }
      else if(close_curr < bb_lower)
        {
         g_last_signal_text = "SQUEEZE BREAKOUT SELL";
         g_last_signal_time = TimeCurrent();
         SendSignalAlert(StringFormat("%s Squeeze SELL", _Symbol));
        }
     }

   if(signal)
     {
      datetime signal_time = iTime(_Symbol, g_entry_tf, 1);
      g_last_signal_time = signal_time;
      g_last_signal_text = StringFormat("%s %s", module, is_buy ? "BUY" : "SELL");
      SendSignalAlert(StringFormat("%s %s signal", _Symbol, g_last_signal_text));

      DrawSignalArrow(0, UI_PREFIX + "ARROW_" + IntegerToString((int)signal_time), signal_time,
                      is_buy ? iLow(_Symbol, g_entry_tf, 1) : iHigh(_Symbol, g_entry_tf, 1),
                      is_buy ? clrLime : clrRed, is_buy);

      if(CanTradeNow())
        {
         if(!InpAllowHedge && HasOppositePosition(_Symbol, InpMagicNumber, is_buy ? POSITION_TYPE_SELL : POSITION_TYPE_BUY))
            return;

         string comment = StringFormat("%s|%s|%s", InpTradeComment, module, state.regime == REGIME_TREND ? "TREND" : "RANGE");
         PlaceTrade(is_buy, sl_price, tp_price, comment);
        }
     }
  }
