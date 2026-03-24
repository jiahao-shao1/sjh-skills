---
name: scholar-inbox
description: "Scholar Inbox CLI — fetch daily paper digest, rate papers, manage collections, browse trending, and deep-read papers via NotebookLM. Use whenever user mentions Scholar Inbox, paper digest, daily papers, rating papers, or wants new paper recommendations. Triggers on: '看论文', '今天有什么论文', 'scholar inbox', 'paper digest', '论文推荐', 'rate papers', '收藏论文', '读论文', 'paper reader', '帮我筛选论文'. Preferred over browser-based access — faster, token-efficient, and integrates with NotebookLM for source-grounded deep reading."
---

# Scholar Inbox CLI

Two modes of operation:
- **Basic Mode**: Pure CLI — fetch, filter, rate papers via REST API (no browser)
- **Enhanced Mode**: CLI + NotebookLM — deep-read papers with source-grounded answers from Gemini, dramatically reducing hallucination and token cost

**Running the CLI**: If `scholar-inbox` is not on PATH (not pip-installed), use:
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox <command>
```

## Quick Reference

| Command | Description |
|---------|-------------|
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
scholar-inbox login --browser    # open browser for Google OAuth
scholar-inbox login --cookie VAL # manual paste from DevTools
scholar-inbox status             # check if session is valid
```

## Basic Mode

For daily paper discovery — no browser, no external dependencies:

```bash
# 1. Check login
scholar-inbox status

# 2. Fetch digest (JSON for programmatic use, plain text for display)
scholar-inbox digest --json --limit 20

# 3. Filter by score
scholar-inbox digest --min-score 0.8

# 4. Deep dive into a paper
scholar-inbox paper <id>
# Returns: abstract, problem, method, contributions, evaluation (AI summaries from Scholar Inbox)

# 5. Rate papers
scholar-inbox rate <id> up
scholar-inbox rate-batch down 111 222 333
```

**Presenting papers**: Show title, paper_id, score, keywords, one-line contribution, and arXiv link.

## Enhanced Mode — NotebookLM Deep Reading

This is the key differentiator. Instead of Claude reading entire PDFs (expensive, hallucination-prone), papers are fed into NotebookLM where Gemini reads them. Claude then queries NotebookLM for source-grounded, citation-backed answers.

**Why this matters:**
- A 20-page PDF costs ~50K tokens for Claude to read. Querying NotebookLM costs ~500 tokens.
- NotebookLM answers only from source documents — zero hallucination on paper content.
- Papers persist in notebooks — queryable across sessions, building a research knowledge base.

**Prerequisites**: The `notebooklm` skill must be installed. Check with:
```bash
python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py status
```

### Enhanced Mode Workflow

Read `<skill-path>/references/notebooklm.md` for the complete step-by-step workflow. Summary:

```
scholar-inbox digest --json          → Fetch today's papers
        ↓
AI filter by user interests          → Select relevant papers
        ↓
notebooklm: add arXiv URLs          → Feed papers to NotebookLM
        ↓
notebooklm: ask questions            → Gemini reads PDFs, returns grounded answers
        ↓
Claude synthesizes reading report    → Structured output for user
        ↓
scholar-inbox rate up/down           → Rate based on user feedback
```

### When to Use Enhanced vs Basic

| Scenario | Mode |
|----------|------|
| Quick scan of today's papers | Basic |
| "What's new in RL today?" | Basic (digest + filter) |
| "Read this paper in detail" | Enhanced |
| "Compare these 3 papers' methods" | Enhanced |
| "Find papers related to my project" | Enhanced (add to notebook, query) |
| Rate/collect/trending | Basic (always) |

## User Configuration

```bash
scholar-inbox config set interests "RL, VLM, multi-modal reasoning, tool-augmented LLM"
```

Interests drive AI-based filtering. Classification is dynamic — no hardcoded categories.

## When to Use Browser Instead

- **Initial login** — Google OAuth requires browser once
- **Scholar Maps** — interactive visualization
- **Full PDF inline** — scholar-inbox.com's PDF viewer
