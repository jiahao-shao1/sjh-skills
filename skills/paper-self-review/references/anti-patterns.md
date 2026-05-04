# Anti-Patterns: Worked Examples

Stylized v1 paragraphs and their three-axis diagnosis. The examples are paraphrased, not verbatim from any specific paper, but they reproduce real failure modes seen across many drafts. Use them to calibrate severity when scanning paragraphs against the three axes in `SKILL.md`. Each case shows the v1 sketch, names the pattern, and gives the mechanical fix.

## Axis 2 — One claim repeated across the intro

A v1 introduction stated the same 5-word claim ("method M outperforms baseline B because of property P") four times in different paragraphs:

> Abstract: "…better explained by property P than by [the conventional account]."
> Hypothesis paragraph, sentence 1: "the load-bearing signal is P, not [the conventional account]."
> Hypothesis paragraph, sentence 2: "[the conventional account] is a redundant carrier of information…"
> Position-and-scope paragraph: same wording as the abstract, **verbatim**.

By the second occurrence the reader is already wondering "why didn't they just say it once"; by the third or fourth, reviewers start deducting points for filler.

**Fix**: keep the single strongest occurrence — usually the hypothesis paragraph (richest mechanism statement) or the abstract (headline framing). Cut the others, or rephrase them so they advance a *different* sub-claim instead of restating the headline.

## Axis 2 — Hypothesis paragraph repeats internally

The same v1 hypothesis paragraph used four consecutive sentences to make a single point. The reader does not understand more on the second sentence; they only learn "the author has not decided which version of this sentence to keep". When the same claim is restated within a paragraph, **keep one sentence — the one with the most mechanism — and delete the rest**.

## Axis 3 — Detail leak: intro paragraph turned into half a §3

A v1 "Testing the hypothesis" paragraph, sitting in the introduction, tried to deliver in one paragraph:

- The exact definition of `Method-M` ("discards [component X] and replaces it with [placeholder Y]")
- Three pairwise comparisons (`Variant-A` vs. `Variant-B`, `Variant-C` vs. `Variant-D`)
- Why `Variant-C` was designed narrow ("preserves [structural property] in a single trial")
- The theoretical reading of that narrow design ("specialized symbolic primitive rather than a generic substitute")

Volume-wise this is half of §3. At the intro stage the reader has not yet built a mental model of `Variant-A` / `Variant-B` / `Variant-C` / `Variant-D`; dropping these symbols into their lap forces them to either skip ahead or stop reading.

**Fix**: pull all four bullets out of the intro. Replace with two-clause comparisons in plain language ("with vs. without [the proposed component]; with vs. without [the structural scaffold]"). Defer symbols and design rationale to §3.

## Axis 1 — False-parallel "First / Second / Third"

A v1 "cracks in the orthodoxy" paragraph used "First / Second / Third" to pose three findings, but all three were paraphrases of one underlying point ([X] is weak, [Y] is strong, [single-pass] works). Reviewers see this as **structural padding for emphasis weight**, not as three orthogonal claims.

**Fix**: either compress to one declarative sentence (one claim, stated once), or replace with three genuinely orthogonal claims. A list of three is only worth using if each item carries information the others do not.

## Axis 1 — One paragraph, five jumps

A v1 opening paragraph chained: "models in domain D struggle with phenomenon E" → "prior work proposes a class of methods M" → "M is usually interpreted literally" → "recent system S reports number N on benchmark B" → "but what if the underlying mechanism is different?" Five steps in one paragraph, no anchor sentence between any pair. The reader is forced to silently bridge each jump, and most do not.

**Fix**: split into multiple paragraphs, one task each. If a jump cannot be removed, write the anchor sentence that justifies it. A paragraph that needs five jumps to make its point is two or three paragraphs in disguise.

## Cross-axis pattern: the v1 → v2 sequence

These cases share one structure:
1. v1 tries to do too much in one paragraph (one task overloaded with three).
2. The author senses the overload and adds connective filler ("First / Second / Third", "Crucially", "Moreover") in lieu of restructuring.
3. The same headline claim leaks across paragraphs as the author tries to "make sure" the reader got it.

The corrective discipline is the same in every case: **one task per paragraph, one statement of the headline claim per intro, no symbols or rationale that depend on §3 / §5 to parse.**
