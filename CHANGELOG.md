# Changelog

All notable changes to SJH Skills are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Each skill's changes are grouped under its name.

## [1.6.3] - 2026-04-15

### sync-docs

#### Added
- Strategy docs checklist item — when `docs/strategy/` exists, checks if vision/roadmap/paper-outline are stale relative to recent commits. Suggests pairing with `/project-review` for full analysis

## [1.6.2] - 2026-04-14

### hooks

#### Fixed
- `post-knowledge-remind`: add missing `"action": "allow"` field to PostToolUse hook JSON output

## [1.6.1] - 2026-04-14

### web-fetcher

#### Changed
- Replaced `fetch.py` script with pure SKILL.md guide — skill now operates entirely through instructions, no external scripts

#### Removed
- `scripts/fetch.py` — no longer needed

## [1.6.0] - 2026-04-14

### handoff (new)

#### Added
- Session handoff summary skill — prints structured context (status, decisions, pitfalls, next steps) directly in conversation for seamless session continuity

### sync-docs (new)

#### Added
- Documentation sync checker — scans recent code changes and reports which docs need updating (knowledge base, experiment registry, CLAUDE.md, rules, README). Report only, no auto-modify

### scholar-agent

#### Added
- Phase A subagent incremental write to `/tmp/scholar_inbox_results.json` — each paper updates the file immediately, ensuring valid JSON at all times
- "Resilient Parallel Research" pattern — 2-3 parallel agents with incremental file writes, merge step compatible with partial results, coverage gap reporting

## [1.5.2] - 2026-04-13

### codex-review

#### Changed
- Default model changed from `gpt-5.3-codex` to `gpt-5.4`

## [1.5.1] - 2026-04-13

### notion-lifeos

#### Fixed
- Trim SKILL.md description to fit 1024-character limit (was 1198 chars)

## [1.5.0] - 2026-04-13

### Repo-wide

#### Added
- Codex CLI native installation support — `.codex/INSTALL.md` with clone + symlink workflow
- `AGENTS.md` symlinked to `CLAUDE.md` for Codex project instruction discovery
- Codex install section in both `README.md` and `README.zh-CN.md`

### init-project

#### Added
- `AGENTS.md` → `CLAUDE.md` symlink creation in `init-skeleton.sh` for Codex compatibility
- `AGENTS.md` entry in `skeleton-manifest.md`

## [1.4.0] - 2026-04-13

### hooks (new)

#### Added
- Plugin hooks system — first hook: `post-knowledge-remind` (PostToolUse)
- Detects debug/env operations (pip install, docker, errors, cluster ops) and reminds to archive knowledge
- Auto-detects project knowledge directory (`docs/knowledge/` or `docs/knowhow/`), falls back to memory
- Supports Bash and `mcp__cluster__remote_bash` matchers
- `run-hook.cmd` polyglot wrapper (required by CC plugin system for PostToolUse hooks)
- Per-project state isolation, frequency control (max 3/session, 5min interval)

## [1.4.1] - 2026-04-13

### init-project

#### Changed
- Migrated knowledge path from `.claude/knowledge/` to `docs/knowledge/` across all templates, scripts, and documentation
- Updated `init-skeleton.sh`, `init-research-profile.sh`, `claude-md-sections.md`, `skeleton-manifest.md`, `research-profile.md`

### remote-cluster-agent

#### Fixed
- Quoted YAML `description` field to fix `npx skills` discovery parsing

### Repo-wide

#### Changed
- Removed duplicate `description` field from `marketplace.json`
- Removed `hooks` field from `plugin.json` (hooks now loaded via `hooks.json` directly)

## [1.2.1] - 2026-04-11

### experiment-registry

#### Improved
- Rewrote SKILL.md from CLI reference manual to Claude behavior guide — added decision flow, smart comparison logic, proactive context, and "why" explanations
- Description field expanded for better triggering on edge cases (experiment management, "which is better", result tracking)

## [1.2.0] - 2026-04-11

### experiment-registry

#### Added
- New skill — ML experiment lifecycle management with structured YAML registry
- `exp` CLI with commands: `init`, `list`, `show`, `register`, `add-benchmark`, `compare`, `update`
- Config module with project-level discovery (`exp.config.yaml`)
- Models module with load/save/validate for experiment YAML files
- Query module with filter and compare across experiments
- Pip-installable package (`pip install exp-registry`)

## [Unreleased]

### notion-lifeos

