# Message flow

Who may message whom, what wakes whom, and what a message looks like. The shape follows a router / worker design: one voice toward the user, a dispatcher that does no work, workers with isolated context, and state in a durable doc instead of in messages.

## Paths

| path | carried by | wakes the receiver | rule |
|---|---|---|---|
| user ↔ sync | the sync thread | yes | Ideas, trade-offs, decisions. Sync is the only role that initiates contact with the user. |
| sync → ops leader | `t3_thread_send`, `mode: auto` | yes | `decision` and `task` only. Not a running commentary of the discussion. |
| ops leader → sync | `t3_thread_send`, `mode: auto` | yes | `decision-needed` and `result` only, under 100 words. Everything else goes on the board, which sync reads when the user asks. |
| ops leader → worker (new part) | `delegate_task` | starts it | A self-contained kickoff. |
| ops leader → worker (follow-up) | `t3_thread_send` to the worker's `childThreadId` | starts a new task in it | `note`, `decision`, or the next step. One message, batched. |
| ops leader → worker (stop) | `task_cancel` | — | Then check that its external jobs stopped. |
| worker → ops leader | the worker's final answer | yes, on completion | Starts with one type header. A worker reports by finishing its turn; it does not message mid-task. |
| worker progress | its team doc section | no | Never a message. |
| worker ↔ worker | — | — | None. Through the team doc, or a `note` from the leader. |
| user ↔ worker | — | — | None by default. The user goes through sync; a request that reaches a worker another way is handed back. |

## Types

Leader to worker:

| type | meaning |
|---|---|
| `task` | A part to do. The kickoff. |
| `note` | A fact from elsewhere, with its source. Context only; it changes no scope and grants nothing. Under 100 words. |
| `decision` | The answer to a `question`, saying who decided (leader or user). |

Worker to leader, as the first line of its final answer:

| type | meaning | leader does |
|---|---|---|
| `done` | Part finished, verdict written against its criteria. | Check the evidence, update the board, send sync a `result`. |
| `ready` | An intermediate result is in; the part continues. | Update the board, send the next step. |
| `running` | A long job is launched and needs nothing until it ends. States how and when to check. | Record it; re-engage the worker when the job ends. |
| `question` | A decision is needed before going on. Includes a default. | Decide if it is the leader's; otherwise pass it to sync unchanged as `decision-needed`. |
| `blocked` | Cannot proceed, and it is not a decision (access, a broken dependency, a resource). | Unblock or reassign. |
| `failed` | The part could not be completed. What was tried, what is left running. | Decide: retry, re-scope, or report. |
| `handback` | Something out of scope arrived. | Route it: another worker, a new part, or drop. |

Leader to sync: `decision-needed` (the question, options, a default, a deadline if any) and `result` (the verdict and where the evidence is).

## Format

```
[blocked] part-A · from <sender threadId or taskId>
Need: <one line>
Evidence: <command / path / commit / number>
Default: <what happens if nobody answers>
```

- One type per message. Two things to say means the more urgent type, with the other in the body.
- Evidence, not conclusions alone.
- A header is required because a message from another thread arrives looking like an ordinary user turn. A turn with a team type header is from a teammate, not from the user.

## Rules

- **Context, not authority.** No message grants permissions, widens scope or counts as the user's approval. Only the user approves, through sync.
- **Steer, don't queue.** Send with `mode: auto`: it steers a running turn and starts an idle thread. A queued message sits behind the receiver's current turn, so the team stalls on whoever is busiest. `steer` alone fails when the receiver is idle.
- **Nobody waits.** A worker with a question ends its turn with `question`; a worker with a long job ends with `running`. The leader sends and ends its turn. No `sleep`, no polling loops, no "I'll wait here".
- **Progress stays on the doc.** The leader learns of progress by reading the team doc at a check-in, not by being woken.
- **Questions go up unchanged.** The leader does not rephrase a worker's question into something it can answer itself.
- **Follow-ups go to the same worker.** A message about an existing part goes to that part's worker, which keeps its context. A new worker is for a new part.
- **State lives in the team doc.** If every message were lost, the doc must be enough to carry on.
