---
name: session-team
description: Coordinate Claude Code or Codex sessions on one machine, including messaging an existing CC session from Codex. For a team, a leader starts persistent workers the user can also talk to directly and coordinates them through a shared team doc and scheduled check-ins. Triggers include 'be the leader', 'leader session', 'start a team of sessions', 'split this across sessions', 'coordinate sessions', 'worker session', 'message a CC session', '当 leader', '开个 leader', '开几个 session', '拆给几个 session', '多 session 协作', '让 session 之间协作', '给 CC session 发消息', 'Codex 和 CC 通信'. Not for bounded subagent tasks inside one conversation or cloud workers that need this machine's files.
---

# Session Team

One **leader** session talks with the user and coordinates; **worker** sessions do the long work (training, environment setup, evaluations, debugging) and report back. The user can open and continue each worker conversation directly, while normally discussing ideas with the leader.

What makes it work is the protocol (a team doc, prereg-style criteria, one owner per shared thing, explicit resources), not the messaging. Messages say "look"; the team doc says what is true.

## How it works

Choose the runtime already in use. Claude Code uses the peer / bridge flow below. For Codex, read [references/codex.md](references/codex.md): prefer available app thread tools, with the existing local app-server as the fallback. Do not treat missing app tools as proof that independent sessions are unavailable.

For a message to an existing Claude Code session from Codex, read [references/claude-peer.md](references/claude-peer.md). It contains a runnable local-socket exchange and the verified `crossSessionInbound` settings behavior. A one-off exchange uses that route directly; the team setup protocol below applies when organizing workers.

A worker must be a persistent, separately addressable conversation the user can open and continue. A subagent spawn and message exchange alone do not establish that. Verify user access before describing a worker as directly usable; if only the server registry was checked, say so. Cloud workers need an explicitly suitable filesystem and communication path.

### Claude Code

