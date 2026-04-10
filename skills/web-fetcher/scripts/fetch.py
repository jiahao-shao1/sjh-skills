#!/usr/bin/env python3
"""Fetch web page content as markdown/text with smart fallback chain.

Strategy:
- Known platforms (zhihu, twitter, reddit, weibo, etc.) → OpenCLI first (deterministic, zero-token)
- Other URLs → Jina Reader → defuddle.md → markdown.new → agent-browser → Raw HTML

Usage:
    python3 fetch.py <url> [--output <file>]
"""

import argparse
import re
import shutil
import subprocess
import sys
import urllib.request


UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

# URL pattern → (opencli command, args extractor)
OPENCLI_ROUTES = [
    # zhihu question: zhihu.com/question/12345
    (r"zhihu\.com/question/(\d+)", lambda m: ["zhihu", "question", m.group(1)]),
    # zhihu article: zhuanlan.zhihu.com/p/12345
    (r"zhuanlan\.zhihu\.com/p/(\d+)", lambda m: ["zhihu", "download", f"https://zhuanlan.zhihu.com/p/{m.group(1)}"]),
    # reddit post: reddit.com/r/xxx/comments/xxx
    (r"reddit\.com/r/\w+/comments/", lambda m: ["reddit", "read", m.string]),
    # twitter/x thread
    (r"(twitter\.com|x\.com)/\w+/status/(\d+)", lambda m: ["twitter", "thread", m.group(2)]),
    # weibo
    (r"weibo\.com/\d+/(\w+)", lambda m: ["weibo", "search", m.group(0)]),
]

# Platforms where OpenCLI should be tried FIRST (login-required or anti-scraping)
PLATFORM_PATTERNS = [
    r"zhihu\.com",
    r"zhuanlan\.zhihu\.com",
    r"reddit\.com",
    r"(twitter\.com|x\.com)",
    r"weibo\.com",
    r"xiaohongshu\.com",
    r"bilibili\.com",
]


def is_known_platform(url: str) -> bool:
    """Check if URL belongs to a platform where OpenCLI should be prioritized."""
    return any(re.search(p, url) for p in PLATFORM_PATTERNS)


def fetch_url(url: str, headers: dict | None = None, timeout: int = 30) -> str:
    h = {"User-Agent": UA}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_via_jina(target: str) -> str:
    return fetch_url(
        f"https://r.jina.ai/{target}",
        headers={"Accept": "text/markdown"},
    )


def fetch_via_defuddle(target: str) -> str:
    return fetch_url(f"https://defuddle.md/{target}")


def fetch_via_markdown_new(target: str) -> str:
    return fetch_url(f"https://markdown.new/{target}")


def fetch_via_opencli(target: str) -> str:
    if not shutil.which("opencli"):
        raise RuntimeError("opencli not installed")
    for pattern, args_fn in OPENCLI_ROUTES:
        m = re.search(pattern, target)
        if m:
            cmd = ["opencli"] + args_fn(m)
            print(f"  → {' '.join(cmd)}", file=sys.stderr)
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout
            raise RuntimeError(result.stderr.strip() or f"exit code {result.returncode}")
    raise RuntimeError(f"no opencli route for {target}")


def fetch_via_agent_browser(target: str) -> str:
    """Use agent-browser to render JS-heavy pages and extract text content."""
    if not shutil.which("agent-browser"):
        raise RuntimeError("agent-browser not installed")
    # Open URL, then get text snapshot (accessibility tree → compact text)
    result = subprocess.run(
        ["agent-browser", "open", target],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"open failed: exit code {result.returncode}")
    # Extract page content as text via eval
    result = subprocess.run(
        ["agent-browser", "eval", "document.body.innerText"],
        capture_output=True, text=True, timeout=15,
    )
    if result.returncode == 0 and result.stdout.strip():
        return result.stdout
    raise RuntimeError(result.stderr.strip() or f"eval failed: exit code {result.returncode}")


def fetch_raw(target: str) -> str:
    return fetch_url(target)


# Default fallback chain for generic URLs
GENERIC_STRATEGIES = [
    ("Jina Reader", fetch_via_jina),
    ("defuddle.md", fetch_via_defuddle),
    ("markdown.new", fetch_via_markdown_new),
    ("agent-browser", fetch_via_agent_browser),
    ("Raw HTML", fetch_raw),
]

# For known platforms: try OpenCLI first, then fall back to generic chain
PLATFORM_STRATEGIES = [
    ("OpenCLI", fetch_via_opencli),
    ("Jina Reader", fetch_via_jina),
    ("defuddle.md", fetch_via_defuddle),
    ("markdown.new", fetch_via_markdown_new),
    ("agent-browser", fetch_via_agent_browser),
    ("Raw HTML", fetch_raw),
]


MIN_CONTENT_LEN = 500  # skip results that are too short (likely error pages)


def fetch(target: str) -> str:
    strategies = PLATFORM_STRATEGIES if is_known_platform(target) else GENERIC_STRATEGIES
    if is_known_platform(target):
        print(f"[Router] Known platform detected, trying OpenCLI first", file=sys.stderr)

    errors = []
    for name, fn in strategies:
        try:
            print(f"[{name}] Fetching...", file=sys.stderr)
            content = fn(target)
            if len(content) < MIN_CONTENT_LEN:
                msg = f"too short ({len(content)} chars), likely error page"
                print(f"[{name}] Skipped: {msg}", file=sys.stderr)
                errors.append((name, msg))
                continue
            print(f"[{name}] Success ({len(content)} chars)", file=sys.stderr)
            return content
        except Exception as e:
            print(f"[{name}] Failed: {e}", file=sys.stderr)
            errors.append((name, str(e)))

    raise RuntimeError(
        "All strategies failed:\n"
        + "\n".join(f"  - {name}: {err}" for name, err in errors)
    )


def main():
    parser = argparse.ArgumentParser(description="Fetch web page content as text")
    parser.add_argument("url", help="Target URL to fetch")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    args = parser.parse_args()

    content = fetch(args.url)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Saved to {args.output}", file=sys.stderr)
    else:
        print(content)


if __name__ == "__main__":
    main()
