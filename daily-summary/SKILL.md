---
name: daily-summary
description: >
  每日工作总结。聚合 Claude Code sessions、Git commits、Notion Tasks，
  生成中文时间线式工作总结。
  触发词：'daily summary', '今天干了什么', '每日总结', '日报',
  'what did I do', 'summarize my day', '总结一下今天'.
  参数：today (默认), yesterday, 24h, YYYY-MM-DD。
---

# Daily Summary

## 使用方式

用户通过 `/daily-summary` 或对话触发。参数来自 ARGUMENTS 行。

```
/daily-summary              → 今天
/daily-summary yesterday    → 昨天
/daily-summary 24h          → 过去24小时
/daily-summary 2026-03-20   → 指定日期
```

## 执行步骤

1. 从 ARGUMENTS 解析日期参数，默认 `today`
2. 运行数据收集脚本：

```bash
bash <skill-base-dir>/scripts/collect-daily-data.sh --date <参数>
```

其中 `<skill-base-dir>` 是本 SKILL.md 所在目录（在 skill 加载时已知，即 "Base directory for this skill" 提示中的路径）。

3. 将脚本的 stdout 完整读取
4. 基于收集到的数据，生成中文总结

## 总结要求

### 输出格式

```
## YYYY-MM-DD 工作总结

### 时间线
- **HH:MM-HH:MM** [项目名] 做了什么（1句话概括）
- **HH:MM-HH:MM** [项目名] 做了什么
...

### 关键产出
- 具体产出1（如：新增了 XX 功能、修复了 XX bug）
- 具体产出2
...

### 任务完成情况
- 已完成 N 项
- 未完成 N 项（列出具体任务名）

### 计划外产出
（Git/Session 中有但 Notion Task 里没有 track 的工作，如果有的话列出）
```

### 注意事项
- 从用户消息推断做了什么，不要原样复制用户消息
- 合并同一主题的多条消息为一个条目
- 时间线按时间顺序排列
- 语言：中文
- 不要使用 emoji
