# 每日总结 Skill

[English](README.md) | 中文

> Claude Code 技能：聚合 Claude Code 会话、Git commits、Notion Tasks，生成时间线式每日工作总结。

## 功能

- **多源聚合** — 从 Claude Code 会话历史、Git 日志、Notion 任务收集数据
- **时间线格式** — 按时间段分组的工作总结
- **灵活日期** — 今天、昨天、过去 24 小时、或指定日期
- **自动数据采集** — Shell 脚本完成所有数据收集

## 安装

```bash
# 添加到 Claude Code skills
cp -r daily-summary ~/.claude/skills/
```

或通过 [dotfiles + stow](https://github.com/jiahao-shao1/dotfiles) 管理：

```bash
git submodule add <repo-url> agents/.agents/skills/daily-summary
```

## 使用

```
/daily-summary              # 今天（默认）
/daily-summary yesterday    # 昨天
/daily-summary 24h          # 过去24小时
/daily-summary 2026-03-20   # 指定日期
```

或对话触发：

```
"今天干了什么"
"每日总结"
"日报"
"summarize my day"
```

## 工作原理

1. 解析日期参数（默认今天）
2. 运行 `scripts/collect-daily-data.sh` 收集：
   - Claude Code 会话日志
   - 各仓库 Git commits
   - Notion 任务完成情况
3. 生成结构化的中文时间线总结

## 许可证

MIT
