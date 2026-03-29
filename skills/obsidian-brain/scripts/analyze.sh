#!/bin/bash
# Analyze human zone of an Obsidian vault — Phase 2 reflection data gatherer.
# Outputs structured data for Claude Code conversation analysis.
#
# Usage:
#   ./analyze.sh <vault-root> --mode challenge|drift|emerge|connect [--topic TOPIC] [--days N] [--topics "a,b"]
#
# Utility functions (scan, extract, find) are defined here and can be
# exercised individually via --test-utils mode.

set -euo pipefail

# ---------------------------------------------------------------------------
# Human zone directories (shared constant)
# ---------------------------------------------------------------------------
HUMAN_DIRS=(notes projects tasks resources contexts daily people)

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

scan_human_zone() {
  # Returns relative paths of all .md files inside human zone directories.
  local vault_root="$1"
  for dir in "${HUMAN_DIRS[@]}"; do
    local full="$vault_root/$dir"
    if [ -d "$full" ]; then
      find "$full" -name '*.md' -type f 2>/dev/null | while IFS= read -r f; do
        echo "${f#$vault_root/}"
      done
    fi
  done | sort
}

extract_frontmatter() {
  # Outputs YAML between the first pair of --- delimiters (without the delimiters).
  local file="$1"
  awk 'NR==1 && /^---$/ { found=1; next }
       found && /^---$/ { exit }
       found { print }' "$file" 2>/dev/null || true
}

extract_body() {
  # Returns everything after the closing --- of frontmatter, trimming leading blanks.
  local file="$1"
  # Find the line number of the second ---
  local end_line
  end_line=$(awk 'NR==1 && /^---$/ { count=1; next } /^---$/ && count==1 { print NR; exit }' "$file" 2>/dev/null)
  if [ -z "$end_line" ]; then
    # No frontmatter — return whole file
    cat "$file"
    return
  fi
  tail -n +"$((end_line + 1))" "$file" | sed '/./,$!d'
}

get_field() {
  # Extracts a field value from raw YAML frontmatter text.
  # Usage: get_field "$frontmatter_text" "field_name"
  local fm="$1"
  local field="$2"
  echo "$fm" | sed -n "s/^${field}: *//p" | sed 's/^ *//; s/ *$//'
}

find_by_date_range() {
  # Finds files whose created: date falls within [start, end].
  # Usage: find_by_date_range <vault_root> <start_date> <end_date> [dir1 dir2 ...]
  local vault_root="$1"; shift
  local start_date="$1"; shift
  local end_date="$1"; shift

  local dirs=("$@")
  if [ ${#dirs[@]} -eq 0 ]; then
    dirs=("${HUMAN_DIRS[@]}")
  fi

  for dir in "${dirs[@]}"; do
    local full="$vault_root/$dir"
    [ -d "$full" ] || continue
    find "$full" -name '*.md' -type f 2>/dev/null | while IFS= read -r f; do
      local fm
      fm=$(extract_frontmatter "$f")
      local created
      created=$(get_field "$fm" "created")
      if [ -n "$created" ] && [[ ! "$created" < "$start_date" ]] && [[ ! "$created" > "$end_date" ]]; then
        echo "${f#$vault_root/}"
      fi
    done
  done | sort
}

find_by_keyword() {
  # Searches file bodies for keyword (case-insensitive).
  # Usage: find_by_keyword <vault_root> <keyword> [dir1 dir2 ...]
  local vault_root="$1"; shift
  local keyword="$1"; shift

  local dirs=("$@")
  if [ ${#dirs[@]} -eq 0 ]; then
    dirs=("${HUMAN_DIRS[@]}")
  fi

  local search_paths=()
  for dir in "${dirs[@]}"; do
    [ -d "$vault_root/$dir" ] && search_paths+=("$vault_root/$dir")
  done
  [ ${#search_paths[@]} -eq 0 ] && return 0

  if command -v rg >/dev/null 2>&1; then
    rg -il --glob '*.md' "$keyword" "${search_paths[@]}" 2>/dev/null \
      | while IFS= read -r f; do
          # Re-grep for line numbers
          rg -in "$keyword" "$f" 2>/dev/null | while IFS= read -r line; do
            echo "${f#$vault_root/}:$line"
          done
        done | sort
  else
    grep -rnil "$keyword" "${search_paths[@]}" --include='*.md' 2>/dev/null \
      | sed "s|^$vault_root/||" \
      | sort || true
  fi
}

# ---------------------------------------------------------------------------
# Main — argument parsing & mode dispatch
# ---------------------------------------------------------------------------

# Allow sourcing this script to access utility functions without running main.
# Set ANALYZE_SOURCED=1 before sourcing to skip argument parsing.
if [ "${ANALYZE_SOURCED:-0}" = "1" ]; then
  return 0 2>/dev/null || true
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 <vault-root> --mode challenge|drift|emerge|connect [--topic TOPIC] [--days N] [--topics \"a,b\"]" >&2
  exit 1
fi

VAULT_ROOT="$1"; shift

MODE=""
TOPIC=""
DAYS=""
TOPICS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)   MODE="$2"; shift 2 ;;
    --topic)  TOPIC="$2"; shift 2 ;;
    --days)   DAYS="$2"; shift 2 ;;
    --topics) TOPICS="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; shift ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "ERROR: --mode is required" >&2
  exit 1
fi

case "$MODE" in
  challenge)
    echo "Mode not yet implemented: challenge"
    exit 0
    ;;
  drift)
    echo "Mode not yet implemented: drift"
    exit 0
    ;;
  emerge)
    echo "Mode not yet implemented: emerge"
    exit 0
    ;;
  connect)
    echo "Mode not yet implemented: connect"
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Valid modes: challenge, drift, emerge, connect" >&2
    exit 1
    ;;
esac
