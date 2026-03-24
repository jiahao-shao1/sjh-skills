---
name: scholar-agent
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
python3 ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py setup
```

## 筛选配置

配置文件在 `~/.config/scholar-inbox/`：

| 文件 | 作用 |
|------|------|
| `context.md` | 全局偏好（研究方向、机构分级、每日篇数等） |
| `<project>.md` | 项目级配置（关键词过滤 + NotebookLM 分类规则） |

执行 `/scholar-inbox` 时，根据当前工作目录的项目名加载对应配置文件。如果存在项目配置，按其中的关键词和机构分级过滤论文列表，并按分类规则将论文归入对应 NotebookLM notebook。

### 首次配置

首次执行 `/scholar-inbox` 时，检查 `~/.config/scholar-inbox/context.md` 是否存在：

- **存在** → 读取配置，直接进入正常流程
- **不存在** → 用 AskUserQuestion 交互式收集偏好，生成配置文件

#### 第 1 轮：研究偏好（同时问 3 个问题）

1. **研究方向**
   - header: "研究方向关键词"
   - 选项: "RL, VLM, visual reasoning" / "NLP, LLM, alignment" / Other（自定义）
   - preview: `用于论文筛选时的相关性排序\n示例: "reinforcement learning, vision-language model, tool use"`

2. **机构偏好**
   - header: "机构分级"
   - 选项: "区分（顶级 > 知名 > 其他）" / "不区分"
   - preview: `区分时：OpenAI/DeepMind/META 等优先展示`

3. **每日篇数**
   - header: "每天想看几篇"
   - 选项: "5" / "10" / "15"

#### 第 2 轮：分类 + 项目（同时问 2 个问题）

4. **NotebookLM 分类方式**
   - header: "论文分类到 notebook 的维度"
   - 选项: "按研究主题自动分类" / "按方法类型（RL / SFT / 数据 / 评估）" / "全部放一个 notebook"

5. **项目级配置**
   - header: "是否需要项目级筛选"
   - 选项: "需要（在特定项目目录下只看该项目相关论文）" / "不需要"
   - 如果选「需要」，追问当前项目的核心关键词

#### 生成配置

根据用户回答，生成 `~/.config/scholar-inbox/context.md`：

```markdown
# Scholar Inbox 全局配置

## 研究方向
keywords: RL, VLM, visual reasoning, tool use

## 筛选偏好
daily_limit: 10
institution_tier: true  # 是否区分机构分级

## NotebookLM 分类
mode: auto_topic  # auto_topic / method_type / single_notebook
```

如果用户启用了项目级配置，额外生成 `~/.config/scholar-inbox/<project>.md`：

```markdown
# <project> 项目配置

## 项目关键词
keywords: agentic reasoning, image editing, multi-turn tool use

## 筛选规则
仅展示与项目关键词匹配的论文，其余论文降低优先级但不隐藏。
```

后续可手动编辑配置文件调整。

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
python3 ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py search --query "<topic>"
```

如果没有匹配的 notebook，用脚本自动创建：
```bash
NB_URL=$(bash <skill-path>/scripts/create_notebook.sh)
# 注册到本地 library
python3 ~/.claude/skills/notebooklm/scripts/run.py notebook_manager.py add \
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

脚本内部流程已改为显式策略路由：
1. `playwright-cli open --browser=chrome --profile=<notebooklm-profile>` 打开 notebook
2. 探测当前 source 进入策略：
   - `open_source_dialog`
   - `open_website_form`
   - `url_input_ready`
3. 进入 URL 输入界面后一次性批量粘贴多个 URL
4. 点击 `插入 / Insert`
5. `playwright-cli close`

Browser profile 路径：`$NOTEBOOKLM_PROFILE`（默认 `~/.claude/skills/notebooklm/data/browser_state/browser_profile`）

Subagent 返回：筛选后的论文列表 + 分类 + 入库状态

#### Phase B: 深度阅读 [主 Context]

拿到 subagent 返回的论文列表后，调 notebooklm skill 提问：

```bash
NOTEBOOKLM="python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py"

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
python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py \
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
| NotebookLM UI 识别优先走策略路由 | 进入 notebook 时的初始 UI 状态不稳定，不能假设永远先看到同一个按钮 |
| 深度阅读用 notebooklm skill scripts | 可靠性、认证管理、venv 隔离 |
| Follow-up NotebookLM 回答 | 第一次回答常不完整 |

## 已实际验证

以下行为已在真实环境中验证通过：

- `scholar-inbox status`
- `scholar-inbox digest`
- `scholar-inbox paper`
- `scholar-inbox rate <id> up`
- `scholar-inbox rate <id> reset`
- `scholar-inbox trending`
- `scholar-inbox collections`
- `create_notebook.sh`
- `rename_notebook.sh`
- `add_to_notebooklm.sh` 单篇添加
- `add_to_notebooklm.sh` 3 篇批量添加
- `ask_question.py`
- `scholar-inbox doctor --online`

