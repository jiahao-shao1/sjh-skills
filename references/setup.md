# Notion LifeOS Setup Guide

English | [中文](./setup.zh.md)

## 1. Get the Notion Template

Duplicate the pre-configured template:

**Template link:** https://jiahaoshao.notion.site/lifeos-template

Click "Duplicate" in the top-right corner to get a fully configured workspace with all databases and Relations.

## 2. Configure Agent Access

Choose the configuration method based on your Agent platform:

### Claude Code / Claude.ai (Notion MCP)

Ensure you've connected your Notion workspace in Claude settings. Verify by trying `notion-search` to search for any content.

### OpenClaw / Codex / Other Agents (REST API)

1. Visit https://www.notion.so/my-integrations to create an Integration
2. Save your API Key:

```bash
mkdir -p ~/.config/notion
echo "your_notion_api_key_here" > ~/.config/notion/api_key
chmod 600 ~/.config/notion/api_key
```

3. Connect the Integration to your LifeOS page in Notion (Share → Invite)

## 3. Configure Database IDs

Create a `CONFIG.private.md` file to record each database's ID:

```bash
cp CONFIG.private.md.example CONFIG.private.md
```

### How to Get Database IDs

**Method A: Via MCP (Claude Code)**
1. Use `notion-search` to search for database names (e.g., "Task Database")
2. Use `notion-fetch` to get database details
3. Find the data_source_id in the `<data-source url="collection://...">` tag

**Method B: Via URL**
- Open the Notion database page; the ID in the URL is the database_id
- Example: `https://notion.so/25b119f193ef804a96fec277cc6b45fa` → `25b119f1-93ef-804a-96fe-c277cc6b45fa`

**Method C: Via API**
```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
curl -X POST "https://api.notion.com/v1/search" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"query": "Task Database", "filter": {"property": "object", "value": "database"}}'
```

### CONFIG.private.md Format

```markdown
# Notion LifeOS - Database ID Configuration

| Database | database_id | data_source_id (for MCP) |
|----------|-------------|--------------------------|
| Task | `your-task-db-id` | `your-task-ds-id` |
| Notes | `your-notes-db-id` | `your-notes-ds-id` |
| Areas | `your-areas-db-id` | `your-areas-ds-id` |
| Resources | `your-resources-db-id` | `your-resources-ds-id` |
| Projects | `your-projects-db-id` | `your-projects-ds-id` |
| Make Time | `your-maketime-db-id` | `your-maketime-ds-id` |

LifeOS Root Page: `your-lifeos-root-page-id`
```

`CONFIG.private.md` is in `.gitignore` and won't be committed to Git.

## 4. Required Databases

Your Notion workspace should contain the following databases:

- **Task Database** — Tasks and todos
- **Notes Database** — Notes and ideas
- **Projects Database** — Projects with deadlines
- **Areas Database** — Ongoing life areas
- **Resources Database** — Reference materials and knowledge base
- **Make Time Database** — Daily highlights and reflection journal

See the "PARA Database Schema" section in SKILL.md for detailed field structures.
