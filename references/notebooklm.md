# NotebookLM Enhanced Mode Reference

This reference is loaded when Enhanced Mode (NotebookLM integration) is activated.
Claude follows this workflow to perform deep paper reading via NotebookLM.

## Prerequisites Check

Before starting, verify:

```bash
# playwright-cli must be installed
which playwright-cli

# NotebookLM requires Google login state in playwright-cli persistent profile
# If login has expired, prompt user to re-authenticate manually
```

If either check fails, fall back to Basic Mode and inform the user.

## Workflow

### Step 1: Get Papers via CLI

```bash
scholar-inbox digest --json --limit 20
```

Parse the JSON output to get paper IDs, titles, arXiv URLs, abstracts, and scores.

### Step 2: AI Classification

Dynamically group papers by topic based on the user's configured interests:

```bash
scholar-inbox config  # check user's research interests
```

**Rules:**
- Generate group names from paper titles, keywords, and user interests
- DO NOT use hardcoded categories — derive them from the actual paper content
- Each group should have 2-5 papers
- If no interests are configured, skip classification and use all high-score papers as one group
- Limit to top 10 papers total per session

### Step 3: Open NotebookLM

```bash
playwright-cli open --persistent https://notebooklm.google.com
```

Wait 3-5 seconds for the page to fully load. Verify the page rendered correctly
before proceeding.

### Step 4: For Each Paper Group

For each classified group:

1. **Find or create a notebook** matching the group name
   - Search existing notebooks first
   - Only create a new one if no match is found
2. **Add sources** to the notebook:
   - Click "Add source" button
   - Select "Website" as the source type
   - Paste the arXiv URL for each paper
   - Wait for NotebookLM to finish processing each source before adding the next
3. **Repeat** for all papers in the group

### Step 5: Ask NotebookLM for Analysis

Use playwright-cli to interact with the notebook's chat interface:

- Type: "Summarize the key contributions and methods of the newly added papers"
- Wait for response, then ask:
  "How do these papers relate to [user's research interests]?"

Capture the responses for the user's review.

### Step 6: Close Browser

Always close the browser when done:

```bash
playwright-cli close
```

### Step 7: Rate Papers

Based on the analysis, suggest ratings and let the user confirm:

```bash
scholar-inbox rate <id> up    # for relevant papers
scholar-inbox rate <id> down  # for irrelevant papers
```

## Notebook Management

Notebooks are tracked in `~/.config/scholar-inbox/notebooks.json`.

**Format:**
```json
{
  "notebooks": {
    "Group Name": {
      "url": "https://notebooklm.google.com/notebook/...",
      "source_count": 12,
      "last_updated": "2026-03-24"
    }
  }
}
```

**Rules:**
- NotebookLM has a limit of **50 sources per notebook**
- When a notebook reaches 40+ sources, warn the user
- When it reaches 50, suggest creating a new notebook (e.g., "Topic Name v2")
- Update `notebooks.json` after each session

## Constraints

| Constraint | Value | Reason |
|------------|-------|--------|
| Max papers per session | 10 | Avoid overwhelming NotebookLM |
| Wait between source adds | 2-3 sec | Let NotebookLM process each URL |
| Max sources per notebook | 50 | NotebookLM hard limit |
| Always close playwright-cli | Required | Prevent orphan browser processes |

## Error Handling

- **NotebookLM unreachable**: Fall back to Basic Mode, inform user
- **Google login expired**: Prompt user to run `playwright-cli open --persistent https://accounts.google.com` to re-login
- **Source add fails**: Skip the paper, log warning, continue with remaining papers
- **Rate limit / slow processing**: Increase wait times, reduce batch size

## Example Session

```
> scholar-inbox enhanced

Checking prerequisites... OK
Fetching papers... 18 papers found
Classifying into groups:
  - "Vision-Language Models" (3 papers)
  - "Reinforcement Learning for LLMs" (4 papers)
  - "3D Scene Understanding" (3 papers)

Opening NotebookLM...
Processing "Vision-Language Models":
  Added: arxiv.org/abs/2603.12345
  Added: arxiv.org/abs/2603.12346
  Added: arxiv.org/abs/2603.12347
  Requesting analysis...

[NotebookLM response displayed]

Closing browser...
Rating suggestions ready. Use `scholar-inbox rate` to confirm.
```
