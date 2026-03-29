#!/bin/bash
# Tests for create-task.sh
# Usage: ./test_create_task.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_TASK="$REPO_ROOT/skills/obsidian-brain/scripts/create-task.sh"
TEST_VAULT="/tmp/test-vault-create-task-$$"
PASS=0
FAIL=0

setup() {
  mkdir -p "$TEST_VAULT/tasks"
}

teardown() {
  rm -rf "$TEST_VAULT"
}

assert_success() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
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

setup
trap teardown EXIT

TODAY=$(date +%Y-%m-%d)

echo "=== create-task.sh tests ==="

# 1. Basic task creation
assert_success "basic task creation" \
  "$CREATE_TASK" "$TEST_VAULT" "My First Task"

# Find the created file
TASK_FILE="$TEST_VAULT/tasks/${TODAY}-my-first-task.md"

# 2. File exists after creation
if [ -f "$TASK_FILE" ]; then
  echo "  PASS: task file exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: task file does not exist at $TASK_FILE"
  FAIL=$((FAIL + 1))
fi

# 3. Frontmatter has type: task
assert_file_contains "frontmatter has type: task" "$TASK_FILE" "^type: task$"

# 4. Frontmatter has source: human
assert_file_contains "frontmatter has source: human" "$TASK_FILE" "^source: human$"

# 5. Frontmatter has done: false
assert_file_contains "frontmatter has done: false" "$TASK_FILE" "^done: false$"

# 6. Due date in frontmatter
"$CREATE_TASK" "$TEST_VAULT" "Task With Due" --due "2026-04-15" > /dev/null 2>&1
DUE_FILE="$TEST_VAULT/tasks/${TODAY}-task-with-due.md"
assert_file_contains "due date in frontmatter" "$DUE_FILE" "^due: 2026-04-15$"

# 7. Tags formatting
"$CREATE_TASK" "$TEST_VAULT" "Tagged Task" --tags "work,urgent" > /dev/null 2>&1
TAGS_FILE="$TEST_VAULT/tasks/${TODAY}-tagged-task.md"
assert_file_contains "tags formatting" "$TAGS_FILE" "tags: \[work, urgent\]"

# 8. Duplicate filename handling
"$CREATE_TASK" "$TEST_VAULT" "My First Task" > /dev/null 2>&1
DUP_FILE="$TEST_VAULT/tasks/${TODAY}-my-first-task-2.md"
if [ -f "$DUP_FILE" ]; then
  echo "  PASS: duplicate filename gets -2 suffix"
  PASS=$((PASS + 1))
else
  echo "  FAIL: duplicate filename handling (expected $DUP_FILE)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
