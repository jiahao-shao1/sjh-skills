#!/bin/bash
# Create a note file in the vault using human-write.sh for zone enforcement.
#
# Usage:
#   ./create-note.sh <vault-root> "Note title" "Content text"
#   ./create-note.sh <vault-root> "Note title" "Content text" --tags "a,b" --links "concept1,concept2"
#
# Generates: notes/slugified-title.md
# If file exists, appends -2, -3, etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HUMAN_WRITE="$SCRIPT_DIR/human-write.sh"

VAULT_ROOT="$1"
shift
TITLE="$1"
shift
BODY_CONTENT="$1"
shift

# Parse optional arguments
TAGS=""
LINKS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --tags)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --tags requires a value" >&2
        exit 1
      fi
      TAGS="$2"; shift 2 ;;
    --links)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --links requires a value" >&2
        exit 1
      fi
      LINKS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Generate slug: lowercase, spaces to hyphens
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
TODAY=$(date +%Y-%m-%d)
BASE_NAME="notes/${SLUG}.md"

# Resolve vault root for file existence check
VAULT_ABS="$(cd "$VAULT_ROOT" && pwd -P)"

# Handle duplicate filenames
REL_PATH="$BASE_NAME"
if [ -f "$VAULT_ABS/$REL_PATH" ]; then
  COUNTER=2
  while [ -f "$VAULT_ABS/notes/${SLUG}-${COUNTER}.md" ]; do
    COUNTER=$((COUNTER + 1))
  done
  REL_PATH="notes/${SLUG}-${COUNTER}.md"
fi

# Build tags line
TAGS_LINE="tags: []"
if [ -n "$TAGS" ]; then
  TAGS_YAML=$(echo "$TAGS" | sed 's/,/, /g')
  TAGS_LINE="tags: [$TAGS_YAML]"
fi

# Build body with optional wikilinks
BODY="# ${TITLE}

${BODY_CONTENT}"

if [ -n "$LINKS" ]; then
  WIKILINKS=""
  IFS=',' read -ra LINK_ARRAY <<< "$LINKS"
  for link in "${LINK_ARRAY[@]}"; do
    WIKILINKS="${WIKILINKS} [[${link}]]"
  done
  BODY="${BODY}

Related:${WIKILINKS}"
fi

# Build content with frontmatter
CONTENT="---
type: note
created: ${TODAY}
${TAGS_LINE}
source: human
---

${BODY}
"

# Write via human-write (zone enforcement)
OUTPUT=$("$HUMAN_WRITE" "$VAULT_ROOT" "$REL_PATH" "$CONTENT")

# Output result
echo "Created: $REL_PATH"
