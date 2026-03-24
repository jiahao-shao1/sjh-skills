#!/bin/bash
# Query tasks with flexible filters: by date, by done/undone, or combined
#
# Usage:
#   ./query-tasks.sh                        # All incomplete tasks
#   ./query-tasks.sh --date today           # Today's tasks (done + undone)
#   ./query-tasks.sh --date 2026-03-18      # Tasks for a specific date
#   ./query-tasks.sh --date today --undone  # Today's incomplete tasks only
#   ./query-tasks.sh --done                 # All completed tasks
#   ./query-tasks.sh --undone               # All incomplete tasks
#   ./query-tasks.sh --limit 50             # Change result limit (default: 20)
#
# Requires: NOTION_KEY or ~/.config/notion/api_key
# Requires: CONFIG.private.md in the skill directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.config/notion-lifeos/CONFIG.private.md"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SKILL_DIR/CONFIG.private.md"

# Defaults
DATE=""
DONE_FILTER=""
LIMIT=20

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --date)
      DATE="$2"
      if [ "$DATE" = "today" ]; then
        DATE=$(date +%Y-%m-%d)
      elif [ "$DATE" = "tomorrow" ]; then
        DATE=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)
      elif [ "$DATE" = "yesterday" ]; then
        DATE=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "-1 day" +%Y-%m-%d)
      fi
      shift 2
      ;;
    --done)
      DONE_FILTER="true"
      shift
      ;;
    --undone)
      DONE_FILTER="false"
      shift
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Default: show undone if no filter specified
if [ -z "$DATE" ] && [ -z "$DONE_FILTER" ]; then
  DONE_FILTER="false"
fi

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

# Build filter JSON
FILTERS=()

if [ -n "$DATE" ]; then
  FILTERS+=("{\"property\": \"Due Date\", \"date\": {\"equals\": \"$DATE\"}}")
fi

if [ -n "$DONE_FILTER" ]; then
  FILTERS+=("{\"property\": \"Done\", \"checkbox\": {\"equals\": $DONE_FILTER}}")
fi

if [ ${#FILTERS[@]} -eq 0 ]; then
  FILTER_JSON=""
elif [ ${#FILTERS[@]} -eq 1 ]; then
  FILTER_JSON="\"filter\": ${FILTERS[0]},"
else
  JOINED=$(IFS=,; echo "${FILTERS[*]}")
  FILTER_JSON="\"filter\": {\"and\": [$JOINED]},"
fi

# Query
RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$DB_ID/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "{
    $FILTER_JSON
    \"sorts\": [{\"property\": \"Due Date\", \"direction\": \"ascending\"}],
    \"page_size\": $LIMIT
  }")

# Format output
python3 -c "
import sys, json

data = json.load(sys.stdin)

if 'object' not in data or data['object'] == 'error':
    print(f'ERROR: {data.get(\"message\", \"Unknown API error\")}')
    sys.exit(1)

results = data.get('results', [])
if not results:
    print('No tasks found matching the criteria.')
    sys.exit(0)

done_count = sum(1 for r in results if r['properties'].get('Done', {}).get('checkbox', False))
undone_count = len(results) - done_count

print(f'Found {len(results)} task(s): {done_count} done, {undone_count} pending')
print()

for r in results:
    props = r['properties']
    name_prop = props.get('Name', {}).get('title', [])
    name = name_prop[0]['plain_text'] if name_prop else '(untitled)'
    done = props.get('Done', {}).get('checkbox', False)
    due = props.get('Due Date', {}).get('date')
    due_str = due['start'] if due else 'no due date'
    status = '✅' if done else '⬜'
    page_id = r['id']
    print(f'  {status} [{due_str}] {name}  (id: {page_id})')
" <<< "$RESPONSE"
