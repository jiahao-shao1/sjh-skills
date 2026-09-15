# SJH Skills

English | [中文](README.zh-CN.md)

> A collection of Claude Code skills for research workflow automation.

## Skills

| Skill | Description |
|-------|-------------|
| [daily-summary](skills/daily-summary/) | Daily work summary — aggregates Claude Code sessions, git commits, and Notion tasks into a timeline-style Chinese report |
| [notion-lifeos](skills/notion-lifeos/) | Notion life management — PARA method + Make Time journaling, with natural language task/note/journal CRUD via Notion API |
| [web-fetcher](skills/web-fetcher/) | Web page → clean markdown with 5-layer fallback: Jina Reader → defuddle.md → markdown.new → OpenCLI (platform-specific with login state) → raw HTML |
| [init-project](skills/init-project/) | Initialize Claude Code project config — CLAUDE.md scaffolding, agent templates, and research profile setup |
| [project-review](skills/project-review/) | Project strategy panoramic review — auto-discover strategy docs and generate a 5-dimension snapshot (vision, roadmap, blockers, related work, next steps) |
| [remote-cluster-agent](skills/remote-cluster-agent/) | Remote GPU cluster operations — edit code locally, run commands remotely via Go daemon + `rca` CLI (exec / batch / cp / nodes), persistent SSH connection pool, node health monitoring |
| [paper-analyzer](skills/paper-analyzer/) | Deep critical paper analysis — causal chain methodology (现象→实验设置→归因→解法), NotebookLM-grounded reading, optional research framework mapping |
| [paper-self-review](skills/paper-self-review/) | Paper paragraph self-review — three-axis check (logic jumps / repetition / premature method detail), v1 → v2 deterministic iteration |
| [experiment-registry](skills/experiment-registry/) | ML experiment lifecycle management — structured YAML registry with CLI for registering experiments, recording benchmarks, comparing results, and tracking status |
| [handoff](skills/handoff/) | Session handoff summary — prints a structured context summary (status, decisions, pitfalls, next steps) directly in the conversation for seamless session continuity |
| [sync-docs](skills/sync-docs/) | Documentation sync — finds where the project's docs have fallen out of sync with recent code changes, rewrites them, and commits the docs on their own |
| [context-audit](skills/context-audit/) | Context management hygiene — audits the three-layer architecture (CLAUDE.md / rules / knowledge) for progressive disclosure compliance. Detects orphaned knowledge, stale references, and CLAUDE.md index leakage. Read-only |
| [bibtex-fetch](skills/bibtex-fetch/) | Fetch correct BibTeX entries from arXiv (by ID) or Semantic Scholar (by title search). Batch fetch, custom bibkeys, exponential backoff. Zero dependencies (Python stdlib only) |

## Install

### Claude Code Plugin (recommended)

```bash
/plugin marketplace add jiahao-shao1/sjh-skills
/plugin install sjh-skills@sjh-skills
/reload-plugins
```

Plugin auto-updates from GitHub on startup. No manual sync needed.

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/jiahao-shao1/sjh-skills/refs/heads/main/.codex/INSTALL.md
```

Or manually:

```bash
git clone https://github.com/jiahao-shao1/sjh-skills.git ~/.codex/sjh-skills
mkdir -p ~/.agents/skills
for skill in ~/.codex/sjh-skills/skills/*/; do
  ln -sf "$skill" ~/.agents/skills/$(basename "$skill")
done
```

Detailed docs: [.codex/INSTALL.md](.codex/INSTALL.md)

### npx (Cursor, Windsurf, etc.)

```bash
npx skills add jiahao-shao1/sjh-skills --skill paper-analyzer
npx skills add jiahao-shao1/sjh-skills --skill web-fetcher
```

All skills at once:

```bash
npx skills add jiahao-shao1/sjh-skills
```

## Architecture

```
sjh_skills/
└── skills/
    ├── daily-summary/     # git + Claude sessions + Notion timeline aggregation
    ├── notion-lifeos/     # PARA method + Make Time journaling via Notion API
    ├── web-fetcher/       # 5-layer fallback web content extraction
    ├── init-project/      # Claude Code project initialization and scaffolding
    ├── project-review/    # 5-dimension strategy review snapshot
    ├── remote-cluster-agent/ # Remote GPU cluster ops via Go daemon + rca CLI
    ├── paper-analyzer/        # Deep critical paper analysis with causal chain methodology
    ├── paper-self-review/     # Paper paragraph self-review (logic / repetition / detail leakage)
    ├── experiment-registry/   # ML experiment registry with YAML + CLI
    ├── handoff/               # Session handoff summary for context continuity
    ├── sync-docs/             # Documentation sync — updates docs and commits
    ├── context-audit/         # Progressive disclosure compliance audit (CLAUDE.md / rules / knowledge)
    └── bibtex-fetch/          # arXiv / Semantic Scholar BibTeX fetcher (Python stdlib only)
```

Each skill is self-contained with its own `SKILL.md`, `scripts/`, and `references/`. Skills can be installed individually or as a collection.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and what changed in each release.

## License

[MIT](LICENSE)
