---
name: scholar-inbox
description: "Scholar Inbox CLI — fetch daily paper digest, rate papers, manage collections, browse trending, and deep-read papers via NotebookLM. Use whenever user mentions Scholar Inbox, paper digest, daily papers, rating papers, or wants new paper recommendations. Triggers on: '看论文', '今天有什么论文', 'scholar inbox', 'paper digest', '论文推荐', 'rate papers', '收藏论文', '读论文', 'paper reader', '帮我筛选论文'. Preferred over browser-based access — faster, token-efficient, and integrates with NotebookLM for source-grounded deep reading."
---

# Scholar Agent

论文发现 → 筛选 → 深度阅读 → 反馈的全流程自动化。

两种模式：
- **Basic Mode**: Pure CLI — fetch, filter, rate papers via REST API (no browser needed)
- **Enhanced Mode**: CLI + NotebookLM — deep-read papers with source-grounded answers from Gemini

## 子命令

| 命令 | 说明 |
|------|------|
| `/scholar-inbox` | 今日论文 → AI 筛选 → 加入 NotebookLM → 深度阅读 → 报告 |
| `/scholar-inbox <arXiv ID>` | 指定论文加入 NotebookLM 并阅读 |
| `/scholar-inbox ask "问题"` | 向 NotebookLM 论文库提问 |
| `/scholar-inbox like 1,3,5` | 给报告中指定编号的论文点赞 |

## Prerequisites

| 依赖 | 用途 | 安装方式 |
|------|------|---------|
| `playwright-cli` | 浏览器登录 + NotebookLM 操作 | `npm install -g @anthropic-ai/playwright-cli` |
| `notebooklm` skill | Enhanced Mode 深度阅读 (可选) | `npx skills add notebooklm` |

- **Basic Mode** 只需 `playwright-cli`（用于首次登录）
- **Enhanced Mode** 额外需要 `notebooklm` skill 并完成 Google 认证

## Setup

一键检查环境和登录：
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox setup
```

检查项：Python → playwright-cli → Scholar Inbox 登录 → NotebookLM skill → add_to_notebooklm.sh

手动安装步骤：
```bash
# 1. 浏览器自动化（必须）
npm install -g @anthropic-ai/playwright-cli

# 2. NotebookLM skill（Enhanced Mode 必须）
npx skills add notebooklm

# 3. NotebookLM Google 登录（仅首次）
python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup
```

## CLI Quick Reference

**Running the CLI**: If `scholar-inbox` is not on PATH:
```bash
PYTHONPATH=<skill-path> python3 -m scholar_inbox <command>
```

| Command | Description |
|---------|-------------|
| `scholar-inbox setup` | One-click environment check + login |
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

## 执行流程

### 模式 1: `/scholar-inbox`（每日论文筛选 + 阅读）

#### Phase A: 收集 + 筛选 + 入库 [派 Subagent 后台执行]

派一个 subagent 执行以下步骤，完成后返回筛选结果和入库状态：

**Step A1: 从 Scholar Inbox 抓取论文（REST API）**

```bash
scholar-inbox digest --json --limit 20
scholar-inbox config  # get user's research interests
```

**Step A2: AI 筛选**

根据用户 research interests 筛选 top 5-10 最相关论文。跳过已评分/已读论文。
如果未配置 interests，按 score 排序取 top 10。

**Step A3: 动态分类**

根据标题和关键词自动分类到 NotebookLM notebook。分类名从论文内容动态生成，不使用硬编码分类。

每个分类对应一个 NotebookLM notebook。查找已有 notebook：
```bash
python ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py search --query "<topic>"
```

如果没有匹配的 notebook，用脚本自动创建：
```bash
NB_URL=$(bash <skill-path>/scripts/create_notebook.sh)
# 注册到本地 library
python ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py add \
  --url "$NB_URL" --name "<topic>" --description "<desc>" --topics "<t1,t2>"
```

**注意**：连续执行 create → add 等多步 playwright-cli 操作时，步骤间需 `sleep 2-3` 等 browser session 完全关闭。

**Step A4: 批量添加到 NotebookLM**

使用 `add_to_notebooklm.sh` 脚本（通过 playwright-cli + NotebookLM browser profile）：

```bash
bash <skill-path>/scripts/add_to_notebooklm.sh \
  "<notebook_url>" \
  "https://arxiv.org/abs/XXXX.XXXXX" \
  "https://arxiv.org/abs/YYYY.YYYYY"
