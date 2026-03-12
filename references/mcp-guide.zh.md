# Notion MCP 工具操作指南

[English](./mcp-guide.md) | 中文

适用于：Claude Code、Claude.ai 等具有 Notion MCP 集成的环境。

## 可用工具

- `notion-search` — 搜索工作区内容和数据库
- `notion-fetch` — 获取页面/数据库详情和 schema
- `notion-create-pages` — 创建页面
- `notion-update-page` — 更新页面属性或内容
- `notion-create-database` — 创建数据库

## 获取数据库 ID

1. 读取 skill 目录下的 `CONFIG.private.md`，从中获取各数据库的 `data_source_id`
2. 如果文件不存在：用 `notion-search` 搜索「LifeOS」找到根页面，然后用 `notion-fetch` 获取该页面内容，从中提取各数据库的 `<data-source>` ID。只使用 LifeOS 根页面下的数据库。

## 创建条目

使用 `notion-create-pages`，以 `data_source_id` 作为 parent。

**属性格式要求（MCP 特有）：**
- 属性值使用扁平字符串，不要用 REST API 的嵌套对象格式
- Date：拆分为 `date:属性名:start`、`date:属性名:end`、`date:属性名:is_datetime`
- Checkbox：使用 `__YES__` / `__NO__`（不是 true/false）
- multi_select：逗号分隔的字符串
- URL 属性：属性名加 `userDefined:` 前缀（如 `userDefined:URL`）

### 创建任务示例

```json
{
  "parent": {"data_source_id": "<从 CONFIG.private.md 读取的 Task data_source_id>"},
  "pages": [{
    "properties": {
      "Name": "完成季度报告",
      "date:Due Date:start": "2026-03-15",
      "date:Due Date:is_datetime": 0,
      "Done": "__NO__"
    }
  }]
}
```

### 创建笔记示例

```json
{
  "parent": {"data_source_id": "<Notes data_source_id>"},
  "pages": [{
    "properties": {
      "Note": "产品团队 Q2 OKR 讨论记录",
      "Note Type": "Records",
      "Tags": "产品, Q2",
      "date:Date:start": "2026-03-08",
      "date:Date:is_datetime": 0
    },
    "content": "## 讨论要点\n\n- 重点提升用户留存率到 85%"
  }]
}
```

### 创建 Make Time 日记示例

```json
{
  "parent": {"data_source_id": "<Make Time data_source_id>"},
  "pages": [{
    "properties": {
      "Name": "2026-03-08",
      "date:Date:start": "2026-03-08",
      "date:Date:is_datetime": 0,
      "Highlight": "项目终于上线了",
      "Grateful": "团队的付出",
      "Let Go": "对延期的焦虑"
    }
  }]
}
```

## 查询数据

使用 `notion-search` 搜索工作区内容：

- 全局搜索：`{"query": "季度报告"}`
- 在特定数据库中搜索：`{"query": "未完成", "data_source_url": "collection://<Task data_source_id>"}`

获取完整页面内容：先 `notion-search` 找到页面 ID，再用 `notion-fetch` 获取详情。

## 更新条目

使用 `notion-update-page`：

**完成任务：**
```json
{
  "page_id": "<page_id>",
  "command": "update_properties",
  "properties": {"Done": "__YES__"}
}
```

**更新页面正文：**
```json
{
  "page_id": "<page_id>",
  "command": "update_content",
  "content_updates": [{"old_str": "旧内容", "new_str": "新内容"}]
}
```
