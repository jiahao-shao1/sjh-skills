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
# Test 7: mode routing — all modes run without error
# ---------------------------------------------------------------------------
echo ""
echo "Test 7: mode routing (modes execute without crash)"
EMERGE_ROUTE=$("$ANALYZE" "$TEST_VAULT" --mode emerge --days 30 2>&1 || true)
assert_contains "emerge mode runs" "Emerge Analysis\|No content found" "$EMERGE_ROUTE"
CONNECT_ROUTE=$("$ANALYZE" "$TEST_VAULT" --mode connect --topics "alignment,safety" 2>&1 || true)
assert_contains "connect mode runs" "Connect:" "$CONNECT_ROUTE"

# ---------------------------------------------------------------------------
# Test 8: challenge finds relevant paragraphs
# ---------------------------------------------------------------------------
echo ""
echo "Test 8: challenge finds relevant paragraphs"
CHALL_OUT=$("$ANALYZE" "$TEST_VAULT" --mode challenge --topic "alignment")
assert_contains "has challenge header" "## Challenge: alignment" "$CHALL_OUT"
assert_contains "finds idea-alpha" "idea-alpha" "$CHALL_OUT"
assert_contains "includes date" "2026-03-15" "$CHALL_OUT"
assert_contains "quotes paragraph" "> " "$CHALL_OUT"

# ---------------------------------------------------------------------------
# Test 9: challenge excludes ops/ content
# ---------------------------------------------------------------------------
echo ""
echo "Test 9: challenge excludes ops/ content"
assert_not_contains "excludes ops/ files" "sync-0320" "$CHALL_OUT"
assert_not_contains "excludes meeting content" "Discussed alignment progress" "$CHALL_OUT"

# ---------------------------------------------------------------------------
# Test 10: challenge with no matches outputs message
# ---------------------------------------------------------------------------
echo ""
echo "Test 10: challenge with no matches"
CHALL_NONE=$("$ANALYZE" "$TEST_VAULT" --mode challenge --topic "xyznonexistent")
assert_contains "shows no content message" "No relevant content found for: xyznonexistent" "$CHALL_NONE"

# ---------------------------------------------------------------------------
# Test 11: challenge without --topic shows error
# ---------------------------------------------------------------------------
echo ""
echo "Test 11: challenge without --topic shows error"
CHALL_ERR=$("$ANALYZE" "$TEST_VAULT" --mode challenge 2>&1 || true)
assert_contains "shows error about --topic" "ERROR: --topic is required" "$CHALL_ERR"

# ---------------------------------------------------------------------------
# Setup additional fixtures for drift tests
# ---------------------------------------------------------------------------

# Create active projects
cat > "$TEST_VAULT/projects/proj-alpha.md" << 'EOF'
---
type: project
status: active
created: 2026-01-01
---

# Project Alpha

Working on alignment research.
EOF

cat > "$TEST_VAULT/projects/proj-beta.md" << 'EOF'
---
type: project
status: active
created: 2026-01-15
---

# Project Beta

Working on interpretability.
EOF

cat > "$TEST_VAULT/projects/proj-archived.md" << 'EOF'
---
type: project
status: archived
created: 2026-01-10
---

# Archived Project

This is done.
EOF

# Create daily notes within the last 60 days that mention projects
cat > "$TEST_VAULT/daily/2026-03-25.md" << 'EOF'
---
type: daily
created: 2026-03-25
source: human
---

# 2026-03-25

Made progress on Project Alpha today. Also reviewed Project Alpha docs.
EOF

cat > "$TEST_VAULT/daily/2026-03-28.md" << 'EOF'
---
type: daily
created: 2026-03-28
source: human
---

# 2026-03-28

Continued work on Project Alpha. Linked to [[Project Beta]] for collaboration.
EOF

# ---------------------------------------------------------------------------
# Test 12: drift lists active projects
# ---------------------------------------------------------------------------
echo ""
echo "Test 12: drift lists active projects"
DRIFT_OUT=$("$ANALYZE" "$TEST_VAULT" --mode drift --days 60)
assert_contains "has drift header" "## Drift Analysis (last 60 days)" "$DRIFT_OUT"
assert_contains "has table header" "| Project | Mentions | Last Mentioned |" "$DRIFT_OUT"
assert_contains "includes Project Alpha" "Project Alpha" "$DRIFT_OUT"
assert_contains "includes Project Beta" "Project Beta" "$DRIFT_OUT"
assert_not_contains "excludes Archived Project" "Archived Project" "$DRIFT_OUT"

# ---------------------------------------------------------------------------
# Test 13: drift counts mentions in daily notes
# ---------------------------------------------------------------------------
echo ""
echo "Test 13: drift counts mentions in daily notes"
# Project Alpha is mentioned 3 times across two daily notes
assert_contains "Project Alpha has mentions" "Project Alpha" "$DRIFT_OUT"
# Check that last mentioned date is shown
assert_contains "shows last mentioned date for Alpha" "2026-03-28" "$DRIFT_OUT"

# ---------------------------------------------------------------------------
# Test 14: drift shows 0 for unmentioned projects
# ---------------------------------------------------------------------------
echo ""
echo "Test 14: drift shows 0 for unmentioned projects"
# Create an active project that is never mentioned in daily notes
cat > "$TEST_VAULT/projects/proj-gamma.md" << 'EOF'
---
type: project
status: active
created: 2026-02-01
---

# Project Gamma

Totally new project nobody writes about.
EOF

