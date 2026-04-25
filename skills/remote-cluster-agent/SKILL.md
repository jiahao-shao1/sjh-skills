---
name: remote-cluster-agent
description: "Remote GPU cluster ops via `rca` CLI — run commands, transfer files, GPU/node inspection, mutagen sync. Trigger for any remote execution, training, GPU, cluster status, sync, or tail-log task even when 'cluster' isn't said. Triggers: cluster, GPU, rca, training, node, sync code, tail log, 集群, 节点, 远程执行, 同步代码, 跑训练, 看日志, GPU 占用."
---

# remote-cluster-agent

Local control plane for remote GPU clusters: a Go daemon + `rca` CLI. All commands go through the daemon's Unix socket to a cluster-side Python `agent.py` over persistent SSH, ~0.1s/command latency.

## What to do when triggered

1. **Check if `rca` is installed**: run `which rca`.
   - If `not found` → run the first-time install flow (below), then continue to step 2.
2. **Check daemon status**: run `rca daemon status`.
   - If `daemon request failed` → run `rca daemon start`.
3. **Check node connectivity**: run `rca nodes`.
   - If the target node is dead → `rca connect <node>`. Still dead → re-establish whatever SSH tunneling / VPN / jump host you depend on, then retry.
   - Second round still dead → read `rca daemon logs -f` for error detail.
4. Run the user's command.

**Don't write raw `ssh` commands**, always use `rca exec` / `rca batch`.

### First-time install (auto, no user action needed beyond SSH info)

When `which rca` returns not found, execute in order:

```bash
cd <skill_dir>
make install              # builds rca into ~/go/bin (requires Go 1.21+)
rca config init           # migrates legacy ~/.config/remote-cluster-agent/*.md, or generates blank template
```

Then **ask the user** for each node's SSH command, and write them into `~/.config/rca/config.toml` under `[nodes.*]`. Example:

```toml
[nodes.train]
ssh = "ssh gpu-train"

[nodes.eval]
ssh = "ssh -p 2222 gpu-eval"
dir = "/home/user/project"
agent_path = "/shared/.agent/agent.py"
```

Optional per-node overrides: `dir` (default working directory) and `agent_path` (where `agent.py` lives on that node). Both fall back to globals if unset.

Finally start and verify:

```bash
rca daemon start
rca daemon status         # confirm running
rca nodes                 # confirm nodes connected
rca agent check           # if agent missing → rca agent deploy
```

## Common operations

### Single-node exec / heredoc

```bash
rca exec -n train "nvidia-smi"
rca exec -n train -d /home/user/project "git pull"
rca exec -t 600 -n train "python train.py"

# heredoc (bypasses shell escaping, recommended for multi-line or special chars)
rca exec --stdin -n train <<'EOF'
cd /home/user/project
python -c "import json; print(json.dumps({'k':'v \"q\"'}))"
EOF
```

### Multi-node parallel (batch)

```bash
rca batch "nvidia-smi | head -20"
rca batch -n train,eval "df -h /home"
rca batch --json "hostname" | jq -r '.results[] | "\(.node): \(.output)"'
```

### Node status / connection management

```bash
rca nodes                   # current connection state
rca nodes --check           # deep ping (with latency)
rca nodes --health          # latency history (monitor-tracked)
rca connect train           # manually reconnect a dead node
rca disconnect train        # actively close a node's connection
```

### File transfer (cp)

`rca cp` moves files through the agent's JSON-Lines channel (base64-encoded, 50 MB/file limit). Works on any SSH setup — no separate SCP/rsync path needed.

```bash
rca cp train:/home/user/logs/train.log ./
rca cp ./config.yaml train:/home/user/project/config.yaml
rca cp -r train:/home/user/checkpoints/exp07 ./local-copy/
```

For very large files (multi-GB checkpoints), use shared filesystem or object storage — `rca cp` peaks around 2–3 MB/s.

### Streaming / long tasks

```bash
rca exec -s -n train "tail -f /var/log/train.log"
rca exec -s -n train "python train.py"
```

### Cluster health inspection

Triggered when the user says "cluster status", "which node is free", "cluster health", "GPU usage". Use `rca batch` for parallel sampling:

```bash
rca nodes --check
rca batch "nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv"
rca batch "df -h /home | tail -1"
rca batch "uptime && tmux ls 2>/dev/null | wc -l"
```

Summarize into a table and recommend the most idle node. See `reference/cluster-health.md` for detailed probe commands, parse rules, and report format.

## Reading files vs running commands

`rca exec` is for **executing commands** (starting training, killing processes, checking process state, installing deps) — not reading file contents.

If mutagen real-time sync is configured, the cluster's `outputs/` appears locally automatically. For logs, JSON results, CSV — use the native `Read` tool on the local path. That's ~20x faster than piping through the SSH connection.

**Decision rule**:
- Want to **read file content** (logs, JSON, CSV, config files) → `Read("outputs/...")` locally
- Want to **run an operation** (ps, nvidia-smi, start/stop, pip install) → `rca exec`
- Unsure if the file is synced locally → `ls outputs/` or `Glob("outputs/**/<pattern>")` first

Typical mistake: `rca exec -n train "cat /home/user/outputs/.../log.txt"` to read a log. That file is already synced — just `Read` it.

## SSH connection failures

When `rca nodes --check` shows dead, or `rca exec` reports connect failed:

