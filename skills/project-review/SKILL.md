---
name: project-review
description: "项目战略全景审视 — 自动发现并读取战略文档（vision、roadmap、决策记录、会议纪要等），生成五维分析快照。当用户想审视项目方向、检查战略对齐、回顾里程碑进度、或在组会前快速了解项目全貌时使用。触发词包括：project review、项目全景、审视战略、战略 review、项目现在什么状态、review 一下方向。注意：不要被代码 review、PR review、code review 触发 — 那些是代码层面的，本 skill 是战略层面的。"
---

# Project Review

读取项目战略文档体系，生成项目全景快照。适合在组会前、方向迷茫时、或阶段性回顾时使用，帮助快速理解项目当前在哪、该往哪走。

## 执行骨架

### Phase 1: 加载文档清单

先检查项目是否有显式配置：读取 `docs/strategy/.review-sources.md`。

如果存在，按其中列出的路径逐一读取 — 项目维护者已指定了哪些文档构成"战略全貌"，不需要猜测。

如果不存在，进入 Phase 1b 自动发现。

#### 项目配置格式（`docs/strategy/.review-sources.md`）

```markdown
# Project Review Sources

## Core
- docs/strategy/vision.md
- docs/strategy/roadmap.md
- docs/strategy/paper-outline.md

## Decisions
- docs/strategy/decisions/log.md

## Related Work
- docs/strategy/related-work/_index.md

## Meetings (latest 2)
- docs/strategy/meetings/

## Experiments
- .claude/knowledge/experiments.md

## Progress
- HANDOFF.md
```

每个条目是相对于项目根目录的路径。目录路径（以 `/` 结尾）表示读取该目录下最近修改的 2 个文件。`#` 开头的行是 section 标题，用于分组。

### Phase 1b: 自动发现（无配置时的 fallback）

在以下路径中搜索，排除 `third_party/`、`node_modules/`、`.venv/`、`vendor/`：

| 文档类型 | 搜索路径（按优先级） | 说明 |
|----------|---------|------|
| Vision | `docs/strategy/vision.md` → `docs/vision.md` → `VISION.md` | 项目定位和核心假设 |
| Roadmap | `docs/strategy/roadmap.md` → `docs/roadmap.md` → `ROADMAP.md` | 路线图 / 里程碑 |
| Paper Outline | `docs/strategy/paper-outline.md` | 论文大纲（研究项目） |
| Related Work | `docs/strategy/related-work/` 下的 `_index.md` 或所有 `.md` | related work |
| Decisions | `docs/strategy/decisions/log.md` → `docs/strategy/decisions/` → `docs/adr/` | 决策记录 |
| Meetings | `docs/strategy/meetings/` 下最近 2 个 `.md`（排除 `_template.md`） | 会议记录 |
| Experiments | `.claude/knowledge/experiments.md` | 实验记录 |
| Progress | `HANDOFF.md`（项目根目录） | 当前进度 |

使用精确路径逐级 fallback，不使用 `**/` 递归 glob — 递归搜索容易匹配到 `third_party/` 下的同名文件，产生噪音。

如果以上路径都不存在，提示用户：
> "未找到战略文档。建议创建 `docs/strategy/.review-sources.md` 指定文档位置，或在 `docs/strategy/` 下创建 `vision.md` 和 `roadmap.md`。"

### Phase 2: 五维分析

根据找到的文档生成分析。每个维度只在有对应文档时输出 — 没有数据支撑的维度直接跳过，因为猜测比沉默更危险。

**1. Vision Check**
- 当前工作是否对齐核心目标 / 假设
- 哪些假设已验证、哪些受质疑、哪些未测试
- 如果没有 vision 文档，基于 README 推断项目目标（标注为推断）

**2. Roadmap Status**
- 进度总览（done / in-progress / planned）
- 当前阶段在整体路线图中的位置
- 是否有偏离计划的工作

**3. 瓶颈识别**
- 从实验结果和决策记录中提取当前阻塞点
- 区分技术瓶颈（如 API 不稳定）和研究/业务瓶颈（如假设不成立）

**4. Related Work Gap**（研究项目）
- 哪些主题缺少 related work 覆盖
- 是否有新发表的相关工作需要关注

**5. 下一步建议**
- 基于以上分析，推荐接下来做什么
- 优先级排序：紧急 vs 重要

### Phase 3: 输出

```
========================================
        PROJECT REVIEW SNAPSHOT
        <project-name> | YYYY-MM-DD
========================================

## 1. Vision Check
...

## 2. Roadmap Status
| ID | 里程碑 | 状态 | 备注 |
...

## 3. 瓶颈识别
...

## 4. Related Work Gap
...

## 5. 下一步建议
1. ...
2. ...
3. ...

========================================
```

### 首次使用引导

如果是通过 Phase 1b 自动发现（而非配置文件）找到的文档，在输出末尾附上推荐配置，方便用户一键创建 `.review-sources.md`：

```
Tip: 创建 docs/strategy/.review-sources.md 可以精确指定文档位置，
避免误匹配。推荐配置：

<根据实际发现的文件生成配置内容>
```

## 约束

- **只读** — 不修改任何文档。这个 skill 的价值是提供视角，不是代替人做决策。
- **输出到终端** — 不生成文件，除非用户明确要求保存。避免产生"文档写文档"的噪音。
- 全部使用中文
- 缺少某个维度的文档时跳过，不要编造 — 空白比错误的信心更有价值
- 不替代 weekly-report（面向汇报）或 meeting-slides（面向展示）— 本 skill 面向个人/团队的战略反思
