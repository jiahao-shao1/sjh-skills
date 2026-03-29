#!/bin/bash
# Tests for query-links.sh wikilink parsing.
# Usage: ./test_query_links.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QUERY_LINKS="$REPO_ROOT/skills/obsidian-brain/scripts/query-links.sh"
TEST_VAULT="/tmp/test-vault-links-$$"
PASS=0
FAIL=0

setup() {
  mkdir -p "$TEST_VAULT/notes" "$TEST_VAULT/ops/meetings"

  cat > "$TEST_VAULT/notes/idea-a.md" << 'EOF'
---
type: note
created: 2026-03-29
source: human
---

# Idea A

This links to [[idea-b]] and [[meeting-yuanbo-0329]].
EOF

  cat > "$TEST_VAULT/notes/idea-b.md" << 'EOF'
---
type: note
created: 2026-03-29
source: human
---

# Idea B

This links back to [[idea-a]].
EOF

  cat > "$TEST_VAULT/ops/meetings/meeting-yuanbo-0329.md" << 'EOF'
---
type: meeting-transcript
created: 2026-03-29
source: ai
---

# Meeting

Discussed [[idea-a]].
EOF
}

teardown() {
  rm -rf "$TEST_VAULT"
}

assert_contains() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if echo "$actual" | grep -q "$expected"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected to contain '$expected')"
    echo "  Got: $actual"
    FAIL=$((FAIL + 1))
  fi
}

setup
trap teardown EXIT

echo "=== query-links.sh tests ==="

# Test: find outgoing links from a file
OUT=$("$QUERY_LINKS" "$TEST_VAULT" outgoing "notes/idea-a.md")
assert_contains "outgoing links from idea-a" "idea-b" "$OUT"
assert_contains "outgoing links include cross-zone" "meeting-yuanbo-0329" "$OUT"

# Test: find backlinks to a file
BACK=$("$QUERY_LINKS" "$TEST_VAULT" backlinks "idea-a")
assert_contains "backlinks to idea-a from idea-b" "notes/idea-b.md" "$BACK"
assert_contains "backlinks to idea-a from meeting" "ops/meetings/meeting-yuanbo-0329.md" "$BACK"

# Test: find all links in human zone only
HUMAN=$("$QUERY_LINKS" "$TEST_VAULT" backlinks "idea-a" --human-only)
assert_contains "human-only includes idea-b" "notes/idea-b.md" "$HUMAN"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
