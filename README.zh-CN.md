# SJH Skills

[English](README.md) | 中文

> 一组用于科研工作流自动化的 Claude Code Skills。

## 技能列表

| Skill | 说明 |
|-------|------|
| [scholar-agent](skills/scholar-agent/) | 懂你品味的论文 Agent —— Scholar Inbox 个性化论文发现 + NotebookLM 无幻觉深度阅读 |
| [cmux](skills/cmux/) | 基于 Ghostty 的 Agent 友好终端 —— 多 Agent 编排、分屏启动 sub-Claude-Code 实例、内置浏览器、Markdown 预览、侧边栏进度报告 |
| [daily-summary](skills/daily-summary/) | 每日工作总结 —— 聚合 Claude Code sessions、git commits 和 Notion 任务，生成中文时间线式报告 |
| [notion-lifeos](skills/notion-lifeos/) | Notion 生活管理 —— PARA 方法 + Make Time 日记系统，通过 Notion API 用自然语言进行任务/笔记/日记的增删改查 |
| [web-fetcher](skills/web-fetcher/) | 网页 → 干净 Markdown，5 层 fallback：Jina Reader → defuddle.md → markdown.new → OpenCLI（带登录态的平台适配） → 原始 HTML |
| [init-project](skills/init-project/) | 初始化 Claude Code 项目配置 —— CLAUDE.md 骨架、Agent 模板、研究 profile |
| [project-review](skills/project-review/) | 项目战略全景审视 —— 自动发现战略文档，生成五维分析快照（vision、roadmap、瓶颈、related work、下一步） |
| [remote-cluster-agent](skills/remote-cluster-agent/) | 远程 GPU 集群操作 —— 本地编辑代码，通过 Go daemon + `rca` CLI（exec / batch / cp / nodes）远程执行，持久 SSH 连接池，节点健康监控 |
| [codex-review](skills/codex-review/) | 跨模型审查 —— 将计划或代码 diff 发送给 OpenAI Codex 独立验证，Claude↔Codex 迭代反馈直到通过（最多 5 轮） |
| [paper-analyzer](skills/paper-analyzer/) | 论文深度批判分析 —— 因果链方法论（现象→实验设置→归因→解法），NotebookLM 溯源阅读，可选研究框架映射 |
| [experiment-registry](skills/experiment-registry/) | ML 实验生命周期管理 —— 结构化 YAML 注册表 + CLI，支持实验注册、Benchmark 记录、跨实验对比、状态追踪 |
| [handoff](skills/handoff/) | Session 交接摘要 —— 在对话中直接打印结构化上下文摘要（状态、决策、坑、下一步），无缝衔接下个 session |
| [sync-docs](skills/sync-docs/) | 文档同步检查 —— 扫描近期代码变更，报告哪些文档（知识库、注册表、CLAUDE.md、规则、README）需要更新。只报告，不自动改 |
| [context-audit](skills/context-audit/) | Context 管理体检 —— 审计三层架构（CLAUDE.md / rules / knowledge）的渐进式披露合规性，检测孤立的 knowledge 文件、失效引用、CLAUDE.md 索引泄漏。只读 |
| [obsidian-brain](skills/obsidian-brain/) | ⏸️ **暂停** — Obsidian 第二大脑，双区 Vault 设计。已转向在 notion-lifeos 中增加反思命令 |

## 安装

### Claude Code Plugin（推荐）

```bash
/plugin marketplace add jiahao-shao1/sjh-skills
/plugin install sjh-skills@sjh-skills
/reload-plugins
```

### Codex

让 Codex 执行：

```
Fetch and follow instructions from https://raw.githubusercontent.com/jiahao-shao1/sjh-skills/refs/heads/main/.codex/INSTALL.md
```

或手动：

```bash
git clone https://github.com/jiahao-shao1/sjh-skills.git ~/.codex/sjh-skills
mkdir -p ~/.agents/skills
for skill in ~/.codex/sjh-skills/skills/*/; do
  ln -sf "$skill" ~/.agents/skills/$(basename "$skill")
done
```

详细文档：[.codex/INSTALL.md](.codex/INSTALL.md)

### npx（Cursor、Windsurf 等）

```bash
npx skills add jiahao-shao1/sjh-skills --skill scholar-agent
npx skills add jiahao-shao1/sjh-skills --skill cmux
```

安装全部：

```bash
npx skills add jiahao-shao1/sjh-skills
```

## 项目结构

```
sjh_skills/
└── skills/
    ├── scholar-agent/     # Scholar Inbox REST API + NotebookLM 批量深度阅读
    ├── cmux/              # Ghostty 终端编排 + 多 Agent 协调
    ├── daily-summary/     # git + Claude sessions + Notion 时间线聚合
    ├── notion-lifeos/     # PARA 方法 + Make Time 日记，通过 Notion API
    ├── web-fetcher/       # 5 层 fallback 网页内容提取
    ├── init-project/      # Claude Code 项目初始化和骨架搭建
    ├── project-review/    # 五维战略审视快照
    ├── remote-cluster-agent/ # 远程 GPU 集群操作，Go daemon + rca CLI
    ├── codex-review/          # 跨模型计划/代码审查，OpenAI Codex
    ├── paper-analyzer/        # 论文深度批判分析，因果链方法论
    ├── experiment-registry/   # ML 实验注册表，YAML + CLI
    ├── handoff/               # Session 交接摘要，上下文无缝衔接
    ├── sync-docs/             # 文档同步检查（只报告）
    └── context-audit/         # 渐进式披露合规审计（CLAUDE.md / rules / knowledge）
```

每个 skill 都是独立的，包含 `SKILL.md`、`scripts/` 和 `references/`。可以单独安装，也可以作为合集安装。

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

[MIT](LICENSE)
