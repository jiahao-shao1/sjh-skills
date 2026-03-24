#!/bin/bash
# List all incomplete tasks, sorted by due date
# Usage: ./list_undone_tasks.sh [limit]
# Requires: NOTION_KEY or ~/.config/notion/api_key
# Requires: CONFIG.private.md in the skill directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.config/notion-lifeos/CONFIG.private.md"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SKILL_DIR/CONFIG.private.md"

LIMIT="${1:-20}"

# Read API key
if [ -z "${NOTION_KEY:-}" ]; then
  KEY_FILE="$HOME/.config/notion/api_key"
  if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: No NOTION_KEY env var and $KEY_FILE not found"
    exit 1
  fi
  NOTION_KEY=$(cat "$KEY_FILE")
fi

# Extract Task database_id from CONFIG.private.md
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Run setup first."
  exit 1
fi

DB_ID=$(grep -i "| Task " "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

if [ -z "$DB_ID" ]; then
  echo "ERROR: Could not find Task database_id in CONFIG.private.md"
  exit 1
fi

# Query incomplete tasks
RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$DB_ID/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "{
    \"filter\": {
      \"property\": \"Done\",
      \"checkbox\": {\"equals\": false}
    },
    \"sorts\": [{\"property\": \"Due Date\", \"direction\": \"ascending\"}],
    \"page_size\": $LIMIT
  }")

# Format output
python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('No incomplete tasks found.')
    sys.exit(0)

print(f'Found {len(results)} incomplete task(s):')
print()
for r in results:
    props = r['properties']
    name = props.get('Name', {}).get('title', [{}])
    name = name[0]['plain_text'] if name else '(untitled)'
    due = props.get('Due Date', {}).get('date')
    due_str = due['start'] if due else 'no due date'
    page_id = r['id']
    print(f'  - [{due_str}] {name}  (id: {page_id})')
" <<< "$RESPONSE"
