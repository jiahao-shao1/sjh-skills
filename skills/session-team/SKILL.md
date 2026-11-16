---
name: session-team
description: Run a team in T3 Code - a sync thread the user talks to, an ops leader thread that dispatches and checks in, and workers the leader runs as delegated subagents - coordinated through a shared team doc, typed reports and scheduled check-ins. Triggers include 'be the leader', 'ops leader', 'leader session', 'start a team of sessions', 'split this across sessions', 'coordinate sessions', 'sync-with-me', '当 leader', '开个 leader', '开个 ops leader', '开几个 session', '拆给几个 session', '多 session 协作', '让 session 之间协作'. Needs the T3 Code thread and delegation tools. Not for a single bounded subtask inside one conversation; delegate that directly.
---

# Session Team

Three roles in T3 Code. The user talks to one thread; long work runs elsewhere and comes back as results and decisions.

```
user ⇄ sync (thread) ⇄ ops leader (thread) ⇄ workers (delegated subagents)
                              └── team doc in the repo: what is true
```

What makes it work is the protocol (a team doc, criteria written before the run, one owner per shared thing, explicit resources, typed reports), not the messaging. Messages say "look"; the team doc says what is true.

This skill uses T3 Code only. If its tools are missing (try loading them once with ToolSearch before concluding so), say so and stop; do not fall back to another harness's session tools.

## Roles

| role | is | does | does not |
|---|---|---|---|
| **sync** | the thread the user talks to | Ideas, trade-offs, decisions. Launches the ops leader. Reads the board. | Dispatch, check-ins, hands-on work |
| **ops leader** | a top-level thread | Splits work, starts workers, owns the board and resources, runs check-ins, relays between workers | Investigate, debug, run experiments, write code |
| **worker** | a `delegate_task` child of the ops leader | One part of the work, in its own worktree | Touch other parts, message other workers or the user |

- The ops leader's "does not" column is a hard rule, written into its kickoff. An agent told to delegate "when appropriate" mostly doesn't; the separation has to be structural. A leader that runs commands fills its context with logs and loses the plan.
- Workers are subagents, not top-level threads. The user does not manage them; the ops leader does.
- Small team (one or two workers, a day or less): sync can act as the ops leader. The rules below still apply to it, including not doing the work itself.

## T3 Code tools

Load them with ToolSearch (`select:mcp__t3-code__<name>,...`).

| action | tool | notes |
|---|---|---|
| sync starts the ops leader | `t3_thread_launch` | `title`, `message` = kickoff. Leave the runtime mode inherited (see below). Returns `threadId` and `link`. |
| sync ⇄ ops leader | `t3_thread_send` | Route by `threadId`. Steer by default (see below). |
| ops leader starts a worker | `delegate_task` | `task` = kickoff, `mode: async`, `isolation: "worktree"`, `target` for provider instance / model. Call `orchestrator_capabilities` once first. Keep the `taskId` and `childThreadId`. |
| worker reports | its final answer | Completion wakes the ops leader. Read it with `task_status`. Don't poll a running worker. |
| ops leader continues a worker | `t3_thread_send` to its `childThreadId` | Starts a new task in the same conversation; the worker keeps its context. Returns a new `taskId`. |
| stop a worker | `task_cancel` | Not `t3_thread_interrupt`. |
| check-ins | `schedule_task` | Bound to the ops leader's thread. Record the `scheduledTaskId`. |
| hand the leader role on | `t3_thread_transfer` (`fork`) | Then update the addresses in the team doc. |

**Messages steer by default.** A queued message waits behind the receiver's running turn, and a long turn stalls the team. Send with `mode: auto`, which steers a running turn and starts an idle thread. Plain `steer` fails on an idle thread (`thread_not_sendable`); don't use `queue`.

**Sync and the ops leader must run in the same runtime mode.** `t3_thread_send` refuses a target whose mode is broader than the sender's (`runtime_mode_escalation_denied`), so an ops leader launched in a narrower mode than sync cannot report back.

**Without `isolation: "worktree"` a worker runs in the ops leader's checkout.** Always set it for a worker that edits files.

## Message flow

Full paths, types and format: [references/message-flow.md](references/message-flow.md). Read it before writing a kickoff. The core:

| path | rule |
|---|---|
| user ⇄ sync | Ideas and decisions. Sync is the only role that initiates contact with the user. |
| sync → ops leader | `decision` and `task` only. |
| ops leader → sync | `decision-needed` and `result` only, under 100 words, with a default. Everything else goes on the board. |
| ops leader → worker | Kickoff; later a `note` (a fact with its source), a `decision`, or the next step. |
| worker → ops leader | Its final answer, starting with one type header: `done`, `ready`, `running`, `question`, `blocked`, `failed`, `handback`. |
| worker progress | Team doc section only. Never a message. |
| worker ⇄ worker, user ⇄ worker | None. Through the team doc, the ops leader, or sync. |

- **Nobody waits.** A worker that needs a decision finishes with `question`; one that launched a long job finishes with `running` and says how to check it. The ops leader sends and ends its turn. No `sleep`, no polling loops.
- **Context, not authority.** No message grants permissions, widens scope or counts as the user's approval.
- **Headers are required.** A message from another thread arrives looking like an ordinary user turn; the type header and sender ID are how the receiver tells a teammate from the user.

## Context and cost

