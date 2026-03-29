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

    # Temp file for raw wikilinks (one per line, may have duplicates)
    _emerge_links=$(mktemp /tmp/emerge_links.XXXXXX)

    # Step 2: Extract all [[wikilinks]] from scanned files
    while IFS= read -r rel_path; do
      [ -z "$rel_path" ] && continue
      local_file="$VAULT_ROOT/$rel_path"
      if command -v rg >/dev/null 2>&1; then
        rg -oP '\[\[\K[^\]|]+' "$local_file" 2>/dev/null >> "$_emerge_links" || true
      else
        grep -oE '\[\[[^]|]+' "$local_file" 2>/dev/null | sed 's/\[\[//' >> "$_emerge_links" || true
      fi
    done <<< "$FILES"

    # Output header
    echo "## Emerge Analysis (last ${DAYS} days)"
    echo ""

    # Count frequency: "count target" lines, sorted descending
    _emerge_counted=$(mktemp /tmp/emerge_counted.XXXXXX)
    if [ -s "$_emerge_links" ]; then
      sort "$_emerge_links" | uniq -c | sort -rn | sed 's/^ *//' > "$_emerge_counted"
    fi

    if [ ! -s "$_emerge_counted" ]; then
      echo "No wikilinks found in scanned files."
      rm -f "$_emerge_links" "$_emerge_counted"
      exit 0
    fi

    # Step 3: Ghost links — targets with no .md file in vault
    _emerge_ghosts=$(mktemp /tmp/emerge_ghosts.XXXXXX)
    while IFS= read -r line; do
      count="${line%% *}"
      target="${line#* }"
      found_file=$(find "$VAULT_ROOT" -name "${target}.md" -type f 2>/dev/null | head -1)
      if [ -z "$found_file" ]; then
        echo "$line" >> "$_emerge_ghosts"
      fi
    done < "$_emerge_counted"

    echo "### Ghost Links (mentioned but no file exists)"
    if [ ! -s "$_emerge_ghosts" ]; then
      echo "None found."
    else
      while IFS= read -r line; do
        count="${line%% *}"
        target="${line#* }"
        echo "- [[${target}]] (${count} mentions)"
      done < "$_emerge_ghosts"
    fi
    echo ""

    # Frequent links: top 10 most-referenced
    echo "### Frequent Links (most connected ideas)"
    head -10 "$_emerge_counted" | while IFS= read -r line; do
      count="${line%% *}"
      target="${line#* }"
      echo "- [[${target}]] (${count} mentions)"
    done

    rm -f "$_emerge_links" "$_emerge_counted" "$_emerge_ghosts"
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

    # Validate: must have exactly 2 topics
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

    # Temp files for file lists (bash 3.2 compatible — no associative arrays)
    _conn_files_a=$(mktemp /tmp/conn_files_a.XXXXXX)
    _conn_files_b=$(mktemp /tmp/conn_files_b.XXXXXX)

    # Step 1 & 2: Find files related to each topic
    for dir in "${HUMAN_DIRS[@]}"; do
      local_dir="$VAULT_ROOT/$dir"
      [ -d "$local_dir" ] || continue
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        body=$(extract_body "$f")
        relpath="${f#$VAULT_ROOT/}"

        if echo "$body" | grep -qi "$TOPIC_A"; then
          echo "$relpath" >> "$_conn_files_a"
        fi
        if echo "$body" | grep -qi "$TOPIC_B"; then
          echo "$relpath" >> "$_conn_files_b"
        fi
      done < <(find "$local_dir" -name '*.md' -type f 2>/dev/null)
    done

    # Deduplicate and sort
    _conn_a_sorted=$(mktemp /tmp/conn_a_sorted.XXXXXX)
    _conn_b_sorted=$(mktemp /tmp/conn_b_sorted.XXXXXX)
    sort -u "$_conn_files_a" > "$_conn_a_sorted" 2>/dev/null || true
    sort -u "$_conn_files_b" > "$_conn_b_sorted" 2>/dev/null || true

    # Handle empty files: wc -l on empty file may return "0" with whitespace
    count_a=0
    count_b=0
    [ -s "$_conn_a_sorted" ] && count_a=$(wc -l < "$_conn_a_sorted" | tr -d ' ')
    [ -s "$_conn_b_sorted" ] && count_b=$(wc -l < "$_conn_b_sorted" | tr -d ' ')

    echo "## Connect: ${TOPIC_A} ↔ ${TOPIC_B}"
    echo ""

    # Files mentioning topic A
    echo "### Files mentioning \"${TOPIC_A}\" (${count_a} files)"
    if [ "$count_a" -eq 0 ]; then
      echo "No content found for: ${TOPIC_A}"
    else
      while IFS= read -r f; do
        echo "- $f"
      done < "$_conn_a_sorted"
    fi
    echo ""

    # Files mentioning topic B
    echo "### Files mentioning \"${TOPIC_B}\" (${count_b} files)"
    if [ "$count_b" -eq 0 ]; then
      echo "No content found for: ${TOPIC_B}"
    else
      while IFS= read -r f; do
        echo "- $f"
      done < "$_conn_b_sorted"
    fi
    echo ""

    # Step 3: Bridge files (intersection)
    echo "### Bridge Files (mention both)"
    _conn_bridges=$(mktemp /tmp/conn_bridges.XXXXXX)
    comm -12 "$_conn_a_sorted" "$_conn_b_sorted" > "$_conn_bridges" 2>/dev/null || true
    if [ ! -s "$_conn_bridges" ]; then
      echo "No bridge files found between these topics."
    else
      while IFS= read -r f; do
        echo "- $f"
      done < "$_conn_bridges"
    fi
    echo ""

    # Step 4: Shared [[wikilinks]] from both file sets
    echo "### Shared Links"
    _conn_links_a=$(mktemp /tmp/conn_links_a.XXXXXX)
    _conn_links_b=$(mktemp /tmp/conn_links_b.XXXXXX)

    while IFS= read -r f; do
      [ -z "$f" ] && continue
      local_file="$VAULT_ROOT/$f"
      if command -v rg >/dev/null 2>&1; then
        rg -oP '\[\[\K[^\]|]+' "$local_file" 2>/dev/null >> "$_conn_links_a" || true
      else
        grep -oE '\[\[[^]|]+' "$local_file" 2>/dev/null | sed 's/\[\[//' >> "$_conn_links_a" || true
      fi
    done < "$_conn_a_sorted"

    while IFS= read -r f; do
      [ -z "$f" ] && continue
      local_file="$VAULT_ROOT/$f"
      if command -v rg >/dev/null 2>&1; then
        rg -oP '\[\[\K[^\]|]+' "$local_file" 2>/dev/null >> "$_conn_links_b" || true
      else
        grep -oE '\[\[[^]|]+' "$local_file" 2>/dev/null | sed 's/\[\[//' >> "$_conn_links_b" || true
      fi
    done < "$_conn_b_sorted"

    # Find shared links via sorted intersection
    _conn_la_s=$(mktemp /tmp/conn_la_s.XXXXXX)
    _conn_lb_s=$(mktemp /tmp/conn_lb_s.XXXXXX)
    _conn_shared=$(mktemp /tmp/conn_shared.XXXXXX)
    sort -u "$_conn_links_a" > "$_conn_la_s" 2>/dev/null || true
    sort -u "$_conn_links_b" > "$_conn_lb_s" 2>/dev/null || true
    comm -12 "$_conn_la_s" "$_conn_lb_s" > "$_conn_shared" 2>/dev/null || true

    if [ ! -s "$_conn_shared" ]; then
      echo "None found."
    else
      while IFS= read -r link; do
        echo "- [[$link]]"
      done < "$_conn_shared"
    fi

    rm -f "$_conn_files_a" "$_conn_files_b" "$_conn_a_sorted" "$_conn_b_sorted" \
          "$_conn_bridges" "$_conn_links_a" "$_conn_links_b" \
          "$_conn_la_s" "$_conn_lb_s" "$_conn_shared"
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Valid modes: challenge, drift, emerge, connect" >&2
    exit 1
    ;;
esac
