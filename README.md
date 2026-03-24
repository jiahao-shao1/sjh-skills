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
- **Claude Code Skill** — natural language interaction via Claude Code
- **NotebookLM Deep Reading** — batch-add papers to NotebookLM for hallucination-free Q&A
- **Zero Dependencies** — pure Python stdlib, works everywhere

## Quick Start

### Install

**Claude Code skill** (recommended for Claude Code users):

```bash
claude install-skill https://github.com/jiahao-shao1/scholar-agent
```

**pip:**

```bash
pip install scholar-inbox
```

**uv tool** (isolated install):

```bash
uv tool install scholar-inbox
```

### Setup

```bash
$ scholar-inbox setup
Scholar Inbox Setup

  ✓ Python 3.14.3
  ✓ scholar-inbox 0.1.0
  ✓ Logged in as: Jiahao Shao
  ✓ playwright-cli found
  ✓ NotebookLM skill installed
  ✓ NotebookLM batch-add script ready

  ✓ Setup complete! Mode: Enhanced (CLI + NotebookLM)

  Try: scholar-inbox digest --limit 5
```

If not logged in, setup will auto-extract your session or open a browser for Google OAuth.

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

**Paper details** — full abstract, method summary, and contributions:

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

**Batch add papers** — one command instead of 10 manual clicks:

```bash
scripts/add_to_notebooklm.sh <notebook-url> \
  https://arxiv.org/abs/2603.14821 \
  https://arxiv.org/abs/2603.14507 \
  https://arxiv.org/abs/2603.14398
# [1/3] Adding: https://arxiv.org/abs/2603.14821
#   ✓ Submitted
# [2/3] Adding: https://arxiv.org/abs/2603.14507
#   ✓ Submitted
# [3/3] Adding: https://arxiv.org/abs/2603.14398
#   ✓ Submitted
# Done: 3/3 sources added.
```

Then query NotebookLM via the `notebooklm` skill for source-grounded answers — ~500 tokens per query instead of ~50K tokens per PDF.

See [references/notebooklm.md](references/notebooklm.md) for the full Enhanced Mode workflow.

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
| `GET` | `/api/paper/{id}` | Get paper details |
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
