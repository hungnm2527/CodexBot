# MQL5 Development Notes (Compilation Pitfalls)

This reference captures compile issues encountered while building the Heiken Ashi MTF EA and the fixes that resolved them.

## Pitfalls and Fixes

1. **Variable-length arrays (VLAs) are not allowed**
   - **Symptom:** compile errors such as `invalid index value` when declaring arrays with input-dependent sizes (e.g., `MqlRates rates[PullbackBars + 3];`).
   - **Fix:** use dynamic arrays and `ArrayResize` before calling `CopyRates`.
   - **Example:**
     ```mql5
     int needed = PullbackBars + 3;
     MqlRates rates[];
     ArrayResize(rates, needed);
     if(CopyRates(symbol, PERIOD_H1, 0, needed, rates) < needed)
        return;
     ```

2. **`PositionSelectByIndex` not available in some builds**
   - **Symptom:** `undeclared identifier` errors when compiling against terminals without `PositionSelectByIndex`.
   - **Fix:** select positions via ticket IDs.
   - **Example:**
     ```mql5
     bool SelectPositionByIndex(const int index)
       {
        ulong ticket = PositionGetTicket(index);
        if(ticket == 0)
           return(false);
        return(PositionSelectByTicket(ticket));
       }
     ```

3. **Avoid ambiguous identifier names (e.g., `now`)**
   - **Symptom:** `undeclared identifier` or parse errors tied to variable names that may conflict with built-ins or macros in some environments.
   - **Fix:** use more explicit names, such as `currentTime`.
   - **Example:**
     ```mql5
     datetime currentTime = TimeCurrent();
     int hour = TimeHour(currentTime);
     ```

4. **Prefer `TimeToStruct` for session hour extraction**
   - **Symptom:** some builds report `undeclared identifier` or parse errors around `TimeHour(...)`.
   - **Fix:** use `TimeToStruct` and access `MqlDateTime.hour`.
   - **Example:**
     ```mql5
     MqlDateTime dt;
     TimeToStruct(TimeCurrent(), dt);
     int hour = dt.hour;
     ```

5. **Enum values share the same namespace as variables**
   - **Symptom:** compile errors like `identifier 'FixedLot' already used` when an enum value matches an input or variable name.
   - **Fix:** prefix enum values (e.g., `LotModeFixedLot`, `RunnerTP_RR2`) to avoid collisions.
   - **Example:**
     ```mql5
     enum LotMode { LotModeFixedLot, LotModeRiskPercent };
     input LotMode lotMode = LotModeRiskPercent;
     ```

6. **Use `StringToUpper` instead of `StringUpper`**
   - **Symptom:** `undeclared identifier` or parse errors around `StringUpper` on some builds.
   - **Fix:** call `StringToUpper`.
   - **Example:**
     ```mql5
     string upper = StringToUpper(symbol);
     ```

## General Guidance

- Always prefer dynamic arrays for buffers sized by inputs or runtime values.
- When iterating positions, rely on `PositionGetTicket` + `PositionSelectByTicket` for portability.
- Use descriptive variable names to avoid conflicts across MQL5 builds.
