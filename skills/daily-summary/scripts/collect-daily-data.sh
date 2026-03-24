#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# collect-daily-data.sh
# Aggregates Claude Code sessions, Git commits, and Notion tasks for a given day.
# Usage: bash collect-daily-data.sh --date today|yesterday|24h|YYYY-MM-DD
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Parse arguments
# ---------------------------------------------------------------------------
DATE_ARG="today"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --date) DATE_ARG="$2"; shift 2 ;;
    *) DATE_ARG="$1"; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# 2. Resolve date range (epoch milliseconds)
# ---------------------------------------------------------------------------
case "$DATE_ARG" in
  today)
    DISPLAY_DATE=$(date +%Y-%m-%d)
    START_MS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DISPLAY_DATE 00:00:00" +%s)000
    END_MS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DISPLAY_DATE 23:59:59" +%s)999
    GIT_SINCE="$DISPLAY_DATE 00:00:00"
    GIT_UNTIL="$DISPLAY_DATE 23:59:59"
    ;;
  yesterday)
    DISPLAY_DATE=$(date -v-1d +%Y-%m-%d)
    START_MS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DISPLAY_DATE 00:00:00" +%s)000
    END_MS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DISPLAY_DATE 23:59:59" +%s)999
    GIT_SINCE="$DISPLAY_DATE 00:00:00"
    GIT_UNTIL="$DISPLAY_DATE 23:59:59"
    ;;
  24h)
    DISPLAY_DATE="past 24h ($(date -v-24H +%Y-%m-%d) ~ $(date +%Y-%m-%d))"
    END_MS=$(date +%s)000
    START_MS=$(date -v-24H +%s)000
    GIT_SINCE="24 hours ago"
    GIT_UNTIL="now"
    ;;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
    DISPLAY_DATE="$DATE_ARG"
    START_MS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DATE_ARG 00:00:00" +%s)000
    END_MS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DATE_ARG 23:59:59" +%s)999
    GIT_SINCE="$DATE_ARG 00:00:00"
    GIT_UNTIL="$DATE_ARG 23:59:59"
    ;;
  *)
    echo "ERROR: Unknown date format: $DATE_ARG" >&2
    echo "Usage: --date today|yesterday|24h|YYYY-MM-DD" >&2
    exit 1
    ;;
esac

echo "Daily Summary: $DISPLAY_DATE"
echo "================================"
echo ""

# ---------------------------------------------------------------------------
# 3. Section 1: Claude Code Sessions
# ---------------------------------------------------------------------------
echo "=== CLAUDE CODE SESSIONS ==="
echo ""

HISTORY_FILE="$HOME/.claude/history.jsonl"

if [[ -f "$HISTORY_FILE" ]]; then
  START_MS="$START_MS" END_MS="$END_MS" python3 << 'PYEOF'
import json
import os
import re
from pathlib import Path
from collections import defaultdict

start_ms = int(os.environ["START_MS"])
end_ms = int(os.environ["END_MS"])
home = Path.home()
history_file = home / ".claude" / "history.jsonl"

# Read history entries within time range, group by sessionId
sessions = defaultdict(list)
session_projects = {}

