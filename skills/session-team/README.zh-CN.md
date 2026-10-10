# session-team

[English](README.md) | 中文

在一台常开的机器上，让多个 Claude Code session 分工协作。**leader** 负责和你对话、统筹安排；**worker** 承担耗时长的活（训练、配环境、评测、排查），通过 `SendMessage` 向 leader 回报。

## 为什么要这样做

用 Claude Code 做研究，同时推进的事情一多，就会碰到两个问题：

- **所有事都在一个 session 里做，会被卡住。** 和你讨论 idea 的 session 同时还在配环境、盯训练，讨论就得等这些跑完，它的 context 也会被日志填满。
- **一个任务开一个 session，你就成了中转站。** 你得在各个 session 之间来回切，每次都要重读一遍才想起进度，自己的思路也会被打断。

分成 leader 和 worker 之后，这两个问题都解决了：

1. **leader 不会被长任务卡住。** 训练、配环境、排查都在 worker 里跑，跑的同时你可以一直和 leader 讨论 idea。
2. **你自己的上下文不会丢。** 你只跟一个 session 说话。worker 的进度由 leader 跟踪，以哪个结论为准写在仓库里的团队文档中。

这件事现在可行，是因为现在的模型拿到一份写好的启动说明，就能独立把一部分工作推进几个小时：写判据、跑实验、排查、回报，都不用人一步步带。leader 只需要负责协调。

一个 session 就能做完的任务，或者很短的查询，不值得这样做，用 subagent 就够了。

## 安装

```bash
npx skills add jiahao-shao1/sjh-skills --skill session-team
```

只需要在 leader 所在的机器上安装。worker 不用装，它们要遵守的规矩都写在启动说明里。

## 准备（每台机器一次）

1. 准备一台常开的机器（dev box 或工作站），装好 Claude Code。我们测试的版本是 2.1.283。
2. 在团队要用的仓库目录下，用 tmux 起 Remote Control：

   ```bash
   tmux new -s rc
   cd ~/code/my-project && claude remote-control   # 简写 claude rc
   ```

   常用参数：
   - `--permission-mode <mode>`：设置新开 session 的权限模式。
   - `--spawn worktree`：让每个新 session 自带一个 git worktree。我们没试过，一直用默认的 `same-dir`，由 worker 自己建 worktree。
3. 在 claude.ai/code 或 Claude app 里选这台机器的环境，新开一个会话，改名为 `leader`。每个会话都是这台机器上的本地进程，合上笔记本也会继续跑。
4. 让 leader「列出其他 session」（`ListAgents`），确认能看到彼此。

不用 Remote Control、直接在同一台机器的 tmux 里起 `claude`，各 session 之间也能互发消息。但这样就不能用手机操作，leader 也可能没有 `create_session`（开 worker）和 `send_later`（定时检查）这两个工具，它们是 Remote Control session 带的。

## 用法

告诉 leader 要做什么，并说明要分给团队来做。例如：「你当 leader，把这件事拆成数据和评测两部分，各交给一个 worker。」

leader 接下来会：

1. 先和你确认怎么拆；
2. 在仓库里写团队文档，包括分工、规矩、资源分配、进度看板和每部分的判据（[模板](references/team-doc-template.md)）；
3. 为每部分写一份自包含的启动说明（[模板](references/kickoff-template.md)），自己开 worker，或者交给你粘贴进新会话。leader 开的 worker 会出现在你的会话列表里，你也可以直接和它对话；
4. 定时回来检查、更新看板，只把结果、卡点和需要你拍板的事带给你。

## 原理

```
你（手机 / 笔记本）──Remote Control──► 机器上的 claude remote-control
                                          │ 在本机开 session：leader、worker-a、worker-b …
                                          │
   ListAgents  ── 读本机的 session 登记表（~/.claude/sessions/*.json）
   SendMessage ── 写到对方的本地 socket，对方收到一条 <cross-session-message>
   create_session(environment_id=<bridge 环境>) ── leader 在同一台机器上开 worker
   send_later  ── leader 给自己排定时检查（进程重启后仍会送达）
   团队文档 + git ── 大家共同读写的状态
```

## 实战经验

skill 里的规则来自一个科研项目约一周的实际运行：一个 leader 带四个 worker，累计约 2,200 条消息、220 次定时检查，跑过几个通宵。

- **真正起作用的是协作约定，而不是消息机制本身。** 判据在运行前写好，共享脚本只有一个负责人，资源明确分配到人，进度有看板。少了这些，交出去的活很容易跑偏。
- **leader 会不知不觉亲自动手。** 它每天自己跑几百条集群命令，context 大约每天压缩一次。所以 skill 要求它把排查交给负责的 worker。
- **没分配清楚的共享资源一定会撞。** 有一批任务失败，原因是 leader 分配的端口起始值超过了 65535。现在端口、GPU 和队列都写进团队文档和启动说明。
