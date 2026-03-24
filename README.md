# Scholar Inbox CLI

> CLI & Python SDK for [Scholar Inbox](https://www.scholar-inbox.com) — your daily paper digest, without the browser.

[![PyPI version](https://img.shields.io/pypi/v/scholar-inbox)](https://pypi.org/project/scholar-inbox/)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Daily Digest** — fetch today's recommended papers with scores, keywords, and AI summaries
- **Rate Papers** — thumbs up/down to improve your recommendations
- **Collections** — organize papers into named collections
- **Trending** — discover trending papers across categories
- **Claude Code Skill** — natural language interaction via Claude Code
- **NotebookLM Integration** — deep reading with Google's AI (optional, requires playwright-cli)
- **Zero Dependencies** — pure Python stdlib, works everywhere

## Quick Start

### Install

**Claude Code skill** (recommended for Claude Code users):

```bash
claude install-skill https://github.com/jiahao-shao1/scholar-inbox
```

**pip:**

```bash
pip install scholar-inbox
```

**uv tool** (isolated install):

```bash
uv tool install scholar-inbox
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

3. [94601] 0.941 -- Efficient Fine-Tuning of Vision-Language Models via Adaptive LoRA
   Wang et al.
   Affiliations: Tsinghua University
   Keywords: LoRA, vision-language models, fine-tuning
   https://arxiv.org/abs/2603.14398
   > Adaptive rank allocation for LoRA reduces parameters by 40% while maintaining performance

4. [94587] 0.928 -- Self-Reflective Agents for Scientific Discovery
   Chen et al.
   Affiliations: MIT, Allen AI
   Keywords: agents, scientific discovery, self-reflection
   https://arxiv.org/abs/2603.14255
   > Demonstrates self-reflective agents can autonomously design and iterate on experiments

5. [94523] 0.912 -- Towards Unified Evaluation of Multimodal Reasoning
   Park et al.
   Affiliations: Seoul National University, KAIST
   Keywords: evaluation, multimodal reasoning, benchmarks
   https://arxiv.org/abs/2603.14102
   > A unified benchmark covering 12 reasoning dimensions across vision-language tasks
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
Affiliations: Stanford University, Google DeepMind
Published: 2026-03-23 | NeurIPS 2026
Ranking Score: 0.971
ArXiv: https://arxiv.org/abs/2603.14821
Keywords: visual reasoning, chain-of-thought, verification

## Abstract
We present a grounded verification mechanism for visual chain-of-thought
reasoning that systematically validates each reasoning step against the
visual input...

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
$ scholar-inbox trending --days 7 --limit 3
# Trending Papers (last 7 days, category: ALL)

1. [93201] Large Concept Models: Language Modeling in a Sentence Representation Space
   Meta AI
   https://arxiv.org/abs/2603.12345

2. [93198] Reasoning with Reinforced Fine-Tuning
   DeepSeek AI
   https://arxiv.org/abs/2603.12340

3. [93185] Unified Multimodal Understanding and Generation
   Google DeepMind
   https://arxiv.org/abs/2603.12330
```

**Collections** — organize papers:

```bash
# List your collections
$ scholar-inbox collections
# Collections

  [1] Reading List (23 papers)
  [2] RL for LLM (15 papers)
  [3] Visual Reasoning (8 papers)

# Add a paper to a collection (by name or ID)
scholar-inbox collect 94712 "Visual Reasoning"
scholar-inbox collect 94658 2
```

**Mark as read:**

```bash
scholar-inbox read 94712
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

When installed as a Claude Code skill, you can interact with Scholar Inbox using natural language:

```
> Show me today's top papers about reinforcement learning
> Rate paper 94712 thumbs up
> What's trending in AI this week?
> Add paper 94658 to my "RL for LLM" collection
> Show me the details of paper 94712
```

## NotebookLM Enhanced Mode

For deep reading, Scholar Inbox can integrate with Google NotebookLM to generate podcast-style audio summaries of papers. This is an optional feature that requires `playwright-cli`.

See [references/notebooklm.md](references/notebooklm.md) for the concept and setup.

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
