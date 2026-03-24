"""Tests for config module."""
import json
from pathlib import Path

from scholar_inbox.config import Config


def test_default_config_dir(tmp_path, monkeypatch):
    """Config uses ~/.config/scholar-inbox by default."""
    monkeypatch.setenv("HOME", str(tmp_path))
    cfg = Config()
    assert cfg.config_dir == tmp_path / ".config" / "scholar-inbox"


def test_custom_config_dir(tmp_path):
    """Config accepts custom directory."""
    cfg = Config(config_dir=tmp_path / "custom")
    assert cfg.config_dir == tmp_path / "custom"


def test_save_and_load_session(tmp_path):
    """Session cookie round-trips through save/load."""
    cfg = Config(config_dir=tmp_path)
    cfg.save_session("test-cookie-value")
    assert cfg.load_session() == "test-cookie-value"


def test_load_session_missing(tmp_path):
    """Missing session file returns None."""
    cfg = Config(config_dir=tmp_path)
    assert cfg.load_session() is None


def test_save_and_load_interests(tmp_path):
    """Interests round-trip through save/load."""
    cfg = Config(config_dir=tmp_path)
    cfg.set("interests", "RL, VLM, multi-modal")
    assert cfg.get("interests") == "RL, VLM, multi-modal"


def test_get_missing_key(tmp_path):
    """Missing config key returns default."""
    cfg = Config(config_dir=tmp_path)
    assert cfg.get("nonexistent") is None
    assert cfg.get("nonexistent", "fallback") == "fallback"
