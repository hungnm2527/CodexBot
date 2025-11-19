# CodexBot

This repository contains a sample MetaTrader 5 Expert Advisor that applies a streamlined Smart Money Concept (SMC) approach. The EA looks for market structure bias, identifies order blocks, checks for fair value gap confluence, and places limit orders with dynamic position sizing.

## Usage
1. Copy `SmartMoneyEA.mq5` into your `MQL5/Experts` folder.
2. Open MetaEditor, compile the expert, and attach it to a chart.
3. Adjust the inputs (risk %, swing size, lookbacks, reward-to-risk) to match your preferences and instrument characteristics.
