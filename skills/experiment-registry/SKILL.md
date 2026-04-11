---
name: experiment-registry
description: "Manage ML experiment lifecycle with structured YAML registry. Register experiments, record benchmark results, compare across runs, track status. Use this skill whenever: user mentions experiments, benchmarks, or results tracking in ML context; asks 'which experiment performed best'; wants to record or compare results; says 'register experiment', 'new experiment', 'compare experiments', 'experiment results', 'exp list', 'exp init', '注册实验', '查实验', '对比实验', '实验结果', '实验状态', '哪个实验最好', '记录一下结果'. Also trigger when user discusses experiment management, tracking, or asks about experiment history in any ML project. NOT for: training monitoring, checkpoint management, launching training jobs, or experiment visualization."
---

# Experiment Registry

Structured YAML experiment registry for ML research. YAML was chosen over databases or JSON because experiment files should be human-readable, git-diffable, and hand-editable — researchers often need to inspect or tweak entries directly.

## Prerequisites

The `exp` CLI must be installed:

```bash
pip install exp-registry
```

If `exp` is not found, install it first. If the project has no `exp.config.yaml`, run `exp init` before any other command.

## How to Think About Experiment Registry

This tool manages the **metadata layer** of experiments — what was run, with what config, and what results came out. It does NOT manage training code, checkpoints, or logs.

The mental model: each experiment gets a YAML file that serves as its "identity card." Over time, benchmark results accumulate in that file as the experiment progresses through training steps. When it's time to report or decide next steps, you compare across experiments.

### Decision Flow

When the user mentions experiments, follow this flow:

1. **Check environment first.** Does `exp.config.yaml` exist? If not, ask if they want to initialize (`exp init`). Don't silently init — the user should confirm the project root.

2. **Understand intent.** Map the user's request to the right action:
   - "New experiment" / "register" → `exp register` (but first `exp list` to check for ID conflicts)
   - "What's running" / "experiment status" → `exp list` (suggest filters if there are many)
   - "Record results" / "add benchmark" → `exp add-benchmark` (ask for dataset and step if not provided)
   - "Compare" / "which is better" → `exp compare` (auto-discover shared datasets from `exp show`)
   - "What happened with exp07" → `exp show` first, then summarize findings

3. **Be proactive with context.** After any operation, offer useful next steps:
   - After registering → "Ready to add benchmarks when results come in"
   - After adding a benchmark → suggest comparing with related experiments if they exist
   - After comparing → highlight the best performer and surface any findings

### Smart Comparison

When the user asks "compare experiments" or "which is better," don't just dump the table. First run `exp show` on each experiment to discover which datasets and eval_modes they share, then run `exp compare` on those shared dimensions. If experiments have no common benchmarks, tell the user — don't produce an empty comparison silently.

### Series Grouping

Experiment IDs like `exp07a`, `exp07b`, `exp07c` automatically group into series `exp07`. This lets you filter by series to see all variants of one experimental idea. When a user discusses "the exp07 experiments," use `exp list --series exp07` to get the full picture.

## Command Reference

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

All list/show/compare commands support `--json` for machine-readable output.

## Typical Workflows

### Experiment Lifecycle

```
register → (train) → add-benchmark at step N → add-benchmark at step M → update status + finding
```

Example:
1. `exp register exp01 --type rl --model Qwen3-VL-8B --reward reward_tool_strict`
2. *(user trains the model)*
3. `exp add-benchmark exp01 --dataset zebra-cot --eval-mode agent --samples 50 --step 50 --extra text_only=0.42 with_tools=0.52`
4. `exp add-benchmark exp01 --dataset zebra-cot --eval-mode agent --samples 50 --step 90 --extra text_only=0.44 with_tools=0.55`
5. `exp update exp01 --status completed --finding "tool use improves reasoning"`

Benchmarks are organized by step number within each dataset — this tracks how performance evolves during training, which is critical for deciding when to stop or which checkpoint to use.

### Compare for Meeting/Report

```bash
exp compare exp07a exp07b exp07c --dataset zebra-cot
```

Outputs a Markdown table — paste directly into docs or slides.

## Project Configuration

`exp.config.yaml` at project root:

```yaml
registry_dir: experiments/           # where YAML files live
paths_template:
  local: outputs/{id}/               # {id} is replaced with experiment ID
defaults:
  type: rl                           # default for `exp register`
types:
  rl:
    fields: [model, config, script, reward]
  sft:
    fields: [model, config, script, base_model]
```

Config is discovered by walking up from CWD. No config = sensible defaults (`registry_dir: experiments/`).

## YAML Schema

Each experiment is one file in `<registry_dir>/<exp_id>.yaml`:

**Required fields:** `id`, `name`, `type`, `series`, `date`, `status`

**Auto-generated:** `series` (inferred from ID prefix), `paths` (from template), `date` (today)

**Structured benchmarks:**
```yaml
benchmarks:
  - dataset: string
    eval_mode: string
    samples: int
    steps:
      <step_number>: { <metric>: <value>, ... }
```

## Error Recovery

| Error | Cause | What to Do |
|-------|-------|------------|
| "experiment already exists" | Duplicate ID | `exp show <id>` to check, use a different ID |
| "experiment not found" | Wrong ID | `exp list` to see available IDs |
| "No benchmark data found" | Wrong dataset in compare | `exp show <id>` to check available datasets |
| "Missing required fields" | Corrupted YAML | Inspect and fix the YAML file directly — it's designed to be human-editable |
