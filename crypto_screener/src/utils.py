"""Utility helpers for configuration, caching, and validation."""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List

import yaml
from dotenv import load_dotenv


@dataclass(frozen=True)
class CacheConfig:
    """Configuration for caching responses."""

    enabled: bool
    directory: Path


@dataclass(frozen=True)
class ApiRetryConfig:
    """Retry configuration."""

    max_attempts: int
    min_seconds: float
    max_seconds: float


@dataclass(frozen=True)
class ApiConfig:
    """Configuration for API usage."""

    base_url: str
    request_timeout_seconds: int
    per_page: int
    throttle_seconds: float
    retries: ApiRetryConfig


@dataclass(frozen=True)
class UniverseConfig:
    """Configuration for the universe builder."""

    target_size: int
    vs_currency: str
    exclude_stablecoins: bool
    stablecoin_symbols: List[str]


@dataclass(frozen=True)
class OutputConfig:
    """Output configuration."""

    directory: Path
    filename: str


@dataclass(frozen=True)
class AppConfig:
    """Root application config."""

    api: ApiConfig
    universe: UniverseConfig
    output: OutputConfig
    cache: CacheConfig


def load_config(config_path: Path) -> AppConfig:
    """Load configuration from a YAML file and environment variables."""
    load_dotenv(override=False)
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with config_path.open("r", encoding="utf-8") as handle:
        raw = yaml.safe_load(handle)

    try:
        api_raw = raw["api"]
        universe_raw = raw["universe"]
        output_raw = raw["output"]
        cache_raw = raw.get("cache", {})
    except KeyError as exc:
        raise KeyError(f"Missing required config section: {exc}") from exc

    api_config = ApiConfig(
        base_url=api_raw["base_url"],
        request_timeout_seconds=int(api_raw["request_timeout_seconds"]),
        per_page=int(api_raw.get("per_page", 250)),
        throttle_seconds=float(api_raw.get("throttle_seconds", 1.0)),
        retries=ApiRetryConfig(
            max_attempts=int(api_raw["retries"]["max_attempts"]),
            min_seconds=float(api_raw["retries"]["min_seconds"]),
            max_seconds=float(api_raw["retries"]["max_seconds"]),
        ),
    )

    universe_config = UniverseConfig(
        target_size=int(universe_raw.get("target_size", 500)),
        vs_currency=universe_raw.get("vs_currency", "usd"),
        exclude_stablecoins=bool(universe_raw.get("exclude_stablecoins", True)),
        stablecoin_symbols=[symbol.lower() for symbol in universe_raw.get("stablecoin_symbols", [])],
    )

    output_config = OutputConfig(
        directory=Path(output_raw.get("directory", "outputs/universe")),
        filename=output_raw.get("filename", "universe.csv"),
    )

    cache_config = CacheConfig(
        enabled=bool(cache_raw.get("enabled", False)),
        directory=Path(cache_raw.get("directory", "data_cache")),
    )

    return AppConfig(
        api=api_config,
        universe=universe_config,
        output=output_config,
        cache=cache_config,
    )


def ensure_directory(path: Path) -> None:
    """Ensure a directory exists."""
    path.mkdir(parents=True, exist_ok=True)


def make_cache_key(endpoint: str, params: Dict[str, Any]) -> str:
    """Create a deterministic cache key from endpoint and params."""
    normalized = json.dumps({"endpoint": endpoint, "params": params}, sort_keys=True)
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    date_stamp = datetime.now(timezone.utc).strftime("%Y%m%d")
    return f"{date_stamp}_{digest}"


def read_cache(cache_dir: Path, key: str) -> Any | None:
    """Read cached payload if it exists."""
    cache_path = cache_dir / f"{key}.json"
    if not cache_path.exists():
        return None
    with cache_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_cache(cache_dir: Path, key: str, payload: Any) -> None:
    """Write payload to cache."""
    ensure_directory(cache_dir)
    cache_path = cache_dir / f"{key}.json"
    with cache_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle)


def validate_market_response(records: Iterable[Dict[str, Any]], required_fields: List[str]) -> List[Dict[str, Any]]:
    """Validate each record contains required fields."""
    validated: List[Dict[str, Any]] = []
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise ValueError(f"Expected record to be object at index {index}, got {type(record)}")
        missing = [field for field in required_fields if field not in record]
        if missing:
            raise ValueError(
                "Unexpected response schema: missing fields "
                f"{missing} in record at index {index}. Keys: {sorted(record.keys())}"
            )
        validated.append(record)
    return validated
