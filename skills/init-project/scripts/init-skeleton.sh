#!/bin/bash
# init-skeleton.sh — Generate Claude Code configuration skeleton for new projects
# Usage: bash init-skeleton.sh [project-root]
# Idempotent: existing files are never overwritten

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

CREATED=()
SKIPPED=()

# Helper: create file (no overwrite)
create_file() {
    local filepath="$1"
    local content="$2"
    mkdir -p "$(dirname "$filepath")"
    if [ -f "$filepath" ]; then
        SKIPPED+=("$filepath")
    else
        echo "$content" > "$filepath"
        CREATED+=("$filepath")
    fi
}

# Helper: ensure directory exists
ensure_dir() {
    local dirpath="$1"
    mkdir -p "$dirpath"
}

# Infer project name from directory
PROJECT_NAME=$(basename "$(pwd)")

# ============================================================
# 1. Directory structure
# ============================================================
ensure_dir ".claude/rules"
ensure_dir "docs/knowledge"
ensure_dir ".claude/hooks"
ensure_dir ".claude/agents"
ensure_dir ".claude/worktrees"
ensure_dir ".agents/skills"

# ============================================================
# 2. General-purpose hooks
# ============================================================
create_file ".claude/hooks/auto-format-python.sh" '#!/bin/bash
# Claude Code PostToolUse hook: auto ruff format after editing Python files
# Gets edited file path via $TOOL_INPUT environment variable

FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('"'"'file_path'"'"', '"'"''"'"'))
except:
    print('"'"''"'"')
" 2>/dev/null)

