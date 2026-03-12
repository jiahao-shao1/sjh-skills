---
name: notion-lifeos
description: "Notion LifeOS PARA Life Management System — Create and query tasks, notes, projects, areas, resources, and Make Time journal entries. Activate when users mention Notion, notes, tasks, projects, todos, journals, or use everyday phrases like 'take a note', 'what do I need to do today', 'jot down an idea', 'add a task', 'search my notes', 'any unfinished tasks'. Also triggers for personal knowledge management, PARA method, life systems, or daily reviews. | Notion LifeOS PARA 生活管理系统 — 创建和查询任务、笔记、项目、领域、资源，以及 Make Time 日记条目。当用户提到 Notion、笔记、任务、项目、待办、日记，或使用日常用语如「帮我记一下」「今天要做什么」「记个想法」「加个任务」「查一下我的笔记」「最近有什么任务没做完」时，都应该激活此 skill。任何涉及个人知识管理、PARA 方法、生活系统、每日回顾的请求也应触发。"
---

# Notion LifeOS Skill

English | [中文](./SKILL.zh.md)

A Notion life management system based on the PARA method and Make Time framework.

## Core Principles

- **Capture first, organize later** — Never let processing block input
- **Proactive information surfacing** — Use Relations to automatically surface information where it's needed
- **Scalable self-awareness** — Every record is a data point for your future AI self

See [JEFF_SU_SUMMARY.md](./JEFF_SU_SUMMARY.md) for detailed design philosophy.

## Database Location

**Database IDs must be read from `CONFIG.private.md`.** This file is located in the skill directory and contains the user's actual database ID mappings.

Reading order:
1. Read `CONFIG.private.md` from the skill directory
2. If the file doesn't exist, locate databases using:
   - Use `notion-fetch` to get the LifeOS root page (page named "LifeOS", not "LifeOS Template")
   - Extract each database's ID from the root page content
   - Only use databases under the LifeOS root page; ignore other databases with the same name
3. If still not found, remind the user to configure per [references/setup.md](./references/setup.md)

**Note: The workspace may contain multiple databases with the same name (e.g., one set under LifeOS and another under LifeOS Template). Always confirm you're using the set under the LifeOS root page.**

## PARA Database Schema

The system contains 6 core databases interconnected via Notion Relations:

### Task
| Property | Type | Description |
|----------|------|-------------|
| Name | title | Task name |
| Done | checkbox | Completed |
| Due Date | date | Due date |
| Related to Projects | relation | Related projects |
| Related to Notes | relation | Related notes |

### Notes
| Property | Type | Description |
|----------|------|-------------|
| Note | title | Note title |
| Note Type | select | Options: My Blog, Thoughts, Records, Notes, Documentation, Experiments |
| Status | select | Options: 进行中, 已完成 |
| Tags | multi_select | Options: optimizer, VLA, NLP, MLLM, 3DV, attention, tokenizer. Do not add new values arbitrarily; update the database schema first |
| folder | rich_text | Folder |
| Date | date | Date |
| URL | url | Link |
| Files & media | files | Attachments |
| Related to Projects | relation | Related projects |
| Related to Areas | relation | Related areas |
| Related Resources | relation | Related resources |

### Projects
| Property | Type | Description |
|----------|------|-------------|
| Log name | title | Project name |
| Status | select | Status |
| End Date | date | End date |
| Project Folder | rich_text | Project folder |
| Related Areas | relation | Related areas |
| Related Resources | relation | Related resources |
| Related Notes | relation | Related notes |

### Areas
| Property | Type | Description |
|----------|------|-------------|
| Blog name | title | Area name |
| type | multi_select | Type tags |
| Related Notes | relation | Related notes |
| Related Resources | relation | Related resources |

### Resources
| Property | Type | Description |
|----------|------|-------------|
| Note | title | Resource name |
| Resources Type | select | Resource type |
| URL | url | Link |
| Date | date | Date |
| Files & media | files | Attachments |
| Related to Areas | relation | Related areas |
| Related to Projects | relation | Related projects |
| Related Notes | relation | Related notes |

### Make Time (Journal)
| Property | Type | Description |
|----------|------|-------------|
| Name | title | Date name, e.g. "2026-03-08" |
| Date | date | Date |
| Highlight | rich_text | Today's highlight |
| Grateful | rich_text | Things to be grateful for |
| Let Go | rich_text | Things to let go of |

## Operation Guide

Choose the execution method based on your Agent environment:

- **With Notion MCP tools** (e.g., Claude Code / Claude.ai) → See [references/mcp-guide.md](./references/mcp-guide.md)
- **With Notion API access** (e.g., OpenClaw / Codex / other agents) → See [references/api-guide.md](./references/api-guide.md)

How to determine: Check if MCP tools like `notion-search`, `notion-create-pages` are available. If yes, use MCP; otherwise use API.

## Intent Recognition & Database Mapping

User input → Target database:

| User Intent | Target DB | Action |
|-------------|-----------|--------|
| "Take a note about XXX" | Notes | Create note |
| "Add a task: XXX" | Task | Create task |
| "The best thing today was..." | Make Time | Create/update journal |
| "Create project XXX" | Projects | Create project |
| "Any unfinished tasks?" | Task | Query incomplete tasks |
| "Search notes about XX" | Notes | Search notes |
| "Add a resource/reference" | Resources | Create resource |

### Note Type Selection Logic

Automatically select the appropriate Note Type based on content:

| Content Characteristics | Note Type |
|------------------------|-----------|
| Personal thoughts, inspiration, reflections | Thoughts |
| Meeting records, event logs | Records |
| Study notes, reading notes | Notes |
| Technical docs, tutorials, guides | Documentation |
| Experiment records, test results | Experiments |
| Blog post drafts | My Blog |

### Make Time Journal Extraction Logic

Extract three elements from the user's natural language:

- **Highlight**: The most important/happiest thing today / achievement
- **Grateful**: Things related to gratitude and appreciation
- **Let Go**: Things to release and stop worrying about

Before creating a Make Time entry, check if today's entry already exists. If it does, update rather than create a duplicate.

## Notes

- Date property values should be in ISO-8601 format (e.g., `2026-03-08`)
- Relation fields require the target page's ID
- Confirm the operation result to the user after creating an entry
- When operating on a database for the first time, it's recommended to fetch the schema first to confirm property names
