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
| [init-project](skills/init-project/) | Initialize Claude Code project config — CLAUDE.md scaffolding, agent templates, and research profile setup |
| [project-review](skills/project-review/) | Project strategy panoramic review — auto-discover strategy docs and generate a 5-dimension snapshot (vision, roadmap, blockers, related work, next steps) |
| [remote-cluster-agent](skills/remote-cluster-agent/) | Remote GPU cluster operations — edit code locally, run commands remotely with ~0.1s latency via persistent SSH agent connections, cluster health inspection |
| [codex-review](skills/codex-review/) | Cross-model review — send your plan or code diff to OpenAI Codex for independent verification, iterative Claude↔Codex feedback until approved (max 5 rounds) |
| [paper-analyzer](skills/paper-analyzer/) | Deep critical paper analysis — causal chain methodology (现象→实验设置→归因→解法), NotebookLM-grounded reading, optional research framework mapping |
| [experiment-registry](skills/experiment-registry/) | ML experiment lifecycle management — structured YAML registry with CLI for registering experiments, recording benchmarks, comparing results, and tracking status |
| [obsidian-brain](skills/obsidian-brain/) | ⏸️ **On Hold** — Obsidian Second Brain with dual-zone vault. Paused in favor of enhancing notion-lifeos with reflection commands |

## Install

### Claude Code Plugin (recommended)

```bash
/plugin marketplace add jiahao-shao1/sjh-skills
/plugin install sjh-skills@sjh-skills
/reload-plugins
```

Plugin auto-updates from GitHub on startup. No manual sync needed.

### npx (alternative)

For other coding agents (Cursor, Windsurf, Codex) or single skill install:

```bash
npx skills add jiahao-shao1/sjh-skills --skill scholar-agent
npx skills add jiahao-shao1/sjh-skills --skill cmux
```

All skills at once:

```bash
npx skills add jiahao-shao1/sjh-skills
```

## Architecture

```
sjh_skills/
└── skills/
    ├── scholar-agent/     # Scholar Inbox REST API + NotebookLM batch deep reading
    ├── cmux/              # Ghostty terminal orchestration + multi-agent coordination
    ├── daily-summary/     # git + Claude sessions + Notion timeline aggregation
    ├── notion-lifeos/     # PARA method + Make Time journaling via Notion API
    ├── web-fetcher/       # 5-layer fallback web content extraction
    ├── init-project/      # Claude Code project initialization and scaffolding
    ├── project-review/    # 5-dimension strategy review snapshot
    ├── remote-cluster-agent/ # Remote GPU cluster ops via persistent SSH agent
    ├── codex-review/          # Cross-model plan/code review via OpenAI Codex
    ├── paper-analyzer/        # Deep critical paper analysis with causal chain methodology
    └── experiment-registry/   # ML experiment registry with YAML + CLI
```

Each skill is self-contained with its own `SKILL.md`, `scripts/`, and `references/`. Skills can be installed individually or as a collection.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and what changed in each release.

## License

[MIT](LICENSE)
