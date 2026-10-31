---
name: team-digest
description: Help a team communicate through its agents, without progress reports. Each agent commits what it did to its own branch; when something needs aligning or deciding, each side sets out its approach in a topic issue; when someone wants to know what others are doing, an agent reads their branches and related issues and explains it in one screen. People decide. Use for 'team digest', 'what is X working on', 'what did the team do this week', 'who is waiting on whom', 'open an issue to align', 'set out my approach', '团队摘要', '某人在干什么', '大家这周做了什么', '谁在等谁', '开个 issue 对齐', '摆一下我的做法', '和队友对齐'. Not for coordinating one person's sessions (session-team), a personal daily summary (daily-summary) or performance review.
---

# Team Digest

This skill is for communication within a team. Talking to everyone costs too much, and a conversation can't carry the full context. Agents can share what they did, including things their person wouldn't think to mention: an agent may have done five things this week, and its person only knows the area of two of them.

Nobody writes periodic progress reports. The agent states what happened; people decide. Describe how far work was checked, not how good anyone is.

## Commit

Commit to your own branch in the team's repo and push it, so others can read it. The message says what was done; it doesn't need to cover involvement, verification or doubts. No one needs to read commits before they're pushed, so keep secrets and things that shouldn't be shared out of them.

## Align

Only when something needs aligning or deciding, open an issue on that topic, or join the one that exists. Each side sets out its own approach there. A teammate reading it should be able to tell:

- what was done, pinned to the exact version: repo and commit ID, plus the PR if there is one. PRs and branches move; a commit lets someone find exactly what you did. If the work isn't committed or pushed, say so. Readers may not have access to every repo, so name the repo and make the text make sense without opening the link.
- how involved the person was: wrote it, read the diff, only asked for it, or unknown. If you can't tell, say unknown; don't claim they looked at something.
- how far it was verified, how, and at which commit
- what you're unsure of, especially what they may not raise themselves
- who you'd like to ask about what

State your approach only. Don't rebut or try to persuade anyone. After that, people decide in a meeting or one to one; the agent doesn't decide.

Show the person before posting. They can add to it, but keep what you were unsure of unless they have a reason to remove it. Check that nothing is going somewhere it shouldn't: warn them if the location is public.

## Digest

Only when someone asks what others are doing, read those people's branches and the related issues. Then tell whoever asked, plainly and within one screen, ordered by what could change someone's decision. Differences that wouldn't change a decision get only a count.

Cover:

- who did what, with links to the commits
- where approaches differ, side by side
- what questions are waiting for someone
- what you could not check

Commit messages don't say how far work was checked or how involved someone was. Unless an issue says, report that as unknown; don't infer it.

Don't recommend answers or judge who is right. Those calls are for people.
