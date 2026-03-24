---
name: scholar-inbox
description: Scholar Inbox CLI — fetch daily paper digest, rate papers, manage collections, and browse trending papers directly via API without opening a browser. Use this skill whenever the user mentions Scholar Inbox, paper digest, daily papers, rating papers, paper collections, or wants to check what new papers are available today. Also triggers on "看论文", "今天有什么论文", "scholar inbox", "paper digest", "论文推荐", "rate papers", "收藏论文". This is the preferred way to interact with Scholar Inbox — much faster and more token-efficient than browser-based access.
---

# Scholar Inbox CLI

API-driven CLI for Scholar Inbox. No browser needed for daily workflows.

**Running the CLI**: If `scholar-inbox` is not on PATH (not pip-installed), use:
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox <command>
```

## Quick Start

| Command | Description | Example |
|---------|-------------|---------|
| `scholar-inbox status` | Check login status | |
| `scholar-inbox login` | Auto-extract cookie from Playwright profile | |
| `scholar-inbox login --browser` | Open browser for Google OAuth | |
| `scholar-inbox login --cookie VAL` | Set cookie manually | |
| `scholar-inbox digest` | Today's paper digest (top 10) | `--limit 20 --min-score 0.8 --json` |
| `scholar-inbox digest --date DATE` | Digest for specific date | `--date 2026-03-20` |
| `scholar-inbox paper ID` | Full paper details + AI summaries | `scholar-inbox paper 123456` |
| `scholar-inbox rate ID up/down` | Rate a paper | `scholar-inbox rate 123456 up` |
| `scholar-inbox rate-batch RATING IDs...` | Batch rate papers | `scholar-inbox rate-batch down 111 222 333` |
| `scholar-inbox trending` | Trending papers (last 7 days) | `--category cs.CV --days 14 --limit 20` |
| `scholar-inbox collections` | List all collections | |
| `scholar-inbox collect ID COLLECTION` | Add paper to collection (name or ID) | `scholar-inbox collect 123456 "Reading List"` |
| `scholar-inbox read ID` | Mark paper as read | `scholar-inbox read 123456` |
| `scholar-inbox config` | Show all config | |
| `scholar-inbox config set KEY VAL` | Set config value | `scholar-inbox config set interests "RL, VLM"` |

## Authentication

Three methods, in order of preference:

1. **Auto-extract** (recommended): `scholar-inbox login`
   - Reads cookie from Playwright's persistent profile SQLite DB
   - Falls back to `playwright-cli cookie-get` if DB is encrypted (macOS)

2. **Browser OAuth**: `scholar-inbox login --browser`
   - Opens Playwright with `--persistent --headed` for Google OAuth
   - Cookie is extracted automatically after login

3. **Manual paste**: `scholar-inbox login --cookie <value>`
   - Paste the `session` cookie from browser DevTools

Session stored at `~/.config/scholar-inbox/session.json` (mode 600). Cookies expire after ~7 days. Run `scholar-inbox status` to check.

## Basic Mode Workflow

When only the CLI is available (no browser needed):

```
# 1. Verify login
scholar-inbox status

# 2. Get today's digest as JSON (best for programmatic use)
scholar-inbox digest --json

# 3. Present papers to user — show: title, score, keywords, one-line summary
#    Use --min-score to filter noise, --limit to control volume

# 4. Drill into interesting papers
scholar-inbox paper <id>
# Shows: abstract, problem, method, contributions, evaluation (AI summaries)

# 5. Rate based on user feedback
scholar-inbox rate <id> up      # interesting
scholar-inbox rate <id> down    # not relevant

# 6. Batch rate to save time
scholar-inbox rate-batch down 111 222 333 444
```

**Presenting papers to the user**: When showing digest results, format each paper as:
- Title (with paper ID for reference)
- Score + keywords
- One-line contribution summary (from `contributions_question`)
- ArXiv link if available

## Enhanced Mode

When `playwright-cli` is also available, enable the full research pipeline:

1. **Fetch & Filter**: `scholar-inbox digest --json` then AI-filter by user interests
2. **Deep Read**: `scholar-inbox paper <id>` for AI summaries
3. **NotebookLM Integration**: Read `<skill-path>/references/notebooklm.md` for instructions on adding papers to NotebookLM for deep analysis
4. **Report**: Compile filtered papers into a structured daily briefing
5. **Rate**: Batch rate all reviewed papers based on user decisions

Flow: digest -> AI filter by interests -> add to NotebookLM -> deep read -> report

## User Configuration

Set research interests for AI-based paper filtering:

```bash
scholar-inbox config set interests "RL, VLM, multi-modal reasoning, tool-augmented LLM"
```

When filtering papers, Claude dynamically classifies each paper against the user's stated interests. No hardcoded categories — classification adapts to whatever interests the user specifies.

Other useful config keys:
- `interests` — comma-separated research topics for filtering
- `default_limit` — default number of papers in digest
- `min_score` — default minimum ranking score

## When to Use Browser Instead

The CLI covers most daily workflows. Use the browser (`playwright-cli open --persistent`) for:

- **Initial login** — Google OAuth requires a browser the first time
- **Scholar Maps** — visual exploration of paper citation graphs
- **Full PDF reading** — inline PDF viewer on scholar-inbox.com
- **Complex collection management** — drag-and-drop organization
