# NotebookLM Integration Details

## Why NotebookLM

NotebookLM (backed by Gemini) ingests arXiv papers as sources. When Claude queries it, responses come exclusively from the paper content with inline citations. Claude never sees the raw PDF — only source-grounded answers.

**Token economics**: Reading a 20-page paper directly costs ~50K tokens. Querying NotebookLM about it costs ~500 tokens per question. For 5 papers, that's 250K saved.

## Prerequisites

The `notebooklm` skill must be installed and authenticated:

```bash
# Check auth
python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py status

# Setup (first time)
python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup
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

## Querying NotebookLM

```bash
NOTEBOOKLM="python ~/.claude/skills/notebooklm/scripts/run.py ask_question.py"

$NOTEBOOKLM --question "your question" --notebook-url "<url>"
$NOTEBOOKLM --question "your question" --notebook-id "<id>"
```

## Notebook Management

```bash
NB="python ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py"

$NB list                          # list all notebooks
$NB search --query "topic"        # find notebook by topic
$NB add --url <url> --name <name> --description <desc> --topics <t1,t2>  # register
$NB stats                         # library statistics
```

## Notebook Lifecycle

- Notebooks accumulate knowledge — papers added today are queryable tomorrow
- Source limit: 50 per notebook. At 40+, warn the user. At 50, create "Topic v2"
- Track notebooks via `notebook_manager.py`
