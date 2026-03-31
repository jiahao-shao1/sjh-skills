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

### Human Zone (read-only for AI, with exceptions)
Directories: `notes/`, `projects/`, `tasks/`, `resources/`, `contexts/`, `daily/`, `people/`

**NEVER directly create or modify files in these directories** — unless using `scripts/human-write.sh` for user-dictated content (tasks, notes). Human-write validates the path is in `tasks/` or `notes/` AND the content has `source: human`.

### AI Zone (read-write for AI)
Directory: `ops/` (and all subdirectories)

All AI-generated writes MUST go through `scripts/safe-write.sh` which validates paths via `realpath`. Direct file writes to the vault are forbidden.

## Commands

### CRUD Commands

#### /capture
Capture user's words as a draft. Run `scripts/capture.sh`.

**Zone:** Writes to `ops/drafts/` only (via safe-write.sh).

#### Create Task
Create a task the user dictates. Run `scripts/create-task.sh`.

```bash
scripts/create-task.sh $VAULT_ROOT "Task title" --due 2026-04-01 --tags "work,urgent"
```

**Zone:** Writes to `tasks/` only (via human-write.sh, source: human).

#### Create Note
Create a note the user dictates. Run `scripts/create-note.sh`.

```bash
scripts/create-note.sh $VAULT_ROOT "Note title" "Content text" --tags "ai" --links "concept-a,concept-b"
```

**Zone:** Writes to `notes/` only (via human-write.sh, source: human).

#### Query Tasks
Query tasks with filtering. Run `scripts/query-tasks.sh`.

```bash
scripts/query-tasks.sh $VAULT_ROOT --undone --date today
scripts/query-tasks.sh $VAULT_ROOT --tag migration --project obsidian-brain
```

**Zone:** Reads only.

#### Complete Task
Mark a task as done. Run `scripts/complete-task.sh`.

```bash
scripts/complete-task.sh $VAULT_ROOT "task keyword"
```

**Zone:** Modifies `done:` field in `tasks/` only.

### Planning Commands

#### /context
Load project context from the vault. Read `references/command-guide.md` for details.

**Zone:** Reads both zones. Never writes.

#### /today
Morning planning. Read tasks, recent daily notes, and calendar.

**Zone:** Reads both zones. Output to terminal only — never writes.

### Reflection Commands (Phase 2)

All reflection commands output to **terminal only** — they never write files.

#### /challenge
Stress-test a belief against your past writing.

```bash
scripts/analyze.sh $VAULT_ROOT --mode challenge --topic "some belief"
```

**Zone:** Reads human zone only.

#### /drift
Detect gaps between intended goals and actual activity.

```bash
scripts/analyze.sh $VAULT_ROOT --mode drift --days 60
```

**Zone:** Reads human zone only.

#### /emerge
Surface hidden ideas — ghost links and recurring themes.

```bash
scripts/analyze.sh $VAULT_ROOT --mode emerge --days 30
```

**Zone:** Reads human zone only.

#### /connect
Find hidden connections between two topics.

```bash
scripts/analyze.sh $VAULT_ROOT --mode connect --topics "topic-a,topic-b"
```

**Zone:** Reads human zone only.

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
