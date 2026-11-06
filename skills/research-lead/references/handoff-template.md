# Research task handoff

Use this as sections in the project's existing task document, not as a second registry. Write in the user's working language and omit inapplicable fields. The leader fills the research plan; the executor adds readiness and results; the leader records the review. Use session-team for the session addresses and communication instructions included in the kickoff.

```markdown
# <Research question>

## Decision and hypothesis — leader
- What result would change our next decision, and why it matters:
- Hypothesis and plausible alternative explanations:
- Current authorization: scope, budget, and decisions reserved for the user:

## Context — leader
- Required sources: <path/section or URL, relevance, commit/date where needed>
- Established facts and their evidence:
- Prior attempts, failures, and limitations:
- Unverified assumptions and remaining questions:

## Plan and acceptance criteria — leader, <date>
- Intervention and control/baseline:
- Data, split, model and evaluation protocol:
- Metrics, comparison and uncertainty treatment:
- Criteria for support, lack of support, or an inconclusive result:
- Stop conditions and resource limit:
- Fixed scientific choices:
- Implementation choices owned by the executor:
- Actual user-facing behavior or integration boundary to validate:

## Execution scope — leader
- Executor host, persistent thread ID, worktree and actual model:
- Coordination document and authorized message routes in both directions:
- Editable files/components and ownership boundaries:
- Required deliverables and evidence locations:
- Conditions requiring a decision before the affected work continues:

## Readiness — executor
- Understanding of the task and acceptance criteria:
- Sources read and actual repo/commit, environment and validation entrypoints:
- Existing jobs/artifacts checked to avoid duplicate work:
- Gaps or contradictions, with evidence; proposed correction if needed:
- Ready to proceed within scope / affected work waiting for a decision:

## Results — executor, ready for review
- Actual repo/commit, working-tree changes, configuration and commands:
- Data/protocol/environment identity and artifact links:
- Results and uncertainty:
- Tests and validation level; failures and skipped checks:
- Deviations from plan and outstanding limitations:
- Remaining jobs/resources and their owner:

## Review and next decision — leader
- Evidence inspected and criteria applied:
- Hypothesis supported / not supported / inconclusive, with scope:
- Implementation accepted / targeted correction needed:
- Next step and why it is worth doing, or reason to stop:
- User decision needed, if any:

## Amendments
- <date, source of the change, rationale, affected work and new criteria>
```
