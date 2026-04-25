---
name: paper-analyzer
description: "Deep critical analysis of one specific paper — dissect experimental setup, extract numbers, evaluate claims against a hypothesis. Triggers: 'analyze this paper', 'deep dive into', '分析这篇论文', '论文深度分析', 'what does this paper really show', '这篇论文说明了什么', arXiv ID with analysis intent. Not for paper discovery (use scholar-agent), quick summaries, or literature surveys."
---

# Paper Analyzer

A structured methodology for critical paper analysis. The goal is not summarization — it's understanding what a paper actually demonstrates (which may differ from what it claims), extracting the numbers that matter, and connecting findings to your research framework.

## When to Use

- User gives an arXiv ID, URL, or paper title and wants deep analysis
- User is building a related work section and needs to understand a specific paper's contribution
- User wants to evaluate whether a paper supports or challenges their hypothesis

## Workflow

### Step 1: Obtain the Paper and Set Up NotebookLM

The primary reading channel is **NotebookLM** — it provides source-grounded answers from Gemini, handles tables/figures reliably, and supports iterative deep questioning. Every paper analyzed should end up in NotebookLM.

**If the user specifies a notebook ID** (e.g., "in notebook 9ef789c8"):
```bash
notebooklm use <notebook-id>
notebooklm source list  # check if the paper is already a source
```

**If the paper is not yet in NotebookLM**, add it:
```bash
# Prefer arXiv HTML — it preserves equations, tables, and structure
notebooklm source add "https://arxiv.org/html/<ID>"
# If HTML unavailable, fall back to abstract page
notebooklm source add "https://arxiv.org/abs/<ID>"
```

If no notebook exists for this line of research, create one:
```bash
notebooklm create "Research Topic Name"
notebooklm source add "https://arxiv.org/html/<ID>"
```

**Supplementary sources** (only when NotebookLM is insufficient):
- Semantic Scholar API — for citation count, related papers, and metadata:
  `https://api.semanticscholar.org/graph/v1/paper/ArXiv:<ID>?fields=title,abstract,year,citationCount,authors`
- `/web-fetcher` on arXiv HTML — fallback if NotebookLM source processing fails
- Direct PDF via Read tool — if the user provides a local path

**How to use NotebookLM during analysis**: Use `notebooklm ask` throughout all steps — for understanding the paper's narrative (Step 2), extracting numbers (Step 3), and verifying claims. Example questions:

- Step 2: "What problem does this paper claim to solve, and what is their core hypothesis?"
- Step 2: "Walk me through their evidence structure — what experiments support their main claim?"
- Step 3: "What exact numbers does Table 3 show? Include all conditions and metrics."
- Step 3: "How is [metric name] defined? What's the denominator?"
- Step 4: "Does Section 4.2 actually control for X when making claim Y?"
- Step 4: "Is the model checkpoint in Table 3 the same as in Table 5?"

### Step 2: Deconstruct the Paper's Own Narrative

Before applying any external framework, respect the authors' story. Map out:

1. **Motivation**: What problem do they claim to solve? What gap do they identify?
2. **Core claim/hypothesis**: What's their main argument? (State it in one sentence)
3. **Evidence structure**: How do they support the claim? (Experiments, ablations, theoretical analysis)
4. **Proposed solution**: If they propose a method, what's the key mechanism?
5. **Validation**: How do they measure success? What baselines do they compare against?
6. **Limitations they acknowledge**: What do they say doesn't work or isn't covered?

This step matters because jumping straight to criticism without understanding the paper on its own terms leads to shallow analysis. The interesting insights come from the gap between what a paper shows and what it claims to show — and you can only see that gap if you first understand the claims.

### Step 3: Extract Key Numbers and Definitions

For every core metric the paper introduces or relies on:
- **Name**: The metric/concept name
- **Definition**: Precise definition including what the numerator and denominator are, how it's measured, and by whom (human? LLM judge? automatic?)
- **Key values**: The actual numbers, with enough context (which model, which benchmark, which condition) to interpret them
- **Comparison anchor**: How these numbers relate to prior work

