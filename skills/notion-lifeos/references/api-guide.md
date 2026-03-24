# Notion REST API Operation Guide

For: OpenClaw, Codex, and other Agent environments that call Notion API via HTTP.

## Prerequisites

Requires a Notion API Key, stored at `~/.config/notion/api_key`:

```bash
mkdir -p ~/.config/notion
echo "your_notion_api_key_here" > ~/.config/notion/api_key
chmod 600 ~/.config/notion/api_key
```

How to get it: Visit https://www.notion.so/my-integrations to create an Integration.

## API Basics

- Base URL: `https://api.notion.com/v1`
- Auth: `Authorization: Bearer $NOTION_KEY`
- Version: `Notion-Version: 2022-06-28`
- Rate limit: ~3 req/s

## Getting Database IDs

Follow "Business Rules > Database ID Resolution" in SKILL.md. Use `database_id` values from `CONFIG.private.md`. If discovering IDs dynamically via API:

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -X POST "https://api.notion.com/v1/search" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"query": "Task Database", "filter": {"property": "object", "value": "database"}}'
```

## Creating Entries

### Create Task

```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "<task_database_id>"},
    "properties": {
      "Name": {"title": [{"text": {"content": "Finish quarterly report"}}]},
      "Due Date": {"date": {"start": "2026-03-15"}},
      "Done": {"checkbox": false}
    }
  }'
```

### Create Note

```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "<notes_database_id>"},
    "properties": {
      "Note": {"title": [{"text": {"content": "Product team Q2 OKR discussion notes"}}]},
      "Note Type": {"select": {"name": "Records"}},
      "Tags": {"multi_select": [{"name": "product"}, {"name": "Q2"}]},
      "Date": {"date": {"start": "2026-03-08"}}
    },
    "children": [
      {
        "object": "block",
        "type": "heading_2",
        "heading_2": {"rich_text": [{"text": {"content": "Key Points"}}]}
      },
      {
        "object": "block",
        "type": "bulleted_list_item",
        "bulleted_list_item": {"rich_text": [{"text": {"content": "Focus on improving user retention to 85%"}}]}
      }
    ]
  }'
```

### Create Make Time Journal

```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "<maketime_database_id>"},
    "properties": {
      "Name": {"title": [{"text": {"content": "2026-03-08"}}]},
      "Date": {"date": {"start": "2026-03-08"}},
      "Highlight": {"rich_text": [{"text": {"content": "Project finally launched"}}]},
      "Grateful": {"rich_text": [{"text": {"content": "The team's dedication"}}]},
      "Let Go": {"rich_text": [{"text": {"content": "Anxiety about the delay"}}]}
    }
  }'
```

## Querying Data

### Query Incomplete Tasks

```bash
curl -X POST "https://api.notion.com/v1/databases/<task_database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {"property": "Done", "checkbox": {"equals": false}},
    "sorts": [{"property": "Due Date", "direction": "ascending"}]
  }'
```

### Query Recent Notes

```bash
curl -X POST "https://api.notion.com/v1/databases/<notes_database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "sorts": [{"property": "Created time", "direction": "descending"}],
    "page_size": 10
  }'
```

## Updating Entries

### Complete a Task

```bash
curl -X PATCH "https://api.notion.com/v1/pages/<page_id>" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {"Done": {"checkbox": true}}
  }'
```

### Add Page Content

```bash
curl -X PATCH "https://api.notion.com/v1/blocks/<page_id>/children" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "children": [
      {"object": "block", "type": "paragraph",
       "paragraph": {"rich_text": [{"text": {"content": "New content"}}]}}
    ]
  }'
```

## Notes

- Use `database_id` for creating pages, `databases/<id>/query` for querying
- Relation fields require the target page's page_id
- Button block automations may be lost when created via API
