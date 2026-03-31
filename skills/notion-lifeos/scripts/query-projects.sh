#!/bin/bash
# Query projects with status filtering
#
# Usage:
#   ./query-projects.sh                    # Active projects (default)
#   ./query-projects.sh --status Active    # Filter by status
#   ./query-projects.sh --all              # All projects regardless of status
#   ./query-projects.sh --limit 50         # Change limit (default: 20)
#
# Requires: NOTION_KEY or ~/.config/notion/api_key
# Requires: CONFIG.private.md in the skill directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.config/notion-lifeos/CONFIG.private.md"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SKILL_DIR/CONFIG.private.md"

# Defaults
STATUS=""
ALL=false
LIMIT=20

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --status)
      STATUS="$2"
      shift 2
      ;;
    --all)
      ALL=true
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

# Default: show Active if no filter specified
if [ "$ALL" = false ] && [ -z "$STATUS" ]; then
  STATUS="WIP"
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

# Extract Projects database_id from CONFIG.private.md
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Run setup first."
  exit 1
fi

DB_ID=$(grep -i "| Projects " "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

if [ -z "$DB_ID" ]; then
  echo "ERROR: Could not find Projects database_id in CONFIG.private.md"
  exit 1
fi

# Build filter JSON
if [ -n "$STATUS" ]; then
  FILTER_JSON="\"filter\": {\"property\": \"Status (状态)\", \"select\": {\"equals\": \"$STATUS\"}},"
else
  FILTER_JSON=""
fi

# Query
RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$DB_ID/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "{
    $FILTER_JSON
    \"sorts\": [{\"property\": \"Log name\", \"direction\": \"ascending\"}],
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
    print('No projects found matching the criteria.')
    sys.exit(0)

print(f'Found {len(results)} project(s)')
print()

for r in results:
    props = r['properties']
    # Title: 'Log name' property
    title_prop = props.get('Log name', {}).get('title', [])
    title = title_prop[0]['plain_text'] if title_prop else '(untitled)'
    # Status
    status = props.get('Status (状态)', {}).get('select', {})
    status_str = status.get('name', '—') if status else '—'
    # End Date
    end_date = props.get('End Date', {}).get('date')
    end_str = end_date['start'] if end_date else '—'
    # Page ID
    page_id = r['id']
    print(f'  [{status_str}] {title}  (end: {end_str})  (id: {page_id})')
" <<< "$RESPONSE"
