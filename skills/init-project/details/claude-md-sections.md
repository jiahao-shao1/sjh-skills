# CLAUDE.md Section-by-Section Fill Guide

In Phase 2, process each `<!-- init-project: 待填充 -->` placeholder. Per-section flow:

```
Read codebase (auto) → Generate draft (auto) → AskUserQuestion to confirm → Write to CLAUDE.md
```

User can reply "skip" to skip any section and keep the placeholder.

---

## Section: Project Overview

### Auto-exploration

```
Read: README.md, pyproject.toml, package.json, Cargo.toml, go.mod
Extract: project name, description, main dependencies
```

### AskUserQuestion

```
Here's a draft project overview:

---
{draft content}
---

Does this look accurate? Press Enter to confirm, type edits, or reply "skip" to skip.
```

### Draft Template

```markdown
**{project_name}** is a {type} that {one-line goal}.

Core approach: {technical method}.

## Workflow

1. {step 1}
2. {step 2}
3. ...
```

---

## Section: Directory Structure

### Auto-exploration

```
Run ls to see top-level directories
Read each subdirectory's README.md or __init__.py docstring
Identify: core modules, third-party deps, scripts, tests, docs
```

### AskUserQuestion

```
Here's a draft directory structure:

---
{draft: modules listed by directory and function}
---

Anything missing or to adjust? Press Enter to confirm / type edits / "skip" to skip.
```

### Draft Template

Organize by category:

```markdown
### Core Modules

#### `module_a/` — Description
- Submodule details
- See: `module_a/README.md`

### Third-Party Dependencies

#### `third_party/xxx`
- Purpose

### Other Directories

#### `scripts/` — Run scripts
#### `tests/` — Unit tests
#### `docs/` — Documentation
```

---

## Section: Dev Workflow

### Auto-exploration

```
Detect: .github/workflows/, Makefile, Justfile, scripts/, Dockerfile
Detect: CI/CD presence, pre-commit hooks
```

### AskUserQuestion

```
Detected the following dev tools: {tool list}

CLAUDE.md already includes the default brainstorming→plans→dev→verify flow.
Does your project have additional workflow stages? (e.g., deployment, release, data processing)

Press Enter to skip / type additions.
```

---

## Section: Dev Guide

### Auto-exploration

```
Detect: venv/conda environment, .env files, Dockerfile, Makefile
Detect: test framework (pytest/jest/go test), lint tools (ruff/eslint)
Read: pyproject.toml or package.json scripts section
```

### AskUserQuestion

```
Here's a draft dev guide:

---
### Environment Setup

{detected setup steps}

### Unit Tests

{detected test commands}

### {other detected dev tools}
---

Anything to add or change?
```

---

## Section: Always Do (Project-Specific Items)

### Auto-exploration

```
Read: existing rule files under .claude/rules/
Detect: lint config (pyproject.toml [tool.ruff], .eslintrc)
Scan: multi-module configs that need consistency
```

### AskUserQuestion

```
CLAUDE.md already includes 3 generic Always Do rules:
- Read related files before modifying code
- Run related unit tests after modifications
- Follow the same module's code style

What **cross-module consistency requirements** does your project have? For example:
- Certain parameters must stay in sync across modules
- API calls must include retry logic
- Specific framework conventions must be followed

Press Enter to skip / type additional items.
```

---

## Section: Ask First

### Auto-exploration

```
Scan: core interface definitions (abstract classes, protocols, signatures)
Scan: config files (yaml, toml, json)
Scan: third_party/ dependencies
```

### AskUserQuestion

```
Already includes 1 generic Ask First rule:
- Adding new Python dependencies

Which **files or directories require confirmation before modifying** in your project? For example:
- Core config files
- Public interfaces/protocol definitions
- Database schemas
- CI/CD configuration

Press Enter to skip / type additional items.
```

---

## Section: Never Do

### Auto-exploration

```
Detect: third_party/ directory
Detect: .env, credentials, and other sensitive files
Scan: immutable interface contracts
```

### AskUserQuestion

```
Already includes 2 generic Never Do rules:
- Hardcode API keys, paths, or endpoints
- Directly modify code under third_party/

What **absolute don't-touch conventions** does your project have? For example:
- Immutable function signatures
- External config that must not be guessed
- Legacy code that must not be touched

Press Enter to skip / type additional items.
```

---

## Section: Progressive References

### Auto-exploration

```
Scan: docs under docs/
List: agents in .claude/agents/
List: skills in .agents/skills/
```

### AskUserQuestion

```
Based on codebase scan, here's a generated reference table:

| Task | Reference file |
|------|---------------|
{auto-generated mappings}

Any additional task→reference file mappings to add?
```

---

## After Completion

Once all sections are processed, output a summary:

```
## CLAUDE.md Fill Complete

| Section | Status |
|---------|--------|
| Project overview | ✓ Filled |
| Directory structure | ✓ Filled |
| Dev workflow | ⊘ Skipped |
| ...     | ... |

Next step: review CLAUDE.md content, then git add + commit.
```
