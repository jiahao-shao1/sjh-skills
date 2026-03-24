# Notion MCP Tools Operation Guide

For: Claude Code, Claude.ai, and other environments with Notion MCP integration.

## Available Tools

- `notion-search` — Search workspace content and databases
- `notion-fetch` — Get page/database details and schema
- `notion-create-pages` — Create pages
- `notion-update-page` — Update page properties or content
- `notion-create-database` — Create databases

## Getting Database IDs

Follow "Business Rules > Database ID Resolution" in SKILL.md. Use `data_source_id` values from `CONFIG.private.md`.

If discovering IDs dynamically: use `notion-search` to find the "LifeOS" root page, then `notion-fetch` to extract `<data-source>` IDs.

## Creating Entries

Use `notion-create-pages` with `data_source_id` as parent.

**Property format requirements (MCP-specific):**
- Property values use flat strings, not the nested object format of REST API
- Date: split into `date:PropertyName:start`, `date:PropertyName:end`, `date:PropertyName:is_datetime`
- Checkbox: use `__YES__` / `__NO__` (not true/false)
- multi_select: comma-separated string
- URL property: prefix property name with `userDefined:` (e.g., `userDefined:URL`)

### Create Task Example

```json
{
  "parent": {"data_source_id": "<Task data_source_id from CONFIG.private.md>"},
  "pages": [{
    "properties": {
      "Name": "Finish quarterly report",
      "date:Due Date:start": "2026-03-15",
      "date:Due Date:is_datetime": 0,
      "Done": "__NO__"
    }
  }]
}
```

### Create Note Example

```json
{
  "parent": {"data_source_id": "<Notes data_source_id>"},
  "pages": [{
    "properties": {
      "Note": "Product team Q2 OKR discussion notes",
      "Note Type": "Records",
      "Tags": "product, Q2",
      "date:Date:start": "2026-03-08",
      "date:Date:is_datetime": 0
    },
    "content": "## Key Points\n\n- Focus on improving user retention to 85%"
  }]
}
```

### Create Make Time Journal Example

```json
{
  "parent": {"data_source_id": "<Make Time data_source_id>"},
  "pages": [{
    "properties": {
      "Name": "2026-03-08",
      "date:Date:start": "2026-03-08",
      "date:Date:is_datetime": 0,
      "Highlight": "Project finally launched",
      "Grateful": "The team's dedication",
      "Let Go": "Anxiety about the delay"
    }
  }]
}
```

## Querying Data

### Semantic Search (MCP)

Use `notion-search` for keyword/semantic queries:

- Global search: `{"query": "quarterly report"}`
- Search within a database: `{"query": "meeting notes", "data_source_url": "collection://<data_source_id>"}`

To get full page content: first use `notion-search` to find the page ID, then use `notion-fetch` for details.

**Limitation:** `notion-search` is semantic search only. It cannot filter by property values (e.g., Due Date = today, Done = false). Results may be incomplete for structured queries.

### Structured Queries (REST API fallback)

For queries that require filtering by property values (dates, checkboxes, selects), use the Notion REST API via curl. This requires an API key at `~/.config/notion/api_key`.

**Query today's tasks:**
```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -s -X POST "https://api.notion.com/v1/databases/<database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "property": "Due Date",
      "date": {"equals": "2026-03-18"}
    },
    "sorts": [{"property": "Due Date", "direction": "ascending"}]
  }'
```

**Query incomplete tasks:**
```bash
curl -s -X POST "https://api.notion.com/v1/databases/<database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "property": "Done",
      "checkbox": {"equals": false}
    },
    "sorts": [{"property": "Due Date", "direction": "ascending"}]
  }'
```

**When to use which:**
| Query Type | Use |
|------------|-----|
| Find pages by keyword/content | MCP `notion-search` |
| Get full page content | MCP `notion-fetch` |
| Filter by date/checkbox/select | REST API via curl |
| Create/update pages | MCP `notion-create-pages` / `notion-update-page` |

## Updating Entries

Use `notion-update-page`:

**Complete a task:**
```json
{
  "page_id": "<page_id>",
  "command": "update_properties",
  "properties": {"Done": "__YES__"}
}
```

**Update page body:**
```json
{
  "page_id": "<page_id>",
  "command": "update_content",
  "content_updates": [{"old_str": "old content", "new_str": "new content"}]
}
```
