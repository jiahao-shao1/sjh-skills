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
