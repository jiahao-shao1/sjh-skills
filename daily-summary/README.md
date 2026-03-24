# Daily Summary Skill

English | [中文](README.zh.md)

> A Claude Code skill that aggregates your daily work across Claude Code sessions, Git commits, and Notion tasks into a timeline-style summary.

## Features

- **Multi-source aggregation** — Collects data from Claude Code session history, Git logs, and Notion tasks
- **Timeline format** — Chronological summary grouped by time blocks
- **Flexible date targeting** — Today, yesterday, last 24 hours, or any specific date
- **Automated data collection** — Shell script handles all data gathering

## Install

```bash
# Add to your Claude Code skills
cp -r daily-summary ~/.claude/skills/
```

Or if using [dotfiles with stow](https://github.com/jiahao-shao1/dotfiles):

```bash
git submodule add <repo-url> agents/.agents/skills/daily-summary
```

## Usage

```
/daily-summary              # Today (default)
/daily-summary yesterday    # Yesterday
/daily-summary 24h          # Last 24 hours
/daily-summary 2026-03-20   # Specific date
```

Or trigger conversationally:

```
"What did I do today?"
"Summarize my day"
"日报"
"今天干了什么"
```

## How It Works

1. Parses date argument (defaults to today)
2. Runs `scripts/collect-daily-data.sh` to gather:
   - Claude Code session logs
   - Git commits across repositories
   - Notion task completions
3. Generates a structured Chinese timeline summary

## License

MIT
