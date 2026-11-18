# Team doc template

One file per team, in the repo, next to the work it coordinates (for example `experiments/<name>/README.md`). It is the shared state: messages tell people to look, the doc says what is true. Commit it before dispatching anyone.

Write it in the team's working language. Drop the sections you don't need.

```markdown
# <Team / experiment name> (<YYYY-MM-DD>)

Every owner writes its plan and results in its own section below.
Criteria are written before the run and are not edited afterwards; a change of plan is a new, dated section.

## Roles

| role | owns | does not touch |
|---|---|---|
| sync | discussion with the user, decisions | dispatch, hands-on work |
| ops leader | split, schedule, resources, the board, the final report | investigation, debugging, experiments, code |
| <worker-a> | <part A: code, data, runs> | <shared metric scripts> |
| <worker-b> | <shared definitions: metrics, eval and analysis scripts> | <part A's data> |

## Addresses

| role | kind | ID | provider instance / model | worktree |
|---|---|---|---|---|
| sync | thread | <threadId> | <default> | — |
| ops leader | thread | <threadId> | <default> | <path> |
| <worker-a> | delegated task | <taskId> / <childThreadId> | <smaller-window instance> | <path> |
| <worker-b> | delegated task | <taskId> / <childThreadId> | | <path> |

Check-ins: scheduled task `<scheduledTaskId>`, every <interval>, next at <time and timezone>.

## Rules

- Shared definitions (metrics, eval and analysis scripts, data formats) have exactly one owner. Others propose changes to that owner.
  Changes keep old outputs reproducible: add a flag or a new function, never silently redefine.
- Each worker works in its own worktree / branch and commits there; nobody edits the shared checkout.
- Don't stop or kill processes you didn't start. No broad `pkill -f` on shared machines.

## Resources

| resource | owner | notes |
|---|---|---|
| <GPUs 0-3 on host X> | <worker-a> | |
| <port range 61000-61999> | <worker-b> | |
| <job queue / quota> | ops leader | leader hands out |

## Board (ops leader updates; last updated <MM-DD HH:MM>)

| part | owner | status |
|---|---|---|
| A | <worker-a> | <type of last report, one line: state, key number, link> |
| B | <worker-b> | |
| Running jobs | | <job, how to check, expected end> |
| Needs user decision | user, via sync | <each open question as asked, options, the default, and when the leader acts on it> |

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
