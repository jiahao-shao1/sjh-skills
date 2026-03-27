# Init Project

English | [中文](README.zh-CN.md)

> Bootstrap Claude Code configuration for new projects — directory skeleton, agents, hooks, and CLAUDE.md, all in one command.

## Quick Start

```bash
npx skills add jiahao-shao1/sjh-skills --skill init-project
```

Then in any project, tell Claude Code:

```
初始化项目
```

or

```
init project
```

Claude Code will automatically trigger this skill and walk you through the setup.

## Overview

This skill automates the setup of Claude Code best practices for any new project. It generates a complete configuration skeleton and interactively fills in project-specific details through a guided workflow.

## Workflow

### Phase 1: Generate Skeleton

Runs `scripts/init-skeleton.sh` to create the directory structure and boilerplate files:

| Path | Purpose |
|------|---------|
| `.claude/rules/` | Hard rules (distilled from validated experience) |
| `.claude/knowledge/` | Hot experience (debug findings, workarounds) |
| `.claude/hooks/` | PostToolUse automation hooks |
| `.claude/agents/` | Agent definitions (domain experts, quality checks) |
| `.claude/worktrees/` | Worktree tracking |
| `.agents/skills/` | Project-level skill definitions |

Generated files:

| File | Description |
|------|-------------|
| `.claude/hooks/auto-format-python.sh` | Auto `ruff format` + `ruff check --fix` after editing `.py` files |
| `.claude/agents/code-verifier.md` | Pre-commit quality gate — ruff lint/format + pytest |
| `.claude/agents/planner.md` | Codebase researcher for brainstorming/planning phases |
| `.claude/settings.json` | PostToolUse hook registration |
| `CLAUDE.md` | Project guide skeleton with placeholder sections |

### Phase 2: Interactive CLAUDE.md Fill

Processes `<!-- init-project: placeholder -->` placeholders section by section:

```
Read codebase (auto) → Generate draft (auto) → AskUserQuestion to confirm → Write to CLAUDE.md
```

| Section | Auto-exploration | User prompt |
|---------|-----------------|-------------|
| Project overview | README, pyproject.toml, package.json | "One-line description of this project's core goal?" |
| Directory structure | ls + key file docstrings | "Does this directory layout look correct?" |
| Dev workflow | CI, Makefile, scripts/ | "Use the default brainstorming→plans→dev→verify flow?" |
| Dev guide | venv, .env, Dockerfile | "Any special environment setup steps?" |
| Always Do | rules/, lint config | "Any cross-module consistency requirements?" |
| Ask First | core interfaces, config files | "Which files/dirs require confirmation before modifying?" |
| Never Do | third_party/, .env | "Any absolute don't-touch conventions?" |
| Progressive references | docs/, skills, agents | "Any additional task→reference file mappings?" |

Users can reply **"skip"** to leave any section unfilled.

### Phase 3: Profile Overlay (Optional)

Optionally layer additional project-type-specific structure on top of the base skeleton.

**Currently supported:** `research`

The research profile adds:
- `docs/reports/weekly/`, `docs/reports/worktree/`, `docs/plans/` directories
- `.claude/knowledge/experiments.md` — experiment registry (date, config, three-tier paths, results)
- `.claude/agents/domain-expert.md` — domain expert agent scaffold
- Research-specific sections appended to CLAUDE.md

New profiles can be added via `scripts/init-<profile>-profile.sh` + `details/<profile>-profile.md`.

### Phase 4: Summary

Lists all generated/modified files and suggests next steps: review content, `git add`, start developing.

## Agents

Two general-purpose agents are included in the skeleton:

### code-verifier (haiku)

Pre-commit quality check. Identifies changed `.py` files, runs `ruff check --fix` + `ruff format`, then `pytest`. Reports results in a structured table — does **not** auto-fix test failures.

### planner (opus)

Read-only codebase researcher for `/brainstorming` and `/writing-plans` workflows. Systematically searches code, outputs structured findings (relevant files, existing patterns, suggestions, risks).

## Constraints

- **Idempotent** — existing files are never overwritten, only gaps are filled
- **No auto git add/commit** — user decides when to commit
- **No existing content modification** — only `<!-- init-project: placeholder -->` placeholders are touched
- **Scripts run standalone** — `init-skeleton.sh` and `init-research-profile.sh` work independently of the skill

## File Structure

```
init-project/
├── SKILL.md                              # Skill definition
├── README.md                             # English docs (this file)
├── README.zh-CN.md                       # 中文文档
├── scripts/
│   ├── init-skeleton.sh                  # Phase 1: skeleton generator
│   └── init-research-profile.sh          # Phase 3: research profile overlay
└── details/
    ├── skeleton-manifest.md              # Complete file manifest
    ├── claude-md-sections.md             # CLAUDE.md section fill guide
    ├── agent-templates.md                # Agent template docs
    └── research-profile.md              # Research profile docs
```
