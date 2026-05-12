---
name: todo-worker
description: "Pick the next executable task from project-root TODO.md by priority + dependency, mark it in-progress, then start executing. Explicit invocation only — never auto-run. Triggers: 'work on todo', 'next task', 'pick a todo', '领 todo', 'todo worker', '接下来做什么', '领下一个任务'. NOT for: listing TODO contents (just read it), brainstorming what to do, interrupting active coding."
---

# Todo Worker

Pick the next executable task from project-root `TODO.md` by priority + dependency, atomically mark it `[~]` (in-progress), then start executing it.

## TODO.md Format Contract

The skill assumes this canonical task-line format:

```
- `[STATE]` [PRIORITY] [ID] (dep: ID1,ID2) Title text
```

Where:

| Field | Values | Example |
|------|--------|---------|
| `STATE` | ` ` (todo), `~` (in-progress), `x` (done), `!` (blocked) | `[ ]` |
| `PRIORITY` | `P0` (must) / `P1` (important) / `P2` (optional) | `[P0]` |
| `ID` | `T` + digits, project-unique | `[T01]` |
| `dep:` | comma-separated IDs, omitted if no deps | `(dep: T02,T03)` |

Task-line regex:

```
^- `\[(.)\]` \[(P\d)\] \[(T\d+)\](?:\s*\(dep:\s*([^)]+)\))?\s*(.+)
```

A project that doesn't already follow this format should adopt it before using the skill (or run a migration). Status markers alone are not enough — dependency-aware picking needs the full schema.

## State Machine

| Marker | Meaning |
|--------|---------|
| `[ ]` | Pending |
| `[~]` | In progress (claimed by a worker) |
| `[x]` | Done |
| `[!]` | Blocked (needs human) |

## Execution Skeleton

### 1. Read TODO.md

Read project-root `TODO.md`. Parse every task line. Extract `state`, `priority`, `id`, `deps[]`, `title`.

### 2. Pick the next task

Filter and sort:

1. `state == "[ ]"`
2. All `dep:` IDs resolve to a task with `state == "[x]"`
3. Sort by priority (`P0 < P1 < P2`), then by numeric `ID` ascending
4. Take the first row

If nothing qualifies (everything done / blocked by deps / `[!]`), report to user and stop.

### 3. Mark in-progress immediately (race-free claim)

**Claim before confirming.** Rewrite the matched line from `[ ]` to `[~]` and write `TODO.md` back. This shrinks the race window with other sessions to a single file write.

### 4. Report the candidate

Concise format:

```
🎯 Next task: [T01] [P0] <title>
   Dependencies: none
   Unblocks: T03, T04, T13

Confirm start? (y / n / skip)
```

- `y` → proceed to step 5 (already claimed)
- `skip` → revert to `[ ]`, loop back to step 2
- `n` → revert to `[ ]`, stop entirely

### 5. Execute

Read the title and figure out what to do. Titles in a well-maintained TODO usually say enough:

- Use whichever sub-skills, scripts, or tools the title implies
- If a project ships a TODO-execution mapping (e.g. `.claude/todo-worker-config.md`), read it
- **If unclear, ask the user.** Don't guess at experimental work, paper edits, or cluster commands

### 6. Update on finish

Success:

```
- `[x]` [P0] [T01] <title>
  > done YYYY-MM-DD: <one-line outcome / artifact pointer>
```

Blocked / failed:

```
- `[!]` [P0] [T01] <title>
  > blocked YYYY-MM-DD: <reason + what unblocks it>
```

Only add a single `> done <date>:` or `> blocked <date>:` continuation line. Don't bloat the task line itself with retrospective spec.

## Cross-Session Coordination

- `TODO.md` is the single source of truth. No lock files.
- Step 3 writes before step 4 confirms — minimizes the claim window.
- If a candidate is already `[~]`, skip it (another session has it) and continue scanning.
- If the user says "take over T0X", jump straight to step 5 without re-filtering.

## When NOT to Use This Skill

- User says "let me think about what to do" — don't push, let them think
- User is mid-code / mid-debug — don't interrupt
- User asks "what's in TODO" — just read it back, **don't claim**

## Project-Level Customization

The skill body stays generic. Per-project conventions live in the project, not in this skill:

- Task-ID → sub-skill mapping → `.claude/todo-worker-config.md` (optional, project-defined)
- Default "done" date format → project chooses (the skill emits `YYYY-MM-DD`)
- Strategy-doc cross-references (roadmap, meeting notes) → project's CLAUDE.md / AGENTS.md

If the project violates the format contract above, fix the project — don't fork the skill.
