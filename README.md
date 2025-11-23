# CodexBot

This repository contains two MetaTrader 5 Expert Advisors **and** a standalone WordPress site (in `wordpress-site/`). The WordPress project is self-contained so it can be worked on separately from the trading code.

## WordPress site
See `wordpress-site/README.md` for how to run the magazine-style homepage locally with the bundled First Theme.

## MetaTrader EAs
This repository contains two MetaTrader 5 Expert Advisors:

1. **SmartMoneyEA.mq5** – applies a streamlined Smart Money Concept (SMC) approach. The EA looks for market structure bias, identifies order blocks, checks for fair value gap confluence, and places limit orders with dynamic position sizing.
2. **MeanReversionEA.mq5** – a high-probability mean-reversion system designed to achieve a trade accuracy near 70%. It scans a configurable list of symbols, waits for oversold/overbought conditions (RSI with Bollinger Bands confirmation), and automatically sizes trades, take profits, and stop losses using ATR-based distances.

## Usage
1. Copy any of the EA files (e.g., `SmartMoneyEA.mq5` or `MeanReversionEA.mq5`) into your `MQL5/Experts` folder.
2. Open MetaEditor, compile the expert, and attach it to a chart.
3. Adjust the inputs (risk %, swing size, lookbacks, reward-to-risk, symbol list, ATR multipliers, etc.) to match your preferences and instrument characteristics.
