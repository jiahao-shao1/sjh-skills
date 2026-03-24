# PARA Database Schema

> **Important:** Select and multi_select fields may have restricted allowed values.
> Always fetch the database schema dynamically before creating entries.
> Do NOT assume or hardcode option values — they may change over time.

The system contains 6 core databases interconnected via Notion Relations:

## Task
| Property | Type | Description |
|----------|------|-------------|
| Name | title | Task name |
| Done | checkbox | Completed |
| Due Date | date | Due date |
| Related to Projects | relation | Related projects |
| Related to Notes | relation | Related notes |

## Notes
| Property | Type | Description |
|----------|------|-------------|
| Note | title | Note title |
| Note Type | select | Fetch current options from database schema (e.g., My Blog, Thoughts, Records, Notes, Documentation, Experiments) |
| Status | select | Fetch current options from database schema |
| Tags | multi_select | Topic tags. Fetch allowed values from schema before use. If user wants a tag that doesn't exist, inform them and ask whether to proceed without it |
| folder | rich_text | Folder |
| Date | date | Date |
| URL | url | Link |
| Files & media | files | Attachments |
| Related to Projects | relation | Related projects |
| Related to Areas | relation | Related areas |
| Related Resources | relation | Related resources |

## Projects
| Property | Type | Description |
|----------|------|-------------|
| Log name | title | Project name |
| Status | select | Fetch current options from database schema |
| End Date | date | End date |
| Project Folder | rich_text | Project folder |
| Related Areas | relation | Related areas |
| Related Resources | relation | Related resources |
| Related Notes | relation | Related notes |

## Areas
| Property | Type | Description |
|----------|------|-------------|
| Blog name | title | Area name |
| type | multi_select | Type tags |
| Related Notes | relation | Related notes |
| Related Resources | relation | Related resources |

## Resources
| Property | Type | Description |
|----------|------|-------------|
| Note | title | Resource name |
| Resources Type | select | Fetch current options from database schema |
| URL | url | Link |
| Date | date | Date |
| Files & media | files | Attachments |
| Related to Areas | relation | Related areas |
| Related to Projects | relation | Related projects |
| Related Notes | relation | Related notes |

## Make Time (Journal)
| Property | Type | Description |
|----------|------|-------------|
| Name | title | Date name, e.g. "2026-03-08" |
| Date | date | Date |
| Highlight | rich_text | Today's highlight |
| Grateful | rich_text | Things to be grateful for |
| Let Go | rich_text | Things to let go of |
