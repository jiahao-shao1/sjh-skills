#!/bin/bash
# Create a task in Notion with optional project/note relations
#
# Usage:
#   ./create-task.sh "Task name" "2026-03-20"
#   ./create-task.sh "Task name" "2026-03-20" --done
#   ./create-task.sh "Task name" "2026-03-20" --done --project "Project name"
#   ./create-task.sh "Task name" "2026-03-20" --project-id "248119f1-..."
#   ./create-task.sh "Task name" "2026-03-20" --note "Note title"
#   ./create-task.sh "Task name" "2026-03-20" --note-id "328119f1-..."
#   ./create-task.sh "Task name" "2026-03-20" --done --project "X" --note "Y"
#
# Requires: NOTION_KEY or ~/.config/notion/api_key
# Requires: CONFIG.private.md in the skill directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$HOME/.config/notion-lifeos/CONFIG.private.md"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SKILL_DIR/CONFIG.private.md"

# Parse positional args
if [ $# -lt 2 ]; then
  echo "Usage: $0 \"Task name\" \"YYYY-MM-DD\" [--done] [--project \"name\" | --project-id \"id\"] [--note \"title\" | --note-id \"id\"]"
  exit 1
fi

TASK_NAME="$1"
DUE_DATE="$2"
shift 2

DONE="false"
PROJECT_NAME=""
PROJECT_ID=""
NOTE_NAME=""
NOTE_ID=""

# Parse optional args
while [[ $# -gt 0 ]]; do
  case $1 in
    --done)
      DONE="true"
      shift
      ;;
    --project)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --note)
      NOTE_NAME="$2"
      shift 2
      ;;
    --note-id)
      NOTE_ID="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Read API key
if [ -z "${NOTION_KEY:-}" ]; then
  KEY_FILE="$HOME/.config/notion/api_key"
  if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: No NOTION_KEY env var and $KEY_FILE not found"
    exit 1
  fi
  NOTION_KEY=$(cat "$KEY_FILE")
fi

# Extract database IDs from CONFIG.private.md
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE not found. Run setup first."
  exit 1
fi

TASK_DB_ID=$(grep -i "| Task " "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
if [ -z "$TASK_DB_ID" ]; then
  echo "ERROR: Could not find Task database_id in CONFIG.private.md"
  exit 1
fi

# Resolve project name to ID if needed
if [ -n "$PROJECT_NAME" ] && [ -z "$PROJECT_ID" ]; then
  PROJECTS_DB_ID=$(grep -i "| Projects " "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
  if [ -z "$PROJECTS_DB_ID" ]; then
    echo "ERROR: Could not find Projects database_id in CONFIG.private.md"
    exit 1
  fi

  SEARCH_RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$PROJECTS_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d "{\"filter\": {\"property\": \"Log name\", \"title\": {\"contains\": \"$PROJECT_NAME\"}}}")

  PROJECT_ID=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('')
else:
    print(results[0]['id'])
" <<< "$SEARCH_RESPONSE")

  if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: Project '$PROJECT_NAME' not found"
    exit 1
  fi
fi

# Resolve note name to ID if needed
if [ -n "$NOTE_NAME" ] && [ -z "$NOTE_ID" ]; then
  NOTES_DB_ID=$(grep -i "| Notes " "$CONFIG_FILE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
  if [ -z "$NOTES_DB_ID" ]; then
    echo "ERROR: Could not find Notes database_id in CONFIG.private.md"
    exit 1
  fi

  SEARCH_RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$NOTES_DB_ID/query" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d "{\"filter\": {\"property\": \"Note\", \"title\": {\"contains\": \"$NOTE_NAME\"}}}")

  NOTE_ID=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if not results:
    print('')
else:
    print(results[0]['id'])
" <<< "$SEARCH_RESPONSE")

  if [ -z "$NOTE_ID" ]; then
    echo "ERROR: Note '$NOTE_NAME' not found"
    exit 1
  fi
fi

# Build properties JSON
PROPERTIES=$(python3 -c "
import json, sys
done = True if '$DONE' == 'true' else False
props = {
    'Name': {'title': [{'text': {'content': sys.argv[1]}}]},
    'Due Date': {'date': {'start': '$DUE_DATE'}},
    'Done': {'checkbox': done}
}
project_id = '$PROJECT_ID'
if project_id:
    props['Related to Projects'] = {'relation': [{'id': project_id}]}
note_id = '$NOTE_ID'
if note_id:
    props['Related to Notes'] = {'relation': [{'id': note_id}]}
print(json.dumps(props))
" "$TASK_NAME")

# Create the task
RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "{\"parent\": {\"database_id\": \"$TASK_DB_ID\"}, \"properties\": $PROPERTIES}")

# Output result
python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('object') == 'error':
    print(f'ERROR: {data.get(\"message\", \"Unknown error\")}')
    sys.exit(1)
page_id = data['id']
done_flag = sys.argv[1] == 'true'
done_icon = '✅' if done_flag else '⬜'
project_info = f' [project: {sys.argv[4]}]' if sys.argv[4] else ''
note_info = f' [note: {sys.argv[5]}]' if sys.argv[5] else ''
print(f'{done_icon} [{sys.argv[2]}] {sys.argv[3]}  (id: {page_id}){project_info}{note_info}')
" "$DONE" "$DUE_DATE" "$TASK_NAME" "${PROJECT_NAME:-${PROJECT_ID:-}}" "${NOTE_NAME:-${NOTE_ID:-}}" <<< "$RESPONSE"
