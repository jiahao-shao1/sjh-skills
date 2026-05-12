# Research Profile Documentation

The research profile adds research-project-specific structure on top of the base skeleton.

## Additional Generated Content

### Directories

| Path | Purpose |
|------|---------|
| `docs/reports/weekly/` | Weekly report output |
| `docs/reports/worktree/` | Worktree work reports |
| `docs/plans/` | Design docs and implementation plans |
| `docs/strategy/` | Project vision, roadmap, and strategic documents |
| `docs/strategy/decisions/` | Architectural and strategic decision records |
| `docs/strategy/meetings/` | Meeting notes |
| `docs/strategy/related-work/` | Related work analysis |
| `scripts/training/` | Training scripts |
| `scripts/benchmark/` | Evaluation and benchmark scripts |
| `scripts/data/` | Data processing scripts |
| `scripts/model/` | Model management scripts (merge, convert, etc.) |
| `scripts/infra/` | Infrastructure and DevOps scripts |
| `scripts/analysis/` | Result analysis scripts (figure prep, statistics, ablation studies) |
| `scripts/monitoring/` | Training / job monitoring scripts (watchers, health checks) |
| `docs/paper-results/` | Paper results manifest — single source of truth for benchmark numbers entering the paper |

### Files

| Path | Content |
|------|---------|
| `docs/experiment-registry/README.md` | Experiment registry guide (YAML-based, managed by `exp-registry` CLI) |
| `docs/experiment-registry/registry/` | Directory for per-experiment YAML files |
| `.claude/agents/domain-expert.md` | Domain expert agent scaffold (`memory: project`, `permissionMode: plan`) |
| `docs/strategy/vision.md` | Project vision template |
| `docs/strategy/roadmap.md` | Milestones and phases template |
| `docs/strategy/decisions/log.md` | Decision log format and template |
| `docs/paper-results/README.md` | Paper manifest workflow + entry schema (three-tier sources of truth: raw outputs → registry → manifest) |
| `docs/paper-results/results.yaml` | Empty manifest with commented-out entry template |
| `scripts/benchmark/validate_paper_results.py` | Stub validator: required-field check, paper_key uniqueness, source path existence |
| `scripts/benchmark/generate_paper_results.py` | Stub generator: emit `paper/generated/results_macros.tex` with `\providecommand{\Result<Key>}{value}` macros |

### AGENTS.md Appended Content

Appends two sections (marker `<!-- research-profile -->`, idempotent) to the end of **AGENTS.md** — not CLAUDE.md, so that CLAUDE.md stays as a thin `@AGENTS.md` stub and AGENTS.md remains the single source of truth for both CC and Codex / external runtimes:

- **Experiment Registry** — pointer to `exp-registry` CLI + per-experiment YAML under `docs/experiment-registry/registry/`, and the relationship to the paper manifest
- **Project Strategy** — table of `docs/strategy/*` documents (vision / roadmap / decisions / meetings / related-work) with when-to-read guidance

The Agents listing (planner / code-verifier / domain-expert) is **not** appended — each agent's frontmatter `description` already drives CC's auto-discovery, so a duplicate table would just be a stale human-facing index.

## Experiment Registry

Experiments are managed via the `exp-registry` CLI tool (`pip install exp-registry`), not manual markdown.

```bash
# Register a new experiment
exp register --name exp01a --hypothesis "..." --config "..."

# List all experiments
exp list

# Update status
exp update exp01a --status completed --results "metric=value"
```

YAML files are stored in `docs/experiment-registry/registry/`, one per experiment.

## Paper Results Manifest

Paper-bound benchmark numbers go through a three-tier sources-of-truth structure to prevent paper-time mistakes (copying numbers from screenshots, stale strategy docs, or outdated tables):

1. **Raw outputs** (`outputs/`) — evidence only, never cited directly in paper
2. **Experiment registry** (`docs/experiment-registry/registry/*.yaml`) — full history, may keep multiple stale / legacy / diagnostic / canonical entries per experiment
3. **Paper manifest** (`docs/paper-results/results.yaml`) — only canonical numbers allowed into paper tables and prose; one canonical number per `paper_key`

The profile generates two stub scripts that wire manifest → paper:

```bash
# Schema + path validation, run before commit
python3 scripts/benchmark/validate_paper_results.py

# Regenerate paper/generated/results_macros.tex from manifest
python3 scripts/benchmark/generate_paper_results.py
```

Paper tables and prose should reference the generated macros (e.g. `\ResultMainMethodABenchX`) rather than hand-written numbers — keeping manifest and `.tex` in sync per commit.

Both stubs are minimal: they handle the schema-validation and macro-emission contract but leave project-specific aggregation (cross-bench means, paired statistics, ablation table grouping) for the user to extend.

## Domain Expert Agent

`domain-expert.md` is a scaffold that users fill in per project:

- `description`: Domain expertise description
- `memory: project`: Retains cross-session diagnostic context
- `permissionMode: plan`: Read-only research, no code modifications
- When to use: Trigger scenarios
- Focus directories: Code locations to research
- Domain knowledge: Key constraints, interface contracts, historical lessons
- Chain hints: If output feeds another agent, note the downstream agent

Typically a research project has 1–3 domain expert agents (e.g., rl-training-expert, data-pipeline-expert).

## Future Extensible Profiles

| Profile | Purpose | Status |
|---------|---------|--------|
| research | Research projects (experiments, reports, domain experts) | Implemented |
| web-app | Web applications (component structure, CI/CD) | Planned |
| data-pipeline | Data pipelines (ETL, monitoring) | Planned |

New profiles are added via `scripts/init-<profile>-profile.sh` + `details/<profile>-profile.md`.
