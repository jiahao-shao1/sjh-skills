# SJH Skills

English | [中文](README.zh-CN.md)

> A collection of Claude Code skills for research workflow automation.

## Skills

| Skill | Description |
|-------|-------------|
| [scholar-agent](skills/scholar-agent/) | Taste-aware research agent — personalized paper discovery via Scholar Inbox + hallucination-free deep reading via NotebookLM |
| [cmux](skills/cmux/) | Agent-friendly terminal built on Ghostty — multi-agent orchestration via split panes, spawn sub-Claude-Code instances, built-in browser, markdown preview, sidebar progress reporting |
| [daily-summary](skills/daily-summary/) | Daily work summary — aggregates Claude Code sessions, git commits, and Notion tasks into a timeline-style Chinese report |
| [notion-lifeos](skills/notion-lifeos/) | Notion life management — PARA method + Make Time journaling, with natural language task/note/journal CRUD via Notion API |
| [web-fetcher](skills/web-fetcher/) | Web page → clean markdown with 5-layer fallback: Jina Reader → defuddle.md → markdown.new → OpenCLI (platform-specific with login state) → raw HTML |

## Install

**Single skill** (recommended):

```bash
npx skills add https://github.com/jiahao-shao1/sjh-skills --skill scholar-agent
npx skills add https://github.com/jiahao-shao1/sjh-skills --skill cmux
```

This installs to both `~/.claude/skills/` and `~/.agents/skills/`, so all coding agents (Claude Code, Cursor, Windsurf, etc.) can use them.

**All skills at once:**

```bash
npx skills add https://github.com/jiahao-shao1/sjh-skills
```

## Architecture

```
sjh_skills/
└── skills/
    ├── scholar-agent/     # Scholar Inbox REST API + NotebookLM batch deep reading
    ├── cmux/              # Ghostty terminal orchestration + multi-agent coordination
    ├── daily-summary/     # git + Claude sessions + Notion timeline aggregation
    ├── notion-lifeos/     # PARA method + Make Time journaling via Notion API
    └── web-fetcher/       # 5-layer fallback web content extraction
```

Each skill is self-contained with its own `SKILL.md`, `scripts/`, and `references/`. Skills can be installed individually or as a collection.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and what changed in each release.

## License

[MIT](LICENSE)
