---
name: scholar-agent
description: "Scholar Inbox CLI — fetch daily paper digest, rate papers, manage collections, browse trending, and deep-read papers via NotebookLM. Use whenever user mentions Scholar Inbox, paper digest, daily papers, rating papers, or wants new paper recommendations. Triggers on: '看论文', '今天有什么论文', 'scholar inbox', 'paper digest', '论文推荐', 'rate papers', '收藏论文', '读论文', 'paper reader', '帮我筛选论文'. Preferred over browser-based access — faster, token-efficient, and integrates with NotebookLM for source-grounded deep reading."
---

# Scholar Agent

End-to-end automation: paper discovery → filtering → deep reading → feedback.

Two modes:
- **Basic Mode**: Pure CLI — fetch, filter, rate papers via REST API (no browser needed)
- **Enhanced Mode**: CLI + NotebookLM — deep-read papers with source-grounded answers from Gemini

## Subcommands

| Command | Description |
|---------|-------------|
| `/scholar-inbox` | Today's papers → AI filtering → add to NotebookLM → deep read → report |
| `/scholar-inbox <arXiv ID>` | Add specific paper to NotebookLM and read |
| `/scholar-inbox ask "question"` | Ask NotebookLM paper library a question |
| `/scholar-inbox like 1,3,5` | Upvote papers by report index |

## Prerequisites

| Dependency | Purpose | Install |
|------------|---------|---------|
| `playwright-cli` | Browser login + NotebookLM operations | `npm install -g @anthropic-ai/playwright-cli` |
| `notebooklm` skill | Enhanced Mode deep reading (optional) | `npx skills add notebooklm` |

- **Basic Mode** only requires `playwright-cli` (for initial login)
- **Enhanced Mode** additionally requires `notebooklm` skill with Google auth completed

## Setup

One-click environment check and login:
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox setup
```

Checks: Python → playwright-cli → Scholar Inbox login → NotebookLM skill → add_to_notebooklm.sh

Manual install steps:
```bash
# 1. Browser automation (required)
npm install -g @anthropic-ai/playwright-cli

# 2. NotebookLM skill (required for Enhanced Mode)
npx skills add notebooklm

# 3. NotebookLM Google login (first time only)
python3 ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup
```

## Filtering Configuration

Config files at `~/.config/scholar-inbox/`:

| File | Purpose |
|------|---------|
| `context.md` | Global preferences (research interests, institution tiers, daily limit, etc.) |
| `<project>.md` | Project-level config (keyword filters + NotebookLM classification rules) |

When `/scholar-inbox` is invoked, the corresponding project config is loaded based on the current working directory name. If a project config exists, papers are filtered by keywords and institution tiers, and classified into NotebookLM notebooks according to the rules.

### First-Time Setup

On first `/scholar-inbox` invocation, check if `~/.config/scholar-inbox/context.md` exists:

- **Exists** → Load config, proceed to normal flow
- **Missing** → Interactively collect preferences via AskUserQuestion, then generate config

#### Round 1: Research Preferences (ask 3 questions simultaneously)

1. **Research Interests**
   - header: "Research interest keywords"
   - options: "RL, VLM, visual reasoning" / "NLP, LLM, alignment" / Other (custom)
   - preview: `Used for relevance ranking during paper filtering\nExample: "reinforcement learning, vision-language model, tool use"`

2. **Institution Preference**
   - header: "Institution tiering"
   - options: "Tier-aware (top > well-known > other)" / "No preference"
   - preview: `When enabled: OpenAI/DeepMind/META etc. shown first`

3. **Daily Paper Count**
   - header: "Papers per day"
   - options: "5" / "10" / "15"

#### Round 2: Classification + Project (ask 2 questions simultaneously)

4. **NotebookLM Classification**
   - header: "Notebook classification dimension"
   - options: "Auto-classify by research topic" / "By method type (RL / SFT / Data / Eval)" / "All in one notebook"

5. **Project-Level Config**
   - header: "Enable project-level filtering?"
   - options: "Yes (only show project-relevant papers in specific project directories)" / "No"
   - If "Yes", follow up with the current project's core keywords

#### Config Generation

Based on user answers, generate `~/.config/scholar-inbox/context.md`:

```markdown
# Scholar Inbox Global Config

