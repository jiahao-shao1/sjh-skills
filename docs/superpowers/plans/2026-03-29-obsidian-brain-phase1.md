# Obsidian Brain Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `obsidian-brain` skill that sets up a dual-zone Obsidian Vault and provides `/context`, `/capture`, and `/today` commands with zone enforcement.

**Architecture:** A Claude Code skill in `skills/obsidian-brain/` with bash scripts for vault initialization, zone-enforced writes, and wikilink querying. The vault at `~/second-brain/` has a human zone (AI read-only: notes/, projects/, tasks/, resources/, contexts/, daily/, people/) and an AI zone (read-write: ops/). All write operations resolve paths via `realpath` and reject anything outside `$VAULT_ROOT/ops/`.

**Tech Stack:** Bash scripts, Obsidian CLI (with ripgrep fallback), YAML frontmatter, Markdown wikilinks, git for vault VCS.

---

## File Map

| File | Responsibility |
|------|---------------|
| `skills/obsidian-brain/SKILL.md` | Skill definition, triggers, zone rules, command docs |
| `skills/obsidian-brain/scripts/init-vault.sh` | Create vault directory structure + git init + copy templates |
| `skills/obsidian-brain/scripts/safe-write.sh` | Zone-enforced write: realpath validation, only allows `ops/` |
| `skills/obsidian-brain/scripts/capture.sh` | Capture user input to `ops/drafts/` via safe-write |
| `skills/obsidian-brain/scripts/query-links.sh` | Query wikilinks/backlinks via obsidian-cli or ripgrep fallback |
| `skills/obsidian-brain/references/vault-schema.md` | Frontmatter conventions, zone rules, wikilink strategy |
| `skills/obsidian-brain/references/command-guide.md` | Detailed command reference for /context, /capture, /today |
| `skills/obsidian-brain/templates/note.md` | Template for notes (human zone) |
| `skills/obsidian-brain/templates/task.md` | Template for tasks (human zone) |
| `skills/obsidian-brain/templates/project.md` | Template for projects (human zone) |
| `skills/obsidian-brain/templates/resource.md` | Template for resources (human zone) |
| `skills/obsidian-brain/templates/daily.md` | Template for daily notes (human zone) |
| `skills/obsidian-brain/templates/meeting-transcript.md` | Template for AI-generated transcripts (AI zone) |
| `skills/obsidian-brain/templates/context.md` | Template for deep context files (human zone) |
| `tests/obsidian-brain/test_safe_write.sh` | Zone boundary tests: path traversal, symlink escape, valid writes |
| `tests/obsidian-brain/test_query_links.sh` | Wikilink query tests: obsidian-cli and ripgrep fallback |
| `tests/obsidian-brain/test_capture.sh` | Capture command tests |

---

### Task 1: Vault Initialization Script

**Files:**
- Create: `skills/obsidian-brain/scripts/init-vault.sh`

- [ ] **Step 1: Write init-vault.sh**

```bash
#!/bin/bash
# Initialize an Obsidian Second Brain vault with dual-zone structure.
# Usage: ./init-vault.sh [vault-path]
# Default: ~/second-brain

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_ROOT="${1:-$HOME/second-brain}"

if [ -d "$VAULT_ROOT/.obsidian" ]; then
  echo "Vault already exists at $VAULT_ROOT"
  exit 0
fi

echo "Creating vault at $VAULT_ROOT..."

# Human zone directories (AI: read-only)
mkdir -p "$VAULT_ROOT/notes"
mkdir -p "$VAULT_ROOT/projects"
mkdir -p "$VAULT_ROOT/tasks"
mkdir -p "$VAULT_ROOT/resources"
mkdir -p "$VAULT_ROOT/contexts"
mkdir -p "$VAULT_ROOT/daily"
mkdir -p "$VAULT_ROOT/people"

# AI zone directories (AI: read-write)
mkdir -p "$VAULT_ROOT/ops/drafts"
mkdir -p "$VAULT_ROOT/ops/meetings"
mkdir -p "$VAULT_ROOT/ops/research"

# System directories
mkdir -p "$VAULT_ROOT/templates"
mkdir -p "$VAULT_ROOT/.obsidian"

# Copy templates from skill
if [ -d "$SKILL_DIR/templates" ]; then
  cp "$SKILL_DIR/templates/"*.md "$VAULT_ROOT/templates/" 2>/dev/null || true
fi

# Initialize git
cd "$VAULT_ROOT"
if [ ! -d ".git" ]; then
  git init
  cat > .gitignore << 'GITIGNORE'
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash/
GITIGNORE
  git add -A
  git commit -m "init: obsidian second brain vault"
fi

echo "Vault initialized at $VAULT_ROOT"
echo "  Human zone: notes/ projects/ tasks/ resources/ contexts/ daily/ people/"
echo "  AI zone:    ops/"
echo "  Templates:  templates/"
echo ""
echo "Open this folder in Obsidian to start using it."
```