#### Added
- `scripts/query-notes.sh` — query Notes DB with filters (Note Type, date range, tags)
- `scripts/query-projects.sh` — query Projects DB by status
- `scripts/collect-drift-data.sh` — aggregate active projects, git commits, and completed tasks for drift analysis
- `/challenge` reflection command — stress-test beliefs against past Thoughts notes
- `/emerge` reflection command — surface recurring themes from recent Thoughts
- `/drift` command — detect gaps between stated goals (Notion projects) and actual activity (git + tasks)

#### Changed
- `scripts/query-tasks.sh` — added `--since`, `--until`, and `--by-edited` date range flags (backward compatible)
- Updated `references/query-guide.md` with new script documentation

### obsidian-brain (⏸️ On Hold)

> Direction paused: reflection commands will be added to notion-lifeos instead.
> Code preserved for potential future use (local-first Obsidian workflow).

#### Added
- New skill: Obsidian Second Brain — dual-zone vault integration with Claude Code
- Vault initialization script with git version control
- Zone-enforced safe-write script (realpath validation, path traversal protection)
- Human-write script (`human-write.sh`) for user-dictated content to `tasks/` and `notes/` with `source: human` validation
- Wikilink query script (ripgrep-based, obsidian-cli fallback ready)
- Capture script for drafting user input to AI zone
- Task creation script (`create-task.sh`) with due dates, tags, duplicate handling
- Task query script (`query-tasks.sh`) with filtering (date/undone/tag/project) and sorted Markdown table output
- Task completion script (`complete-task.sh`) with fuzzy matching
- Note creation script (`create-note.sh`) with slugified filenames, tags, wikilinks, and duplicate handling
- Phase 2 reflection engine (`analyze.sh`) with four modes:
  - `/challenge` — stress-test beliefs against past writing
  - `/drift` — detect intention vs. action gaps across daily notes
  - `/emerge` — surface ghost links and recurring themes
  - `/connect` — find hidden connections between topics
- Templates for all content types (note, task, project, resource, daily, meeting-transcript, context)
- Daily template enhanced with Make Time fields (highlight, energy, gratitude)
- Reference docs: vault schema and command guide
- 138 tests covering zone enforcement, CRUD, reflection, and security (traversal/symlink attacks)

## [0.6.0] - 2026-03-29

### codex-review
- **Added**: New skill — cross-model plan/code review via OpenAI Codex CLI, iterative Claude↔Codex feedback loop (max 5 rounds)
- **Added**: `README.md` and `README.zh-CN.md`

### paper-analyzer
- **Added**: New skill — structured deep analysis of academic papers with causal chain methodology (现象→实验设置→归因→解法)
- **Added**: NotebookLM integration for source-grounded paper reading
- **Added**: Optional research framework mapping via `references/hypothesis.md`
- **Added**: `README.md` and `README.zh-CN.md`

### scholar-agent
- **Added**: `README.zh-CN.md` — Chinese documentation

### project-review
- **Added**: `README.zh-CN.md` — Chinese documentation

## [0.5.0] - 2026-03-28

### remote-cluster-agent
- **Added**: New skill — remote GPU cluster operations with ~0.1s command latency via persistent SSH agent connections
- **Added**: Two-layer configuration (`~/.config/remote-cluster-agent/` — global infrastructure + per-project)
- **Added**: Auto agent deployment detection and deployment on startup (no manual "deploy agent" step)
- **Added**: Cluster health inspection — parallel GPU/disk/tmux/load scanning with smart node recommendation
- **Added**: Unified `cluster` MCP server with `node` parameter routing (supports both Claude Code and Codex)
- **Added**: SSH config auto-generation with best-practice settings (`StrictHostKeyChecking=accept-new`)
- **Added**: "Read file vs run command" guidance — smart prompts to read Mutagen-synced files locally
- **Changed**: Default Mutagen sync mode to `one-way-replica` (never conflicts, syncs `.git`)
- **Added**: `reference/project.template.md` — project-level config template
- **Added**: `reference/cluster-health.md` — health check procedure with recommendation algorithm

## [0.4.3] - 2026-03-28

### cmux
- **Changed**: Replace `proxy` alias with explicit `export https_proxy=... http_proxy=... all_proxy=...` for portability — not all users have a `proxy` alias

## [0.4.2] - 2026-03-28

