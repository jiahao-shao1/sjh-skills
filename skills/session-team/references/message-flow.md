# Message flow

Who may message whom, what wakes whom, and what a message looks like. Supports both **Single-Ops-Leader** and **Multi-Lead (Model B)** topologies while keeping state on disk instead of in chatty messages.

## Paths

| path | carried by | wakes receiver | rule |
|---|---|---|---|
| user ↔ sync | sync thread | yes | Global overview, cross-track trade-offs, global rules, spawning/retiring leads. |
| user ↔ domain lead *(Model B)* | domain lead thread | yes | Vertical architecture/research discussion and domain-local decisions. |
| sync → any lead | `t3_thread_send`, `mode: auto` | yes | `decision` and `task` only. Not a running commentary. |
| **any lead → sync** | team doc / `status/<lead>.md` | **no** | **Universal Quiet-Sync (hard rule):** Ops Leader AND every Domain Lead NEVER send messages to sync. Write your own status card; sync reads all cards in parallel when the user asks. |
| lead ↔ lead *(Model B)* | `t3_thread_send`, `mode: auto` | yes | Cross-lead `note`, `request`, or `handoff` (e.g., domain lead handing verified commit + run spec to ops leader). Explicit header, evidence/paths, state if no reply needed. |
| lead → worker (new part) | `delegate_task` | starts it | Self-contained kickoff (`isolation: "worktree"` when editing files). |
| lead → worker (follow-up) | `t3_thread_send` to `childThreadId` | starts a new task | `note`, `decision`, or next step. One batched message. |
| lead → worker (stop) | `task_cancel` | — | Never `t3_thread_interrupt`. Verify external jobs stopped afterwards. |
| worker → parent lead | worker's final answer | yes, on completion | Starts with one type header. Reports by finishing; never messages mid-task. |
| worker progress | team doc section | no | Never a message. |
| worker ↔ worker | — | — | None. Through the team doc or a `note` from the parent lead. |
| user ↔ worker | — | — | None. Requests reaching a worker directly go back as `handback`. |

## Types

### Lead to worker

| type | meaning |
|---|---|
| `task` | A bounded part to do (the kickoff). |
| `note` | A fact from elsewhere with its source. Context only; changes no scope and grants nothing. Under 100 words. |
| `decision` | The answer to a `question`, stating who decided (lead or user). |

### Cross-lead (Model B: domain lead ↔ ops leader, domain lead ↔ domain lead)

| kind | meaning | typical example |
|---|---|---|
| `note` | Verified fact or change another lead should know. Usually `Reply needed: no`. | Infra lead merged a schema fix on commit `abc1234`. |
| `request` | Bounded ask requiring another lead's action or info. | Ops leader asks infra lead to debug a crashing container script (0-GPU code fix). |
| `handoff` | Verified commit + exact run spec handed over for execution. | Domain lead hands verified training/eval commit + config + pass/fail criteria to ops leader for cluster GPU run. |

### Worker to parent lead (first line of final answer)

| type | meaning | parent lead does |
|---|---|---|
| `done` | Part finished, verdict written against criteria. | Verify evidence, record verdict in doc, update board/card. |
| `ready` | Intermediate result is in; part continues. | Update board/card, send next step. |
| `running` | Long job launched; states how and when to check. | Record it; re-engage worker when job ends. |
| `question` | Decision needed before continuing; includes default. | Decide if lead-owned; else record unchanged in open decisions with default (or ask user in domain lead thread) and continue on default/other work. |
| `blocked` | Cannot proceed (access, broken dep, resource). | Unblock or reassign. |
| `failed` | Could not complete; states what was tried and what is still running. | Decide: retry, re-scope, or record. |
| `handback` | Out-of-scope request arrived. | Route to right owner/lead or drop. |

## Formats

**Cross-lead message (Model B):**
```
[from: <lead> | kind: note|request|handoff]
Summary: <one line>
Evidence / paths: <commit, file path, command, status card>
Action / spec: <what is requested or handed off, if any>
Reply needed: <yes (by when / what) | no>
```

**Worker report / lead-to-worker:**
```
[blocked] part-A · from <sender threadId or taskId>
Need: <one line>
Evidence: <command / path / commit / number>
Default: <what happens if nobody answers>
```

- One type/kind per message. If two things apply, use the more urgent type and put the other in the body.
- Evidence, not conclusions alone.
- Headers are mandatory: cross-thread messages arrive looking like ordinary user turns, so the header is how the receiver distinguishes a teammate from the user.

## Rules

- **Universal Quiet-Sync:** No lead (neither Ops Leader nor any Domain Lead) ever messages `sync`. Upward visibility flows exclusively through disk (`status/<lead>.md` and the team doc).
- **Context, not authority:** No message grants permissions, widens scope, or counts as user approval.
- **Steer, don't queue:** Always send with `mode: auto` (steers a running turn, starts an idle thread). Plain `steer` fails on idle (`thread_not_sendable`); `queue` stalls behind long turns.
- **Nobody waits:** A worker with a question ends with `question`; one with a long job ends with `running`. Leads send and end their turn. No `sleep`, no polling loops.
- **Questions go up unchanged:** Leads do not rephrase a worker's user-facing question into something they can answer themselves.
- **Follow-ups go to the same worker:** Same part → `t3_thread_send` to `childThreadId`; new part or stale history → fresh `delegate_task`.
- **State lives on disk:** If every message were lost, the team doc and `status/<lead>.md` cards must be enough to carry on.
