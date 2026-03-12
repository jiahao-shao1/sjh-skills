# Notion LifeOS 配置指南

[English](./setup.md) | 中文

## 1. 获取 Notion 模板

推荐直接复制预配置模板：

**模板链接：** https://jiahaoshao.notion.site/lifeos-template

点击右上角「Duplicate」即可获得完整配置的工作区，包含所有数据库和 Relations。

## 2. 配置 Agent 访问权限

根据你使用的 Agent 平台，选择对应的配置方式：

### Claude Code / Claude.ai（Notion MCP）

确保已在 Claude 设置中连接 Notion 工作区。验证方法：尝试使用 `notion-search` 搜索任意内容。

### OpenClaw / Codex / 其他 Agent（REST API）

1. 访问 https://www.notion.so/my-integrations 创建 Integration
2. 获取 API Key 并保存：

```bash
mkdir -p ~/.config/notion
echo "your_notion_api_key_here" > ~/.config/notion/api_key
chmod 600 ~/.config/notion/api_key
```

3. 在 Notion 中将 Integration 连接到 LifeOS 页面（Share → Invite）

## 3. 配置数据库 ID

创建 `CONFIG.private.md` 文件，记录各数据库的 ID：

```bash
cp CONFIG.private.md.example CONFIG.private.md
```

### 如何获取数据库 ID

**方式 A：通过 MCP（Claude Code）**
1. 使用 `notion-search` 搜索数据库名称（如 "Task Database"）
2. 使用 `notion-fetch` 获取数据库详情
3. 在 `<data-source url="collection://...">` 标签中找到 data_source_id

**方式 B：通过 URL**
- 打开 Notion 数据库页面，URL 中的 ID 部分即为 database_id
- 例：`https://notion.so/25b119f193ef804a96fec277cc6b45fa` → `25b119f1-93ef-804a-96fe-c277cc6b45fa`

**方式 C：通过 API**
```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -X POST "https://api.notion.com/v1/search" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"query": "Task Database", "filter": {"property": "object", "value": "database"}}'
```

### CONFIG.private.md 格式

```markdown
# Notion LifeOS - 数据库 ID 配置

| 数据库 | database_id | data_source_id (MCP 用) |
|--------|-------------|------------------------|
| Task | `your-task-db-id` | `your-task-ds-id` |
| Notes | `your-notes-db-id` | `your-notes-ds-id` |
| Areas | `your-areas-db-id` | `your-areas-ds-id` |
| Resources | `your-resources-db-id` | `your-resources-ds-id` |
| Projects | `your-projects-db-id` | `your-projects-ds-id` |
| Make Time | `your-maketime-db-id` | `your-maketime-ds-id` |

LifeOS 根页面：`your-lifeos-root-page-id`
```

`CONFIG.private.md` 已在 `.gitignore` 中，不会被提交到 Git。

## 4. 所需数据库

你的 Notion 工作区应包含以下数据库：

- **Task Database** — 任务和待办事项
- **Notes Database** — 笔记和想法
- **Projects Database** — 有截止日期的项目
- **Areas Database** — 持续关注的生活领域
- **Resources Database** — 参考资料和知识库
- **Make Time Database** — 每日亮点和反思日记

详细字段结构见 SKILL.zh.md 中的「PARA 数据库结构」部分。
