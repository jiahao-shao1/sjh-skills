---
name: codex-review
description: "Get a second opinion from OpenAI Codex on your plan or code changes. Automatically detects whether to do a plan review or code review based on context. Claude and Codex iterate back-and-forth until Codex approves (max 5 rounds). Use whenever you want cross-model verification before implementing a plan or merging code — especially for architecture decisions, non-trivial refactors, config changes in critical systems, or when you're unsure about an approach. Triggers: '/codex-review', 'codex review', 'second opinion', 'let codex check', 'cross-check this', '让 codex 看看', '交叉审查', 'review with codex'. NOT for: trivial one-line fixes, formatting-only changes, or when user explicitly declines review."
user_invocable: true
---

# Codex Review

A cross-model review skill that sends your plan or code diff to OpenAI Codex for independent verification. The value of cross-model review is that different models have different blind spots — Codex may catch issues that Claude misses, and vice versa.

The skill operates in two modes (auto-detected):
- **Plan Review**: when you have an implementation plan, Codex challenges it for completeness, risks, and alternatives
- **Code Review**: when you have a git diff, Codex inspects the actual code for bugs, security issues, and edge cases

In both modes, Claude doesn't just relay feedback — it actively revises the plan or proposes fixes based on Codex's input, then re-submits for re-review. This continues until Codex approves or 5 rounds are reached.

## Prerequisites

- `codex` CLI installed and on PATH (`npm install -g @openai/codex`)
- OpenAI credentials configured (API key or ChatGPT login)

Verify with: `codex --version`

## Proxy Setup

Codex CLI requires proxy to reach OpenAI API. Set these environment variables before every `codex exec` call:

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
```

Prepend this export to all `codex exec` commands in this skill (use `&&` to chain).

## Step 1: Detect Review Mode

Check what's available, in this priority order:

1. **Plan in context** → Plan Review mode
2. **Staged changes** (`git diff --cached --stat`) → Code Review mode
3. **Unstaged changes** (`git diff --stat`) → Code Review mode
4. **Nothing found** → ask the user what they'd like reviewed

Tell the user which mode was detected:
> "Detected [staged diff / plan in context]. Running **Code Review** / **Plan Review** mode."

If the user passed arguments (e.g., `/codex-review gpt-5.4`), parse the model name and use it instead of the default.

## Step 2: Prepare the Review Package

Generate a session-scoped ID to avoid conflicts if multiple reviews run concurrently:

```bash
REVIEW_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | head -c 8)
```

Write the review content to `/tmp/codex-review-input-${REVIEW_ID}.md`:

### For Plan Review:
```markdown
# Plan Review Request

## Project Context
[2-3 lines from CLAUDE.md describing what the project does]

## Implementation Plan
[Full plan content from conversation context]
```

### For Code Review:
```markdown
# Code Review Request

## Project Context
[2-3 lines from CLAUDE.md describing what the project does]

## Summary
[1-2 sentence summary of what these changes do and why]

## Diff
[Output of git diff --cached, or git diff if nothing staged]
```

For code review, also note the file count and diff size. If the diff exceeds ~3000 lines, warn the user that Codex may not review everything thoroughly and suggest reviewing in smaller chunks.

## Step 3: Send to Codex (Round 1)

The review prompt differs by mode because plans and code need different lenses.

### Plan Review Prompt

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 && \
codex exec \
  -m gpt-5.4-high \
  -s read-only \
  -o /tmp/codex-review-output-${REVIEW_ID}.md \
  "Review the implementation plan in /tmp/codex-review-input-${REVIEW_ID}.md.

Evaluate along these dimensions:
1. GOAL ALIGNMENT - Does the plan actually solve the stated problem? Are there simpler alternatives?
2. COMPLETENESS - Are any steps missing? What about rollback, error handling, migration?
3. RISK ASSESSMENT - What could go wrong? Data loss? Breaking changes? Race conditions?
4. ORDERING & DEPENDENCIES - Are the steps in the right order? Any implicit dependencies?
5. TESTABILITY - How will we know this worked? What should be tested?

For each issue found, be specific: name the step number, explain what's wrong, and suggest a fix.
Skip anything that looks fine — only flag real problems.

End your review with exactly one of:
VERDICT: APPROVED (if the plan is solid and ready to implement)
VERDICT: REVISE (if changes are needed — list what needs to change)" 2>/dev/null
```

### Code Review Prompt

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 && \
codex exec \
  -m gpt-5.4-high \
  -s read-only \
  -o /tmp/codex-review-output-${REVIEW_ID}.md \
  "Review the code changes in /tmp/codex-review-input-${REVIEW_ID}.md.

