# Team doc & federated status card templates

Two patterns:
- **Team doc** (Single-Ops-Leader, and shared index/registry in Model B): one file in the repo next to the work (e.g. `experiments/<name>/README.md`), committed before dispatching anyone.
- **Federated status cards** (Model B, or any multi-worktree team): one shared absolute directory `<main-repo>/<team-dir>/status/` with **one concise file per lead** (`ops.md`, `infra.md`, `taskgen.md`, `kg.md`, <= 20 lines each). Solves the multi-worktree blind spot (worktree-local `STATUS.md` files are invisible across worktrees), eliminates write contention, and lets `sync` read every lead in parallel in 1 turn.

Write in the team's working language. Drop sections you don't need.

## Federated status card (`<main-repo>/<team-dir>/status/<lead>.md`)

One owner per file; keep strictly **<= 20 lines** so `sync` and peer leads can scan all cards in one turn.

```markdown
# <lead> status
- Updated: <YYYY-MM-DD HH:MM TZ>
- Thread: `<threadId>` | Worktree: `<path or main>`
- Focus: <1–2 line current objective / active milestone>
- Verified numbers:
  - <metric / test / eval result> (`<commit or path>`)
- Active compute / resources: <none (0-GPU local) | GPUs / jobs / ports / stop-timer>
- Open user decisions:
  - <none | question, options, default, action time>
- Next step: <concrete next action or handoff target>
```

## Team doc (`<team-dir>/README.md`)

```markdown
# <Team / experiment name> (<YYYY-MM-DD>)

Every owner writes its plan and results in its own section below.
Criteria are written before the run and are not edited afterwards; a change of plan is a new, dated section.
<Model B only> Live per-lead status cards live in `<main-repo>/<team-dir>/status/<lead>.md` (one owner per file, <= 20 lines).

## Roles

| role | owns | does not touch |
|---|---|---|
| sync | global overview, cross-track trade-offs, spawning/retiring leads | dispatch, hands-on work |
| ops leader | shared GPUs/pools, long runs, check-ins, teardown, `status/ops.md` | investigation, debugging, experiments, domain 0-GPU code edits |
| <domain-lead> *(Model B)* | <vertical track: 0-GPU code/tests/PRs, own workers, `status/<lead>.md`> | shared cluster GPUs / unattended long loops |
| <worker-a> | <part A: code, data, runs> | <shared metric scripts> |
| <worker-b> | <shared definitions: metrics, eval and analysis scripts> | <part A's data> |

## Addresses

| role | kind | ID | provider instance / model | worktree | status card |
|---|---|---|---|---|---|
| sync | thread | <threadId> | <default> | — | reads all |
| ops leader | thread | <threadId> | <default> | <path> | `status/ops.md` |
| <domain-lead> | thread | <threadId> | <default> | <path> | `status/<lead>.md` |
| <worker-a> | delegated task | <taskId> / <childThreadId> | <smaller-window instance> | <path> | — |
| <worker-b> | delegated task | <taskId> / <childThreadId> | | <path> | — |

Check-ins: scheduled task `<scheduledTaskId>`, every <interval>, next at <time and timezone>.

## Rules

- **Universal Quiet-Sync:** No lead (ops leader or domain lead) ever messages `sync`. Write to your own status card / team doc.
- Shared definitions (metrics, eval and analysis scripts, data formats) have exactly one owner. Others propose changes to that owner. Changes keep old outputs reproducible: add a flag or a new function, never silently redefine.
- Each worker works in its own worktree / branch (`isolation: "worktree"`) and commits there; nobody edits the shared checkout.
- Don't stop or kill processes you didn't start. No broad `pkill -f` on shared machines.

## Resources

| resource | owner | notes |
|---|---|---|
| <GPUs 0-3 on host X> | <worker-a> | allocated by ops leader |
| <port range 61000-61999> | <worker-b> | allocated by ops leader |
| <job queue / quota> | ops leader | ops leader hands out |

## Board (ops leader updates; last updated <MM-DD HH:MM>)

| part | owner | status |
|---|---|---|
| A | <worker-a> | <type of last report, one line: state, key number, link> |
| B | <worker-b> | |
| Running jobs | | <job, how to check, expected end> |
| Needs user decision | user, via sync | <each open question as asked, options, default, and when the leader acts on it> |

## Next steps (ops leader, <MM-DD HH:MM>; confirmed by the user: yes / no)

- ...

## Part A: plan and criteria (<owner>, <MM-DD HH:MM>, before any result)

- Question:
- Design and control:
- Pass / fail criteria:

## Part A: progress (<owner>; append, newest last)

- <MM-DD HH:MM> <what changed, where it is>

## Part A: results (<owner>, <MM-DD HH:MM>; criteria unchanged)

- Verdict against the criteria above:
- Evidence (commit, paths, commands):
```
