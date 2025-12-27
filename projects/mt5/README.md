# MT5 Trading Project

This project contains the MetaTrader 5 Expert Advisors (EAs) and related assets for CodexBot.

## Layout
- `experts/` – Expert Advisors (.mq5). Current EAs: `SmartMoneyEA.mq5`, `MeanReversionEA.mq5`, `MartingaleEA.mq5`, `AlertRelayEA.mq5`.
- `indicators/` – Custom indicators (placeholder).
- `scripts/` – Utility scripts (placeholder).
- `include/` – Shared headers/libraries (placeholder).
- `profiles/`, `tester/` – Strategy tester and profile assets (placeholders).
- `build/` – Local compiled outputs (untracked).
- `docs/` – Project-specific documentation (placeholder).

## Usage
1. Copy the folders in `projects/mt5/` into your platform’s `MQL5` directory (or point MetaEditor to this path).
2. Open MetaEditor and compile the EAs in `experts/`.
3. Attach the compiled experts to a chart and adjust inputs as needed (risk %, swing size, lookbacks, reward-to-risk, symbol list, ATR multipliers, etc.).

## Notes
- Keep compiled artifacts (`*.ex5`) in `build/` locally; do not commit them.
- Shared code for new EAs should live in `include/` to avoid duplication.
