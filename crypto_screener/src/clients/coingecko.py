from __future__ import annotations

import os
import time
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type


class CoinGeckoClient:
    """
    CoinGecko client for:
    - /coins/markets (already used)
    - /coins/{id}/market_chart (used in Step 3)
    """

    def __init__(
        self,
        base_url: str,
        api_key: Optional[str] = None,
        min_delay_s: float = 1.2,
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key or os.getenv("COINGECKO_DEMO_API_KEY")
        self.min_delay_s = float(min_delay_s)
        self._last_call_ts = 0.0
        self._session = requests.Session()

    def _headers(self) -> Dict[str, str]:
        headers = {"accept": "application/json"}
        if self.api_key:
            headers["x-cg-demo-api-key"] = self.api_key
        return headers

    def _throttle(self) -> None:
        now = time.time()
        elapsed = now - self._last_call_ts
        if elapsed < self.min_delay_s:
            time.sleep(self.min_delay_s - elapsed)
        self._last_call_ts = time.time()

    @retry(
    retry=retry_if_exception_type(requests.RequestException),
    wait=wait_exponential(multiplier=2, min=2, max=60),
    stop=stop_after_attempt(7),
    reraise=True,
    )
    def market_chart(self, coin_id: str, vs_currency: str, days: int) -> Dict[str, Any]:
        self._throttle()
        url = f"{self.base_url}/coins/{coin_id}/market_chart"
        params = {"vs_currency": vs_currency, "days": str(days)}
        resp = self._session.get(url, params=params, headers=self._headers(), timeout=30)
        # If rate limited, raise a RequestException so tenacity retries
        if resp.status_code == 429:
            raise requests.RequestException("Rate limited (429). Backing off...")
        resp.raise_for_status()
        data = resp.json()
        if not isinstance(data, dict) or "prices" not in data:
            raise requests.RequestException("Unexpected market_chart response shape")
        return data


def load_cache(cache_dir: str, key: str, ttl_hours: int) -> Optional[Dict[str, Any]]:
    path = Path(cache_dir) / f"{key}.json"
    if not path.exists():
        return None
    age_seconds = time.time() - path.stat().st_mtime
    if age_seconds > ttl_hours * 3600:
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def save_cache(cache_dir: str, key: str, data: Dict[str, Any]) -> None:
    Path(cache_dir).mkdir(parents=True, exist_ok=True)
    path = Path(cache_dir) / f"{key}.json"
    path.write_text(json.dumps(data), encoding="utf-8")