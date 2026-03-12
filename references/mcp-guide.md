# Notion MCP Tools Operation Guide

English | [中文](./mcp-guide.zh.md)

For: Claude Code, Claude.ai, and other environments with Notion MCP integration.

## Available Tools

- `notion-search` — Search workspace content and databases
- `notion-fetch` — Get page/database details and schema
- `notion-create-pages` — Create pages
- `notion-update-page` — Update page properties or content
- `notion-create-database` — Create databases

## Getting Database IDs

1. Read `CONFIG.private.md` from the skill directory to get each database's `data_source_id`
2. If the file doesn't exist: use `notion-search` to find "LifeOS" root page, then use `notion-fetch` to get the page content and extract each database's `<data-source>` ID. Only use databases under the LifeOS root page.

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

Use `notion-search` to search workspace content:

- Global search: `{"query": "quarterly report"}`
- Search within a specific database: `{"query": "unfinished", "data_source_url": "collection://<Task data_source_id>"}`

To get full page content: first use `notion-search` to find the page ID, then use `notion-fetch` for details.

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