Evaluate along these dimensions:
1. CORRECTNESS - Does the code do what it claims? Off-by-one errors, wrong comparisons, missing null checks?
2. SECURITY - Injection risks, auth bypasses, secrets in code, unsafe deserialization?
3. EDGE CASES - What inputs or states would break this? Empty collections, concurrent access, large inputs?
4. ERROR HANDLING - Are errors caught and handled appropriately? Can failures cascade?
5. COMPATIBILITY - Does this break existing callers, APIs, or data formats?
6. TEST COVERAGE - Are the changes tested? What test cases are missing?

For each issue, reference the specific file and code snippet. Suggest a concrete fix, not just 'consider handling this'.
Skip anything that looks fine — only flag real problems. No praise, no filler.

End your review with exactly one of:
VERDICT: APPROVED (if the code is solid and ready to merge)
VERDICT: REVISE (if changes are needed — list what needs to change)" 2>/dev/null
```

**Capture the Codex session ID** from stdout (the line containing `session id: <uuid>`). Store as `CODEX_SESSION_ID` for subsequent rounds.

**CLI notes:**
- Default model: `gpt-5.4-high` (thorough, good balance of quality and speed).
- Always use `-s read-only` — Codex should never modify files.
- `2>/dev/null` suppresses thinking tokens that would bloat context.

## Step 4: Process the Verdict

Read `/tmp/codex-review-output-${REVIEW_ID}.md` and present to the user:

```
## Codex Review — Round N [Plan/Code] (gpt-5.4-high)

[Codex's feedback, preserving its structure]

**Verdict: APPROVED / REVISE**
```

Then branch:
- **APPROVED** → Step 7 (done)
- **REVISE** → Step 5
- No clear verdict but only positive comments → treat as APPROVED
- Round 5 reached → Step 7 with unresolved concerns listed

## Step 5: Revise Based on Feedback

This is where the skill earns its value — Claude doesn't just relay Codex's feedback, but thinks about it and acts.

### For Plan Review:
- Update the plan to address each issue Codex raised
- Rewrite `/tmp/codex-review-input-${REVIEW_ID}.md` with the revised plan

### For Code Review:
- Don't modify files directly (the user hasn't approved yet)
- Instead, write a **proposed fix list** into the temp file explaining what you'd change and why
- If Codex flagged a false positive (e.g., the code is correct but Codex misread it), note that and explain why you're skipping it

In both cases, summarize for the user:
```
### Revisions (Round N)
- [What changed and why, one bullet per issue]
- [Skipped: issue X — reason why it's not applicable]
```

If a suggested revision contradicts the user's explicit requirements, skip it and explain why.

## Step 6: Re-submit to Codex (Rounds 2-5)

Resume the Codex session so it retains context from prior rounds:

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890 && \
codex exec resume ${CODEX_SESSION_ID} \
  "I've addressed your feedback. The updated content is in /tmp/codex-review-input-${REVIEW_ID}.md.

Changes made:
[Bullet list of what was revised]

Skipped (with rationale):
[Any items intentionally not addressed]

Please re-review. End with VERDICT: APPROVED or VERDICT: REVISE" 2>&1 | tail -80
```

`codex exec resume` doesn't support `-o`, so read output from stdout (piped through `tail` to skip startup noise).

If resume fails (session expired), fall back to a fresh `codex exec` with a note summarizing prior rounds.

Return to Step 4.

## Step 7: Present Final Result

### If approved:
```
## Codex Review — Final [Plan/Code] (gpt-5.4-high)

**Status:** APPROVED after N round(s)

[Final Codex feedback]

---
Ready for your approval to [implement / merge].
```

For code review, if there were proposed fixes along the way, list them:
```
**Proposed fixes from review:**
- [ ] file.py:42 — add null check for `user_input`
- [ ] config.yaml:15 — remove hardcoded timeout value
```

### If max rounds reached:
```
## Codex Review — Final [Plan/Code] (gpt-5.4-high)

**Status:** 5 rounds reached — not fully approved

**Remaining concerns:**
[Unresolved issues from last review]

---
Review these remaining items and decide whether to proceed or keep refining.
```

## Step 8: Cleanup

```bash
rm -f /tmp/codex-review-input-${REVIEW_ID}.md /tmp/codex-review-output-${REVIEW_ID}.md
```

## Ground Rules

- Claude **actively revises** based on feedback — not just a messenger between the user and Codex
- Codex runs in **read-only** mode, always. It reviews but never writes files
- **Max 5 rounds** prevents infinite loops. If 3+ rounds happen on the same issue, surface it to the user as a judgment call
- **Show every round** to the user so they can follow the conversation and intervene
- In code review mode, **don't apply fixes** until the user approves — just propose them
- If Codex CLI isn't installed or fails, tell the user: `npm install -g @openai/codex`
- Default model: `gpt-5.4-high`. User can override via arguments (e.g., `/codex-review gpt-5.3-codex`)
- UUID-scoped temp files support concurrent sessions safely