## Research Interests
keywords: RL, VLM, visual reasoning, tool use

## Filtering Preferences
daily_limit: 10
institution_tier: true  # whether to tier institutions

## NotebookLM Classification
mode: auto_topic  # auto_topic / method_type / single_notebook
```

If project-level config is enabled, also generate `~/.config/scholar-inbox/<project>.md`:

```markdown
# <project> Project Config

## Project Keywords
keywords: agentic reasoning, image editing, multi-turn tool use

## Filtering Rules
Only show papers matching project keywords; demote others but don't hide them.
```

Config files can be manually edited afterwards.

## CLI Quick Reference

**Running the CLI**: If `scholar-inbox` is not on PATH:
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox <command>
```

| Command | Description |
|---------|-------------|
| `scholar-inbox setup` | One-click environment check + login |
| `scholar-inbox doctor` | Diagnose NotebookLM/auth/profile/script issues |
| `scholar-inbox doctor --online` | Open Scholar Inbox / NotebookLM pages and verify live page state |
| `scholar-inbox status` | Check login status |
| `scholar-inbox login [--browser] [--cookie VAL]` | Authenticate |
| `scholar-inbox digest [--limit N] [--min-score F] [--json]` | Today's papers |
| `scholar-inbox paper ID` | Paper details + AI summaries |
| `scholar-inbox rate ID up/down/reset` | Rate a paper |
| `scholar-inbox rate-batch RATING ID...` | Batch rate |
| `scholar-inbox trending [--category CAT --days N]` | Trending papers |
| `scholar-inbox collections` | List collections |
| `scholar-inbox collect ID COLLECTION` | Add to collection |
| `scholar-inbox config set interests "RL, VLM, ..."` | Set research interests |

## Authentication

Session cookie stored at `~/.config/scholar-inbox/session.json` (~7 day expiry).

```bash
scholar-inbox login              # auto-extract from Playwright profile
scholar-inbox login --browser    # open browser, auto-extract cookie on login
scholar-inbox login --cookie VAL # manual paste from DevTools
scholar-inbox status             # check if session is valid
```

## Execution Flow

### Mode 1: `/scholar-inbox` (Daily Paper Filtering + Reading)

#### Phase A: Collect + Filter + Ingest [Dispatch Subagent in Background]

Dispatch a subagent to execute the following steps, returning filtered results and ingestion status:

**Step A1: Fetch Papers from Scholar Inbox (REST API)**

```bash
scholar-inbox digest --json --limit 20
scholar-inbox config  # get user's research interests
```

**Step A2: AI Filtering**

Filter top 5-10 most relevant papers based on user's research interests. Skip already-rated/read papers.
If interests are not configured, sort by score and take top 10.

**Step A3: Dynamic Classification**

Auto-classify papers into NotebookLM notebooks based on title and keywords. Category names are dynamically generated from paper content — no hardcoded categories.

Each category maps to a NotebookLM notebook. Search for existing notebooks:
```bash
python3 ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py search --query "<topic>"
```

If no matching notebook exists, auto-create one:
```bash
NB_URL=$(bash <skill-path>/scripts/create_notebook.sh)
# Register in local library
python3 ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py add \
  --url "$NB_URL" --name "<topic>" --description "<desc>" --topics "<t1,t2>"
```

**Note**: When running consecutive playwright-cli operations (create → add, etc.), add `sleep 2-3` between steps to let the browser session fully close.

**Step A4: Batch Add to NotebookLM**

Use `add_to_notebooklm.sh` (via playwright-cli + NotebookLM browser profile):

```bash
bash <skill-path>/scripts/add_to_notebooklm.sh \
  "<notebook_url>" \
  "https://arxiv.org/abs/XXXX.XXXXX" \
  "https://arxiv.org/abs/YYYY.YYYYY"
```

The script uses explicit strategy routing internally:
1. `playwright-cli open --browser=chrome --profile=<notebooklm-profile>` opens the notebook
2. Detect the current source entry strategy:
   - `open_source_dialog`
   - `open_website_form`
   - `url_input_ready`
3. Once at the URL input, batch-paste all URLs at once
4. Click `Insert`
5. `playwright-cli close`

Browser profile path: `$NOTEBOOKLM_PROFILE` (default `~/.claude/skills/notebooklm/data/browser_state/browser_profile`)

