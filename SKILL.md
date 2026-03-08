---
name: notion-lifeos
description: "Notion LifeOS PARA 生活管理系统 — 创建和查询任务、笔记、项目、领域、资源，以及 Make Time 日记条目。当用户提到 Notion、笔记、任务、项目、待办、日记，或使用日常用语如「帮我记一下」「今天要做什么」「记个想法」「加个任务」「查一下我的笔记」「最近有什么任务没做完」时，都应该激活此 skill。任何涉及个人知识管理、PARA 方法、生活系统、每日回顾的请求也应触发。"
---

# Notion LifeOS Skill

基于 PARA 方法和 Make Time 框架的 Notion 生活管理系统。

## 核心理念

- **先捕获，后整理** — 永不让处理阻塞输入
- **信息主动呈现** — 通过 Relations 让信息自动浮现到需要它的地方
- **可扩展的自我觉察** — 每条记录都是未来 AI 理解你的数据点

详细设计理念见 [JEFF_SU_SUMMARY.md](./JEFF_SU_SUMMARY.md)。

## 数据库定位

**必须从 `CONFIG.private.md` 读取数据库 ID。** 这个文件位于 skill 目录下，包含用户的真实数据库 ID 映射表。

读取顺序：
1. 读取 skill 目录下的 `CONFIG.private.md`
2. 如果文件不存在，使用以下方法定位数据库：
   - 先用 `notion-fetch` 获取 LifeOS 根页面（页面名称为「LifeOS」，不是「LifeOS Template」）
   - 从根页面内容中找到各数据库的 ID
   - 只使用 LifeOS 根页面下的数据库，忽略其他同名数据库
3. 如果仍找不到，提醒用户按 [references/setup.md](./references/setup.md) 配置

**注意：工作区中可能存在多个同名数据库（如 LifeOS 和 LifeOS Template 下各有一套）。必须确认使用的是 LifeOS 根页面下的那一套。**

## PARA 数据库结构

系统包含 6 个核心数据库，通过 Notion Relations 互相关联：

### Task（任务）
| 属性 | 类型 | 说明 |
|------|------|------|
| Name | title | 任务名称 |
| Done | checkbox | 是否完成 |
| Due Date | date | 截止日期 |
| Related to Projects | relation | 关联项目 |
| Related to Notes | relation | 关联笔记 |

### Notes（笔记）
| 属性 | 类型 | 说明 |
|------|------|------|
| Note | title | 笔记标题 |
| Note Type | select | 可选值：My Blog, Thoughts, Records, Notes, Documentation, Experiments |
| Status (状态) | select | 可选值：进行中, 已完成 |
| Tags | multi_select | 标签 |
| folder | rich_text | 文件夹 |
| Date | date | 日期 |
| URL | url | 链接 |
| Files & media | files | 附件 |
| Related to Projects | relation | 关联项目 |
| Related to Areas | relation | 关联领域 |
| Related Resources | relation | 关联资源 |

### Projects（项目）
| 属性 | 类型 | 说明 |
|------|------|------|
| Log name | title | 项目名称 |
| Status (状态) | select | 状态 |
| End Date | date | 结束日期 |
| Project Folder | rich_text | 项目文件夹 |
| Related Areas | relation | 关联领域 |
| Related Resources | relation | 关联资源 |
| Related Notes | relation | 关联笔记 |

### Areas（领域）
| 属性 | 类型 | 说明 |
|------|------|------|
| Blog name | title | 领域名称 |
| type | multi_select | 类型标签 |
| Related Notes | relation | 关联笔记 |
| Related Resources | relation | 关联资源 |

### Resources（资源）
| 属性 | 类型 | 说明 |
|------|------|------|
| Note | title | 资源名称 |
| Resources Type | select | 资源类型 |
| URL | url | 链接 |
| Date | date | 日期 |
| Files & media | files | 附件 |
| Related to Areas | relation | 关联领域 |
| Related to Projects | relation | 关联项目 |
| Related Notes | relation | 关联笔记 |

### Make Time（日记）
| 属性 | 类型 | 说明 |
|------|------|------|
| Name | title | 日期名称（如 "2026-03-08"） |
| Date | date | 日期 |
| Highlight | rich_text | 今日亮点 |
| Grateful | rich_text | 感恩的事 |
| Let Go | rich_text | 放下的事 |

## 操作指南

根据你的 Agent 环境，选择对应的执行方式：

- **有 Notion MCP 工具**（如 Claude Code / Claude.ai）→ 见 [references/mcp-guide.md](./references/mcp-guide.md)
- **有 Notion API 访问**（如 OpenClaw / Codex / 其他 Agent）→ 见 [references/api-guide.md](./references/api-guide.md)

判断方法：检查是否有 `notion-search`、`notion-create-pages` 等 MCP 工具可用。如果有，使用 MCP 方式；否则使用 API 方式。

## 意图识别与数据库映射

用户说的话 → 应操作的数据库：

| 用户意图 | 目标数据库 | 操作 |
|----------|-----------|------|
| 「帮我记一下 XXX」「记个笔记」 | Notes | 创建笔记 |
| 「加个任务 XXX」「待办：XXX」 | Task | 创建任务 |
| 「今天最开心的事是…」「记录今天」 | Make Time | 创建/更新日记 |
| 「创建项目 XXX」 | Projects | 创建项目 |
| 「最近有什么任务没做完」 | Task | 查询未完成任务 |
| 「查一下关于 XX 的笔记」 | Notes | 搜索笔记 |
| 「添加资源/参考资料」 | Resources | 创建资源 |

### Note Type 选择逻辑

根据笔记内容自动选择合适的 Note Type：

| 内容特征 | Note Type |
|---------|-----------|
| 个人想法、灵感、反思 | Thoughts |
| 会议记录、事件记录、日志 | Records |
| 学习笔记、读书笔记 | Notes |
| 技术文档、教程、指南 | Documentation |
| 实验记录、测试结果 | Experiments |
| 博客文章草稿 | My Blog |

### Make Time 日记提取逻辑

从用户的自然语言中提取三个要素：

- **Highlight**：今日最重要的事 / 最开心的事 / 成就
- **Grateful**：感恩、感谢相关的内容
- **Let Go**：想放下的、不再纠结的事

创建 Make Time 条目前，先查询今日是否已有条目。如果已有，更新而非重复创建。

## 注意事项

- Date 属性的值应为 ISO-8601 格式（如 `2026-03-08`）
- Relation 字段需要目标页面的 ID
- 创建条目后向用户确认操作结果
- 首次操作某个数据库时，建议先获取 schema 确认属性名称