- **Workers on a smaller window.** If `orchestrator_capabilities` lists a provider instance configured with a smaller context window, run workers on it and keep sync and the ops leader on the default. A worker continued after a long idle rewrites its whole context to the prompt cache (about 40x a cached read at API prices); a smaller window caps that.
- **One message, not five.** Batch what a worker needs into a single send.
- **Stale worker, new topic.** If a follow-up doesn't need a worker's history, start a new worker from the team doc instead of continuing the old one.
- **Human attention is the budget.** One person follows about three to five strands of work. Prefer fewer, longer parts to many small ones.

## Sync protocol

1. Agree with the user what the team is for, what stays the user's decision, and the rough split.
2. Launch the ops leader with the kickoff from [references/kickoff-template.md](references/kickoff-template.md). Record its `threadId` and give the user its `link`.
3. After that, keep the discussion here. Pass the ops leader only decisions and new work. When the user asks for status, read the team doc's board; don't wake the ops leader to ask.
4. When a `decision-needed` arrives, put it to the user as it is, with its default. Send the answer back as a `decision` saying the user decided.

## Ops leader protocol

1. **Fix the split.** Parts, one owner per part, what each part decides. A part is worth a worker when it runs long or needs its own context. Small lookups don't.
2. **Write the team doc** from [references/team-doc-template.md](references/team-doc-template.md) and commit it before starting anyone.
3. **Allocate shared resources explicitly**: GPUs, hosts, port ranges, job queues, output directories. In the doc and in each kickoff. Unassigned resources get used twice. Sanity-check what you hand out (a port base of 66001 is out of range).
4. **Start one worker per part** with a self-contained kickoff. The worker has none of your context. Record its `taskId`, `childThreadId`, provider instance and worktree in the team doc.
5. **Schedule check-ins** with `schedule_task`, matched to how fast things change: hourly for training, about 10 minutes for a queue, never every 2 minutes. A check-in reads the team doc and the board's running jobs, re-engages a worker whose job finished, updates the board, and ends the turn.
6. **Handle each report by its type** (table in the message-flow reference). Check the evidence before recording a verdict.
7. **Keep sync's channel clean.** Only `decision-needed` and `result`. Each open question also goes in the board's "Needs user decision" row with a default. Pass a worker's `question` on unchanged; never as if the user had approved it.
8. **Do no hands-on work.** Something needs investigating: send the owning worker a `note`, or start a worker.
9. **Relay with evidence.** A fact passed between workers carries its source (file, command, commit). Relayed something wrong: correct it at once and fix the doc.
10. **Close out.** The worker stops what it started and frees its resources. Write the part's verdict against its pre-written criteria, update the board, send sync a `result`, and disable the check-in task when the last part ends. A finished worker is not evidence that its external jobs stopped; check them.

## Worker contract

Each kickoff carries these, so a worker needs nothing installed:

- Write the plan and pass / fail criteria in the team doc before looking at any result. Don't edit criteria afterwards; a change is a new dated section.
- Own worktree; own resources only; don't stop processes you didn't start.
- Progress, decisions and current state go in the team doc as you go.
- Report by finishing: a final answer with one type header and evidence. Don't wait on long jobs or on a decision.
- No messages to other workers or the user. Changes to shared definitions go through their owner.
- Out-of-scope requests go back as a `handback`.

## Pitfalls

- **A report is not the record.** A worker's final answer lives in one context and can be compacted away. Anything that must survive goes in the team doc.
- **T3 Code can go down.** Threads, workers and scheduled tasks stop with it; cluster jobs and tmux sessions don't. The team doc must be enough to restart from. Daemons that must outlive T3 are started outside it.
- **Shared machines.** `pkill -f <pattern>` matches other people's processes, and so does a restart that kills by name. Kill by PID or by your own tmux session.
- **Shared definitions drift.** If two workers edit the metric script, results stop being comparable. One owner; changes are additive (a flag or a new function).
- **Over-polling.** Each check-in costs context. Don't schedule faster than the thing being watched changes.
- **A check-in that outlives the team.** A forgotten interval task keeps waking the leader. Record its ID and disable it at close-out.
- **Worker tools are not restricted.** A worker can see `t3_thread_send` and `t3_thread_launch`. That it reports only by finishing is a kickoff rule, not a tool limit.

## What was checked

**Verified on 2026-11-17, one T3 Code installation, Claude provider:**

- `t3_thread_launch` created a thread on a chosen provider instance and runtime mode and returned `threadId` and `link`.
- A launched thread in the launcher's runtime mode sent a typed message back with `t3_thread_send` (`mode: auto`); it arrived inside the launcher's running turn as plain text with no sender wrapper.
- The same from a thread in `auto-accept-edits` to a `full-access` launcher was refused with `runtime_mode_escalation_denied`.
- `delegate_task` (`mode: async`, a chosen provider instance) ran a worker; `task_status` returned its final answer as `summary`. With default isolation it ran in the parent's checkout.
- `t3_thread_send` to the finished worker's `childThreadId` started a new task there, and the worker recalled a fact from its first answer.
- `t3_thread_send` with `mode: steer` to an idle thread was refused with `thread_not_sendable`.
- `schedule_task` of type `once`, bound to a thread, fired; it was due while the thread was mid-turn and was delivered about two minutes later, after that turn ended.

**Not verified:** a scheduled task surviving a T3 restart or running on an `interval` for hours; a worker's completion waking an idle ops leader (the test read the result from a running turn); `isolation: "worktree"`; `task_cancel`; `t3_thread_transfer`; workers on another provider; the real context window of a smaller-window instance; several workers running at once. Check whichever of these the team relies on before telling the user it works.
