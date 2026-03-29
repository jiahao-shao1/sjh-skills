#!/bin/bash
# Tests for create-note.sh
# Usage: ./test_create_note.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_NOTE="$REPO_ROOT/skills/obsidian-brain/scripts/create-note.sh"
TEST_VAULT="/tmp/test-vault-create-note-$$"
PASS=0
FAIL=0

setup() {
  mkdir -p "$TEST_VAULT/notes"
}

teardown() {
  rm -rf "$TEST_VAULT"
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
    if [ -f "$file" ]; then
      echo "    File contents:"
      cat "$file" | head -20 | sed 's/^/    /'
    fi
    FAIL=$((FAIL + 1))
  fi
}

setup
trap teardown EXIT

TODAY=$(date +%Y-%m-%d)

echo "=== create-note.sh tests ==="

# 1. Basic note creation
OUTPUT=$("$CREATE_NOTE" "$TEST_VAULT" "My First Note" "This is the body text.")
NOTE_FILE="$TEST_VAULT/notes/my-first-note.md"
if [ -f "$NOTE_FILE" ]; then
  echo "  PASS: basic note creation"
  PASS=$((PASS + 1))
else
  echo "  FAIL: basic note creation (file not found at $NOTE_FILE)"
  FAIL=$((FAIL + 1))
fi

# 2. Frontmatter has type: note and source: human
assert_file_contains "frontmatter has type: note" "$NOTE_FILE" "^type: note$"
assert_file_contains "frontmatter has source: human" "$NOTE_FILE" "^source: human$"

# 3. Content appears in body
assert_file_contains "content appears in body" "$NOTE_FILE" "This is the body text."

# 4. Tags formatting
"$CREATE_NOTE" "$TEST_VAULT" "Tagged Note" "Some content" --tags "research,ml" > /dev/null 2>&1
TAGS_FILE="$TEST_VAULT/notes/tagged-note.md"
assert_file_contains "tags formatting" "$TAGS_FILE" "tags: \[research, ml\]"

# 5. Wikilinks from --links appear in body
"$CREATE_NOTE" "$TEST_VAULT" "Linked Note" "Some linked content" --links "concept1,concept2" > /dev/null 2>&1
LINKS_FILE="$TEST_VAULT/notes/linked-note.md"
assert_file_contains "wikilinks appear in body" "$LINKS_FILE" "Related:.*\[\[concept1\]\].*\[\[concept2\]\]"

# 6. Duplicate filename handling
"$CREATE_NOTE" "$TEST_VAULT" "My First Note" "Duplicate body." > /dev/null 2>&1
DUP_FILE="$TEST_VAULT/notes/my-first-note-2.md"
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
