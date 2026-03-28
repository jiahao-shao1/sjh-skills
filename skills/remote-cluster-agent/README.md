# Remote Cluster Agent

![Version](https://img.shields.io/badge/version-0.3.0-blue)

English | [中文](README.zh-CN.md)

> A skill for Claude Code / Codex to operate GPU clusters — edit code locally, run commands remotely with ~0.1s latency via persistent SSH agent connections.

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill remote-cluster-agent
```

Restart your agent after installing, then say "connect to cluster" to start. Your agent will guide you through the setup automatically on first use (nodes, paths, MCP server installation).

## What's New in v0.3.0

- **Two-layer configuration**: Global infrastructure config + per-project config at `~/.config/remote-cluster-agent/`
- **Auto agent deployment**: Agent is auto-detected and deployed on startup — no manual "deploy agent" step
- **Cluster health inspection**: Parallel GPU/disk/tmux/load scanning across all nodes with smart recommendations
- **Unified MCP server**: Single `cluster` MCP server with `node` parameter routing (replaces per-node servers)
- **one-way-replica sync**: Default Mutagen mode, syncs `.git` for clean cluster-side git status, never conflicts
- **Read-local-first guidance**: Smart prompts to read Mutagen-synced files locally instead of via remote_bash
- **SSH config generation**: Auto-generates `~/.ssh/config` entries with best-practice settings

## Architecture

![Architecture](docs/architecture.png)

> [Interactive version](docs/architecture.html) — click to toggle between Agent and Sentinel modes.

**Two execution modes** — agent mode is ~10x faster, sentinel mode is the automatic fallback:

| Mode | Latency | How it works |
|------|---------|-------------|
| **Agent mode** | ~0.1s | Persistent SSH connection → cluster-side `agent.py` → JSON-Lines protocol |
| **Sentinel mode** | ~1.5s | Per-command SSH → sentinel pattern detection → `proc.kill()` |

```
Local Machine                            GPU Cluster (no internet needed)
├── Claude Code / Codex (Read/Edit/Write)└── /path/to/project/
│   ~0.5ms per operation                     ├── training scripts
├── Mutagen real-time sync ◄──SSH──────────► code + logs
├── remote_bash MCP ──────────SSH──────────► bash commands
│   agent mode: ~0.1s                       └── agent.py (persistent)
│   sentinel fallback: ~1.5s
└── Read results locally (~20x faster)
```

### The Automation Loop

```
Edit code (local) → Mutagen syncs instantly → Run experiment (remote) → Logs sync back → Read results (local) → repeat
```

- **Code editing**: Local native tools (fast, ~0.5ms)
- **Code sync**: [Mutagen](https://mutagen.io) real-time one-way-replica sync over SSH (see [MUTAGEN.md](MUTAGEN.md))
- **Remote execution**: `remote_bash` MCP tool — single MCP server, multi-node routing via `node` parameter
- **Reading results**: Local native Read tool (~20x faster than reading through remote MCP)

## Quick Start

### 1. Install the skill

```bash
npx skills add jiahao-shao1/sjh-skills --skill remote-cluster-agent
```

### 2. Install the MCP server

The installer supports both Claude Code and Codex, with auto-detection. Use `--client` to pick one explicitly.

**Multi-node (recommended)**:
```bash
bash <skill_dir>/mcp-server/setup.sh '{"train":"ssh -p 2222 gpu-node","eval":"ssh gpu-eval"}' /home/user/project
```

**Legacy single-node**:
```bash
bash <skill_dir>/mcp-server/setup.sh train "ssh -p 2222 gpu-node" /home/user/project
```

**With explicit client**:
```bash
bash <skill_dir>/mcp-server/setup.sh --client codex '{"train":"ssh -p 2222 gpu-node"}' /home/user/project
```

Prerequisites: [uv](https://docs.astral.sh/uv/), SSH access to cluster, Claude Code or Codex CLI.

### 3. Restart and auto-deploy

Restart your agent. The Agent is auto-detected and deployed on first use — no manual step needed. Without it, sentinel mode (~1.5s/command) is the automatic fallback.

### 4. Set up Mutagen sync

```bash
bash <skill_dir>/mutagen-setup.sh gpu-node ~/repo/my_project /home/user/my_project
```

See [MUTAGEN.md](MUTAGEN.md) for details. Works entirely over SSH — no public internet required on the cluster.

### 5. First-time interactive setup

On first use, your agent asks a few questions (SSH endpoints, paths, safety rules) and generates config at `~/.config/remote-cluster-agent/`. This config stays local — never committed to git.

## Configuration

Two-layer configuration at `~/.config/remote-cluster-agent/`:

| File | Purpose |
|------|---------|
| `context.local.md` | Global: cluster nodes, shared storage, safety rules, GPU scripts |
| `<project>.md` | Per-project: code paths, Mutagen sessions, output sync |

Generated through interactive setup on first use.

## File Structure

```
remote-cluster-agent/
├── SKILL.md                          # Skill instructions for your agent
├── README.md                         # This file
├── README.zh-CN.md                   # Chinese version
├── MUTAGEN.md                        # Mutagen sync guide
├── VERSION                           # 0.3.0
├── .gitignore
├── cluster-agent/
│   └── agent.py                      # Cluster-side agent (zero deps, ~100 lines)
├── mcp-server/
│   ├── mcp_remote_server.py          # MCP server with agent + sentinel modes
│   ├── pyproject.toml                # Dependencies: mcp>=1.25
│   └── setup.sh                      # One-command install (Claude Code / Codex)
├── mutagen-setup.sh                  # Mutagen file sync setup
├── reference/
│   ├── context.template.md           # Global config template
│   ├── project.template.md           # Project config template
│   └── cluster-health.md             # Health check procedure
└── docs/
    ├── architecture.png              # Architecture diagram
    └── architecture.html             # Interactive version
```

## Acknowledgements

Heavily inspired by [claude-code-local-for-vscode](https://github.com/justimyhxu/claude-code-local-for-vscode).

Thanks to [@cherubicXN](https://github.com/cherubicXN) for the implementation of Mutagen-based local-cluster real-time sync.

## License

MIT
