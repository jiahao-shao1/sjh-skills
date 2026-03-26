# Scholar Agent

> A taste-aware research agent that discovers papers you'll love and reads them deeply — powered by [Scholar Inbox](https://www.scholar-inbox.com) + [NotebookLM](https://notebooklm.google.com).

[![PyPI version](https://img.shields.io/pypi/v/scholar-inbox)](https://pypi.org/project/scholar-inbox/)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Why This Exists

Reading papers is broken. Here's what a typical day looks like:

1. **Finding papers**: You open Scholar Inbox, scroll through 50+ papers, click into each one, decide if it's relevant. 30 minutes gone.
2. **Reading papers**: You find 10 interesting ones. Each PDF is 10–20 pages. You either skim (and miss details) or read carefully (and lose the afternoon).
3. **Asking an AI to help**: You feed PDFs to Claude/GPT. But a 20-page PDF costs ~50K tokens. 10 papers = 500K tokens — context window blown. And the AI doesn't know your taste, so it can't filter for you.

**Scholar Agent solves both problems by composing two existing services:**

- **Scholar Inbox** already knows your taste. It tracks every paper you upvote/downvote and builds a personalized ranking model. We reverse-engineered its REST API so you can access this programmatically — no browser needed.
- **NotebookLM** already knows how to read papers. It ingests PDFs, extracts structured content, and answers questions grounded in the source — zero hallucination on paper content. Querying it costs ~500 tokens instead of ~50K.

The result: tell Claude Code "show me today's interesting papers about RL for VLMs and summarize the key ideas", and it will:
1. Fetch your personalized digest from Scholar Inbox (your taste, not generic rankings)
2. Batch-add the relevant papers to NotebookLM (one command, not 10 manual clicks)
3. Query NotebookLM for source-grounded summaries (500 tokens/paper, not 50K)
4. Synthesize a reading report and let you rate papers to refine future recommendations

**No custom ML model. No training data. Just two good services, composed well.**

## Features

- **Daily Digest** — fetch today's recommended papers with scores, keywords, and AI summaries
- **Rate Papers** — thumbs up/down to improve your recommendations
- **Collections** — organize papers into named collections
- **Trending** — discover trending papers across categories
- **One-Click Setup** — `scholar-inbox setup` checks all prerequisites and guides you through
- **Doctor Command** — `scholar-inbox doctor` diagnoses auth, scripts, NotebookLM profile state, and lock conflicts
- **Online Doctor** — `scholar-inbox doctor --online` performs read-only live probes against Scholar Inbox and NotebookLM
- **Claude Code Skill** — natural language interaction via Claude Code
- **NotebookLM Deep Reading** — batch-add papers to NotebookLM for hallucination-free Q&A
- **Zero Dependencies** — pure Python stdlib, works everywhere

## Verified Status

Last verified: 2026-03-26

| Flow | Status | Notes |
|------|--------|-------|
| `scholar-inbox status` / `digest` / `paper` | ✅ | REST API |
| `scholar-inbox rate` / `trending` / `collections` | ✅ | REST API |
| `notebooklm list` / `create` / `use` | ✅ | RPC API via notebooklm-py |
| `notebooklm source add <url>` | ✅ | Single + batch |
| `notebooklm ask "..."` | ✅ | Source-grounded Q&A with citations |
| `notebooklm auth check --test` | ✅ | Cookie health check |

## Quick Start

```bash
# 1. Install skill
npx skills add jiahao-shao1/sjh-skills --skill scholar-agent

# 2. Install NotebookLM API (for deep reading)
pipx install "notebooklm-py[browser]"

# 3. Login (one-time each)
npm install -g @anthropic-ai/playwright-cli  # for Scholar Inbox browser login
notebooklm login                     # Google — opens browser
scholar-inbox login --browser         # Scholar Inbox — opens browser for OAuth
```

### Authenticate

Scholar Inbox uses Google OAuth. Choose one method:

```bash
# Auto-extract from existing Playwright browser profile (simplest)
scholar-inbox login

# Open browser for interactive OAuth login
scholar-inbox login --browser

# Paste cookie manually (from browser DevTools)
scholar-inbox login --cookie "your-session-cookie-value"
```

Verify login status:

```bash
scholar-inbox status
# Logged in as: Jiahao Shao (user_id: 12345)

# Diagnose local setup without changing anything
scholar-inbox doctor

# Run read-only live probes against Scholar Inbox and NotebookLM
scholar-inbox doctor --online
```

### Usage

**Daily digest** — your personalized paper feed:

```bash
$ scholar-inbox digest --limit 5
# Scholar Inbox Digest -- 2026-03-24
# Total: 87 papers, showing top 5

1. [94712] 0.971 -- Visual Chain-of-Thought Reasoning with Grounded Verification
   Zhang et al.
   Affiliations: Stanford University, Google DeepMind
   Keywords: visual reasoning, chain-of-thought, verification
   https://arxiv.org/abs/2603.14821
   > Introduces a grounded verification mechanism for visual CoT that reduces hallucination by 34%

2. [94658] 0.953 [up] -- Scaling Multimodal RL with Tool-Augmented Reward Shaping
   Li et al.
   Affiliations: UC Berkeley, Meta AI
   Keywords: reinforcement learning, multimodal, tool use
   https://arxiv.org/abs/2603.14507
   > Proposes tool-augmented reward shaping that enables efficient multi-turn RL training for VLMs
```

**JSON output** for programmatic use:

```bash
scholar-inbox digest --limit 3 --min-score 0.9 --json
```

If Scholar Inbox returns a clearly mismatched summary for a paper, the CLI now marks it as suspect and suppresses it in the human-readable output instead of printing misleading content. In JSON output, these cases surface as `suspect_summary: true`.

**Paper details** — full abstract, with suspect summaries automatically hidden when they appear unrelated to the paper title:

```bash
$ scholar-inbox paper 94712
# Visual Chain-of-Thought Reasoning with Grounded Verification
Authors: Zhang et al.
Published: 2026-03-23 | NeurIPS 2026
Ranking Score: 0.971

## Abstract
We present a grounded verification mechanism for visual chain-of-thought
reasoning that systematically validates each reasoning step...

## Contributions
- Introduces grounded verification for visual CoT, reducing hallucination by 34%
- Achieves state-of-the-art on 5 visual reasoning benchmarks
```

**Rate papers** to improve recommendations:

```bash
scholar-inbox rate 94712 up       # thumbs up
scholar-inbox rate 94658 down     # thumbs down
scholar-inbox rate 94601 reset    # remove rating

# Batch rate multiple papers at once
scholar-inbox rate-batch up 94712 94658 94601
```

**Trending papers** across the community:

```bash
scholar-inbox trending --days 7 --limit 3
```

**Collections** — organize papers:

```bash
scholar-inbox collections
scholar-inbox collect 94712 "Visual Reasoning"
```

## NotebookLM Deep Reading

This is the key differentiator. Instead of Claude reading entire PDFs (expensive, hallucination-prone), papers are batch-loaded into NotebookLM where Gemini reads them with source grounding.

Powered by [notebooklm-py](https://github.com/teng-lin/notebooklm-py) — an unofficial Python API that uses Google's internal RPC endpoints (no browser automation needed after login).

```bash
# Create a notebook and add papers
notebooklm create "RL Papers"
notebooklm use <notebook_id>
notebooklm source add "https://arxiv.org/abs/2602.01334"
notebooklm source add "https://arxiv.org/abs/2505.14362"

# Ask source-grounded questions (~500 tokens/query vs ~50K/PDF)
notebooklm ask "Compare the key findings of these papers"
notebooklm ask "How do they prove that tool-returned images are not utilized?"
```

## Python SDK

```python
from scholar_inbox import ScholarInboxClient

client = ScholarInboxClient(session="your-session-cookie")

# Fetch today's digest
digest = client.get_digest()
for paper in digest["digest_df"][:5]:
    print(f"{paper['ranking_score']:.3f} {paper['title']}")

# Rate a paper
client.rate(94712, "up")

# Get trending papers
trending = client.get_trending(category="ALL", days=7)

# Manage collections
collections = client.get_collections()
client.add_to_collection(collection_id=1, paper_id=94712)
client.create_collection("New Collection", paper_id=94712)

# Find similar papers
similar = client.get_similar(94712)
```

## Claude Code Integration

When installed as a Claude Code skill, you can interact naturally:

```
> Show me today's top papers about reinforcement learning
> Rate paper 94712 thumbs up
> What's trending in AI this week?
> Add paper 94658 to my "RL for LLM" collection
> Read these 10 papers and summarize the key ideas
```

## API Reference

Scholar Inbox API endpoints (discovered via reverse engineering):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/check_session` | Verify session validity |
| `GET` | `/api/digest` | Fetch paper digest (params: `date`, `from_date`, `to_date`) |
| `GET` | `/?paper_id=ID` | Fetch paper details from the current digest view; upstream behavior is unstable, so CLI filters exact matches |
| `POST` | `/api/rate` | Rate paper(s) (body: `{rating, id}` or `{rating, ids}`) |
| `POST` | `/api/mark_read` | Mark paper as read (body: `{id}`) |
| `GET` | `/api/collections` | List user collections |
| `POST` | `/api/collection/add` | Add paper to collection (body: `{collection_id, paper_id}`) |
| `POST` | `/api/collection/create` | Create collection (body: `{name, paper_id?}`) |
| `GET` | `/api/trending` | Trending papers (params: `category`, `days`, `page`) |
| `GET` | `/api/similar/{id}` | Find similar papers |

Base URL: `https://api.scholar-inbox.com`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run the test suite (`pytest tests/ -v`)
5. Commit your changes (`git commit -m 'feat: add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

[MIT](LICENSE)
