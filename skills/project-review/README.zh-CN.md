# Project Review

[English](README.md) | 中文

> 项目战略全景审视 —— 自动发现战略文档，生成五维分析快照（vision、roadmap、瓶颈、related work 缺口、下一步）。

## 功能

- **自动发现** — 通过 `docs/strategy/.review-sources.md` 配置或智能回退搜索找到战略文档
- **五维分析** — 愿景检查、路线图进度、瓶颈识别、related work 缺口、下一步行动
- **只读** — 只提供视角，不修改任何文档
- **首次引导** — 从已发现的文件生成推荐配置

## 安装

```bash
npx skills add jiahao-shao1/sjh-skills --skill project-review
```

## 使用

```
/project-review
```

或通过对话触发：

```
"审视一下项目战略"
"项目现在什么状态"
"project review"
"where is the project at?"
```

## 工作原理

1. **加载文档** — 读取 `docs/strategy/.review-sources.md` 获取指定路径，或从标准位置自动发现（`docs/strategy/`、`HANDOFF.md`、`.claude/knowledge/experiments.md`）
2. **五维分析** — 对有支撑文档的维度生成洞察（跳过无数据的维度）
3. **输出快照** — 在终端渲染结构化报告

## 配置

在项目中创建 `docs/strategy/.review-sources.md` 来指定要包含的文档：

```markdown
# Project Review Sources

## Core
- docs/strategy/vision.md
- docs/strategy/roadmap.md

## Decisions
- docs/strategy/decisions/log.md

## Meetings (latest 2)
- docs/strategy/meetings/
```

目录路径（以 `/` 结尾）会读取最近修改的 2 个文件。

## 许可证

MIT
