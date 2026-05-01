---
name: codex-task
description: "Delegate a coding task (debug, implement feature, refactor) to OpenAI Codex CLI directly via codex exec. Faster than codex:rescue agent because it skips the Node companion runtime. Codex writes the code; Claude verifies. Use when you want Codex to actually do the work, not just review. Triggers: '/codex-task', 'codex task', 'let codex do', 'delegate to codex', 'codex implement', 'codex debug', '让 codex 干', '让 codex 实现', '让 codex 修', '丢给 codex', '外包给 codex'. Not for review or second opinion (use codex-review)."
user_invocable: true
---

# Codex Task

Forward a coding task to Codex CLI in one shot. Codex writes the code; Claude verifies after.

**Why not just use `codex:rescue`?** rescue routes through a 1000-line Node companion (background mode, session persistence, status/result polling). For straightforward tasks, calling `codex exec` directly skips ~10s of wrapper overhead and avoids any chance of session-state confusion.

## Prerequisites

- `codex` CLI on PATH (`npm install -g @openai/codex`)
- OpenAI credentials configured

Verify: `codex --version`. If missing, tell the user `npm install -g @openai/codex` and stop.

## Working Directory

Codex runs in Claude's current cwd by default. Before invoking, sanity-check that cwd is the right repo for the task. If the user's task implies a different directory (e.g., "fix the bug in agentic_umm"), pass `-C /absolute/path` to codex or `cd` first. Don't assume.

## Defaults

- **Model:** `gpt-5.5`
- **Reasoning effort:** `xhigh`
- **Sandbox:** `--dangerously-bypass-approvals-and-sandbox` — Codex has full filesystem + network access, no approval prompts. Required so it can install packages, hit the internet, and run arbitrary commands.
- **Session:** `--ephemeral` (no persistence, clean each run)

⚠️ **The default sandbox is intentionally permissive.** Codex can read/write anywhere on disk, install global packages, call external APIs, and modify files outside the repo. Only invoke this skill for tasks where you're OK with that. Pass `--safe` to drop back to `workspace-write` (cwd-only, no network).

## Step 1: Parse Routing Flags

**Parsing rules:**

- Routing flags must appear at the **start** of the user's task text, immediately after `/codex-task` or the trigger phrase. Once non-flag content is seen, stop parsing — the rest is task text, even if it looks like a flag (e.g., `"add support for --safe"` is task content, not a routing flag).
- Treat `--` as an explicit end-of-flags marker. Anything after `--` is task text.
- If a token at the head looks like a flag but is ambiguous (e.g., the user says "implement `--read-only`"), ask once before stripping.

**Recognized flags** (each consumed once at the head):

| Flag | Effect | Precedence |
|------|--------|------------|
| `--read-only` | Sandbox becomes `read-only` (Codex can only read, no edits, no network) | overrides `--safe` and default |
| `--safe` | Sandbox becomes `workspace-write` (Codex edits cwd only, no network) | overrides default |
| `--model <name>` | Override model (e.g. `gpt-5.4`, `gpt-5.3-codex-spark`) | — |
| `--effort <level>` | Override effort: `low` / `medium` / `high` / `xhigh` | — |
| `-C <dir>` | Run Codex with this cwd (alternative: `cd` first) | — |

If both `--read-only` and `--safe` are present, `--read-only` wins. Whatever's left is `TASK_TEXT`. Pass it through as-is — don't rewrite it. Codex prefers raw intent over Claude-mediated prompts.

## Step 2: Confirm (Only If Truly Ambiguous)

Each codex round-trip is ~25s. Spending 5s to clarify is cheap, but don't over-clarify. Ask only if you genuinely can't tell:
- Which file/module to touch
- What "done" looks like
- What's explicitly out of scope

Skip clarification for tasks that are already concrete. Trust Codex to ask if it needs more.

## Step 3: Preflight Check

Before invoking Codex (especially in default danger mode), do a quick sanity check and surface anything risky:

```bash
echo "cwd: $(pwd)"
git rev-parse --show-toplevel 2>/dev/null || echo "WARNING: not in a git repo — codex changes will be hard to inspect/revert"
git status --short > /tmp/codex-task-pre-status-${TASK_ID}.txt
test -s /tmp/codex-task-pre-status-${TASK_ID}.txt && echo "WARNING: dirty worktree — codex's changes will mix with yours"
```