with open(history_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = entry.get("timestamp", 0)
        if start_ms <= ts <= end_ms:
            sid = entry.get("sessionId", "")
            if sid:
                sessions[sid].append(entry)
                if "project" in entry:
                    session_projects[sid] = entry["project"]

if not sessions:
    print("(no sessions found)")
else:
    def encode_path(p):
        """Encode path like Claude does: non-alnum and non-hyphen chars become hyphens."""
        return re.sub(r'[^a-zA-Z0-9\-]', '-', p)

    for sid in sorted(sessions.keys(), key=lambda s: min(e["timestamp"] for e in sessions[s])):
        entries = sessions[sid]
        project_path = session_projects.get(sid, "unknown")
        project_name = os.path.basename(project_path) if project_path != "unknown" else "unknown"

        # Compute time range for this session
        timestamps = [e["timestamp"] for e in entries]
        from datetime import datetime
        start_dt = datetime.fromtimestamp(min(timestamps) / 1000)
        end_dt = datetime.fromtimestamp(max(timestamps) / 1000)

        # Read session JSONL for user messages
        encoded_cwd = encode_path(project_path)
        session_jsonl = home / ".claude" / "projects" / encoded_cwd / f"{sid}.jsonl"

        user_messages = []
        if session_jsonl.exists():
            with open(session_jsonl) as sf:
                for sline in sf:
                    sline = sline.strip()
                    if not sline:
                        continue
                    try:
                        msg = json.loads(sline)
                    except json.JSONDecodeError:
                        continue
                    if msg.get("type") != "user":
                        continue
                    if msg.get("userType") == "system":
                        continue

                    # Extract text content
                    content = msg.get("message", {}).get("content", "")
                    if isinstance(content, list):
                        text_parts = []
                        for part in content:
                            if isinstance(part, dict) and part.get("type") == "text":
                                text_parts.append(part.get("text", ""))
                        content = " ".join(text_parts)
                    if not isinstance(content, str):
                        continue

                    content = content.strip()
                    # Redact potential secrets (API keys, tokens)
                    content = re.sub(r'(ntn_|sk-|ghp_|gho_|glpat-|xoxb-|xoxp-)\S+', r'\1***', content)
                    # Skip messages starting with < or /
                    if content.startswith("<") or content.startswith("/"):
                        continue
                    # Skip very short messages
                    if len(content) < 5:
                        continue

                    # Truncate to 120 chars
                    if len(content) > 120:
                        content = content[:117] + "..."
                    user_messages.append(content)

        msg_count = len(user_messages)
        print(f"[{start_dt.strftime('%H:%M')}-{end_dt.strftime('%H:%M')}] {project_name} ({msg_count} msgs)")
        for um in user_messages[:8]:
            print(f"  - {um}")
        if msg_count > 8:
            print(f"  ... and {msg_count - 8} more messages")
        print()
PYEOF
else
  echo "(history.jsonl not found)"
  echo ""
fi

# ---------------------------------------------------------------------------
# 4. Section 2: Git Commits
# ---------------------------------------------------------------------------
echo "=== GIT COMMITS ==="
echo ""

# Collect project paths from history.jsonl + hardcoded extras
PROJECT_PATHS=()

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

# Deduplicate using a temp file
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

FOUND_COMMITS=false
for proj in "${UNIQUE_PATHS[@]}"; do
  proj_name=$(basename "$proj")
  commits=$(cd "$proj" && git log --since="$GIT_SINCE" --until="$GIT_UNTIL" --format="%ai %s" --all 2>/dev/null || true)
  if [[ -n "$commits" ]]; then
    FOUND_COMMITS=true
    echo "[$proj_name]"
    while IFS= read -r commit_line; do
      # Extract time (HH:MM) and message from format "YYYY-MM-DD HH:MM:SS +ZZZZ message"
      commit_time=$(echo "$commit_line" | awk '{print substr($2,1,5)}')
      commit_msg=$(echo "$commit_line" | cut -d' ' -f4-)
      echo "  $commit_time $commit_msg"
    done <<< "$commits"
    echo ""
  fi
done

if [[ "$FOUND_COMMITS" = false ]]; then
  echo "(no commits found)"
  echo ""
fi

# ---------------------------------------------------------------------------
# 5. Section 3: Notion Tasks
# ---------------------------------------------------------------------------
echo "=== NOTION TASKS ==="
echo ""

NOTION_SCRIPT="$HOME/.claude/skills/notion-lifeos/scripts/query-tasks.sh"

if [[ -x "$NOTION_SCRIPT" ]] || [[ -f "$NOTION_SCRIPT" ]]; then
  if [[ "$DATE_ARG" = "24h" ]]; then
    # Query both yesterday and today
    YESTERDAY=$(date -v-1d +%Y-%m-%d)
    TODAY=$(date +%Y-%m-%d)
    echo "--- $YESTERDAY ---"
    bash "$NOTION_SCRIPT" --date "$YESTERDAY" --limit 50 2>/dev/null || echo "(query failed)"
    echo ""
    echo "--- $TODAY ---"
    bash "$NOTION_SCRIPT" --date "$TODAY" --limit 50 2>/dev/null || echo "(query failed)"
  else
    QUERY_DATE="$DISPLAY_DATE"
    # For "today" or "yesterday", DISPLAY_DATE is already YYYY-MM-DD
    bash "$NOTION_SCRIPT" --date "$QUERY_DATE" --limit 50 2>/dev/null || echo "(query failed)"
  fi
else
  echo "(notion-lifeos skill not found, skipping)"
fi

echo ""
echo "================================"
echo "End of daily data collection"
