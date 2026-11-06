# research-lead

English | [中文](README.zh-CN.md)

Lead a research question from context and hypothesis to an evidence-based decision. The default arrangement is an **Opus 5.5 leader** with a **Codex executor** in a persistent remote chat the user can open and continue. Model choices remain configurable; the skill does not switch the current session's model.

The leader explains why an experiment matters, prepares a handoff with sources and acceptance criteria, and reviews decisive evidence. The executor verifies the actual code and environment, implements and tests, runs authorized experiments, and flags contradictions rather than blindly following a plan.

## Install and use

```bash
npx skills add jiahao-shao1/sjh-skills --skill research-lead
npx skills add jiahao-shao1/sjh-skills --skill session-team
```

In your Opus 5.5 conversation, ask:

> Use research-lead to investigate whether our data change improves recovery on the held-out tasks. Read the project context and existing evidence first. Coordinate a Codex executor in a remote chat I can open in my app, and allow it to report back to this conversation. Propose the smallest useful experiment within the existing budget.

For planning only, say so; a plan request does not create a team. A one-off code fix, status lookup, or paper review does not need this workflow.

## Boundaries

- **research-lead:** research context, hypotheses, experimental design, evidence review, and the next decision.
- **session-team:** session creation, communication, client visibility, worktree/resource ownership, and check-ins. Install it for automatic coordination; without it, the leader can still prepare a kickoff for manual use.
- **Project records:** the authoritative plan, experiment state, and evidence. The [handoff template](references/handoff-template.md) extends these records rather than creating another registry.

The executor reports **ready for review**; the leader distinguishes implementation completion from scientific success. Direct user changes are recorded and relayed. Neither provider refusals nor unavailable leaders authorize scope expansion or automatic rerouting of blocked work.

## Validation status

This is a workflow definition, not a claim of improved research performance or immunity to model refusals. Validate it on one bounded research task and compare context omissions, avoidable rework, user coordination effort, and the evidence behind the final decision. Verify remote chat visibility and direct user continuation on the target installation through session-team.
