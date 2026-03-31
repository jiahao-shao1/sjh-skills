# Command Guide

## CRUD Commands

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

**Zone:** Writes AI zone only (source: ai).

### Create Task

**Purpose:** Create a task file from user-dictated content.

**Writes to:** `tasks/YYYY-MM-DD-slugified-title.md`

**Usage:**
- `scripts/create-task.sh ~/second-brain "Buy groceries"`
- `scripts/create-task.sh ~/second-brain "Submit report" --due 2026-04-01 --tags "work,urgent"`

**Behavior:**
1. Generates slugified filename with date prefix
2. Builds frontmatter (type: task, done: false, source: human)
3. Writes via human-write.sh (validates tasks/ path + source: human)
4. Handles duplicate filenames with -2, -3 suffix

**Zone:** Writes human zone (tasks/) with source: human.

### Create Note

**Purpose:** Create a note file from user-dictated content.

**Writes to:** `notes/slugified-title.md`

**Usage:**
- `scripts/create-note.sh ~/second-brain "AI Taste" "My thoughts on AI taste"`
- `scripts/create-note.sh ~/second-brain "Meeting Ideas" "Discussion points" --tags "meeting" --links "project-x,person-y"`

**Behavior:**
1. Generates slugified filename (no date prefix — notes are evergreen)
2. Builds frontmatter (type: note, source: human)
3. Appends `Related: [[link1]] [[link2]]` from --links
4. Writes via human-write.sh

**Zone:** Writes human zone (notes/) with source: human.

### Query Tasks

**Purpose:** Query and filter task files.

**Usage:**
- `scripts/query-tasks.sh ~/second-brain` — all tasks
- `scripts/query-tasks.sh ~/second-brain --undone` — incomplete only
- `scripts/query-tasks.sh ~/second-brain --date today` — due today
- `scripts/query-tasks.sh ~/second-brain --date this-week` — due this week
- `scripts/query-tasks.sh ~/second-brain --tag migration` — by tag
- `scripts/query-tasks.sh ~/second-brain --project obsidian-brain` — by project wikilink

**Output:** Markdown table (Status, Title, Due, Tags). Sorted by due date.

**Zone:** Reads only.

### Complete Task

**Purpose:** Mark a task as done.

**Usage:**
- `scripts/complete-task.sh ~/second-brain "migrate"` — fuzzy match by keyword
- `scripts/complete-task.sh ~/second-brain "migrate-projects"` — exact filename

**Behavior:**
1. Searches tasks/ for matching file (exact → glob → title keyword)
2. Changes `done: false` → `done: true` in frontmatter
3. Errors on 0 or multiple matches

**Zone:** Modifies tasks/ only.

## Planning Commands

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

### /today

**Purpose:** Morning planning — aggregates tasks, recent notes, and calendar events.

**Reads:** `tasks/` (undone items) + `daily/` (past 7 days) + calendar (if available)

**Behavior:**
1. Scan `tasks/` for files where `done: false`
2. Read daily notes from the past 7 days
3. Look for items with due dates
4. Present a prioritized plan in the terminal

**Zone:** Reads human zone + AI zone. Never writes — output is terminal only.

## Reflection Commands

All reflection commands **output to terminal only** — they never write files. They only scan the human zone to prevent AI from reading its own prior outputs.

### /challenge

**Purpose:** Stress-test a current belief against your past writing.

**Usage:** `scripts/analyze.sh ~/second-brain --mode challenge --topic "AI has no taste"`

**Behavior:**
1. Scans notes/ + daily/ for paragraphs containing the topic keyword
2. Outputs matching paragraphs with source file and date
3. Sorted oldest-first to show evolution of thinking
4. Claude Code analyzes whether past writing contradicts current belief

**Zone:** Reads human zone only.

### /drift

**Purpose:** Detect gaps between what you say you're focused on and what you actually do.

**Usage:** `scripts/analyze.sh ~/second-brain --mode drift --days 60`

**Behavior:**
1. Finds active projects (status: active in projects/)
2. Counts how often each project appears in daily notes over N days
3. Outputs a table showing projects vs. mention frequency
4. Claude Code identifies projects that are "all talk, no action"

**Zone:** Reads human zone only.

### /emerge

**Purpose:** Surface ideas hiding in your notes that you haven't consciously recognized.

**Usage:** `scripts/analyze.sh ~/second-brain --mode emerge --days 30`

**Behavior:**
1. Scans notes/ + daily/ from the last N days
2. Extracts all wikilinks and counts frequency
3. Identifies "ghost links" — referenced but with no corresponding file (ideas mentioned but never developed)
4. Lists most frequently connected ideas
5. Claude Code analyzes patterns and hidden themes

**Zone:** Reads human zone only.

### /connect

**Purpose:** Find hidden connections between two seemingly unrelated topics.

**Usage:** `scripts/analyze.sh ~/second-brain --mode connect --topics "filmmaking,worldbuilding"`

**Behavior:**
1. Finds files related to each topic (keyword + wikilink search)
2. Identifies "bridge files" that reference both topics
3. Extracts shared wikilinks between the two file sets
4. Claude Code analyzes the hidden connections

**Zone:** Reads human zone only.
