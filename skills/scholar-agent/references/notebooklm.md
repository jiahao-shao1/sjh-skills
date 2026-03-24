# Enhanced Mode: NotebookLM Deep Reading

Scholar Inbox CLI's Enhanced Mode uses NotebookLM as a **RAG subagent** — Gemini reads the PDFs, Claude asks questions and synthesizes. This avoids Claude reading full papers directly, saving tokens and eliminating hallucination about paper content.

## How It Works

NotebookLM (backed by Gemini) ingests arXiv papers as sources. When Claude queries it, responses come exclusively from the paper content with inline citations. Claude never sees the raw PDF — only source-grounded answers.

**Token economics**: Reading a 20-page paper directly costs ~50K tokens. Querying NotebookLM about it costs ~500 tokens per question. For 5 papers, that's 250K saved.

## Prerequisites

The `notebooklm` skill must be installed and authenticated. All NotebookLM operations go through its scripts — this skill does NOT use playwright-cli directly for NotebookLM.

```bash
# Check notebooklm auth
python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py status

# If not authenticated:
python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup
# (Browser opens for Google login)
```

If notebooklm skill is not installed or auth fails, fall back to Basic Mode.

## Step-by-Step Workflow

### Step 1: Fetch and Filter Papers

```bash
scholar-inbox digest --json --limit 20
scholar-inbox config  # get user's research interests
```

AI-filter papers based on interests. Select top 5-10 most relevant papers. Skip papers the user has already rated or read.

### Step 2: Classify Papers into Groups

Dynamically group selected papers by topic. Derive group names from paper titles, keywords, and user interests — never use hardcoded categories.

Example grouping:
- "RL Reward Design" (3 papers)
- "VLM Tool Use" (2 papers)
- "Multimodal Reasoning" (2 papers)

Each group maps to a NotebookLM notebook. If no interests configured, use a single group "Daily Papers".

### Step 3: Add Papers to NotebookLM

For each group, use the notebooklm skill's scripts:

```bash
# Check if a notebook for this group already exists
python ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py search --query "RL Reward Design"

# If not found, the paper URL can be added directly with --notebook-url for a new notebook
# If found, use the existing notebook ID

# Add each paper's arXiv URL as a source
# NotebookLM's add source supports website URLs — use the arXiv abstract page
python ~/.claude/skills/notebooklm/scripts/run.py ask_question.py \
  --question "What are the key contributions, methods, and results of the most recently added paper?" \
  --notebook-url "https://notebooklm.google.com/notebook/..."
```

**Important**: When adding new papers to an existing notebook, first add the arXiv URL as a source (via the NotebookLM web UI through playwright-cli if the notebooklm skill doesn't support direct source addition), then query.

### Step 4: Deep Read via NotebookLM

For each paper group, ask NotebookLM targeted questions:

```bash
NOTEBOOKLM="python ~/.claude/skills/notebooklm/scripts/run.py ask_question.py"

# Overview question
$NOTEBOOKLM --question "Summarize each paper's core contribution in 2-3 sentences. Include the paper title before each summary." --notebook-url "$URL"

# Method deep-dive
$NOTEBOOKLM --question "Compare the methods across papers. What are the key technical innovations? What baselines do they compare against?" --notebook-url "$URL"

# Relevance to user's research
$NOTEBOOKLM --question "How do these papers relate to [user's research interests]? Which findings are most actionable?" --notebook-url "$URL"
```

**Follow-up is critical**: NotebookLM answers end with "Is that ALL you need to know?" — if the answer is incomplete or raises new questions, ask follow-ups until you have enough information to write a comprehensive report.

### Step 5: Compile Reading Report

Synthesize NotebookLM's responses into a structured report:

```markdown
## YYYY-MM-DD Paper Reading Report (N papers)

### Group: RL Reward Design

#### 1. [Paper Title] | Authors (Institution)
- **Paper ID**: 4626954 | **Score**: 0.880
- **arXiv**: https://arxiv.org/abs/XXXX.XXXXX
- **Core contribution**: [from NotebookLM, with citation]
- **Method**: [key technical details]
- **Results**: [main numbers]
- **Relevance**: [how it connects to user's work]

#### 2. ...

### Group: VLM Tool Use
...

---
**Actions**: Rate papers with `scholar-inbox rate <id> up/down`
```

### Step 6: Rate Papers

After the user reviews the report:

```bash
scholar-inbox rate <id> up      # relevant papers
scholar-inbox rate <id> down    # not relevant
scholar-inbox rate-batch up 111 222 333  # batch
```

## Notebook Lifecycle

- **Notebooks accumulate knowledge** — papers added today are queryable tomorrow
- **Source limit**: 50 per notebook. At 40+, warn the user. At 50, create "Topic v2"
- Track notebooks in `~/.config/scholar-inbox/notebooks.json` (update after each session)
- Periodically query old notebooks to answer cross-paper questions

## Constraints

| Rule | Why |
|------|-----|
| Max 10 papers per session | NotebookLM processing time + quality |
| Use notebooklm skill scripts, not raw playwright-cli | Reliability, auth management, venv isolation |
| Follow up on NotebookLM answers | First answer is often incomplete |
| Close browser after each session | Prevent orphan processes |
| Dynamic classification only | Hardcoded categories become stale |

## Error Handling

| Error | Action |
|-------|--------|
| notebooklm skill not installed | Fall back to Basic Mode, inform user |
| Google auth expired | `python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py reauth` |
| Source add fails | Skip paper, continue with rest |
| NotebookLM rate limit (50/day) | Switch to Basic Mode for remaining papers |
| Notebook at 50 sources | Create new notebook with "v2" suffix |
