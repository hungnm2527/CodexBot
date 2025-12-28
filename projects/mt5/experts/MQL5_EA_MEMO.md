# MQL5 EA implementation memo

Guidelines compiled from recent compile issues to avoid regressions when building Expert Advisors:

1) **SymbolInfo* overloads**
   - Prefer the 3-argument overloads (`SymbolInfoInteger/Double(symbol, prop, outVar)`) and check the returned `bool` before using the value.
   - Do not mix up property enums: use `ENUM_SYMBOL_INFO_INTEGER` for integer properties (e.g., `SYMBOL_SPREAD`, `SYMBOL_VOLUME_DIGITS`) and `ENUM_SYMBOL_INFO_DOUBLE` for doubles (e.g., `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_VOLUME_STEP`).
   - Guard against `0`/invalid values to avoid division by zero in risk sizing.

2) **String utilities**
   - `StringToUpper/StringToLower` return the converted string; they do **not** modify in place. Assign the return to your variable.
   - `StringSplit` with a single-character separator expects a `ushort` delimiter; pass `(ushort)','` and capture output into a `string &array[]`.

3) **Arrays & references**
   - Functions taking arrays must declare parameters by reference (`type &arr[]`). Do not pass constants or temporary expressions to such parameters.
   - When comparing symbols against exclusion lists, copy to mutable strings and uppercase them before comparing.

4) **Enum vs numeric conversions**
   - Watch for implicit narrowing (double ➜ int). Explicitly cast if safe, or adjust the receiving type to `double/long`.
   - Avoid passing enums where numeric values are required (and vice versa); mismatches trigger “cannot convert enum” errors.

5) **Risk and price math**
   - Always retrieve tick size/value and volume step/limits via `SymbolInfo*` before sizing orders.
   - Normalize volumes using `SYMBOL_VOLUME_STEP` and price digits from `SYMBOL_DIGITS`; bail out if property reads fail.
   - Use `AccountInfoDouble(ACCOUNT_EQUITY)` for equity-based sizing instead of deprecated helpers.

6) **General compile hygiene**
   - Check every broker constraint (stop level/freeze level) using `SymbolInfoInteger` before placing/modifying stops.
   - Use closed bar data (e.g., `CopyRates(..., shift=1)`) to avoid repainting signals.
   - Filter symbols before scanning: require `SYMBOL_TRADE_MODE` not disabled and positive `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_STEP`.

Keep this memo close when adding or editing EAs to prevent repeat compile errors.***
