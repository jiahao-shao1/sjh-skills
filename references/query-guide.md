# Structured Query Guide

For queries that filter by property values, **prefer using the provided scripts** in `scripts/`. They handle API key loading, database ID resolution, and output formatting automatically.

## Task Queries — `scripts/query-tasks.sh`

```bash
# Today's tasks (both done and undone, showing status)
./scripts/query-tasks.sh --date today

# Today's incomplete tasks only
./scripts/query-tasks.sh --date today --undone

# All incomplete tasks (sorted by due date)
./scripts/query-tasks.sh --undone

# All completed tasks
./scripts/query-tasks.sh --done

# Tasks for a specific date
./scripts/query-tasks.sh --date 2026-03-18

# Yesterday's tasks
./scripts/query-tasks.sh --date yesterday

# Change result limit (default: 20)
./scripts/query-tasks.sh --undone --limit 50
```

Output shows done/undone status, due date, task name, and page ID for each task.

## Make Time Dedup Check — `scripts/check_today_journal.sh`

```bash
# Check if today's journal exists (returns page ID if found)
./scripts/check_today_journal.sh

# Check for a specific date
./scripts/check_today_journal.sh 2026-03-18
```

## Other Databases — REST API

For querying Notes, Projects, Areas, or Resources by property values, use curl. Requires API key at `~/.config/notion/api_key`.

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -s -X POST "https://api.notion.com/v1/databases/<database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '<filter_json>'
```

Common filter patterns:
- **By date:** `{"filter": {"property": "Date", "date": {"equals": "2026-03-18"}}}`
- **By select:** `{"filter": {"property": "Note Type", "select": {"equals": "Records"}}}`
- **By checkbox:** `{"filter": {"property": "Done", "checkbox": {"equals": false}}}`
- **Combined (AND):** `{"filter": {"and": [<filter1>, <filter2>]}}`

Parse response: `results[].properties.Name.title[0].plain_text` for title, `.Done.checkbox` for status.

## Note Type Selection

Choose the most appropriate Note Type based on content nature. Fetch allowed values from schema first. Common patterns:

| Content Characteristics | Note Type |
|------------------------|-----------|
| Personal thoughts, inspiration, reflections | Thoughts |
| Meeting records, event logs | Records |
| Study notes, reading notes | Notes |
| Technical docs, tutorials, guides | Documentation |
| Experiment records, test results | Experiments |
| Blog post drafts | My Blog |

When uncertain, ask the user.

## Make Time Journal Extraction

Extract three elements from the user's natural language:

- **Highlight**: The most important/happiest thing today / achievement
- **Grateful**: Things related to gratitude and appreciation
- **Let Go**: Things to release and stop worrying about