Subagent returns: filtered paper list + classifications + ingestion status

#### Phase B: Deep Reading [Main Context]

After receiving the paper list from the subagent, query NotebookLM:

```bash
NOTEBOOKLM="python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py"

# Overview
$NOTEBOOKLM --question "Summarize each paper's core contribution (2-3 sentences), label with paper title" --notebook-url "$URL"

# Method comparison
$NOTEBOOKLM --question "Compare the methodological innovations, technical approaches, and baselines across papers" --notebook-url "$URL"

# Relevance to user's research
$NOTEBOOKLM --question "How do these papers relate to [user interests]? Which findings are most actionable?" --notebook-url "$URL"
```

**Follow-up is important**: NotebookLM often asks "What else would you like to know?" at the end — if the answer is incomplete or raises new questions, keep asking.

#### Phase C: Output Reading Report

```markdown
## YYYY-MM-DD Paper Reading Report (N new papers)

### Category: RL Reward Design

#### 1. Paper Title | Author et al. (Institution)
- **Paper ID**: 4626954 | **Score**: 0.880
- **arXiv**: https://arxiv.org/abs/XXXX.XXXXX
- **Key Findings**: [from NotebookLM, with citation]
- **Method**: [key technical details]
- **Project Relevance**: [how it connects to user's work]

#### 2. ...

---
Upvote: `/scholar-inbox like 1,3`
Downvote: `scholar-inbox rate-batch down <id1> <id2>`
```

### Mode 2: `/scholar-inbox <arXiv ID>`

1. Fetch paper info with `scholar-inbox paper <id>` (if paper_id)
2. Dynamically classify into the appropriate notebook by title keywords
3. Add arXiv URL to notebook via `add_to_notebooklm.sh`
4. Deep-read via NotebookLM skill
5. Output single-paper reading report

### Mode 3: `/scholar-inbox ask "question"`

Directly query NotebookLM:
```bash
python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py \
  --question "question" --notebook-url "<url>"
```

If no notebook is specified, use the most recently active one.

### Mode 4: `/scholar-inbox like 1,3,5`

Extract paper_ids from the most recent reading report by index, then batch upvote via REST API:
```bash
scholar-inbox rate-batch up <id1> <id2> <id3>
```

## Basic Mode (No NotebookLM)

For quick browsing when deep reading isn't needed:

```bash
scholar-inbox digest --limit 10          # today's paper list
scholar-inbox digest --min-score 0.8     # high-score papers
scholar-inbox paper <id>                 # paper details (with Scholar Inbox AI summary)
scholar-inbox trending --days 7          # trending in past 7 days
scholar-inbox rate <id> up               # upvote
scholar-inbox rate-batch down 111 222    # batch downvote
```

**When displaying papers**: Show title, paper_id, score, keywords, one-line contribution, arXiv link.

## Notebook Lifecycle

- Notebooks accumulate knowledge across sessions — papers added today can be queried tomorrow
- Source limit: 50/notebook. Warn user when approaching 40; at 50, create "Topic v2"
- Process at most 10 new papers per run
- Always `close` playwright-cli when done

## Constraints

| Rule | Reason |
|------|--------|
| REST API over DOM scraping | More stable, no SPA dependency |
| Dynamic classification, no hardcoded categories | Hardcoded categories go stale |
| Use `add_to_notebooklm.sh` to add sources | Verified working, handles playwright-cli quirks |
| Strategy routing for NotebookLM UI detection | Initial UI state after entering a notebook is unpredictable |
| Use notebooklm skill scripts for deep reading | Reliability, auth management, venv isolation |
| Follow up on NotebookLM answers | First answer is often incomplete |

## Verified Behaviors

The following have been verified in production:

- `scholar-inbox status`
- `scholar-inbox digest`
- `scholar-inbox paper`
- `scholar-inbox rate <id> up`
- `scholar-inbox rate <id> reset`
- `scholar-inbox trending`
- `scholar-inbox collections`
- `create_notebook.sh`
- `rename_notebook.sh`
- `add_to_notebooklm.sh` single paper
- `add_to_notebooklm.sh` 3-paper batch
- `ask_question.py`
- `scholar-inbox doctor --online`

