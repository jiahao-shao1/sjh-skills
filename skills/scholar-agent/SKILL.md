---
name: scholar-agent
description: "Academic paper discovery / filtering / reading via Scholar Inbox API + notebooklm-py CLI. Use for browsing today's papers, recommendations, rate/collect, deep-read via NotebookLM, ask questions about papers, trending. Triggers: 'scholar inbox', 'paper digest', '看论文', '读论文', '论文推荐', 'rate papers', '今天有什么论文', 'deep read paper', '帮我筛选论文'. Not for PDF reading, lit reviews, or general notes."
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
| `playwright-cli` | Scholar Inbox browser login | `npm install -g @anthropic-ai/playwright-cli` |
| [notebooklm-py](https://github.com/teng-lin/notebooklm-py) | NotebookLM API (notebooks, sources, chat) | `pipx install "notebooklm-py[browser]"` |

- **Basic Mode** only requires `playwright-cli` (for Scholar Inbox login)
- **Enhanced Mode** additionally requires `notebooklm-py` with Google auth completed (`notebooklm login`)

### Why notebooklm-py?

Scholar Agent 的深度阅读功能通过 `notebooklm` CLI 实现：自动创建笔记本、批量添加 arXiv 论文为 source、查询 Gemini 获取 source-grounded 回答。notebooklm-py 使用 Google 内部 RPC API（非浏览器自动化），稳定性远高于 DOM 操作。

安装 notebooklm-py 后，你也可以独立使用它管理任意 NotebookLM 笔记本（不限于论文）：

```bash
notebooklm list                                    # 列出所有笔记本
notebooklm use <id>                                # 选择笔记本
notebooklm source add "https://arxiv.org/abs/..."  # 添加 source
notebooklm ask "summarize the key findings"        # 提问
```

## Setup

One-click environment check and login:
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox setup
```

Checks: Python → playwright-cli → Scholar Inbox login → notebooklm CLI

Manual install steps:
```bash
# 1. Scholar Inbox browser login (required)
npm install -g @anthropic-ai/playwright-cli

# 2. NotebookLM API (required for Enhanced Mode)
pipx install "notebooklm-py[browser]"

# 3. NotebookLM Google login (first time only — opens browser)
notebooklm login
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

Dispatch a subagent with **incremental output** — subagent must write results to a temp file after each step, so partial work survives if killed.

**Subagent prompt must include:**
```
将每一步的结果增量写入 /tmp/scholar_inbox_results.json。
每处理完一篇论文就更新文件，确保文件随时是有效 JSON。
格式：{"papers": [...], "status": "in_progress|done", "last_updated": "ISO8601"}
```

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
notebooklm list  # list all notebooks, find matching one by title
```

If no matching notebook exists, auto-create one:
```bash
notebooklm create "<topic>"
# Note the notebook ID from output, then set as active:
notebooklm use <notebook_id>
```

**Step A4: Batch Add Sources to NotebookLM**

Add arXiv URLs as sources to the target notebook:

```bash
notebooklm use <notebook_id>
notebooklm source add "https://arxiv.org/abs/XXXX.XXXXX"
notebooklm source add "https://arxiv.org/abs/YYYY.YYYYY"
# ... repeat for each paper
```

Check source status before querying (ensure status is "ready"):
```bash
notebooklm source list  # check all sources are "ready" before asking questions
```

Subagent returns: filtered paper list + classifications + ingestion status

**If subagent is killed**: Read `/tmp/scholar_inbox_results.json` for partial results. Continue from where it stopped — don't restart from scratch.

#### Phase B: Deep Reading [Main Context]

After receiving the paper list from the subagent, query NotebookLM:

```bash
notebooklm use <notebook_id>

# Overview
notebooklm ask "Summarize each paper's core contribution (2-3 sentences), label with paper title"

# Method comparison
notebooklm ask "Compare the methodological innovations, technical approaches, and baselines across papers"

# Relevance to user's research
notebooklm ask "How do these papers relate to [user interests]? Which findings are most actionable?"
```

**Follow-up is important**: Each `notebooklm ask` continues the conversation by default. If the answer is incomplete or raises new questions, keep asking. Use `--new` to start a fresh conversation.

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
3. Add arXiv URL: `notebooklm use <notebook_id> && notebooklm source add "https://arxiv.org/abs/XXXX.XXXXX"`
4. Wait for indexing: `notebooklm source wait`
5. Deep-read: `notebooklm ask "Summarize this paper's core contribution, method, and key findings"`
6. Output single-paper reading report

### Mode 3: `/scholar-inbox ask "question"`

Directly query NotebookLM:
```bash
notebooklm ask "question"  # uses current notebook context
# or specify notebook:
notebooklm ask -n <notebook_id> "question"
```

If no notebook is active, use `notebooklm use <id>` first or pass `-n`.

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
- Source limit: 50/notebook. Check with `notebooklm source list`. At 40+, warn user; at 50, create "Topic v2"
- Process at most 10 new papers per run

## Resilient Parallel Research

当需要多 agent 并行调研（如文献综述、领域调研）时，遵循以下模式防止全军覆没：

1. **最多 2-3 个并行 agent**，不要 5+（越多越容易被 kill）
2. **每个 agent 必须增量写文件**：`/tmp/research_{agent_name}.md`，每处理完一个 source 就更新
3. **文件随时可用**：写入的 markdown 必须是完整的（不是半截 JSON），即使中断也能直接读
4. **merge step 兼容 partial**：最终合并时读所有 `/tmp/research_*.md`，有多少用多少
5. **记录缺口**：如果某个 agent 没产出，在报告中标注"未覆盖：XXX 方向"

示例 agent prompt：
```
研究 [方向]。每分析完一篇论文，立即追加到 /tmp/research_[方向].md。
文件格式：每篇论文一个 ## 标题，包含要点和相关性评估。
确保文件随时是完整可读的 markdown。
```

## Constraints

| Rule | Reason |
|------|--------|
| REST API over DOM scraping | More stable, no SPA dependency |
| Dynamic classification, no hardcoded categories | Hardcoded categories go stale |
| Use `notebooklm` CLI for all NotebookLM operations | RPC API is more stable than browser DOM automation |
| Follow up on NotebookLM answers | First answer is often incomplete |

## Verified Behaviors

The following have been verified in production:

- `scholar-inbox status` / `digest` / `paper` / `rate` / `trending` / `collections`
- `scholar-inbox doctor --online`
- `notebooklm list` / `create` / `use` / `ask`
- `notebooklm source add <url>` (single + batch)
- `notebooklm auth check --test`

Still recommended to test:

- `scholar-inbox rate-batch`
- `scholar-inbox collect`
- Larger batch NotebookLM source imports (10+ papers)
- NotebookLM multi-turn follow-up conversations

## Error Handling

| Error | Action |
|-------|--------|
| `notebooklm` not installed | `pipx install "notebooklm-py[browser]"` or fall back to Basic Mode |
| NotebookLM auth expired | `notebooklm login` (opens browser for Google login) |
| Source addition failed | Skip that paper, continue with the rest |
| NotebookLM rate limit | Fall back to Basic Mode |
| Scholar Inbox session expired | `scholar-inbox login --browser` to re-login |

Run diagnostics:

```bash
scholar-inbox doctor              # Scholar Inbox login + basic checks
notebooklm auth check --test      # NotebookLM auth + cookie health
```

## When to Use Browser Instead

- **Scholar Maps** — interactive visualization
- **Full PDF inline** — scholar-inbox.com's PDF viewer
