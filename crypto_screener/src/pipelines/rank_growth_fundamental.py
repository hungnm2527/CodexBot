from __future__ import annotations

import math
from typing import Any, Dict

import pandas as pd
import yaml


def load_config(config_path: str = "config.yaml") -> Dict[str, Any]:
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def zscore(series: pd.Series) -> pd.Series:
    s = pd.to_numeric(series, errors="coerce")
    mu = s.mean(skipna=True)
    sd = s.std(skipna=True)
    if sd is None or sd == 0 or (isinstance(sd, float) and math.isnan(sd)):
        return pd.Series([0.0] * len(s), index=s.index)
    return (s - mu) / sd


def weighted_score(df: pd.DataFrame, weights: Dict[str, float]) -> pd.Series:
    score = pd.Series([0.0] * len(df), index=df.index, dtype="float64")
    for col, w in weights.items():
        if col not in df.columns:
            raise ValueError(f"Missing column for scoring: {col}")
        score = score + float(w) * zscore(df[col]).fillna(0.0)
    return score


def run(config_path: str = "config.yaml") -> pd.DataFrame:
    cfg = load_config(config_path)
    paths = cfg["paths"]

    feats = pd.read_csv(paths["features_csv"])
    tvl = pd.read_csv(paths["tvl_features_csv"])

    merged = feats.merge(
        tvl[["id", "llama_slug", "tvl_usd", "tvl_change_7d", "tvl_change_30d", "tvl_mcap_ratio"]],
        on="id",
        how="left",
    )

    # Keep columns used in scoring
    # Ensure names exist from Step 3
    for c in ["ret_90d", "rs_90d_vs_btc", "vol_24h"]:
        if c not in merged.columns:
            raise ValueError(f"Missing {c} in merged features")

    w = cfg.get("scoring", {}).get("growth_fundamental_weights", {})

    weights = {
        "tvl_change_30d": w.get("tvl_change_30d", 0.35),
        "tvl_mcap_ratio": w.get("tvl_mcap_ratio", 0.20),
        "rs_90d_vs_btc": w.get("rs_90d_vs_btc", 0.20),
        "ret_90d": w.get("ret_90d", 0.15),
        "vol_24h": w.get("vol_24h", 0.10),
    }

    # NaNs in TVL columns: treat as neutral (0 z-score contribution)
    merged["growth_fundamental_score"] = weighted_score(merged, weights)

    ranked = merged.sort_values("growth_fundamental_score", ascending=False).copy()
    ranked.to_csv(paths["ranked_growth_fundamental_csv"], index=False)
    return ranked


if __name__ == "__main__":
    ranked = run("config.yaml")
    print("Saved:", "outputs/rankings/ranked_growth_fundamental.csv")
    print(ranked[["market_cap_rank", "symbol", "growth_fundamental_score", "tvl_change_30d", "tvl_mcap_ratio"]].head(15).to_string(index=False))
