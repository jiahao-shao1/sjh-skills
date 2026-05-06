# Anti-Patterns: Worked Examples

Stylized v1 paragraphs and their five-axis diagnosis. The examples are paraphrased, not verbatim from any specific paper, but they reproduce real failure modes seen across many drafts. Use them to calibrate severity when scanning paragraphs against the five axes in `SKILL.md`. Each case shows the v1 sketch, names the pattern, and gives the mechanical fix.

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

**Fix**: pull all four bullets out of the intro. Replace with two-clause comparisons in plain language ("with vs. without [the proposed component]; with vs. without [the auxiliary structure]"). Defer symbols and design rationale to §3.

## Axis 1 — False-parallel "First / Second / Third"

A v1 "cracks in the orthodoxy" paragraph used "First / Second / Third" to pose three findings, but all three were paraphrases of one underlying point ([X] is weak, [Y] is strong, [single-pass] works). Reviewers see this as **structural padding for emphasis weight**, not as three orthogonal claims.

**Fix**: either compress to one declarative sentence (one claim, stated once), or replace with three genuinely orthogonal claims. A list of three is only worth using if each item carries information the others do not.

## Axis 1 — One paragraph, five jumps

A v1 opening paragraph chained: "models in domain D struggle with phenomenon E" → "prior work proposes a class of methods M" → "M is usually interpreted literally" → "recent system S reports number N on benchmark B" → "but what if the underlying mechanism is different?" Five steps in one paragraph, no anchor sentence between any pair. The reader is forced to silently bridge each jump, and most do not.

**Fix**: split into multiple paragraphs, one task each. If a jump cannot be removed, write the anchor sentence that justifies it. A paragraph that needs five jumps to make its point is two or three paragraphs in disguise.

## Axis 4 — Negative framing: defining yourself by what others lack

A v1 intro paragraph reads:

> "While recent work has explored augmented inference for task X, these approaches only modify the inference pipeline without training the model to use component C. Furthermore, none of these methods examines whether component C alone carries the signal."

This is pure negative framing — two sentences saying what prior work does NOT do. The reader learns nothing positive about what this paper contributes. Worse, reviewers may see this as unfair characterization (prior work had different goals).

**Fix**: flip the polarity. State what THIS paper does: "We integrate component C directly into the training loop, and show that the intermediate representation produced during invocation — independent of the expensive external output — carries the signal." The contrast with prior work becomes implicit or a short subordinate clause ("unlike inference-only approaches").

## Axis 4 — Hypothesis presented as obvious intuition

A v1 paragraph reads:

> "The intuition behind these findings is simple: when the model invokes the external module, it has already encoded all necessary information in its intermediate representation. The external output is therefore redundant."

This is the paper's core hypothesis being presented as an established, obvious fact ("the intuition is simple"). But this is NOT established — it's what you're trying to prove. Reviewers will either (a) think you're overstating your evidence, or (b) dismiss it as trivial.

**Fix**: frame as hypothesis with epistemic marker: "We hypothesize that when the model invokes the external module, it has already encoded the necessary information in its intermediate representation. Under this hypothesis, the external output is a redundant carrier; the intermediate representation is sufficient." Then the experiments become tests of this hypothesis, not confirmations of the obvious.

## Axis 4 — Questions masquerading as findings

A v1 contribution paragraph reads:

> "We investigate: (1) Can our method transfer across model scales? (2) Does the effect remain under reinforcement learning? (3) Is the improvement consistent across diverse benchmarks?"

Three questions, zero claims. The reader cannot tell whether the answers are yes or no. Contribution lists must be declarative: the reader should know what you found, not what you asked.

**Fix**: "We show that (1) our method transfers across model scales (small → large), (2) the effect persists after RL fine-tuning, (3) improvements hold across six diverse benchmarks."

## Axis 5 — Section depends on prior sections to make sense

A v1 §3 ("Method") opens with:

> "Building on the hypothesis introduced in §1, we design three training variants..."

If the reader skipped to §3 (reviewers often do), they have no idea what "the hypothesis" refers to. The section is not self-contained — its first sentence is a forward pointer to another section.

**Fix**: §3 must re-establish its own motivation in 1–2 sentences: "When a model invokes an external tool, it produces an intermediate representation — structured reasoning, parameter specifications — before receiving the tool's output. We ask whether this intermediate representation alone carries the task-relevant information. We design three training variants to test this..." Now §3 stands alone.

## Axis 5 — Experiment feels surprising (no build-up)

A v1 reads:

> "[After two paragraphs of general motivation about augmented systems]... We therefore remove the expensive external output entirely and retrain the model with only the intermediate representation."

The reader thinks: "Wait, why would you throw away the output? What motivated this drastic ablation?" The experimental design was not foreshadowed — it lands as surprising rather than inevitable.

**Fix**: before revealing the experiment, build up the reasoning that makes it feel natural: "Since the model encodes what it needs before receiving the external output, we can test whether that output adds information by replacing it with a null placeholder. If performance is preserved, the intermediate representation — not the external output — is the load-bearing component." NOW the experiment design feels obvious to the reader. The best paper makes the reader think "I would have tried the same thing."

## Cross-axis pattern: the v1 → v2 sequence

These cases share one structure:
1. v1 tries to do too much in one paragraph (one task overloaded with three).
2. The author senses the overload and adds connective filler ("First / Second / Third", "Crucially", "Moreover") in lieu of restructuring.
3. The same headline claim leaks across paragraphs as the author tries to "make sure" the reader got it.
4. The claim is framed negatively ("no one has done X") instead of positively ("we do X").
5. The reader is expected to hold project-internal context that was never given to them.

The corrective discipline is the same in every case: **one task per paragraph, one statement of the headline claim per intro, no symbols or rationale that depend on §3 / §5 to parse, positive framing of your own contribution, and reader guidance that makes your design feel inevitable.**
