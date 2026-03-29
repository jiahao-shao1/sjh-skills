#!/bin/bash
# Query task files from an Obsidian vault's tasks/ directory.
# Parses YAML frontmatter and filters by date, done status, tag, and project.
#
# Usage:
#   ./query-tasks.sh <vault-root> [--date DATE|today|this-week] [--undone] [--tag TAG] [--project PROJECT]
#
# Output: Markdown table sorted by due date (earliest first, nulls last).

set -euo pipefail

VAULT_ROOT="$1"; shift

# Parse optional arguments
FILTER_DATE=""
FILTER_UNDONE=false
FILTER_TAG=""
FILTER_PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --date)    FILTER_DATE="$2"; shift 2 ;;
    --undone)  FILTER_UNDONE=true; shift ;;
    --tag)     FILTER_TAG="$2"; shift 2 ;;
    --project) FILTER_PROJECT="$2"; shift 2 ;;
    *)         echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TASKS_DIR="$VAULT_ROOT/tasks"
if [ ! -d "$TASKS_DIR" ]; then
  echo "No tasks found."
  exit 0
fi

# Resolve date filters
resolve_today() {
  date +%Y-%m-%d
}

resolve_week_range() {
  # Returns Monday and Sunday of current week
  local dow
  # macOS date: %u = day of week (1=Monday, 7=Sunday)
  dow=$(date +%u)
  local days_since_monday=$(( dow - 1 ))
  local days_until_sunday=$(( 7 - dow ))

  if [ "$(uname)" = "Darwin" ]; then
    WEEK_START=$(date -v-"${days_since_monday}"d +%Y-%m-%d)
    WEEK_END=$(date -v+"${days_until_sunday}"d +%Y-%m-%d)
  else
    WEEK_START=$(date -d "-${days_since_monday} days" +%Y-%m-%d)
    WEEK_END=$(date -d "+${days_until_sunday} days" +%Y-%m-%d)
  fi
}

# Parse a single task file and output a tab-separated record
# Format: due\tdone\ttags\ttitle\thas_project
parse_task() {
  local file="$1"
  local in_frontmatter=false
  local past_frontmatter=false
  local due="" done_val="" tags="" title=""
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if [ "$line_num" -eq 1 ] && [ "$line" = "---" ]; then
      in_frontmatter=true
      continue
    fi

    if $in_frontmatter; then
      if [ "$line" = "---" ]; then
        in_frontmatter=false
        past_frontmatter=true
        continue
      fi
      # Parse frontmatter fields
      case "$line" in
        due:*)
          due=$(echo "$line" | sed 's/^due:[[:space:]]*//')
          ;;
        done:*)
          done_val=$(echo "$line" | sed 's/^done:[[:space:]]*//')
          ;;
        tags:*)
          tags=$(echo "$line" | sed 's/^tags:[[:space:]]*//')
          # Normalize [tag1, tag2] -> tag1, tag2
          tags=$(echo "$tags" | sed 's/^\[//; s/\]$//; s/,[[:space:]]*/,/g')
          ;;
      esac
      continue
    fi

    if $past_frontmatter; then
      # Look for first # heading
      if echo "$line" | grep -q '^# '; then
        title=$(echo "$line" | sed 's/^# //')
        break
      fi
    fi
  done < "$file"

  # Check project filter (search entire file for [[PROJECT]] wikilink)
  local has_project="yes"
  if [ -n "$FILTER_PROJECT" ]; then
    if ! grep -q "\[\[$FILTER_PROJECT\]\]" "$file" 2>/dev/null; then
      has_project="no"
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$due" "$done_val" "$tags" "$title" "$has_project"
}

# Date comparison helper: is date within range?
date_in_range() {
  local d="$1" start="$2" end="$3"
  if [ -z "$d" ]; then return 1; fi
  if [[ "$d" < "$start" ]]; then return 1; fi
  if [[ "$d" > "$end" ]]; then return 1; fi
  return 0
}

# Collect matching tasks
RESULTS=()

for file in "$TASKS_DIR"/*.md; do
  [ -f "$file" ] || continue

  record=$(parse_task "$file")
  due=$(echo "$record" | cut -f1)
  done_val=$(echo "$record" | cut -f2)
  tags=$(echo "$record" | cut -f3)
  title=$(echo "$record" | cut -f4)
  has_project=$(echo "$record" | cut -f5)

  # Apply filters (AND logic)

  # --undone filter
  if $FILTER_UNDONE && [ "$done_val" != "false" ]; then
    continue
  fi

  # --date filter
  if [ -n "$FILTER_DATE" ]; then
    case "$FILTER_DATE" in
      today)
        target_date=$(resolve_today)
        if [ "$due" != "$target_date" ]; then
          continue
        fi
        ;;
      this-week)
        resolve_week_range
        if ! date_in_range "$due" "$WEEK_START" "$WEEK_END"; then
          continue
        fi
        ;;
      *)
        # Specific YYYY-MM-DD
        if [ "$due" != "$FILTER_DATE" ]; then
          continue
        fi
        ;;
    esac
  fi

  # --tag filter
  if [ -n "$FILTER_TAG" ]; then
    if ! echo ",$tags," | grep -q ",$FILTER_TAG,"; then
      continue
    fi
  fi

  # --project filter
  if [ "$has_project" = "no" ]; then
    continue
  fi

  # Build status icon
  local_status="⬜"
  if [ "$done_val" = "true" ]; then
    local_status="✅"
  fi

  # Format tags for display
  display_tags=""
  if [ -n "$tags" ]; then
    display_tags=$(echo "$tags" | sed 's/,/, /g')
  fi

  # Sort key: due date, with empty dates sorted last
  sort_key="$due"
  if [ -z "$sort_key" ]; then
    sort_key="9999-99-99"
  fi

  RESULTS+=("${sort_key}|${local_status}|${title}|${due}|${display_tags}")
done

if [ ${#RESULTS[@]} -eq 0 ]; then
  echo "No tasks found."
  exit 0
fi

# Sort by due date
IFS=$'\n' SORTED=($(printf '%s\n' "${RESULTS[@]}" | sort -t'|' -k1,1))
unset IFS

# Output markdown table
echo "| Status | Title | Due | Tags |"
echo "|--------|-------|-----|------|"
for row in "${SORTED[@]}"; do
  status=$(echo "$row" | cut -d'|' -f2)
  title=$(echo "$row" | cut -d'|' -f3)
  due=$(echo "$row" | cut -d'|' -f4)
  tags=$(echo "$row" | cut -d'|' -f5)
  echo "| $status | $title | $due | $tags |"
done

exit 0
