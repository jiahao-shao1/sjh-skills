#!/bin/bash
# Query notes with flexible filters: by type, by tag, by date range, or combined
#
# Usage:
#   ./query-notes.sh                              # Recent 30 days
#   ./query-notes.sh --type Thoughts              # Filter by Note Type
#   ./query-notes.sh --type Thoughts --days 60    # Thoughts from last 60 days
#   ./query-notes.sh --tag "RL"                   # Filter by tag
#   ./query-notes.sh --limit 50                   # Change limit (default: 20)
#
# Requires: NOTION_KEY or ~/.config/notion/api_key
# Requires: CONFIG.private.md in the skill directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.config/notion-lifeos/CONFIG.private.md"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SKILL_DIR/CONFIG.private.md"

# Defaults
NOTE_TYPE=""
DAYS=""
TAG=""
LIMIT=20
HAS_FILTER=false

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      NOTE_TYPE="$2"
      HAS_FILTER=true
      shift 2
      ;;
    --days)
      DAYS="$2"
      HAS_FILTER=true
      shift 2
      ;;
    --tag)
      TAG="$2"
      HAS_FILTER=true
      shift 2
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

# Default: last 30 days if no filter specified
if [ "$HAS_FILTER" = false ]; then
  DAYS=30
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

# Extract Notes database_id from CONFIG.private.md
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Run setup first."
  exit 1
fi

DB_ID=$(grep -i "| Notes " "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

if [ -z "$DB_ID" ]; then
  echo "ERROR: Could not find Notes database_id in CONFIG.private.md"
  exit 1
fi

# Build filter JSON
FILTERS=()

if [ -n "$NOTE_TYPE" ]; then
  FILTERS+=("{\"property\": \"Note Type\", \"select\": {\"equals\": \"$NOTE_TYPE\"}}")
fi

if [ -n "$DAYS" ]; then
  # Compute start date (macOS date -v, fallback to GNU date -d)
  START_DATE=$(date -v-${DAYS}d +%Y-%m-%d 2>/dev/null || date -d "-${DAYS} days" +%Y-%m-%d)
  FILTERS+=("{\"property\": \"Date\", \"date\": {\"on_or_after\": \"$START_DATE\"}}")
fi

if [ -n "$TAG" ]; then
  FILTERS+=("{\"property\": \"Tags\", \"multi_select\": {\"contains\": \"$TAG\"}}")
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
    \"sorts\": [{\"property\": \"Date\", \"direction\": \"descending\"}],
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
    print('No notes found matching the criteria.')
    sys.exit(0)

print(f'Found {len(results)} note(s)')
print()

for r in results:
    props = r['properties']
    # Title: 'Note' property (not 'Name')
    title_prop = props.get('Note', {}).get('title', [])
    title = title_prop[0]['plain_text'] if title_prop else '(untitled)'
    # Note Type
    note_type = props.get('Note Type', {}).get('select', {})
    type_str = note_type.get('name', '—') if note_type else '—'
    # Date
    date = props.get('Date', {}).get('date')
    date_str = date['start'] if date else 'no date'
    # Tags
    tags = props.get('Tags', {}).get('multi_select', [])
    tags_str = ', '.join(t['name'] for t in tags) if tags else ''
    tags_display = f'  (tags: {tags_str})' if tags_str else ''
    # Page ID
    page_id = r['id']
    print(f'  [{date_str}] [{type_str}] {title}{tags_display}  (id: {page_id})')
" <<< "$RESPONSE"
