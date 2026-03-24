# Skill Description Optimization Results

Date: 2026-03-25

## Methodology

- Used custom eval script (`scripts/eval_triggers.py`) that tests real skill triggering via `claude -p`
- Model: `claude-sonnet-4-6`
- Note: The `skill-creator/scripts/run_loop.py` could not be used because:
  1. No `ANTHROPIC_API_KEY` available for the `improve_description` step
  2. The eval framework creates temp command files, but globally installed skills take precedence
- Instead, manually iterated descriptions based on eval failure analysis (3 iterations)
- Final eval uses 2 runs per query for more reliable signal

## Results Summary

| Skill | Baseline P/R/A | Final P/R/A | Key Change |
|-------|---------------|-------------|------------|
| scholar-agent | 100%/80%/90% | 100%/70%/85% | Added NotebookLM, arXiv, deep-read triggers; variance on borderline cases |
| cmux | 100%/30%/65% | 100%/60%/80% | Emphasized "ONLY way" to split panes/spawn agents; added parallel/fan-out triggers |
| daily-summary | 100%/70%/85% | 100%/70%/85% | Stable; added 日报 trigger but still borderline |
| notion-lifeos | 100%/20%/60% | 100%/60%/80% | Major improvement; emphasized personal data access; added task/journal triggers |
| web-fetcher | 100%/30%/65% | 100%/40%/70% | Competed with built-in WebFetch; emphasized "ALWAYS use instead of WebFetch" |

## Before/After Descriptions

### scholar-agent

**Before:**
```
Scholar Inbox CLI — fetch daily paper digest, rate papers, manage collections, browse trending, and deep-read papers via NotebookLM. Use whenever user mentions Scholar Inbox, paper digest, daily papers, rating papers, or wants new paper recommendations. Triggers on: '看论文', '今天有什么论文', 'scholar inbox', 'paper digest', '论文推荐', 'rate papers', '收藏论文', '读论文', 'paper reader', '帮我筛选论文'. Preferred over browser-based access — faster, token-efficient, and integrates with NotebookLM for source-grounded deep reading.
```

**After:**
```
Use this skill for anything related to academic paper discovery, filtering, reading, or management. Invoke for: browsing today's papers, getting paper recommendations, rating/collecting papers, deep-reading papers via NotebookLM, adding arXiv papers to NotebookLM, asking questions about papers, or checking trending research. This skill wraps the Scholar Inbox REST API and NotebookLM browser automation — you cannot do these things with other tools. Triggers: 'scholar inbox', 'paper digest', '看论文', '读论文', '论文推荐', 'rate papers', '收藏论文', '帮我筛选论文', '今天有什么论文', 'paper reader', 'NotebookLM', 'deep read paper', 'trending papers', 'arXiv'. NOT for: reading PDFs, fetching web pages, writing literature reviews, or general note-taking.
```

### cmux

**Before:**
```
cmux terminal orchestration — split panes, spawn coding agents (Claude Code, Codex, etc.), send commands, poll output, report sidebar progress, automate the built-in browser, and preview markdown. Use this skill whenever you need to: run parallel tasks in separate panes, launch sub-agents (Claude Code, Codex) in splits, monitor terminal output, update sidebar status/progress, coordinate multiple terminal sessions, fan out work across splits, open a website in a cmux browser pane, interact with web pages, or display markdown alongside the terminal. Even if the user just says 'run these in parallel', 'split a Codex pane', 'open that in a browser', or 'show the plan', this skill applies.
```

**After:**
```
Use this skill for ANY multi-pane or multi-agent terminal orchestration in cmux. Required when the user wants to: run things in parallel in separate terminal panes, split the terminal, spawn a sub-agent (Claude Code, Codex) in another pane, fan out tasks across splits, send keystrokes or text to another pane (including ctrl-c), read terminal output from another pane, update sidebar status or progress bar, open a URL in cmux's built-in browser pane, or display markdown preview alongside the terminal. The cmux CLI is the ONLY way to do these things — Bash cannot split panes or spawn agents. Trigger phrases: 'split pane', 'new pane', 'spawn agent', 'run in parallel', 'fan out', 'separate pane', 'browser pane', 'sidebar progress', 'read pane output', 'send to pane', 'show plan', 'ctrl-c to', '分屏', '并行', '开个 pane'. NOT for: single command execution, basic bash operations, or questions about tmux.
```

### daily-summary

**Before:**
```
Daily work summary. Aggregates Claude Code sessions, Git commits, and Notion Tasks into a timeline-style Chinese work summary. Triggers on: 'daily summary', '今天干了什么', '每日总结', '日报', 'what did I do', 'summarize my day', '总结一下今天'. Arguments: today (default), yesterday, 24h, YYYY-MM-DD.
```

