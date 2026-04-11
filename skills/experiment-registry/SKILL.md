---
name: experiment-registry
description: "Manage ML experiment lifecycle with structured YAML registry. Register experiments, record benchmark results, compare across runs, track status. Use when: 'register experiment', 'new experiment', 'compare experiments', 'experiment results', 'exp list', 'exp init', '注册实验', '查实验', '对比实验', '实验结果', '实验状态'. NOT for: training monitoring (use monitor-training), checkpoint management, or launching training jobs."
---

# Experiment Registry

Structured YAML experiment registry for ML research. Track experiments, record benchmarks, compare results.

## Installation

```bash
pip install exp-registry
```

After installation, initialize in your project:
```bash
cd your-ml-project
exp init
```

## Quick Setup

`exp init` creates:
- `exp.config.yaml` — project configuration (path templates, defaults)
- `experiments/` — directory for experiment YAML files

Edit `exp.config.yaml` to customize for your project (see Project Configuration below).

## When This Skill Activates

**Explicit:** `/experiment-registry`, `exp list`, `exp register`, `exp compare`

**Intent detection:**
- "注册实验" / "register experiment" / "new experiment"
- "查实验" / "实验状态" / "what experiments are running"
- "对比实验" / "compare experiments"
- "记录结果" / "add benchmark results"
- "实验结果" / "experiment results"

**NOT for:** training monitoring, checkpoint management, launching training, experiment visualization

## Quick Reference

| Task | Command |
|------|---------|
| Initialize | `exp init` |
| List all | `exp list` |
| Filter by status | `exp list --status completed` |
| Filter by type | `exp list --type rl` |
| Filter by series | `exp list --series exp07` |
| Show details | `exp show <id>` |
| JSON output | `exp show <id> --json` |
| Register new | `exp register <id> --type rl --model Qwen3-VL-8B` |
| Add benchmark | `exp add-benchmark <id> --dataset mmlu --eval-mode cot --samples 100 --step 50 --extra acc=0.72` |
| Compare | `exp compare <id1> <id2> --dataset mmlu` |
| Update status | `exp update <id> --status completed` |
| Add finding | `exp update <id> --finding "key insight"` |

## Common Workflows

### New Project Setup

1. `exp init` — creates config + registry directory
2. Edit `exp.config.yaml` to set path templates and defaults
3. Start registering experiments

### Experiment Lifecycle

1. `exp register exp01 --type rl --model Qwen3-VL-8B --reward reward_tool_strict`
2. *(train the model)*
3. `exp add-benchmark exp01 --dataset zebra-cot --eval-mode agent --samples 50 --step 50 --extra text_only=0.42 with_tools=0.52`
4. `exp add-benchmark exp01 --dataset zebra-cot --eval-mode agent --samples 50 --step 90 --extra text_only=0.44 with_tools=0.55`
5. `exp update exp01 --status completed --finding "tool use improves reasoning"`

### Compare for Meeting/Report

```bash
exp compare exp07a exp07b exp07c --dataset zebra-cot
```

Outputs Markdown table — paste directly into docs or slides.

## Project Configuration

`exp.config.yaml` at project root:

```yaml
# Where experiment YAML files are stored (relative to project root)
registry_dir: experiments/

# Path templates — {id} is replaced with experiment ID
paths_template:
  local: outputs/{id}/
  # Add project-specific paths:
  # cluster: /data/outputs/{id}/
  # oss: oss://bucket/outputs/{id}/

# Defaults for `exp register`
defaults:
  type: rl
  # model: Qwen3-VL-8B

# Per-type recommended fields (shown as hints during register)
types:
  rl:
    fields: [model, config, script, reward]
  sft:
    fields: [model, config, script, base_model]
  benchmark:
    fields: [model, dataset, eval_mode]
```

Config is discovered by walking up from CWD. No config = sensible defaults (`registry_dir: experiments/`).

## YAML Schema

Each experiment is one file in `<registry_dir>/<exp_id>.yaml`:

**Required fields:** `id`, `name`, `type`, `series`, `date`, `status`

**Auto-generated:** `series` (inferred from ID), `paths` (from template), `date` (today)

**Free-form:** `stages`, `findings`, and any custom fields your project needs

**Structured:** `benchmarks` list:
```yaml
benchmarks:
  - dataset: string
    eval_mode: string
    samples: int
    steps:
      <step_number>: { <metric>: <value>, ... }
```

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| "experiment already exists" | Duplicate ID | Use a different ID or `exp show` to check |
| "experiment not found" | Wrong ID | Run `exp list` to see available IDs |
| "No benchmark data found" | Wrong dataset in compare | Check `exp show <id>` for available datasets |
| "Missing required fields" | Corrupted YAML | Fix the YAML file manually |

## Output Formats

All list/show/compare commands support `--json` for machine-readable output:

```bash
exp list --json              # Array of experiment objects
exp show exp01 --json        # Single experiment object
exp compare a b --dataset x --json  # {exp_ids, metrics, steps}
```
