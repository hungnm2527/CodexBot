from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

import requests


class DeFiLlamaClient:
    def __init__(self, base_url: str = "https://api.llama.fi", min_delay_s: float = 1.0) -> None:
        self.base_url = base_url.rstrip("/")
        self.min_delay_s = float(min_delay_s)
        self._last_call = 0.0
        self._session = requests.Session()

    def _throttle(self) -> None:
        now = time.time()
        elapsed = now - self._last_call
        if elapsed < self.min_delay_s:
            time.sleep(self.min_delay_s - elapsed)
        self._last_call = time.time()

    def protocols(self) -> List[Dict[str, Any]]:
        self._throttle()
        url = f"{self.base_url}/protocols"
        r = self._session.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if not isinstance(data, list):
            raise ValueError("Unexpected /protocols response shape")
        return data

    def protocol(self, slug: str) -> Dict[str, Any]:
        self._throttle()
        url = f"{self.base_url}/protocol/{slug}"
        r = self._session.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if not isinstance(data, dict):
            raise ValueError("Unexpected /protocol/{slug} response shape")
        return data
