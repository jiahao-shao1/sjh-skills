# cmux Skill

English | [中文](README.zh.md)

> A Claude Code skill for orchestrating terminal sessions inside [cmux](https://github.com/nicholasgasior/cmux) — split panes, spawn sub-agents, automate the built-in browser, and preview markdown.

## Features

- **Terminal orchestration** — Split panes, create workspaces, send commands to any surface
- **Sub-agent spawning** — Launch Claude Code instances in parallel panes
- **Browser automation** — Open URLs, click elements, fill forms, take screenshots in cmux's built-in browser
- **Markdown preview** — Live-reloading markdown panel alongside the terminal
- **Sidebar status** — Progress bars, status badges, and log entries in the cmux sidebar

## Install

```bash
# Add to your Claude Code skills
cp -r cmux ~/.claude/skills/
```

Or if using [dotfiles with stow](https://github.com/jiahao-shao1/dotfiles):

```bash
git submodule add <repo-url> agents/.agents/skills/cmux
```

## Usage

The skill activates automatically when you're inside a cmux session (`CMUX_WORKSPACE_ID` is set).

```
# Split pane and run parallel tasks
"run these two tests in parallel"

# Open a website in cmux browser
"open that URL in a browser"

# Show a plan alongside the terminal
"preview plan.md"
```

## Key Commands

| Command | Description |
|---------|-------------|
| `cmux new-split <direction>` | Split current pane |
| `cmux send --surface <ref> "cmd\n"` | Send command to a surface |
| `cmux read-screen --surface <ref>` | Read terminal output |
| `cmux browser open <url>` | Open built-in browser |
| `cmux markdown open <file>` | Preview markdown |
| `cmux set-progress <0-1>` | Update sidebar progress |

## License

MIT