- [ ] **Step 2: Make it executable and test manually**

Run:
```bash
chmod +x skills/obsidian-brain/scripts/init-vault.sh
./skills/obsidian-brain/scripts/init-vault.sh /tmp/test-vault
ls -la /tmp/test-vault/
ls -la /tmp/test-vault/ops/
```

Expected: directories exist, git initialized, templates copied.

- [ ] **Step 3: Clean up test vault**

Run:
```bash
rm -rf /tmp/test-vault
```

- [ ] **Step 4: Commit**

```bash
git add skills/obsidian-brain/scripts/init-vault.sh
git commit -m "feat(obsidian-brain): add vault initialization script"
```

---

### Task 2: Templates

**Files:**
- Create: `skills/obsidian-brain/templates/note.md`
- Create: `skills/obsidian-brain/templates/task.md`
- Create: `skills/obsidian-brain/templates/project.md`
- Create: `skills/obsidian-brain/templates/resource.md`
- Create: `skills/obsidian-brain/templates/daily.md`
- Create: `skills/obsidian-brain/templates/meeting-transcript.md`
- Create: `skills/obsidian-brain/templates/context.md`

- [ ] **Step 1: Create note template**

```markdown
---
type: note
created: {{date}}
tags: []
source: human
---

# {{title}}


```

- [ ] **Step 2: Create task template**

```markdown
---
type: task
created: {{date}}
due:
done: false
tags: []
source: human
---

# {{title}}


```

- [ ] **Step 3: Create project template**

```markdown
---
type: project
created: {{date}}
status: active
tags: []
source: human
---

# {{title}}

## Goal


## Current Status


## Related
```

- [ ] **Step 4: Create resource template**

```markdown
---
type: resource
created: {{date}}
url:
tags: []
source: human
---

# {{title}}

## Summary


## Key Takeaways

```

- [ ] **Step 5: Create daily template**

```markdown
---
type: daily
created: {{date}}
source: human
---

# {{date}}

## What happened today


## What I'm thinking about


## Tomorrow
```

- [ ] **Step 6: Create meeting-transcript template (AI zone)**

```markdown
---
type: meeting-transcript
created: {{date}}
speakers: []
source: ai
---

# Meeting: {{title}} — {{date}}

## Participants


## Transcript


## Action Items

```

- [ ] **Step 7: Create context template**

```markdown
---
type: context
created: {{date}}
project:
source: human
---

# {{title}} — Working Context

## What is this project?


## Current state


## Key decisions made


## What I'm exploring


## How I like to work on this

```

- [ ] **Step 8: Commit all templates**

```bash
git add skills/obsidian-brain/templates/
git commit -m "feat(obsidian-brain): add vault templates for all content types"
```

---

### Task 3: Zone Enforcement — safe-write.sh

**Files:**
- Create: `skills/obsidian-brain/scripts/safe-write.sh`
- Create: `tests/obsidian-brain/test_safe_write.sh`

- [ ] **Step 1: Write the zone boundary test**

```bash
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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
chmod +x tests/obsidian-brain/test_safe_write.sh
./tests/obsidian-brain/test_safe_write.sh
```

Expected: FAIL — `safe-write.sh` doesn't exist yet.

- [ ] **Step 3: Write safe-write.sh**

