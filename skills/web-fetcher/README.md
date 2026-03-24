# Web Fetcher

English | [中文](README.zh-CN.md)

> **Fetch any web page as clean markdown** — a 5-layer fallback chain that handles static sites, JS-rendered SPAs, and login-required platforms.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)

## How It Works

Web Fetcher tries 5 strategies in order, returning the first result with enough content (>500 chars):

```
① Jina Reader  →  ② defuddle.md  →  ③ markdown.new  →  ④ OpenCLI  →  ⑤ Raw HTML
   (best md)        (by @kepano)      (browser render)   (login-aware)   (last resort)
```

- **Layers 1–3** are free web services for public pages (no setup needed)
- **Layer 4** uses [OpenCLI](https://github.com/jackwener/opencli) to read login-required platforms via your browser's existing session
- **Layer 5** is a direct HTTP fetch as last resort

## Install

### Claude Code Skill (recommended)

```bash
claude install-skill https://github.com/jiahao-shao1/web-fetcher
```

Then just ask Claude: *"fetch this page: https://..."* — the skill triggers automatically.

### Standalone Script

```bash
git clone https://github.com/jiahao-shao1/web-fetcher.git
python3 web-fetcher/scripts/fetch.py <url>
```

Zero dependencies — pure Python stdlib.

## Usage

```bash
# Fetch to stdout
python3 scripts/fetch.py https://example.com

# Save to file
python3 scripts/fetch.py https://example.com -o output.md
```

Progress is printed to stderr, content to stdout:

```
[Jina Reader] Fetching...
[Jina Reader] Skipped: too short (168 chars), likely error page
[defuddle.md] Fetching...
[defuddle.md] Failed: HTTP Error 502: Bad Gateway
[OpenCLI] Fetching...
  → opencli zhihu question 660648498
[OpenCLI] Success (12847 chars)
```

## OpenCLI Integration (Optional)

For login-required platforms (Zhihu, Reddit, Twitter/X, Weibo), OpenCLI automatically kicks in when free services fail. It reuses your browser's existing login session — no separate authentication needed.

### Setup

1. Install OpenCLI:

```bash
npm install -g @jackwener/opencli
```

2. Install the Browser Bridge extension in your browser:

| Browser | Instructions |
|---------|-------------|
| **Chrome** | Download `opencli-extension.zip` from [OpenCLI Releases](https://github.com/jackwener/opencli/releases), unzip, go to `chrome://extensions/` → Enable Developer Mode → Load Unpacked → select the unzipped folder |
| **Arc** | Same as Chrome — Arc uses Chromium extensions. Go to `arc://extensions/` → Enable Developer Mode → Load Unpacked → select the unzipped folder |

> **Note**: The extension is NOT on Chrome Web Store. You must download it from GitHub Releases.

3. Verify the connection:

```bash
opencli doctor
```

You should see:

```
[OK] Daemon: running on port 19825
[OK] Extension: connected
[OK] Connectivity: connected in 0.3s
```

### Supported URL Patterns

| URL Pattern | OpenCLI Command | Opens Browser? |
|-------------|----------------|----------------|
| `zhihu.com/question/xxx` | `opencli zhihu question` | No (`[cookie]`) |
| `zhuanlan.zhihu.com/p/xxx` | `opencli zhihu download` | No (`[cookie]`) |
| `reddit.com/r/.../comments/...` | `opencli reddit read` | No (`[cookie]`) |
| `twitter.com` or `x.com/.../status/xxx` | `opencli twitter thread` | No (`[cookie]`) |
| `weibo.com/...` | `opencli weibo search` | No (`[cookie]`) |

All content-reading commands use the `[cookie]` strategy — they read cookies via the browser extension **without opening any new tabs**.

## Rate Limits

| Service | Limit |
|---------|-------|
| Jina Reader | 20 req/min (free tier) |
| defuddle.md | Not documented |
| markdown.new | 500 req/day/IP |
| OpenCLI | No limits (uses browser session) |

## Limitations

- WeChat articles (微信公众号) are not supported by any strategy
- OpenCLI layer requires one-time browser extension setup
- Without OpenCLI, login-required pages will fall through to Raw HTML (which usually returns a login wall)

## License

[MIT](LICENSE)