仍建议继续补测：

- `scholar-inbox rate-batch`
- `scholar-inbox collect`
- `scholar-inbox read`
- 更大批量的 NotebookLM source 导入
- NotebookLM 多轮 follow-up 对话

## Error Handling

| 错误 | 处理 |
|------|------|
| NotebookLM skill 未安装 | 降级到 Basic Mode |
| Google auth 过期 | `python3 ~/.claude/skills/notebooklm/scripts/run.py auth_manager.py reauth` |
| Source 添加失败 | 跳过该论文，继续处理其余 |
| NotebookLM rate limit | 降级到 Basic Mode |
| Scholar Inbox session 过期 | `scholar-inbox login --browser` 重新登录 |
| `add_to_notebooklm.sh` 找不到 “添加来源 / Add source” 按钮 | 先怀疑 NotebookLM UI 改版。不要反复重试脚本；改用 `playwright-cli snapshot` 检查真实按钮文本和 ref，再手动点击当前 UI 中的 “添加来源” / “网站” / “插入” |
| `ask_question.py` 报 `Failed to create a ProcessSingleton` 或 `SingletonLock` | NotebookLM Chrome profile 仍被残留 Chromium 进程占用。先执行 `pkill -f '/Users/$USER/.claude/skills/notebooklm/data/browser_state/browser_profile'` 或按实际 profile 路径 `pkill -f '<profile-path>'`，等待 1-2 秒后再重试 |

优先先跑：

```bash
scholar-inbox doctor
scholar-inbox doctor --online
```

它会检查：
- Scholar Inbox 登录是否有效
- NotebookLM skill / browser profile / state.json 是否存在
- `add_to_notebooklm.sh` / `create_notebook.sh` / `rename_notebook.sh` / `notebooklm_site_knowledge.sh` 是否齐全
- 当前是否有进程占用 NotebookLM profile
- `--online` 时还会真实打开 Scholar Inbox / NotebookLM 页面做只读探测

### NotebookLM Troubleshooting

#### 1. `add_to_notebooklm.sh` 因 UI 改版失效

现象：
- 脚本直接退出
- `bash -x add_to_notebooklm.sh ...` 显示 `ADD_BTN=` 或找不到 `网站` / `Insert` 按钮

推荐处理：

```bash
# 1. 打开 notebook
playwright-cli open --browser=chrome --profile="$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile" "<notebook-url>"
sleep 6

# 2. 抓当前 DOM 快照
playwright-cli snapshot

# 3. 在快照里找真实按钮文案和 ref
rg -n '添加来源|Add source|网站|Website|输入网址|插入|Insert' .playwright-cli/*.yml
```

如果脚本里的文案匹配失效，按快照中的真实 ref 手动执行：

```bash
playwright-cli click <add-source-ref>
playwright-cli click <website-ref>
playwright-cli fill <url-input-ref> "https://arxiv.org/abs/XXXX https://arxiv.org/abs/YYYY"
playwright-cli click <insert-ref>
```

经验规则：
- NotebookLM 当前 UI 可能在进入 notebook 后已经自动弹出 “添加来源” 对话框，此时无需再点一次旧按钮
- `网站和 YouTube 网址` 页面支持空格或换行批量粘贴多个 URL
- 修脚本前先用一次手工 ref 验证流程，确认不是 auth 或 profile 问题

#### 2. `ask_question.py` 被 NotebookLM profile 锁住

现象：
- `BrowserType.launch_persistent_context: Failed to create a ProcessSingleton`
- 报错里出现 `SingletonLock` / `profile directory is already in use`

原因：
- 上一步 `playwright-cli open` 或其他 Chrome headless 进程没有完全退出
- 同一个 NotebookLM browser profile 被多个会话同时占用

推荐处理：

```bash
# 查残留进程
ps aux | rg 'browser_profile|Google Chrome|Chromium'

# 杀掉占用 NotebookLM profile 的进程
pkill -f "$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile" || true
sleep 2

# 再次确认没有残留
ps aux | rg "$HOME/.claude/skills/notebooklm/data/browser_state/browser_profile" || true
```

然后再执行：

```bash
python3 ~/.claude/skills/notebooklm/scripts/run.py ask_question.py \
  --notebook-url "<notebook-url>" \
  --question "..."
```

经验规则：
- 连续执行 `create_notebook.sh` → `add_to_notebooklm.sh` → `ask_question.py` 时，步骤间最好显式留 `sleep 2-3`
- 如果刚用 `playwright-cli` 手工调过 NotebookLM，再跑 `ask_question.py` 前优先检查 profile 锁
- `playwright-cli close` 只能关闭它自己管理的浏览器；遇到残留 headless Chrome，还是要 `pkill -f '<profile-path>'`

## When to Use Browser Instead

- **Scholar Maps** — interactive visualization
- **Full PDF inline** — scholar-inbox.com's PDF viewer
