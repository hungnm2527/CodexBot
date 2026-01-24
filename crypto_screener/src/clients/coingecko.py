"""CoinGecko API client."""
from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import requests
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from src.utils import ApiConfig


class CoinGeckoError(RuntimeError):
    """Custom error for CoinGecko issues."""


@dataclass
class CoinGeckoClient:
    """Client for CoinGecko API."""

    api_config: ApiConfig

    def __post_init__(self) -> None:
        self._session = requests.Session()
        api_key = os.getenv("COINGECKO_API_KEY")
        if api_key:
            self._session.headers.update({"x-cg-pro-api-key": api_key})

    def _request(self, endpoint: str, params: Dict[str, Any]) -> Any:
        url = f"{self.api_config.base_url}{endpoint}"
        response = self._session.get(url, params=params, timeout=self.api_config.request_timeout_seconds)
        if response.status_code in {429, 500, 502, 503, 504}:
            raise CoinGeckoError(
                f"CoinGecko API temporarily unavailable (status {response.status_code}): {response.text}"
            )
        try:
            response.raise_for_status()
        except requests.HTTPError as exc:
            raise CoinGeckoError(f"CoinGecko API error: {exc} - {response.text}") from exc
        return response.json()

    def _throttle(self) -> None:
        if self.api_config.throttle_seconds > 0:
            time.sleep(self.api_config.throttle_seconds)

    def _build_retry(self):
        return retry(
            retry=retry_if_exception_type((CoinGeckoError, requests.RequestException)),
            stop=stop_after_attempt(self.api_config.retries.max_attempts),
            wait=wait_exponential(
                min=self.api_config.retries.min_seconds,
                max=self.api_config.retries.max_seconds,
            ),
            reraise=True,
        )

    def fetch_markets_page(self, params: Dict[str, Any], throttle: bool = True) -> List[Dict[str, Any]]:
        """Fetch a single markets page with retries."""
        if throttle:
            self._throttle()

        retry_decorator = self._build_retry()

        @retry_decorator
        def _do_request() -> List[Dict[str, Any]]:
            return self._request("/coins/markets", params)

        return _do_request()
