---
name: team-digest
description: Help a team communicate through its agents. Each agent commits detailed work to its own branch and posts reports as issues, including how involved its person was, how far the work was verified and what it is unsure of; a digest brings the reports together for people to decide on. Use for 'team digest', 'write my team report', 'what did the team do this week', 'who is waiting on whom', 'what has nobody verified', '团队摘要', '写团队记录', '大家这周做了什么', '谁在等谁', '哪些事没人验证', '和队友对齐'. Not for coordinating one person's sessions (session-team), a personal daily summary (daily-summary) or performance review.
---

# Team Digest

This skill is for communication within a team. Talking to everyone costs too much, and a conversation can't carry the full context. Agents can share what they did, including things their person wouldn't think to mention: an agent may have done five things this week, and its person only knows the area of two of them.

The agent states what happened; people decide. Describe how far work was checked, not how good anyone is.

## Report

Commit often to your own branch in the team's repo, with messages detailed enough that a teammate can follow what happened and why. No one needs to read these before they're pushed, so keep secrets and things that shouldn't be shared out of them.

From time to time, post a report as an issue so the team can align and discuss. A teammate reading it should be able to tell:

- what was done, pinned to the exact version: repo and commit ID, plus the PR if there is one. PRs and branches move; a commit lets someone find exactly what you did. If the work isn't committed or pushed, say so. If a report spans several lines of work, list each line's commits. Readers may not have access to every repo, so name the repo and make the text make sense without opening the link.
- how involved the person was: wrote it, read the diff, only asked for it, or unknown. If you can't tell, say unknown; don't claim they looked at something.
- how far it was verified, how, and at which commit
- what you're unsure of, especially what they may not raise themselves
- who you'd like to ask about what

Show the person before sending. They can add to it, but keep what you were unsure of unless they have a reason to remove it. Check that nothing is going somewhere it shouldn't: warn them if the location is public.

## Digest

Read everyone's reports and check them against the links, their branches and recent activity. Then tell the team, plainly and within one screen, ordered by what could change someone's decision. Differences that wouldn't change a decision get only a count.

Cover:

- who did what, with links to the commits
- what nobody has verified
- who said they are waiting on whom
- where two accounts differ, side by side
- what questions are waiting for someone
- what you could not check

Don't recommend answers or judge who is right. Those calls are for people. Send it the way the team usually communicates.
