# Advanced: Composite Intents & Error Handling

## Composite Intent Handling

Users often express multiple intents in a single message. Parse and execute them in dependency order.

| User Input | Intents | Actions |
|------------|---------|---------|
| "Take a note about X and add a task to follow up" | Note + Task | 1. Create note 2. Create task with relation to note |
| "Today's highlight was X, also jot down a thought about Y" | Make Time + Note | 1. Create/update Make Time 2. Create note |
| "Add a task for project Z: do ABC by Friday" | Task + Project lookup | 1. Find project Z 2. Create task with project relation and due date |
| "Search notes about X and create a summary task" | Query + Create | 1. Search notes 2. Create task referencing results |

**Execution strategy:**
1. Parse all intents from the message
2. Resolve dependencies (e.g., need project ID before creating related task)
3. Execute in dependency order
4. If one operation fails, continue with remaining and report partial results
5. Confirm all results at the end

## Error Handling

| Error Scenario | Action |
|---------------|--------|
| Database ID not found | Fall back to LifeOS root page discovery; if that fails, guide user to setup |
| Property name mismatch | Fetch fresh schema, retry with correct property name |
| Select/multi_select value rejected | Fetch schema for allowed values, suggest closest match to user |
| Rate limit (API: ~3 req/s) | Wait and retry; batch operations if possible |
| Page not found (for update/relation) | Re-search using title; confirm with user if ambiguous |
| Relation target ambiguous | Present options to user, ask for clarification |
| Permission denied | Guide user to share LifeOS page with Integration |

**General principles:**
- Never silently fail — always inform the user what happened
- On partial failure in composite operations, report what succeeded and what failed
- Prefer graceful degradation: if a relation can't be set, create the entry without it and inform the user
