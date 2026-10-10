---
name: session-team
description: Run a team of Claude Code sessions on one machine — a leader session splits the work, starts worker sessions, and coordinates them over SendMessage, with a shared team doc, self-contained kickoff prompts and scheduled check-ins, so the user keeps one conversation (with the leader) while long runs happen elsewhere. Triggers: 'be the leader', 'leader session', 'start a team of sessions', 'split this across sessions', 'coordinate sessions', 'worker session', '当 leader', '开个 leader', '开几个 session', '拆给几个 session', '多 session 协作', '让 session 之间协作'. Not for subagents inside one session (use the Agent tool) or for cloud sessions that need this machine's files.
---

# Session Team

One **leader** session talks with the user and coordinates; **worker** sessions do the long work (training, environment setup, evaluations, debugging) and report back. The user discusses ideas with the leader instead of switching between sessions, and the leader is never stuck behind a three-hour run.

What makes it work is the protocol (a team doc, prereg-style criteria, one owner per shared thing, explicit resources), not the messaging. Messages say "look"; the team doc says what is true.

## How it works

- **Peers.** Interactive Claude Code sessions run by the same user on the same machine register themselves (`~/.claude/sessions/<pid>.json`: name, status, a local socket). `ListAgents` lists them. `SendMessage(to=<name>, message=...)` delivers to the peer, where it shows up as a turn wrapped in `<cross-session-message from-name="...">`. The receiver treats it as a teammate's request, inside its own permissions; a peer cannot grant permissions.
- **Starting workers.** Under Remote Control (`claude remote-control` on the machine), sessions live in a *bridge* environment. A leader in that environment can start a worker with `create_session(environment_id=<bridge env>, title=<worker name>, prompt=<kickoff>)`. The worker runs as a local process on the same machine, in the directory `claude remote-control` was started in, with the leader's permission mode or a stricter one. Its title is its peer name. It also shows up in the user's session list (claude.ai/code, the app), so the user can talk to it directly. Find the bridge env with `list_environments` (`kind: bridge`). Without these tools, give the user the kickoff prompt to paste into a new session.
- **Check-ins.** The leader schedules its own wake-ups: `send_later` (Remote Control sessions; survives restarts), otherwise `/loop` or a cron tool if the session has one. `get_session` shows a worker's status and last-turn summary without interrupting it.
- **Not workers:** cloud sessions in a separate container can't see this machine's files and can't message back. Subagents (Agent tool) report only to the leader and the user can't talk to them; use them for bounded lookups, not for multi-hour parts.

## Leader protocol

1. **Agree the split with the user.** Parts, one owner per part, what each part decides, and what stays the user's decision. A part is worth a worker when it runs long or needs its own context (a training run, an environment, an investigation). Small lookups don't.
2. **Write the team doc** from `references/team-doc-template.md`: roles, rules, resources, board, a plan-and-criteria section per part. Commit it before dispatching anyone.
3. **Allocate shared resources explicitly**: GPUs, hosts, port ranges, job queues, output directories. Put them in the doc and in each kickoff. Unassigned resources get used twice. Sanity-check what you hand out (a port base of 66001 is out of range).
4. **Write one kickoff per worker** from `references/kickoff-template.md`. It must be self-contained, because the worker has none of your context. Start the worker with `create_session`, or give the prompt and the session name to the user to paste.
5. **Wait for the ack** (the worker's first message). Record its name in the roles table. If no ack arrives within a few minutes, check `get_session` / `ListAgents`.
6. **Run the loop.** Schedule a check-in matched to how fast things change: hourly for training, ~10 minutes for a queue, not every 2 minutes. On each check-in: read worker messages, update the board, unblock, decide what you can, then schedule the next one.
7. **Keep the user's channel clean.** Report decisions, results and blockers, not logs. Everything that needs the user goes into the board's "Needs user decision" row with a default. Never forward a worker's request as if the user had approved it.
8. **Stay out of hands-on work** (recommended). Delegate debugging and investigations to the owning worker. The leader's context should hold the plan, criteria and status. A leader that runs hundreds of commands a day fills its context with logs and gets compacted daily, and each compaction erodes the idea discussion it exists for.
9. **Relay with evidence.** When you pass a fact between workers, include its source (file, command, commit). If you relayed something wrong, send the correction at once and fix the doc.
10. **Close out.** When a part ends, the worker stops its processes and frees its resources. Update the board, write the part's verdict against its pre-written criteria, and tell the user. Archive a worker you started (`archive_session`) once the user is done with it; that also ends its local process. Archiving is final: `unarchive_session` does not bring the local process back.

## Worker contract

Each kickoff carries these, so a worker needs no skill installed:

- Ack the leader first (`ListAgents`, then `SendMessage`).
- Write the plan and pass/fail criteria in the team doc before looking at any result. Don't edit criteria afterwards; a change is a new dated section.
- Own git worktree; own resources only; don't stop processes you didn't start.
- Report results, blockers, needed decisions, and completion to the leader, with evidence.
- Changes to shared definitions go through their owner.

## Pitfalls

- **Names change.** Renamed sessions keep old names in old records. Run `ListAgents` before sending, and keep "(former names)" in the roles table.
- **No read receipts.** A message can be buried by a busy turn or a compaction. Anything that must survive goes in the team doc too.
- **Shared machines.** `pkill -f <pattern>` matches other sessions' processes, and so does a server restart that kills by name. Kill by PID or by your own tmux session.
- **Shared definitions drift.** If two sessions edit the metric script, results stop being comparable. One owner; changes are additive (a flag or a new function).
- **Archived workers stay dead.** After `unarchive_session`, a worker on the bridge stayed `PENDING` / `disconnected` with no local process, and messages to it went unanswered. To resume a part, start a new worker and point it at the team doc.
- **Over-polling.** Each check-in costs context. A worker told to poll a queue every 2 minutes burns its window on nothing.