- **Peers.** Interactive Claude Code sessions run by the same user on the same machine register themselves (`~/.claude/sessions/<pid>.json`: name, status, a local socket). `ListAgents` lists them. `SendMessage(to=<name>, message=...)` delivers to the peer, where it shows up as a turn wrapped in `<cross-session-message from-name="...">`. The receiver treats it as a teammate's request, inside its own permissions; a peer cannot grant permissions.
- **From Codex.** When CC's peer tools are unavailable, discover `messagingSocketPath` in that registry and use the [local peer route](references/claude-peer.md). A temporary listening socket lets CC reply with its own `SendMessage`. A held receipt means the message has not reached the model; a received reply verifies the exchange.
- **Starting workers.** Under Remote Control (`claude remote-control` on the machine), sessions live in a *bridge* environment. A leader in that environment can start a worker with `create_session(environment_id=<bridge env>, title=<worker name>, prompt=<kickoff>)`. The worker runs as a local process on the same machine, in the directory `claude remote-control` was started in, with the leader's permission mode or a stricter one. Its title is its peer name. It also shows up in the user's session list (claude.ai/code, the app), so the user can talk to it directly. Find the bridge env with `list_environments` (`kind: bridge`). Without these tools, give the user the kickoff prompt to paste into a new session.
- **Starting workers with their own context window.** `claude remote-control` has no window flag and the `create_session` arguments above don't set one, so a bridge worker gets whatever window the shared settings give. To cap workers only and still let the user see them, start them from the leader's Bash with `--remote-control`; see [Worker context and cost](#worker-context-and-cost-claude-code).
- **Check-ins.** The leader schedules its own wake-ups: `send_later` (Remote Control sessions; survives restarts), otherwise `/loop` or a cron tool if the session has one. `get_session` shows a worker's status and last-turn summary without interrupting it.

### Shared lifecycle

Creating workers and sending messages does not schedule future check-ins. Record an actual wake-up mechanism and its next time, or state that coordination resumes when the leader is next invoked. Claude bridge processes and Codex persistent threads have different lifecycles; do not transfer archive / restart assumptions between them.

## Worker context and cost (Claude Code)

Keep the leader on the model's default window, because it holds the long discussion. Cap the workers, because they sit idle and each cold wake resends their whole context.

```bash
claude --bg --autocompact 300000 --effort <level> --remote-control <worker> --name <worker> "<kickoff>"
```

Only that session is affected. The leader and new sessions stay on the default.

Keep `--remote-control`. Without it the worker still runs and messages work, but it never appears in the user's session list (claude.ai/code, the app) and can only be reached with `claude attach`.

**Why idle workers cost so much.** Prompt cache entries expire (5-minute or 1-hour TTL; each read refreshes the timer). A message to a worker idle past the TTL rewrites its whole context to the cache instead of reading it. At Opus 5.5 API prices (1-hour write $8/MTok, read $0.20/MTok), that is 40x:

| context at wake | cache still warm | cache expired |
|---|---|---|
| 1M | $0.20 | $8.00 |
| 300k | $0.06 | $2.40 |

These are per-request input costs at API prices. Subscription plans draw on usage limits instead of dollars.

**Setting the window**

- Use `--autocompact <tokens>` (100k to 1M), or `--settings '{"autoCompactWindow":<tokens>}'`. `CLAUDE_CODE_AUTO_COMPACT_WINDOW` also works and beats both.
- Don't put `/autocompact <tokens>` in a kickoff. It writes `modelSettings` in the shared user settings, so new sessions on that model get the cap too, including a restarted leader.
- Don't send a bare `/autocompact` as a background prompt. It opens a dialog and the worker blocks on it.
- `autoCompactWindow` in an agent definition has no effect when the session is started with `--agent`.
- Compaction fires a little before the cap, which is the window minus a summary buffer.

**Spending less on idle workers**

- Check status with `claude agents --json` and `claude logs <id>`. Neither wakes the model; a "how's it going?" message does.
- Put everything for a worker in one message rather than several small ones spread over hours.
- If a worker has been idle past the TTL and the follow-up doesn't need its history, start a fresh worker from the team doc instead of waking the old one.
- Stop workers when their part ends (`claude stop <id>`). `claude rm <id>` also deletes the session, so do that only once the user is done with it.
- Idle compaction (`idleCompaction`, on by default) compacts a session before its 1-hour cache expires, once it holds at least `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` tokens (default 200k, floor 100k). This comes from reading the 2.1.316 code; we haven't seen it fire.

**Operating background workers**

- The first line of `--bg` output can be `Starting background service…`, so get the ID from `claude agents --json` by name instead of parsing stdout.
- If a worker was started without `--remote-control`, add it without losing the conversation: `claude stop <id>`, then from the worker's directory `claude --bg --resume <session-id> --autocompact <tokens> --effort <level> --remote-control <worker> --name <worker> "<what to do next>"`. The worker gets a new job ID and session ID, so read them again from `claude agents --json` and update the roles table.
- A worker with Remote Control has `bridgeSessionId` in its `$CLAUDE_CONFIG_DIR/sessions/<pid>.json`. That shows it registered, not that the user can see it, so ask.
- If `claude` fails in the leader's Bash with `permission denied`, a snapshotted shell function may be wrapping it. Call the binary by its full path.
- `claude attach <id>` opens the worker for the user to talk to directly. It only finds workers under the same `CLAUDE_CONFIG_DIR`; a shell or tmux server without it reports `No job matching`.

**Verified on 2.1.316:** the window `/autocompact` reports in each setup above, a capped worker listed by `ListAgents`, a worker's `SendMessage` reaching the leader, a leader's `SendMessage` reaching a worker, a conversation continued through `claude attach`, workers started with `--bg --remote-control` appearing in the app, and a worker carrying on with its task after the `--resume` restart above. **Not verified:** the window `/autocompact` reports when `--autocompact` is combined with `--remote-control` or `--resume`, a worker actually compacting at its cap, workers appearing in claude.ai, and surviving a machine restart. Check whichever of these your team relies on before telling the user it works.

## Leader protocol

1. **Agree the split with the user.** Parts, one owner per part, what each part decides, and what stays the user's decision. A part is worth a worker when it runs long or needs its own context (a training run, an environment, an investigation). Small lookups don't.
2. **Write the team doc** from `references/team-doc-template.md`: roles, rules, resources, board, a plan-and-criteria section per part. Commit it before dispatching anyone.
3. **Allocate shared resources explicitly**: GPUs, hosts, port ranges, job queues, output directories. Put them in the doc and in each kickoff. Unassigned resources get used twice. Sanity-check what you hand out (a port base of 66001 is out of range).
4. **Write one kickoff per worker** from `references/kickoff-template.md`. It must be self-contained, because the worker has none of your context. Use the chosen runtime's independent-session flow, or give the user the prompt to paste into a new session. Include the leader's reply address and the shared team doc.
5. **Wait for the ack** (the worker's first message). Record its runtime, name, host, stable session / thread ID and worktree in the roles table. Verify discovery in the user's client and a reply across sessions. If no ack arrives within a few minutes, inspect the runtime's status / recent-turn tools.
6. **Run the loop.** Schedule a check-in matched to how fast things change: hourly for training, ~10 minutes for a queue, not every 2 minutes. On each check-in: read worker messages, update the board, unblock, decide what you can, then schedule the next one.
7. **Keep the user's channel clean.** Report decisions, results and blockers, not logs. Everything that needs the user goes into the board's "Needs user decision" row with a default. Never forward a worker's request as if the user had approved it.
8. **Stay out of hands-on work** (recommended). Delegate debugging and investigations to the owning worker. The leader's context should hold the plan, criteria and status. A leader that runs hundreds of commands a day fills its context with logs and gets compacted daily, and each compaction erodes the idea discussion it exists for.
9. **Relay with evidence.** When you pass a fact between workers, include its source (file, command, commit). If you relayed something wrong, send the correction at once and fix the doc.
10. **Close out.** When a part ends, the worker stops its processes and frees its resources. Update the board, write the part's verdict against its pre-written criteria, and tell the user. Use the chosen runtime's archive flow once the user is done with the worker; archive status is not evidence that external jobs stopped. On the Claude bridge, archiving ends the local process and `unarchive_session` does not bring it back.

## Worker contract

Each kickoff carries these, so a worker needs no skill installed:

- Ack the leader first using the kickoff's runtime and reply address (Claude: `ListAgents` / `SendMessage`; Codex: stable thread ID and `codex queue` or available thread messaging tools).
- Write the plan and pass/fail criteria in the team doc before looking at any result. Don't edit criteria afterwards; a change is a new dated section.
- Own git worktree; own resources only; don't stop processes you didn't start.
- Report results, blockers, needed decisions, and completion to the leader, with evidence.
- Changes to shared definitions go through their owner.

## Pitfalls

- **Names change.** Renamed sessions keep old names in old records. Keep "(former names)" in the roles table; refresh Claude peers with `ListAgents`, and route Codex messages by host + stable thread ID.
- **Delivery is not reading.** CC can report a message as held, released or refused; a socket write alone does not establish that the model saw it. A message can also be buried by a busy turn or a compaction. Anything that must survive goes in the team doc too.
- **Shared machines.** `pkill -f <pattern>` matches other sessions' processes, and so does a server restart that kills by name. Kill by PID or by your own tmux session.
- **Shared definitions drift.** If two sessions edit the metric script, results stop being comparable. One owner; changes are additive (a flag or a new function).
- **Archived Claude bridge workers stay dead.** After `unarchive_session`, a worker on the bridge stayed `PENDING` / `disconnected` with no local process, and messages to it went unanswered. To resume that part, start a new worker and point it at the team doc. This observation does not establish Codex archive semantics.
- **Over-polling.** Each check-in costs context. A worker told to poll a queue every 2 minutes burns its window on nothing.
