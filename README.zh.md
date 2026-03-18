# Notion LifeOS Skill

[English](README.md) | 中文

> **人类的记忆系统** — 一个可扩展的自我觉察系统，捕获你数十年间的想法、决策和成长。

一个**与 Agent 无关**的 Notion LifeOS skill，基于 PARA 方法和 Make Time 框架。支持 **Claude Code、OpenClaw、Codex** 及任何能与 Notion 交互的 AI Agent。

## 愿景

这不只是一个效率工具 — 它是一个**长期记忆架构**，旨在：

1. **实时捕获你的思考** — 零延迟的想法捕获，确保没有任何思绪被遗漏
2. **跨越数十年的积累** — 构建你认知演变的完整记录
3. **让 AI 重建你** — 10 年后，AI 可以从这些数据中重建「你」

### 核心设计原则

**1. 前后端分离**
- **前端：** Notion（用户界面，用于捕获和查看）
- **后端：** AI Agent（自动化、处理、洞察）
- 这种分离让你可以更换工具，而不会丢失数据结构

**2. 数据库分离（DP 原则）**
- **写入：** 即时、无摩擦的捕获 — 没有处理开销
- **处理：** 延迟的、AI 驱动的组织和洞察提取
- **哲学：** 先捕获，后整理。永不让处理阻塞输入。

**3. 可扩展的自我觉察**
- 每条笔记、任务和决策都成为一个数据点
- 随着时间推移，模式浮现：你如何思考、你重视什么、你如何成长
- AI 可以分析数十年的数据来理解你的认知指纹
- **终极目标：** 一个像你一样思考的 AI，基于你真实的思维过程训练

### 为什么这很重要

大多数效率系统优化的是**做事**。LifeOS 优化的是**成为**。

- **短期：** 高效管理任务和项目
- **中期：** 理解你的模式，改善决策
- **长期：** 创建一个保留你思维方式的数字认知双生体

**10 年后，一个基于你的 LifeOS 数据训练的 AI 可以：**
- 像你一样做决策
- 预测你会对什么感兴趣
- 向他人解释你的推理过程
- 在你离开后继续你的工作

这是**作为基础设施的记忆** — 不仅用于回忆，更用于重建。

## 功能特点

- 自然语言创建/查询任务、笔记、项目、领域、资源
- Make Time 每日日记（亮点 / 感恩 / 放下）
- 完整 PARA 系统，支持跨数据库 Relations
- 多 Agent 支持：Notion MCP（Claude）+ REST API（任意 Agent）

## 快速开始

### 1. 获取 Notion 模板

复制预配置模板：

👉 **https://jiahaoshao.notion.site/lifeos-template**

所有数据库和 Relations 已预配置，开箱即用。

### 2. 安装 Skill

```bash
# 克隆到 Agent 的 skill 目录
git clone https://github.com/jiahao-shao1/notion-lifeos-skill.git notion-lifeos
```

### 3. 配置

```bash
cd notion-lifeos
cp CONFIG.private.md.example CONFIG.private.md
# 编辑 CONFIG.private.md，填入你的数据库 ID
```

详细配置请参考 [references/setup.md](./references/setup.md)。

## 使用方式

配置完成后，使用自然语言：

```
"帮我记一下，刚才开会讨论了 Q2 OKR"
"加个任务：周五前完成竞品分析报告"
"今天最开心的事是项目上线了，感恩团队的支持"
"最近有什么任务没做完？"
"查一下关于 AI 的笔记"
```

## 架构

```
SKILL.md                    ← 核心：意图识别 + 业务规则 + 错误处理（agent-agnostic）
references/
├── schema.md               ← PARA 数据库字段定义
├── mcp-guide.md            ← Claude Code / Claude.ai（Notion MCP）
├── api-guide.md            ← OpenClaw / Codex / 其他（REST API）
└── setup.md                ← 多平台配置指南
JEFF_SU_SUMMARY.md          ← 设计理念参考
CONFIG.private.md.example   ← 数据库 ID 配置模板
```

**知识层与执行层分离：** SKILL.md 只描述数据模型和工作流逻辑，不绑定特定工具。Agent 根据自身环境读取对应的执行指南。

## 支持的 Agent

| Agent | 执行方式 | 参考文档 |
|-------|---------|---------|
| Claude Code | Notion MCP 工具 | [mcp-guide.md](./references/mcp-guide.md) |
| Claude.ai | Notion MCP 工具 | [mcp-guide.md](./references/mcp-guide.md) |
| OpenClaw | Notion REST API | [api-guide.md](./references/api-guide.md) |
| Codex | Notion REST API | [api-guide.md](./references/api-guide.md) |
| 其他 Agent | Notion REST API | [api-guide.md](./references/api-guide.md) |

## 数据库结构

六个互相关联的数据库：

| 数据库 | 标题属性 | 关键字段 |
|--------|---------|---------|
| Task | Name | Done, Due Date, Related Projects/Notes |
| Notes | Note | Note Type, Tags, Status, Related Projects/Areas/Resources |
| Projects | Log name | Status, End Date, Related Areas/Resources/Notes |
| Areas | Blog name | type, Related Notes/Resources |
| Resources | Note | Resources Type, URL, Related Areas/Projects/Notes |
| Make Time | Name | Date, Highlight, Grateful, Let Go |

完整字段定义见 [references/schema.md](./references/schema.md)。

## Roadmap

- [ ] Agent 驱动的数据迁移（Apple Notes、Obsidian、Bear、Evernote）
- [ ] 批量操作
- [ ] 智能标签
- [ ] 周报/月报工作流

## License

MIT

## Author

Created by [Jiahao Shao](https://github.com/jiahao-shao1)

## 致谢

- Notion 核心实现逻辑来自 [Jeff Su 的 Notion Command Center](https://www.youtube.com/@JeffSu)
- 基于 Tiago Forte 的 **PARA 方法**
- 融合 Jake Knapp 和 John Zeratsky 的 **Make Time 框架**

**免责声明：** 基于公开内容的独立实现，与任何付费课程无关。
