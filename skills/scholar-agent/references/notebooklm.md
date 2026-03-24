# NotebookLM Integration Details

## Why NotebookLM

NotebookLM (backed by Gemini) ingests arXiv papers as sources. When Claude queries it, responses come exclusively from the paper content with inline citations. Claude never sees the raw PDF — only source-grounded answers.

**Token economics**: Reading a 20-page paper directly costs ~50K tokens. Querying NotebookLM about it costs ~500 tokens per question. For 5 papers, that's 250K saved.

## Prerequisites

The `notebooklm` skill must be installed and authenticated:

```bash
# Check auth
python3 ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py status

# Setup (first time)
python3 ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup
```

If notebooklm skill is not installed or auth fails, fall back to Basic Mode.

## Batch Adding Sources

Use `<skill-path>/scripts/add_to_notebooklm.sh`:

```bash
bash scripts/add_to_notebooklm.sh <notebook_url> <url1> [url2] ...
```

Requirements:
- `playwright-cli` installed
- NotebookLM browser profile at `$NOTEBOOKLM_PROFILE` (default: `~/.claude/skills/notebooklm/data/browser_state/browser_profile`)
- Google login in that profile must be valid

The script uses `playwright-cli open --browser=chrome --profile=<path>` (NOT `--persistent`).

Current implementation detail:

- The add flow now uses an explicit strategy router rather than assuming a single click path.
- Supported source-entry strategies currently include:
  - `open_source_dialog`
  - `open_website_form`
  - `url_input_ready`

This matters because NotebookLM may:

- open a notebook directly into `?addSource=true`
- show the website picker immediately
- require clicking `添加来源` first on existing notebooks

Related files:

- `scripts/notebooklm_flow.sh`
- `scripts/notebooklm_site_knowledge.sh`
- `scripts/add_to_notebooklm.sh`

## Renaming Notebooks

Use `<skill-path>/scripts/rename_notebook.sh`:

```bash
bash scripts/rename_notebook.sh <notebook_url> "Notebook Name"
```

This script edits the in-page title field using the shared NotebookLM browser profile.

## Querying NotebookLM

```bash
NOTEBOOKLM="python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py"

$NOTEBOOKLM --question "your question" --notebook-url "<url>"
$NOTEBOOKLM --question "your question" --notebook-id "<id>"
```

## Notebook Management

```bash
NB="python3 ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py"

$NB list                          # list all notebooks
$NB search --query "topic"        # find notebook by topic
$NB add --url <url> --name <name> --description <desc> --topics <t1,t2>  # register
$NB stats                         # library statistics
```

## Diagnostics

For local-only checks:

```bash
scholar-inbox doctor
```

For read-only live probes against Scholar Inbox and NotebookLM pages:

```bash
scholar-inbox doctor --online
```

The online mode verifies:

- Scholar Inbox page reachability
- NotebookLM home page readiness
- NotebookLM source-dialog strategy detection on an existing notebook

## Notebook Lifecycle

- Notebooks accumulate knowledge — papers added today are queryable tomorrow
- Source limit: 50 per notebook. At 40+, warn the user. At 50, create "Topic v2"
- Track notebooks via `notebook_manager.py`

## Verified Behavior

Real browser validation completed on 2026-03-24 for:

- notebook creation
- notebook renaming
- single-paper add
- three-paper batch add
- NotebookLM question answering
