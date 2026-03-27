# Changelog

All notable changes to SJH Skills are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/). Each skill's changes are grouped under its name.

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
