# Notion LifeOS Skill

English | [中文](README.zh.md)

> **Memory System for Human** — A scalable self-awareness system that captures your thoughts, decisions, and growth over decades.

An **agent-agnostic** Notion LifeOS skill based on the PARA method and Make Time framework. Works with **Claude Code, OpenClaw, Codex**, and any AI agent that can interact with Notion.

## Vision

This is not just a productivity tool — it's a **long-term memory architecture** designed to:

1. **Capture your thinking in real-time** — Zero-latency idea capture ensures no thought is lost
2. **Scale across decades** — Build a comprehensive record of your cognitive evolution
3. **Enable AI reconstruction** — In 10 years, an AI agent can rebuild "you" from this data

### Core Design Principles

**1. Frontend-Backend Separation**
- **Frontend:** Notion (user interface for capture and review)
- **Backend:** AI agents (automation, processing, insights)
- This separation allows you to switch tools without losing your data structure

**2. Database Separation (DP Principle)**
- **Write:** Instant, frictionless capture — no processing overhead
- **Process:** Deferred, AI-powered organization and insight extraction
- **Philosophy:** Capture first, organize later. Never let processing block input.

**3. Scalable Self-Awareness**
- Every note, task, and decision becomes a data point
- Over time, patterns emerge: how you think, what you value, how you grow
- AI agents can analyze decades of data to understand your cognitive fingerprint
- **Ultimate goal:** An AI that thinks like you, trained on your actual thought process

### Why This Matters

Most productivity systems optimize for *doing*. LifeOS optimizes for *becoming*.

- **Short-term:** Manage tasks and projects efficiently
- **Mid-term:** Understand your patterns and improve decision-making
- **Long-term:** Create a digital cognitive twin that preserves your thinking style

**In 10 years, an AI agent trained on your LifeOS data could:**
- Make decisions the way you would
- Predict what you'd find interesting
- Explain your reasoning to others
- Continue your work after you're gone

This is **memory as infrastructure** — not just for recall, but for reconstruction.

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
npx skills add jiahao-shao1/sjh-skills --skill notion-lifeos
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
"Take a note: we discussed Q2 OKR in the meeting"
"Add a task: finish competitor analysis report by Friday"
"The highlight today was the project launch, grateful for the team's support"
"Any unfinished tasks?"
"Search notes about AI"
```

## Architecture

```
SKILL.md                    ← Core: intent recognition + business rules + gotchas
references/
├── schema.md               ← PARA database field definitions
├── mcp-guide.md            ← Claude Code / Claude.ai (Notion MCP)
├── api-guide.md            ← OpenClaw / Codex / others (REST API)
├── query-guide.md          ← Structured query patterns + Note Type / Make Time logic
├── advanced.md             ← Composite intents + error handling
└── setup.md                ← Multi-platform setup guide
scripts/
├── query-tasks.sh          ← Flexible task query (by date, done/undone, combined)
├── check_today_journal.sh  ← Make Time deduplication check
└── list_undone_tasks.sh    ← Quick incomplete tasks listing
JEFF_SU_SUMMARY.md          ← Design philosophy reference
CONFIG.private.md.example   ← Database ID config template
```

**Knowledge layer separated from execution layer:** SKILL.md only describes the data model and workflow logic, without binding to specific tools. Agents read the corresponding execution guide based on their environment.

## Supported Agents

| Agent | Execution Method | Reference |
|-------|-----------------|-----------|
| Claude Code | Notion MCP tools | [mcp-guide.md](./references/mcp-guide.md) |
| Claude.ai | Notion MCP tools | [mcp-guide.md](./references/mcp-guide.md) |
| OpenClaw | Notion REST API | [api-guide.md](./references/api-guide.md) |
| Codex | Notion REST API | [api-guide.md](./references/api-guide.md) |
| Other Agents | Notion REST API | [api-guide.md](./references/api-guide.md) |

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

See [references/schema.md](./references/schema.md) for complete field definitions.

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

- Core Notion implementation logic from [Jeff Su's Notion Command Center](https://www.youtube.com/@JeffSu)
- Based on the **PARA method** by Tiago Forte
- Incorporates **Make Time framework** by Jake Knapp and John Zeratsky

**Disclaimer:** Independent implementation based on publicly available content. Not affiliated with or endorsed by any paid courses.
