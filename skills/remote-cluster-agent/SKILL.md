---
name: remote-cluster-agent
description: Remote GPU cluster operations and health inspection. Use when the user mentions cluster, remote execution, GPU, training, code sync, mutagen, cluster status, or node inspection. Trigger words include but are not limited to: "connect to cluster", "sync code", "GPU occupancy", "run on cluster", "remote bash", "run training", "check logs", "tail log", "mutagen", "cluster status", "node status", "which node is free", "most idle node", "cluster health", "GPU usage", "连集群", "同步代码", "GPU 占用", "集群上跑", "在服务器上", "跑训练", "看日志", "集群状态", "节点状态", "哪个节点空", "最空闲节点", "集群巡检", "GPU 占用情况". Even if the user doesn't explicitly mention the cluster, trigger this skill whenever the task involves remote execution, training operations, or cluster status queries.
---

# Remote Cluster Agent

Execute commands on remote GPU clusters via a single MCP server providing `remote_bash` with `node` parameter routing.
Uses persistent SSH connections + cluster-side Agent mode for ~0.1s command latency (old sentinel mode: ~1.5s, ~10x speedup).

> **`<skill_dir>`** refers to the directory containing this SKILL.md (i.e., `remote-cluster-agent/`). Replace with the actual absolute path when running commands.

## Step 0: Check Configuration

Read two layers of configuration:

1. **Global**: `~/.config/remote-cluster-agent/context.local.md` (cluster nodes, shared storage, safety rules)
2. **Project-level**: `~/.config/remote-cluster-agent/<project>.md` (code paths, Mutagen sessions, output sync)

Where `<project>` defaults to the current project root directory name, e.g., `my_project` maps to `~/.config/remote-cluster-agent/my_project.md`.

- **Both exist** → Merge context, check Agent deployment status (below), then jump to "Core Operations"
- **Global missing** → Enter "First-Time Setup"
- **Global exists, project-level missing** → Prompt user to create `~/.config/remote-cluster-agent/<project>.md`
- **Repo has `<project_root>/.claude/cluster-context.md`** → Treat as compatibility entry; if it declares source of truth is in `~/.config`, continue reading from there

### Agent Deployment Detection

After config is loaded, check whether the cluster-side Agent is deployed via `remote_bash`:

```bash
test -f <agent_path> && echo '{"type":"ping"}' | python3 <agent_path>
```

- **Returns pong** → Agent ready, proceed normally
- **File missing or ping fails** → Auto-execute Step F (deploy Agent) without requiring user action

### Mutagen Session Health Check

When the user mentions "skill updated" or "redeploy", also check Mutagen session health:

```bash
mutagen sync list 2>/dev/null
```

Check each session:
1. **Sync mode**: Should be `one-way-replica`. If `one-way-safe` or `two-way-resolved`, warn:
   ```
   ⚠️ Session "<name>" uses old mode <old_mode>. Recommend rebuilding as one-way-replica (never conflicts).
   Rebuild now? (requires terminate + recreate, sync will briefly pause)
   ```
2. **Ignore list**: `.git` should NOT be in the ignore list (v0.3.0+ syncs .git to keep cluster-side git status clean). If `.git` is ignored, suggest rebuilding.

Rebuild commands (execute only after user confirms):
```bash
# Record current parameters
mutagen sync list <name> --long

# Rebuild
mutagen sync terminate <name>
bash <skill_dir>/mutagen-setup.sh <ssh_host> <local_dir> <remote_dir> <session_name> [extra_ignores...]
```

## First-Time Setup

Use AskUserQuestion to collect info, generating `~/.config/remote-cluster-agent/context.local.md`. Goal: complete in 2 rounds.

### Round 1: Nodes + Project Paths (3-4 questions)

Ask these simultaneously:

1. **SSH command and name for each node**
   - header: "Nodes"
   - Format: `<name> <ssh_command>` — one node per line, e.g.:
     ```
     train ssh -p 2222 gpu-node
     eval ssh gpu-eval
     ```

2. **Project code path on the cluster**
   - header: "Project path"
   - Options: "/home/user/projects/<project_name>" / "Custom path"

3. **GPU occupancy anti-reclaim**
   - header: "GPU occupancy"
   - Options: "Yes (I have start/stop scripts)" / "Yes (scripts at custom path)" / "No"

### Round 2: Safety + Storage (2-3 questions)

1. **Shared storage safety restrictions**
   - header: "Safety"
   - Options: "Has protected shared paths" / "No special restrictions" / "Custom"

2. **Shared storage path (for Agent deployment)**
   - header: "Storage"
   - The agent needs a path accessible from all nodes that persists across container restarts
   - Options: "~/.mcp-agent/ (home directory)" / "Custom path"

3. **(Conditional) GPU script paths** — only if Round 1 selected "custom path"

### Generate Config & Install

Execute the following steps based on collected info:

**Step A: (Optional) SSH Tunnel Setup**

