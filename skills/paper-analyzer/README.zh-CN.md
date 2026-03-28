# Paper Analyzer

[English](README.md) | 中文

> 论文深度批判分析 —— 因果链方法论（现象→实验设置→归因→解法），NotebookLM 溯源阅读，可选研究框架映射。

## 功能

- **结构化方法论** — 不是摘要，而是解剖论文的声明与证据
- **因果链分析** — 现象→实验设置→归因→解法，暴露论文展示内容和声称内容之间的逻辑断层
- **NotebookLM 溯源** — 每篇分析的论文都通过 NotebookLM 进行基于原文的问答（~500 tokens/次 vs ~50K/篇 PDF）
- **研究框架映射** — 可选步骤，将论文发现与你自己的假说关联
- **关键数字提取** — 每个指标的精确定义、分母、对比锚点

## 安装

```bash
npx skills add jiahao-shao1/sjh-skills --skill paper-analyzer
```

## 前置条件

- [notebooklm-py](https://github.com/teng-lin/notebooklm-py) 已安装（`pipx install "notebooklm-py[browser]"`）
- NotebookLM Google 登录已完成（`notebooklm login`）

## 使用

```
"分析这篇论文：2603.14821"
"论文深度分析"
"deep dive into this paper"
"这篇论文到底说明了什么"
```

## 工作原理

1. **获取论文** — 通过 arXiv HTML/摘要 URL 添加到 NotebookLM
2. **解构叙事** — 梳理作者的动机、核心声明、证据结构和已承认的局限性
3. **提取关键数字** — 每个核心指标的精确定义和数值，表格呈现
4. **因果链分析** — 核心输出：
   - **现象** — 他们观察到了什么？有什么反直觉的？
   - **实验设置** — 他们如何观察到的？
   - **归因** — 他们认为为什么会这样？
   - **解法** — 他们提出了什么方案，是否真的解决了归因的原因？
5. **框架映射**（可选） — 通过 `references/hypothesis.md` 将发现与你的研究假说关联
6. **跨论文关联**（可选） — 结构类比、互补证据、矛盾

## 配置

### 研究框架（可选）

在 `references/hypothesis.md` 中定义你的研究假说或理论框架。存在时，分析会将论文证据映射到你的框架，并进行"反向挑战"——询问论文的解法是否无意中证明了你的假说。

## 何时用 vs. Scholar Agent

| 任务 | 使用 |
|------|------|
| 发现和筛选今天的论文 | scholar-agent |
| 深度批判分析一篇特定论文 | paper-analyzer |
| 将论文添加到 NotebookLM 问答 | scholar-agent |
| 评估论文与你的假说的关系 | paper-analyzer |

## 许可证

MIT
