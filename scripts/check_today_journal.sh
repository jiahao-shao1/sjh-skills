#!/bin/bash
# Check if today's Make Time journal entry already exists
# Usage: ./check_today_journal.sh [date]
# If no date provided, uses today's date
# Requires: NOTION_KEY or ~/.config/notion/api_key
# Requires: CONFIG.private.md in the skill directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.config/notion-lifeos/CONFIG.private.md"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SKILL_DIR/CONFIG.private.md"

DATE="${1:-$(date +%Y-%m-%d)}"

# Read API key
if [ -z "${NOTION_KEY:-}" ]; then
  KEY_FILE="$HOME/.config/notion/api_key"
  if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: No NOTION_KEY env var and $KEY_FILE not found"
    exit 1
  fi
  NOTION_KEY=$(cat "$KEY_FILE")
fi

# Extract Make Time database_id from CONFIG.private.md
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Run setup first."
  exit 1
fi

DB_ID=$(grep -i "Make Time" "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

if [ -z "$DB_ID" ]; then
  echo "ERROR: Could not find Make Time database_id in CONFIG.private.md"
  exit 1
fi

# Query for today's entry
RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$DB_ID/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "{
    \"filter\": {
      \"property\": \"Date\",
      \"date\": {\"equals\": \"$DATE\"}
    }
  }")

COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('results',[])))" 2>/dev/null || echo "0")

if [ "$COUNT" -gt "0" ]; then
  PAGE_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['results'][0]['id'])")
  echo "EXISTS: Today's journal ($DATE) already exists. Page ID: $PAGE_ID"
  echo "ACTION: Update rather than create a new entry."
  exit 0
else
  echo "NOT_FOUND: No journal entry for $DATE."
  echo "ACTION: Safe to create a new entry."
  exit 0
fi
