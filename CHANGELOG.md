# Changelog

All notable changes to SJH Skills are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Each skill's changes are grouped under its name.

## [Unreleased]

### obsidian-brain

#### Added
- New skill: Obsidian Second Brain — dual-zone vault integration with Claude Code
- Vault initialization script with git version control
- Zone-enforced safe-write script (realpath validation, path traversal protection)
- Wikilink query script (ripgrep-based, obsidian-cli fallback ready)
- Capture script for drafting user input to AI zone
- Templates for all content types (note, task, project, resource, daily, meeting-transcript, context)
- Reference docs: vault schema and command guide
- Zone boundary tests with traversal/symlink attack coverage

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
