"""Tests for Scholar Inbox API client."""
import json
from unittest.mock import patch, MagicMock

import pytest

from scholar_inbox.api import ScholarInboxClient, SessionExpiredError, APIError


def _mock_response(data: dict | None = None, status: int = 200, set_cookie: str = ""):
    """Create a mock urllib response."""
    body = json.dumps(data).encode() if data else b""
    resp = MagicMock()
    resp.status = status
    resp.read.return_value = body
    resp.headers = MagicMock()
    resp.headers.get.side_effect = lambda k, d="": set_cookie if k == "Set-Cookie" else d
    resp.__enter__ = MagicMock(return_value=resp)
    resp.__exit__ = MagicMock(return_value=False)
    return resp


class TestCheckSession:
    def test_logged_in(self):
        client = ScholarInboxClient(session="test-cookie")
        mock_data = {"is_logged_in": True, "name": "Test User", "user_id": 1}
        with patch("urllib.request.urlopen", return_value=_mock_response(mock_data)):
            result = client.check_session()
        assert result["is_logged_in"] is True
        assert result["name"] == "Test User"

    def test_no_session_raises(self):
        client = ScholarInboxClient(session=None)
        with pytest.raises(SessionExpiredError):
            client.check_session()


class TestGetDigest:
    def test_returns_papers(self):
        client = ScholarInboxClient(session="test")
        mock_data = {
            "success": True,
            "current_digest_date": "2026-03-24",
            "total_papers": 100,
            "digest_df": [{"paper_id": 1, "title": "Test Paper", "ranking_score": 0.9}],
        }
        with patch("urllib.request.urlopen", return_value=_mock_response(mock_data)):
            result = client.get_digest()
        assert result["total_papers"] == 100
        assert len(result["digest_df"]) == 1

    def test_with_date_param(self):
        client = ScholarInboxClient(session="test")
        mock_data = {"success": True, "digest_df": [], "total_papers": 0}
        with patch("urllib.request.urlopen", return_value=_mock_response(mock_data)) as mock:
            client.get_digest(date="2026-03-20")
            req = mock.call_args[0][0]
            assert "date=2026-03-20" in req.full_url


class TestRate:
    def test_rate_up_with_int(self):
        client = ScholarInboxClient(session="test")
        with patch("urllib.request.urlopen", return_value=_mock_response(status=204)) as mock:
            client.rate(12345, 1)
            req = mock.call_args[0][0]
            body = json.loads(req.data)
            assert body == {"rating": 1, "id": 12345}

    def test_rate_up_with_string(self):
        client = ScholarInboxClient(session="test")
        with patch("urllib.request.urlopen", return_value=_mock_response(status=204)) as mock:
            client.rate(12345, "up")
            req = mock.call_args[0][0]
            body = json.loads(req.data)
            assert body == {"rating": 1, "id": 12345}

    def test_rate_batch(self):
        client = ScholarInboxClient(session="test")
        with patch("urllib.request.urlopen", return_value=_mock_response(status=204)) as mock:
            client.rate_batch([1, 2, 3], "down")
            req = mock.call_args[0][0]
            body = json.loads(req.data)
            assert body == {"rating": -1, "ids": [1, 2, 3]}


class TestSessionAutoRenew:
    def test_renews_session_from_set_cookie(self, tmp_path):
        from scholar_inbox.config import Config
        cfg = Config(config_dir=tmp_path)
        cfg.save_session("old-cookie")
        client = ScholarInboxClient(session="old-cookie", config=cfg)
        new_cookie = "session=new-rotated-cookie; Path=/; HttpOnly"
        mock_data = {"is_logged_in": True, "name": "User"}
        with patch("urllib.request.urlopen", return_value=_mock_response(mock_data, set_cookie=new_cookie)):
            client.check_session()
        assert cfg.load_session() == "new-rotated-cookie"


class TestCollections:
    def test_get_collections_list(self):
        client = ScholarInboxClient(session="test")
        mock_data = {"collections": [{"collection_id": 1, "collection_name": "Bookmarks"}]}
        with patch("urllib.request.urlopen", return_value=_mock_response(mock_data)):
            result = client.get_collections()
        assert len(result) == 1
        assert result[0]["collection_name"] == "Bookmarks"

    def test_add_to_collection(self):
        client = ScholarInboxClient(session="test")
        mock_data = {"success": True}
        with patch("urllib.request.urlopen", return_value=_mock_response(mock_data)) as mock:
            client.add_to_collection(91055, 12345)
            req = mock.call_args[0][0]
            body = json.loads(req.data)
            assert body["collection_id"] == 91055
            assert body["paper_id"] == 12345
