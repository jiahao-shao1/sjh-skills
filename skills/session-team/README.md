# session-team

English | [中文](README.zh-CN.md)

Run a team of Claude Code sessions on one always-on machine. A **leader** session talks with you and coordinates. **Worker** sessions do the long work (training, environment setup, evaluations, debugging) and report back over `SendMessage`.

## Why

Doing research with Claude Code, you hit two problems once there is more than one thread of work:

- **One session for everything gets blocked.** If the session you discuss ideas with is also setting up an environment or watching a training run, the discussion waits for the run, and its context fills with logs.
- **One session per task makes you the router.** You switch between sessions, re-read each one to remember where it was, and lose your own train of thought.

A leader / worker split fixes both:

1. **The leader is never blocked.** Training, environment setup and debugging happen in workers, so you can keep discussing ideas with the leader while they run.
2. **You don't lose your own context.** You talk to one session. The leader keeps track of the workers, and a team doc in the repo holds what is true.

This works now because current models can carry a part for hours from a written kickoff (write the criteria, run, debug, report) without being walked through it. The leader only has to coordinate.

It is not worth it for a task that fits in one session, or for short lookups; use a subagent for those.

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill session-team
```

Install it where the leader runs. Workers don't need it, because the kickoff prompt carries their rules.

## Setup (once per machine)

1. Use a machine that stays on (a dev box or a workstation), with Claude Code installed. Tested with 2.1.283.
2. Start Remote Control in a tmux session from the repo the team will work in:

   ```bash
   tmux new -s rc
   cd ~/code/my-project && claude remote-control   # short form: claude rc
   ```

   Useful flags: `--permission-mode <mode>` sets the permission mode for spawned sessions. `--spawn worktree` gives each new session its own git worktree. We haven't tried it; we use the default `same-dir` and have each worker create its own worktree.
3. Open a session from claude.ai/code or the Claude app and pick this machine's environment. Name it `leader`. Each session is a local process on the machine and keeps running when your laptop is closed.
4. Ask the leader to "list peer sessions" (`ListAgents`) to check the wiring.

Plain `claude` sessions in tmux on the same machine can also message each other. Without Remote Control you can't drive them from your phone, though, and the leader may not have `create_session` (start workers) or `send_later` (schedule its own check-ins), which come with Remote Control sessions.

## Usage

Tell the leader what you want done and that it should run it as a team, for example: "Be the leader. Split this into a data part and an eval part, give each to a worker session."

The leader then:

1. agrees the split with you;
2. writes a team doc in the repo (roles, rules, resources, a board, per-part criteria): [template](references/team-doc-template.md);
3. starts one worker per part with a self-contained kickoff prompt ([template](references/kickoff-template.md)), or hands you the prompt to paste. Workers the leader starts appear in your session list, and you can talk to them directly;
4. checks in on a schedule, updates the board, and brings you only results, blockers and decisions.

## How it works

```
you (phone / laptop) ──Remote Control──► claude remote-control on the machine
                                            │ spawns local sessions: leader, worker-a, worker-b …
                                            │
   ListAgents  ── reads the local session registry (~/.claude/sessions/*.json)
   SendMessage ── delivers to a peer's local socket → arrives as a <cross-session-message> turn
   create_session(environment_id=<bridge env>) ── leader starts a worker on the same machine
   send_later  ── leader schedules its own check-ins (survives restarts)
   team doc + git ── the shared state everyone reads and writes
```

## Lessons from running it

The rules in the skill come from about a week of a leader running four workers on a research project: around 2,200 messages, 220 scheduled check-ins, and several overnight runs.

- **Most of the work is the protocol, not the messaging.** Criteria are written before the run, each shared script has one owner, resources are assigned explicitly, and there is a board. Without these, delegated work drifts.
- **The leader drifted into hands-on work.** It ran a few hundred cluster commands a day itself and was compacted about once a day. The skill tells it to delegate investigations to the owning worker.
- **Unassigned shared resources collide.** One run broke because the leader handed out port bases above 65535. Ports, GPUs and queues are now written into the team doc and the kickoff.
