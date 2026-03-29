#!/bin/bash
# Mark a task as done by modifying its YAML frontmatter.
#
# Usage:
#   ./complete-task.sh <vault-root> <task-identifier>
#
# Task identifier can be a filename (without path/extension) or a title keyword.
# Search logic:
#   1. Exact filename match in tasks/ (e.g., "migrate-projects" matches tasks/migrate-projects.md or tasks/*migrate-projects*.md)
#   2. Fuzzy: grep all tasks/*.md for title keyword (case-insensitive)
#   3. Exactly 1 match → proceed; 0 → error; multiple → list and error

set -euo pipefail

VAULT_ROOT="$1"
IDENTIFIER="$2"

VAULT_ABS="$(cd "$VAULT_ROOT" && pwd -P)"
TASKS_DIR="$VAULT_ABS/tasks"

if [ ! -d "$TASKS_DIR" ]; then
  echo "ERROR: No task found matching: $IDENTIFIER" >&2
  exit 1
fi

matches=()

# Step 1: Try exact filename match
if [ -f "$TASKS_DIR/${IDENTIFIER}.md" ]; then
  matches=("$TASKS_DIR/${IDENTIFIER}.md")
fi

# Step 1b: Try glob match if no exact match
if [ ${#matches[@]} -eq 0 ]; then
  while IFS= read -r f; do
    matches+=("$f")
  done < <(find "$TASKS_DIR" -maxdepth 1 -name "*${IDENTIFIER}*.md" -type f 2>/dev/null)
fi

# Step 2: Fuzzy search by title keyword if still no match
if [ ${#matches[@]} -eq 0 ]; then
  while IFS= read -r f; do
    matches+=("$f")
  done < <(grep -ril "$IDENTIFIER" "$TASKS_DIR"/*.md 2>/dev/null || true)
fi

# Step 3: Evaluate match count
if [ ${#matches[@]} -eq 0 ]; then
  echo "ERROR: No task found matching: $IDENTIFIER" >&2
  exit 1
fi

if [ ${#matches[@]} -gt 1 ]; then
  echo "ERROR: Multiple tasks match, please be more specific:" >&2
  for m in "${matches[@]}"; do
    echo "  - tasks/$(basename "$m")" >&2
  done
  exit 1
fi

# Exactly one match
file="${matches[0]}"
rel_path="tasks/$(basename "$file")"

# Check if already completed
if grep -q '^done: true' "$file"; then
  echo "Already completed: $file"
  exit 0
fi

# Modify done: false → done: true
if [ "$(uname)" = "Darwin" ]; then
  sed -i '' 's/^done: false$/done: true/' "$file"
else
  sed -i 's/^done: false$/done: true/' "$file"
fi

echo "Completed: $rel_path"
