# SJH Skills

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

## License

[MIT](LICENSE)
