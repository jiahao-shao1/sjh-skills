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
    if [ -z "$TOPIC" ]; then
      echo "ERROR: --topic is required for challenge mode" >&2
      exit 1
    fi

    # Temp files for collecting entries (bash 3.2 compatible — no associative arrays)
    _ch_index=$(mktemp /tmp/challenge_idx.XXXXXX)
    _ch_para_dir=$(mktemp -d /tmp/challenge_para.XXXXXX)
    _ch_counter=0

    for dir in notes daily projects tasks resources contexts people; do
      local_dir="$VAULT_ROOT/$dir"
      [ -d "$local_dir" ] || continue
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        body=$(extract_body "$f")
        if echo "$body" | grep -qi "$TOPIC"; then
          fm=$(extract_frontmatter "$f")
          created=$(get_field "$fm" "created")
          [ -z "$created" ] && created="unknown"
          filename=$(basename "$f" .md)

          # Extract matching paragraphs (text blocks separated by blank lines)
          matching_paras=$(echo "$body" | awk -v topic="$TOPIC" '
            BEGIN { IGNORECASE=1; para="" }
            /^[[:space:]]*$/ {
              if (para != "" && para ~ topic) print para
              para = ""
              next
            }
            { para = (para == "" ? $0 : para "\n" $0) }
            END { if (para != "" && para ~ topic) print para }
          ')

          if [ -n "$matching_paras" ]; then
            _ch_counter=$((_ch_counter + 1))
            echo "$matching_paras" > "$_ch_para_dir/$_ch_counter"
            printf '%s\t%s\t%s\n' "$created" "$filename" "$_ch_counter" >> "$_ch_index"
          fi
        fi
      done < <(find "$local_dir" -name '*.md' -type f 2>/dev/null)
    done

    if [ ! -s "$_ch_index" ]; then
      echo "## Challenge: $TOPIC"
      echo ""
      echo "No relevant content found for: $TOPIC"
      rm -rf "$_ch_index" "$_ch_para_dir"
      exit 0
    fi

    echo "## Challenge: $TOPIC"
    echo ""

    # Sort entries by date (oldest first) and output
    sort -t$'\t' -k1,1 "$_ch_index" | while IFS=$'\t' read -r c_date c_file c_id; do
      echo "### $c_file ($c_date)"
      while IFS= read -r line; do
        echo "> $line"
      done < "$_ch_para_dir/$c_id"
      echo ""
    done

    rm -rf "$_ch_index" "$_ch_para_dir"
    exit 0
    ;;
  drift)
    DAYS="${DAYS:-60}"

    # Calculate start date (cross-platform)
    if [ "$(uname)" = "Darwin" ]; then
      START_DATE=$(date -v-"${DAYS}"d +%Y-%m-%d)
    else
      START_DATE=$(date -d "-${DAYS} days" +%Y-%m-%d)
    fi
    TODAY=$(date +%Y-%m-%d)

    # Step 1: Find active projects — one title per line in temp file
    projects_dir="$VAULT_ROOT/projects"
    _drift_proj=$(mktemp /tmp/drift_proj.XXXXXX)

    if [ -d "$projects_dir" ]; then
      while IFS= read -r pf; do
        [ -z "$pf" ] && continue
        fm=$(extract_frontmatter "$pf")
        status=$(get_field "$fm" "status")
        if [ "$status" = "active" ]; then
          body=$(extract_body "$pf")
          title=$(echo "$body" | grep -m1 '^# ' | sed 's/^# //')
          if [ -z "$title" ]; then
            title=$(basename "$pf" .md)
          fi
          echo "$title" >> "$_drift_proj"
        fi
      done < <(find "$projects_dir" -name '*.md' -type f 2>/dev/null)
    fi

    if [ ! -s "$_drift_proj" ]; then
      echo "No active projects found."
      rm -f "$_drift_proj"
      exit 0
    fi

    echo "## Drift Analysis (last $DAYS days)"
    echo ""
    echo "| Project | Mentions | Last Mentioned |"
    echo "|---------|----------|----------------|"

    # Step 2: For each project, count mentions in daily/ within date range
    daily_dir="$VAULT_ROOT/daily"
    _drift_results=$(mktemp /tmp/drift_results.XXXXXX)

    while IFS= read -r proj; do
      [ -z "$proj" ] && continue
      total=0
      last="never"

      if [ -d "$daily_dir" ]; then
        while IFS= read -r df; do
          [ -z "$df" ] && continue
          fm=$(extract_frontmatter "$df")
          created=$(get_field "$fm" "created")
          [ -z "$created" ] && continue
          if [[ "$created" < "$START_DATE" ]] || [[ "$created" > "$TODAY" ]]; then
            continue
          fi
          body=$(extract_body "$df")
          # Count occurrences of project title (case-insensitive, includes wikilinks)
          count=$(echo "$body" | { grep -oi "$proj" 2>/dev/null || true; } | wc -l | tr -d ' ')
          if [ "$count" -gt 0 ]; then
            total=$((total + count))
            if [ "$last" = "never" ] || [[ "$created" > "$last" ]]; then
              last="$created"
            fi
          fi
        done < <(find "$daily_dir" -name '*.md' -type f 2>/dev/null)
      fi

      printf '%s\t%s\t%s\n' "$total" "$proj" "$last" >> "$_drift_results"
    done < "$_drift_proj"

    # Sort by mentions descending
    sort -t$'\t' -k1,1 -rn "$_drift_results" | while IFS=$'\t' read -r cnt name last_date; do
      echo "| $name | $cnt | $last_date |"
    done

    rm -f "$_drift_proj" "$_drift_results"
    exit 0
    ;;
  emerge)
    # Default to 30 days if not specified
    DAYS="${DAYS:-30}"

    # Calculate start date (platform-aware)
    if [ "$(uname)" = "Darwin" ]; then
      START_DATE=$(date -v-"${DAYS}"d +%Y-%m-%d)
    else
      START_DATE=$(date -d "-${DAYS} days" +%Y-%m-%d)
    fi
    END_DATE=$(date +%Y-%m-%d)

    # Step 1: Scan notes/ + daily/ for files within date range
    FILES=$(find_by_date_range "$VAULT_ROOT" "$START_DATE" "$END_DATE" notes daily)

    if [ -z "$FILES" ]; then
      echo "No content found in the last ${DAYS} days."
      exit 0
    fi

    # Step 2: Extract all [[wikilinks]] and count frequency
    declare -A LINK_COUNT=()
    while IFS= read -r rel_path; do
      [ -z "$rel_path" ] && continue
      local_file="$VAULT_ROOT/$rel_path"
      # Extract wikilinks
      local links=""
      if command -v rg >/dev/null 2>&1; then
        links=$(rg -oP '\[\[\K[^\]|]+' "$local_file" 2>/dev/null || true)
      else
        links=$(grep -oE '\[\[[^]|]+' "$local_file" | sed 's/\[\[//' || true)
      fi
      while IFS= read -r link; do
        [ -z "$link" ] && continue
        LINK_COUNT["$link"]=$(( ${LINK_COUNT["$link"]:-0} + 1 ))
      done <<< "$links"
    done <<< "$FILES"

    # Output header
    echo "## Emerge Analysis (last ${DAYS} days)"
    echo ""

    if [ ${#LINK_COUNT[@]} -eq 0 ]; then
      echo "No wikilinks found in scanned files."
      exit 0
    fi

    # Step 3: Identify ghost links (no corresponding .md file in vault)
    declare -A GHOST_LINKS=()
    for target in "${!LINK_COUNT[@]}"; do
      found=$(find "$VAULT_ROOT" -name "${target}.md" -type f 2>/dev/null | head -1)
      if [ -z "$found" ]; then
        GHOST_LINKS["$target"]="${LINK_COUNT[$target]}"
      fi
    done

    # Ghost links sorted by frequency descending
    echo "### Ghost Links (mentioned but no file exists)"
    if [ ${#GHOST_LINKS[@]} -eq 0 ]; then
      echo "None found."
    else
      for target in "${!GHOST_LINKS[@]}"; do
        echo "${GHOST_LINKS[$target]} [[${target}]]"
      done | sort -rn | while IFS= read -r line; do
        count="${line%% *}"
        rest="${line#* }"
        echo "- ${rest} (${count} mentions)"
      done
    fi
    echo ""

    # Frequent links: top 10 most-referenced, sorted by frequency
    echo "### Frequent Links (most connected ideas)"
    for target in "${!LINK_COUNT[@]}"; do
      echo "${LINK_COUNT[$target]} [[${target}]]"
    done | sort -rn | head -10 | while IFS= read -r line; do
      count="${line%% *}"
      rest="${line#* }"
      echo "- ${rest} (${count} mentions)"
    done

    exit 0
    ;;
  connect)
    # Validate --topics argument
    if [ -z "$TOPICS" ]; then
      echo "ERROR: --topics is required for connect mode (e.g. --topics \"topic-a,topic-b\")" >&2
      exit 1
    fi

    # Parse topics — must be exactly 2 comma-separated
    TOPIC_A="${TOPICS%%,*}"
    TOPIC_B="${TOPICS#*,}"

    # Validate: must have exactly 2 topics (no second comma, and they must differ from raw)
    if [ -z "$TOPIC_A" ] || [ -z "$TOPIC_B" ] || [ "$TOPIC_A" = "$TOPICS" ]; then
      echo "ERROR: --topics must contain exactly 2 comma-separated topics (e.g. \"topic-a,topic-b\")" >&2
      exit 1
    fi
    # Check no third topic (extra comma)
    remainder="${TOPICS#*,}"
    if echo "$remainder" | grep -q ','; then
      echo "ERROR: --topics must contain exactly 2 comma-separated topics (e.g. \"topic-a,topic-b\")" >&2
      exit 1
    fi

    # Step 1 & 2: Find files related to each topic
    # Search by keyword in body + wikilink matching across all human dirs
    declare -A FILES_A=()
    declare -A FILES_B=()

    for dir in "${HUMAN_DIRS[@]}"; do
      local_dir="$VAULT_ROOT/$dir"
      [ -d "$local_dir" ] || continue
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        body=$(extract_body "$f")
        relpath="${f#$VAULT_ROOT/}"

        # Check topic A: keyword in body or wikilink
        if echo "$body" | grep -qi "$TOPIC_A" || echo "$body" | grep -q "\[\[$TOPIC_A\]\]"; then
          FILES_A["$relpath"]=1
        fi

        # Check topic B: keyword in body or wikilink
        if echo "$body" | grep -qi "$TOPIC_B" || echo "$body" | grep -q "\[\[$TOPIC_B\]\]"; then
          FILES_B["$relpath"]=1
        fi
      done < <(find "$local_dir" -name '*.md' -type f 2>/dev/null)
    done

    echo "## Connect: ${TOPIC_A} ↔ ${TOPIC_B}"
    echo ""

    # Files mentioning topic A
    echo "### Files mentioning \"${TOPIC_A}\" (${#FILES_A[@]} files)"
    if [ ${#FILES_A[@]} -eq 0 ]; then
      echo "No content found for: ${TOPIC_A}"
    else
      for f in $(echo "${!FILES_A[@]}" | tr ' ' '\n' | sort); do
        echo "- $f"
      done
    fi
    echo ""

    # Files mentioning topic B
    echo "### Files mentioning \"${TOPIC_B}\" (${#FILES_B[@]} files)"
    if [ ${#FILES_B[@]} -eq 0 ]; then
      echo "No content found for: ${TOPIC_B}"
    else
      for f in $(echo "${!FILES_B[@]}" | tr ' ' '\n' | sort); do
        echo "- $f"
      done
    fi
    echo ""

    # Step 3: Find bridge files (intersection)
    echo "### Bridge Files (mention both)"
    bridge_found=0
    declare -A BRIDGE_FILES=()
    for f in "${!FILES_A[@]}"; do
      if [ -n "${FILES_B[$f]:-}" ]; then
        BRIDGE_FILES["$f"]=1
        bridge_found=1
      fi
    done
    if [ "$bridge_found" -eq 0 ]; then
      echo "No bridge files found between these topics."
    else
      for f in $(echo "${!BRIDGE_FILES[@]}" | tr ' ' '\n' | sort); do
        echo "- $f"
      done
    fi
    echo ""

    # Step 4: Extract shared [[wikilinks]] from both file sets
    echo "### Shared Links"
    declare -A LINKS_A=()
    declare -A LINKS_B=()

    for f in "${!FILES_A[@]}"; do
      local_file="$VAULT_ROOT/$f"
      local links=""
      if command -v rg >/dev/null 2>&1; then
        links=$(rg -oP '\[\[\K[^\]|]+' "$local_file" 2>/dev/null || true)
      else
        links=$(grep -oE '\[\[[^]|]+' "$local_file" | sed 's/\[\[//' || true)
      fi
      while IFS= read -r link; do
        [ -z "$link" ] && continue
        LINKS_A["$link"]=1
      done <<< "$links"
    done

    for f in "${!FILES_B[@]}"; do
      local_file="$VAULT_ROOT/$f"
      local links=""
      if command -v rg >/dev/null 2>&1; then
        links=$(rg -oP '\[\[\K[^\]|]+' "$local_file" 2>/dev/null || true)
      else
        links=$(grep -oE '\[\[[^]|]+' "$local_file" | sed 's/\[\[//' || true)
      fi
      while IFS= read -r link; do
        [ -z "$link" ] && continue
        LINKS_B["$link"]=1
      done <<< "$links"
    done

    shared_found=0
    for link in "${!LINKS_A[@]}"; do
      if [ -n "${LINKS_B[$link]:-}" ]; then
        echo "- [[$link]]"
        shared_found=1
      fi
    done | sort

    if [ "$shared_found" -eq 0 ]; then
      echo "None found."
    fi

    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Valid modes: challenge, drift, emerge, connect" >&2
    exit 1
    ;;
esac
