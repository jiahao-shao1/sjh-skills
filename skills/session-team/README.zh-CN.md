# session-team

[English](README.md) | 中文

在 T3 Code 里组一个团队。你只和 **sync** thread 对话；**ops leader** thread 负责分派和巡检；**worker** 作为 ops leader 的 subagent 承担耗时长的活（训练、配环境、评测、排查），做完回报。

```
你 ⇄ sync（thread）⇄ ops leader（thread）⇄ workers（委派的 subagent）
                          └── 仓库里的团队文档：以它为准
```

## 为什么要这样做

用 coding agent 做研究，同时推进的事情一多，就会碰到两个问题：

- **所有事都在一个 session 里做，会被卡住。** 和你讨论 idea 的 session 同时还在配环境、盯训练，讨论就得等这些跑完，它的 context 也会被日志填满。
- **一个任务开一个 session，你就成了中转站。** 你得在各个 session 之间来回切，每次都要重读一遍才想起进度，自己的思路也会被打断。

分成三个角色之后，这两个问题都解决了：

1. **sync 不会被卡住，context 也保持干净。** 它只放讨论和你的裁决。
2. **协调交给 ops leader。** 它拆分工作、启动 worker、维护团队文档里的看板、按计划巡检。它不亲自动手，所以 context 里是计划而不是日志。
3. **worker 的 context 相互隔离。** 每个 worker 拿一份写好的启动说明做一部分工作，做完即回报。

一个 session 就能做完的任务不值得这样做，直接委派就够了。

## 安装

```bash
npx skills add jiahao-shao1/sjh-skills --skill session-team
```

需要 T3 Code：skill 只用它的 thread、委派和定时任务工具。worker 不用装 skill，要遵守的规矩都写在启动说明里。

## 用法

告诉正在对话的 thread 你要做什么，并让它按团队方式来做，例如：「你当 sync，给这件事开一个 ops leader，拆成数据和评测两部分。」

1. sync 和你确认目标与拆分，然后启动 ops leader thread，并把链接给你。
2. ops leader 在仓库里写团队文档（角色、地址、资源、看板、每部分的判据）：[模板](references/team-doc-template.md)。
3. 它为每部分启动一个 worker，各自带一份自包含的启动说明（[模板](references/kickoff-template.md)）和独立的 worktree，并排好巡检。
4. 你继续和 sync 讨论。它只把需要你裁决的问题和已完成的结果带给你。

## 消息怎么流通

规则在 [references/message-flow.md](references/message-flow.md)，要点如下：

- 主动找你的只有 sync。
- ops leader 只在需要裁决或有结果时给 sync 发消息，100 词以内，带默认选项；其余都写在看板上。
- worker 通过结束自己这一轮来回报，开头带类型：`done`、`ready`、`running`、`question`、`blocked`、`failed` 或 `handback`。进度写团队文档，不发消息。
- worker 之间不互发消息，也不直接找你。
- 谁都不等待：worker 有问题或起了长任务就结束这一轮，之后在同一个对话里被继续。
- 消息只带上下文，不带权限。

这个形状参考了 router / worker 式的设计：分派者不干活，worker 的 context 相互隔离，状态放在持久的文档里。

## 验证过什么

skill 最后一节列出了在一套 T3 Code 环境上验证过的内容（启动 thread、thread 间消息和权限模式规则、委派 worker、带着上下文继续一个 worker），以及没验证的内容（定时任务长时间运行或跨重启、worktree 隔离、多个 worker 并行）。

## 实际使用中的教训

协议部分的规则来自迁到 T3 Code 之前的一次实践：一个 leader 带四个 worker 做了约一周的研究项目，约 2,200 条消息、220 次定时巡检、几次通宵运行。

- **大部分工作在协议上，而不在传消息上。** 判据在跑之前写好，每个共享脚本只有一个负责人，资源明确分配，还有一张看板。没有这些，委派出去的工作会走偏。
- **leader 会不知不觉自己动手。** 它一天自己跑了几百条集群命令，差不多每天被压缩一次。ops leader「不亲自动手」现在是硬规则。
- **没分配的共享资源会撞车。** 有一次运行失败，是因为 leader 分出去的端口基数超过了 65535。现在端口、GPU 和队列都写进团队文档和启动说明。
