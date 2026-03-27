#!/bin/bash
# init-research-profile.sh — Overlay research profile
# Usage: bash init-research-profile.sh [project-root]
# Run after init-skeleton.sh to add research-project-specific structure

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

CREATED=()
SKIPPED=()

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

ensure_dir() {
    mkdir -p "$1"
}

# ============================================================
# 1. Report directories
# ============================================================
ensure_dir "docs/reports/weekly"
ensure_dir "docs/reports/worktree"
ensure_dir "docs/plans"

# ============================================================
# 2. Experiment registry
# ============================================================
create_file ".claude/knowledge/experiments.md" '# Experiment Registry

Track all experiment configurations, paths, and key results.

## Entry Format

```markdown
## Experiment Name

- **Date**: YYYY-MM-DD ~ YYYY-MM-DD
- **Config**: Brief config summary
- **Paths**:
  - Cluster: /path/on/cluster
  - OSS: oss://bucket/path
  - Local: outputs/path
- **Key Results**:
  - Metric 1: value
  - Metric 2: value
- **Conclusion**: One-line summary
```

---

<!-- Append experiment entries below -->'

# ============================================================
# 3. Domain expert agent scaffold
# ============================================================
create_file ".claude/agents/domain-expert.md" '---
name: domain-expert
description: <!-- Fill in: domain expertise description, e.g. "XX framework integration and debugging expert" -->
model: opus
tools:
  - Read
  - Grep
  - Glob
---

# Domain Expert

## Role

<!-- Fill in: what is this agent'"'"'s area of expertise -->

## When to Use

<!-- Fill in: what scenarios should trigger this agent -->

## How It Works

### 1. Receive Question

Get domain-related technical questions from the parent workflow.

### 2. Research Code

Focus directories and files:
<!-- Fill in: list directories this agent should focus on -->

### 3. Output Suggestions

Output format follows the planner agent standard format.

## Domain Knowledge

<!-- Fill in: key domain constraints, interface contracts, historical lessons -->'

# ============================================================
# 4. Append research-related content to CLAUDE.md
# ============================================================
if [ -f "CLAUDE.md" ]; then
    # Check if research profile marker already exists
    if ! grep -q "<!-- research-profile -->" "CLAUDE.md" 2>/dev/null; then
        cat >> "CLAUDE.md" << 'RESEARCH_EOF'

<!-- research-profile -->

## Extended Configuration

See `.claude/agents/`, `.claude/skills/`, `.claude/rules/`, `.claude/knowledge/` for specialized guidance.

### Agents

| Agent | Purpose | Model | Trigger |
|-------|---------|-------|---------|
| `planner` | Codebase research | opus | brainstorming/writing-plans phases |
| `code-verifier` | ruff + pytest | haiku | After code changes, before commit |
| `domain-expert` | Domain expertise | opus | When touching core domain code |

### Knowledge (Experience Capture)

| File | Content |
|------|---------|
| `experiments.md` | **Experiment registry**: all experiment configs, paths, key results |
RESEARCH_EOF
        CREATED+=("CLAUDE.md (appended research profile)")
    else
        SKIPPED+=("CLAUDE.md (research profile already exists)")
    fi
fi

# ============================================================
# Output summary
# ============================================================
echo ""
echo "=========================================="
echo "  research profile overlay complete"
echo "=========================================="
echo ""

if [ ${#CREATED[@]} -gt 0 ]; then
    echo "✓ Created/modified ${#CREATED[@]} files:"
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
