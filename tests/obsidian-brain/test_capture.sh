#!/bin/bash
# Tests for capture.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CAPTURE="$REPO_ROOT/skills/obsidian-brain/scripts/capture.sh"
TEST_VAULT="/tmp/test-vault-capture-$$"
PASS=0
FAIL=0

setup() {
  mkdir -p "$TEST_VAULT/ops/drafts"
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

echo "=== capture.sh tests ==="

# Test: basic capture creates a file in ops/drafts/
assert_success "capture creates file" \
  "$CAPTURE" "$TEST_VAULT" "This is my thought about AI taste"

# Check the file was created
DRAFT=$(ls "$TEST_VAULT/ops/drafts/"*.md 2>/dev/null | head -1)
if [ -n "$DRAFT" ]; then
  echo "  PASS: draft file exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no draft file created"
  FAIL=$((FAIL + 1))
fi

# Check content
assert_file_contains "draft has source: ai frontmatter" "$DRAFT" "source: ai"
assert_file_contains "draft has user content" "$DRAFT" "AI taste"
assert_file_contains "draft has type: capture" "$DRAFT" "type: capture"

# Test: capture with tags
"$CAPTURE" "$TEST_VAULT" "Another thought" --tags "ai,philosophy" > /dev/null 2>&1
DRAFT2=$(ls -t "$TEST_VAULT/ops/drafts/"*.md 2>/dev/null | head -1)
assert_file_contains "tagged capture has tags" "$DRAFT2" "tags:"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
