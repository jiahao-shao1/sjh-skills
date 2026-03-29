#!/bin/bash
# Tests for complete-task.sh
# Usage: ./test_complete_task.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPLETE_TASK="$REPO_ROOT/skills/obsidian-brain/scripts/complete-task.sh"
TEST_VAULT="/tmp/test-vault-complete-$$"
PASS=0
FAIL=0

setup() {
  mkdir -p "$TEST_VAULT/tasks"
}

teardown() {
  rm -rf "$TEST_VAULT"
}

assert_output_contains() {
  local desc="$1"
  local expected="$2"
  local output="$3"
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected' in output, got: $output)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local desc="$1"
  local file="$2"
  local expected="$3"
  if [ -f "$file" ] && grep -q "$expected" "$file"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (file missing or content mismatch)"
    FAIL=$((FAIL + 1))
  fi
}

create_task_file() {
  local name="$1"
  local title="${2:-Task Title}"
  local done="${3:-false}"
  cat > "$TEST_VAULT/tasks/${name}.md" <<EOF
---
type: task
created: 2026-03-29
due: 2026-04-05
done: $done
tags: [migration]
source: human
---

# $title
EOF
}

setup
trap teardown EXIT

echo "=== complete-task.sh tests ==="

# 1. Exact filename match completes task
create_task_file "migrate-projects" "把活跃项目迁移到 Obsidian"
OUTPUT=$("$COMPLETE_TASK" "$TEST_VAULT" "migrate-projects")
assert_output_contains "exact filename match outputs Completed" "Completed:" "$OUTPUT"

# 2. Frontmatter changes from done: false to done: true
assert_file_contains "frontmatter changed to done: true" \
  "$TEST_VAULT/tasks/migrate-projects.md" "^done: true$"

# 3. Fuzzy keyword match completes task
create_task_file "2026-03-29-review-papers" "Review papers for NeurIPS"
OUTPUT=$("$COMPLETE_TASK" "$TEST_VAULT" "NeurIPS")
assert_output_contains "fuzzy keyword match outputs Completed" "Completed:" "$OUTPUT"
assert_file_contains "fuzzy match changed frontmatter" \
  "$TEST_VAULT/tasks/2026-03-29-review-papers.md" "^done: true$"

# 4. Already completed task shows "Already completed"
create_task_file "done-task" "Already Done Task" "true"
OUTPUT=$("$COMPLETE_TASK" "$TEST_VAULT" "done-task")
assert_output_contains "already completed task shows message" "Already completed:" "$OUTPUT"

# 5. No match returns error
OUTPUT=$("$COMPLETE_TASK" "$TEST_VAULT" "nonexistent-xyz-123" 2>&1 || true)
assert_output_contains "no match returns error" "ERROR: No task found matching: nonexistent-xyz-123" "$OUTPUT"

# 6. Multiple matches returns error with list
create_task_file "weekly-review-a" "Weekly Review A"
create_task_file "weekly-review-b" "Weekly Review B"
OUTPUT=$("$COMPLETE_TASK" "$TEST_VAULT" "weekly-review" 2>&1 || true)
assert_output_contains "multiple matches returns error" "ERROR: Multiple tasks match" "$OUTPUT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
