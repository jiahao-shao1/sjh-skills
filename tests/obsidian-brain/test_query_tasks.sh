#!/bin/bash
# Tests for query-tasks.sh task querying and filtering.
# Usage: ./test_query_tasks.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QUERY_TASKS="$REPO_ROOT/skills/obsidian-brain/scripts/query-tasks.sh"
TEST_VAULT="/tmp/test-vault-query-$$"
PASS=0
FAIL=0

# Get today's date and compute useful dates
TODAY=$(date +%Y-%m-%d)
if [ "$(uname)" = "Darwin" ]; then
  YESTERDAY=$(date -v-1d +%Y-%m-%d)
  NEXT_WEEK=$(date -v+8d +%Y-%m-%d)
  # A date guaranteed within this week (today itself)
  THIS_WEEK_DATE="$TODAY"
else
  YESTERDAY=$(date -d "-1 day" +%Y-%m-%d)
  NEXT_WEEK=$(date -d "+8 days" +%Y-%m-%d)
  THIS_WEEK_DATE="$TODAY"
fi

setup() {
  mkdir -p "$TEST_VAULT/tasks"

  # Task 1: undone, due today, tag: migration
  cat > "$TEST_VAULT/tasks/migrate-projects.md" << EOF
---
type: task
created: 2026-03-28
due: $TODAY
done: false
tags: [migration, obsidian]
source: human
---

# 把活跃项目迁移到 Obsidian

从 Notion 里把当前 WIP 的项目描述搬到 \`projects/\`。Related: [[obsidian-brain]]
EOF

  # Task 2: done, due yesterday, tag: review
  cat > "$TEST_VAULT/tasks/review-paper.md" << EOF
---
type: task
created: 2026-03-27
due: $YESTERDAY
done: true
tags: [review]
source: human
---

# Review transformer paper

Read and annotate the paper.
EOF

  # Task 3: undone, due next week, tag: migration
  cat > "$TEST_VAULT/tasks/setup-templates.md" << EOF
---
type: task
created: 2026-03-28
due: $NEXT_WEEK
done: false
tags: [migration]
source: human
---

# Setup vault templates

Create templates for daily notes and tasks.
EOF

  # Task 4: undone, no due date, tag: idea
  cat > "$TEST_VAULT/tasks/explore-plugins.md" << EOF
---
type: task
created: 2026-03-29
done: false
tags: [idea]
source: human
---

# Explore useful Obsidian plugins

Research community plugins. Related: [[obsidian-brain]]
EOF

  # Task 5: undone, due today, no tags, empty tags list
  cat > "$TEST_VAULT/tasks/quick-fix.md" << EOF
---
type: task
created: 2026-03-29
due: $TODAY
done: false
tags: []
source: human
---

# Quick fix for daily template

Fix the date format bug.
EOF
}

teardown() {
  rm -rf "$TEST_VAULT"
}

assert_contains() {
  local desc="$1" output="$2" expected="$3"
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected to find: $expected)"
    echo "  Got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" output="$2" expected="$3"
  if echo "$output" | grep -q "$expected"; then
    echo "  FAIL: $desc (found unexpected: $expected)"
    echo "  Got: $output"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

setup
trap teardown EXIT

echo "=== query-tasks.sh tests ==="

# Test 1: Query all tasks (no filters) — should return all 5
echo "--- Test 1: all tasks ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT")
assert_contains "shows migrate task" "$OUT" "把活跃项目迁移到 Obsidian"
assert_contains "shows review task" "$OUT" "Review transformer paper"
assert_contains "shows templates task" "$OUT" "Setup vault templates"
assert_contains "shows plugins task" "$OUT" "Explore useful Obsidian plugins"
assert_contains "shows quick-fix task" "$OUT" "Quick fix for daily template"
assert_contains "has table header" "$OUT" "| Status | Title | Due | Tags |"

# Test 2: Filter by --undone
echo "--- Test 2: --undone ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --undone)
assert_contains "undone includes migrate" "$OUT" "把活跃项目迁移到 Obsidian"
assert_not_contains "undone excludes done review" "$OUT" "Review transformer paper"

# Test 3: Filter by --date with specific date
echo "--- Test 3: --date specific ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --date "$YESTERDAY")
assert_contains "specific date finds yesterday task" "$OUT" "Review transformer paper"
assert_not_contains "specific date excludes today task" "$OUT" "把活跃项目迁移到 Obsidian"

# Test 4: Filter by --date today
echo "--- Test 4: --date today ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --date today)
assert_contains "today includes migrate" "$OUT" "把活跃项目迁移到 Obsidian"
assert_contains "today includes quick-fix" "$OUT" "Quick fix for daily template"
assert_not_contains "today excludes next-week task" "$OUT" "Setup vault templates"

# Test 5: Filter by --date this-week
echo "--- Test 5: --date this-week ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --date this-week)
assert_contains "this-week includes today task" "$OUT" "把活跃项目迁移到 Obsidian"
assert_not_contains "this-week excludes next-week task" "$OUT" "Setup vault templates"
assert_not_contains "this-week excludes no-due task" "$OUT" "Explore useful Obsidian plugins"

# Test 6: Filter by --tag
echo "--- Test 6: --tag ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --tag migration)
assert_contains "tag migration includes migrate" "$OUT" "把活跃项目迁移到 Obsidian"
assert_contains "tag migration includes templates" "$OUT" "Setup vault templates"
assert_not_contains "tag migration excludes review" "$OUT" "Review transformer paper"

# Test 7: Combined filters --undone --tag migration
echo "--- Test 7: combined --undone --tag ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --undone --tag migration)
assert_contains "combined: migrate (undone + migration)" "$OUT" "把活跃项目迁移到 Obsidian"
assert_contains "combined: templates (undone + migration)" "$OUT" "Setup vault templates"
assert_not_contains "combined: excludes done review" "$OUT" "Review transformer paper"
assert_not_contains "combined: excludes idea tag" "$OUT" "Explore useful Obsidian plugins"

# Test 8: No matching tasks
echo "--- Test 8: no matches ---"
OUT=$("$QUERY_TASKS" "$TEST_VAULT" --tag nonexistent)
assert_contains "no matches returns message" "$OUT" "No tasks found."

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