DRIFT_OUT2=$("$ANALYZE" "$TEST_VAULT" --mode drift --days 60)
assert_contains "shows Project Gamma" "Project Gamma" "$DRIFT_OUT2"
assert_contains "shows 0 mentions" "| Project Gamma | 0 | never |" "$DRIFT_OUT2"

# ---------------------------------------------------------------------------
# Test 15: drift with no active projects shows message
# ---------------------------------------------------------------------------
echo ""
echo "Test 15: drift with no active projects"
# Create a vault with no active projects
NO_ACTIVE_VAULT="/tmp/test-vault-no-active-$$"
mkdir -p "$NO_ACTIVE_VAULT/projects" "$NO_ACTIVE_VAULT/daily"
cat > "$NO_ACTIVE_VAULT/projects/old.md" << 'EOF'
---
type: project
status: archived
created: 2026-01-01
---

# Old Project
EOF

DRIFT_EMPTY=$("$ANALYZE" "$NO_ACTIVE_VAULT" --mode drift)
assert_contains "shows no active projects message" "No active projects found." "$DRIFT_EMPTY"
rm -rf "$NO_ACTIVE_VAULT"

# ---------------------------------------------------------------------------
# Tests 16-23: emerge and connect modes
# ---------------------------------------------------------------------------

# Setup additional fixtures for emerge and connect tests
cat > "$TEST_VAULT/notes/idea-gamma.md" << 'EOF'
---
type: note
created: 2026-03-22
tags: [ai]
source: human
---

# Idea Gamma

This references [[ghost-concept]] which has no file.
Also links to [[idea-beta]] and [[another-ghost]].
And mentions [[ghost-concept]] again for emphasis.
EOF

cat > "$TEST_VAULT/daily/2026-03-22.md" << 'EOF'
---
type: daily
created: 2026-03-22
source: human
---

# 2026-03-22

Today I explored [[idea-beta]] and discovered [[ghost-concept]].
Also thought about [[idea-gamma]].
EOF

echo ""
echo "Test 16: emerge finds ghost links"
EMERGE_OUT=$("$ANALYZE" "$TEST_VAULT" --mode emerge --days 30)
assert_contains "has emerge header" "## Emerge Analysis" "$EMERGE_OUT"
assert_contains "has ghost links section" "### Ghost Links" "$EMERGE_OUT"
assert_contains "finds ghost-concept" "ghost-concept" "$EMERGE_OUT"
assert_contains "finds another-ghost" "another-ghost" "$EMERGE_OUT"

echo ""
echo "Test 17: emerge finds frequent links"
assert_contains "has frequent links section" "### Frequent Links" "$EMERGE_OUT"
assert_contains "idea-beta is frequent" "idea-beta" "$EMERGE_OUT"

echo ""
echo "Test 18: emerge respects --days filter"
EMERGE_SHORT=$("$ANALYZE" "$TEST_VAULT" --mode emerge --days 1)
assert_contains "no content for 1-day window" "No content found in the last 1 days" "$EMERGE_SHORT"

echo ""
echo "Test 19: emerge with no content in date range"
EMPTY_VAULT="/tmp/test-vault-emerge-empty-$$"
mkdir -p "$EMPTY_VAULT/notes" "$EMPTY_VAULT/daily"
EMERGE_EMPTY=$("$ANALYZE" "$EMPTY_VAULT" --mode emerge --days 30)
assert_contains "shows no content message" "No content found in the last 30 days" "$EMERGE_EMPTY"
rm -rf "$EMPTY_VAULT"

# Setup connect fixtures
cat > "$TEST_VAULT/notes/safety-review.md" << 'EOF'
---
type: note
created: 2026-03-21
tags: [safety]
source: human
---

# Safety Review

Reviewing safety protocols and their relation to [[shared-link]].
EOF

cat > "$TEST_VAULT/notes/bridge-note.md" << 'EOF'
---
type: note
created: 2026-03-23
tags: [ai]
source: human
---

# Bridge Note

This note discusses both alignment concerns and safety requirements.
It links to [[shared-link]] and [[unique-to-bridge]].
EOF

echo ""
echo "Test 20: connect finds files for each topic"
CONNECT_OUT=$("$ANALYZE" "$TEST_VAULT" --mode connect --topics "alignment,safety")
assert_contains "has connect header" "Connect: alignment" "$CONNECT_OUT"
assert_contains "has alignment section" "Files mentioning \"alignment\"" "$CONNECT_OUT"
assert_contains "has safety section" "Files mentioning \"safety\"" "$CONNECT_OUT"
assert_contains "alignment finds idea-alpha" "notes/idea-alpha.md" "$CONNECT_OUT"
assert_contains "safety finds idea-beta" "notes/idea-beta.md" "$CONNECT_OUT"

echo ""
echo "Test 21: connect finds bridge files"
assert_contains "has bridge section" "### Bridge Files" "$CONNECT_OUT"
assert_contains "bridge-note is a bridge" "notes/bridge-note.md" "$CONNECT_OUT"

echo ""
echo "Test 22: connect finds shared wikilinks"
assert_contains "has shared links section" "### Shared Links" "$CONNECT_OUT"
assert_contains "finds shared-link" "shared-link" "$CONNECT_OUT"

echo ""
echo "Test 23: connect with missing --topics shows error"
CONNECT_ERR=$("$ANALYZE" "$TEST_VAULT" --mode connect 2>&1 || true)
assert_contains "shows error about --topics" "ERROR: --topics is required" "$CONNECT_ERR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
