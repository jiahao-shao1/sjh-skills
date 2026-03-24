"""Configuration management for Scholar Inbox CLI.

Stores session cookies and user preferences in ~/.config/scholar-inbox/.
"""

from __future__ import annotations

import json
import os
import stat
from pathlib import Path


class Config:
    """Manages Scholar Inbox configuration and session state."""

    def __init__(self, config_dir: Path | None = None):
        if config_dir is None:
            config_dir = Path.home() / ".config" / "scholar-inbox"
        self.config_dir = config_dir
        self._session_file = self.config_dir / "session.json"
        self._config_file = self.config_dir / "config.json"

    def _ensure_dir(self):
        self.config_dir.mkdir(parents=True, exist_ok=True)

    # --- Session ---

    def load_session(self) -> str | None:
        """Load session cookie from disk. Returns None if not found."""
        if not self._session_file.exists():
            return None
        try:
            data = json.loads(self._session_file.read_text())
            return data.get("session")
        except (json.JSONDecodeError, KeyError, OSError):
            return None

    def save_session(self, cookie: str):
        """Save session cookie to disk with restricted permissions."""
        self._ensure_dir()
        self._session_file.write_text(json.dumps({"session": cookie}, indent=2))
        try:
            os.chmod(self._session_file, stat.S_IRUSR | stat.S_IWUSR)  # 600
        except OSError:
            pass

    def clear_session(self):
        """Remove saved session."""
        if self._session_file.exists():
            self._session_file.unlink()

    # --- Config key-value ---

    def _load_config(self) -> dict:
        if not self._config_file.exists():
            return {}
        try:
            return json.loads(self._config_file.read_text())
        except (json.JSONDecodeError, OSError):
            return {}

    def _save_config(self, data: dict):
        self._ensure_dir()
        self._config_file.write_text(json.dumps(data, indent=2, ensure_ascii=False))

    def get(self, key: str, default=None):
        """Get a config value."""
        return self._load_config().get(key, default)

    def set(self, key: str, value):
        """Set a config value."""
        data = self._load_config()
        data[key] = value
        self._save_config(data)

    def all(self) -> dict:
        """Get all config values."""
        return self._load_config()
