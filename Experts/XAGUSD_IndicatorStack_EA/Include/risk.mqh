#ifndef XAGUSD_STACK_RISK_MQH
#define XAGUSD_STACK_RISK_MQH

struct DailyStats
  {
   int trades;
   double pnl;
  };

bool GetTodayStats(const ulong magic, DailyStats &stats)
  {
   stats.trades = 0;
   stats.pnl = 0.0;
   datetime from = (datetime)StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime to = TimeCurrent();
   if(!HistorySelect(from, to))
      return false;

   uint total = HistoryDealsTotal();
   for(uint i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)magic)
         continue;
      int entry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
         stats.trades++;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      stats.pnl += profit + swap + commission;
     }
   return true;
  }

int CountOpenPositions(const string symbol, const ulong magic)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!PositionSelectByIndex(i))
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym != symbol)
         continue;
      ulong pos_magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(pos_magic != magic)
         continue;
      count++;
     }
   return count;
  }

bool HasOppositePosition(const string symbol, const ulong magic, const ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!PositionSelectByIndex(i))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type != type)
         return true;
     }
   return false;
  }

bool NormalizeLot(const string symbol, double &lot)
  {
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0)
      return false;
   lot = MathMax(min_lot, MathMin(max_lot, lot));
   lot = MathFloor(lot / step) * step;
   lot = NormalizeDouble(lot, 2);
   if(lot < min_lot)
      lot = min_lot;
   return true;
  }

bool CalculateLotSize(const string symbol, const ENUM_RISK_MODE mode, const double risk_percent, const double fixed_lot,
                      const double sl_points, double &lot_out)
  {
   if(mode == RISK_FIXED_LOT)
     {
      lot_out = fixed_lot;
      return NormalizeLot(symbol, lot_out);
     }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amount = equity * (risk_percent / 100.0);

   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tick_size <= 0 || point <= 0)
      return false;

   double value_per_point = tick_value / tick_size * point;
   if(value_per_point <= 0)
      return false;

   double risk_per_lot = sl_points * value_per_point;
   if(risk_per_lot <= 0)
      return false;

   lot_out = risk_amount / risk_per_lot;
   return NormalizeLot(symbol, lot_out);
  }

#endif // XAGUSD_STACK_RISK_MQH
