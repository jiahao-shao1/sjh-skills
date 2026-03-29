#!/bin/bash
# Create a task file in the vault using human-write.sh for zone enforcement.
#
# Usage:
#   ./create-task.sh <vault-root> "Task title"
#   ./create-task.sh <vault-root> "Task title" --due 2026-04-01 --tags "work,urgent"
#
# Generates: tasks/YYYY-MM-DD-slugified-title.md
# If file exists, appends -2, -3, etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HUMAN_WRITE="$SCRIPT_DIR/human-write.sh"

VAULT_ROOT="$1"
shift
TITLE="$1"
shift

# Parse optional arguments
DUE=""
TAGS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --due)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --due requires a value" >&2
        exit 1
      fi
      DUE="$2"; shift 2 ;;
    --tags)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --tags requires a value" >&2
        exit 1
      fi
      TAGS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Generate slug: lowercase, spaces to hyphens
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
TODAY=$(date +%Y-%m-%d)
BASE_NAME="tasks/${TODAY}-${SLUG}.md"

# Resolve vault root for file existence check
VAULT_ABS="$(cd "$VAULT_ROOT" && pwd -P)"

# Handle duplicate filenames
REL_PATH="$BASE_NAME"
if [ -f "$VAULT_ABS/$REL_PATH" ]; then
  COUNTER=2
  while [ -f "$VAULT_ABS/tasks/${TODAY}-${SLUG}-${COUNTER}.md" ]; do
    COUNTER=$((COUNTER + 1))
  done
  REL_PATH="tasks/${TODAY}-${SLUG}-${COUNTER}.md"
fi

# Build due line
DUE_LINE="due: "
if [ -n "$DUE" ]; then
  DUE_LINE="due: $DUE"
fi

# Build tags line
TAGS_LINE="tags: []"
if [ -n "$TAGS" ]; then
  TAGS_YAML=$(echo "$TAGS" | sed 's/,/, /g')
  TAGS_LINE="tags: [$TAGS_YAML]"
fi

# Build content with frontmatter
CONTENT="---
type: task
created: ${TODAY}
${DUE_LINE}
done: false
${TAGS_LINE}
source: human
---

# ${TITLE}
"

# Write via human-write (zone enforcement)
OUTPUT=$("$HUMAN_WRITE" "$VAULT_ROOT" "$REL_PATH" "$CONTENT")

# Convert "Written:" to "Created:" for output
echo "Created: $REL_PATH"