1. Try `rca connect <node>` once — most transient issues resolve here.
2. Still dead? The SSH transport underneath is broken. `rca` itself doesn't manage tunnels / VPN / jump hosts — re-establish those through your usual workflow (ssh config, tunnel script, corporate VPN, etc.), then retry step 1.
3. Inspect daemon errors with `rca daemon logs -f`.

Report failures grouped by cause — don't just say "all nodes failed". Which nodes recovered? Which need tunnel re-establishment? Which look like SSH config issues?

## Mutagen session health

When the user mentions "skill updated" or "redeploy", check mutagen session config:

```bash
mutagen sync list 2>/dev/null
```

For each session:
1. **Sync mode**: should be `one-way-replica`. If `one-way-safe` or `two-way-resolved`, prompt to rebuild.
2. **Ignore list**: `.git` should NOT be ignored (v0.4.0+ syncs `.git` to keep cluster-side `git status` clean).

Rebuild (only after user confirms):
```bash
mutagen sync list <name> --long    # record current params first
mutagen sync terminate <name>
bash <skill_dir>/mutagen-setup.sh <ssh_host> <local_dir> <remote_dir> <session_name>
```

### Container restart: mutagen fails to reconnect

**Symptom**: `mutagen sync list` shows Beta `Connected: No`; `mutagen sync resume` reports `server magic number incorrect`.

**Root cause**: the cluster container restarted and lost `~/.mutagen/` (container home is ephemeral). Mutagen's agent binary and staging data live in a persistent path (typically mounted storage like `/shared/.mutagen/`).

**Fix**:
```bash
# Recreate the symlink on the cluster node
rca exec -n <node> "ln -sf /shared/.mutagen ~/.mutagen"

# Then resume locally
mutagen sync pause <session-name>
mutagen sync resume <session-name>
```

**Prevention**: have the container init script create this symlink on startup.

See `reference/mutagen-troubleshooting.md` for more failure modes.

## Config

Main config: `~/.config/rca/config.toml` (edit via `rca config edit`).

First-time install flow is in "What to do when triggered → First-time install". Day-to-day, just keep the daemon running (`rca daemon status`).

### Agent deployment / updates

```bash
rca agent check               # show agent version per node
rca agent deploy              # copy local agent.py (only where missing)
rca agent deploy --force      # force overwrite
```

> **Note**: `rca agent deploy` uses direct SSH (bypasses the daemon) and iterates all nodes in `config.toml` serially. Disconnected nodes will block for SSH's default connect timeout (minutes). Workaround — use a temp config with only live nodes:
>
> ```bash
> cp ~/.config/rca/config.toml /tmp/rca_deploy.toml
> # manually delete [nodes.*] sections for dead nodes
> rca --config /tmp/rca_deploy.toml agent deploy --force
> ```

### Auto-start (optional, macOS)

```bash
rca daemon register           # register launchd agent (requires App Management permission)
```

Without this, start the daemon manually with `rca daemon start` whenever you reboot.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `daemon request failed` | `rca daemon start`; if still failing `rca daemon logs -f` |
| Node status=dead | `rca connect <node>`; if still dead, re-establish SSH tunneling |
| tunnel down | Reconnect through your usual workflow (ssh config, VPN, tunnel script) |
| agent missing | `rca agent deploy` |
| Command special chars | Use `rca exec --stdin <<'EOF' ... EOF` |
| daemon crash | `rca daemon start` (launchd auto-restarts if registered) |

## Safety boundaries

- Read shared storage restrictions from your config and follow them strictly — files on shared paths often belong to other teams, there's typically no recycle bin, and deletion can destroy days of someone else's work.
- If the cluster has no public internet, use internal PyPI mirrors — don't attempt external URLs (GitHub, PyPI.org, etc.).
- Don't auto-push to `master`/`main` — avoid shipping unreviewed code to teammates.
- **`pkill -f` must use the bracket trick**: `pkill -f "[s]glang.launch_server"` not `pkill -f "sglang.launch_server"` — because the SSH process command line contains the kill pattern, `pkill -f` would match SSH itself and tear the connection down. Same applies to `pgrep -f`, `grep` over process lists, etc.
- **Long-running processes must be backgrounded**: if a process doesn't exit (inference server, training loop), use `nohup ... &` or `tmux new-session -d`, with `echo` placed **after** the background command using `;`:
  ```bash
  # Correct: nohup background + echo outside
  nohup python -m sglang.launch_server ... > /tmp/log 2>&1 & echo "PID=$!"
  # Correct: tmux detach + echo outside
  tmux new-session -d -s sglang "python -m sglang.launch_server ..."; echo "started"
  # Wrong: echo inside tmux's && chain, never executes
  tmux new-session -d -s sglang "python ... && echo started"
  ```

## Architecture

The daemon runs independently of Claude Code (Unix socket), so every session shares one connection pool. The CLI is standalone too — usable in shells, scripts, or cron. Cluster-side `agent.py` speaks JSON-Lines v2.1.0 (streaming, cancel, batch, file transfer).

> **Upgrading from MCP v0.3.x**: `remote_bash(node, cmd)` → `rca exec -n node "cmd"`, `remote_bash_batch` → `rca batch`. Legacy `~/.config/remote-cluster-agent/*.md` markdown config auto-migrates on `rca config init`.