If the user needs SSH tunnels (e.g., port forwarding through a jump host), help them set up SSH config entries. If they already have direct SSH access, skip this step.

**Step B: Generate SSH Config**

For each node, add a host alias in `~/.ssh/config`. Mutagen real-time sync depends on it; manual SSH is also easier. Check for existing entries to avoid duplicates.

Each node gets an entry like:
```
Host cluster-<name>
  Hostname <host>
  Port <port>
  User root
  StrictHostKeyChecking accept-new
  UserKnownHostsFile /dev/null
  LogLevel ERROR
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

- `StrictHostKeyChecking accept-new`: Auto-accept new host keys but reject changed ones
- `LogLevel ERROR`: Suppress SSH warnings that can corrupt agent/mutagen stdout protocols
- `ServerAliveInterval 30`: Keep-alive for persistent Agent mode connections

**Step C: Generate Config Files**

Using `reference/context.template.md` (global) and `reference/project.template.md` (project-level) as templates, fill in user answers to generate:
- `~/.config/remote-cluster-agent/context.local.md` (global infrastructure)
- `~/.config/remote-cluster-agent/<project>.md` (project-specific: code paths, Mutagen sessions, output paths)

**Step D: Build NODES JSON**

Combine all node names and SSH commands into JSON. For example, with two nodes:
```
NODES='{"train":"ssh -p 2222 gpu-node","eval":"ssh gpu-eval"}'
```

**Step E: Install MCP Server**

```bash
bash <skill_dir>/mcp-server/setup.sh "$NODES" <project_path>
```

If the agent path is not the default `~/.mcp-agent/agent.py`, append it:
```bash
bash <skill_dir>/mcp-server/setup.sh "$NODES" <project_path> <agent_path>
```

**Step F: Deploy Cluster-Side Agent**

The Agent enables ~0.1s command latency (without it, sentinel mode runs at ~1.5s). This step runs **automatically** after MCP server installation — no manual user action needed.

1. Read `<skill_dir>/cluster-agent/agent.py` content
2. Write to cluster via `remote_bash`:
   ```bash
   mkdir -p $(dirname <agent_path>)
   cat > <agent_path> << 'AGENT_EOF'
   ... (full agent.py content)
   AGENT_EOF
   chmod +x <agent_path>
   python3 -c "import ast; ast.parse(open('<agent_path>').read()); print('syntax OK')"
   ```
3. Verify Agent works:
   ```bash
   echo '{"type":"ping"}' | python3 <agent_path>
   ```

> Note: Step F requires the MCP server to be loaded (i.e., restart after Step E). Actual flow:
> Steps A-E → Prompt restart → After restart, auto-detect Agent not deployed → Auto-execute Step F → Done.

**Step G: Prompt Restart**

Tell the user to restart their agent (Claude Code / Codex) to load the new MCP server. Validation runs automatically after restart.

**Step H: Post-Restart Validation**

After restart, run end-to-end validation to confirm everything works:

1. **MCP server connectivity**: Execute a simple command on each node
   ```bash
   remote_bash(node="<each_node>", command="echo OK && hostname")
   ```
2. **Agent deployment detection**: Check agent (see Step 0), auto-deploy if missing
3. **Agent mode verification**: Confirm agent connection (not sentinel fallback)
   ```bash
   remote_bash(node="<default_node>", command="echo agent-test")
   ```
   Check `elapsed` field — Agent mode should be < 0.5s, sentinel is typically > 1s
4. **Project path reachable**:
   ```bash
   remote_bash(node="<default_node>", command="test -d <project_dir> && echo EXISTS || echo MISSING")
   ```

Report results as a table:

```
✅ Configuration verified