```bash
#!/bin/bash
# Zone-enforced write: only allows writing under $VAULT_ROOT/ops/.
# Resolves paths via realpath to prevent traversal and symlink escapes.
#
# Usage: ./safe-write.sh <vault-root> <relative-path> <content>
# Example: ./safe-write.sh ~/second-brain ops/drafts/idea.md "My thought"
#
# Exit codes:
#   0 — success
#   1 — zone violation (path outside ops/)

set -euo pipefail

VAULT_ROOT="$1"
REL_PATH="$2"
CONTENT="$3"

# Resolve vault root to canonical path
VAULT_ROOT="$(cd "$VAULT_ROOT" && pwd -P)"
OPS_ROOT="$VAULT_ROOT/ops"

# Build target path and ensure parent directory exists
TARGET="$VAULT_ROOT/$REL_PATH"
TARGET_DIR="$(dirname "$TARGET")"
mkdir -p "$TARGET_DIR"

# Resolve to canonical absolute path (follows symlinks)
CANONICAL="$(cd "$TARGET_DIR" && pwd -P)/$(basename "$TARGET")"

# Zone check: canonical path must start with ops root
if [[ "$CANONICAL" != "$OPS_ROOT"* ]]; then
  echo "ERROR: Zone violation — write blocked." >&2
  echo "  Target:  $REL_PATH" >&2
  echo "  Resolved: $CANONICAL" >&2
  echo "  Allowed:  $OPS_ROOT/*" >&2
  exit 1
fi

# Write content
printf '%s' "$CONTENT" > "$CANONICAL"
echo "Written: $REL_PATH"
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
chmod +x skills/obsidian-brain/scripts/safe-write.sh
./tests/obsidian-brain/test_safe_write.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/obsidian-brain/scripts/safe-write.sh tests/obsidian-brain/test_safe_write.sh
git commit -m "feat(obsidian-brain): add zone-enforced safe-write with boundary tests"
```

---

### Task 4: Wikilink Query Script

**Files:**
- Create: `skills/obsidian-brain/scripts/query-links.sh`
- Create: `tests/obsidian-brain/test_query_links.sh`

- [ ] **Step 1: Write the query-links test**

```bash
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
HUMAN=$("$QUERY_LINKS" "$TEST_VAULT" outgoing "notes/idea-a.md" --human-only)
assert_contains "human-only includes idea-b" "idea-b" "$HUMAN"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
chmod +x tests/obsidian-brain/test_query_links.sh
./tests/obsidian-brain/test_query_links.sh
```

Expected: FAIL — `query-links.sh` doesn't exist yet.

- [ ] **Step 3: Write query-links.sh (ripgrep-based, no obsidian-cli dependency)**

```bash
#!/bin/bash
# Query wikilinks in an Obsidian vault.
# Uses ripgrep to parse [[wikilinks]] from Markdown files.
# Falls back from obsidian-cli if available, otherwise pure ripgrep.
#
# Usage:
#   ./query-links.sh <vault-root> outgoing <file-path>           # links FROM a file
#   ./query-links.sh <vault-root> backlinks <link-target>         # files linking TO a target
#   ./query-links.sh <vault-root> outgoing <file-path> --human-only  # skip ops/
#
# Output: one link/file per line

set -euo pipefail

VAULT_ROOT="$1"
MODE="$2"
TARGET="$3"
HUMAN_ONLY=false
if [ "${4:-}" = "--human-only" ]; then
  HUMAN_ONLY=true
fi

case "$MODE" in
  outgoing)
    # Extract [[wikilinks]] from a specific file
    FILE="$VAULT_ROOT/$TARGET"
    if [ ! -f "$FILE" ]; then
      echo "ERROR: File not found: $TARGET" >&2
      exit 1
    fi
    # Extract link targets, one per line, deduplicated
    grep -oP '\[\[([^\]|]+)' "$FILE" | sed 's/\[\[//' | sort -u
    ;;

  backlinks)
    # Find all files that contain [[TARGET]]
    SEARCH_PATH="$VAULT_ROOT"
    if $HUMAN_ONLY; then
      # Search only human zone directories
      SEARCH_PATH=""
      for dir in notes projects tasks resources contexts daily people; do
        if [ -d "$VAULT_ROOT/$dir" ]; then
          SEARCH_PATH="$SEARCH_PATH $VAULT_ROOT/$dir"
        fi
      done
    fi

    if [ -z "$SEARCH_PATH" ]; then
      exit 0
    fi

    # shellcheck disable=SC2086
    rg -l "\[\[$TARGET(\|[^\]]*)?]]" $SEARCH_PATH --glob '*.md' 2>/dev/null \
      | sed "s|^$VAULT_ROOT/||" \
      | sort
    ;;

  *)
    echo "Usage: $0 <vault-root> outgoing|backlinks <target> [--human-only]" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
chmod +x skills/obsidian-brain/scripts/query-links.sh
./tests/obsidian-brain/test_query_links.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/obsidian-brain/scripts/query-links.sh tests/obsidian-brain/test_query_links.sh
git commit -m "feat(obsidian-brain): add wikilink query script with ripgrep fallback"
```

---