Format as a table when there are multiple conditions:

```markdown
| Condition | Metric A | Metric B | Notes |
|-----------|----------|----------|-------|
| Baseline  | X%       | Y%       | ...   |
| Proposed  | X'%      | Y'%      | ...   |
```

The standard for definitions is: a reader should understand what the number means without looking at the original paper.

### Step 4: Write the Causal Chain Analysis

This is the core output. The structure follows a causal reasoning chain — each section flows from the previous one:

1. **现象**: What did they observe? What's the surprising or counterintuitive finding? Lead with the punchline.
2. **实验设置**: How did they observe it? What experimental design, models, data, and metrics made this phenomenon visible? The setup serves the phenomenon, not the other way around.
3. **归因**: Why do they think this happens? What's their causal explanation for the phenomenon?
4. **解法**: Based on their attribution, what do they propose to fix it? What's the mechanism of the fix, and does it actually address the attributed cause?

```markdown
### Paper-Name (arXiv-ID) — "one-line characterization"

**现象**：
- The key experimental finding, with actual numbers
- What's surprising or counterintuitive about it
- Note: lead with what they *saw*, not what they *did*

**实验设置**：Base model | Method | Data | Key metrics — how the above phenomenon was observed

**归因**：Authors' explanation for why the phenomenon occurs.

**解法**（if applicable）：Based on the attribution above, what they propose and how it addresses the cause.
```

The causal chain matters because it exposes logical gaps: if the 解法 doesn't actually follow from the 归因, or if the 归因 doesn't fully explain the 现象, that's where the interesting analysis lives.

### Step 4.5: Tri-dimensional Tagging

If a taxonomy is configured (i.e., `references/taxonomy.md` exists), add a tag line at the top of each paper's analysis, mapping it to the classification framework:

```markdown
### Paper-Name (arXiv-ID) — "大白话一句话概括"

> 📍 诊断：[用什么方法发现的] | 归因：[为什么会这样] | 修复：[怎么修的/没修]
```

The tag line serves two purposes:
1. **Reader navigation**: scanning 30+ papers by tags without reading each analysis
2. **Gap detection**: if a category has no papers, that's an unexplored area

If no taxonomy is configured, skip the tag line — Steps 1-4 already produce a complete analysis.

### Step 5: Research Framework Mapping and Reverse Challenge

