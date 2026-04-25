---
name: cmux
description: "cmux multi-pane / multi-agent terminal orchestration via cmux CLI (Bash cannot split panes or spawn agents). Use for parallel panes, splits, spawning Claude/Codex sub-agents, sending keys (incl. ctrl-c) between panes, reading pane output, sidebar updates, browser/markdown panes. Triggers: 'in parallel', 'split pane', 'spawn agent', 'fan out', 'browser pane', 'sidebar', '分屏', '并行', '开个 pane'. Not for plain bash or generic tmux."
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
cmux trigger-flash --surface <ref>               # flash surface for visual confirmation
cmux surface-health                               # detect hidden/detached surfaces
```

## Create Terminals

```bash
cmux new-split <left|right|up|down>               # split current pane
cmux new-workspace --cwd <path>                   # new workspace tab
cmux new-surface                                  # new tab in current pane
```

## Launch Agents in a Pane

Network access requires proxy env vars. Always set them before agent commands.

**Important**: When sending compound commands (proxy export + agent launch), send them as a single string to `cmux send`. Do NOT split into separate `send` calls — the second command would run before the first finishes.

```bash
# Claude Code — interactive mode (user can switch to this pane and intervene)
cmux send --surface <ref> 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && claude --dangerously-skip-permissions\n'

# Claude Code — non-interactive mode (run task, capture output, signal completion)
cmux send --surface <ref> 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && claude -p "your prompt" --model haiku 2>&1 | tee /tmp/agent-output.txt; echo "AGENT_DONE"\n'

# Codex — interactive mode (full-auto, user can intervene)
cmux send --surface <ref> 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && codex --dangerously-bypass-approvals-and-sandbox\n'

# Codex — with initial prompt
cmux send --surface <ref> 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && codex --dangerously-bypass-approvals-and-sandbox -p "your prompt"\n'
```

When the user asks to "split a pane with Codex/Claude/agent", always:
1. `cmux new-split <direction>` to create the pane
2. `cmux send --surface <new-ref> '<export https_proxy=... && agent command>\n'` to launch
3. Optionally send context after the agent starts: `cmux send --surface <new-ref> 'prompt'` then `cmux send-key --surface <new-ref> enter`

## Send Input / Read Output

```bash
cmux send --surface <ref> 'text\n'                # send text + Enter (for shell commands)
cmux send --surface <ref> 'text'                  # send text only (no Enter)
cmux send-key --surface <ref> <key>               # send special key (ctrl-c, enter, etc.)
cmux read-screen --surface <ref> --lines <n>      # read last n lines of terminal output
```

**Shell vs interactive programs**: `\n` works as Enter for shell prompts (bash processes it via line discipline). But interactive programs in raw terminal mode (Claude Code, vim, etc.) treat `\n` as a literal newline character, not a submit action. For those, send text without `\n`, then use `send-key enter`:

```bash
# Shell command — \n works as Enter
cmux send --surface <ref> 'ls -la\n'

# Interactive program — use send-key enter to submit
cmux send --surface <ref> 'your message here'
cmux send-key --surface <ref> enter
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
cmux send --surface surface:2 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && claude -p "analyze project structure" --model haiku > /tmp/a1.txt; echo "DONE"\n'

cmux new-split down
cmux send --surface surface:3 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && claude -p "count code lines" --model haiku > /tmp/a2.txt; echo "DONE"\n'

cmux set-status task "Running" --icon hammer --color "#1565C0"
# Poll: cmux read-screen --surface surface:2 --lines 5
# Collect: cat /tmp/a1.txt /tmp/a2.txt
# Clean up: cmux close-surface --surface surface:2 && cmux close-surface --surface surface:3
```

### Interactive sub-agents (user can intervene)

Launch an agent in a split pane that the user can interact with directly:

```bash
# Claude Code in right split
cmux new-split right
cmux send --surface surface:2 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && claude --dangerously-skip-permissions\n'

# Codex in right split (full-auto mode)
cmux new-split right
cmux send --surface surface:2 'export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 ALL_PROXY=socks5://127.0.0.1:7890 && codex --dangerously-bypass-approvals-and-sandbox\n'
```

To feed context to the agent after it starts (e.g., a handoff prompt):
```bash
# Wait for the agent to be ready, then send context
sleep 5
cmux send --surface surface:2 'Here is the task: ...'
cmux send-key --surface surface:2 enter
```

User can press `⌥⌘→` to switch to the agent pane and talk to it directly.

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
