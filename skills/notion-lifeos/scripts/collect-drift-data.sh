#!/bin/bash
# Collect drift analysis data: active projects, git activity, completed tasks.
# Outputs structured text for CC to analyze goals vs actual activity.
#
# Usage:
#   ./collect-drift-data.sh --days 30     # Default 30 days
#   ./collect-drift-data.sh --days 60

set -euo pipefail

DAYS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --days) DAYS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Drift Analysis Data (last $DAYS days)"
echo "======================================"
echo ""

# =============================================================================
# Section 1: Active Projects
# =============================================================================
echo "=== ACTIVE PROJECTS ==="
bash "$SCRIPT_DIR/query-projects.sh" 2>&1 || echo "(failed to query projects)"
echo ""

# =============================================================================
# Section 2: Git Commits
# =============================================================================
echo "=== GIT COMMITS (last $DAYS days) ==="
echo ""

HISTORY_FILE="$HOME/.claude/history.jsonl"
PROJECT_PATHS=()

# Discover repos from CC session history
if [[ -f "$HISTORY_FILE" ]]; then
  while IFS= read -r proj; do
    if [[ -d "$proj/.git" ]]; then
      PROJECT_PATHS+=("$proj")
    fi
  done < <(python3 -c "
import json, sys
seen = set()
with open('$HISTORY_FILE') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            p = e.get('project','')
            if p and p not in seen:
                seen.add(p)
                print(p)
        except: pass
")
fi

# Add hardcoded extra repos
EXTRA_REPOS=(
  "$HOME/dotfiles"
  "$HOME/workspace/agentic_umm/agentic_umm"
)
for repo in "${EXTRA_REPOS[@]}"; do
  if [[ -d "$repo/.git" ]]; then
    PROJECT_PATHS+=("$repo")
  fi
done

# Deduplicate using realpath
UNIQUE_PATHS=()
_seen_file=$(mktemp)
trap "rm -f $_seen_file" EXIT
for p in "${PROJECT_PATHS[@]}"; do
  real_p=$(cd "$p" 2>/dev/null && pwd -P) || continue
  if ! grep -qxF "$real_p" "$_seen_file" 2>/dev/null; then
    echo "$real_p" >> "$_seen_file"
    UNIQUE_PATHS+=("$p")
  fi
done

# Collect commits per repo
for proj in "${UNIQUE_PATHS[@]}"; do
  repo_name=$(basename "$proj")
  EMAIL=$(cd "$proj" && git config user.email 2>/dev/null || true)

  if [[ -z "$EMAIL" ]]; then
    echo "⚠️ No git user.email in $proj, skipping"
    echo ""
    continue
  fi

  commits=$(cd "$proj" && git log --author="$EMAIL" --since="$DAYS days ago" --format="%ai %s" --all 2>/dev/null || true)

  if [[ -z "$commits" ]]; then
    continue
  fi

  commit_count=$(echo "$commits" | wc -l | tr -d ' ')
  echo "[$repo_name] ($commit_count commits)"
  echo "$commits" | while IFS= read -r line; do
    # Extract date (first 10 chars) and message (after the timezone offset)
    date_part="${line:0:10}"
    # Format: "2026-03-28 12:34:56 +0800 commit message"
    # Skip past "YYYY-MM-DD HH:MM:SS +ZZZZ " (25 chars + space)
    msg_part="${line:26}"
    echo "  $date_part $msg_part"
  done
  echo ""
done

# =============================================================================
# Section 3: Completed Tasks
# =============================================================================

# Calculate start date
if [ "$(uname)" = "Darwin" ]; then
  START_DATE=$(date -v-"${DAYS}"d +%Y-%m-%d)
else
  START_DATE=$(date -d "-${DAYS} days" +%Y-%m-%d)
fi

echo "=== COMPLETED TASKS (last $DAYS days) ==="
bash "$SCRIPT_DIR/query-tasks.sh" --done --since "$START_DATE" --by-edited --limit 100 2>&1 || echo "(failed to query tasks)"
echo ""

echo "======================================"
echo "End of drift data collection"
