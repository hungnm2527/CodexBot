# XAGUSD Indicator Stack EA — User Guide

## Installation
1. Copy the folder `Experts/XAGUSD_IndicatorStack_EA/` into your MetaTrader 5 `MQL5/Experts/` directory.
2. Open MetaEditor and compile `XAGUSD_IndicatorStack_EA.mq5`.
3. Restart MT5 or refresh the Navigator panel.
4. Drag the EA onto a XAGUSD chart (or any supported symbol).

## Attaching the EA
- **Entry TF**: Default is `PERIOD_CURRENT`. You can attach to any TF; the EA will use the chart TF unless overridden.
- **Context TF**: Default `H1`. For H1 swing, use `H4` or `D1`.

## Modes
- **MODE_AUTO_TRADE**: Places and manages trades.
- **MODE_SIGNAL_ONLY**: Displays signals, alerts, and on-chart UI without opening trades.

## Inputs Overview
### Indicator Modules
- **Trend Module**: Pullback to EMA50/EMA20 + RSI (or Stoch) confirmation.
- **Range Module**: BB mean-reversion; only active in RANGE regime and when BB enabled.
- **Squeeze**: BB inside KC for N bars, breakout detection (signal-only by default).

### Filters
- **MaxSpreadPoints**: Avoids high spread.
- **MinATRPoints**: Avoids low-volatility sessions.
- **Session Filter**: Default London/NY overlap. Toggle off for 24h.
- **Manual Block Time**: Two block windows (HH:MM) for news or broker maintenance.

### Risk Controls
- **RiskMode**: Fixed lot or % equity.
- **MaxTradesPerDay / DailyLossLimit / CooldownMinutes**: Prevents overtrading.

### Alerts
Popup, sound, push, email are available (off by default).

## On-Chart UI
The panel shows:
- Regime + bias
- Key indicator values
- Spread, ATR, SL/TP, Lot
- Daily trades and PnL (history-based)
- Latest signal and timestamp

## Presets
- **XAGUSD_M5_Scalp.set**: Tight filters, lower RR.
- **XAGUSD_M15_Intraday.set**: Balanced.
- **XAGUSD_H1_Swing.set**: Wider ATR, fewer trades.

## Troubleshooting
- If you see no trades, check session filter, manual block time, or MaxSpreadPoints.
- Ensure AutoTrading is enabled in MT5.
- Verify symbol specs (tick value/size) in the Market Watch.

## Backtesting (Strategy Tester)
1. Open Strategy Tester and select `XAGUSD_IndicatorStack_EA`.
2. Set **Model** to “Every tick based on real ticks” when possible.
3. Choose a representative date range and your desired preset.
4. Key metrics: Profit Factor, max drawdown, win rate, average trade, recovery factor.

## Exness Symbol Validation
- Check `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_TRADE_TICK_SIZE`, and lot step.
- Confirm the EA’s lot calculation aligns with your broker’s spec.

## Common Pitfalls
- Spread spikes at rollover can cause skipped trades.
- Tick volume is not real volume; use it as a proxy only.
- Ensure your VPS time matches broker server time for session filters.
