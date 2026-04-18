# Remote Cluster Agent

![Version](https://img.shields.io/badge/version-0.4.0-blue)

English | [中文](README.zh-CN.md)

> A skill for Claude Code / Codex to operate GPU clusters — edit code locally, run commands remotely with ~0.1s latency via a local Go daemon + persistent SSH agent connections.

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill remote-cluster-agent
```

Then build and install the `rca` CLI (requires Go 1.21+):

```bash
cd <skill_dir>
make install
```

Restart your agent, then say "connect to cluster" to start. Your agent will guide you through setup automatically on first use.

## What's New in v0.4.0

**Architecture: MCP server → Go daemon + `rca` CLI**

- **Breaking**: The Python MCP server is replaced with a local Go daemon and `rca` CLI.
  - Single `rca` binary: background daemon (lazy-start, auto-spawn on first CLI call) + CLI subcommands (stateless HTTP client over Unix socket).
  - Migration: `make install` then `rca config init` — auto-detects legacy `~/.config/remote-cluster-agent/*.md` and converts to `~/.config/rca/config.toml`.
  - Tool rename: `remote_bash(node, cmd)` → `rca exec -n <node> "<cmd>"`; `remote_bash_batch` → `rca batch`.

**New capabilities**

- `rca batch` — parallel command execution across multiple nodes.
- `rca cp` — file transfer via the agent's JSON-Lines channel (base64, 50 MB/file), works with any SSH transport.
- `rca nodes --check / --health` — deep latency probe + historical latency tracking (via the built-in node health monitor).
- `rca agent check / deploy` — cluster-side agent lifecycle management.
- `rca daemon register` — optional launchd auto-start on macOS.

**Agent protocol v2.1**

- Streaming output line-by-line.
- Request cancellation.
- Batch execution in one round-trip.
- Read/write file through the agent channel (no separate SCP step).

**Fixes**

- **Fixed**: MCP stdio drops eliminated entirely — the daemon communicates with your AI agent through CLI invocations, no more progress-notification races on MCP transport.
- **Fixed**: Multi-session SSH explosion — N sessions × M nodes collapses to 1 daemon × M persistent connections.

## Architecture

```
Local Machine                            GPU Cluster (no internet needed)
├── Claude Code / Codex (Read/Edit/Write)└── /path/to/project/
│   ~0.5ms per operation                     ├── training scripts
├── Mutagen real-time sync ◄──SSH──────────► code + logs
├── rca CLI ─────► rcad ◄──SSH──────────► bash commands
│                  (Unix socket,             └── agent.py (persistent)
│                   connection pool)              JSON-Lines v2.1
└── Read results locally (~20x faster)
```

**Key properties**:

| Property | Value |
|----------|-------|
| Latency | ~0.1s/command (persistent SSH + JSON-Lines) |
| Concurrency | One daemon serves all CC/Codex sessions |
| Install | `make install` → `~/go/bin/rca` (~8 MB, zero runtime deps) |

### The automation loop

```
Edit code (local) → Mutagen syncs instantly → Run experiment (remote) → Logs sync back → Read results (local) → repeat
```

- **Code editing**: local native tools (~0.5ms)
- **Code sync**: [Mutagen](https://mutagen.io) real-time one-way-replica sync over SSH (see [MUTAGEN.md](MUTAGEN.md))
- **Remote execution**: `rca exec` / `rca batch` — routed through a single local daemon
- **Reading results**: local `Read` tool (~20x faster than reading through remote exec)

## Quick start

### 1. Install the skill

```bash
npx skills add jiahao-shao1/sjh-skills --skill remote-cluster-agent
```

### 2. Build and install the CLI

```bash
cd <skill_dir>
make install
```

This builds `rca` into `$(go env GOPATH)/bin`. Make sure that directory is on your `PATH`.

### 3. Initialize config

```bash
rca config init
```

- Fresh install → generates an annotated `~/.config/rca/config.toml` template.
- Legacy markdown config at `~/.config/remote-cluster-agent/` → auto-migrated.

Edit the config to add your nodes:

```toml
socket_path = "~/.config/rca/rca.sock"
default_dir = "/home/user/project"
agent_path  = "/shared/.agent/agent.py"

[nodes.train]
ssh = "ssh gpu-train"

[nodes.eval]
ssh = "ssh -p 2222 gpu-eval"
dir = "/home/user/eval-project"       # optional per-node override
```

### 4. Start the daemon

```bash
rca daemon start
rca daemon status
rca nodes
rca agent deploy           # push agent.py to each node
```

Optional: `rca daemon register` to auto-start via launchd on macOS.

### 5. Set up Mutagen sync

```bash
bash <skill_dir>/mutagen-setup.sh gpu-train ~/repo/my_project /home/user/my_project
```

See [MUTAGEN.md](MUTAGEN.md) for details. Works entirely over SSH — no public internet required on the cluster.

## Configuration

Single config file: `~/.config/rca/config.toml`.

```toml
socket_path = "~/.config/rca/rca.sock"
default_dir = "/home/user/project"
agent_path  = "/shared/.agent/agent.py"

[monitor]
enabled           = true
interval          = "30s"
latency_threshold = "200ms"
latency_multiplier = 3.0
auto_reconnect    = false

[nodes.train]
ssh = "ssh gpu-train"

[nodes.eval]
ssh = "ssh -p 2222 gpu-eval"
```

Edit with `rca config edit`, show effective config with `rca config show`.

## File structure

```
remote-cluster-agent/
├── SKILL.md                          # Skill instructions for your agent
├── README.md                         # This file
├── README.zh-CN.md                   # Chinese version
├── MUTAGEN.md                        # Mutagen sync guide
├── VERSION                           # 0.4.0
├── Makefile                          # build / install / test
├── go.mod / go.sum                   # Go dependencies
├── cmd/rca/                          # CLI entry point + subcommands
├── internal/
│   ├── agent/                        # SSH agent connection (JSON-Lines v2.1)
│   ├── client/                       # HTTP client over Unix socket
│   ├── config/                       # TOML loader + legacy migration
│   ├── daemon/                       # HTTP server, connection pool, monitor
│   └── protocol/                     # Shared types (daemon ↔ CLI)
├── launchd/
│   └── com.rca.daemon.plist          # launchd template for auto-start
├── cluster-agent/
│   └── agent.py                      # Cluster-side agent (zero deps, v2.1.0)
├── mutagen-setup.sh                  # Mutagen file sync setup
├── reference/
│   ├── cluster-health.md             # Health check procedure
│   └── mutagen-troubleshooting.md    # Mutagen recovery playbook
└── docs/
    ├── architecture.png              # Architecture diagram
    └── architecture.html             # Interactive version
```

## Acknowledgements

Heavily inspired by [claude-code-local-for-vscode](https://github.com/justimyhxu/claude-code-local-for-vscode).

Thanks to [@cherubicXN](https://github.com/cherubicXN) for the Mutagen-based local-cluster real-time sync pattern.

## License

MIT