```

脚本内部流程：
1. `playwright-cli open --browser=chrome --profile=<notebooklm-profile>` 打开 notebook
2. `playwright-cli snapshot` 获取 DOM → grep 找到搜索框 ref
3. `playwright-cli fill <ref> <url>` + `playwright-cli press Enter` 提交每个 URL
4. 循环处理所有 URL，最后 `playwright-cli close`

Browser profile 路径：`$NOTEBOOKLM_PROFILE`（默认 `~/.claude/skills/notebooklm/data/browser_state/browser_profile`）

Subagent 返回：筛选后的论文列表 + 分类 + 入库状态

#### Phase B: 深度阅读 [主 Context]

拿到 subagent 返回的论文列表后，调 notebooklm skill 提问：

```bash
NOTEBOOKLM="python ~/.claude/skills/notebooklm/scripts/run.py ask_question.py"

# 概览
$NOTEBOOKLM --question "总结每篇论文的核心贡献（2-3 句），标注论文标题" --notebook-url "$URL"

# 方法对比
$NOTEBOOKLM --question "对比各论文的方法创新、技术路线和 baseline" --notebook-url "$URL"

# 与用户研究的关联
$NOTEBOOKLM --question "这些论文与 [user interests] 有何关联？哪些发现最可落地？" --notebook-url "$URL"
```

**Follow-up 很重要**：NotebookLM 回答末尾常问 "还需要了解什么？" — 如果回答不完整或有新问题，继续追问。

#### Phase C: 输出阅读报告

```markdown
## YYYY-MM-DD 论文阅读报告 (N 篇新增)

### 分类: RL Reward Design

#### 1. Paper Title | Author et al. (Institution)
- **Paper ID**: 4626954 | **Score**: 0.880
- **arXiv**: https://arxiv.org/abs/XXXX.XXXXX
- **核心发现**：[from NotebookLM, with citation]
- **方法**：[key technical details]
- **与项目关联**：[how it connects to user's work]

#### 2. ...

---
👍 点赞: `/scholar-inbox like 1,3`
👎 踩: `scholar-inbox rate-batch down <id1> <id2>`
```

### 模式 2: `/scholar-inbox <arXiv ID>`

1. 用 `scholar-inbox paper <id>` 获取论文信息（如果是 paper_id）
2. 根据标题关键词动态分类到对应 notebook
3. `add_to_notebooklm.sh` 添加 arXiv URL 到 notebook
4. NotebookLM skill 提问深度阅读
5. 输出单篇阅读报告

### 模式 3: `/scholar-inbox ask "问题"`

直接调 NotebookLM skill 向 notebook 提问：
```bash
python ~/.claude/skills/notebooklm/scripts/run.py ask_question.py \
  --question "问题" --notebook-url "<url>"
```

如果不指定 notebook，使用最近活跃的 notebook。

### 模式 4: `/scholar-inbox like 1,3,5`

从最近一次阅读报告中提取对应编号的 paper_id，调 REST API 批量点赞：
```bash
scholar-inbox rate-batch up <id1> <id2> <id3>
```

## Basic Mode（无 NotebookLM）

适用于快速浏览、不需要深度阅读的场景：

```bash
scholar-inbox digest --limit 10          # 今日论文列表
scholar-inbox digest --min-score 0.8     # 高分论文
scholar-inbox paper <id>                 # 论文详情（含 Scholar Inbox AI 摘要）
scholar-inbox trending --days 7          # 近 7 天热门
scholar-inbox rate <id> up               # 点赞
scholar-inbox rate-batch down 111 222    # 批量踩
```

**展示论文时**：显示 title, paper_id, score, keywords, one-line contribution, arXiv link。

## Notebook 生命周期

- Notebook 跨 session 积累知识 — 今天加的论文明天仍可查询
- Source 上限 50/notebook。接近 40 时提醒用户，满 50 创建 "Topic v2"
- 每次最多处理 10 篇新论文
- 用完 playwright-cli 必须 `close`

## 约束

| 规则 | 原因 |
|------|------|
| REST API 优先于 DOM scraping | 更稳定，不依赖 SPA 结构 |
| 动态分类，不硬编码分类名 | 硬编码分类会过时 |
| 添加 source 用 `add_to_notebooklm.sh` | 已验证可用，处理了 playwright-cli 行为 |
| 深度阅读用 notebooklm skill scripts | 可靠性、认证管理、venv 隔离 |
| Follow-up NotebookLM 回答 | 第一次回答常不完整 |

## Error Handling

| 错误 | 处理 |
|------|------|
| NotebookLM skill 未安装 | 降级到 Basic Mode |
| Google auth 过期 | `python ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py reauth` |
| Source 添加失败 | 跳过该论文，继续处理其余 |
| NotebookLM rate limit | 降级到 Basic Mode |
| Scholar Inbox session 过期 | `scholar-inbox login --browser` 重新登录 |

## When to Use Browser Instead

- **Scholar Maps** — interactive visualization
- **Full PDF inline** — scholar-inbox.com's PDF viewer
