from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Tuple

import pandas as pd
import yaml

from src.utils import ensure_dir


def load_config(config_path: str = "config.yaml") -> Dict[str, Any]:
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def non_null_count(row: pd.Series, cols: List[str]) -> int:
    return int(row[cols].notna().sum())


def apply_timing_gate(df: pd.DataFrame, cfg: Dict[str, Any]) -> Tuple[pd.DataFrame, pd.DataFrame]:
    gate = cfg.get("timing_gate", {})

    require_ret_90d = bool(gate.get("require_ret_90d_positive", True))
    require_rs_90d = bool(gate.get("require_rs_90d_vs_btc_positive", True))
    max_ret_30d = gate.get("max_ret_30d", None)
    min_non_null_required = int(gate.get("min_non_null_required", 3))

    # Columns we expect from Step 3
    needed_cols = ["ret_7d", "ret_30d", "ret_90d", "rs_90d_vs_btc"]
    missing = [c for c in needed_cols if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required feature columns in features.csv: {missing}")

    df = df.copy()

    df["data_quality_non_null"] = df.apply(lambda r: non_null_count(r, needed_cols), axis=1)

    # Base gate
    cond = df["data_quality_non_null"] >= min_non_null_required

    if require_ret_90d:
        cond = cond & (df["ret_90d"] > 0)

    if require_rs_90d:
        cond = cond & (df["rs_90d_vs_btc"] > 0)

    passed = df[cond].copy()
    failed = df[~cond].copy()

    # Extension check -> move to watchlist
    watchlist = pd.DataFrame(columns=df.columns)
    if max_ret_30d is not None and str(max_ret_30d).lower() not in ("null", ""):
        max_ret_30d = float(max_ret_30d)
        too_hot = passed["ret_30d"].fillna(-999) > max_ret_30d
        watchlist = passed[too_hot].copy()
        passed = passed[~too_hot].copy()

        watchlist["timing_note"] = f"Too extended: ret_30d > {max_ret_30d:.2f}"

    passed["timing_note"] = "PASS"
    failed["timing_note"] = "FAIL"

    return passed, watchlist


def build_suggestions(config_path: str = "config.yaml") -> Tuple[pd.DataFrame, pd.DataFrame]:
    cfg = load_config(config_path)
    paths = cfg["paths"]
    gate = cfg.get("timing_gate", {})

    features_csv = paths["features_csv"]
    ranked_momentum_csv = paths["ranked_momentum_csv"]
    ranked_growth_csv = paths["ranked_growth_csv"]

    ensure_dir(Path(paths["suggestions_dir"]))

    feats = pd.read_csv(features_csv)
    mom = pd.read_csv(ranked_momentum_csv)
    gr = pd.read_csv(ranked_growth_csv)

    # Merge scores into features (by id is safest)
    cols_keep = ["id", "symbol", "name", "market_cap_rank", "market_cap", "vol_24h",
                 "ret_7d", "ret_30d", "ret_90d", "rs_90d_vs_btc"]
    feats_small = feats[cols_keep].copy()

    mom_small = mom[["id", "momentum_score"]].copy()
    gr_small = gr[["id", "growth_score"]].copy()

    merged = feats_small.merge(mom_small, on="id", how="left").merge(gr_small, on="id", how="left")

    passed, watchlist = apply_timing_gate(merged, cfg)

    # Build two top lists
    top_n_mom = int(gate.get("top_n_momentum", 10))
    top_n_gr = int(gate.get("top_n_growth", 10))

    top_mom = passed.sort_values("momentum_score", ascending=False).head(top_n_mom).copy()
    top_mom["bucket"] = "TOP_MOMENTUM"

    top_gr = passed.sort_values("growth_score", ascending=False).head(top_n_gr).copy()
    top_gr["bucket"] = "TOP_GROWTH"

    # Combine + de-duplicate by id (prefer momentum bucket if both)
    suggested = pd.concat([top_mom, top_gr], ignore_index=True)
    suggested = suggested.sort_values(["bucket", "momentum_score"], ascending=[True, False])
    suggested = suggested.drop_duplicates(subset=["id"], keep="first")

    # Nice ordering
    suggested = suggested.sort_values(["bucket", "market_cap_rank"], ascending=[True, True])

    out_suggested = Path(paths["suggested_today_csv"])
    out_watchlist = Path(paths["watchlist_csv"])

    suggested.to_csv(out_suggested, index=False)
    watchlist.to_csv(out_watchlist, index=False)

    return suggested, watchlist


if __name__ == "__main__":
    suggested, watchlist = build_suggestions("config.yaml")
    print(f"Suggested rows: {len(suggested)} -> outputs/suggestions/suggested_today.csv")
    print(f"Watchlist rows: {len(watchlist)} -> outputs/suggestions/watchlist.csv")
    if len(suggested) > 0:
        print("\nSuggested preview:")
        print(suggested[["bucket","market_cap_rank","symbol","ret_30d","ret_90d","rs_90d_vs_btc","momentum_score","growth_score"]].to_string(index=False))