Still recommended to test:

- `scholar-inbox rate-batch`
- `scholar-inbox collect`
- `scholar-inbox read`
- Larger batch NotebookLM source imports
- NotebookLM multi-turn follow-up conversations

## Error Handling

| Error | Action |
|-------|--------|
| NotebookLM skill not installed | Fall back to Basic Mode |
| Google auth expired | `python3 ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py reauth` |
| Source addition failed | Skip that paper, continue with the rest |
| NotebookLM rate limit | Fall back to Basic Mode |
| Scholar Inbox session expired | `scholar-inbox login --browser` to re-login |
| `add_to_notebooklm.sh` can't find "Add source" button | Suspect NotebookLM UI change. Don't retry the script blindly; use `playwright-cli snapshot` to check actual button text and ref, then manually click the current UI's "Add source" / "Website" / "Insert" |
| `ask_question.py` reports `Failed to create a ProcessSingleton` or `SingletonLock` | NotebookLM Chrome profile still held by residual Chromium process. Run `pkill -f '/Users/$USER/.claude/skills/notebooklm/data/browser_state/browser_profile'` or the actual profile path, wait 1-2 seconds, then retry |

Run diagnostics first:

```bash
scholar-inbox doctor
scholar-inbox doctor --online
```

It checks:
- Scholar Inbox login validity
- NotebookLM skill / browser profile / state.json existence
- Presence of `add_to_notebooklm.sh` / `create_notebook.sh` / `rename_notebook.sh` / `notebooklm_site_knowledge.sh`
- Whether any process is holding the NotebookLM profile
- With `--online`: actually opens Scholar Inbox / NotebookLM pages for read-only probing

### NotebookLM Troubleshooting

#### 1. `add_to_notebooklm.sh` Broken by UI Change

Symptoms:
- Script exits immediately
- `bash -x add_to_notebooklm.sh ...` shows `ADD_BTN=` or can't find "Website" / "Insert" button

Recommended fix:

```bash
# 1. Open notebook
playwright-cli open --browser=chrome --profile="$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile" "<notebook-url>"
sleep 6

# 2. Capture current DOM snapshot
playwright-cli snapshot

# 3. Find actual button text and refs in snapshot
rg -n 'Add source|Website|Enter URL|Insert' .playwright-cli/*.yml
```

If the script's text matching is broken, manually execute with real refs from the snapshot:

```bash
playwright-cli click <add-source-ref>
playwright-cli click <website-ref>
playwright-cli fill <url-input-ref> "https://arxiv.org/abs/XXXX https://arxiv.org/abs/YYYY"
playwright-cli click <insert-ref>
```

Rules of thumb:
- NotebookLM may auto-open the "Add source" dialog upon entering a notebook — no need to click the old button
- The "Website and YouTube URLs" page supports batch-pasting multiple URLs separated by spaces or newlines
- Before modifying the script, manually verify the flow with real refs to rule out auth or profile issues

#### 2. `ask_question.py` Blocked by NotebookLM Profile Lock

Symptoms:
- `BrowserType.launch_persistent_context: Failed to create a ProcessSingleton`
- Error mentions `SingletonLock` / `profile directory is already in use`

Cause:
- Previous `playwright-cli open` or other Chrome headless process didn't fully exit
- Same NotebookLM browser profile occupied by multiple sessions

Recommended fix:

```bash
# Check for residual processes
ps aux | rg 'browser_profile|Google Chrome|Chromium'

# Kill processes holding the NotebookLM profile
pkill -f "$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile" || true
sleep 2

# Confirm no residual processes
ps aux | rg "$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile" || true
```

Then retry:

```bash
python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py \
  --notebook-url "<notebook-url>" \
  --question "..."
```

Rules of thumb:
- When running `create_notebook.sh` → `add_to_notebooklm.sh` → `ask_question.py` consecutively, add explicit `sleep 2-3` between steps
- If you just used `playwright-cli` manually with NotebookLM, check for profile lock before running `ask_question.py`
- `playwright-cli close` only closes browsers it manages; for residual headless Chrome, use `pkill -f '<profile-path>'`

## When to Use Browser Instead

- **Scholar Maps** — interactive visualization
- **Full PDF inline** — scholar-inbox.com's PDF viewer
