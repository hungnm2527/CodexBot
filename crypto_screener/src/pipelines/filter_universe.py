from __future__ import annotations

from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any

import pandas as pd
import yaml

from src.utils import ensure_dir


REQUIRED_COLS = [
    "id",
    "symbol",
    "name",
    "market_cap_rank",
    "market_cap",
    "total_volume",
    "current_price",
    "circulating_supply",
    "total_supply",
    "max_supply",
    "price_change_percentage_24h",
    "last_updated",
]


def load_config(config_path: str = "config.yaml") -> Dict[str, Any]:
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def validate_input(df: pd.DataFrame) -> None:
    missing = [c for c in REQUIRED_COLS if c not in df.columns]
    if missing:
        raise ValueError(f"Universe CSV missing required columns: {missing}")


def compute_reject_reasons(
    df: pd.DataFrame,
    *,
    min_market_cap: float,
    min_volume: float,
    max_rank: Optional[int],
) -> pd.DataFrame:
    # Start with empty list of reasons per row
    reasons: List[List[str]] = [[] for _ in range(len(df))]

    # Missing critical data
    mc_missing = df["market_cap"].isna()
    vol_missing = df["total_volume"].isna()
    rank_missing = df["market_cap_rank"].isna()

    for i in df.index[mc_missing | vol_missing]:
        reasons[df.index.get_loc(i)].append("MISSING_MARKET_DATA")

    # Low market cap
    low_mc = df["market_cap"].fillna(0) < float(min_market_cap)
    for i in df.index[low_mc]:
        reasons[df.index.get_loc(i)].append("LOW_MARKET_CAP")

    # Low volume
    low_vol = df["total_volume"].fillna(0) < float(min_volume)
    for i in df.index[low_vol]:
        reasons[df.index.get_loc(i)].append("LOW_VOLUME")

    # Rank filter (optional)
    if max_rank is not None:
        bad_rank = df["market_cap_rank"].fillna(10**9).astype(int) > int(max_rank)
        for i in df.index[bad_rank]:
            reasons[df.index.get_loc(i)].append("RANK_TOO_LOW")

    out = df.copy()
    out["reject_reasons"] = ["|".join(r) if r else "" for r in reasons]
    out["is_rejected"] = out["reject_reasons"].ne("")
    return out


def run_filter_pipeline(config_path: str = "config.yaml") -> Tuple[pd.DataFrame, pd.DataFrame]:
    cfg = load_config(config_path)

    universe_csv = cfg["paths"]["universe_csv"]
    filtered_csv = cfg["paths"]["filtered_universe_csv"]
    rejects_csv = cfg["paths"]["rejects_csv"]
    out_dir = Path(cfg["paths"]["filtered_dir"])

    ensure_dir(out_dir)

    df = pd.read_csv(universe_csv)
    validate_input(df)

    # Ensure numeric types
    for col in ["market_cap", "total_volume", "market_cap_rank"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    fcfg = cfg.get("filters", {})
    min_market_cap = float(fcfg.get("min_market_cap_usd", 200_000_000))
    min_volume = float(fcfg.get("min_volume_24h_usd", 10_000_000))
    max_rank = fcfg.get("max_market_cap_rank", None)
    if max_rank in ("null", "", None):
        max_rank = None
    else:
        max_rank = int(max_rank)

    tagged = compute_reject_reasons(
        df,
        min_market_cap=min_market_cap,
        min_volume=min_volume,
        max_rank=max_rank,
    )

    # Split outputs
    rejects = tagged[tagged["is_rejected"]].copy()
    filtered = tagged[~tagged["is_rejected"]].copy()

    # Keep ordering deterministic
    filtered = filtered.sort_values("market_cap_rank", ascending=True)
    rejects = rejects.sort_values("market_cap_rank", ascending=True)

    filtered.to_csv(filtered_csv, index=False)
    rejects.to_csv(rejects_csv, index=False)

    return filtered, rejects


if __name__ == "__main__":
    filtered, rejects = run_filter_pipeline("config.yaml")
    print(f"Filtered universe rows: {len(filtered)}")
    print(f"Rejected rows: {len(rejects)}")
    print("Saved:")
    print(" - outputs/filtered/filtered_universe.csv")
    print(" - outputs/filtered/rejects.csv")