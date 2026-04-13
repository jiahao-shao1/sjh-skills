---
name: handoff
description: Generate a structured handoff summary for the next session. Triggered when user says "handoff", "交接", or "写个交接".
---

Print the handoff summary directly in the conversation (do NOT create files). The user copies it into the first message of the next session to resume context.

Infer content from the current conversation context + `git diff` + task list. Ask the user to fill gaps if information is insufficient.

Format:

```
## Current Status
(One sentence summarizing progress)

## Completed
- ...

## Not Yet Done
- ...

## Key Decisions
- ...

## Pitfalls to Avoid
- ...

## Next Steps
(What to do first in the next session)

## Key Files
- ...
```
