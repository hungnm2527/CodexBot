from __future__ import annotations

import math
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
import yaml

from src.utils import ensure_dir
from src.clients.coingecko import CoinGeckoClient, load_cache, save_cache


def load_config(config_path: str = "config.yaml") -> Dict[str, Any]:
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def pct_change(current: float, past: float) -> Optional[float]:
    if past is None or past == 0 or current is None:
        return None
    return (current / past) - 1.0


def last_price_from_chart(chart: Dict[str, Any]) -> Optional[float]:
    prices = chart.get("prices", [])
    if not prices:
        return None
    return float(prices[-1][1])


def first_price_from_chart(chart: Dict[str, Any]) -> Optional[float]:
    prices = chart.get("prices", [])
    if not prices:
        return None
    return float(prices[0][1])


def fetch_price_return(
    client: CoinGeckoClient,
    cache_dir: str,
    cache_enabled: bool,
    ttl_hours: int,
    coin_id: str,
    vs_currency: str,
    days: int,
) -> Optional[float]:
    key = f"market_chart__{coin_id}__{vs_currency}__{days}d"
    data = None
    if cache_enabled:
        data = load_cache(cache_dir, key, ttl_hours)
    if data is None:
        data = client.market_chart(coin_id=coin_id, vs_currency=vs_currency, days=days)
        if cache_enabled:
            save_cache(cache_dir, key, data)

    p0 = first_price_from_chart(data)
    p1 = last_price_from_chart(data)
    if p0 is None or p1 is None:
        return None
    return pct_change(p1, p0)


def zscore(series: pd.Series) -> pd.Series:
    s = pd.to_numeric(series, errors="coerce")
    mu = s.mean(skipna=True)
    sd = s.std(skipna=True)
    if sd is None or sd == 0 or math.isnan(sd):
        return pd.Series([0.0] * len(s), index=s.index)
    return (s - mu) / sd


def weighted_score(df: pd.DataFrame, weights: Dict[str, float]) -> pd.Series:
    # Use z-scores so different scales combine well
    score = pd.Series([0.0] * len(df), index=df.index, dtype="float64")
    for col, w in weights.items():
        if col not in df.columns:
            raise ValueError(f"Missing feature column for scoring: {col}")
        score = score + float(w) * zscore(df[col]).fillna(0.0)
    return score


