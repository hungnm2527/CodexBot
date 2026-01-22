#ifndef XAGUSD_STACK_INDICATORS_MQH
#define XAGUSD_STACK_INDICATORS_MQH

struct IndicatorHandles
  {
   int ema200_entry;
   int ema50_entry;
   int ema20_entry;
   int adx_entry;
   int atr_entry;
   int rsi_entry;
   int stoch_entry;
   int bands_entry;
   int ema200_ctx;
   int adx_ctx;
   int atr_ctx;
   int rsi_ctx;
   int ema20_ctx;
  };

bool InitIndicators(IndicatorHandles &h, const ENUM_TIMEFRAMES entry_tf, const ENUM_TIMEFRAMES ctx_tf,
                    const int ema200, const int ema50, const int ema20, const int adx_p, const int atr_p, const int rsi_p,
                    const int stoch_k, const int stoch_d, const int stoch_slow, const int bb_p, const double bb_dev)
  {
   h.ema200_entry = iMA(_Symbol, entry_tf, ema200, 0, MODE_EMA, PRICE_CLOSE);
   h.ema50_entry  = iMA(_Symbol, entry_tf, ema50, 0, MODE_EMA, PRICE_CLOSE);
   h.ema20_entry  = iMA(_Symbol, entry_tf, ema20, 0, MODE_EMA, PRICE_CLOSE);
   h.adx_entry    = iADX(_Symbol, entry_tf, adx_p);
   h.atr_entry    = iATR(_Symbol, entry_tf, atr_p);
   h.rsi_entry    = iRSI(_Symbol, entry_tf, rsi_p, PRICE_CLOSE);
   h.stoch_entry  = iStochastic(_Symbol, entry_tf, stoch_k, stoch_d, stoch_slow, MODE_SMA, STO_LOWHIGH);
   h.bands_entry  = iBands(_Symbol, entry_tf, bb_p, 0, bb_dev, PRICE_CLOSE);

   h.ema200_ctx = iMA(_Symbol, ctx_tf, ema200, 0, MODE_EMA, PRICE_CLOSE);
   h.ema20_ctx  = iMA(_Symbol, ctx_tf, ema20, 0, MODE_EMA, PRICE_CLOSE);
   h.adx_ctx    = iADX(_Symbol, ctx_tf, adx_p);
   h.atr_ctx    = iATR(_Symbol, ctx_tf, atr_p);
   h.rsi_ctx    = iRSI(_Symbol, ctx_tf, rsi_p, PRICE_CLOSE);

   if(h.ema200_entry == INVALID_HANDLE || h.ema50_entry == INVALID_HANDLE || h.ema20_entry == INVALID_HANDLE ||
      h.adx_entry == INVALID_HANDLE || h.atr_entry == INVALID_HANDLE || h.rsi_entry == INVALID_HANDLE ||
      h.stoch_entry == INVALID_HANDLE || h.bands_entry == INVALID_HANDLE || h.ema200_ctx == INVALID_HANDLE ||
      h.adx_ctx == INVALID_HANDLE || h.atr_ctx == INVALID_HANDLE || h.rsi_ctx == INVALID_HANDLE || h.ema20_ctx == INVALID_HANDLE)
     {
      PrintFormat("Indicator handle init failed. Error: %d", GetLastError());
      return false;
     }
   return true;
  }

void ReleaseIndicators(IndicatorHandles &h)
  {
   if(h.ema200_entry != INVALID_HANDLE) IndicatorRelease(h.ema200_entry);
   if(h.ema50_entry != INVALID_HANDLE) IndicatorRelease(h.ema50_entry);
   if(h.ema20_entry != INVALID_HANDLE) IndicatorRelease(h.ema20_entry);
   if(h.adx_entry != INVALID_HANDLE) IndicatorRelease(h.adx_entry);
   if(h.atr_entry != INVALID_HANDLE) IndicatorRelease(h.atr_entry);
   if(h.rsi_entry != INVALID_HANDLE) IndicatorRelease(h.rsi_entry);
   if(h.stoch_entry != INVALID_HANDLE) IndicatorRelease(h.stoch_entry);
   if(h.bands_entry != INVALID_HANDLE) IndicatorRelease(h.bands_entry);
   if(h.ema200_ctx != INVALID_HANDLE) IndicatorRelease(h.ema200_ctx);
   if(h.adx_ctx != INVALID_HANDLE) IndicatorRelease(h.adx_ctx);
   if(h.atr_ctx != INVALID_HANDLE) IndicatorRelease(h.atr_ctx);
   if(h.rsi_ctx != INVALID_HANDLE) IndicatorRelease(h.rsi_ctx);
   if(h.ema20_ctx != INVALID_HANDLE) IndicatorRelease(h.ema20_ctx);
  }

bool CopyIndicatorValue(const int handle, const int buffer, const int shift, double &value)
  {
   double temp[];
   ArraySetAsSeries(temp, true);
   if(CopyBuffer(handle, buffer, shift, 1, temp) != 1)
     {
      return false;
     }
   value = temp[0];
   return true;
  }

bool CopyIndicatorValues(const int handle, const int buffer, const int start_shift, const int count, double &dest[])
  {
   ArraySetAsSeries(dest, true);
   if(CopyBuffer(handle, buffer, start_shift, count, dest) != count)
     {
      return false;
     }
   return true;
  }

#endif // XAGUSD_STACK_INDICATORS_MQH