If any warning fires, surface it to the user and ask whether to continue. Default `--dangerously-bypass-approvals-and-sandbox` outside a git repo is high-risk: codex can change anything on disk and you'll have no diff to inspect.

If the user explicitly chose `--safe` or `--read-only`, you can skip the dirty-worktree warning (sandbox limits the damage).

## Step 4: Invoke Codex

After Step 1, you have these resolved values. Default to substituting them inline below; only fall back to the variable form if you need to call codex multiple times in one session.

| Variable | Default | Source |
|----------|---------|--------|
| `MODEL` | `gpt-5.5` | `--model <name>` |
| `EFFORT` | `xhigh` | `--effort <level>` |
| `SANDBOX_FLAG` | `--dangerously-bypass-approvals-and-sandbox` | `--safe` → `-s workspace-write`; `--read-only` → `-s read-only` |
| `CD_FLAG` | empty | `-C <dir>` if user passed it |
| `TASK_TEXT` | — | user input minus stripped routing flags |

**Critical: pass TASK_TEXT via stdin, not as a quoted argument.** Raw user text in a shell-quoted argument is a command-injection risk under the default danger-mode sandbox (e.g., a task containing `$(rm -rf ~)` would execute). Always feed the prompt through stdin with a `<<'PROMPT'` heredoc (single-quoted delimiter prevents shell expansion):

```bash
TASK_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | head -c 8)
ERR_LOG=/tmp/codex-task-error-${TASK_ID}.log
OUT_FILE=/tmp/codex-task-output-${TASK_ID}.md

export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

codex exec \
  -m "${MODEL}" \
  ${SANDBOX_FLAG} \
  -c "model_reasoning_effort=\"${EFFORT}\"" \
  ${CD_FLAG} \
  --ephemeral \
  -o "${OUT_FILE}" \
  - <<'PROMPT' 2>"${ERR_LOG}"
<TASK_TEXT goes here verbatim — no escaping needed because heredoc is single-quoted>

After making changes, end your response with one line:
STATUS: DONE  -- task complete and verified (tests run, build passes, etc.)
STATUS: PARTIAL  -- partially complete; list what's left
STATUS: BLOCKED  -- couldn't proceed; explain why
PROMPT

EXIT=$?
if [ $EXIT -ne 0 ] || [ ! -s "${OUT_FILE}" ]; then
  echo "Codex invocation failed (exit=$EXIT). stderr tail:"
  tail -30 "${ERR_LOG}"
  exit 1
fi
```

**Note on the heredoc:** because the delimiter is `'PROMPT'` (single-quoted), the shell does no expansion inside the body — `$()`, backticks, `${...}` are all preserved literally. This is what makes the user's task text safe to embed verbatim.

The trailing STATUS protocol is the **only** thing appended to the user's task text — everything else is forwarded as-is.

**CLI notes:**
- Default sandbox `--dangerously-bypass-approvals-and-sandbox` — full network + filesystem.
- `-c 'model_reasoning_effort="xhigh"'` is the official way to set effort.
- `--ephemeral` keeps each task self-contained.
- UUID-scoped temp files support concurrent invocations.
- Don't add `--background` — this skill is single-shot foreground.
- Don't pass `--file` — it doesn't exist on `codex exec`. Reference file paths inside the task text; Codex will read them itself.

## Step 5: Verify Independently

Read `${OUT_FILE}` AND inspect what changed. Don't trust Codex's self-reported STATUS alone.

```bash
git status --short > /tmp/codex-task-post-status-${TASK_ID}.txt
diff /tmp/codex-task-pre-status-${TASK_ID}.txt /tmp/codex-task-post-status-${TASK_ID}.txt
git diff --stat
```

Verification checklist:
- Files changed match the task scope?
- Any new files Codex created — necessary or scope creep?
- Any edits outside the stated scope?
- Run the project's test command on affected modules.
- In default danger mode: also check whether codex touched anything **outside** the repo (run `find ~/.config -newer /tmp/codex-task-pre-status-${TASK_ID}.txt 2>/dev/null` or similar if you have reason to suspect global writes).

**Special case: BLOCKED with no changes.** `git diff` will be empty; verification reduces to reading codex's BLOCKED reason and judging whether it's plausible.

## Step 6: Present Result

