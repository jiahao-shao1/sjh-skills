---
name: daily-summary
description: "Produce daily/yesterday work summary (日报) by aggregating Claude Code sessions, Git commits, and Notion task data — git log alone cannot do this. Args: today (default), yesterday, 24h, YYYY-MM-DD. Triggers: 'daily summary', 'what did I do today', 'yesterday summary', '日报', '今天干了什么', '工作总结', '某天做了什么'. Not for weekly reports or summarizing files."
---

# Daily Summary

## Usage

Triggered by `/daily-summary` or conversational triggers. Arguments come from the ARGUMENTS line.

```
/daily-summary              → today
/daily-summary yesterday    → yesterday
/daily-summary 24h          → past 24 hours
/daily-summary 2026-03-20   → specific date
```

## Prerequisites

| Dependency | Purpose | Check |
|------------|---------|-------|
| `collect-daily-data.sh` | Aggregates git log, Claude sessions, Notion tasks | Bundled in `scripts/` |
| `notion-lifeos` skill | Notion task data (optional — skipped if missing) | `~/.claude/skills/notion-lifeos/` |
| `git` | Commit history | Available on PATH |

## Execution Steps

1. Parse date argument from ARGUMENTS, default to `today`
2. Run data collection script:

```bash
bash <skill-base-dir>/scripts/collect-daily-data.sh --date <argument>
```

Where `<skill-base-dir>` is the directory containing this SKILL.md (known at skill load time, i.e., the "Base directory for this skill" path).

3. Read the script's full stdout
4. Generate a Chinese summary based on the collected data

## Summary Requirements

### Output Format

```
## YYYY-MM-DD Work Summary

### Timeline
- **HH:MM-HH:MM** [Project] What was done (1-sentence summary)
- **HH:MM-HH:MM** [Project] What was done
...

### Key Outputs
- Specific output 1 (e.g., added XX feature, fixed XX bug)
- Specific output 2
...

### Task Completion
- Completed: N items
- Incomplete: N items (list specific task names)

### Unplanned Work
(Work found in Git/Sessions but not tracked in Notion Tasks, if any)
```

### Guidelines
- Infer what was done from user messages — do not copy messages verbatim
- Merge multiple messages on the same topic into a single entry
- Timeline entries in chronological order
- Language: Chinese
- No emojis

## Error Handling

| Error | Action |
|-------|--------|
| `collect-daily-data.sh` returns empty | Report "no activity found for this date" — don't generate an empty summary |
| Notion tasks unavailable | Skip the Task Completion section, note it was skipped |
| No git repos found | Skip git data, rely on Claude Code sessions only |
| Date argument invalid | Default to `today`, warn user about invalid input |
