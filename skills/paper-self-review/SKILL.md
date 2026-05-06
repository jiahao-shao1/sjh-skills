---
name: paper-self-review
description: "Self-review for paper paragraphs — diagnose v1 issues and give a revision direction (intro, abstract, method, related work). Triggers: 'review this intro', 'check this paragraph', 'paper paragraph self-review', 'help me look at intro / abstract', 'polish this intro', 'paper self-review', '帮我看 intro', 'paper 段落自检', 'review 这段 paper'. Not for: generating a draft from scratch — write v1 yourself first, then iterate."
---

# Paper Self-Review

Mechanical v1 → v2 iteration for paper paragraphs. Core belief: every v1 is a mix of logic gaps, repetition, detail leakage, framing errors, and reader-orientation failures. This skill does not write the first draft — it makes the revision loop deterministic instead of vibe-driven.

Theoretical anchors:
- Advisor reviewer comments distilled into five axes (logic / expression / detail / framing / reader orientation) — primary anchor
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

## Five-axis self-check (apply to every paragraph)

Run all five axes after each paragraph. If any axis fails, **rewrite the paragraph** — do not patch locally. The reason: paragraph-level problems almost always cascade across sentences; surgical edits leave the structure broken.

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

### Axis 4 — Framing (positive voice; hypothesis ≠ established fact)

**Rule**: Every claim must be framed positively (what IS true, what we DO find), not negatively (what others fail to do, what is missing). Your hypothesis is YOUR proposal — do not dress it as obvious intuition.

**Sub-rules**:

1. **Positive, not negative**: "We show X works" is stronger than "Previous work fails to do X." Frame prior work's limitation as a contrast that motivates your contribution, not as a criticism that leaves a vacuum. Example: instead of "others only modify inference but not training," write "we integrate component C directly into the training loop."

2. **Hypothesis ≠ intuition**: Do not write "The intuition behind these findings is simple" when introducing YOUR hypothesis. That phrase implies the claim is already established. Instead, frame it as a hypothesis with a "when" trigger: "We hypothesize that when the model invokes the external module, it has already encoded the necessary information in its intermediate output." Let the experiments prove it; the intro proposes it.

3. **No abbreviations at key points**: The first mention of a concept in a section must use its full descriptive name — the abbreviation alone assumes reader context that does not exist. Section titles, hypothesis statements, and contribution bullets are "key points." (Good example: a section title "Lightweight Training Preserves Visual Reasoning" rather than "LT Preserves VR".)

4. **Declarative, not interrogative**: Contribution bullets and findings should be stated as claims, not questions. "Can small-scale training transfer?" → "Small-scale training transfers to large-scale models." Questions belong in the introduction's motivation paragraph (to open the niche), not in your findings or contribution list.

5. **Qualitative scale in intro, quantitative in body**: In intro/abstract, describe results at the level of "across scales / under different training regimes / on N benchmarks." Concrete numbers ("+3.2pp on Benchmark-X") belong in §4/§5 tables. The intro sells the shape of the result, not the decimal.

**Self-check questions**:
1. Is any sentence structured as "[Others] do NOT do X" or "[Prior work] lacks Y"? Reframe as what we positively contribute.
2. Am I presenting my hypothesis as if it were already accepted? Does the sentence have an "obviously" or "intuitively" tone? If so, add the epistemic marker (we hypothesize / we propose / we test whether).
3. Are there abbreviations that a fresh reader cannot parse at this point? Spell them out.
4. Are my contribution points / findings phrased as questions? Flip to declarative.
5. Am I putting exact numbers in the intro where a qualitative shape would suffice?

### Axis 5 — Reader Orientation (the reader has zero context)

**Rule**: The audience does not share your internal project context. Each section must be self-contained relative to its own scope, and the narrative must actively guide the reader toward your experimental design before revealing it.

**Sub-rules**:

1. **Section self-containment**: Each section maps to one paper (your own P3). Do not require the reader to recall background from P1/P2 to follow the current section. If §3 explains your method, it must establish its own motivation locally — do not rely on "as discussed in §1" for critical setup. A section that cannot stand alone if you hide all other sections has a dependency problem.

