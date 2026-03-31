# Structured Query Guide

For queries that filter by property values, **prefer using the provided scripts** in `scripts/`. They handle API key loading, database ID resolution, and output formatting automatically.

## Create Task — `scripts/create-task.sh`

```bash
# Basic task
./scripts/create-task.sh "Task name" "2026-03-20"

# Completed task
./scripts/create-task.sh "Task name" "2026-03-20" --done

# With project relation (searches by name)
./scripts/create-task.sh "Task name" "2026-03-20" --done --project "Thinking with Image"

# With project relation (by ID, faster)
./scripts/create-task.sh "Task name" "2026-03-20" --project-id "248119f1-..."

# With note relation (searches by title)
./scripts/create-task.sh "Task name" "2026-03-20" --note "Meeting notes"

# With note relation (by ID, faster)
./scripts/create-task.sh "Task name" "2026-03-20" --note-id "328119f1-..."

# Combine project + note
./scripts/create-task.sh "Task name" "2026-03-20" --done --project "X" --note "Y"
```

Typical workflow for backfilling tasks from git history:
1. Claude Code analyzes `git log` and groups commits into meaningful tasks
2. Calls `create-task.sh` for each task with `--done --project "Project Name"`

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

## Notes Queries — `scripts/query-notes.sh`

```bash
# Recent 30 days (default)
./scripts/query-notes.sh

# Filter by Note Type
./scripts/query-notes.sh --type Thoughts

# Thoughts from last 60 days
./scripts/query-notes.sh --type Thoughts --days 60

# Filter by tag
./scripts/query-notes.sh --tag "RL"

# Change result limit (default: 20)
./scripts/query-notes.sh --limit 50
```

Output shows date, Note Type, title, tags, and page ID for each note. Sorted by date descending (newest first).

## Projects Queries — `scripts/query-projects.sh`

```bash
# Active projects (default)
./scripts/query-projects.sh

# Filter by status
./scripts/query-projects.sh --status "On Hold"

# All projects
./scripts/query-projects.sh --all

# Change result limit (default: 20)
./scripts/query-projects.sh --limit 50
```

Output shows status, project name (Log name), end date, and page ID.

## Task Date Range Queries

In addition to `--date` for a single day, `query-tasks.sh` supports date ranges:

```bash
# Tasks due since March 1st
./scripts/query-tasks.sh --since 2026-03-01

# Tasks due between two dates
./scripts/query-tasks.sh --since 2026-03-01 --until 2026-03-31

# Completed tasks (by last_edited_time, not due date)
./scripts/query-tasks.sh --done --since 2026-03-01 --by-edited

# --date and --since/--until are MUTUALLY EXCLUSIVE
# This will ERROR:
./scripts/query-tasks.sh --date today --since 2026-03-01
```

The `--by-edited` flag switches filtering from `Due Date` to `last_edited_time`. Use this for `/drift` to find tasks actually completed in a period (regardless of when they were due).

## Drift Data Collection — `scripts/collect-drift-data.sh`

```bash
# Aggregate 30 days of drift data (default)
./scripts/collect-drift-data.sh --days 30

# 60 days
./scripts/collect-drift-data.sh --days 60
```

Outputs three sections: active projects, git commits (author-filtered, grouped by repo), and completed tasks. Designed to feed into CC's `/drift` analysis.

## Other Databases — REST API

For querying Areas or Resources by property values, use curl. Requires API key at `~/.config/notion/api_key`.

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
