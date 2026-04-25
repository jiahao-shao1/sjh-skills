---
name: project-review
description: "Strategic project review — auto-discovers strategy docs (vision, roadmap, decisions, notes), produces five-dimension snapshot. Use for direction review, alignment check, milestone status, pre-meeting overview. Triggers: 'project review', 'strategic review', 'where is the project at', '项目全景', '审视战略', '项目现在什么状态'. Not for code/PR review."
---

# Project Review

Reads the project's strategy document ecosystem and generates a panoramic snapshot. Useful before team meetings, when feeling lost about direction, or for periodic retrospectives — helps you quickly understand where the project is and where it should go.

## Execution Skeleton

### Phase 1: Load Document Manifest

First check if the project has an explicit configuration: read `docs/strategy/.review-sources.md`.

If it exists, read each path listed — the project maintainer has already specified which documents constitute the "strategic picture", no guessing needed.

If it doesn't exist, fall through to Phase 1b (auto-discovery).

#### Configuration Format (`docs/strategy/.review-sources.md`)

```markdown
# Project Review Sources

## Core
- docs/strategy/vision.md
- docs/strategy/roadmap.md
- docs/strategy/paper-outline.md

## Decisions
- docs/strategy/decisions/log.md

## Related Work
- docs/strategy/related-work/_index.md

## Meetings (latest 2)
- docs/strategy/meetings/

## Experiments
- .claude/knowledge/experiments.md

## Progress
- HANDOFF.md
```

Each entry is a path relative to project root. Directory paths (ending with `/`) mean "read the 2 most recently modified files in that directory". Lines starting with `#` are section headers for grouping.

### Phase 1b: Auto-Discovery (fallback when no config exists)

Search the following paths, excluding `third_party/`, `node_modules/`, `.venv/`, `vendor/`:

| Document Type | Search Paths (by priority) | Purpose |
|---------------|---------------------------|---------|
| Vision | `docs/strategy/vision.md` → `docs/vision.md` → `VISION.md` | Core positioning and assumptions |
| Roadmap | `docs/strategy/roadmap.md` → `docs/roadmap.md` → `ROADMAP.md` | Milestones and timeline |
| Paper Outline | `docs/strategy/paper-outline.md` | Paper outline (research projects) |
| Related Work | `_index.md` or all `.md` under `docs/strategy/related-work/` | Related work coverage |
| Decisions | `docs/strategy/decisions/log.md` → `docs/strategy/decisions/` → `docs/adr/` | Decision records |
| Meetings | 2 most recent `.md` under `docs/strategy/meetings/` (exclude `_template.md`) | Meeting notes |
| Experiments | `.claude/knowledge/experiments.md` | Experiment log |
| Progress | `HANDOFF.md` (project root) | Current progress |

Use exact paths with sequential fallback — avoid `**/` recursive globs, which tend to match files under `third_party/` and produce noise.

If none of the above paths exist, prompt the user:
> "No strategy documents found. Consider creating `docs/strategy/.review-sources.md` to specify document locations, or create `vision.md` and `roadmap.md` under `docs/strategy/`."

### Phase 2: Five-Dimension Analysis

Generate analysis based on the discovered documents. Only produce a dimension when supporting documents exist — skip dimensions without data, because speculation is more dangerous than silence.

**1. Vision Check**
- Is current work aligned with core objectives / assumptions?
- Which assumptions are validated, challenged, or untested?
- If no vision document exists, infer project goals from README (mark as inferred)

**2. Roadmap Status**
- Progress overview (done / in-progress / planned)
- Current phase's position in the overall roadmap
- Any work that deviates from the plan

**3. Bottleneck Identification**
- Extract current blockers from experiment results and decision records
- Distinguish technical bottlenecks (e.g., unstable API) from research/business bottlenecks (e.g., invalidated assumptions)

**4. Related Work Gap** (research projects)
- Which topics lack related work coverage?
- Are there newly published works that need attention?

**5. Next Steps**
- Recommendations based on the above analysis
- Priority ordering: urgent vs. important

### Phase 3: Output

```
========================================
        PROJECT REVIEW SNAPSHOT
        <project-name> | YYYY-MM-DD
========================================

## 1. Vision Check
...

## 2. Roadmap Status
| ID | Milestone | Status | Notes |
...

## 3. Bottleneck Identification
...

## 4. Related Work Gap
...

## 5. Next Steps
1. ...
2. ...
3. ...

========================================
```

### First-Use Onboarding

If documents were found via Phase 1b auto-discovery (rather than the config file), append a recommended configuration at the end of the output so the user can quickly create `.review-sources.md`:

```
Tip: Create docs/strategy/.review-sources.md to precisely specify document
locations and avoid false matches. Recommended config:

<generate config content based on actually discovered files>
```

## Constraints

- **Read-only** — do not modify any documents. This skill's value is providing perspective, not making decisions for the user.
- **Output to terminal** — do not create files unless the user explicitly asks to save. Avoid "documents writing documents" noise.
- **Follow the user's language** — respond in whichever language the user uses.
- Skip dimensions that lack supporting documents — silence is more valuable than false confidence.
- This skill does not replace weekly-report (for reporting) or meeting-slides (for presentations) — it's for personal/team strategic reflection.
