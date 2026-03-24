"""Cookie extraction for Scholar Inbox.

Login flow:
1. Open persistent headed browser → user logs in
2. While browser is still open → cookie-get extracts session cookie
3. Close browser

Fallback: user pastes cookie manually via --cookie flag.
"""

from __future__ import annotations

import subprocess
import sys
import time


def _parse_cookie_output(output: str) -> str | None:
    """Parse session cookie value from playwright-cli cookie-get output.

    Expected format: session=eyJ... (domain: api.scholar-inbox.com, ...)
    """
    for line in output.strip().split("\n"):
        if line.startswith("session="):
            # "session=eyJ... (domain: ...)" → extract value before space
            value = line.split("=", 1)[1].split(" ")[0].strip()
            if value:
                return value
    return None


def extract_cookie_from_open_browser() -> str | None:
    """Extract session cookie from an already-open playwright-cli browser.

    cookie-get works when the persistent headed browser is still running,
    as they share the same browser context.
    """
    try:
        result = subprocess.run(
            ["playwright-cli", "cookie-get", "session"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            return _parse_cookie_output(result.stdout)
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return None


def _close_browser() -> None:
    """Try to close the playwright-cli browser."""
    try:
        subprocess.run(
            ["playwright-cli", "close"],
            capture_output=True, timeout=5,
        )
    except Exception:
        pass


def open_browser_for_login() -> str | None:
    """Open persistent headed browser for login, extract cookie while open.

    Flow:
    1. Launch --persistent --headed browser via Popen (non-blocking)
    2. User logs in (Google OAuth or email/password)
    3. Poll cookie-get every 3s — works while browser shares persistent context
    4. Once cookie appears → close browser and return it
    5. Timeout after ~3 minutes → prompt manual paste

    Note: playwright-cli open may return immediately in subprocess even though
    the browser stays open. We poll cookie-get regardless of process state.
    """
    try:
        print("Opening browser for login...", file=sys.stderr)
        print("Log in to Scholar Inbox, then wait — cookie will be extracted automatically.", file=sys.stderr)
        print(file=sys.stderr)
    except Exception:
        pass

    # Launch browser as a background process — don't wait for it
    try:
        browser_proc = subprocess.Popen(
            ["playwright-cli", "open", "--persistent", "--headed",
             "https://www.scholar-inbox.com"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        print("Error: playwright-cli not found.", file=sys.stderr)
        print("Install: npm install -g @anthropic-ai/playwright-cli", file=sys.stderr)
        return None

    # Wait for browser to start
    time.sleep(5)

    # Poll for cookie — keep going even if the subprocess has already exited,
    # because the browser may still be running (persistent context stays alive)
    cookie = None
    try:
        for _ in range(60):  # up to ~3 minutes
            cookie = extract_cookie_from_open_browser()
            if cookie:
                print("  ✓ Cookie extracted automatically!", file=sys.stderr)
                _close_browser()
                return cookie

            time.sleep(3)
    except KeyboardInterrupt:
        cookie = extract_cookie_from_open_browser()
        if cookie:
            print("  ✓ Cookie extracted!", file=sys.stderr)
            _close_browser()
            return cookie

    # Clean up
    _close_browser()
    # Also terminate the Popen process if still running
    if browser_proc.poll() is None:
        browser_proc.terminate()

    # Fallback: manual paste
    print(file=sys.stderr)
    print("Could not auto-extract cookie.", file=sys.stderr)
    print("To get it manually:", file=sys.stderr)
    print("  1. Open https://www.scholar-inbox.com in your browser", file=sys.stderr)
    print("  2. Log in, then open DevTools (F12) → Network tab", file=sys.stderr)
    print("  3. Reload, click any request to scholar-inbox.com", file=sys.stderr)
    print("  4. In Request Headers, find: Cookie: session=...", file=sys.stderr)
    print("  5. Copy everything after 'session='", file=sys.stderr)
    print(file=sys.stderr)

    try:
        value = input("Paste session cookie (or Enter to skip): ").strip()
        if value:
            return value
    except (EOFError, KeyboardInterrupt):
        pass

    return None
