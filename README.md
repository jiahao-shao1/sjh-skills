# SJH Skills

English | [中文](README.zh-CN.md)

> A collection of Claude Code skills for research workflow automation.

## Skills

| Skill | Description |
|-------|-------------|
| [scholar-agent](skills/scholar-agent/) | Taste-aware research agent — paper discovery via Scholar Inbox + deep reading via NotebookLM |
| [cmux](skills/cmux/) | Terminal orchestration — split panes, spawn Claude Code instances, browser automation |
| [daily-summary](skills/daily-summary/) | Daily work summary — aggregates git commits, Claude sessions, and Notion tasks |
| [notion-lifeos](skills/notion-lifeos/) | Notion PARA life management with Make Time journaling |
| [web-fetcher](skills/web-fetcher/) | Web page fetcher with Jina → defuddle → markdown.new fallback chain |

## Install

**All skills:**

```bash
claude install-skill https://github.com/jiahao-shao1/sjh-skills
```

**Single skill:**

```bash
claude install-skill https://github.com/jiahao-shao1/sjh-skills --path skills/scholar-agent
```

## Architecture

```
sjh_skills/
└── skills/
    ├── scholar-agent/     # Scholar Inbox API + NotebookLM deep reading
    ├── cmux/              # tmux multiplexer + browser panes
    ├── daily-summary/     # git + Claude sessions + Notion aggregation
    ├── notion-lifeos/     # PARA method + Make Time journaling
    └── web-fetcher/       # Jina → defuddle → markdown.new fallback
```

Each skill is self-contained with its own `SKILL.md`, `scripts/`, and `references/`. Skills can be installed individually or as a collection.

## License

[MIT](LICENSE)
