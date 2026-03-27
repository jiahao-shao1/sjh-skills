# Init Project

[English](README.md) | 中文

> 为新项目一键配置 Claude Code 最佳实践：目录骨架、Agent、Hooks 和 CLAUDE.md。

## 快速开始

```bash
npx skills add jiahao-shao1/sjh-skills --skill init-project
```

然后在任意项目中，对 Claude Code 说：

```
初始化项目
```

或

```
init project
```

Claude Code 会自动触发该 skill，引导你完成配置。

## 概述

该 Skill 自动化配置新项目的 Claude Code 最佳实践，生成完整的配置骨架，并通过交互式工作流填充项目特定信息。

## 工作流程

### Phase 1: 生成骨架

运行 `scripts/init-skeleton.sh`，创建目录结构和样板文件：

| 路径 | 用途 |
|------|------|
| `.claude/rules/` | 硬性规则（经验多次验证后提炼） |
| `.claude/knowledge/` | 热经验沉淀（调试发现、workaround） |
| `.claude/hooks/` | PostToolUse 等自动化钩子 |
| `.claude/agents/` | Agent 定义（领域专家、质量检查） |
| `.claude/worktrees/` | Worktree 追踪 |
| `.agents/skills/` | 项目级 Skill 定义 |

生成的文件：

| 文件 | 说明 |
|------|------|
| `.claude/hooks/auto-format-python.sh` | 编辑 `.py` 后自动 `ruff format` + `ruff check --fix` |
| `.claude/agents/code-verifier.md` | 提交前质量关卡 — ruff lint/format + pytest |
| `.claude/agents/planner.md` | 代码库研究，用于 brainstorming/planning 阶段 |
| `.claude/settings.json` | PostToolUse hook 注册 |
| `CLAUDE.md` | 项目说明骨架（含占位符待填充） |

### Phase 2: 交互式填充 CLAUDE.md

逐个处理 `<!-- init-project: placeholder -->` 占位符：

```
读代码库（自动） → 生成草稿（自动） → AskUserQuestion 确认 → 写入 CLAUDE.md
```

| Section | 自动探索 | 问用户什么 |
|---------|---------|-----------|
| 项目概述 | README、pyproject.toml、package.json | "一句话描述这个项目的核心目标？" |
| 目录结构和功能 | ls + 读关键文件 docstring | "以下目录结构对吗？有遗漏要调整的吗？" |
| 开发工作流 | 检测 CI、Makefile、scripts/ | "用默认的 brainstorming→plans→dev→verify 流程？" |
| 开发指南 | 检测 venv、.env、Dockerfile | "环境配置有什么特殊步骤？" |
| Always Do（项目特定） | 读已有 rules/、lint 配置 | "有哪些跨模块一致性要求？" |
| Ask First | 扫描核心文件（接口、配置） | "哪些文件/目录修改前必须先确认？" |
| Never Do | 检测 third_party/、.env | "有哪些绝对不能碰的约定？" |
| 渐进式参考 | 扫描 docs/、skills、agents | "还有需要补充的任务→参考文件映射吗？" |

用户可回复 **"skip"** 跳过任意 section，保留占位符。

### Phase 3: Profile 叠加（可选）

在基础骨架之上叠加特定项目类型的额外结构。

**当前支持：** `research`

Research profile 额外添加：
- `docs/reports/weekly/`、`docs/reports/worktree/`、`docs/plans/` 目录
- `.claude/knowledge/experiments.md` — 实验注册表（日期、配置、三级路径、结果）
- `.claude/agents/domain-expert.md` — 领域专家 Agent 骨架
- CLAUDE.md 追加研究相关 section

新 profile 通过 `scripts/init-<profile>-profile.sh` + `details/<profile>-profile.md` 添加。

### Phase 4: 输出摘要

列出所有生成/修改的文件，提示下一步：检查内容、`git add`、开始开发。

## Agents

骨架内含两个通用 Agent：

### code-verifier (haiku)

提交前质量检查。识别变更的 `.py` 文件，运行 `ruff check --fix` + `ruff format`，然后 `pytest`。以结构化表格报告结果，**不会**自行修复测试失败。

### planner (opus)

只读的代码库研究工具，服务于 `/brainstorming` 和 `/writing-plans` 工作流。系统性搜索代码，输出结构化发现（相关文件、现有模式、建议、风险点）。

## 约束

- **幂等** — 已存在的文件不覆盖，只补缺
- **不自动 git add/commit** — 由用户决定
- **不修改已有内容** — 只填充 `<!-- init-project: placeholder -->` 占位符
- **脚本可独立运行** — `init-skeleton.sh` 和 `init-research-profile.sh` 可脱离 Skill 单独执行

## 文件结构

```
init-project/
├── SKILL.md                              # Skill 定义
├── README.md                             # English docs
├── README.zh-CN.md                       # 中文文档（本文件）
├── scripts/
│   ├── init-skeleton.sh                  # Phase 1: 骨架生成
│   └── init-research-profile.sh          # Phase 3: Research profile 叠加
└── details/
    ├── skeleton-manifest.md              # 完整文件清单
    ├── claude-md-sections.md             # CLAUDE.md 各 section 填充引导
    ├── agent-templates.md                # Agent 模板说明
    └── research-profile.md              # Research profile 说明
```
