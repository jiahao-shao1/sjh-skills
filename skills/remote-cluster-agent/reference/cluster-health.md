# Cluster Health Check — Detailed Procedure

## Probe Commands

Issue **1** `remote_bash` call per node, concatenating all probes with separator markers. Call all nodes in parallel within a single message to maximize throughput.

```bash
echo '===GPU==='; nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 'NVIDIA_ERROR'; echo '===DISK==='; df -h / /home 2>/dev/null | grep -vE 'tmpfs|Filesystem' ; echo '===TMUX==='; tmux list-sessions 2>/dev/null || echo 'NO_SESSIONS'; echo '===PROCS==='; nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader,nounits 2>/dev/null || echo 'NO_PROCESSES'; echo '===LOAD==='; uptime
```

## Parse Rules

Split each node's output by `===SECTION===` markers:

### GPU
- Parse CSV: `index, name, memory.used, memory.total, utilization.gpu, temperature.gpu`
- Idle check: `memory.used < 100` MiB **and** `utilization.gpu == 0`
- Compute: total GPUs, idle GPUs, total used VRAM, total VRAM, avg utilization, max temperature

### Disk
- Parse `df -h` output, extract Used/Avail/Use% for `/`, `/home` (or whatever mounts exist)
- Flag Use% > 90% as WARNING

### tmux
- Parse session names and window counts
- `NO_SESSIONS` means no active sessions

### GPU Processes
- Parse CSV: `pid, used_memory, name`
- Sort by memory descending

### Load
- Extract load average (1min, 5min, 15min) from `uptime`

## Report Format

```markdown
## Cluster Health Report (YYYY-MM-DD HH:MM)

### GPU Overview

| Node | Total | Idle | Used VRAM | Total VRAM | Util% | Temp | Load |
|------|-------|------|-----------|------------|-------|------|------|
| train | 8 | 3 | 120G | 640G | 45% | 72°C | 2.1 |
| eval | 8 | 8 | 0G | 640G | 0% | 35°C | 0.0 |

### Disk

| Node | / | /home |
|------|---|-------|
| train | 20G/50G (40%) | 1.2T/2T (60%) |

### tmux Sessions

| Node | Count | Details |
|------|-------|---------|
| train | 2 | train_exp05 (3w), monitor (1w) |

### GPU Processes (VRAM > 1G)

| Node | PID | VRAM | Process |
|------|-----|------|---------|
| train | 12345 | 70G | python train.py |

### Recommendation

> **Most idle node: eval** — 8 GPUs all idle, /home 60% free, no tmux sessions, load 0.0
```

## Recommendation Algorithm

```
score = idle_gpus × 100
      + disk_free_pct × 1
      - active_tmux_sessions × 10
      - load_1min × 5
```

Highest score wins. On tie, prefer the node with more free disk. If all nodes are fully loaded (idle GPUs = 0), report "No idle nodes — consider waiting or freeing resources."

## Error Handling

| Situation | Action |
|-----------|--------|
| `remote_bash` timeout | Mark node as `UNREACHABLE`, continue scanning others |
| `NVIDIA_ERROR` | GPU info marked `N/A`, exclude from recommendation |
| Disk > 90% | Add warning marker to disk column |
| All nodes full | Recommendation says "No idle nodes, suggest waiting or freeing resources" |
