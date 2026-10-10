# Team doc template

One file per team, in the repo, next to the work it coordinates (for example `experiments/<name>/README.md`). It is the shared state: messages tell people to look, the doc says what is true. Commit it before dispatching anyone.

Write it in the team's working language. Drop the sections you don't need.

```markdown
# <Team / experiment name> (<YYYY-MM-DD>)

Lead: the `<leader name>` session. Every owner writes its plan and results in its own section below.
Criteria are written before the run and are not edited afterwards; a change of plan is a new, dated section.

## Roles

| session (former names) | owns | does not touch |
|---|---|---|
| leader | split, schedule, resources, the board, the final report | hands-on debugging (delegated to the owner) |
| <worker-a> | <part A: code, data, runs> | <shared metric scripts> |
| <worker-b> | <shared definitions: metrics, eval and analysis scripts> | <part A's data> |

## Rules

- Shared definitions (metrics, eval and analysis scripts, data formats) have exactly one owner. Others propose changes to that owner.
  Changes keep old outputs reproducible: add a flag or a new function, never silently redefine.
- Each session works in its own git worktree / branch and commits there; nobody edits the shared checkout.
- Don't stop or kill processes you didn't start. No broad `pkill -f` on shared machines.

## Resources

| resource | owner | notes |
|---|---|---|
| <GPUs 0-3 on host X> | <worker-a> | |
| <port range 61000-61999> | <worker-b> | |
| <job queue / quota> | leader | leader submits |

## Board (leader updates; last updated <MM-DD HH:MM>)

| part | owner | status |
|---|---|---|
| A | <worker-a> | <one line: state, key number, link> |
| B | <worker-b> | |
| Needs user decision | leader | <each open question, with the default if nobody answers> |

## Next steps (leader, <MM-DD HH:MM>; confirmed by the user: yes / no)

- ...

## Part A: plan and criteria (<owner>, <MM-DD HH:MM>, before any result)

- Question:
- Design and control:
- Pass / fail criteria:

## Part A: results (<owner>, <MM-DD HH:MM>; criteria unchanged)

- Verdict against the criteria above:
- Evidence (commit, paths, commands):
```
