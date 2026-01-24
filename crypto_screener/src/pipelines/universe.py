"""Universe builder pipeline."""
from __future__ import annotations

import math
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd

from src.clients.coingecko import CoinGeckoClient
from src.utils import (
    AppConfig,
    ensure_directory,
    load_config,
    make_cache_key,
    read_cache,
    validate_market_response,
    write_cache,
)

REQUIRED_COLUMNS = [
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


def build_params(config: AppConfig, page: int) -> Dict[str, Any]:
    """Build request params for CoinGecko markets endpoint."""
    return {
        "vs_currency": config.universe.vs_currency,
        "order": "market_cap_desc",
        "per_page": config.api.per_page,
        "page": page,
        "price_change_percentage": "24h",
    }


def fetch_universe(config: AppConfig) -> List[Dict[str, Any]]:
    """Fetch top N assets by market cap with pagination."""
    client = CoinGeckoClient(config.api)
    pages = math.ceil(config.universe.target_size / config.api.per_page)
    all_records: List[Dict[str, Any]] = []

    for page in range(1, pages + 1):
        params = build_params(config, page)
        cache_key = make_cache_key("/coins/markets", params)
        cached = None
        if config.cache.enabled:
            cached = read_cache(config.cache.directory, cache_key)
        if cached is not None:
            records = cached
        else:
            records = client.fetch_markets_page(params, throttle=page > 1)
            if config.cache.enabled:
                write_cache(config.cache.directory, cache_key, records)
        if not isinstance(records, list):
            raise ValueError(f"Unexpected response type from CoinGecko: {type(records)}")
        validated = validate_market_response(records, REQUIRED_COLUMNS)
        all_records.extend(validated)

    return all_records


def apply_exclusions(records: List[Dict[str, Any]], config: AppConfig) -> List[Dict[str, Any]]:
    """Apply optional stablecoin exclusions."""
    if not config.universe.exclude_stablecoins:
        return records
    stablecoins = set(config.universe.stablecoin_symbols)
    return [record for record in records if record.get("symbol", "").lower() not in stablecoins]


def to_dataframe(records: List[Dict[str, Any]]) -> pd.DataFrame:
    """Convert records to a dataframe with expected columns."""
    dataframe = pd.DataFrame(records)
    dataframe = dataframe[REQUIRED_COLUMNS]
    dataframe = dataframe.sort_values("market_cap_rank", ascending=True)
    return dataframe


def write_output(dataframe: pd.DataFrame, config: AppConfig) -> Path:
    """Write the universe CSV to disk."""
    output_dir = config.output.directory
    ensure_directory(output_dir)
    output_path = output_dir / config.output.filename
    dataframe.to_csv(output_path, index=False)
    return output_path


def run() -> Path:
    """Run the universe pipeline."""
    root_dir = Path(__file__).resolve().parents[2]
    config = load_config(root_dir / "config.yaml")
    config = config.__class__(
        api=config.api,
        universe=config.universe,
        output=config.output.__class__(
            directory=root_dir / config.output.directory,
            filename=config.output.filename,
        ),
        cache=config.cache.__class__(
            enabled=config.cache.enabled,
            directory=root_dir / config.cache.directory,
        ),
    )

    records = fetch_universe(config)
    filtered = apply_exclusions(records, config)
    dataframe = to_dataframe(filtered)
    output_path = write_output(dataframe, config)
    print(f"Universe saved: {len(dataframe)} rows -> {output_path}")
    return output_path


if __name__ == "__main__":
    run()
