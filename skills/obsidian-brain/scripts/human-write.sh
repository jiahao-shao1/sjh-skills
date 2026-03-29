#!/bin/bash
# Zone-enforced write: only allows writing under $VAULT_ROOT/tasks/ or $VAULT_ROOT/notes/.
# Validates that content contains "source: human" in YAML frontmatter.
# Resolves paths via realpath to prevent traversal and symlink escapes.
#
# Usage: ./human-write.sh <vault-root> <relative-path> <content>
# Example: ./human-write.sh ~/second-brain tasks/2026-03-29-my-task.md "---\nsource: human\n---"
#
# Exit codes:
#   0 — success
#   1 — zone violation (path outside tasks/ or notes/, or missing source: human)

set -euo pipefail

VAULT_ROOT="$1"
REL_PATH="$2"
CONTENT="$3"

# Resolve vault root to canonical path
VAULT_ROOT="$(cd "$VAULT_ROOT" && pwd -P)"
TASKS_ROOT="$VAULT_ROOT/tasks"
NOTES_ROOT="$VAULT_ROOT/notes"

# Reject obvious traversal/absolute paths before any side effects
if [[ "$REL_PATH" == /* ]] || [[ "$REL_PATH" == *..* ]]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Reason:  absolute or traversal path rejected" >&2
  exit 1
fi

# Pre-check: rel path must start with tasks/ or notes/ (fast reject before any filesystem ops)
if [[ "$REL_PATH" != tasks/* ]] && [[ "$REL_PATH" != notes/* ]]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Allowed:  tasks/*, notes/*" >&2
  exit 1
fi

# Validate content contains source: human in YAML frontmatter
# Extract frontmatter (between first --- and second ---) and check for source: human
FRONTMATTER=$(echo "$CONTENT" | sed -n '/^---$/,/^---$/p')
if ! echo "$FRONTMATTER" | grep -q '^source: human$'; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Reason:  content must contain 'source: human' in YAML frontmatter" >&2
  exit 1
fi

# Build target path and ensure parent directory exists (safe: already validated prefix)
TARGET="$VAULT_ROOT/$REL_PATH"
TARGET_DIR="$(dirname "$TARGET")"
mkdir -p "$TARGET_DIR"

# Resolve to canonical absolute path (follows symlinks — catches symlink escapes)
CANONICAL="$(cd "$TARGET_DIR" && pwd -P)/$(basename "$TARGET")"

# Zone check: canonical path must be under tasks root or notes root
if [[ "$CANONICAL" != "$TASKS_ROOT/"* ]] && [[ "$CANONICAL" != "$NOTES_ROOT/"* ]]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Resolved: $CANONICAL" >&2
  echo "  Allowed:  $TASKS_ROOT/*, $NOTES_ROOT/*" >&2
  exit 1
fi

# Final check: reject if target file is an existing symlink (could point outside zone)
if [ -L "$CANONICAL" ]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Reason:  target is a symlink" >&2
  exit 1
fi

# Write content
printf '%s' "$CONTENT" > "$CANONICAL"
echo "Written: $REL_PATH"
