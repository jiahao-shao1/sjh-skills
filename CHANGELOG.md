# Changelog

All notable changes to SJH Skills are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Each skill's changes are grouped under its name.

## [1.10.2] - 2026-04-21

### remote-cluster-agent

#### Fixed
- Agent handshake error paths now reap the child subprocess, preventing a zombie leak in the daemon. `Connection.Connect()` killed the child on handshake timeout / read error / unexpected handshake without a matching `Wait()`, so every failed dial left a `<defunct>` child. With auto-reconnect retrying dead nodes every 150s × 3 retries per dial, this could exhaust the per-user process limit within ~2 hours and hang the whole shell session. Fix mirrors `closeLocked()` — `Kill()` + `Process.Wait()` on every error exit from `Connect()`.

## [1.10.1] - 2026-04-19

### remote-cluster-agent

#### Fixed
- `SKILL.md` frontmatter failed YAML parsing in Codex (`mapping values are not allowed in this context at line 2 column 319`). The unquoted `description` contained `: ` sequences such as `Trigger words: cluster`, which YAML interpreted as nested mappings. Wrapped the description in double quotes and replaced inner `: ` with ` — `, matching `scholar-agent`'s convention

## [1.10.0] - 2026-04-19

### init-project

#### Added
- `post-knowledge-remind.sh` — new PostToolUse hook (Bash matcher) that nudges capturing debugging experience into `docs/knowledge/` when a command exits non-zero. Frequency-limited (max 3 per session, 5-minute cooldown) and outputs `systemMessage` JSON
- Agent frontmatter fields documented and applied to generated agents: `memory` (`project` / `session`), `permissionMode` (`bypassPermissions` / `plan` / `default`), `maxTurns` (bounded execution)
- Chain-hints pattern in `details/agent-templates.md` — upstream agents can point at downstream agents in their `## Notes` section so the orchestrator routes output correctly

#### Changed
- Progressive disclosure redesign — dropped the centralized "Knowledge Quick Reference" and "Progressive References" tables in `CLAUDE.md` in favor of inline references inside each `.claude/rules/` file, so knowledge surfaces at the point of need instead of being buried in a lookup table
- Experiment registry switched from markdown `docs/knowledge/experiments.md` to YAML `docs/experiment-registry/registry/*.yaml` managed by the `exp-registry` CLI (`pip install exp-registry`)
- HANDOFF mode now points users at the `/handoff` skill (in-conversation summary) instead of writing a `HANDOFF.md` file
- Generated agents ship with explicit permission modes: `code-verifier` → `permissionMode: bypassPermissions` + `maxTurns: 15`; `planner` and `domain-expert` → `permissionMode: plan`; `domain-expert` also gets `memory: project`
- `.claude/settings.json` now registers a `Bash`-matcher PostToolUse hook for knowledge reminders alongside the existing `Edit|Write` matchers

## [1.9.0] - 2026-04-19

### context-audit

#### Added
- New skill that audits the three-layer context architecture (`CLAUDE.md` / `.claude/rules/` / `docs/knowledge/`) for progressive disclosure compliance
- Cross-references knowledge files against rule files to detect orphaned knowledge, stale references, and CLAUDE.md index leakage
- Read-only report output with coverage summary, orphan list, stale-reference table, and optional fix suggestions — never auto-applies changes

## [1.8.1] - 2026-04-18

### remote-cluster-agent

**File transfer & agent deploy bug fixes** (bumps skill VERSION `0.4.0` → `0.4.1`)

#### Fixed
- `rca cp` now resolves relative local paths against the user's shell cwd before sending to the daemon. Previously the daemon's own cwd was used, causing `open xxx: no such file or directory` for any relative path.
- `rca cp` success messages (`uploaded ...`, `downloaded ...`) now end with a newline, so subsequent command output no longer concatenates onto the same line.
- `rca agent deploy` no longer hangs on active nodes under tunneled SSH. When the agent is reachable through the daemon, the deploy now uploads via the existing agent channel (`/exec` mkdir + `/transfer` + `/exec` chmod +x) instead of spawning an SSH subprocess. SSH remains as a fallback for brand-new nodes and is bounded by context timeouts (30s mkdir / 60s write) so dead or wedged nodes can't block the rest of the deploy.

## [1.8.0] - 2026-04-18

### remote-cluster-agent

**Architecture: MCP server → Go daemon + `rca` CLI** (bumps skill VERSION `0.3.0` → `0.4.0`)

#### Breaking
- Python MCP server replaced with a local Go daemon + `rca` CLI. Tool rename: `remote_bash(node, cmd)` → `rca exec -n <node> "<cmd>"`; `remote_bash_batch` → `rca batch`.
- Config moved from two-layer markdown (`~/.config/remote-cluster-agent/context.local.md` + `<project>.md`) to a single TOML (`~/.config/rca/config.toml`). `rca config init` auto-detects and migrates the legacy markdown.
- Removed: `mcp-server/`, `reference/context.template.md`, `reference/project.template.md`.

#### Added
- `cmd/rca/` + `internal/` — Go daemon with lazy-start, connection pool, Unix socket HTTP server, node health monitor.
- `rca exec` / `rca batch` / `rca cp` / `rca nodes` / `rca connect` / `rca disconnect` / `rca agent check|deploy` / `rca daemon start|stop|status|logs|register` / `rca config init|show|edit`.
- `rca cp` — file transfer via the agent's JSON-Lines channel (base64, 50 MB/file). Works with any SSH transport.
- `rca nodes --check` / `--health` — deep latency probe and per-node latency history.
- Node health monitor — daemon periodically pings connected nodes (default 30s), tracks latency in a ring buffer (60 samples), flags degradation (>200ms absolute or >3× median), optional auto-reconnect.
- `rca daemon register` — optional launchd auto-start on macOS.
- Agent protocol v2.1 (`cluster-agent/agent.py` bumped `1.0.0` → `2.1.0`): streaming output, command cancellation, batch execution, file read/write through the agent channel.
- Mutagen troubleshooting: container-restart recovery (`~/.mutagen` symlink fix for `server magic number incorrect`).

#### Fixed
- MCP stdio drops eliminated entirely — the AI agent interacts with the daemon through CLI invocations, so there are no more MCP progress-notification races.
- Multi-session SSH explosion — N agent sessions × M nodes collapses to 1 daemon × M persistent connections.

## [1.7.0] - 2026-04-17

### experiment-registry

#### Added
- `exp validate` command — checks filename/id consistency, required fields, known statuses/types, series prefix, date format, and benchmark dataset/eval_mode/steps shape. Supports `--strict` (non-zero exit on issues) and `--json` for CI integration
- Tests covering clean registry, missing `eval_mode`, filename mismatch, strict exit, and JSON output

#### Changed
- Bumped `exp-registry` package version to 0.2.0

## [1.6.4] - 2026-04-17

### experiment-registry

#### Added
- `data_ready` as a known status in `KNOWN_STATUSES`, for experiments whose data is generated but not yet benchmarked

#### Changed
- Bumped `exp-registry` package version to 0.1.1

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
