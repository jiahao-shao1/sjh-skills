# Codex Review

English | [中文](README.zh-CN.md)

> Cross-model review — send your plan or code diff to OpenAI Codex for independent verification, with iterative Claude-Codex feedback until approved (max 5 rounds).

## Features

- **Auto-detect mode** — Plan review or code review, based on context
- **Iterative feedback** — Claude revises based on Codex's comments, re-submits for re-review
- **Two review lenses** — Plans evaluated on goal alignment, completeness, risk; code on correctness, security, edge cases
- **Max 5 rounds** — Prevents infinite loops while ensuring thorough review

## Install

```bash
npx skills add jiahao-shao1/sjh-skills --skill codex-review
```

## Prerequisites

- `codex` CLI installed and on PATH (`npm install -g @openai/codex`)
- OpenAI credentials configured (API key or ChatGPT login)

## Usage

```
/codex-review
```

Or trigger conversationally:

```
"let codex check this"
"second opinion on this plan"
"cross-check the diff"
"让 codex 看看"
```

Optionally specify a model:

```
/codex-review gpt-5.4
```

## How It Works

1. **Detect** — Checks for a plan in context (plan review) or git diff (code review)
2. **Package** — Writes review content + project context to a temp file
3. **Send to Codex** — Runs `codex exec` in read-only mode with a structured review prompt
4. **Process verdict** — APPROVED exits; REVISE triggers Claude to fix issues and re-submit
5. **Iterate** — Up to 5 rounds until Codex approves or max rounds reached
6. **Report** — Final summary with verdict and any proposed fixes

## Review Dimensions

### Plan Review
- Goal alignment — does the plan solve the stated problem?
- Completeness — missing steps, rollback, migration?
- Risk assessment — data loss, breaking changes, race conditions?
- Ordering & dependencies — correct step order?
- Testability — how will we know it worked?

### Code Review
- Correctness — off-by-one, wrong comparisons, null checks?
- Security — injection, auth bypass, secrets in code?
- Edge cases — empty collections, concurrency, large inputs?
- Error handling — cascading failures?
- Compatibility — breaking existing callers/APIs?
- Test coverage — missing test cases?

## License

MIT