**Skip this step if** no research framework is configured (i.e., `references/hypothesis.md` doesn't exist). Steps 1-4 already produce a complete, standalone analysis.

If the user has defined a research framework — their own hypothesis, theoretical lens, or set of claims they're building evidence for — this step connects the paper's findings to that framework. The framework is stored in `references/hypothesis.md` and is entirely user-defined. It could be a hypothesis, a taxonomy, a set of open questions, or anything else that gives structure to a body of related work.

**Mapping**: How does this paper's evidence relate to the framework?
- Does it support, challenge, or provide boundary conditions?
- Is there evidence the authors didn't interpret this way, but that supports the framework?
- What would this paper's findings look like if the framework's claims were true?

**Reverse Challenge**: For any "fix" the paper proposes, ask:
> "Does this fix inadvertently prove the framework's claims?"

The logic: if a paper identifies a problem and proposes a fix, and the fix addresses a symptom predicted by your framework, then the fix itself becomes evidence — even if the authors don't frame it that way. Push hard on whether the paper's narrative holds up, and whether its evidence points somewhere the authors didn't look.

### Step 6: Cross-Paper Connections (Optional)

If the user is building a body of related work, note:
- **Structural analogues**: Other papers that observe the same phenomenon through different methods
- **Complementary evidence**: Papers whose findings combine to tell a stronger story
- **Contradictions**: Papers whose findings genuinely conflict (not just different interpretations)
- **Methodology comparisons**: Differences in base model, training data, or evaluation that affect comparability

## Writing Rules

All output from this skill must follow these rules. The standard is: **a reader should understand every sentence without looking up the original paper.**

### De-jargoning

Always use plain language first, then note the paper's original term in parentheses for traceability.

- ❌ "Visual Anchor Drifting 导致 dilution effect"
- ✅ "推理越长越忘记看图（论文称 Visual Anchor Drifting），因为文字太多把图的注意力挤没了（论文称 dilution effect）"

This applies to:
- Paper-coined concept names (Language Shortcut, Tool Usage Homogenization, etc.)
- Causal explanations (credit assignment failure → 训练信号分不清该奖励什么)
- Method names when the name is opaque (Cold-Start SFT → 先 SFT 打底再 RL)

Do NOT de-jargon universally understood ML terms (RL, SFT, GRPO, CoT, attention, loss, etc.) or proper nouns (benchmark names, model names).

### Abbreviation Expansion

Every abbreviation must be expanded on first use with a one-line explanation:

- ❌ "基于 SCM 设计"
- ✅ "基于 SCM（Structural Causal Model，结构因果模型——将变量间的因果关系建模为有向图）设计"

### One-line Characterization

The paper title's one-line characterization (after the em-dash) must be in plain language, not the paper's own jargon:

- ❌ `#### GeoEyes — "Tool Usage Homogenization"`
- ✅ `#### GeoEyes — "工具调用千篇一律：每题恰好一次 zoom 的机械行为"`

## Output Format

The primary output is the causal chain analysis (Step 4), plus tri-dimensional tagging (Step 4.5) when a taxonomy is configured, plus research framework mapping (Step 5) when a hypothesis is configured. This goes into the user's related work document.

For a complete analysis, produce:

1. **Three-part entry** (for `thinking-with-image.md` or equivalent doc)
2. **Evidence chain entry** (one row for the summary table, if it exists)
3. **Attribution entry** (if the paper proposes a new explanation)
4. **Fix entry** (if the paper proposes a solution)

## Configuration

### Research Framework (Optional)

If the user has a research hypothesis, theoretical lens, or set of claims they're building evidence for, they can create `references/hypothesis.md` (see `references/hypothesis.example.md` for the expected format). This file is entirely user-defined — it could be a hypothesis, a set of open questions, or any high-level narrative that organizes related work.

- If `references/hypothesis.md` exists → read it before analysis, apply Step 5
- If it doesn't exist → Steps 1-4 produce a complete analysis on their own, no need to ask

### Classification Taxonomy (Optional)

`references/taxonomy.md` defines the multi-dimensional classification framework for the research area. Each paper gets "hung" into this framework via the tri-dimensional tag (Step 4.5). See `references/taxonomy.example.md` for the expected format.

- If `references/taxonomy.md` exists → apply Step 4.5 tagging
- If it doesn't exist → skip tagging, the analysis is still complete
- The taxonomy evolves as more papers are read — when a paper doesn't fit existing categories, propose a new category to the user

### NotebookLM

This skill depends on the `notebooklm` skill (notebooklm-py CLI). Every paper analyzed gets added to NotebookLM as a source. The typical notebook organization is one notebook per research topic (e.g., "CoT Faithfulness Survey"), with multiple papers as sources.

If the user has an existing notebook, they'll usually specify a notebook ID or name. If not specified, ask which notebook to use or whether to create a new one.

## Tips for Better Analysis

- **Don't trust abstracts.** The abstract tells you what the authors want you to think. The experiments tell you what actually happened. Start from the experiments.
- **Chase the denominators.** A "22% error rate" means nothing until you know: 22% of what? Measured how? On which subset? With what judge?
- **Compare experimental setups before comparing results.** Two papers using "Qwen2.5-VL-7B" might have different SFT data, different RL recipes, different eval splits. Note these differences explicitly.
- **Distinguish API errors from model errors.** In tool-augmented reasoning papers, reported failure rates may mix "the tool API was down" with "the model made a bad tool call". These have very different implications.
- **Look for what the paper doesn't show.** Missing ablations, unreported baselines, or asymmetric comparisons often reveal more than what's presented.
