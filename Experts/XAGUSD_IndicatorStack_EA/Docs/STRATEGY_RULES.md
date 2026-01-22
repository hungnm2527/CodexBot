# Strategy Rules

## Regime Definition (Context TF)
**TREND** when:
- ADX(Context, 14) ≥ ADX_Trend_Threshold, and ADX is rising (current > previous).
- Bias is determined by EMA200:
  - Close > EMA200 → LONG bias
  - Close < EMA200 → SHORT bias

**RANGE** when ADX is below the threshold or not rising.

## Trend Module (Entry TF)
**BUY**
- Bias LONG (Context).
- Pullback: previous bar touched/closed below EMA50 (EMA20 optional) and current bar closed above EMA50.
- RSI confirmation: RSI crosses above RSI_Buy_Level, or rebounds from < 40.
- Optional: Stochastic %K crosses above %D from oversold.

**SELL** (mirror conditions)

## Range Module (Entry TF)
Requires Bollinger Bands enabled.

**BUY**
- Previous bar touches/pierces lower BB.
- Current bar closes back inside BB.
- RSI < RSI_Oversold.

**SELL**
- Previous bar touches/pierces upper BB.
- Current bar closes back inside BB.
- RSI > RSI_Overbought.

**Targets**
- TP at BB mid band or opposite band (configurable).
- SL ATR-based or beyond band + ATR buffer (configurable).

## Squeeze Breakout (Optional)
- Compression when BB is inside Keltner Channel for N bars.
- Breakout when close breaks BB upper/lower with expanding range.
- Default: signal-only (can be enabled for trading).

## Risk Management Math
- **SL**: ATR(Entry TF) × SL_ATR_Mult, minimum SL enforced.
- **TP**: SL × RR.
- **Position Size**:
  - Risk amount = Equity × RiskPercent.
  - Value per point = TickValue / TickSize × Point.
  - Lot = RiskAmount / (SL points × Value per point).

## Examples
- Trend BUY: Context ADX rising, price above EMA200, entry TF pulls to EMA50 and RSI crosses above 50.
- Range SELL: Context ADX weak, upper BB touch, RSI > 70, closes inside band.
