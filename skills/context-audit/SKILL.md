---
name: context-audit
description: "Audit project context management (CLAUDE.md, rules, knowledge) for progressive disclosure compliance. Checks that all knowledge files are reachable from rules, detects stale references, orphaned files, and CLAUDE.md index leakage. Triggers: 'audit context', 'check context', 'context hygiene', 'context audit', '检查 context', '审计上下文', 'knowledge 覆盖检查'. NOT for: code review, rule content correctness, or knowledge content quality."
user_invocable: true
---

# Context Audit

Audits the project's three-layer context management system (CLAUDE.md / rules / knowledge) against the **progressive disclosure** architecture:

```
CLAUDE.md (always loaded) — describes architecture, no detailed index
  └─ Rules (.claude/rules/) (always loaded) — inline `> 详见` refs to knowledge
       └─ Knowledge (docs/knowledge/) — on-demand deep experience
```

## When to Use

- After adding new knowledge files — verify they're indexed from a rule
- After refactoring rules — verify no references broke
- Periodic hygiene check — catch drift over time
- After onboarding a new domain — verify the new rule covers its knowledge files

## Execution

### Phase 1: Discovery

Scan the project to find all context files:

```bash
# Knowledge files
find docs/knowledge/ -name "*.md" -type f 2>/dev/null | sort

# Rule files
find .claude/rules/ -name "*.md" -type f 2>/dev/null | sort

# CLAUDE.md
ls CLAUDE.md 2>/dev/null
```

If `docs/knowledge/` or `.claude/rules/` doesn't exist, report and skip the corresponding checks.

### Phase 2: Cross-Reference Audit

For each knowledge file found in Phase 1:

1. **Grep rule files first** for references to that knowledge file (match `docs/knowledge/<filename>` or bare `<filename>`)
2. **If not found in rules, grep knowledge index files** (`docs/knowledge/*-index.md` or files whose name ends with `-index.md`). An index file that is itself rule-referenced transitively covers the leaves it lists.
3. Record which rule(s) and/or index reference it
4. Mark files as:
   - **Directly covered**: referenced from at least one rule
   - **Indirectly covered**: referenced from a knowledge index that is itself rule-covered (legal two-tier pattern)
   - **Orphaned**: not reachable from any rule, even transitively (action needed)
   - **Deprecated**: contains `[DEPRECATED]` marker (info only, no action needed)

For each reference found in rule/AGENTS/CLAUDE files:

1. **Verify target exists**: check the referenced knowledge file actually exists on disk
2. **Skip placeholder examples**: refs that look like syntax illustrations (e.g., `docs/knowledge/xxx.md`, `<filename>.md`, `foo.md`) inside example/format sections are not real refs. Detect by:
   - filename matches `xxx`, `foo`, `bar`, `<.*>`, or
   - the surrounding line uses template-like wording (e.g., 内联 `详见 docs/knowledge/xxx.md` 引用)
3. Mark real references as:
   - **Valid**: target file exists
   - **Stale**: target file doesn't exist (action needed)

### Phase 3: CLAUDE.md Compliance

Check that CLAUDE.md follows the architecture principle — it should describe the progressive disclosure system, NOT duplicate the detailed index.

1. **Count direct knowledge references**: grep CLAUDE.md for `docs/knowledge/` patterns
2. **Check architecture description**: look for keywords indicating the architecture is described (e.g., "渐进式披露", "progressive disclosure", "rules", "详见")
3. Flag if CLAUDE.md contains more than **3 direct knowledge file references** (suggests index leakage — the detailed index belongs in rules, not CLAUDE.md)

