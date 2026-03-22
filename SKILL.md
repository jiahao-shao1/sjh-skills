---
name: notion-lifeos
description: >
  Notion LifeOS — PARA life management with Make Time journaling.
  Activate when: user mentions Notion, notes, tasks, projects, todos, journals,
  or uses phrases like 'take a note', 'add a task', 'what do I need to do',
  'search my notes', 'jot down', 'today was great', 'record a thought',
  or Chinese equivalents like '帮我记一下', '加个任务', '今天要做什么', '查笔记'.
  Also: PARA method, personal knowledge management, daily reviews.
  Do NOT activate for: Notion API docs, Notion pricing/plans, workspace admin,
  database schema modification, or general productivity advice without data intent.
---

# Notion LifeOS Skill

A Notion life management system based on the PARA method and Make Time framework.

## When NOT to Use This Skill

- **Notion product questions** — pricing, features, API documentation, workspace admin
- **Generic productivity advice** — "how should I organize my life" without intent to store/retrieve data
- **Other note-taking apps** — unless user wants to migrate data INTO Notion LifeOS
- **Database schema modification** — creating new databases, adding/removing properties

## Core Principles

- **Capture first, organize later** — Never let processing block input
- **Proactive information surfacing** — Use Relations to automatically surface information where it's needed

See [JEFF_SU_SUMMARY.md](./JEFF_SU_SUMMARY.md) for detailed design philosophy.

## Reference Files

Read these as needed — do NOT load them all upfront:

| File | When to read |
|------|-------------|
| [references/schema.md](./references/schema.md) | Before creating/updating any entry (get field names & types) |
| [references/mcp-guide.md](./references/mcp-guide.md) | When using MCP tools (Claude Code / Claude.ai) |
| [references/api-guide.md](./references/api-guide.md) | When using REST API (OpenClaw / Codex / other agents) |
| [references/query-guide.md](./references/query-guide.md) | When querying/filtering data (tasks by date, done status, etc.) |
| [references/advanced.md](./references/advanced.md) | For composite intents or error handling |

## Operation Guide

- **With Notion MCP tools** → See [references/mcp-guide.md](./references/mcp-guide.md)
- **With Notion API access** → See [references/api-guide.md](./references/api-guide.md)
- **For structured queries** (filter by date, checkbox, select) → Always use scripts or REST API. MCP `notion-search` is semantic only and CANNOT filter by property values.

## Intent Recognition & Database Mapping

| User Intent | Target DB | Method |
|-------------|-----------|--------|
| "Take a note about XXX" | Notes | MCP / API |
| "Add a task: XXX" | Task | `scripts/create-task.sh` / MCP / API |
| "The best thing today was..." | Make Time | MCP / API (check dedup first) |
| "Create project XXX" | Projects | MCP / API |
| "Today's tasks" | Task | `scripts/query-tasks.sh --date today` |
| "Any unfinished tasks?" | Task | `scripts/query-tasks.sh --undone` |
| "Today's unfinished tasks" | Task | `scripts/query-tasks.sh --date today --undone` |
| "Search notes about XX" | Notes | MCP `notion-search` |
| "Add a resource/reference" | Resources | MCP / API |

For Note Type selection and Make Time journal extraction logic, see [references/query-guide.md](./references/query-guide.md).
For composite intents (multiple actions in one message), see [references/advanced.md](./references/advanced.md).

## Business Rules

1. **Database IDs**: Read `CONFIG.private.md` for IDs. If missing, search for "LifeOS" root page (NOT "LifeOS Template"). Last resort: guide user to [references/setup.md](./references/setup.md).
2. **Schema-first**: Fetch database schema before first write in a session — confirm property names and allowed select values.
3. **Make Time dedup**: Always check if today's entry exists before creating (`scripts/check_today_journal.sh`). Update if exists.
4. **Date format**: ISO-8601 only (e.g., `2026-03-08`).
5. **Relations**: Require target page ID — search for it first.
6. **Post-op confirmation**: Always confirm results to the user.

## Gotchas (Common Pitfalls)

### MCP-Specific
- **Checkbox**: `__YES__` / `__NO__`, NOT `true`/`false`
- **URL property**: Prefix with `userDefined:` (e.g., `userDefined:URL`)
- **Date property**: Split into `date:PropName:start`, `date:PropName:end`, `date:PropName:is_datetime`
- **multi_select**: Comma-separated string, NOT array
- **notion-search**: Cannot filter by property values — use scripts/REST API

### REST API-Specific
- **database_id vs data_source_id**: REST API uses `database_id`, MCP uses `data_source_id` — they differ
- **Date filter**: ISO-8601 only, never natural language

### General
- **Select values change**: NEVER hardcode — always fetch schema first
- **Duplicate DB names**: Always use databases under the LifeOS root page
