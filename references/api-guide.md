# Notion REST API 操作指南

适用于：OpenClaw、Codex、及其他通过 HTTP 调用 Notion API 的 Agent 环境。

## 前置条件

需要 Notion API Key，存储在 `~/.config/notion/api_key`：

```bash
mkdir -p ~/.config/notion
echo "your_notion_api_key_here" > ~/.config/notion/api_key
chmod 600 ~/.config/notion/api_key
```

获取方式：访问 https://www.notion.so/my-integrations 创建 Integration。

## API 基础信息

- Base URL: `https://api.notion.com/v1`
- 认证: `Authorization: Bearer $NOTION_KEY`
- 版本: `Notion-Version: 2022-06-28`
- Rate limit: ~3 req/s

## 获取数据库 ID

先读取 `CONFIG.private.md` 获取 database_id 映射。或通过 API 搜索：

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -X POST "https://api.notion.com/v1/search" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"query": "Task Database", "filter": {"property": "object", "value": "database"}}'
```

## 创建条目

### 创建任务

```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "<task_database_id>"},
    "properties": {
      "Name": {"title": [{"text": {"content": "完成季度报告"}}]},
      "Due Date": {"date": {"start": "2026-03-15"}},
      "Done": {"checkbox": false}
    }
  }'
```

### 创建笔记

```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "<notes_database_id>"},
    "properties": {
      "Note": {"title": [{"text": {"content": "产品团队 Q2 OKR 讨论记录"}}]},
      "Note Type": {"select": {"name": "Records"}},
      "Tags": {"multi_select": [{"name": "产品"}, {"name": "Q2"}]},
      "Date": {"date": {"start": "2026-03-08"}}
    },
    "children": [
      {
        "object": "block",
        "type": "heading_2",
        "heading_2": {"rich_text": [{"text": {"content": "讨论要点"}}]}
      },
      {
        "object": "block",
        "type": "bulleted_list_item",
        "bulleted_list_item": {"rich_text": [{"text": {"content": "重点提升用户留存率到 85%"}}]}
      }
    ]
  }'
```

### 创建 Make Time 日记

```bash
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "<maketime_database_id>"},
    "properties": {
      "Name": {"title": [{"text": {"content": "2026-03-08"}}]},
      "Date": {"date": {"start": "2026-03-08"}},
      "Highlight": {"rich_text": [{"text": {"content": "项目终于上线了"}}]},
      "Grateful": {"rich_text": [{"text": {"content": "团队的付出"}}]},
      "Let Go": {"rich_text": [{"text": {"content": "对延期的焦虑"}}]}
    }
  }'
```

## 查询数据

### 查询未完成任务

```bash
curl -X POST "https://api.notion.com/v1/databases/<task_database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {"property": "Done", "checkbox": {"equals": false}},
    "sorts": [{"property": "Due Date", "direction": "ascending"}]
  }'
```

### 查询最近笔记

```bash
curl -X POST "https://api.notion.com/v1/databases/<notes_database_id>/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "sorts": [{"property": "Created time", "direction": "descending"}],
    "page_size": 10
  }'
```

## 更新条目

### 完成任务

```bash
curl -X PATCH "https://api.notion.com/v1/pages/<page_id>" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {"Done": {"checkbox": true}}
  }'
```

### 添加页面内容

```bash
curl -X PATCH "https://api.notion.com/v1/blocks/<page_id>/children" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "children": [
      {"object": "block", "type": "paragraph",
       "paragraph": {"rich_text": [{"text": {"content": "新内容"}}]}}
    ]
  }'
```

## 注意事项

- 创建页面用 `database_id`，查询用 `databases/<id>/query`
- Relation 字段需要目标页面的 page_id
- button 块的自动化配置通过 API 创建时可能会丢失
