#!/bin/bash
# Tests for analyze.sh utility functions and mode routing.
# Usage: ./test_analyze.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANALYZE="$REPO_ROOT/skills/obsidian-brain/scripts/analyze.sh"
TEST_VAULT="/tmp/test-vault-analyze-$$"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  mkdir -p "$TEST_VAULT/notes" \
           "$TEST_VAULT/tasks" \
           "$TEST_VAULT/projects" \
           "$TEST_VAULT/daily" \
           "$TEST_VAULT/ops/meetings" \
           "$TEST_VAULT/templates" \
           "$TEST_VAULT/.obsidian"

  cat > "$TEST_VAULT/notes/idea-alpha.md" << 'EOF'
---
type: note
created: 2026-03-15
tags: [ai, alignment]
source: human
---

# Idea Alpha

Exploring alignment tax and its implications for [[idea-beta]].
EOF

  cat > "$TEST_VAULT/notes/idea-beta.md" << 'EOF'
---
type: note
created: 2026-03-20
tags: [ai, safety]
source: human
---

# Idea Beta

Complementary view on safety.
EOF

  cat > "$TEST_VAULT/tasks/review-paper.md" << 'EOF'
---
type: task
created: 2026-03-18
tags: [reading]
source: human
---

# Review Paper

Read the alignment tax paper thoroughly.
EOF

  cat > "$TEST_VAULT/daily/2026-03-20.md" << 'EOF'
---
type: daily
created: 2026-03-20
source: human
---

# 2026-03-20

Worked on alignment ideas today.
EOF

  cat > "$TEST_VAULT/ops/meetings/sync-0320.md" << 'EOF'
---
type: meeting-transcript
created: 2026-03-20
source: ai
---

# Sync Meeting

Discussed alignment progress.
EOF

  cat > "$TEST_VAULT/templates/note-tmpl.md" << 'EOF'
---
type: template
---

# {{title}}
EOF

  cat > "$TEST_VAULT/.obsidian/config.json" << 'EOF'
{}
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

assert_not_contains() {
  local desc="$1"
  local unexpected="$2"
  local actual="$3"
  if echo "$actual" | grep -q "$unexpected"; then
    echo "  FAIL: $desc (should NOT contain '$unexpected')"
    echo "  Got: $actual"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

assert_equals() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

setup
trap teardown EXIT

echo "=== analyze.sh tests ==="

# Source the script to access utility functions (ANALYZE_SOURCED skips main).
ANALYZE_SOURCED=1 source "$ANALYZE"

# ---------------------------------------------------------------------------
# Test 1: scan_human_zone returns files from notes/, tasks/, daily/
# ---------------------------------------------------------------------------
echo ""
echo "Test 1: scan_human_zone includes human zone files"
OUT=$(scan_human_zone "$TEST_VAULT")
assert_contains "includes notes/idea-alpha.md" "notes/idea-alpha.md" "$OUT"
assert_contains "includes tasks/review-paper.md" "tasks/review-paper.md" "$OUT"
assert_contains "includes daily/2026-03-20.md" "daily/2026-03-20.md" "$OUT"

# ---------------------------------------------------------------------------
# Test 2: scan_human_zone excludes ops/ and templates/ files
# ---------------------------------------------------------------------------
echo ""
echo "Test 2: scan_human_zone excludes ops/ and templates/"
assert_not_contains "excludes ops/" "ops/" "$OUT"
assert_not_contains "excludes templates/" "templates/" "$OUT"

# ---------------------------------------------------------------------------
# Test 3: extract_frontmatter returns correct YAML
# ---------------------------------------------------------------------------
echo ""
echo "Test 3: extract_frontmatter"
FM=$(extract_frontmatter "$TEST_VAULT/notes/idea-alpha.md")
assert_contains "has type field" "type: note" "$FM"
assert_contains "has created field" "created: 2026-03-15" "$FM"
assert_contains "has tags field" "tags:" "$FM"
assert_not_contains "no --- delimiters" "^---$" "$FM"

# ---------------------------------------------------------------------------
# Test 4: extract_body returns content after frontmatter
# ---------------------------------------------------------------------------
echo ""
echo "Test 4: extract_body"
BODY=$(extract_body "$TEST_VAULT/notes/idea-alpha.md")
assert_contains "has title" "# Idea Alpha" "$BODY"
assert_contains "has body text" "alignment tax" "$BODY"
assert_not_contains "no frontmatter type field" "type: note" "$BODY"

# ---------------------------------------------------------------------------
# Test 5: find_by_date_range returns files within range
# ---------------------------------------------------------------------------
echo ""
echo "Test 5: find_by_date_range"
RANGE=$(find_by_date_range "$TEST_VAULT" "2026-03-17" "2026-03-21")
assert_contains "includes idea-beta (2026-03-20)" "notes/idea-beta.md" "$RANGE"
assert_contains "includes review-paper (2026-03-18)" "tasks/review-paper.md" "$RANGE"
assert_not_contains "excludes idea-alpha (2026-03-15)" "idea-alpha" "$RANGE"

# ---------------------------------------------------------------------------
# Test 6: find_by_keyword finds matching files
# ---------------------------------------------------------------------------
echo ""
echo "Test 6: find_by_keyword"
KW=$(find_by_keyword "$TEST_VAULT" "alignment")
assert_contains "finds idea-alpha" "notes/idea-alpha.md" "$KW"
assert_contains "finds daily" "daily/2026-03-20.md" "$KW"
assert_not_contains "excludes ops/ (not in human zone)" "ops/" "$KW"

# ---------------------------------------------------------------------------
# Test 7: mode routing outputs stub message
# ---------------------------------------------------------------------------
echo ""
echo "Test 7: mode routing"
for mode in challenge drift emerge connect; do
  MODE_OUT=$("$ANALYZE" "$TEST_VAULT" --mode "$mode")
  assert_equals "mode $mode outputs stub" "Mode not yet implemented: $mode" "$MODE_OUT"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