def run_step3(config_path: str = "config.yaml") -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    cfg = load_config(config_path)
    paths = cfg["paths"]
    feat_cfg = cfg.get("features", {})
    scoring = cfg.get("scoring", {})

    filtered_csv = paths["filtered_universe_csv"]
    features_csv = paths["features_csv"]
    ranked_momentum_csv = paths["ranked_momentum_csv"]
    ranked_growth_csv = paths["ranked_growth_csv"]

    ensure_dir(Path(paths["features_dir"]))
    ensure_dir(Path(paths["rankings_dir"]))

    df = pd.read_csv(filtered_csv)

    # Optional: limit number of coins for fast testing
    max_coins = feat_cfg.get("max_coins", None)
    if max_coins not in (None, "null", ""):
        df = df.sort_values("market_cap_rank").head(int(max_coins)).copy()
    else:
        df = df.sort_values("market_cap_rank").copy()

    # Setup client
    base_url = cfg["coingecko"]["base_url"]
    delay_s = float(feat_cfg.get("request_delay_s", 1.2))
    client = CoinGeckoClient(base_url=base_url, min_delay_s=delay_s)

    vs_currency = feat_cfg.get("vs_currency", "usd")
    lookbacks: List[int] = list(feat_cfg.get("lookback_days", [7, 30, 90]))
    cache_enabled = bool(feat_cfg.get("cache_enabled", True))
    ttl_hours = int(feat_cfg.get("cache_ttl_hours", 24))
    cache_dir = str(paths.get("cache_dir", "data_cache"))

    # Compute BTC baseline returns (for RS)
    btc_ret: Dict[int, Optional[float]] = {}
    for d in lookbacks:
        btc_ret[d] = fetch_price_return(
            client, cache_dir, cache_enabled, ttl_hours,
            coin_id="bitcoin", vs_currency=vs_currency, days=int(d)
        )

    # Build features
    rows = []
    for _, r in df.iterrows():
        coin_id = r["id"]
        row = {
            "id": r["id"],
            "symbol": r["symbol"],
            "name": r["name"],
            "market_cap_rank": r["market_cap_rank"],
            "market_cap": r["market_cap"],
            "vol_24h": r["total_volume"],
        }

        # Returns
        for d in lookbacks:
            ret = fetch_price_return(
                client, cache_dir, cache_enabled, ttl_hours,
                coin_id=str(coin_id), vs_currency=vs_currency, days=int(d)
            )
            row[f"ret_{d}d"] = ret
            # Relative strength vs BTC
            if btc_ret[d] is None or ret is None:
                row[f"rs_{d}d_vs_btc"] = None
            else:
                row[f"rs_{d}d_vs_btc"] = ret - btc_ret[d]

        rows.append(row)

    feats = pd.DataFrame(rows)

    # Save features
    feats = feats.sort_values("market_cap_rank")
    feats.to_csv(features_csv, index=False)

    # Rank: Momentum
    mom_w = scoring.get("momentum_weights", {})
    # Map weights to columns
    mom_weights = {
        "ret_90d": mom_w.get("ret_90d", 0.45),
        "rs_90d_vs_btc": mom_w.get("rs_90d_vs_btc", 0.30),
        "ret_30d": mom_w.get("ret_30d", 0.15),
        "vol_24h": mom_w.get("vol_24h", 0.10),
    }
    # Convert to actual feature column names
    mom_weights = {
        "ret_90d": mom_weights["ret_90d"],
        "rs_90d_vs_btc": mom_weights["rs_90d_vs_btc"],
        "ret_30d": mom_weights["ret_30d"],
        "vol_24h": mom_weights["vol_24h"],
    }
    # Rename columns expected by weights
    feats_sc = feats.rename(columns={
        "ret_90d": "ret_90d",  # placeholder if already
    })
    # Our columns are ret_90d etc? Actually we created ret_{d}d
    feats_sc = feats.rename(columns={
        "ret_90d": "ret_90d",
    })

    # Simple mapping for 30/90d columns
    feats_sc["ret_30d"] = feats["ret_30d"]
    feats_sc["ret_90d"] = feats["ret_90d"]
    feats_sc["rs_90d_vs_btc"] = feats["rs_90d_vs_btc"]

    feats_sc["momentum_score"] = weighted_score(feats_sc, mom_weights)
    ranked_mom = feats_sc.sort_values("momentum_score", ascending=False).copy()
    ranked_mom.to_csv(ranked_momentum_csv, index=False)

    # Rank: Growth v1 (still momentum-ish)
    gr_w = scoring.get("growth_weights", {})
    growth_weights = {
        "ret_90d": gr_w.get("ret_90d", 0.35),
        "rs_90d_vs_btc": gr_w.get("rs_90d_vs_btc", 0.25),
        "ret_30d": gr_w.get("ret_30d", 0.20),
        "market_cap": gr_w.get("market_cap", 0.10),
        "vol_24h": gr_w.get("vol_24h", 0.10),
    }

    feats_sc["growth_score"] = weighted_score(feats_sc, growth_weights)
    ranked_growth = feats_sc.sort_values("growth_score", ascending=False).copy()
    ranked_growth.to_csv(ranked_growth_csv, index=False)

    return feats, ranked_mom, ranked_growth


if __name__ == "__main__":
    feats, ranked_mom, ranked_growth = run_step3("config.yaml")
    print(f"Features rows: {len(feats)} -> outputs/features/features.csv")
    print("Rankings saved:")
    print(" - outputs/rankings/ranked_momentum.csv")
    print(" - outputs/rankings/ranked_growth.csv")
    print("Top 10 Momentum:")
    print(ranked_mom[["market_cap_rank","symbol","momentum_score"]].head(10).to_string(index=False))