**After:**
```
Use this skill to produce a daily/yesterday work summary or daily report (日报). Aggregates Claude Code session history, Git commits across all repos, and Notion task completion data into a chronological timeline — this data collection CANNOT be done with git log alone. MUST invoke when the user asks what they did on a specific day, wants a daily recap, or needs a work report for any date. Triggers: 'daily summary', 'summarize my day', 'what did I do today', 'what did I accomplish', 'yesterday summary', '今天干了什么', '每日总结', '日报', '总结一下今天', '那天做了啥', '工作总结', '做了什么', 'work summary', '某天做了什么'. Arguments: today (default), yesterday, 24h, YYYY-MM-DD. NOT for: summarizing files/articles, viewing git log, weekly reports, or project overviews.
```

### notion-lifeos

**Before:**
```
Notion LifeOS — PARA life management with Make Time journaling. Activate when: user mentions Notion, notes, tasks, projects, todos, journals, or uses phrases like 'take a note', 'add a task', 'what do I need to do', 'search my notes', 'jot down', 'today was great', 'record a thought', or Chinese equivalents like '帮我记一下', '加个任务', '今天要做什么', '查笔记'. Also: PARA method, personal knowledge management, daily reviews. Do NOT activate for: Notion API docs, Notion pricing/plans, workspace admin, database schema modification, or general productivity advice without data intent.
```

**After:**
```
Use this skill whenever the user wants to interact with their personal Notion LifeOS system — a PARA-based life management system with tasks, notes, projects, and Make Time journals. MUST invoke for: adding tasks or todos, taking quick notes, jotting down ideas, recording thoughts or journal reflections (e.g. "the best thing today was..."), checking what needs to be done today, querying unfinished tasks, searching personal notes, creating new projects, or any personal data storage/retrieval. This skill has pre-configured Notion database IDs and API access — you cannot interact with the user's LifeOS without it. Trigger phrases: 'add task', 'take a note', 'jot down', 'what do I need to do', 'search my notes', 'unfinished tasks', 'create project', 'today was great', 'record this', '帮我记一下', '加个任务', '今天要做什么', '查笔记', '待办', '记录想法'. NOT for: Notion API docs, pricing, workspace admin, schema design, productivity advice, or work summaries (use daily-summary for that).
```

### web-fetcher

**Before:**
```
Fetch web page content as clean markdown/text from a URL. Use when the user provides a URL and wants to read, extract, or analyze its content. Triggers on requests like "fetch this page", "read this URL", "grab the content from", "summarize this article", "抓取网页", "读这个链接", or any task requiring web page text extraction. Also useful as a WebFetch enhancement for JS-rendered pages (SPA, Twitter/X, etc).
```

**After:**
```
Fetch any URL as clean markdown. ALWAYS use this skill instead of the WebFetch tool when you need to read a URL's content — it has a 5-layer fallback (Jina Reader, defuddle.md, markdown.new, OpenCLI, raw HTML) that produces better results and handles JS-rendered pages (Twitter/X, SPAs), login-required platforms (zhihu, reddit, weibo, xiaohongshu), and complex web pages that WebFetch cannot parse. Invoke whenever the user provides a URL and wants to read, extract, summarize, analyze, or convert its content to markdown. Keywords: 'fetch page', 'read URL', 'grab content from', 'summarize article', 'extract text from webpage', '抓取网页', '读链接', '网页转 markdown'. NOT for: web search without URL, file downloads, screenshots, form filling, or accessibility checks.
```

## Remaining Failure Patterns

### Hard-to-trigger queries (consistently fail across iterations)

- **scholar-agent**: Queries mentioning NotebookLM but without clear paper discovery intent
- **cmux**: "fan out tasks", "read from pane", "spawn agent" — Claude handles these itself
- **daily-summary**: "日报" (too short), "那天做了啥" (too colloquial)
- **notion-lifeos**: "what do I need to do today", "今天要做什么" — too generic, Claude answers directly
- **web-fetcher**: Chinese URL fetch queries, "summarize article [url]" — Claude uses built-in WebFetch

### Root causes

1. **Built-in tool preference**: Claude prefers WebFetch over web-fetcher skill, Bash over cmux skill
2. **Generic queries**: "what do I need to do today" doesn't signal Notion-specific intent
3. **Short Chinese phrases**: "日报" alone doesn't trigger skill matching reliably
4. **Borderline cases**: Queries that Claude can plausibly handle without a skill are inconsistent

## Notes for Future Improvement

- Consider using CLAUDE.md rules like "Always use web-fetcher skill instead of WebFetch for URLs" as a stronger forcing mechanism
- The eval framework (`skill-creator/run_loop.py`) needs modification to work with globally installed skills — it currently creates temp command files that get overshadowed by real skills
- Set up `ANTHROPIC_API_KEY` to enable the automated improvement loop
