from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
import yaml

from src.utils import ensure_dir
from src.clients.defillama import DeFiLlamaClient
from src.clients.coingecko import load_cache, save_cache


def load_config(config_path: str = "config.yaml") -> Dict[str, Any]:
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def pct_change(curr: Optional[float], past: Optional[float]) -> Optional[float]:
    if curr is None or past is None or past == 0:
        return None
    return (curr / past) - 1.0


def tvl_at_or_before(tvl_series: List[Dict[str, Any]], target_ts: int) -> Optional[float]:
    # tvl is usually [{date: unix, totalLiquidityUSD: ...}, ...] sorted ascending
    last = None
    for p in tvl_series:
        d = int(p.get("date", 0))
        v = p.get("totalLiquidityUSD", None)
        if d <= target_ts and v is not None:
            last = float(v)
        elif d > target_ts:
            break
    return last


def fetch_protocol_cached(
    client: DeFiLlamaClient,
    cache_dir: str,
    cache_enabled: bool,
    ttl_hours: int,
    slug: str,
) -> Dict[str, Any]:
    key = f"defillama__protocol__{slug}"
    data = load_cache(cache_dir, key, ttl_hours) if cache_enabled else None
    if data is None:
        data = client.protocol(slug)
        if cache_enabled:
            save_cache(cache_dir, key, data)
    return data


def run_step4(config_path: str = "config.yaml") -> pd.DataFrame:
    cfg = load_config(config_path)
    paths = cfg["paths"]

    filtered_csv = paths["filtered_universe_csv"]
    out_csv = paths.get("tvl_features_csv", "outputs/tvl/tvl_features.csv")
    out_path = Path(out_csv)
    ensure_dir(out_path.parent)
    print("Writing TVL features to:", out_path.resolve())


    df = pd.read_csv(filtered_csv)

    # Setup client
    llama_cfg = cfg.get("defillama", {})
    feat_cfg = cfg.get("features", {})
    base_url = llama_cfg.get("base_url", "https://api.llama.fi")
    delay_s = float(feat_cfg.get("llama_delay_s", 1.0))
    client = DeFiLlamaClient(base_url=base_url, min_delay_s=delay_s)

    cache_dir = str(paths.get("cache_dir", "data_cache"))
    cache_enabled = bool(feat_cfg.get("llama_cache_enabled", True))
    ttl_hours = int(feat_cfg.get("llama_cache_ttl_hours", 24))

    # 1) Download protocol list once
    protocols = client.protocols()

    # 2) Build mapping by gecko_id (best) + fallback by symbol
    # Many protocols include "gecko_id" according to DeFiLlama ecosystem usage. :contentReference[oaicite:1]{index=1}
    by_gecko: Dict[str, Dict[str, Any]] = {}
    by_symbol: Dict[str, Dict[str, Any]] = {}

    for p in protocols:
        gid = p.get("gecko_id")
        sym = p.get("symbol")
        if isinstance(gid, str) and gid.strip():
            by_gecko[gid.strip().lower()] = p
        if isinstance(sym, str) and sym.strip():
            by_symbol[sym.strip().lower()] = p

    # 3) Compute TVL features
    rows = []
    for _, r in df.iterrows():
        coin_id = str(r["id"]).lower()
        symbol = str(r["symbol"]).lower()

        proto = by_gecko.get(coin_id) or by_symbol.get(symbol)
        slug = proto.get("slug") if proto else None

        out = {
            "id": r["id"],
            "symbol": r["symbol"],
            "name": r["name"],
            "market_cap_rank": r["market_cap_rank"],
            "market_cap": r["market_cap"],
            "llama_slug": slug,
            "tvl_usd": None,
            "tvl_change_7d": None,
            "tvl_change_30d": None,
            "tvl_mcap_ratio": None,
        }

        if not slug:
            rows.append(out)
            continue

        data = fetch_protocol_cached(client, cache_dir, cache_enabled, ttl_hours, slug)
        tvl_series = data.get("tvl", [])
        if not isinstance(tvl_series, list) or len(tvl_series) == 0:
            rows.append(out)
            continue

        # Latest TVL point
        latest = tvl_series[-1]
        curr_tvl = latest.get("totalLiquidityUSD", None)
        curr_date = int(latest.get("date", 0))

        if curr_tvl is None or curr_date == 0:
            rows.append(out)
            continue

        curr_tvl = float(curr_tvl)
        t7 = tvl_at_or_before(tvl_series, curr_date - 7 * 86400)
        t30 = tvl_at_or_before(tvl_series, curr_date - 30 * 86400)

        out["tvl_usd"] = curr_tvl
        out["tvl_change_7d"] = pct_change(curr_tvl, t7)
        out["tvl_change_30d"] = pct_change(curr_tvl, t30)

        mc = r.get("market_cap", None)
        if mc is not None and float(mc) > 0:
            out["tvl_mcap_ratio"] = curr_tvl / float(mc)

        rows.append(out)

    tvl_df = pd.DataFrame(rows)
    tvl_df.to_csv(out_csv, index=False)
    return tvl_df


if __name__ == "__main__":
    tvl_df = run_step4("config.yaml")
    print(f"TVL features rows: {len(tvl_df)} -> outputs/tvl/tvl_features.csv")
    print("Matched protocols:", int(tvl_df["llama_slug"].notna().sum()))
