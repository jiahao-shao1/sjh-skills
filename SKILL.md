---
name: web-fetcher
description: Fetch web page content as clean markdown/text from a URL. Use when the user provides a URL and wants to read, extract, or analyze its content. Triggers on requests like "fetch this page", "read this URL", "grab the content from", "summarize this article", "抓取网页", "读这个链接", or any task requiring web page text extraction. Also useful as a WebFetch enhancement for JS-rendered pages (SPA, Twitter/X, etc).
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

## Fallback Chain

The script tries these sources in order, falling back on failure:

1. **Jina Reader** (`r.jina.ai/{url}`) — best markdown quality, supports JS-rendered pages
2. **defuddle.md** (`defuddle.md/{url}`) — by Obsidian creator @kepano
3. **markdown.new** (`markdown.new/{url}`) — 3-layer strategy with browser rendering fallback
4. **OpenCLI** — platform-specific commands with browser login state (zhihu, reddit, twitter, weibo)
5. **Raw HTML** — direct fetch as last resort

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
