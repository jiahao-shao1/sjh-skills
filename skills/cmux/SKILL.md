---
name: cmux
description: "cmux terminal orchestration — split panes, spawn Claude Code instances, send commands, poll output, report sidebar progress, automate the built-in browser, and preview markdown. Use this skill whenever you need to: run parallel tasks in separate panes, launch sub-Claude-Code instances, monitor terminal output, update sidebar status/progress, coordinate multiple terminal sessions, fan out work across splits, open a website in a cmux browser pane, interact with web pages, or display markdown alongside the terminal. Even if the user just says 'run these in parallel', 'open that in a browser', or 'show the plan', this skill applies."
---

# cmux Orchestration

Orchestrate terminal sessions, spawn Claude Code instances, automate the built-in browser, preview markdown — all inside cmux.

## Detection

Check `CMUX_WORKSPACE_ID` env var. If set → you're in cmux. If unset → skip all cmux commands.

Auto-set env vars: `CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`, `CMUX_SOCKET_PATH`.

## Hierarchy

Window > Workspace (sidebar tab) > Pane (split region) > Surface (terminal tab in pane).

Short refs: `workspace:1`, `pane:1`, `surface:2`.

## Orientation

```bash
cmux identify --json                              # your current context
cmux list-workspaces                              # all workspaces
cmux list-panes                                   # panes in current workspace
cmux list-pane-surfaces --pane <ref>              # surfaces in a pane
cmux tree --all                                   # full hierarchy view
```

## Create Terminals

```bash
cmux new-split <left|right|up|down>               # split current pane
cmux new-workspace --cwd <path>                   # new workspace tab
cmux new-surface                                  # new tab in current pane
```

## Launch Claude Code in a Pane

Network access requires `proxy`. Always include it before `claude`.

```bash
# Interactive mode — user can switch to this pane and intervene anytime
cmux send --surface <ref> 'proxy && claude --dangerously-skip-permissions\n'

# Non-interactive mode — run a task, capture output, signal completion
cmux send --surface <ref> 'proxy && claude -p "your prompt" --model haiku 2>&1 | tee /tmp/agent-output.txt; echo "AGENT_DONE"\n'
```

## Send Input / Read Output

```bash
cmux send --surface <ref> "text\n"                # send text (include \n for Enter)
cmux send-key --surface <ref> <key>               # send special key (ctrl-c, enter, etc.)
cmux read-screen --surface <ref> --lines <n>      # read last n lines of terminal output
```

## Sidebar Status & Progress

The sidebar is always visible — use it to give the user a glance at what's happening without switching panes.

```bash
cmux set-status <key> <value> --icon <name> --color <#hex>
cmux set-progress <0.0-1.0> --label "text"
cmux log --level <info|success|warning|error> --source "agent" -- "message"
cmux notify --title "Title" --body "Body"         # desktop notification
cmux clear-status <key> / cmux clear-progress / cmux clear-log
```

## Workspace Management

```bash
cmux rename-workspace "name"
cmux rename-tab --surface <ref> "name"
cmux close-surface --surface <ref>
cmux close-workspace --workspace <ref>
```

## Browser (quick reference)

Open sites in cmux's built-in browser, interact with pages, take screenshots. Read [references/browser.md](references/browser.md) for full command reference, form automation, and troubleshooting.

```bash
cmux --json browser open https://example.com      # open browser split, returns surface ref
cmux browser <surface> wait --load-state complete --timeout-ms 15000
cmux browser <surface> snapshot --interactive      # get clickable element refs
cmux browser <surface> click e1                    # click element by ref
cmux browser <surface> fill e2 "text"              # fill input field
cmux browser <surface> screenshot --out /tmp/s.png # take screenshot
cmux browser <surface> get url                     # current URL
cmux browser <surface> get title                   # page title
cmux browser <surface> navigate <url>              # go to URL
```

## Markdown Preview (quick reference)

Display formatted markdown alongside the terminal with live reload. Read [references/markdown.md](references/markdown.md) for routing options and agent integration patterns.

```bash
cmux markdown open plan.md                         # open preview panel (auto-reloads on file change)
cmux markdown open plan.md --workspace workspace:2 # target specific workspace
```

## Workflow Patterns

### Fan out into splits (parallel tasks)

```bash
cmux new-split right
cmux send --surface surface:2 'proxy && claude -p "analyze project structure" --model haiku > /tmp/a1.txt; echo "DONE"\n'

cmux new-split down
cmux send --surface surface:3 'proxy && claude -p "count code lines" --model haiku > /tmp/a2.txt; echo "DONE"\n'

cmux set-status task "Running" --icon hammer --color "#1565C0"
# Poll: cmux read-screen --surface surface:2 --lines 5
# Collect: cat /tmp/a1.txt /tmp/a2.txt
# Clean up: cmux close-surface --surface surface:2 && cmux close-surface --surface surface:3
```

### Interactive sub-agents (user can intervene)

```bash
cmux new-split right
cmux send --surface surface:2 'proxy && claude --dangerously-skip-permissions\n'
# User can ⌥⌘→ to switch to that pane and talk to the sub-agent directly
```

### Progress tracking

```bash
cmux set-progress 0.0 --label "Starting"
# ... work ...
cmux set-progress 0.5 --label "Testing"
# ... work ...
cmux set-progress 1.0 --label "Complete"
cmux clear-progress
cmux notify --title "Done" --body "All tasks finished"
```

## Safety Rules

- **Don't send to surfaces you didn't create** — the user may be actively typing there.
- **Always target by surface ref** — use `--surface <ref>` from when you created the pane.
- **Don't steal focus** — avoid `select-workspace`, `focus-pane` unless the user asked.
- **Clean up after yourself** — close surfaces/workspaces you created once done.
- **Start with `identify --json`** — know your context before creating terminals.
