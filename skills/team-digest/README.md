# team-digest

English | [中文](README.zh-CN.md)

Help a small team stay aligned through its agents. Each agent reports what it did, and a digest brings the reports together. The agent states what happened; people decide.

## Why

[session-team](../session-team/) helps one person manage many sessions. This skill helps several people stay aligned.

On a small team people trust each other and are happy to share, but they rarely look at what the others did. Talking to everyone is tiring, and a conversation can't carry the full context.

Say someone's agent did five things this week. Two are in the person's area; the person only asked for the other three. The person may not think to say that. The agent can, and a teammate who knows that area can then take a look.

The skill assumes a cooperative team. It is not designed for performance monitoring.

## What it does

- **Report:** the agent says what it did, with the repo and commit ID so that others can find the exact version. It also says how involved the person was, how far the work was verified and at which commit, what it is unsure of, and who it wants to ask. The person reads the report before it is sent.
- **Digest:** an agent reads everyone's reports and tells the team who did what, what nobody has verified, who said they are waiting on whom, where accounts differ, what questions are open, and what it could not check. It doesn't recommend answers.

The skill is one short instruction file, with no scripts or fixed format. The agent chooses the wording and uses the tools on the machine, so reports will vary in form.

## Install and start

```bash
npx skills add jiahao-shao1/sjh-skills --skill team-digest
```

Then tell your agent, for example: "Write my team report to the issues of OWNER/REPO" or "Write this week's team digest from OWNER/REPO." Use a private repository for reports. Any other shared place works if your agent can reach it.

## Testing status

This skill has not been used by a real team yet, and no report or digest has been produced with it. Installing it through `npx skills add` is also untested.
