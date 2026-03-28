# Cluster Infrastructure Context

Cross-project infrastructure info maintained here. Project-specific config lives in `<project>.md` files in the same directory.

## Project Index

| Project | Config File |
|---------|-------------|
| `my_project` | `my_project.md` |

## Cluster Nodes

Use `mcp__cluster__remote_bash(node="<name>", command="...")` for all remote commands.

| Name | SSH Command | Purpose |
|------|------------|---------|
| train | `ssh -p 2222 gpu-node` | Training |
| eval | `ssh gpu-eval` | Evaluation |

- Default node: `train`

## Storage

| Storage | Path | Description |
|---------|------|-------------|
| Project storage | `/home/user/` | Personal workspace, code and outputs |
| Shared storage | `/shared/data/` | Team shared data — **never delete or modify others' files** |

### Common Directories

| Path | Purpose |
|------|---------|
| `/home/user/projects/` | Project code |
| `/home/user/data/` | Datasets |
| `/home/user/outputs/` | Training/eval outputs |
| `~/.mcp-agent/agent.py` | Cluster-side Agent (shared across nodes) |

## GPU Occupancy Management

If your cluster reclaims idle GPUs, configure anti-reclaim scripts here.

| Script | Purpose | When to Call |
|--------|---------|-------------|
| `scripts/start_gpu.sh` | Start GPU occupancy | After training ends / idle time |
| `scripts/stop_gpu.sh` | Stop GPU occupancy | Before training starts, free VRAM |

## Safety Boundaries

- Shared storage paths are read-only for non-owned files — accidental deletion cannot be recovered
- If cluster has no public internet, use internal package mirrors — don't attempt external URLs
- Long-running processes must be backgrounded: `nohup ... &` or `tmux new-session -d`
- `pkill -f` must use bracket trick to avoid killing SSH: `pkill -f "[p]attern"` not `pkill -f "pattern"`

## Code Sync

- **Recommended**: Mutagen real-time sync (`one-way-replica`, local → cluster, save and it's there)
- **Fallback**: `git push` locally → `git pull` on cluster (slower iteration, not recommended for daily use)

## Mutagen Rules

- All sessions use `one-way-replica` mode — Alpha is sole source of truth, never conflicts
- Do not manually run `mutagen sync` — rely on background session auto-sync
- Do not create multiple sessions targeting the same remote path — they will conflict

## Notes

(Free-form: hardware specs, OSS configuration, special restrictions, etc.)
