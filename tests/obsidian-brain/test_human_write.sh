#!/bin/bash
# Tests for human-write.sh zone enforcement.
# Usage: ./test_human_write.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HUMAN_WRITE="$REPO_ROOT/skills/obsidian-brain/scripts/human-write.sh"
TEST_VAULT="/tmp/test-vault-human-write-$$"
PASS=0
FAIL=0

VALID_CONTENT="---
type: task
created: 2026-03-29
source: human
---

# Test
"

setup() {
  mkdir -p "$TEST_VAULT/tasks"
  mkdir -p "$TEST_VAULT/notes"
  mkdir -p "$TEST_VAULT/ops/drafts"
  mkdir -p "$TEST_VAULT/projects"
  mkdir -p "$TEST_VAULT/daily"
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
    echo "  FAIL: $desc (expected success, got failure)"
    FAIL=$((FAIL + 1))
  fi
}

assert_failure() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "  FAIL: $desc (expected failure, got success)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

setup
trap teardown EXIT

echo "=== human-write.sh zone enforcement tests ==="

# 1. Valid write to tasks/
assert_success "write to tasks/" \
  "$HUMAN_WRITE" "$TEST_VAULT" "tasks/test.md" "$VALID_CONTENT"

# 2. Valid write to notes/
assert_success "write to notes/" \
  "$HUMAN_WRITE" "$TEST_VAULT" "notes/test.md" "$VALID_CONTENT"

# 3. Valid write to tasks/subdir/
assert_success "write to tasks/subdir/" \
  "$HUMAN_WRITE" "$TEST_VAULT" "tasks/subdir/test.md" "$VALID_CONTENT"

# 4. Blocked: write to ops/
assert_failure "write to ops/ blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "ops/drafts/hack.md" "$VALID_CONTENT"

# 5. Blocked: write to projects/
assert_failure "write to projects/ blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "projects/hack.md" "$VALID_CONTENT"

# 6. Blocked: write to daily/
assert_failure "write to daily/ blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "daily/hack.md" "$VALID_CONTENT"

# 7. Blocked: path traversal tasks/../ops/
assert_failure "traversal tasks/../ops/ blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "tasks/../ops/hack.md" "$VALID_CONTENT"

# 8. Blocked: missing source: human
NO_SOURCE_CONTENT="---
type: task
created: 2026-03-29
---

# Test
"
assert_failure "missing source: human blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "tasks/no-source.md" "$NO_SOURCE_CONTENT"

# 9. Blocked: source: ai content
AI_SOURCE_CONTENT="---
type: task
created: 2026-03-29
source: ai
---

# Test
"
assert_failure "source: ai blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "tasks/ai-source.md" "$AI_SOURCE_CONTENT"

# 10. Blocked: symlink escape
ln -sf "$TEST_VAULT/ops" "$TEST_VAULT/tasks/escape-link"
assert_failure "symlink escape blocked" \
  "$HUMAN_WRITE" "$TEST_VAULT" "tasks/escape-link/hack.md" "$VALID_CONTENT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
