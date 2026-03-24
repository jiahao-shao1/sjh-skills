---
name: daily-summary
description: >
  Daily work summary. Aggregates Claude Code sessions, Git commits, and Notion Tasks
  into a timeline-style Chinese work summary.
  Triggers on: 'daily summary', '今天干了什么', '每日总结', '日报',
  'what did I do', 'summarize my day', '总结一下今天'.
  Arguments: today (default), yesterday, 24h, YYYY-MM-DD.
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
