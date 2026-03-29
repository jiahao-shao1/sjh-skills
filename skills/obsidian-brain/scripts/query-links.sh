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
    if [ ! -f "$FILE" ]; then
      echo "ERROR: File not found: $TARGET" >&2
      exit 1
    fi
    # Extract link targets, one per line, deduplicated
    # Use rg (ripgrep) for PCRE-compatible extraction; fallback to grep -oE
    if command -v rg >/dev/null 2>&1; then
      rg -oP '\[\[\K[^\]|]+' "$FILE" 2>/dev/null | sort -u
    else
      grep -oE '\[\[[^]|]+' "$FILE" | sed 's/\[\[//' | sort -u
    fi
    ;;

  backlinks)
    # Find all files that contain [[TARGET]]
    SEARCH_PATH="$VAULT_ROOT"
    if $HUMAN_ONLY; then
      # Search only human zone directories
      SEARCH_PATH=""
      for dir in notes projects tasks resources contexts daily people; do
        if [ -d "$VAULT_ROOT/$dir" ]; then
          SEARCH_PATH="$SEARCH_PATH $VAULT_ROOT/$dir"
        fi
      done
    fi

    if [ -z "$SEARCH_PATH" ]; then
      exit 0
    fi

    # shellcheck disable=SC2086
    rg -l "\[\[$TARGET(\|[^\]]*)?]]" $SEARCH_PATH --glob '*.md' 2>/dev/null \
      | sed "s|^$VAULT_ROOT/||" \
      | sort
    ;;

  *)
    echo "Usage: $0 <vault-root> outgoing|backlinks <target> [--human-only]" >&2
    exit 1
    ;;
esac
