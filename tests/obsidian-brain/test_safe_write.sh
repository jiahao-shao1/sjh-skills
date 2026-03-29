#!/bin/bash
# Tests for safe-write.sh zone enforcement.
# Usage: ./test_safe_write.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SAFE_WRITE="$REPO_ROOT/skills/obsidian-brain/scripts/safe-write.sh"
TEST_VAULT="/tmp/test-vault-$$"
PASS=0
FAIL=0

setup() {
  mkdir -p "$TEST_VAULT/ops/drafts"
  mkdir -p "$TEST_VAULT/notes"
  mkdir -p "$TEST_VAULT/projects"
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

echo "=== safe-write.sh zone enforcement tests ==="

# Valid writes to AI zone
assert_success "write to ops/drafts/" \
  "$SAFE_WRITE" "$TEST_VAULT" "ops/drafts/test.md" "test content"

assert_success "write to ops/meetings/" \
  bash -c "mkdir -p '$TEST_VAULT/ops/meetings' && '$SAFE_WRITE' '$TEST_VAULT' 'ops/meetings/m.md' 'content'"

assert_success "write to ops/research/" \
  bash -c "mkdir -p '$TEST_VAULT/ops/research' && '$SAFE_WRITE' '$TEST_VAULT' 'ops/research/r.md' 'content'"

# Invalid writes to human zone — must be rejected
assert_failure "write to notes/ blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "notes/hack.md" "injected content"

assert_failure "write to projects/ blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "projects/hack.md" "injected content"

assert_failure "write to daily/ blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "daily/hack.md" "injected content"

assert_failure "write to root blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "hack.md" "injected content"

# Path traversal attacks
assert_failure "traversal ops/../notes/ blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "ops/../notes/hack.md" "injected content"

assert_failure "traversal ops/../../etc/passwd blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "ops/../../etc/passwd" "injected content"

# Symlink escape
ln -sf "$TEST_VAULT/notes" "$TEST_VAULT/ops/escape-link"
assert_failure "symlink escape blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "ops/escape-link/hack.md" "injected content"

# ops prefix bypass (opsx/ should not pass)
mkdir -p "$TEST_VAULT/opsx"
assert_failure "opsx/ prefix bypass blocked" \
  "$SAFE_WRITE" "$TEST_VAULT" "opsx/hack.md" "injected content"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