Exception: a summary table mapping rule files to knowledge domains is acceptable (it's architecture description, not a detailed index).

### Phase 4: Report

Output a structured report:

```
==========================================
  CONTEXT AUDIT REPORT
  <project-name> | YYYY-MM-DD
==========================================

## Coverage Summary

Knowledge files: N total
  - M directly covered (cited from a rule)
  - K indirectly covered (cited from a rule-linked knowledge index)
  - X orphaned
  - Y deprecated
Rule files: N total
Stale references: N (placeholders excluded)

## Orphaned Knowledge Files (not indexed from any rule)

| File | Suggested Rule | Reason |
|------|---------------|--------|
| docs/knowledge/foo.md | rl-training.md | topic overlaps with RL training |

## Stale References (pointing to non-existent files)

| Rule File | Line | Reference | Status |
|-----------|------|-----------|--------|
| .claude/rules/bar.md | 42 | docs/knowledge/removed.md | file not found |

## CLAUDE.md Compliance

- Architecture description: [FOUND / MISSING]
- Direct knowledge refs: N (threshold: <=3)
- Status: [PASS / WARN — index leakage detected]

## Coverage Map

| Rule File | Knowledge Files Referenced |
|-----------|--------------------------|
| rl-training.md | reward, config, verl-integration, ... |
| cluster-ops.md | container-unify, mutagen-sync, ... |

## Deprecated Files

| File | Deprecation Notice |
|------|--------------------|
| docs/knowledge/experiments.md | migrated to experiment-registry |

==========================================
```

### Phase 5: Fix Suggestions (optional)

If orphaned files are found, suggest concrete edits:

- Identify the most relevant rule file based on topic overlap
- Suggest the specific section where a `> 详见` reference should be added
- Provide the exact line to add (copy-pasteable)

**Do NOT auto-apply fixes.** Present suggestions and let the user decide.

### Phase 6: Rule Slimming Methodology (when rules are bloated)

If audit reveals rules are too large (always-loaded context bloat), recommend the **three-tier split** approach (validated on agentic_umm 2026-04-25, reduced 8 rules / ~830 lines → 6 rules / 469 lines, -43%):

**Tier 1 — Whole-file migration (highest ROI)**

Identify rules that are pure how-to / reference manuals with no hard constraints. Move the entire file to `docs/knowledge/`, update the index pointer in CLAUDE.md/AGENTS.md to point at knowledge instead.

Signals: rule reads like a tutorial, no "必须 / 不要 / 硬约束" language, pure command recipes or organization conventions.

**Tier 2 — In-file split (medium ROI)**

For mixed rules, split into:
- **Keep in rule**: hard constraints (project-specific invariants where violation causes incidents — data corruption, eval mismatch, lost work)
- **Move to knowledge**: how-to procedures, detailed diagnostic stories, reference tables, command templates

Create a sibling knowledge file (e.g., `<rule-name>-howto.md`, `<rule-name>-details.md`) and replace the moved sections with a one-line `> 详见 docs/knowledge/<...>.md`.

**Tier 3 — Index extraction (low-medium ROI)**

If a rule contains a long flat table indexing many knowledge files (e.g., 20+ rows like "数据/轨迹/评估"), extract that table into a dedicated `docs/knowledge/<topic>-index.md`. The rule keeps a single sentence pointing to the index. The index file is itself rule-referenced, so leaves remain reachable (legal two-tier pattern recognized in Phase 2).

**Decision rules:**

- Hard constraint → rule (always-loaded)
- How-to / reference / diagnostic detail → knowledge (on-demand)
- Long flat index of knowledge files → dedicated index knowledge file
- Cross-tool agents (e.g., Codex) that don't load `.claude/rules/` → may need direct knowledge refs in AGENTS.md; this is acceptable cross-tool-compat redundancy, not a violation

### Phase 7: Change Impact Matrix (forward audit, opt-in)

Phases 1-6 are **reverse** audits — start from existing files, check structural compliance. Phase 7 is the **forward** audit — start from recent changes, check whether the knowledge they introduced actually landed in every place it should.

This phase is opt-in: trigger it when the user supplies a change summary, or when the audit follows a sizable session (feature shipped, refactor done, bug fixed). Skip silently if there's nothing to forward-audit.

**Inputs**

Collect "new facts" introduced by recent work. Sources, in order of preference:
1. User-supplied change summary (most reliable)
2. `git log --since="<session start>" --oneline` + `git diff` of touched files
3. Recent conversation context (least reliable — confirm with user before acting on it)

A "new fact" is anything that, if the next session reads stale docs, would mislead the agent. Examples: dependency swap (SQLite → PostgreSQL), new env var, renamed CLI flag, deprecated module, new invariant ("never call X directly"), new directory convention.

**Mapping rules — fact type → expected locations**

| Fact type | Should appear in |
|-----------|-----------------|
| Tech stack swap (DB, framework, runtime) | CLAUDE.md tech section + relevant rule + setup docs/README |
| New env var / config key | runbook + CLAUDE.md (if always-needed) + .env.example |
| New hard constraint ("never X") | a rule (always-loaded), not knowledge |
| New how-to / command recipe | knowledge file + index reference from rule |
| Deprecated feature/file | `[DEPRECATED]` marker + rule reference removed + replacement noted |
| Renamed module/function | grep-replace across all docs + CLAUDE.md if mentioned |
| New directory or file convention | a rule + CLAUDE.md repository structure section |

**Procedure**

For each new fact:
1. Determine fact type from the table above
2. Enumerate expected locations
3. For each expected location, grep for evidence the fact landed:
   - ✅ **Updated**: location contains the new fact
   - ❌ **Missing**: location exists but still describes the old state, or the fact is absent entirely
   - ⚠️ **Conflict**: location partially updated — old and new state coexist (often worse than fully stale, since it confuses the reader)
4. Cross-project check: if this repo is depended on by another (monorepo sibling, paired client/server, etc.), flag whether the dependent's docs may need the same update

**Output**

Append to the Phase 4 report:

```
## Change Impact Matrix

Source: [user-supplied | git diff | conversation]
Window: <commit range or session start>

### Fact 1: <one-line description, e.g. "DB switched from SQLite to PostgreSQL">

| Expected location | Status | Evidence |
|-------------------|--------|----------|
| CLAUDE.md "Tech Stack" | ❌ Missing | line 42 still reads "SQLite" |
| docs/knowledge/db-schema.md | ⚠️ Conflict | lines 10-30 use Postgres, line 88 still has `sqlite3` import |
| .claude/rules/data-access.md | ✅ Updated | — |
| README.md install steps | ❌ Missing | step 3 still says "create sqlite db" |

Cross-project: agentic_umm-cli depends on this repo's DB schema → flag for review

### Fact 2: ...
```

**Constraints**

- Phase 7 is **still read-only** — emit the matrix, don't apply edits
- If no facts are supplied and no recent commits exist, skip silently rather than fabricate
- Conflicts (⚠️) are higher priority than misses (❌) — call them out first

## Constraints

- **Read-only** — never modify files. This is an audit tool, not an auto-fixer.
- **Project-agnostic** — works with any project that has `docs/knowledge/` and `.claude/rules/`. Does not assume specific file names.
- **Follow the user's language** — respond in whichever language the user uses.
- **Deprecated files are not failures** — files with `[DEPRECATED]` markers are expected to exist without rule references. Report them for visibility but don't flag as errors.
- **Threshold, not perfection** — the CLAUDE.md compliance check uses a threshold (<=3 direct refs). A summary table mapping rules to knowledge domains is architecture description, not index leakage.
