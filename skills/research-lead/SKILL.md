---
name: research-lead
description: Lead a research question from context and hypothesis through delegated experiments to an evidence-based decision. Use when the user asks to lead research, organize experiments, or coordinate an Opus leader with Codex execution; triggers include 'research lead', '带着推进这个研究', '你当研究 leader', and '组织实验验证这个假设'. Not for a one-off code fix, log lookup, paper review, project status review, or session management alone.
---

# Research Lead

Turn a research question into evidence that changes a decision. The default team is an **Opus 5.5 leader** and one **Codex executor**, with the executor in a persistent remote conversation the user can open and continue in their Codex app. Add executors only for work that benefits from independent ownership.

This is a role arrangement, not a model-switch command. Respect the user's chosen models and existing client settings; do not claim this session runs Opus if it does not. If invoked from another runtime, prepare the handoff or use the role the user explicitly assigns. Do not silently change shared settings.

## Division of responsibility

- **User:** research value, material changes of direction, and resource commitments outside existing authorization.
- **Leader:** understand the question and relevant history, identify competing explanations, design the smallest useful test, review evidence, and recommend the next decision.
- **Executor:** inspect the actual code and environment, choose implementation details, implement, test, run authorized experiments, and report evidence and discrepancies. It must challenge a plan contradicted by the implementation or data.

The leader reads source material and decisive evidence when needed. Delegate lengthy implementation and debugging; keep raw logs in executor artifacts instead of filling the leader conversation with them.

## Reuse session-team

Use the installed **session-team** skill for session creation, discovery, message delivery, worktree/resource ownership, and check-ins. Read its `references/codex.md` for Codex execution and `references/claude-peer.md` for replies to a Claude leader. Do not recreate its transport scripts here.

Resolve session-team from the available skills catalog; in the source repository it is a sibling skill. If it is unavailable, continue planning and provide a self-contained kickoff, but report automatic coordination as unavailable. Never represent a draft kickoff as a running executor.

Before dispatch, confirm existing user authorization covers creating independent chats and sending messages in both directions. A request to design or review a plan alone does not authorize dispatch. Do not ask again when authorization is already clear.

The executor must use the remote host and existing Codex service connected to the user's app. Record its host, stable thread ID, working directory, and actual model. Verify client visibility and direct continuation separately from server-side creation; an ephemeral command or subagent is not a substitute for this workflow. Reuse a suitable existing executor when possible.

Use session-team's actual wake-up mechanism if unattended coordination is requested. Otherwise resume coordination on the next leader invocation. A temporary reply socket expiring does not invalidate the persistent Codex thread: use the recorded Codex message route for subsequent tasks.

## Research loop

### 1. Establish the question and evidence

Start with the project's own entrypoint, instructions, task source, and relevant experiment records. Follow the references needed for this question; do not load every historical report or reactivate dormant projects.

Separate verified facts, interpretations, hypotheses, and unknowns. Preserve the sources and dates of important claims. Inspect failed attempts and relevant baselines before proposing work. Ask only for missing information that cannot be recovered from the available sources.

State what decision the result would change. If neither outcome would change the next step, reconsider the experiment's value before spending resources.

### 2. Specify the smallest discriminating test

Describe the hypothesis, plausible alternatives, intervention and control, data split, metrics, acceptance criteria, and stopping conditions appropriate to the question. For scientific results, choose these before inspecting the new outcomes; a changed criterion becomes a dated amendment, not a rewrite of the original.

Use the [handoff template](references/handoff-template.md) to add the necessary fields to the existing task document. Carry the reasoning behind the plan as well as the steps. Link required context with a sentence explaining its relevance. Distinguish fixed scientific choices from implementation details the executor owns.

Respect existing approved scope and budgets. Escalate a material direction change or additional resource commitment to the user with the evidence and tradeoff; routine implementation choices do not require another approval.

### 3. Check readiness, then execute

The executor first reads the specified sources and checks the actual repo/commit, working tree, code path, environment, existing jobs/artifacts, and validation entrypoints relevant to its task. It briefly reports its understanding and any gaps with evidence.

This readiness report is not an automatic waiting gate: proceed within the agreed scope when the facts match. If a missing dependency or contradiction invalidates the plan, report it before the affected work; continue independent authorized work where useful. Never invent missing context or silently substitute a different dataset, model, baseline, metric, or target behavior.

Test the behavior the user will actually use, including the relevant launcher or integration boundary. Component tests alone do not establish end-to-end success. Mark mocked, local, small-scale, and full validation separately; skipped checks are not passes.

### 4. Review evidence before closing

The executor delivers the changes, actual commands/configuration, repo/commit and environment, data/protocol identity, results, failures, deviations, and remaining uncertainty. Link bulky artifacts; summarize only what affects the decision. Mark the task **ready for review**, not accepted.

The leader checks the evidence against the original question and criteria, inspects decisive raw artifacts and the actual diff where relevant, and tests alternative explanations such as changed evaluation conditions or leakage. Request a targeted correction if a gap could change the conclusion; do not repeat checks without a reason.

Report whether the evidence supports the hypothesis, does not support it, or remains inconclusive. Distinguish implementation completion from scientific success. Recommend accepting, revising, stopping, or the next discriminating test, with its expected value. A negative result or a justified stop can complete the research task.

## Durable state and interruptions

Keep the plan, evidence links, current status, and next decision in the project's existing task and experiment records. Stable lessons go to its established knowledge location. Link the coordination document instead of creating competing copies of the task state.

If the user directly changes the executor's assignment, the executor records the change and informs the leader through the authorized route. Preserve direct user instructions over stale plans. After a restart or compaction, recover from these records and check live state before dispatching again.

If the leader is unavailable, the executor may finish only already-authorized work and record its result; it must not invent a new research direction or expand resources. If a provider refuses a request, record the affected action and stop it. This workflow does not automatically reword or transfer a refused task to bypass safeguards, and it does not promise freedom from refusals.

## Evaluate the workflow

Start with one real, bounded research task. Check whether context omissions, avoidable rework, and user coordination interventions decrease, and whether the final decision has adequate evidence. Successful session communication alone is not evidence of research quality.
