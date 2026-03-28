# <project> Project Context

This file is the source of truth for `<project>`. Cross-project infrastructure info lives in `context.local.md` in the same directory.

## Code Paths

| Environment | Path |
|-------------|------|
| Local Mac | `~/workspace/<project>` |
| Cluster | `/home/user/projects/<project>` |

## Python Environment

| Environment | Setup |
|-------------|-------|
| Cluster | Use system/container Python; run project-specific editable install on first use |

## Experiment Output Paths

| Environment | Root Path | Description |
|-------------|-----------|-------------|
| Cluster | `/home/user/outputs/` | Raw training/eval outputs |
| Local Mac | `outputs/` (project root) | Local mirror (Mutagen sync) |

## Mutagen Sessions

| Session | Mode | Source → Target |
|---------|------|----------------|
| `<project>-code` | `one-way-replica` | Mac → Cluster `/home/user/projects/<project>` |
| `<project>-outputs` | `one-way-replica` | Cluster `/home/user/outputs` → Mac `outputs/` |

**Convention**: Code is only edited on Mac; outputs are only written on cluster. Local `outputs/` is a read-only mirror.

## Project-Specific Init

Commands to run on a new node/container before first use:

```bash
# Fill in as needed: editable install, env vars, etc.
pip install --no-deps -e .
```

## Git Remote

- origin: `git@github.com:<user>/<project>.git`
