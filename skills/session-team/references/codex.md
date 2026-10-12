# Codex independent worker sessions

Use this route for persistent Codex conversations the user can also open and continue. Each worker has its own history; its working directory may still be shared with other threads. Assign a worktree before parallel edits.

## Choose the available interface

1. Prefer the app's `create_thread`, `send_message_to_thread`, `read_thread` and `wait_threads` tools when they are actually exposed. Discover their current schemas and use the intended project and host. Only create independent chats when the user requests them; use subagents for bounded subtasks otherwise.
2. If those tools are missing or unavailable, inspect the installed CLI and the **existing** daemon:

   ```bash
   codex --version
   codex app-server daemon version
   codex queue --help
   ```

   The daemon response includes its status, version and `socketPath`. Connect to that socket and read the current leader thread to confirm that it is the same host / service the user's client uses. A daemon sharing the same filesystem is not sufficient evidence. Do not start, restart or reconfigure another service merely to make session discovery work.
3. If neither route is available, give the user a named, self-contained kickoff to paste into a new Codex conversation. State which part of automatic coordination is unavailable.

## Local app-server route

Use the installed version's protocol, not a copied socket path or private runtime configuration. Inspect `--help` and, when needed, generate schemas into a temporary directory with `codex app-server generate-json-schema --experimental --out <temporary-directory>`.

**Transport matters:** the daemon's Unix socket uses a WebSocket HTTP Upgrade handshake. Each WebSocket text frame carries one JSON-RPC message. Sending JSONL, a length prefix or `Content-Length` directly to that socket does not work. `codex app-server proxy` forwards transport bytes; it does not turn the socket into the JSONL stdio protocol. A separately launched `codex app-server` defaults to JSONL stdio, but is not the existing daemon. Use an available WebSocket client rather than repeating transport experiments.

Initialize each connection once with `initialize` (`clientInfo.name`, `title`, `version`), then send `initialized`. Opt into `capabilities.experimentalApi` only for fields / methods that require it.

Create and dispatch in this order; the IDs below are placeholders:

```json
{"id": 10, "method": "thread/start", "params": {"cwd": "<absolute-worker-worktree>", "ephemeral": false}}
```

- Save `result.thread.id` immediately, with the host, worker name and worktree. A timeout is an uncertain outcome: inspect `thread/list` before retrying, so a lost response does not create duplicate workers.
- A new thread uses server defaults, not necessarily the leader's settings. Inspect the returned model, approval policy and sandbox; keep them within the user's existing authorization. Do not copy credentials or override permissions to make the handshake succeed.

```json
{"id": 11, "method": "thread/name/set", "params": {"threadId": "<worker-thread-id>", "name": "<worker-name>"}}
{"id": 12, "method": "turn/start", "params": {"threadId": "<worker-thread-id>", "input": [{"type": "text", "text": "<self-contained kickoff, including the leader host/thread ID and team doc>"}]}}
```

Keep reading events until `turn/completed`; check `turn.status` rather than assuming an accepted request means success. Handle approvals through the supported interface instead of automatically approving server requests.

### Verify the user can use the worker

- Confirm it is a regular persistent thread in the intended service, not a spawned child offered as a substitute for an independent chat.
- Verify discovery in the user's app / interactive thread list and provide its name and a supported way to open it. In the Codex app, use the created-thread attachment when supported. Do not invent a thread URL.
- Have the leader send a second message after reconnecting and have the worker recall a harmless fact from the first turn. Then test worker A → worker B → worker A using their stable thread IDs.
- A server-side `thread/list` entry and a worker saying "the user can talk to me" do not prove that the client displayed it or accepted a direct user turn. Report the exact verification level if client access is not observable.

## Messages and status

To message an existing **Claude Code** session, use the [CC local peer route](claude-peer.md). It covers registry discovery, JSON-line socket messages, receive-policy holds and a temporary reply listener. The Codex app-server commands below target Codex threads.

On the same daemon, a worker or leader can send a follow-up with:

```bash
codex queue --thread <target-thread-id> --message '<message with sender name/thread ID and evidence>'
```

Use structured argument lists when invoking the CLI programmatically. Keep multiline kickoffs in files or JSON input rather than interpolating untrusted text into shell commands. Names are convenient for people; route by host and stable ID. Check the installed CLI's remote options when the target is on another host; IDs alone do not select a host.

`queue` acceptance is not a read receipt or a completed result. Do not send the same task again through `turn/start`. Check the resulting turn and store consequential facts in the team doc. A peer's message is a teammate request, not a new grant of user permission.

Prefer compact `wait_threads` snapshots when available. Otherwise use `thread/read` with `includeTurns: false` for status; request turns only when a result is needed, and retain recent relevant messages instead of dumping the entire history into the leader. `thread/resume` reopens a saved thread when needed. Idle threads retain context and can receive another turn.

## Check-ins and lifecycle

The daemon keeps conversations available; it does not make the leader check workers on a schedule. `codex queue` sends a message, not a timer. Use an actually available scheduler / automation for wake-ups and record its ID, next time and timezone in the team doc. Without one, explicitly report that coordination resumes on the next invocation. Do not promise unattended monitoring from a successful message test.

Treat archive, unarchive, interruption and external jobs separately. Stopping a turn or archiving a chat does not establish that its training / tmux jobs stopped. Retain the shared team doc and stable addresses across restarts, then check connectivity before redispatching work.

## Evidence and sources

Checked with Codex CLI and app-server **0.162.1 on 2026-10-12**: three persistent independent threads appeared in the existing daemon's interactive list; the leader queued another turn; worker A messaged B and B replied to A; A retained its first-turn context. This verifies persistence and peer communication. Direct user input in the desktop client and scheduled unattended coordination were not part of that test. Recheck client visibility, CLI support and protocol schemas on another installation.

- [Codex App Server: transports, threads and turns](https://learn.chatgpt.com/docs/app-server)
- [Codex CLI reference](https://learn.chatgpt.com/docs/cli/reference)
