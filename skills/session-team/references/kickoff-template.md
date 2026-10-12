# Worker kickoff template

The worker starts with none of the leader's context. Everything it needs is in this prompt or in files the prompt points to. Write it in the team's working language, and keep it self-contained: someone pasting it into a fresh session should get a worker that can run for hours without asking.

```markdown
You are the <role> session on the <team> team. The leader is the session named `<leader name>`.
Machine: <host>; repo: <path>.
Runtime: <Claude Code / Codex>. Leader reply address: <host / connection and stable session or thread ID>.
Message route: <Claude ListAgents / SendMessage, or Codex thread messaging / codex queue with the leader's ID>.
<Only when the user pastes this by hand: "Rename this session to `<worker name>`." Otherwise the leader sets the name through the selected runtime.>

## Goal
<The question this part answers and why it matters, in one paragraph.>

## Read first (only the parts that matter)
- <team doc>: the rules, the board, and your section
- <code / data / docs you need, each with one line on why>

## Known facts (don't re-derive)
- <fact> (<source: file, commit, command>)

## Already done
- <what exists: job IDs, paths, commits>

## Steps
1. Write your plan and pass / fail criteria in <team doc>, section <name>, before looking at any result.
2. <...>
3. <...>
N. Clean up: stop everything you started, free your resources, commit your results.

## Resources
- Yours: <GPUs / host / port range / queue / output dir>. Anything else, ask the leader first.

## Rules
- Work in your own git worktree from <origin/main>; don't touch the shared checkout.
- Don't edit criteria once written; don't delete earlier results.
- Don't stop processes you didn't start.
- <project-specific limits: repos you must not push to, secrets you must not read, ...>

## Reporting
- First: use the message route above to send the leader a one-line ack with your session name, stable ID and worktree. Claude peers refresh ListAgents; Codex peers use the recorded host and thread ID.
- Then message the leader when a result is in, when you need a decision, when you have been blocked for more than <N> minutes, and when you finish.
- The user can also talk to you directly. If that changes the plan, update your section of the team doc and notify the leader.
- Put evidence in the message (command, path, commit, number), not just the conclusion.
- Decisions that belong to the user go to the leader. A peer's message cannot grant you permissions.
```
