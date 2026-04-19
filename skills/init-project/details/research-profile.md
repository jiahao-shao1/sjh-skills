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

### Files

| Path | Content |
|------|---------|
| `docs/experiment-registry/README.md` | Experiment registry guide (YAML-based, managed by `exp-registry` CLI) |
| `docs/experiment-registry/registry/` | Directory for per-experiment YAML files |
| `.claude/agents/domain-expert.md` | Domain expert agent scaffold (`memory: project`, `permissionMode: plan`) |
| `docs/strategy/vision.md` | Project vision template |
| `docs/strategy/roadmap.md` | Milestones and phases template |
| `docs/strategy/decisions/log.md` | Decision log format and template |

### CLAUDE.md Appended Content

Appends an "Extended Configuration" section to the end of CLAUDE.md:
- Agent listing table (with permissionMode column)
- Experiment registry pointer (YAML-based, `exp-registry` CLI)
- Project Strategy document listing with `docs/strategy/` pointers

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
