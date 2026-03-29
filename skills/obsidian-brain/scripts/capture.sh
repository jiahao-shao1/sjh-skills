#!/bin/bash
# Capture user input as a draft note in the AI zone.
# Uses safe-write.sh for zone enforcement.
#
# Usage:
#   ./capture.sh <vault-root> "text to capture"
#   ./capture.sh <vault-root> "text" --tags "tag1,tag2"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAFE_WRITE="$SCRIPT_DIR/safe-write.sh"

VAULT_ROOT="$1"
shift
TEXT="$1"
shift

# Parse optional arguments
TAGS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --tags)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --tags requires a value" >&2
        exit 1
      fi
      TAGS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Generate filename from timestamp + PID to avoid same-second collisions
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
FILENAME="ops/drafts/capture-${TIMESTAMP}-$$.md"

# Build tags line
TAGS_LINE="tags: []"
if [ -n "$TAGS" ]; then
  # Convert comma-separated to YAML array
  TAGS_YAML=$(echo "$TAGS" | sed 's/,/, /g')
  TAGS_LINE="tags: [$TAGS_YAML]"
fi

# Build content with frontmatter
CONTENT="---
type: capture
created: $(date +%Y-%m-%d)
${TAGS_LINE}
source: ai
---

$TEXT
"

# Write via safe-write (zone enforcement)
"$SAFE_WRITE" "$VAULT_ROOT" "$FILENAME" "$CONTENT"
