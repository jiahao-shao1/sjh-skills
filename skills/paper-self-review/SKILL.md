---
name: paper-self-review
description: "Self-review for paper paragraphs — diagnose v1 issues and give a revision direction (intro, abstract, method, related work). Triggers: 'review this intro', 'check this paragraph', 'paper paragraph self-review', 'help me look at intro / abstract', 'polish this intro', 'paper self-review', '帮我看 intro', 'paper 段落自检', 'review 这段 paper'. Not for: generating a draft from scratch — write v1 yourself first, then iterate."
---

# Paper Self-Review

Mechanical v1 → v2 iteration for paper paragraphs. Core belief: every v1 is a mix of logic gaps, repetition, and detail leakage. This skill does not write the first draft — it makes the revision loop deterministic instead of vibe-driven.

Theoretical anchors:
- Advisor reviewer comments distilled into three axes (logic / expression / detail) — primary anchor
- Simon Peyton Jones, *How to Write a Great Research Paper* (contributions-first; one-page intro)
- WritingAIPaper handbook (CARS three-move: establish territory → niche → occupy)

## When to use

- User pastes a paragraph of paper draft and asks for review
- User says "I revised the intro / abstract / method, take a look"
- User explicitly invokes: `paper-self-review` / "self-check this paragraph"

Not used for: typo / grammar / LaTeX compilation issues.

## Pre-flight: one-sentence claim test

Before writing the intro (not after) — required. If the user cannot state the paper's core contribution in one sentence, stop:

> Write the contribution in ≤ 25 words. If you cannot, you have not yet thought it through clearly. Do not start writing the intro.

— SPJ: *"If you cannot state your contribution in one sentence, you don't yet have a paper."*

Save that sentence. Every paragraph that follows must trace back to it.

## Three-axis self-check (apply to every paragraph)

Run all three axes after each paragraph. If any axis fails, **rewrite the paragraph** — do not patch locally. The reason: paragraph-level problems (logic gap, repetition, detail leak) almost always cascade across sentences; surgical edits leave the structure broken.

### Axis 1 — Logic (one task per paragraph; pause after each step)

**Rule**: Before drafting, write down the paragraph's "single task" in one sentence. Then every sentence must follow directly from the previous one.

**Anti-patterns** (canonical v1 symptoms):
- One paragraph with 4–5 jumps A → B → C → D → E, no anchor sentence — the reader bridges them silently in their head and loses the thread.
- "First / Second / Third" structuring three points that are paraphrases of one underlying point. Reviewers spot the padding instantly.
- Topic sentence and closing sentence don't align — the paragraph drifted in the middle.

