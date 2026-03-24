"""Cookie extraction from Playwright persistent profiles.

Provides multiple strategies (in order of preference):
1. Read SQLite cookie DB from Playwright's persistent profile directory
2. Use playwright-cli subprocess to extract cookies
3. Open browser for interactive OAuth login
"""

from __future__ import annotations

import platform
import sqlite3
import subprocess
import sys
from pathlib import Path


def _get_playwright_daemon_dirs() -> list[Path]:
    """Return candidate Playwright daemon directories for the current platform."""
    home = Path.home()
    system = platform.system()
    if system == "Darwin":
        return [home / "Library" / "Caches" / "ms-playwright" / "daemon"]
    elif system == "Linux":
        return [home / ".cache" / "ms-playwright" / "daemon"]
    elif system == "Windows":
        return [home / "AppData" / "Local" / "ms-playwright" / "daemon"]
    return []


def _find_cookie_in_dir(daemon_dir: Path) -> str | None:
    """Search a daemon dir for session cookie in Chrome SQLite databases."""
    if not daemon_dir.exists():
        return None

    for profile_dir in daemon_dir.iterdir():
        if not profile_dir.is_dir():
            continue
        for ud_dir in profile_dir.iterdir():
            if not ud_dir.name.startswith("ud-"):
                continue
            cookie_db = ud_dir / "Default" / "Cookies"
            if not cookie_db.exists():
                continue
            try:
                conn = sqlite3.connect(str(cookie_db))
                cursor = conn.execute(
                    "SELECT value, encrypted_value FROM cookies "
                    "WHERE host_key = 'api.scholar-inbox.com' AND name = 'session'"
                )
                row = cursor.fetchone()
                conn.close()
                if row:
                    value, _encrypted = row
                    if value:
                        return value
                    # On macOS, Chrome encrypts cookies — plain value may be empty.
                    # Fall through to other strategies.
            except Exception:
                continue
    return None


def extract_from_playwright_profile() -> str | None:
    """Try reading session cookie from Playwright's Chrome SQLite database.

    Checks platform-specific paths for the Playwright daemon directory,
    then looks for ud-*/Default/Cookies SQLite DB with the session cookie.
    """
    for daemon_dir in _get_playwright_daemon_dirs():
        cookie = _find_cookie_in_dir(daemon_dir)
        if cookie:
            return cookie
    return None


def extract_via_playwright_cli() -> str | None:
    """Use playwright-cli subprocess to extract session cookie.

    Opens Scholar Inbox briefly to ensure cookies are accessible,
    then queries for the session cookie value.
    """
    try:
        # Open the page to make cookies available
        subprocess.run(
            ["playwright-cli", "open", "--persistent",
             "https://api.scholar-inbox.com/api/session_info"],
            capture_output=True, timeout=15,
        )
        result = subprocess.run(
            ["playwright-cli", "cookie-get", "session"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            output = result.stdout.strip()
            # Try to extract the cookie value from structured output
            if "=" in output and "session" in output.lower():
                for line in output.split("\n"):
                    if "=" in line and "session" in line.lower():
                        return line.split("=", 1)[1].strip()
            return output

        # Also try cookie-list and parse
        result = subprocess.run(
            ["playwright-cli", "cookie-list"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            for line in result.stdout.split("\n"):
                if "session" in line and "scholar-inbox" in line:
                    # Try to extract value after '='
                    parts = line.split("=", 1)
                    if len(parts) == 2:
                        return parts[1].strip().split()[0].rstrip(";")
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    finally:
        try:
            subprocess.run(["playwright-cli", "close"], capture_output=True, timeout=5)
        except Exception:
            pass
    return None


def open_browser_for_login() -> str | None:
    """Open browser with --persistent --headed for user to do OAuth.

    After the user completes login, extracts cookie from the persistent
    profile by re-opening headlessly and reading cookies directly.
    """
    try:
        print("Opening browser for login...", file=sys.stderr)
        print("Please complete Google OAuth in the browser window.", file=sys.stderr)
        print("After logging in, close the browser or press Ctrl+C.", file=sys.stderr)

        subprocess.run(
            ["playwright-cli", "open", "--persistent", "--headed",
             "https://www.scholar-inbox.com"],
            timeout=300,  # 5 minute timeout for manual login
        )
    except subprocess.TimeoutExpired:
        print("Browser session timed out.", file=sys.stderr)
    except FileNotFoundError:
        print("Error: playwright-cli not found. Install it first.", file=sys.stderr)
        return None
    except KeyboardInterrupt:
        pass

    # Re-open headlessly with same persistent profile to extract cookie.
    # The persistent profile retains cookies from the headed session.
    try:
        subprocess.run(
            ["playwright-cli", "open", "--persistent",
             "https://www.scholar-inbox.com/digest"],
            capture_output=True, timeout=15,
        )
        result = subprocess.run(
            ["playwright-cli", "cookie-get", "session"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            for line in result.stdout.strip().split("\n"):
                if line.startswith("session="):
                    cookie = line.split("=", 1)[1].split(" ")[0].strip()
                    return cookie
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    finally:
        try:
            subprocess.run(["playwright-cli", "close"], capture_output=True, timeout=5)
        except Exception:
            pass

    return None
