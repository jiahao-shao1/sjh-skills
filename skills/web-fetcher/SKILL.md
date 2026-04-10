---
name: web-fetcher
description: "Fetch any URL as clean markdown. ALWAYS use this skill instead of the WebFetch tool when you need to read a URL's content — it has smart routing (known platforms → OpenCLI first, others → Jina Reader → defuddle.md → markdown.new → raw HTML) that produces better results and handles JS-rendered pages (Twitter/X, SPAs), login-required platforms (zhihu, reddit, weibo, xiaohongshu, bilibili), and complex web pages that WebFetch cannot parse. Invoke whenever the user provides a URL and wants to read, extract, summarize, analyze, or convert its content to markdown. Keywords: 'fetch page', 'read URL', 'grab content from', 'summarize article', 'extract text from webpage', '抓取网页', '读链接', '网页转 markdown'. NOT for: web search without URL, file downloads, screenshots, form filling, or accessibility checks."
---

# Web Fetcher

Extract web page content as clean text/markdown from a given URL using a fallback chain of free services.

## Usage

```bash
python3 <skill-path>/scripts/fetch.py <url>
```

Save to file:

```bash
python3 <skill-path>/scripts/fetch.py <url> -o output.md
```

## Smart Routing

The script detects known platforms and chooses the optimal strategy:

**Known platforms** (zhihu, twitter/x, reddit, weibo, xiaohongshu, bilibili):
1. **OpenCLI** — deterministic commands with browser login state, zero LLM token cost
2. Falls back to generic chain below if OpenCLI fails

**Generic URLs**:
1. **Jina Reader** (`r.jina.ai/{url}`) — best markdown quality, supports JS-rendered pages
2. **defuddle.md** (`defuddle.md/{url}`) — by Obsidian creator @kepano
3. **markdown.new** (`markdown.new/{url}`) — 3-layer strategy with browser rendering fallback
4. **Raw HTML** — direct fetch as last resort

## When to Use

- JS-rendered pages that WebFetch can't handle (Twitter/X, SPAs)
- Login-required pages on supported platforms (zhihu, reddit, twitter, weibo, xiaohongshu)
- Bulk content extraction
- When you need clean markdown instead of summarized content

## OpenCLI Supported Platforms

When free services fail, OpenCLI auto-detects the platform from URL and routes to the right command:

| URL Pattern | OpenCLI Command |
|-------------|----------------|
| `zhihu.com/question/xxx` | `opencli zhihu question` |
| `zhuanlan.zhihu.com/p/xxx` | `opencli zhihu download` |
| `reddit.com/r/.../comments/...` | `opencli reddit read` |
| `twitter.com/x.com/.../status/xxx` | `opencli twitter thread` |
| `weibo.com/...` | `opencli weibo search` |

Requires: `npm i -g @jackwener/opencli` + Browser Bridge extension in Chrome/Arc.

## OpenCLI Setup (if not installed)

If the script output contains "opencli not installed", guide the user through setup:

1. `npm i -g @jackwener/opencli`
2. Download `opencli-extension.zip` from https://github.com/jackwener/opencli/releases
3. Chrome → `chrome://extensions` → Enable Developer mode → Load unpacked → select unzipped folder
4. Run `opencli doctor` to verify

This is a one-time setup. After installation, known platform URLs will automatically use OpenCLI for fast, login-aware fetching.

## Limitations

- WeChat articles (微信公众号) not supported by any strategy
- OpenCLI requires browser extension setup (one-time)

## Rate Limits

| Service | Limit |
|---------|-------|
| Jina Reader | 20 req/min (free), 10M token key available at jina.ai/reader |
| markdown.new | 500 req/day/IP |
| defuddle.md | Not documented |
| OpenCLI | No documented limits (uses browser session) |
