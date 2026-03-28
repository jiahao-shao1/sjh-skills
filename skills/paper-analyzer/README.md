# Paper Analyzer

English | [中文](README.zh-CN.md)

> Deep critical analysis of academic papers — causal chain methodology (phenomenon, setup, attribution, solution), NotebookLM-grounded reading, optional research framework mapping.

## Features

- **Structured methodology** — Not summarization, but dissecting claims vs. evidence
- **Causal chain analysis** — 现象→实验设置→归因→解法, exposing logical gaps between what a paper shows and what it claims
- **NotebookLM-grounded** — Every paper analyzed goes through NotebookLM for source-grounded Q&A (~500 tokens/query vs ~50K/PDF)
- **Research framework mapping** — Optional step connecting paper findings to your own hypothesis
- **Key number extraction** — Precise definitions, denominators, and comparison anchors for every metric

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill paper-analyzer
```

## Prerequisites

- [notebooklm-py](https://github.com/teng-lin/notebooklm-py) installed (`pipx install "notebooklm-py[browser]"`)
- NotebookLM Google login completed (`notebooklm login`)

## Usage

```
"analyze this paper: 2603.14821"
"deep dive into this paper"
"分析这篇论文"
"what does this paper really show?"
```

## How It Works

1. **Obtain paper** — Add to NotebookLM via arXiv HTML/abstract URL
2. **Deconstruct narrative** — Map the authors' motivation, core claim, evidence structure, and acknowledged limitations
3. **Extract key numbers** — Precise definitions and values for every core metric, formatted as tables
4. **Causal chain analysis** — The core output:
   - **现象** (Phenomenon) — What did they observe? What's surprising?
   - **实验设置** (Setup) — How did they observe it?
   - **归因** (Attribution) — Why do they think this happens?
   - **解法** (Solution) — What do they propose, and does it address the attributed cause?
5. **Framework mapping** (optional) — Connect findings to your research hypothesis via `references/hypothesis.md`
6. **Cross-paper connections** (optional) — Structural analogues, complementary evidence, contradictions

## Configuration

### Research Framework (Optional)

Define your research hypothesis or theoretical lens in `references/hypothesis.md`. When present, Step 5 maps each paper's evidence to your framework and applies a "reverse challenge" — asking whether the paper's fix inadvertently proves your claims.

## When to Use vs. Scholar Agent

| Task | Use |
|------|-----|
| Discover and filter today's papers | scholar-agent |
| Deep-read a specific paper critically | paper-analyzer |
| Add papers to NotebookLM for Q&A | scholar-agent |
| Evaluate a paper against your hypothesis | paper-analyzer |

## License

MIT
