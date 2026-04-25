---
name: notion-lifeos
description: "User's personal Notion LifeOS (PARA: tasks, notes, projects, Make Time journals) with pre-configured DB IDs + API access — required for any LifeOS interaction. Use for adding tasks, taking notes, journaling, querying todos, searching notes, creating projects, reflection. Triggers: 'add task', 'take a note', 'what do I need to do', 'search my notes', '加个任务', '查笔记', '待办', '记录想法', '反思', '目标偏移'. Not for Notion API docs or workspace admin."
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
| "Query my recent thoughts" | Notes | `scripts/query-notes.sh --type Thoughts` |
| "List active projects" | Projects | `scripts/query-projects.sh` |
| "Tasks completed this month" | Task | `scripts/query-tasks.sh --done --since YYYY-MM-DD --by-edited` |
| "/challenge X" | Notes | `scripts/query-notes.sh` + CC analysis (see Reflection Commands) |
| "/emerge" | Notes | `scripts/query-notes.sh` + CC analysis (see Reflection Commands) |
| "/drift" | Projects + Task + Git | `scripts/collect-drift-data.sh` + CC analysis (see Reflection Commands) |

For Note Type selection and Make Time journal extraction logic, see [references/query-guide.md](./references/query-guide.md).
For composite intents (multiple actions in one message), see [references/advanced.md](./references/advanced.md).

## Business Rules

1. **Database IDs**: Read `~/.config/notion-lifeos/CONFIG.private.md` for IDs (fallback: `CONFIG.private.md` in skill dir). If missing, search for "LifeOS" root page (NOT "LifeOS Template"). Last resort: guide user to [references/setup.md](./references/setup.md).
2. **Schema-first**: Fetch database schema before first write in a session — confirm property names and allowed select values.
3. **Make Time dedup**: Always check if today's entry exists before creating (`scripts/check_today_journal.sh`). Update if exists.
4. **Date format**: ISO-8601 only (e.g., `2026-03-08`).
5. **Relations**: Require target page ID — search for it first.
6. **Post-op confirmation**: Always confirm results to the user.

## Reflection Commands

These commands use Notion data + Git history as input, with CC performing the analysis. Output is **terminal only** — never write to Notion.

### /challenge \<topic\>

Stress-test a current belief against past writing.

1. Run `scripts/query-notes.sh --type Thoughts --days 90 --limit 50`
2. Scan the returned **titles** for relevance to the topic
3. Use MCP `notion-fetch` to read the **top 15-20** most relevant notes (do NOT fetch all 50 — context budget)
4. Analyze: identify contradictions, weak assumptions, and evidence gaps
5. Output in Chinese: "当前信念 → 矛盾证据 → 更强的替代假设"

### /emerge

Surface recurring themes and hidden patterns in recent thinking.

1. Run `scripts/query-notes.sh --type Thoughts --days 30 --limit 50`
2. Scan **titles** first — select top 15 most interesting/diverse
3. Use MCP `notion-fetch` to read those 15 notes
4. Identify: recurring themes, emotional patterns, unasked questions, connections the user hasn't made explicit
5. Output in Chinese, grouped by theme, quoting original notes

### /drift \[N days\]

Detect gaps between stated goals and actual activity.

1. Run `scripts/collect-drift-data.sh --days N` (default 30)
2. Read `~/.claude/rules/personal-context.md` for project↔repo mapping hints
3. Perform **semantic matching** (project names like "Thinking with Image" ≠ repo names like "agentic_umm" — match by meaning, not string)
4. Analyze:
   - Per-project: git commit count + completed task count
   - **幽灵项目**: active in Notion but zero git/task activity
   - **隐性工作**: heavy git activity in repos not mapped to any active project
   - Time allocation distribution
5. Output in Chinese: "项目活跃度矩阵" + "幽灵项目" + "隐性工作" + "建议"

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
