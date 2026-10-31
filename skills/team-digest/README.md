# team-digest

English | [中文](README.zh-CN.md)

Help a team communicate through its agents. Each agent commits detailed work to its own branch and posts reports as issues, and a digest brings the reports together. The agent states what happened; people decide.

## Why

[session-team](../session-team/) helps one person manage many sessions. This skill is for communication between people.

Talking to everyone is tiring, and a conversation can't carry the full context.

Say someone's agent did five things this week. Two are in the person's area; the person only asked for the other three. The person may not think to say that. The agent can, and a teammate who knows that area can then take a look.

## What it does

- **Commits:** the agent commits often to its own branch in the team's repo, with detailed messages. Nobody needs to read them before they're pushed, so secrets and things that shouldn't be shared stay out.
- **Report:** from time to time, the agent posts an issue so the team can align and discuss. It says what it did, with the repo and commit ID so that others can find the exact version. It also says how involved the person was, how far the work was verified and at which commit, what it is unsure of, and who it wants to ask. The person reads the report before it is posted.
- **Digest:** an agent reads everyone's reports, checks them against their branches, and tells the team who did what, what nobody has verified, who said they are waiting on whom, where accounts differ, what questions are open, and what it could not check. It doesn't recommend answers.

The skill is one short instruction file, with no scripts or fixed format. The agent chooses the wording and uses the tools on the machine, so reports will vary in form.

## Install and start

```bash
npx skills add jiahao-shao1/sjh-skills --skill team-digest
```

Then tell your agent, for example: "Commit this work to my branch in OWNER/REPO", "Post my team report to the issues of OWNER/REPO" or "Write this week's team digest from OWNER/REPO." Use a private repository. Another shared place works if your agent can reach it.

## Testing status

This skill has not been used by a real team yet, and no report or digest has been produced with it. Installing it through `npx skills add` is also untested.