| Check | Status | Details |
|-------|--------|---------|
| MCP server (train) | ✅ | hostname: gpu-train-01 |
| MCP server (eval) | ✅ | hostname: gpu-eval-01 |
| Agent deployment | ✅ | v1.0.0, pid 12345 |
| Agent mode | ✅ | latency 0.08s |
| Project path | ✅ | /home/user/projects/my_project |
```

If any check fails, provide specific troubleshooting suggestions (e.g., "Is the SSH tunnel running?", "Is the storage path correct?").

## Architecture Principles

- **Edit code locally**: Claude Code native tools (~0.5ms) — remote MCP file operations are ~2000x slower
- **Run commands remotely**: Via `mcp__cluster__remote_bash(node="train")`
- **Single MCP manages all nodes**: `node` parameter routing (train/eval/...), scales to N nodes without context overhead
- **Agent mode first**: `agent.py` on shared storage communicates via persistent SSH, ~0.1s/command; auto-fallback to sentinel mode if unavailable
- **Sync code with Mutagen**: Real-time `one-way-replica` (save and it's there, zero manual steps); git push/pull only as fallback when Mutagen is unavailable
- **Read logs/results locally**: Mutagen auto-syncs outputs to local `outputs/` — use native Read tool (~20x faster than remote_bash cat)

## Core Operations

All paths below come from `~/.config/remote-cluster-agent/context.local.md` and the project-level config. Never hardcode.

### ⚠️ Reading Files vs Running Commands — Decide Before Acting

`remote_bash` is for **executing commands** (start training, kill processes, check process status, install packages), not reading file content.

If the project has Mutagen real-time sync configured, cluster output files automatically appear in local `outputs/`. When you need to check logs, eval results, or training curves, use the native Read tool on the local path — 20x faster and doesn't tie up the SSH connection.

**Decision rules**:
- Want to **read file content** (logs, JSON results, CSV, config files) → `Read("outputs/...")` locally
- Want to **run an operation** (ps, nvidia-smi, start/stop processes, pip install) → `remote_bash`
- Not sure if file is local → check with `ls outputs/` or `Glob("outputs/**/<pattern>")` first

Common mistake: Using `remote_bash(command="cat /path/to/log.txt")` or `remote_bash(command="tail -30 ...")` to read logs. These files are already synced locally — just Read them.

### Code Sync

**Mutagen Real-Time Sync** (strongly recommended)

All remote environments sync via Mutagen (`one-way-replica`) — save and it's there, zero manual steps. First-time setup auto-configures SSH config and Mutagen sessions. See `MUTAGEN.md` for details.

**Git Manual Sync** (fallback only, not recommended for daily use)

Requires commit + push + remote pull for every code change — slow iteration and easy to forget:

```bash
# Local
git add <files> && git commit -m "..." && git push

# Cluster (remote_bash)
cd <project_dir> && git pull
```

### GPU Occupancy Management (if configured)

```bash
# Release GPUs (before training)
bash <stop_gpu_script>

# Occupy GPUs (after training / idle time)
bash <start_gpu_script>
```

### Launch Training

```bash
# remote_bash: stop GPU occupancy (if configured), then start training
bash <stop_gpu_script> 2>/dev/null || true
cd <project_dir> && nohup <train_cmd> > <log_path> 2>&1 &
echo $!
```

### Check Training Status

Two steps: check process remotely, read logs locally.

```bash
# remote_bash: only check process status (don't read files)
ps -p <pid> -o pid,stat,etime --no-headers 2>/dev/null || echo "FINISHED"

# After training completes, restart GPU occupancy (if configured)
bash <start_gpu_script> 2>/dev/null || true
```

```python
# Local: read logs with Read tool (Mutagen has synced them)
Read("outputs/<experiment>/log.txt", offset=-30)  # last 30 lines
```

### Cluster Health Inspection

Scan all nodes in parallel for GPU/disk/tmux/load status, produce summary table, and recommend the most idle node.

Triggered when user says "cluster status", "which node is free", "cluster health", "GPU usage", etc. Can target specific nodes (e.g., `train,eval`) for partial scans. Supports `/loop 10m` for periodic monitoring.

Node list comes from the `context.local.md` node table. For probe commands, parse rules, report format, and recommendation algorithm, see `reference/cluster-health.md`.

### Sync Outputs to Local

Mutagen real-time sync handles configured projects — outputs appear locally automatically. Just use Read (see "Reading Files vs Running Commands" above).

**Manual download** (fallback, for projects without Mutagen output sync):

```bash
# Step 1: Cluster → local via scp or rsync
scp -r <ssh_host>:<output_path> ./outputs/

# Step 2: Read locally
Read("outputs/...")
```

Default: exclude checkpoint files (*.pt, *.bin, *.safetensors). Only add `--full` when user explicitly requests it.

## Safety Boundaries

- Read shared storage restrictions from `context.local.md` and follow strictly — files on shared paths belong to other teams, there's no recycle bin, accidental deletion can destroy days of their training work
- If the cluster has no public internet, use internal mirrors for `pip install` — don't attempt external URLs (GitHub, PyPI, etc.)
- Don't auto-push to master/main — avoid unreviewed code affecting the team
- **`pkill -f` must use bracket trick**: `pkill -f "[s]glang.launch_server"` not `pkill -f "sglang.launch_server"` — because the SSH process command line contains the kill pattern, `pkill -f` would kill SSH itself, causing the sentinel to hang. Same applies to `pgrep -f`, `grep` on process lists, etc.
- **Long-running processes must be backgrounded**: remote_bash detects completion via sentinel — if the process doesn't exit (e.g., inference server, training script), the sentinel never fires and the command hangs. Must use `nohup ... &` or `tmux new-session -d`, with `echo` placed after the background command using `;`:
  ```bash
  # Correct: nohup background + echo outside
  nohup python -m sglang.launch_server ... > /tmp/log 2>&1 & echo "PID=$!"
  # Correct: tmux detach + echo outside
  tmux new-session -d -s sglang "python -m sglang.launch_server ..."; echo "started"
  # Wrong: echo inside tmux's && chain, never executes
  tmux new-session -d -s sglang "python ... && echo started"
  ```