### Task 5: Capture Script

**Files:**
- Create: `skills/obsidian-brain/scripts/capture.sh`
- Create: `tests/obsidian-brain/test_capture.sh`

- [ ] **Step 1: Write capture test**

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
chmod +x tests/obsidian-brain/test_capture.sh
./tests/obsidian-brain/test_capture.sh
```

Expected: FAIL — `capture.sh` doesn't exist yet.

- [ ] **Step 3: Write capture.sh**

```bash
#!/bin/bash
# Capture user input as a draft note in the AI zone.
# Uses safe-write.sh for zone enforcement.
#
# Usage:
#   ./capture.sh <vault-root> "text to capture"
#   ./capture.sh <vault-root> "text" --tags "tag1,tag2"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAFE_WRITE="$SCRIPT_DIR/safe-write.sh"

VAULT_ROOT="$1"
shift
TEXT="$1"
shift

# Parse optional arguments
TAGS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --tags) TAGS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Generate filename from timestamp
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
FILENAME="ops/drafts/capture-${TIMESTAMP}.md"

# Build tags line
TAGS_LINE="tags: []"
if [ -n "$TAGS" ]; then
  # Convert comma-separated to YAML array
  TAGS_YAML=$(echo "$TAGS" | sed 's/,/, /g')
  TAGS_LINE="tags: [$TAGS_YAML]"
fi

# Build content with frontmatter
CONTENT="---
type: capture
created: $(date +%Y-%m-%d)
${TAGS_LINE}
source: ai
---

$TEXT
"

# Write via safe-write (zone enforcement)
"$SAFE_WRITE" "$VAULT_ROOT" "$FILENAME" "$CONTENT"
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
chmod +x skills/obsidian-brain/scripts/capture.sh
./tests/obsidian-brain/test_capture.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/obsidian-brain/scripts/capture.sh tests/obsidian-brain/test_capture.sh
git commit -m "feat(obsidian-brain): add capture script for drafting user input"
```

---

### Task 6: Reference Documents

**Files:**
- Create: `skills/obsidian-brain/references/vault-schema.md`
- Create: `skills/obsidian-brain/references/command-guide.md`

- [ ] **Step 1: Write vault-schema.md**

```markdown
# Vault Schema

## Dual-Zone Architecture

The vault has two zones with different AI permission levels:

### Human Zone (AI: read-only)

| Directory | Content |
|-----------|---------|
| `notes/` | Ideas, reflections, learning notes |
| `projects/` | Project descriptions, goals, progress |
| `tasks/` | To-do items |
| `resources/` | Collected resources, articles, videos |
| `contexts/` | Deep context files (project/personal workflow) |
| `daily/` | Daily notes |
| `people/` | People notes (collaborators, mentors) |

**Rule:** AI must NEVER create or modify files in these directories. Output analysis to the terminal only.

### AI Zone (AI: read-write)

| Directory | Content |
|-----------|---------|
| `ops/drafts/` | Captured user input, rough drafts |
| `ops/meetings/` | AI-transcribed meeting notes |
| `ops/research/` | AI-organized research materials |
| `ops/<project>/` | Per-project troubleshooting, decisions |

**Rule:** All AI writes MUST go through `scripts/safe-write.sh` which enforces path validation.

## Frontmatter Convention

Every file uses YAML frontmatter:

```yaml
---
type: note | task | project | resource | meeting-transcript | debug-log | capture | context | daily
created: YYYY-MM-DD
tags: [tag1, tag2]
source: human | ai
---
```

- `source: human` — written by the user. Used in human zone.
- `source: ai` — generated by AI. Used in AI zone (ops/).

## Wikilink Strategy

Link to **specific entities**, not broad categories:

- Good: `[[渊博]]`, `[[obsidian-brain]]`, `[[meeting-yuanbo-0329]]`
- Bad: `[[podcast]]`, `[[fitness]]`, `[[work]]`

Cross-zone links are encouraged: a human note can link to `[[meeting-yuanbo-0329]]` in ops/, and vice versa.

## Reflection Command Scope

Reflection commands (`/challenge`, `/drift`, `/emerge`, `/trace`, `/graduate`) MUST only scan the human zone. This prevents the AI from reading its own prior outputs and mistaking them for human thinking patterns.

Project/operational commands (`/context`, `/today`, `/connect`, `/debug-log`) can read both zones.
```

- [ ] **Step 2: Write command-guide.md**

```markdown
# Command Guide

## Phase 1 Commands

