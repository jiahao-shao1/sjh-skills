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
- **Notion page design** — layout, icons, covers, templates not related to PARA data

## Core Principles

- **Capture first, organize later** — Never let processing block input
- **Proactive information surfacing** — Use Relations to automatically surface information where it's needed
- **Scalable self-awareness** — Every record is a data point for your future AI self

See [JEFF_SU_SUMMARY.md](./JEFF_SU_SUMMARY.md) for detailed design philosophy.

## Database Schema

The system contains 6 core databases (Task, Notes, Projects, Areas, Resources, Make Time) interconnected via Notion Relations. See [references/schema.md](./references/schema.md) for full field definitions.

**Critical rule for select/multi_select fields:** Always fetch the database schema dynamically before writing. Never assume hardcoded option values — they may have changed since this skill was written.

## Operation Guide

Choose the execution method based on your Agent environment:

- **With Notion MCP tools** (e.g., Claude Code / Claude.ai) → See [references/mcp-guide.md](./references/mcp-guide.md)
- **With Notion API access** (e.g., OpenClaw / Codex / other agents) → See [references/api-guide.md](./references/api-guide.md)

How to determine: Check if MCP tools like `notion-search`, `notion-create-pages` are available. If yes, use MCP for creation/updates; otherwise use API.

**Important:** For structured queries that filter by property values (e.g., "today's tasks", "incomplete tasks"), always use the REST API via curl, even in MCP environments. MCP `notion-search` is semantic search only and cannot reliably filter by date, checkbox, or select values. See "Structured Queries" in [references/mcp-guide.md](./references/mcp-guide.md).

## Intent Recognition & Database Mapping

User input → Target database:

| User Intent | Target DB | Action | Method |
|-------------|-----------|--------|--------|
| "Take a note about XXX" | Notes | Create note | MCP / API |
| "Add a task: XXX" | Task | Create task | MCP / API |
| "The best thing today was..." | Make Time | Create/update journal | MCP / API |
| "Create project XXX" | Projects | Create project | MCP / API |
| "Today's tasks" / "What do I need to do today" | Task | Query by Due Date = today | **REST API** (filter by date) |
| "Any unfinished tasks?" | Task | Query by Done = false | **REST API** (filter by checkbox) |
| "Search notes about XX" | Notes | Search by keyword | MCP search |
| "Add a resource/reference" | Resources | Create resource | MCP / API |

### Structured Query Workflow (REST API)

For queries that filter by property values, use the Notion REST API. Requires API key at `~/.config/notion/api_key`.

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -s -X POST "https://api.notion.com/v1/databases/<database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '<filter_json>'
```

Common filters:
- **Today's tasks:** `{"filter": {"property": "Due Date", "date": {"equals": "<today>"}}}`
- **Incomplete tasks:** `{"filter": {"property": "Done", "checkbox": {"equals": false}}}`
- **Today's incomplete tasks:** `{"filter": {"and": [{"property": "Due Date", "date": {"equals": "<today>"}}, {"property": "Done", "checkbox": {"equals": false}}]}}`

Parse the response to extract `properties.Name.title[0].plain_text` and `properties.Done.checkbox` for each result.

### Note Type Selection Logic

Automatically select the appropriate Note Type based on content:

| Content Characteristics | Note Type |
|------------------------|-----------|
| Personal thoughts, inspiration, reflections | Thoughts |
| Meeting records, event logs | Records |
| Study notes, reading notes | Notes |
| Technical docs, tutorials, guides | Documentation |
| Experiment records, test results | Experiments |
| Blog post drafts | My Blog |

### Make Time Journal Extraction Logic

Extract three elements from the user's natural language:

- **Highlight**: The most important/happiest thing today / achievement
- **Grateful**: Things related to gratitude and appreciation
- **Let Go**: Things to release and stop worrying about

## Composite Intent Handling

Users often express multiple intents in a single message. Parse and execute them in dependency order.

| User Input | Intents | Actions |
|------------|---------|---------|
| "Take a note about X and add a task to follow up" | Note + Task | 1. Create note 2. Create task with relation to note |
| "Today's highlight was X, also jot down a thought about Y" | Make Time + Note | 1. Create/update Make Time 2. Create note |
| "Add a task for project Z: do ABC by Friday" | Task + Project lookup | 1. Find project Z 2. Create task with project relation and due date |
| "Search notes about X and create a summary task" | Query + Create | 1. Search notes 2. Create task referencing results |

**Execution strategy:**
1. Parse all intents from the message
2. Resolve dependencies (e.g., need project ID before creating related task)
3. Execute in dependency order
4. If one operation fails, continue with remaining and report partial results
5. Confirm all results at the end

## Business Rules

These rules apply regardless of execution method (MCP or API).

### Database ID Resolution
1. Read `CONFIG.private.md` from the skill directory for database IDs
2. If not found: use the execution guide's search method to locate the LifeOS root page (named "LifeOS", NOT "LifeOS Template"), then extract each database's ID from it
3. If still not found: direct user to [references/setup.md](./references/setup.md)
4. **Warning:** The workspace may have duplicate database names. Always use databases under the LifeOS root page.

### Make Time Deduplication
Before creating a Make Time entry, query the Make Time database for today's date. If an entry already exists, UPDATE it instead of creating a duplicate.

### Schema-First Approach
When operating on a database for the first time in a session, fetch its schema to:
- Confirm property names (they may have been renamed)
- Get current allowed values for select/multi_select fields
- Verify relation targets

### Date Format
All date values must be ISO-8601 format (e.g., `2026-03-08`).

### Relation Fields
Relation fields require the target page's ID. Search for the target page first if needed.

### Post-Operation Confirmation
Always confirm the operation result to the user after creating or updating an entry.

## Error Handling

| Error Scenario | Action |
|---------------|--------|
| Database ID not found | Fall back to LifeOS root page discovery; if that fails, guide user to setup |
| Property name mismatch | Fetch fresh schema, retry with correct property name |
| Select/multi_select value rejected | Fetch schema for allowed values, suggest closest match to user |
| Rate limit (API: ~3 req/s) | Wait and retry; batch operations if possible |
| Page not found (for update/relation) | Re-search using title; confirm with user if ambiguous |
| Relation target ambiguous | Present options to user, ask for clarification |
| Permission denied | Guide user to share LifeOS page with Integration |

**General principles:**
- Never silently fail — always inform the user what happened
- On partial failure in composite operations, report what succeeded and what failed
- Prefer graceful degradation: if a relation can't be set, create the entry without it and inform the user