### cmux
- **Fixed**: Interactive program send pattern — `\n` in `cmux send` only works as Enter for shell prompts; interactive programs (Claude Code, vim) in raw terminal mode need `cmux send "text"` + `cmux send-key enter` to submit
- **Added**: "Sending to interactive programs" workflow pattern with examples for Claude Code communication
- **Added**: Shell vs interactive distinction in "Send Input / Read Output" section
- **Added**: `trigger-flash` and `surface-health` commands (from official cmux skills) for visual feedback and health checks

## [0.4.1] - 2026-03-28

### Repo-wide
- **Added**: `CLAUDE.md` — project guide with conventions, Always Do / Ask First / Never Do boundaries, and changelog policy
- **Fixed**: Install commands unified to `npx skills add jiahao-shao1/sjh-skills --skill <name>` across all READMEs (root, init-project, notion-lifeos had wrong URLs)
- **Fixed**: Chinese README naming standardized to `README.zh-CN.md` (renamed cmux, daily-summary, notion-lifeos from `README.zh.md`)
- **Fixed**: Root `README.zh-CN.md` missing init-project and project-review in skill table and architecture tree

### project-review
- **Added**: `README.md` — English documentation with install, usage, and configuration guide

## [0.4.0] - 2026-03-27

### project-review
- **Added**: New skill — strategic project review with five-dimension analysis (vision, roadmap, bottlenecks, related work gaps, next steps)
- **Added**: Explicit config support via `docs/strategy/.review-sources.md` with auto-discovery fallback
- **Added**: First-use onboarding that generates recommended config from discovered files
- **Changed**: Rewrote SKILL.md in English (Chinese trigger words preserved in description)
- **Changed**: Output language now follows the user's language instead of forcing Chinese

## [0.3.0] - 2026-03-25

### scholar-agent
- **Changed**: Rewrote SKILL.md in English (Chinese trigger words preserved)
- **Added**: Interactive first-time setup — auto-generates `~/.config/scholar-inbox/context.md` via 2-round AskUserQuestion flow
- **Added**: Filtering configuration section (global + project-level config)
- **Improved**: Trigger description optimized via eval-driven iteration (precision 100%, recall 70-90%)

### cmux
- **Changed**: "Launch Claude Code" → "Launch Agents" — now covers Codex, Claude Code, and other agents
- **Added**: Codex interactive/prompt examples in workflow patterns
- **Added**: `send` command caveats (compound commands must be single string)
- **Improved**: Trigger description optimized (recall +30%, from 30% → 60%)

### daily-summary
- **Changed**: Rewrote SKILL.md in English
- **Added**: Prerequisites table (collect-daily-data.sh, notion-lifeos, git)
- **Added**: Error handling table (empty data, missing Notion, invalid date)
- **Improved**: Trigger description optimized with "CANNOT be done with git log alone" emphasis

### notion-lifeos
- **Improved**: Trigger description optimized (recall +40%, from 20% → 60%)

### web-fetcher
- **Improved**: Trigger description slightly improved (recall +10%, limited by built-in WebFetch competition)

## [0.2.0] - 2026-03-24

### scholar-agent
- **Added**: `create_notebook.sh` — auto-create NotebookLM notebooks
- **Added**: `rename_notebook.sh` — rename notebooks via JS eval
- **Changed**: `add_to_notebooklm.sh` rewritten for batch mode (~3x faster)
- **Added**: `notebooklm_flow.sh` — strategy router for UI state detection
- **Added**: `notebooklm_site_knowledge.sh` — centralized UI text patterns
- **Added**: `doctor [--online]` CLI command for environment health checks
- **Fixed**: `api.py` `get_paper()` now filters by exact paper_id
- **Added**: Merged paper-reader orchestration into scholar-agent (Phase A/B/C subagent workflow)
- **Added**: Troubleshooting section (UI drift, profile locks)

## [0.1.0] - 2026-03-20

Initial release of SJH Skills monorepo.

### scholar-agent
- Scholar Inbox CLI with REST API integration
- NotebookLM deep reading via Enhanced Mode
- `add_to_notebooklm.sh` for source ingestion

### cmux
- Terminal orchestration with split panes and multi-agent coordination
- Browser automation and markdown preview
- Sidebar status/progress reporting

### daily-summary
- Git + Claude Code sessions + Notion task aggregation
- Timeline-style Chinese work summary

### notion-lifeos
- PARA method + Make Time journaling
- Natural language CRUD via Notion API

### web-fetcher
- 5-layer fallback: Jina → defuddle.md → markdown.new → OpenCLI → raw HTML
- Platform-specific extraction (zhihu, reddit, twitter, weibo)
