# Project Review

English | [中文](README.zh-CN.md)

> Strategic project review — auto-discovers strategy documents and generates a five-dimension analysis snapshot (vision, roadmap, bottlenecks, related work gaps, next steps).

## Features

- **Auto-discovery** — Finds strategy docs via `docs/strategy/.review-sources.md` config or smart fallback search
- **Five-dimension analysis** — Vision check, roadmap status, bottleneck identification, related work gaps, next steps
- **Read-only** — Provides perspective without modifying any documents
- **First-use onboarding** — Generates recommended config from discovered files

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill project-review
```

## Usage

```
/project-review
```

Or trigger conversationally:

```
"project review"
"where is the project at?"
"审视战略"
"项目现在什么状态"
```

## How It Works

1. **Load documents** — Reads `docs/strategy/.review-sources.md` for explicit paths, or auto-discovers from standard locations (`docs/strategy/`, `HANDOFF.md`, `.claude/knowledge/experiments.md`)
2. **Five-dimension analysis** — Generates insights for each dimension that has supporting documents (skips dimensions without data)
3. **Output snapshot** — Renders a structured report to the terminal

## Configuration

Create `docs/strategy/.review-sources.md` in your project to specify exactly which documents to include:

```markdown
# Project Review Sources

## Core
- docs/strategy/vision.md
- docs/strategy/roadmap.md

## Decisions
- docs/strategy/decisions/log.md

## Meetings (latest 2)
- docs/strategy/meetings/
```

Directory paths (ending with `/`) read the 2 most recently modified files.

## Constraints

- Does not replace [weekly-report](../weekly-report/) (for reporting) or meeting-slides (for presentations) — this skill is for strategic reflection
- Skips dimensions without supporting documents rather than speculating

## License

MIT