### /context

**Purpose:** Load project global context for the current conversation.

**Reads:** `contexts/` + recent `daily/` (past 7 days) + relevant `ops/<project>/`

**Behavior:**
1. Find context files in `contexts/` matching the current project or topic
2. Read the 7 most recent daily notes from `daily/`
3. Follow outgoing wikilinks from context files to load related notes
4. Include relevant entries from `ops/` for operational context
5. Present a unified context summary in the terminal

**Zone:** Reads human zone + AI zone. Never writes.

### /capture

**Purpose:** Capture the user's words as a draft in the AI zone.

**Writes to:** `ops/drafts/capture-YYYY-MM-DD-HHMMSS.md`

**Usage:**
- `/capture "My thought about X"` — basic capture
- `/capture "Idea" --tags "ai,philosophy"` — with tags

**Behavior:**
1. Takes the user's text input
2. Wraps it in frontmatter (type: capture, source: ai, timestamp)
3. Writes to `ops/drafts/` via safe-write.sh
4. User can later review and move valuable content to the human zone

**Zone:** Writes AI zone only.

### /today

**Purpose:** Morning planning — aggregates tasks, recent notes, and calendar events.

**Reads:** `tasks/` (undone items) + `daily/` (past 7 days) + calendar (if available)

**Behavior:**
1. Scan `tasks/` for files where `done: false`
2. Read daily notes from the past 7 days
3. Look for items with due dates
4. Present a prioritized plan in the terminal

**Zone:** Reads human zone + AI zone. Never writes — output is terminal only.
```

- [ ] **Step 3: Commit**

```bash
git add skills/obsidian-brain/references/
git commit -m "docs(obsidian-brain): add vault schema and command guide references"
```

---

### Task 7: SKILL.md

**Files:**
- Create: `skills/obsidian-brain/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

```markdown
---
name: obsidian-brain
description: "Obsidian Second Brain — Claude Code integration for a dual-zone Obsidian vault. Invoke for: loading project context from Obsidian notes, capturing thoughts and ideas, morning planning, querying linked notes, working with your second brain. Keywords: 'obsidian', 'second brain', 'vault', 'capture thought', 'load context', 'today plan', 'my notes', '笔记', '第二大脑', '今日计划', '记录想法'. NOT for: Notion operations (use notion-lifeos), web fetching (use web-fetcher), academic papers (use scholar-inbox)."
---

# Obsidian Brain

A thinking partner skill that integrates Claude Code with your Obsidian vault.

## Setup

If the vault doesn't exist yet, initialize it:

```bash
scripts/init-vault.sh ~/second-brain
```

The vault path defaults to `~/second-brain`. Set `VAULT_ROOT` environment variable to override.

## Core Principle: Dual-Zone Architecture

The vault has two zones. **You MUST respect these boundaries:**

### Human Zone (read-only for AI)
Directories: `notes/`, `projects/`, `tasks/`, `resources/`, `contexts/`, `daily/`, `people/`

**NEVER create, modify, or delete files in these directories.** These contain the user's own thoughts and judgments. Output your analysis to the terminal only — the user decides what to record.

### AI Zone (read-write for AI)
Directory: `ops/` (and all subdirectories)

All AI writes MUST go through `scripts/safe-write.sh` which validates paths via `realpath`. Direct file writes to the vault are forbidden.

## Commands

### /context
Load project context from the vault. Read `references/command-guide.md` for details.

**Zone:** Reads both zones. Never writes.

### /capture
Capture user's words as a draft. Run `scripts/capture.sh`.

**Zone:** Writes to `ops/drafts/` only.

### /today
Morning planning. Read tasks, recent daily notes, and calendar.

**Zone:** Reads both zones. Output to terminal only — never writes.

## Wikilink Queries

Use `scripts/query-links.sh` to find connected notes:

```bash
# Find what a note links to
scripts/query-links.sh $VAULT_ROOT outgoing "notes/idea-a.md"

# Find what links to a topic
scripts/query-links.sh $VAULT_ROOT backlinks "idea-a"

# Backlinks from human zone only (for reflection commands)
scripts/query-links.sh $VAULT_ROOT backlinks "idea-a" --human-only
```

## Schema Reference

See `references/vault-schema.md` for frontmatter conventions, zone rules, and wikilink strategy.

See `references/command-guide.md` for detailed command documentation.
```

- [ ] **Step 2: Commit**

