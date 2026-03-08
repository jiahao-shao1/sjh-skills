# Notion LifeOS Skill

> **Memory System for Human** — A scalable self-awareness system that captures your thoughts, decisions, and growth over decades.

An **agent-agnostic** Notion LifeOS skill based on the PARA method and Make Time framework. Works with **Claude Code, OpenClaw, Codex**, and any AI agent that can interact with Notion.

## Features

- Natural language to create/query tasks, notes, projects, areas, resources
- Make Time daily journal (Highlight / Grateful / Let Go)
- Full PARA system with cross-database Relations
- Multi-agent support: Notion MCP (Claude) + REST API (any agent)

## Quick Start

### 1. Get the Notion Template

Duplicate the pre-configured template:

👉 **https://jiahaoshao.notion.site/lifeos-template**

All databases and Relations are pre-configured — works out of the box.

### 2. Install the Skill

```bash
# Clone to your agent's skill directory
git clone https://github.com/jiahao-shao1/notion-lifeos-skill.git notion-lifeos
```

### 3. Configure

```bash
cd notion-lifeos
cp CONFIG.private.md.example CONFIG.private.md
# Edit CONFIG.private.md with your database IDs
```

See [references/setup.md](./references/setup.md) for detailed setup instructions for each agent platform.

## Usage

Once configured, use natural language:

```
"帮我记一下，刚才开会讨论了 Q2 OKR"
"加个任务：周五前完成竞品分析报告"
"今天最开心的事是项目上线了，感恩团队的支持"
"最近有什么任务没做完？"
"查一下关于 AI 的笔记"
```

## Architecture

```
SKILL.md                    ← 核心：PARA 数据库结构 + 意图识别（agent-agnostic）
references/
├── mcp-guide.md            ← Claude Code / Claude.ai（Notion MCP）
├── api-guide.md            ← OpenClaw / Codex / 其他（REST API）
└── setup.md                ← 多平台配置指南
JEFF_SU_SUMMARY.md          ← 设计理念参考
CONFIG.private.md.example   ← 数据库 ID 配置模板
```

**知识层与执行层分离：** SKILL.md 只描述数据模型和工作流逻辑，不绑定特定工具。Agent 根据自身环境读取对应的执行指南。

## Supported Agents

| Agent | 执行方式 | 参考文档 |
|-------|---------|---------|
| Claude Code | Notion MCP 工具 | [mcp-guide.md](./references/mcp-guide.md) |
| Claude.ai | Notion MCP 工具 | [mcp-guide.md](./references/mcp-guide.md) |
| OpenClaw | Notion REST API | [api-guide.md](./references/api-guide.md) |
| Codex | Notion REST API | [api-guide.md](./references/api-guide.md) |
| 其他 Agent | Notion REST API | [api-guide.md](./references/api-guide.md) |

## Database Schema

Six interconnected databases:

| Database | Title Property | Key Fields |
|----------|---------------|------------|
| Task | Name | Done, Due Date, Related Projects/Notes |
| Notes | Note | Note Type, Tags, Status, Related Projects/Areas/Resources |
| Projects | Log name | Status, End Date, Related Areas/Resources/Notes |
| Areas | Blog name | type, Related Notes/Resources |
| Resources | Note | Resources Type, URL, Related Areas/Projects/Notes |
| Make Time | Name | Date, Highlight, Grateful, Let Go |

See [SKILL.md](./SKILL.md) for complete field definitions.

## Roadmap

- [ ] Agent-driven migration (Apple Notes, Obsidian, Bear, Evernote)
- [ ] Batch operations
- [ ] Smart tagging
- [ ] Weekly/Monthly review workflows

## License

MIT

## Author

Created by [Jiahao Shao](https://github.com/jiahao-shao1)

## Acknowledgments

- Inspired by [Jeff Su's Notion Command Center](https://www.youtube.com/@JeffSu)
- Based on the **PARA method** by Tiago Forte
- Incorporates **Make Time framework** by Jake Knapp and John Zeratsky

**Disclaimer:** Independent implementation based on publicly available content. Not affiliated with or endorsed by any paid courses.