# Only process .py files, exclude third_party/
if [[ "$FILE_PATH" == *.py ]] && [[ "$FILE_PATH" != */third_party/* ]]; then
    # Run ruff format (quiet, only output on issues)
    ruff format "$FILE_PATH" --quiet 2>/dev/null

    # Run ruff check --fix (auto-fix import sorting etc.)
    OUTPUT=$(ruff check --fix "$FILE_PATH" 2>/dev/null)
    if [ -n "$OUTPUT" ]; then
        echo "$OUTPUT" | head -10
    fi
fi'

chmod +x ".claude/hooks/auto-format-python.sh" 2>/dev/null || true

create_file ".claude/hooks/guard-critical-edit.sh" '#!/bin/bash
# Claude Code PostToolUse hook: warn when editing critical directories
# Customize CRITICAL_DIRS to match your project'"'"'s sensitive areas

FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('"'"'file_path'"'"', '"'"''"'"'))
except:
    print('"'"''"'"')
" 2>/dev/null)

# Define critical directories — edit this list per project
CRITICAL_DIRS=("core/" "interfaces/")

for dir in "${CRITICAL_DIRS[@]}"; do
    if [[ "$FILE_PATH" == *"$dir"* ]]; then
        echo "⚠️ Editing critical directory: $dir — check .claude/rules/ for constraints"
        break
    fi
done'

chmod +x ".claude/hooks/guard-critical-edit.sh" 2>/dev/null || true

# ============================================================
# 3. General-purpose agent definitions
# ============================================================
create_file ".claude/agents/code-verifier.md" '---
name: code-verifier
description: Code quality check. Proactively runs ruff lint/format and pytest after code changes, before commit. Auto-fixes formatting issues and reports results.
model: haiku
tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Code Verifier

## When to Use

**Proactive**: after user completes code changes, before commit.

## Check Flow

Execute the following steps in order:

### 1. Identify Changed Files

```bash
git diff --name-only HEAD
git diff --name-only --cached
git ls-files --others --exclude-standard
```

Only check `.py` files, skip `third_party/`, `outputs/`, `__pycache__/`.

### 2. Ruff Lint + Format

```bash
ruff check --fix .
ruff format .
```

If ruff is unavailable, fall back to reporting an install prompt.

### 3. Run Tests

```bash
pytest tests/ -v --tb=short -q 2>&1 | tail -30
```

### 4. Report Results

```
## Check Results

| Check | Status | Notes |
|-------|--------|-------|
| Ruff Lint | PASS/FAIL/SKIP | Fixed N issues |
| Ruff Format | PASS/FAIL/SKIP | Formatted N files |
| Tests | PASS/FAIL/SKIP | N passed, M failed |
```

## Notes

- Do not modify code under `third_party/`
- On test failure, report the cause — do not auto-fix
- If ruff is not installed, skip lint/format steps and prompt to install'

create_file ".claude/agents/planner.md" '---
name: planner
description: Codebase researcher. Use during brainstorming or writing-plans phases when deep understanding of code structure is needed. Researches code and outputs findings and suggestions.
model: opus
tools:
  - Read
  - Grep
  - Glob
---

# Planner (Codebase Researcher)

## Role

This agent assists the `/brainstorming` and `/writing-plans` workflows by systematically researching the codebase and outputting findings for the parent workflow.

**Not a standalone planner** — implementation plans are handled by the `/writing-plans` skill.

## When to Use

- `/brainstorming` "Explore project context" phase needs deep code research
- `/writing-plans` needs to confirm code structure or find reusable patterns
- Tasks involving 3+ files need upfront code relationship mapping

**Do not use for**: single-file changes, tasks where code structure is already clear.

## How It Works

### 1. Receive Research Question

Get a specific research question from brainstorming or writing-plans.

### 2. Systematic Search

Research by directory focus, using Glob, Grep, Read tools.

### 3. Output Findings

```markdown
## Research Findings

### Relevant Files
- `file_a.py:L42` — [what it does, why it matters]

### Existing Patterns
- [reusable patterns]

### Suggestions
- [suggestions]

### Risks
- [constraints to watch out for]
```

## Notes

- Read-only operations, no code modifications
- Always cite specific file paths and line numbers'

# ============================================================
# 4. Universal rule files
# ============================================================
create_file ".claude/rules/testing.md" '# Testing Rules

## Test Structure

- Follow Arrange-Act-Assert pattern
- Naming: `test_<what>_<condition>_<expected>()`
- Each test function includes a brief docstring explaining its purpose

## Running Tests

```bash
# Run all tests
pytest tests/ -v

# Skip slow tests
pytest tests/ -v -m "not slow"
```

## Pytest Markers

- `@pytest.mark.slow` — tests over 10 seconds
- `@pytest.mark.skipif()` — conditional skip (GPU, network, etc.)
- `@pytest.mark.parametrize()` — parameterized tests'

create_file ".claude/rules/knowledge-writing.md" '# Knowledge Writing Guide

This rule applies to all experience records under `docs/knowledge/`.

## When to Write

When a non-trivial problem is solved during a session (debugging, workaround, design trade-off, etc.), **write immediately** — do not wait until the session ends.

## File Naming

By domain topic: `api-integration.md`, `deployment.md`. Create new files for new domains.

## Entry Format

```markdown
## YYYY-MM-DD: Brief Title

**Problem**: what happened
**Solution**: how it was resolved
**Lesson**: what to watch for next time
**Files**: code files involved
**Commit**: related git commit hash
```

## What to Write

- Bugs and root causes discovered during debugging
- Non-obvious workarounds or API behaviors
- Design decisions and their trade-offs
- Parameter tuning experiences

## What NOT to Write

- Pure code change records (tracked by git log)
- Content already in documentation
- Temporary exploratory attempts with no conclusions

## Capture Path

```
discovered in session → docs/knowledge/ (hot experience)
                                ↓ validated multiple times
                         .claude/rules/ (hard rules)
```'

# ============================================================
# 5. Scripts directory structure
# ============================================================
ensure_dir "scripts"

# ============================================================
# 6. Settings.json (project-level)
# ============================================================
create_file ".claude/settings.json" '{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/guard-critical-edit.sh"
          },
          {
            "type": "command",
            "command": "bash .claude/hooks/auto-format-python.sh"
          }
        ]
      }
    ]
  }
}'

# ============================================================
# 7. CLAUDE.md skeleton
# ============================================================
create_file "CLAUDE.md" "# ${PROJECT_NAME} Project Guide

## Project Overview
<!-- init-project: placeholder -->

## Directory Structure
<!-- init-project: placeholder -->

## Dev Workflow

This project uses a phased workflow:

\`\`\`
/brainstorming  →  /writing-plans  →  /subagent-driven-development  →  code-verifier
  explore ideas       make a plan          execute the plan             quality check
\`\`\`

### Phase Guide

| Scenario | Starting phase |
|----------|---------------|
| New feature / architecture change / research idea | Start from \`/brainstorming\` |
| Requirements already clear, need implementation plan | Start from \`/writing-plans\` |
| Small change (single file, bug fix) | Direct edit + \`code-verifier\` |

<!-- init-project: add project-specific workflow stages here if needed -->

## Models / Key Dependencies
<!-- init-project: placeholder -->

## Dev Guide
<!-- init-project: placeholder -->

## Experience Capture

When a non-trivial problem is solved during a session (debugging, workaround, design trade-off, etc.), **immediately** write the experience to the corresponding domain file in \`docs/knowledge/\` — don't wait until the session ends.

### Writing Guidelines

- **File naming**: by domain topic, e.g., \`api-integration.md\`, \`deployment.md\`. Create new files for new domains.
- **Entry format**:

\`\`\`markdown
## YYYY-MM-DD: Brief Title

**Problem**: what happened
**Solution**: how it was resolved
**Lesson**: what to watch for next time
**Files**: code files involved
**Commit**: related git commit hash
\`\`\`

### What to Write

- Bugs and root causes discovered during debugging
- Non-obvious workarounds or API behaviors
- Design decisions and their trade-offs
- Parameter tuning experiences

### What Not to Write

- Pure code change records (tracked by git log)
- Content already in documentation
- Temporary exploratory attempts (no conclusions)

### Capture Path

\`\`\`
discovered in session → docs/knowledge/ (hot experience)
                                ↓ validated multiple times
                         .claude/rules/ (hard rules)
\`\`\`

## Context Management

### Compact Instructions

When context is compressed (/compact or auto-triggered), the following **must be preserved**:
- Current task goal and acceptance criteria
- Architecture decisions made and their rationale
- Key constraints from behavior boundaries
- Current worktree branch name and work progress
- Unresolved blocking issues

### HANDOFF Mode

When a long session is ending or context is near its limit, proactively write a \`HANDOFF.md\` to the project root:
\`\`\`markdown
## Current Progress
## What Was Tried (worked / didn't work)
## Next Steps
## Key Decisions and Constraints
\`\`\`
The next session only needs to read \`HANDOFF.md\` to continue. Delete the file when done.

### Context Hygiene

- Task switch → \`/clear\`
- Same task, new phase → \`/compact\`
- Long command output: pipe through \`| head -30\` to avoid context pollution

## Behavior Boundaries

### Always Do

- Read related files before modifying code to understand context
- Run related unit tests after modifying code
- Follow the existing code style and naming conventions of the same module
<!-- init-project: examples below, modify per project needs -->
<!-- - Ensure config consistency across cross-module changes -->
<!-- - Include timeout protection and retry logic for API calls -->

### Ask First

- Adding new Python dependencies
<!-- init-project: examples below, modify per project needs -->
<!-- - Modifying core interfaces or config structure -->
<!-- - Running GPU tests (check availability first) -->

### Never Do

- Hardcode API keys, paths, or endpoints
- Directly modify code under third_party/
<!-- init-project: examples below, modify per project needs -->
<!-- - Modify immutable interface signatures -->
<!-- - Guess cluster configuration or hardware topology -->

## Knowledge Quick Reference

When encountering the following scenarios, **read the corresponding knowledge file first** before taking action:

| Scenario | File |
|----------|------|
<!-- init-project: placeholder — auto-generate from docs/knowledge/ contents -->

## Progressive References
<!-- init-project: placeholder -->
"

# ============================================================
# Output summary
# ============================================================
echo ""
echo "=========================================="
echo "  init-skeleton complete"
echo "=========================================="
echo ""

if [ ${#CREATED[@]} -gt 0 ]; then
    echo "✓ Created ${#CREATED[@]} files:"
    for f in "${CREATED[@]}"; do
        echo "  + $f"
    done
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo ""
    echo "⊘ Skipped ${#SKIPPED[@]} existing files:"
    for f in "${SKIPPED[@]}"; do
        echo "  - $f"
    done
fi

echo ""
echo "Next: run Phase 2 to interactively fill CLAUDE.md"
