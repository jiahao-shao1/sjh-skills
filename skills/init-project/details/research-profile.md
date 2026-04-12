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
| `docs/knowledge/experiments.md` | Experiment registry template (date, config, three-tier paths, results) |
| `.claude/agents/domain-expert.md` | Domain expert agent scaffold (user fills in expertise) |
| `docs/strategy/vision.md` | Project vision template |
| `docs/strategy/roadmap.md` | Milestones and phases template |
| `docs/strategy/decisions/log.md` | Decision log format and template |

### CLAUDE.md Appended Content

Appends an "Extended Configuration" section to the end of CLAUDE.md:
- Agent listing table
- Knowledge file listing table
- Project Strategy document listing with `docs/strategy/` pointers

## Experiment Registry Format

Append an entry to `docs/knowledge/experiments.md` for each new experiment:

```markdown
## Experiment Name

- **Date**: YYYY-MM-DD ~ YYYY-MM-DD
- **Config**: Brief config summary
- **Paths**:
  - Cluster: /path/on/cluster
  - OSS: oss://bucket/path
  - Local: outputs/path
- **Key Results**:
  - Metric 1: value
  - Metric 2: value
- **Conclusion**: One-line summary
```

The three-tier paths (cluster/OSS/local) track data location for easy sync and lookup.

## Domain Expert Agent

`domain-expert.md` is a scaffold that users fill in per project:

- `description`: Domain expertise description
- When to use: Trigger scenarios
- Focus directories: Code locations to research
- Domain knowledge: Key constraints, interface contracts, historical lessons

Typically a research project has 1–3 domain expert agents (e.g., rl-training-expert, data-pipeline-expert).

## Future Extensible Profiles

| Profile | Purpose | Status |
|---------|---------|--------|
| research | Research projects (experiments, reports, domain experts) | Implemented |
| web-app | Web applications (component structure, CI/CD) | Planned |
| data-pipeline | Data pipelines (ETL, monitoring) | Planned |

New profiles are added via `scripts/init-<profile>-profile.sh` + `details/<profile>-profile.md`.
