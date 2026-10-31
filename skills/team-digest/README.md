# team-digest

English | [中文](README.zh-CN.md)

Help a team communicate through its agents, without progress reports. Each agent commits what it did to its own branch. Topic issues exist only for things that need aligning or deciding, and a digest is written only when someone asks. The agent states what happened; people decide.

## Why

[session-team](../session-team/) helps one person manage many sessions. This skill is for communication between people.

Talking to everyone is tiring, and a conversation can't carry the full context.

Say someone's agent did five things this week. Two are in the person's area; the person only asked for the other three. The person may not think to say that. The agent can, and a teammate who knows that area can then take a look.

## What it does

- **Commits:** the agent commits to its own branch in the team's repo and pushes it. The message only says what was done. Nobody needs to read commits before they're pushed, so secrets and things that shouldn't be shared stay out.
- **Topic issue:** only when something needs aligning or deciding, an issue is opened and each side sets out its approach there. It says what it did, with the repo and commit ID so that others can find the exact version. It also says how involved the person was (including "unknown", rather than claiming they looked), how far the work was verified and at which commit, what it is unsure of, and who it wants to ask. It states its approach without rebutting or persuading, and the person reads it before it is posted. People then decide in a meeting or one to one; the agent doesn't decide.
- **Digest:** when someone wants to know what others are doing, an agent reads those people's branches and related issues and tells whoever asked who did what, where approaches differ, what questions are open, and what it could not check. How far work was checked and how involved someone was are reported as unknown unless an issue says. It fits on one screen, ordered by what could change someone's decision; differences that wouldn't change one get only a count. It doesn't recommend answers.

The skill is one short instruction file, with no scripts or fixed format. The agent chooses the wording and uses the tools on the machine, so issues and digests will vary in form.

## Install and start

```bash
npx skills add jiahao-shao1/sjh-skills --skill team-digest
```

Then tell your agent, for example: "Commit this work to my branch in OWNER/REPO", "Open an issue in OWNER/REPO to align on this and set out my approach" or "What has NAME been working on in OWNER/REPO?" Use a private repository. Another shared place works if your agent can reach it.

## Testing status

This skill has not been used by a real team yet, and no topic issue or digest has been produced with it. Installing it through `npx skills add` is also untested.
