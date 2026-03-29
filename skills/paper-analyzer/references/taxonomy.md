# Paper Classification Taxonomy

<!--
Replace this example with your own classification framework.
The skill reads this file and applies Step 4.5 (Tri-dimensional Tagging)
to categorize each analyzed paper.

Delete this file or leave it empty to skip tagging.
-->

## Example: CoT Faithfulness Research

### Dimension 1: Diagnosis Method

| Code | Method | Core Logic |
|------|--------|-----------|
| A | Perturb reasoning steps | Corrupt/shuffle/truncate CoT and measure accuracy change |
| B | Probe internal representations | Check if model internals align with stated reasoning |
| C | Compare with/without CoT | Measure accuracy delta between direct and CoT prompting |
| D | Causal intervention | Modify specific reasoning steps and check downstream effects |

### Dimension 2: Attribution

| Code | Attribution | Meaning |
|------|------------|---------|
| A | Training signal artifact | CoT supervision rewards plausible text, not faithful reasoning |
| B | Capability gap | Model can solve the task without CoT; reasoning is decorative |
| C | Reasoning-decision disconnect | Stated reasoning doesn't reflect actual computation |

### Dimension 3: Fix Location

| Code | Fix | Meaning |
|------|-----|---------|
| A | Training objective | Reward faithful reasoning steps, not just final answers |
| B | Architecture change | Add mechanisms that enforce reasoning-output coupling |
| C | Inference-time verification | Post-hoc check whether CoT steps are causally relevant |

## Tag Format

```
> 📍 Diagnosis: [method] | Attribution: [code + plain language] | Fix: [code + approach]
```
