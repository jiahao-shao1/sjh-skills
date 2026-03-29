#!/bin/bash
# Zone-enforced write: only allows writing under $VAULT_ROOT/ops/.
# Resolves paths via realpath to prevent traversal and symlink escapes.
#
# Usage: ./safe-write.sh <vault-root> <relative-path> <content>
# Example: ./safe-write.sh ~/second-brain ops/drafts/idea.md "My thought"
#
# Exit codes:
#   0 — success
#   1 — zone violation (path outside ops/)

set -euo pipefail

VAULT_ROOT="$1"
REL_PATH="$2"
CONTENT="$3"

# Resolve vault root to canonical path
VAULT_ROOT="$(cd "$VAULT_ROOT" && pwd -P)"
OPS_ROOT="$VAULT_ROOT/ops"

# Reject obvious traversal/absolute paths before any side effects
if [[ "$REL_PATH" == /* ]] || [[ "$REL_PATH" == *..* ]]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Reason:  absolute or traversal path rejected" >&2
  exit 1
fi

# Build target path and ensure parent directory exists
TARGET="$VAULT_ROOT/$REL_PATH"
TARGET_DIR="$(dirname "$TARGET")"
mkdir -p "$TARGET_DIR"

# Resolve to canonical absolute path (follows symlinks)
CANONICAL="$(cd "$TARGET_DIR" && pwd -P)/$(basename "$TARGET")"

# Zone check: canonical path must be under ops root (trailing slash prevents opsx/ bypass)
if [[ "$CANONICAL" != "$OPS_ROOT/"* ]]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Resolved: $CANONICAL" >&2
  echo "  Allowed:  $OPS_ROOT/*" >&2
  exit 1
fi

# Write content
printf '%s' "$CONTENT" > "$CANONICAL"
echo "Written: $REL_PATH"
