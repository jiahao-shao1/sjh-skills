# session-team

English | [中文](README.zh-CN.md)

Run a team in T3 Code. You talk to a **sync** thread. An **ops leader** thread dispatches and checks in. **Workers** do the long work (training, environment setup, evaluations, debugging) as subagents of the ops leader and report back.

```
you ⇄ sync (thread) ──→ ops leader (thread) ⇄ workers (delegated subagents)
           ↑ reads              │ writes
           └──── team doc in the repo: what is true
```

## Why

Doing research with coding agents, you hit two problems once there is more than one strand of work:

- **One session for everything gets blocked.** If the session you discuss ideas with is also setting up an environment or watching a training run, the discussion waits for the run, and its context fills with logs.
- **One session per task makes you the router.** You switch between sessions, re-read each one to remember where it was, and lose your own train of thought.

Three roles fix both:

1. **Sync is never blocked and stays clean.** It holds the discussion and your decisions, nothing else.
2. **The ops leader carries the coordination.** It splits the work, starts workers, keeps a board in the team doc and checks in on a schedule. It does no hands-on work, so its context holds the plan instead of logs.
3. **Workers have isolated context.** Each takes one part from a written kickoff and reports by finishing.

It is not worth it for a task that fits in one session; delegate that directly.

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill session-team
```

Requires T3 Code: the skill uses its thread, delegation and scheduling tools and nothing else. Workers need no skill installed; the kickoff carries their rules.

## Usage

Tell the thread you are talking to what you want done and that it should run it as a team, for example: "Be sync. Start an ops leader for this; split it into a data part and an eval part."

1. Sync agrees the goal and the split with you, then launches the ops leader thread and gives you its link.
2. The ops leader writes a team doc in the repo (roles, addresses, resources, a board, per-part criteria): [template](references/team-doc-template.md).
3. It starts one worker per part with a self-contained kickoff ([template](references/kickoff-template.md)), each in its own worktree, and schedules its check-ins.
4. You keep discussing with sync. Ask it how things are going whenever you want; it reads the team doc and tells you, including any decisions waiting for you.

## How messages flow

The rules are in [references/message-flow.md](references/message-flow.md). In short:

- Only sync talks to you.
- The ops leader never messages sync. It writes results, progress and open decisions to the team doc; sync reads the doc when you ask for progress.
- A worker reports by finishing, with a type header: `done`, `ready`, `running`, `question`, `blocked`, `failed` or `handback`. Progress goes in the team doc, not in messages.
- Workers do not message each other or you.
- Nobody waits: a worker with a question or a long job finishes its turn and is continued later in the same conversation.
- A message carries context, never authority.

The shape follows router / worker designs: a dispatcher that does no work, workers with isolated context, and state kept in a durable doc.

## What was checked

The skill's last section lists what was verified on one T3 Code installation (launching threads, messages between threads and the runtime-mode rule, delegated workers, continuing a worker with its context) and what was not (scheduled tasks firing over hours or across a restart, worktree isolation, several workers at once).

## Lessons from running it

The protocol rules come from about a week of a leader running four workers on a research project, before the move to T3 Code: around 2,200 messages, 220 scheduled check-ins, and several overnight runs.

- **Most of the work is the protocol, not the messaging.** Criteria are written before the run, each shared script has one owner, resources are assigned explicitly, and there is a board. Without these, delegated work drifts.
- **The leader drifted into hands-on work.** It ran a few hundred cluster commands a day itself and was compacted about once a day. The ops leader's "no hands-on work" rule is now a hard one.
- **Unassigned shared resources collide.** One run broke because the leader handed out port bases above 65535. Ports, GPUs and queues are written into the team doc and the kickoff.
