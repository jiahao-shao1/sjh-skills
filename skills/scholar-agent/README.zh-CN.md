# Scholar Agent

[English](README.md) | 中文

> 懂你品味的论文 Agent —— [Scholar Inbox](https://www.scholar-inbox.com) 个性化论文发现 + [NotebookLM](https://notebooklm.google.com) 无幻觉深度阅读。

## 为什么需要它

读论文的流程是碎的：

1. **找论文**：打开 Scholar Inbox，翻 50+ 篇，逐个点进去判断相关性。30 分钟没了。
2. **读论文**：挑出 10 篇感兴趣的，每篇 10-20 页。要么略读（漏细节），要么精读（一下午没了）。
3. **让 AI 帮忙**：喂 PDF 给 Claude/GPT，一篇 ~50K tokens，10 篇直接爆 context。而且 AI 不了解你的品味，没法帮你筛。

**Scholar Agent 组合两个现有服务解决这两个问题：**

- **Scholar Inbox** 已经了解你的品味（追踪你的 upvote/downvote，建立个性化排序模型）。我们逆向了它的 REST API，可以编程访问。
- **NotebookLM** 已经会读论文（摄入 PDF，提取结构化内容，回答基于源文档的问题——零幻觉）。查询只需 ~500 tokens，而非 ~50K。

## 功能

- **每日推荐** — 获取今天的个性化论文推荐，带评分、关键词和 AI 摘要
- **论文评分** — 点赞/点踩，持续优化推荐
- **收藏夹** — 将论文整理到命名集合
- **热门论文** — 发现各类别的热门论文
- **NotebookLM 深度阅读** — 通过 [notebooklm-py](https://github.com/teng-lin/notebooklm-py) 批量添加论文，无幻觉问答
- **零依赖** — 核心功能纯 Python stdlib

## 安装

```bash
npx skills add jiahao-shao1/sjh-skills --skill scholar-agent
```

## 快速开始

```bash
# 1. 安装 NotebookLM API（深度阅读需要）
pipx install "notebooklm-py[browser]"

# 2. 登录（各服务首次需要）
npm install -g @anthropic-ai/playwright-cli  # Scholar Inbox 浏览器登录
notebooklm login                     # Google 登录 — 打开浏览器
PYTHONPATH=~/.claude/skills/scholar-agent python3 -m scholar_inbox login --browser  # Scholar Inbox
```

## 使用

在 Claude Code 中自然语言交互：

```
> 今天有什么好论文
> 看看关于 RL for VLM 的推荐
> 帮我点赞论文 94712
> 这周有什么热门论文
> 把这 10 篇论文读一下，总结关键 idea
```

## CLI 命令

| 命令 | 说明 |
|------|------|
| `scholar-inbox setup` | 一键环境检查 + 登录 |
| `scholar-inbox digest [--limit N]` | 今日推荐论文 |
| `scholar-inbox paper ID` | 论文详情 + AI 摘要 |
| `scholar-inbox rate ID up/down` | 评分 |
| `scholar-inbox rate-batch RATING ID...` | 批量评分 |
| `scholar-inbox trending [--days N]` | 热门论文 |
| `scholar-inbox collections` | 查看收藏 |
| `scholar-inbox collect ID COLLECTION` | 添加到收藏 |

## NotebookLM 深度阅读

不让 Claude 直接读 PDF（贵且易幻觉），而是批量加载到 NotebookLM，由 Gemini 基于源文档回答问题。

```bash
notebooklm create "RL Papers"
notebooklm use <notebook_id>
notebooklm source add "https://arxiv.org/abs/2602.01334"
notebooklm ask "对比这些论文的核心发现"
```

## 许可证

MIT
