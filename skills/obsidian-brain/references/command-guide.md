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
