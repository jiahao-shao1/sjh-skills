#!/bin/bash
# Query wikilinks in an Obsidian vault.
# Uses ripgrep to parse [[wikilinks]] from Markdown files.
#
# Usage:
#   ./query-links.sh <vault-root> outgoing <file-path>           # links FROM a file
#   ./query-links.sh <vault-root> backlinks <link-target>         # files linking TO a target
#   ./query-links.sh <vault-root> backlinks <target> --human-only # skip ops/
#
# Output: one link/file per line

set -euo pipefail

VAULT_ROOT="$1"
MODE="$2"
TARGET="$3"
HUMAN_ONLY=false
if [ "${4:-}" = "--human-only" ]; then
  HUMAN_ONLY=true
fi

case "$MODE" in
  outgoing)
    # Extract [[wikilinks]] from a specific file
    FILE="$VAULT_ROOT/$TARGET"
    # Validate file is within vault
    CANONICAL_FILE="$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P)/$(basename "$FILE")" 2>/dev/null || true
    CANONICAL_VAULT="$(cd "$VAULT_ROOT" && pwd -P)"
    if [[ -z "$CANONICAL_FILE" ]] || [[ "$CANONICAL_FILE" != "$CANONICAL_VAULT/"* ]]; then
      echo "ERROR: Path outside vault: $TARGET" >&2
      exit 1
    fi
    if [ ! -f "$FILE" ]; then
      echo "ERROR: File not found: $TARGET" >&2
      exit 1
    fi
    # Extract link targets, one per line, deduplicated
    # Use rg (ripgrep) for PCRE-compatible extraction; fallback to grep -oE
    if command -v rg >/dev/null 2>&1; then
      rg -oP '\[\[\K[^\]|]+' "$FILE" 2>/dev/null | sort -u || true
    else
      grep -oE '\[\[[^]|]+' "$FILE" | sed 's/\[\[//' | sort -u || true
    fi
    ;;

  backlinks)
    # Find all files that contain [[TARGET]]
    # Escape regex metacharacters in target name
    ESCAPED_TARGET=$(printf '%s' "$TARGET" | sed 's/[.[\*^$()+?{}|]/\\&/g')

    # Build search paths as array to handle spaces correctly
    SEARCH_PATHS=()
    if $HUMAN_ONLY; then
      for dir in notes projects tasks resources contexts daily people; do
        if [ -d "$VAULT_ROOT/$dir" ]; then
          SEARCH_PATHS+=("$VAULT_ROOT/$dir")
        fi
      done
    else
      SEARCH_PATHS=("$VAULT_ROOT")
    fi

    if [ ${#SEARCH_PATHS[@]} -eq 0 ]; then
      exit 0
    fi

    if ! command -v rg >/dev/null 2>&1; then
      echo "ERROR: ripgrep (rg) is required for backlink queries" >&2
      exit 1
    fi

    rg -l "\[\[$ESCAPED_TARGET(\|[^\]]*)?]]" "${SEARCH_PATHS[@]}" --glob '*.md' 2>/dev/null \
      | sed "s|^$VAULT_ROOT/||" \
      | sort \
      || true
    ;;

  *)
    echo "Usage: $0 <vault-root> outgoing|backlinks <target> [--human-only]" >&2
    exit 1
    ;;
esac
