# exp-registry

Structured YAML experiment registry for ML research.

## Install

```bash
pip install exp-registry
```

## Quick Start

```bash
exp init                    # Create config + registry directory
exp register exp01 --type rl --model Qwen3-VL-8B
exp add-benchmark exp01 --dataset mmlu --eval-mode cot --samples 100 --step 50 --extra accuracy=0.72
exp list
exp compare exp01 exp02 --dataset mmlu
```