**Self-check questions**:
1. Can I state this paragraph's single task in one sentence?
2. Delete each sentence one at a time and reread — does the logic break? (Breaks = necessary anchor; doesn't = filler.)
3. Are the "First / Second / Third" points genuinely parallel, or paraphrases?

### Axis 2 — Expression (do not say the same thing twice)

**Rule**: After drafting, condense the paragraph's claim to a 5-word phrase (e.g., "method M beats baseline B"). Then check repetition at two scopes:
- **Local (always available)**: within this paragraph, are 4+ sentences restating the claim? Keep the one with the most mechanism, cut the rest.
- **Global (only if the user gave you the full intro / abstract context)**: grep the whole intro. **If it appears ≥ 2 times, cut to 1**; let that one occurrence be the anchor.

If the user pasted only one paragraph in isolation, do the local check fully and flag global repetition as "needs full-intro context to verify" — do not invent or assume what other paragraphs say.

**Self-check questions**:
1. What is the 5-word version of this paragraph's claim?
2. Within this paragraph, are four sentences making the same point? (Hypothesis paragraphs are highest-risk.)
3. (If full intro is available) How often does it appear across the intro? ≥ 2 → cut.

For stylized examples (an introduction that repeats one claim four times), see `references/anti-patterns.md`.

### Axis 3 — Detail (intro is not a method preview)

**Rule**: When the intro touches on the method, each comparison conveys only two things — *what was asked / what number was obtained*. Symbol definitions, narrow-design rationale, and theoretical interpretation defer to §3 / §5.

**Hard constraint**: in the intro, **method word count ≤ results word count**.

**Self-check questions**:
1. Can the reader parse every symbol I introduced (e.g., `Variant-A`, `Method-M`) at this point in the intro?
2. Did I explain "why this design / why narrow"? That belongs in §3 / §5.
3. Method words vs. result words — methods longer? Cut.

For a stylized example (a "Testing the hypothesis" paragraph that turned into half a §3), see `references/anti-patterns.md`.

## Workflow

When the user pastes a paragraph:

### Step 1 — Extract the single task

Either ask the user, or extract it yourself: what is this paragraph's "single task"? If you cannot extract it cleanly, **send the paragraph back**: it is not yet thought through, and word-choice edits will not fix it.

### Step 2 — Scan the three axes, in order

Axis 1 → 2 → 3. **Surface only the single most severe issue per axis.** Listing ten nits is unactionable; the user cannot revise breadth-first.

Output template:

```markdown
## Single task (extracted)
<one sentence>

## Axis 1 — Logic
<the most severe jump + which anchor sentence is missing>

## Axis 2 — Expression
<5-word claim + how many times it repeats + which to keep, which to cut>

## Axis 3 — Detail
<which symbol / rationale should defer to §X>

## Suggested revision (≤ 3 sentences, direction only — do not rewrite)
<direction, not v2 prose>
```

### Step 3 — Default: diagnose, don't rewrite

The default mode is **diagnosis only** — name the issue, point at the v1 sentence, give a direction. This is what trains the user's self-review reflex; rewriting on every request short-circuits the learning loop and produces another v1 next time.

**When to give a reference v2** (allowed, mark it explicitly):
- User asks for revision wording: "rewrite", "polish", "give me v2", "改一版", "重写".
- User asks for a specific sentence-level edit ("how would you phrase the anchor sentence?").

In these cases, after the three-axis diagnosis, give one reference rewrite and tag it: *"reference only — please verify against the three axes; the diagnosis above is the more important output."*

**Never** generate a v1 from scratch — if the user has not written anything yet, return them to the pre-flight one-sentence claim test.

## Reviewer voice to emulate

- **Cite specifics**: quote the v1 sentence; do not abstract-criticize.
- **Name the pattern**: not "this is unclear" but "this is X-type (filler structure / anchor repetition / detail leak)".
- **Give an executable v2 direction** — a mechanical step, not a vibe.

Avoid the "reviewer #2" tone of "this is unclear, please revise".

## Anti-pattern quick reference

| Symptom | Axis | Fix |
|---|---|---|
| 4–5 jumps in one paragraph | 1 | Split into N paragraphs, one task each |
| First/Second/Third filler | 1 | Check if the three points are paraphrases; if so, merge |
| Topic sentence and closing don't align | 1 | Rewrite topic sentence, or cut the drifted middle |
| Same 5-word claim repeats ≥ 2 times | 2 | Keep the strongest occurrence; cut the rest |
| Hypothesis paragraph repeats across 4 sentences | 2 | Keep 1; defer the rest to §3 |
| Intro mentions an undefined method symbol | 3 | Replace with natural-language contrast ("with vs. without the proposed component") |
| Intro explains "why narrow / why this design" | 3 | Cut; defer to §3.X |
| Method word count > result word count | 3 | Cut method description; add result numbers |

For worked examples behind these rows, see `references/anti-patterns.md`.

## References

- `references/anti-patterns.md` — stylized v1 paragraphs and their three-axis diagnosis
- SPJ: <https://simon.peytonjones.org/great-research-paper/>
- WritingAIPaper handbook: <https://github.com/hzwer/WritingAIPaper>
