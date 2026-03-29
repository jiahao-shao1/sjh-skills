# Obsidian Second Brain — Design Spec

> A Claude Code skill that integrates with an Obsidian Vault to create a "thinking partner" workflow, replacing Notion Life OS with a Markdown-native system.

## Background & Motivation

The user currently runs a Notion Life OS (PARA method) with 6 interconnected databases. As more workflows converge into Claude Code, the Notion API-based interaction becomes a bottleneck — Claude Code reads/writes Markdown natively, but Notion requires API calls with quirky formatting rules (checkbox `__YES__`/`__NO__`, date splitting, etc.).

Inspired by [Internet Vin's Obsidian + Claude Code system](https://www.youtube.com/watch?v=6MBq1paspVU) and [My-Brain-Is-Full-Crew](https://github.com/gnekt/My-Brain-Is-Full-Crew), this project aims to:

1. Move the second brain to local Markdown files (Obsidian Vault)
2. Let Claude Code interact with it natively (read/write files)
3. Preserve the user's "taste" — human thinking must not be polluted by AI-generated content
4. Maintain a single entry point for all knowledge (no scattered docs across projects)

## Core Design Principle: Dual-Zone Vault

The vault is split into two zones with different AI permission levels, connected by wikilinks.

### Human Zone (AI: read-only)

Contains the user's own thoughts, judgments, and taste. AI **must never write** to these directories. This ensures that reflection commands (`/challenge`, `/emerge`, `/drift`, `/trace`) only analyze genuinely human-authored content, preventing a feedback loop where AI reads its own prior outputs and mistakes them for human thinking patterns.

### AI Zone (AI: read-write)

Contains operational knowledge: troubleshooting logs, meeting transcripts, research summaries, technical decisions. This is factual/engineering content that doesn't pollute the reflection feedback loop.

### Wikilink Bridge

Human zone notes can link to AI zone notes (e.g., a hand-written meeting reflection links to the full AI-generated transcript), and vice versa. This creates a connected graph in Obsidian while maintaining clear authorship boundaries.

## Vault Structure

```
~/second-brain/                    # Obsidian Vault root
│
├── ── Human Zone (AI: read-only) ──
├── notes/                         # Ideas, reflections, learning notes
├── projects/                      # Project descriptions, goals, progress
├── tasks/                         # To-do items
├── resources/                     # Collected resources, articles, videos
├── contexts/                      # Deep context files (project/personal workflow)
├── daily/                         # Daily notes (Obsidian Daily Notes plugin)
├── people/                        # People notes (collaborators, mentors...)
│
├── ── AI Zone (AI: read-write) ──
├── ops/                           # AI-produced operational knowledge
│   ├── <project-name>/            # Per-project: troubleshooting, decisions
│   ├── meetings/                  # AI-transcribed meeting notes
│   └── research/                  # AI-organized research materials
│
├── ── System ──
├── templates/                     # Templates for each content type
└── .obsidian/                     # Obsidian configuration
```

### Frontmatter Convention

Every file uses YAML frontmatter for metadata:

```yaml
---
type: note | task | project | resource | meeting-transcript | debug-log
created: 2026-03-29
tags: [tag1, tag2]
source: human | ai          # Authorship marker (AI zone files always have source: ai)
speakers: [name1, name2]    # For meeting transcripts only
---
```

### Wikilink Strategy

Following Vin's approach: link to **specific entities** (people, projects, concepts, patterns), not broad categories.

- Good: `[[greg-eisenberg]]`, `[[obsidian-brain]]`, `[[meeting-yuanbo-0329]]`
- Bad: `[[podcast]]`, `[[fitness]]`, `[[work]]`

## Command Design

### Command Permission Matrix

| Command | Purpose | Read Human | Read AI | Write AI |
|---------|---------|:----------:|:-------:|:--------:|
| `/context` | Load project global context | ✓ | ✓ | — |
| `/today` | Morning planning (calendar + notes + tasks) | ✓ | ✓ | — |
| `/capture` | Capture user's words as a draft note | — | — | ✓ |
| `/transcribe` | Meeting recording → structured transcript | — | — | ✓ |
| `/debug-log` | Record troubleshooting experience | — | ✓ | ✓ |
| `/connect` | Discover cross-domain associations | ✓ | ✓ | — |
| `/challenge` | Pressure-test current beliefs | ✓ | **✗** | — |
| `/drift` | Compare stated goals vs actual behavior | ✓ | **✗** | — |
| `/emerge` | Surface unconscious patterns | ✓ | **✗** | — |
| `/trace` | Track idea evolution over time | ✓ | **✗** | — |
| `/graduate` | Promote scattered ideas to standalone articles | ✓ | **✗** | — |

**Reflection commands** (`/challenge`, `/drift`, `/emerge`, `/trace`, `/graduate`) strictly skip the AI zone to maintain feedback loop purity.

### Command Details

**Phase 1 — Foundation:**

- **`/context`**: Reads context files from `contexts/`, recent daily notes, and relevant `ops/` entries. Follows wikilinks to build a complete project picture. Equivalent to Vin's `/context` command.
- **`/capture "text"`**: Saves the user's input to `ops/drafts/` as a timestamped Markdown file. The user can later review and move relevant content into the human zone.
- **`/today`**: Aggregates today's tasks, recent daily notes (past 7 days), and calendar events to propose a prioritized daily plan. Output in terminal only.

**Phase 2 — Thinking Partner:**

- **`/challenge <topic>`**: Scans human zone for the user's writings on a topic, finds contradictions, counter-evidence, and shifts in thinking. Pressure-tests current beliefs.
- **`/drift`**: Compares stated goals (from `projects/` and `contexts/`) with actual behavior patterns (from `daily/` over past 30-60 days). Identifies avoidance or drift.
- **`/emerge`**: Finds ideas the vault implies but never explicitly states — conclusions from scattered premises, unnamed patterns.
- **`/trace <idea>`**: Tracks how a specific idea has evolved across time in the vault.
- **`/graduate`**: Scans recent daily notes for recurring ideas that deserve their own standalone note. Suggests promotion, user writes the final version.
- **`/connect <concept1> <concept2>`**: Forces the AI to find deep connections between seemingly unrelated concepts, based on vault content.
- **`/transcribe <audio-file>`**: Converts meeting audio to a structured transcript in `ops/meetings/`, with speaker identification. Adds a wikilink placeholder for the user to create their own reflection note.

## Data Flow Example: Meeting Scenario

```
1. Meeting happens with 渊博 about Agentic UM

2. /transcribe meeting.mp3
   → AI writes: ops/meetings/meeting-yuanbo-0329.md
     (source: ai, speakers: [嘉豪, 渊博], full transcript)
     Contains: 嘉豪的笔记：[[yuanbo-agentic-um]]

3. User manually writes: notes/yuanbo-agentic-um.md
   "渊博说应该先做 XX。我同意因为...但我觉得 YY 也值得探索。"
   Contains: 完整记录：[[meeting-yuanbo-0329]]

4. /emerge (later)
   → Scans human zone only
   → "嘉豪 repeatedly mentions wanting to explore YY across multiple notes.
      This might be an unnamed direction worth formalizing."

5. /context (when working on the project)
   → Reads both zones
   → Full picture: user's judgment + meeting details + troubleshooting history
```

## Technical Stack

### Dependencies

- **Obsidian**: GUI for browsing and manually writing in the vault
- **Obsidian CLI** ([obsidian-cli](https://github.com/Obsidian-CLI/obsidian-cli)): Lets Claude Code query wikilink relationships, backlinks, and graph structure beyond plain file reads
- **Claude Code Skill**: `obsidian-brain` skill in sjh-skills monorepo

### Skill Structure

```
skills/obsidian-brain/
├── SKILL.md              # Skill definition with triggers and zone rules
├── scripts/
│   ├── init-vault.sh     # Set up vault directory structure + templates
│   ├── query-links.sh    # Query wikilinks and backlinks via Obsidian CLI
│   └── capture.sh        # Write captured content to ops/drafts/
├── references/
│   ├── vault-schema.md   # Frontmatter conventions and zone rules
│   └── command-guide.md  # Detailed command documentation
└── templates/
    ├── note.md
    ├── task.md
    ├── project.md
    ├── resource.md
    ├── daily.md
    └── meeting-transcript.md
```

### Integration with Existing Systems

- **Claude Code Memory** (`~/.claude/projects/.../memory/`): Continues to store conversation-scoped feedback and user preferences. The Obsidian vault stores durable knowledge.
- **Notion Life OS**: Coexists during transition. New content goes to Obsidian; old Notion data stays until the user decides to migrate.
- **Per-project docs**: Projects can optionally maintain their own `CLAUDE.md` and `docs/`, but the vault's `ops/<project>/` provides a centralized view across all projects.

## Zone Enforcement

Zone boundaries are enforced at two levels:

1. **Script-level**: All write scripts (`capture.sh`, etc.) resolve the target path to its canonical absolute form (`realpath`) and validate it falls under `$VAULT_ROOT/ops/`. Symlink escapes and path traversal (e.g., `ops/../notes/`) are rejected. This is the hard boundary.
2. **SKILL.md rules**: The skill definition explicitly instructs Claude Code never to write files outside `ops/`. This is a defense-in-depth layer on top of script enforcement.

Obsidian CLI fallback: If `obsidian-cli` is unavailable, the skill falls back to `ripgrep` for parsing `[[wikilinks]]` from Markdown files. This ensures the skill works without a hard dependency on a single third-party tool.

## Vault Version Control

The vault is a git repository (`git init` at setup). This provides:
- **Rollback**: Any batch operation can be undone via `git checkout`
- **History**: Track how notes and links evolve over time
- **Safety net**: Before AI writes to `ops/`, the skill can auto-commit to create a restore point

## Phasing

### Phase 1: Foundation

1. Set up Obsidian vault with dual-zone structure + `git init`
2. Create templates for each content type
3. Define deep context file conventions (context schema for `/context`)
4. **Establish zone enforcement** — path allowlist in write scripts + SKILL.md rules
5. Install and configure Obsidian CLI (with ripgrep fallback)
6. Build `obsidian-brain` skill with `/context`, `/capture`, `/today`
7. Add zone boundary tests (assert reflection commands never read `ops/`, write commands never touch human zone, path traversal/symlink escape attempts are rejected)

### Phase 2: Thinking Partner

- Implement reflection commands: `/challenge`, `/drift`, `/emerge`, `/trace`
- Implement `/graduate` for idea promotion
- Implement `/connect` for cross-domain discovery
- Implement `/transcribe` for meeting recording processing

## Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| AI write permission | Dual-zone (read-only human, read-write AI) | Protects reflection feedback loop while allowing operational knowledge capture |
| Vault structure | PARA-inspired folders + wikilinks | User already familiar with PARA from Notion; wikilinks add Obsidian's unique value |
| GUI | Obsidian (existing) | Start with proven tool; custom web GUI deferred to future |
| Reflection scope | Human zone only | Prevents AI from reading its own prior outputs as human patterns |
| Migration strategy | Gradual — no migration timeline; consider migrating when all active projects/tasks live in Obsidian for 1+ month | Low risk, no big-bang migration needed |
| Link strategy | Specific entities, not broad categories | Following Vin's validated approach for meaningful graph structure |
| Obsidian CLI dependency | Required with ripgrep fallback | Avoids single point of failure while leveraging CLI when available |
| Vault VCS | Git-managed vault | Enables rollback, history tracking, and safety snapshots before batch writes |

## Out of Scope (for now)

- Custom web GUI (Notion-like interface) — deferred until workflow is proven
- Notion data migration — user will decide when ready (trigger: all active work in Obsidian for 1+ month)
- Mobile access — Obsidian has mobile apps, but Claude Code integration is desktop-only
- Multi-user / collaboration features