```
## Codex Task Result (${MODEL} · ${EFFORT})

**Status:** DONE / PARTIAL / BLOCKED

### What Codex did
[1-paragraph from Codex output]

### Files changed
[git diff --stat output]

### Verification
- Codex reported: [its claim]
- Claude verified: [what Claude ran independently + result]

### Concerns
[Anything off — out-of-scope edits, missing tests, suspicious changes, files touched outside cwd. Empty if none.]
```

## Step 7: Decide Next Action

| Result | Action |
|--------|--------|
| DONE + verification clean | Tell user it's ready. Ask if they want to commit. |
| DONE + Claude found issues | Show issues. Options: (a) Claude fixes manually, (b) re-run codex with refined task text, (c) revert Codex's changes (see below). |
| PARTIAL | Show what's left. Ask: continue with codex, switch to Claude, or stop. |
| BLOCKED | Show blocker. Likely needs user input. |

**Reverting Codex's changes safely.** Don't blindly run `git checkout -- <file>` — that can destroy unrelated edits the user had in the same files before the task started. Instead:

1. If pre-status was clean for that file (compare `/tmp/codex-task-pre-status-${TASK_ID}.txt`), `git checkout -- <file>` is safe.
2. If the file was already dirty pre-task, generate a reverse patch of just Codex's hunks: `git diff <file> | git apply -R --check` first to confirm it applies cleanly, and explicitly ask the user before applying.
3. For files Codex created that didn't exist before, `rm <file>` is safe.

## Step 8: Cleanup

```bash
rm -f /tmp/codex-task-output-${TASK_ID}.md \
      /tmp/codex-task-error-${TASK_ID}.log \
      /tmp/codex-task-pre-status-${TASK_ID}.txt \
      /tmp/codex-task-post-status-${TASK_ID}.txt
```

## Examples

**Example 1 — Bug fix in cwd:**
- User: "/codex-task 让 codex 把 `src/api.py` 里的 N+1 query 修了"
- Step 1: no routing flags. TASK_TEXT = "让 codex 把 `src/api.py` 里的 N+1 query 修了"
- Step 3: cwd is the right repo, worktree clean. Proceed.
- Step 4: codex runs in danger mode (default), edits `src/api.py`, returns `STATUS: DONE`.
- Step 5: `git diff src/api.py` shows N+1 fix; `pytest tests/api/` passes.
- Step 6: present diff + test result.

**Example 2 — Safe mode with new dependency:**
- User: "/codex-task --safe add a `--dry-run` flag to scripts/migrate.py and a unit test for it"
- Step 1: `--safe` → `SANDBOX_FLAG="-s workspace-write"`. TASK_TEXT = "add a `--dry-run` flag to scripts/migrate.py and a unit test for it"
- Step 3: clean worktree. Proceed.
- Step 4: codex runs sandboxed, edits `scripts/migrate.py` and `tests/test_migrate.py`.
- Step 5: verify both files; run the new test.

**Example 3 — Cwd mismatch:**
- User (in `~/workspace/sjh-skills`): "/codex-task 让 codex 把 agentic_umm 里 `train.py` 的 lr scheduler 换成 cosine"
- Step 3 preflight: cwd is wrong repo. Either `cd ~/workspace/agentic_umm/agentic_umm` first, or pass `-C ~/workspace/agentic_umm/agentic_umm`.
- Then proceed normally.

## Ground Rules

- **Single shot.** No multi-round loop. If the result is wrong, surface to user — don't auto-retry.
- **Forward, don't preprocess.** Pass TASK_TEXT raw. Don't rewrite into "better" prompts unless the user asks.
- **Always feed prompt via stdin heredoc.** Never embed user text in a quoted shell argument under default danger mode.
- **Verify independently.** Codex saying "tests pass" ≠ tests passed. Run them.
- **Default sandbox is intentionally permissive.** User opted in by choosing this skill. Mention it briefly at start of run so they remember.
- **Don't auto-commit.** Even on clean DONE, wait for user.
- **Don't auto-revert with `git checkout --`.** Generate reverse patches when the file was pre-dirty.
- **No background mode.** That's `codex:rescue`'s job.

## When to use this vs alternatives

| Situation | Use |
|-----------|-----|
| Concrete coding task, want it done fast | **codex-task** (this skill) |
| Long-running task, want async + status polling | `codex:rescue` agent |
| Want second opinion on plan/diff (no edits) | `codex-review` skill |
| Task is small enough for Claude itself | Just do it in Claude |
