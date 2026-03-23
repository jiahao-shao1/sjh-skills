"""Scholar Inbox API client — zero-dependency wrapper using only stdlib."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any
from urllib.parse import urlencode

from scholar_inbox.config import Config

API_BASE = "https://api.scholar-inbox.com/api"

RATING_MAP = {"up": 1, "down": -1, "reset": 0}


class APIError(Exception):
    """Non-recoverable API error."""

    def __init__(self, message: str, status: int | None = None):
        super().__init__(message)
        self.status = status


class SessionExpiredError(APIError):
    """Session cookie is missing or expired."""

    def __init__(self, message: str = "Session expired or not set. Run 'si login' first."):
        super().__init__(message, status=401)


class ScholarInboxClient:
    """Thin wrapper around the Scholar Inbox REST API."""

    def __init__(
        self,
        session: str | None = None,
        config: Config | None = None,
        config_dir=None,
    ):
        self._config = config or Config(config_dir=config_dir) if (config or config_dir) else None
        self._session = session

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _ensure_session(self) -> str:
        if self._session:
            return self._session
        if self._config:
            s = self._config.load_session()
            if s:
                self._session = s
                return s
        raise SessionExpiredError()

    def _request(
        self,
        method: str,
        path: str,
        *,
        params: dict | None = None,
        body: dict | None = None,
        needs_session: bool = True,
    ) -> dict | None:
        if needs_session:
            cookie = self._ensure_session()

        url = f"{API_BASE}{path}"
        if params:
            url = f"{url}?{urlencode({k: v for k, v in params.items() if v is not None})}"

        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if needs_session:
            req.add_header("Cookie", f"session={cookie}")

        try:
            with urllib.request.urlopen(req) as resp:
                # Auto-renew session from Set-Cookie header
                set_cookie = resp.headers.get("Set-Cookie", "")
                if set_cookie and "session=" in set_cookie:
                    new_val = set_cookie.split("session=")[1].split(";")[0]
                    if new_val and new_val != self._session:
                        self._session = new_val
                        if self._config:
                            self._config.save_session(new_val)

                raw = resp.read()
                if not raw:
                    return None
                return json.loads(raw)
        except urllib.error.HTTPError as exc:
            if exc.code == 401:
                raise SessionExpiredError() from exc
            raise APIError(f"HTTP {exc.code}: {exc.reason}", status=exc.code) from exc

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def check_session(self) -> dict:
        """Verify the current session is valid."""
        return self._request("GET", "/check_session")

    def get_digest(
        self,
        date: str | None = None,
        from_date: str | None = None,
        to_date: str | None = None,
    ) -> dict:
        """Fetch the paper digest."""
        params = {"date": date, "from_date": from_date, "to_date": to_date}
        return self._request("GET", "/digest", params=params)

    def get_paper(self, paper_id: int) -> dict | None:
        """Fetch details for a single paper."""
        return self._request("GET", f"/paper/{paper_id}")

    def rate(self, paper_id: int, rating: int | str) -> None:
        """Rate a paper. rating can be int (1/-1/0) or str ('up'/'down'/'reset')."""
        if isinstance(rating, str):
            rating = RATING_MAP[rating]
        self._request("POST", "/rate", body={"rating": rating, "id": paper_id})

    def rate_batch(self, paper_ids: list[int], rating: int | str) -> None:
        """Rate multiple papers at once."""
        if isinstance(rating, str):
            rating = RATING_MAP[rating]
        self._request("POST", "/rate", body={"rating": rating, "ids": paper_ids})

    def mark_as_read(self, paper_id: int) -> None:
        """Mark a paper as read."""
        self._request("POST", "/mark_read", body={"id": paper_id})

    def get_collections(self) -> list[dict]:
        """List all collections."""
        data = self._request("GET", "/collections")
        return data.get("collections", []) if data else []

    def add_to_collection(self, collection_id: int, paper_id: int) -> dict:
        """Add a paper to a collection."""
        return self._request(
            "POST", "/collection/add", body={"collection_id": collection_id, "paper_id": paper_id}
        )

    def create_collection(self, name: str, paper_id: int | None = None) -> dict:
        """Create a new collection, optionally adding a paper to it."""
        body: dict[str, Any] = {"name": name}
        if paper_id is not None:
            body["paper_id"] = paper_id
        return self._request("POST", "/collection/create", body=body)

    def get_trending(
        self,
        category: str | None = None,
        days: int | None = None,
        page: int | None = None,
    ) -> dict:
        """Fetch trending papers."""
        params = {"category": category, "days": days, "page": page}
        return self._request("GET", "/trending", params=params)

    def get_similar(self, paper_id: int) -> dict:
        """Fetch papers similar to the given paper."""
        return self._request("GET", f"/similar/{paper_id}")