2. **Guide the reader to your experiment**: The best paper makes the reader think "I would design a similar experiment" before you reveal yours. This means: lay out the phenomenon → state what is unknown → make the natural next question obvious → then present your design as the answer. If your experiment feels surprising to the reader, you have not guided them well enough.

3. **Big picture always visible**: Every paragraph should let the reader know where they are in the argument arc. When you drill into a detail, one sentence must connect it back to the section's claim. A paragraph that serves the big picture implicitly (you know why it's there, but the reader doesn't) has failed this test.

4. **No private terminology**: If a concept has a project-internal name, the paper must define it at first use with enough context that an outsider can reconstruct the meaning. Never assume the reader's mental model matches yours — they are building it from your words alone.

**Self-check questions**:
1. If I hide all other sections, does this section still make sense on its own?
2. Before I reveal my experiment/method, have I set up the reader to expect something like it?
3. Can the reader tell WHY this paragraph is here and where it fits in the argument arc?
4. Is there any term that only makes sense if you already know the project? Define or replace it.

## Workflow

When the user pastes a paragraph:

### Step 1 — Extract the single task

Either ask the user, or extract it yourself: what is this paragraph's "single task"? If you cannot extract it cleanly, **send the paragraph back**: it is not yet thought through, and word-choice edits will not fix it.

### Step 2 — Scan the five axes, in order

Axis 1 → 2 → 3 → 4 → 5. **Surface only the single most severe issue per axis.** Listing ten nits is unactionable; the user cannot revise breadth-first.

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

## Axis 4 — Framing
<negative framing / false intuition / abbreviation / question-as-claim identified>

## Axis 5 — Reader Orientation
<self-containment gap / missing guidance / big-picture disconnect>

## Suggested revision (≤ 3 sentences, direction only — do not rewrite)
<direction, not v2 prose>
```

### Step 3 — Default: diagnose, don't rewrite

The default mode is **diagnosis only** — name the issue, point at the v1 sentence, give a direction. This is what trains the user's self-review reflex; rewriting on every request short-circuits the learning loop and produces another v1 next time.

**When to give a reference v2** (allowed, mark it explicitly):
- User asks for revision wording: "rewrite", "polish", "give me v2", "改一版", "重写".
- User asks for a specific sentence-level edit ("how would you phrase the anchor sentence?").

In these cases, after the five-axis diagnosis, give one reference rewrite and tag it: *"reference only — please verify against the five axes; the diagnosis above is the more important output."*

**Never** generate a v1 from scratch — if the user has not written anything yet, return them to the pre-flight one-sentence claim test.

## Reviewer voice to emulate

- **Cite specifics**: quote the v1 sentence; do not abstract-criticize.
- **Name the pattern**: not "this is unclear" but "this is X-type (filler structure / anchor repetition / detail leak / negative framing / context dependency)".
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
| "Others fail to / lack / do not" framing | 4 | Flip to positive: what we contribute, not what's missing |
| "The intuition is simple / obvious" for your hypothesis | 4 | Reframe as "We hypothesize that…" with epistemic marker |
| Abbreviation in section title / contribution bullet | 4 | Spell out the full descriptive name |
| Findings phrased as questions | 4 | Flip to declarative claims |
| Exact numbers in intro | 4 | Replace with qualitative shape ("across N benchmarks") |
| Section requires reading §1 to make sense | 5 | Add local motivation; make self-contained |
| Experiment design feels surprising to reader | 5 | Add build-up paragraph that makes the design feel inevitable |
| Paragraph serves big picture only implicitly | 5 | Add one connecting sentence to the section's claim |
| Project-internal jargon without definition | 5 | Define at first use or replace with descriptive term |

For worked examples behind axes 1–3, see `references/anti-patterns.md`.

## References

- `references/anti-patterns.md` — stylized v1 paragraphs and their five-axis diagnosis
- SPJ: <https://simon.peytonjones.org/great-research-paper/>
- WritingAIPaper handbook: <https://github.com/hzwer/WritingAIPaper>

## Acknowledgements

Axes 1–3 distilled from repeated review comments by Yinghao Xu. Axes 4–5 distilled from paper revision feedback by Ceyuan Yang.
