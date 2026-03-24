# Web Fetcher

[English](README.md) | 中文

> **将任意网页转为干净的 Markdown** — 5 层降级策略，覆盖静态网站、JS 渲染的 SPA、以及需要登录的平台。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)

## 工作原理

Web Fetcher 按顺序尝试 5 种策略，返回第一个内容足够长（>500 字符）的结果：

```
① Jina Reader  →  ② defuddle.md  →  ③ markdown.new  →  ④ OpenCLI  →  ⑤ Raw HTML
   (最佳 md)        (by @kepano)      (浏览器渲染)       (有登录态)     (兜底)
```

- **第 1–3 层** 是免费 Web 服务，适用于公开页面（无需任何配置）
- **第 4 层** 使用 [OpenCLI](https://github.com/jackwener/opencli)，复用浏览器已有的登录态来读取需要登录的平台
- **第 5 层** 是直接 HTTP 抓取，作为最后兜底

## 安装

### Claude Code Skill（推荐）

```bash
claude install-skill https://github.com/jiahao-shao1/web-fetcher
```

安装后直接对 Claude 说：*"帮我抓取这个网页：https://..."* — Skill 会自动触发。

### 独立脚本

```bash
git clone https://github.com/jiahao-shao1/web-fetcher.git
python3 web-fetcher/scripts/fetch.py <url>
```

零依赖 — 纯 Python 标准库。

## 使用方法

```bash
# 输出到终端
python3 scripts/fetch.py https://example.com

# 保存到文件
python3 scripts/fetch.py https://example.com -o output.md
```

进度信息输出到 stderr，内容输出到 stdout：

```
[Jina Reader] Fetching...
[Jina Reader] Skipped: too short (168 chars), likely error page
[defuddle.md] Fetching...
[defuddle.md] Failed: HTTP Error 502: Bad Gateway
[OpenCLI] Fetching...
  → opencli zhihu question 660648498
[OpenCLI] Success (12847 chars)
```

## OpenCLI 集成（可选）

对于需要登录的平台（知乎、Reddit、Twitter/X、微博），当免费服务失败时 OpenCLI 会自动介入。它复用你浏览器已有的登录态 — 无需单独认证。

### 配置步骤

1. 安装 OpenCLI：

```bash
npm install -g @jackwener/opencli
```

2. 在浏览器中安装 Browser Bridge 扩展：

| 浏览器 | 安装方式 |
|--------|---------|
| **Chrome** | 从 [OpenCLI Releases](https://github.com/jackwener/opencli/releases) 下载 `opencli-extension.zip`，解压后在 `chrome://extensions/` → 开启开发者模式 → 加载已解压的扩展程序 → 选择解压后的文件夹 |
| **Arc** | 与 Chrome 相同 — Arc 使用 Chromium 扩展。在 `arc://extensions/` → 开启开发者模式 → 加载已解压的扩展程序 → 选择解压后的文件夹 |

> **注意**：该扩展**不在** Chrome 商店里，必须从 GitHub Releases 手动下载安装。

3. 验证连接：

```bash
opencli doctor
```

正常输出：

```
[OK] Daemon: running on port 19825
[OK] Extension: connected
[OK] Connectivity: connected in 0.3s
```

### 支持的 URL 模式

| URL 模式 | OpenCLI 命令 | 是否弹出浏览器？ |
|----------|-------------|-----------------|
| `zhihu.com/question/xxx` | `opencli zhihu question` | 否（`[cookie]` 模式） |
| `zhuanlan.zhihu.com/p/xxx` | `opencli zhihu download` | 否（`[cookie]` 模式） |
| `reddit.com/r/.../comments/...` | `opencli reddit read` | 否（`[cookie]` 模式） |
| `twitter.com` 或 `x.com/.../status/xxx` | `opencli twitter thread` | 否（`[cookie]` 模式） |
| `weibo.com/...` | `opencli weibo search` | 否（`[cookie]` 模式） |

所有内容读取命令都使用 `[cookie]` 策略 — 通过浏览器扩展在后台读取 cookie，**不会弹出任何新标签页**。

## 请求限制

| 服务 | 限制 |
|------|------|
| Jina Reader | 免费版 20 次/分钟 |
| defuddle.md | 未公开 |
| markdown.new | 500 次/天/IP |
| OpenCLI | 无限制（使用浏览器会话） |

## 已知限制

- 微信公众号文章不被任何策略支持
- OpenCLI 层需要一次性安装浏览器扩展
- 没有 OpenCLI 时，需要登录的页面会降级到 Raw HTML（通常只能拿到登录墙）

## 许可证

[MIT](LICENSE)