```bash
git add skills/obsidian-brain/SKILL.md
git commit -m "feat(obsidian-brain): add SKILL.md with dual-zone rules and command definitions"
```

---

### Task 8: Update Monorepo Docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Add to CHANGELOG.md**

Add under a new version entry at the top:

```markdown
## [Unreleased]

### obsidian-brain

#### Added
- New skill: Obsidian Second Brain — dual-zone vault integration with Claude Code
- Vault initialization script with git version control
- Zone-enforced safe-write script (realpath validation, path traversal protection)
- Wikilink query script (ripgrep-based, obsidian-cli fallback ready)
- Capture script for drafting user input to AI zone
- Templates for all content types (note, task, project, resource, daily, meeting-transcript, context)
- Reference docs: vault schema and command guide
- Zone boundary tests with traversal/symlink attack coverage
```

- [ ] **Step 2: Add skill to README.md skill table**

Find the skill table in README.md and add:

```markdown
| [obsidian-brain](skills/obsidian-brain/) | Obsidian Second Brain — dual-zone vault with Claude Code as thinking partner |
```

Install command: `npx skills add jiahao-shao1/sjh-skills --skill obsidian-brain`

- [ ] **Step 3: Add skill to README.zh-CN.md skill table**

Add the same entry in Chinese:

```markdown
| [obsidian-brain](skills/obsidian-brain/) | Obsidian 第二大脑 — 双区 Vault 与 Claude Code 思考伙伴集成 |
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md README.md README.zh-CN.md
git commit -m "docs: add obsidian-brain to changelog and README skill tables"
```

---

### Task 9: End-to-End Smoke Test

**Files:** None (manual verification)

- [ ] **Step 1: Initialize a test vault**

Run:
```bash
./skills/obsidian-brain/scripts/init-vault.sh /tmp/smoke-test-vault
```

Expected: Vault created with all directories, git initialized, templates copied.

- [ ] **Step 2: Test capture flow**

Run:
```bash
./skills/obsidian-brain/scripts/capture.sh /tmp/smoke-test-vault "I think AI doesn't have taste — humans need to maintain that judgment"
ls /tmp/smoke-test-vault/ops/drafts/
cat /tmp/smoke-test-vault/ops/drafts/capture-*.md
```

Expected: File exists with frontmatter (type: capture, source: ai) and user text.

- [ ] **Step 3: Create some linked notes manually**

Run:
```bash
cat > /tmp/smoke-test-vault/notes/ai-taste.md << 'EOF'
---
type: note
created: 2026-03-29
tags: [ai, philosophy]
source: human
---

# AI Has No Taste

I believe AI has no taste. See also [[meeting-yuanbo-0329]].
EOF

cat > /tmp/smoke-test-vault/ops/meetings/meeting-yuanbo-0329.md << 'EOF'
---
type: meeting-transcript
created: 2026-03-29
speakers: [嘉豪, 渊博]
source: ai
---

# Meeting 2026-03-29

Discussion about Agentic UM. Notes: [[ai-taste]]
EOF
```

- [ ] **Step 4: Test link queries**

Run:
```bash
./skills/obsidian-brain/scripts/query-links.sh /tmp/smoke-test-vault outgoing "notes/ai-taste.md"
./skills/obsidian-brain/scripts/query-links.sh /tmp/smoke-test-vault backlinks "ai-taste"
```

Expected: Outgoing shows `meeting-yuanbo-0329`. Backlinks shows both files that reference `ai-taste`.

- [ ] **Step 5: Test zone enforcement**

Run:
```bash
# This should succeed
./skills/obsidian-brain/scripts/safe-write.sh /tmp/smoke-test-vault "ops/drafts/ok.md" "valid write"

# This should fail
./skills/obsidian-brain/scripts/safe-write.sh /tmp/smoke-test-vault "notes/hack.md" "zone violation" && echo "BUG: should have failed" || echo "OK: correctly blocked"
```

Expected: First succeeds, second fails with zone violation error.

- [ ] **Step 6: Run all unit tests**

Run:
```bash
./tests/obsidian-brain/test_safe_write.sh
./tests/obsidian-brain/test_query_links.sh
./tests/obsidian-brain/test_capture.sh
```

Expected: All pass.

- [ ] **Step 7: Clean up and final commit**

Run:
```bash
rm -rf /tmp/smoke-test-vault
```

Verify all files are committed:
```bash
git status
```

If any uncommitted files, add and commit:
```bash
git add -A
git commit -m "chore(obsidian-brain): finalize phase 1"
```
