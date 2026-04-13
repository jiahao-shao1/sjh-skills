---
name: web-fetcher
description: "Fetch any URL as clean markdown. Use instead of WebFetch for JS-rendered pages, login-required platforms (Twitter/X, zhihu, reddit, weibo, xiaohongshu, bilibili, etc.), and complex pages. Routes known platforms through OpenCLI (browser login state), others through Jina Reader / defuddle.md / markdown.new. Invoke when the user provides a URL to read, extract, summarize, or convert to markdown."
---

# Web Fetcher

Fetch any URL as clean markdown. Two paths: known platforms go through OpenCLI (uses browser login state), everything else falls back through a chain of free markdown services.

## Strategy Overview

1. **Known platforms** (Twitter/X, zhihu, reddit, weibo, xiaohongshu, bilibili, etc.) → OpenCLI first. It uses the user's browser login state, is deterministic, and costs zero LLM tokens.
2. **Generic URLs** (blogs, docs, articles) → Jina Reader > defuddle.md > markdown.new > WebFetch.

These are soft priorities — skip obviously wrong strategies (e.g., don't try OpenCLI for a random blog post, don't try Jina for a login-walled zhihu page).

## Known Platform → OpenCLI Commands

| URL Pattern | Command | Notes |
|-------------|---------|-------|
| `x.com/.../status/<id>` | `opencli twitter thread <id>` | Tweet threads. If the result is just a t.co link (very short text), the tweet likely links to an X Article — retry with `opencli twitter article <same-id>` |
| `x.com/.../article/<id>` or `x.com/i/article/<id>` | `opencli twitter article <id>` | X Article long-form |
| `zhihu.com/question/<id>` | `opencli zhihu question <id>` | |
| `zhuanlan.zhihu.com/p/<id>` | `opencli zhihu download <full-url>` | |
| `reddit.com/r/.../comments/...` | `opencli reddit read <full-url>` | |
| `weibo.com/...` | `opencli weibo search <query>` | |
| `xiaohongshu.com/...` | `opencli xiaohongshu download <id>` | |
| `bilibili.com/video/BV...` | `opencli bilibili download <bvid>` | |

## Dynamic Discovery

The table above covers high-frequency platforms. OpenCLI supports 80+ platforms. For anything not listed:

```bash
# See all supported platforms
opencli --help

# See subcommands for a specific platform
opencli <platform> --help
```

## Generic Fallback Tools

For URLs that don't match a known platform, try these in order:

| Tool | How to Use | Strengths | Weaknesses |
|------|-----------|-----------|------------|
| Jina Reader | `curl -s -H "Accept: text/markdown" "https://r.jina.ai/<url>"` | Best markdown quality, JS support | 20 req/min free limit |
| defuddle.md | `curl -s "https://defuddle.md/<url>"` | Good quality, by Obsidian creator | Undocumented limits |
| markdown.new | `curl -s "https://markdown.new/<url>"` | Browser rendering fallback | 500 req/day |
| WebFetch | Built-in tool, no curl needed | No setup needed | No JS rendering, poor on complex pages |

## Decision Guide

- **Known platform with login** → OpenCLI first
- **Static article/blog** → Jina Reader first
- **If a tool returns too-short content** (<500 chars) → likely an error page, try next tool in chain
- **If Jina fails or is rate-limited** → defuddle → markdown.new → WebFetch
- **If OpenCLI fails** → fall back to the generic chain above

## OpenCLI Setup

If `opencli` is not installed:

1. `npm i -g @jackwener/opencli`
2. Download browser extension from https://github.com/jackwener/opencli/releases
3. Chrome → `chrome://extensions` → Developer mode → Load unpacked → select unzipped folder
4. `opencli doctor` to verify

One-time setup. After installation, known platform URLs automatically use browser login state.

## Limitations

- WeChat articles partially supported via `opencli weixin`; proxy may be needed for some URLs behind GFW
- OpenCLI requires browser extension setup (one-time)
- Jina Reader free tier: 20 req/min
- markdown.new: 500 req/day/IP
