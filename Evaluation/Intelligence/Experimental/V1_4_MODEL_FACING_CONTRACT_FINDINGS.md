# Intelligence V1.4 — Model-Facing Proposal Contract Investigation Findings

EXPERIMENTAL evidence only. Not production Intelligence behavior. Does not
change `Sources/Fluid/Intelligence/` (V1.0/V1.1/V1.2 remain completely
unmodified and authoritative). This document is a findings report, not a
production design decision.

## Repository starting state

- Branch `main`, `HEAD` `b84bd26560c413c97fa2bb8786325cf24e064aa0` ("Record
  Intelligence model capability findings"), clean working tree, 26 ahead of
  `origin/main` / 0 behind, nothing pushed. Verified directly with Git
  before any work began; matched exactly.

## Research question

*What is the minimum information a model must provide so deterministic
PratiLekh code can unambiguously identify the intended edit against
immutable source text?*

No schema was assumed before testing. A general resolver (below) was built
that can honor several optional discriminator fields at once, so the same
deterministic logic could be exercised under different "which fields does
this candidate actually populate" disciplines -- that is how the minimum
was investigated, rather than picking one schema and checking if it works.

## Candidate representations tested

- **A — exact source only** (`sourceText`, `replacementText`).
- **B — exact source + occurrence** (adds a 1-based ordinal).
- **C — exact source + exact context** (adds `leftContext`/`rightContext`).
- **D — insertion anchor** (`anchorText` + `anchorSide`, or `atStart`/`atEnd`
  booleans for absolute source boundaries).
- **Multi-edit** — an array-of-proposals wrapper, tested both without and
  with per-item disambiguation fields.
- Candidate E (zero-edit representation) was observed empirically rather
  than separately engineered: both "identical sourceText/replacementText"
  and "no tool call at all" were observed as real model behaviors for a
  correct-as-is input (see below).

## Exact model/runtime used

`granite4:3b` (IBM Granite 4, 3.4B parameters, Q4_K_M, digest-verified in
V1.3C) via local Ollama `0.34.4`, OpenAI-compatible `/v1/chat/completions`
endpoint, cloud explicitly disabled and reverified before this milestone's
inference began. Fixed throughout: `temperature: 0`, `seed: 42`,
`num_ctx: 2048`. No other model was downloaded or tested, per instructions
-- the model capability ladder was not resumed.

## Deterministic resolver semantics tested (no Ollama required)

`Evaluation/Intelligence/Experimental/V1_4_ModelFacingResolver.swift`
implements one general `resolveReference` function honoring all of:
exact-substring search (never fuzzy, never case-folded, never
Unicode-normalized), 1-based occurrence disambiguation, exact left/right
context disambiguation, anchor-based insertion (before/after), and absolute
start/end boundary insertion. `V14ResolverTests.swift` (22 deterministic
`precondition`-based checks, run via
`scripts/test_v1_4_experimental_resolver.sh`, **all passing, zero Ollama
dependency**) proves, independent of any model:

- unique replacement and deletion resolve correctly;
- insertion before/after an anchor, and at absolute start/end, resolve
  correctly;
- repeated source text is correctly rejected as ambiguous under Candidate A
  (no discriminator), and correctly resolved under Candidate B (occurrence)
  and Candidate C (context);
- context that does **not** actually distinguish repeated occurrences
  still fails closed -- context is a discriminator, not a promotion to
  "resolve somehow";
- hallucinated/nonexistent source text is rejected (`zeroOccurrences`);
  a context claim that doesn't match anywhere is rejected distinctly
  (`contextMismatch`);
- Odia/Indic text, a genuine non-BMP emoji surrogate pair, and mixed
  ASCII/Indic/emoji text all resolve to the exact correct UTF-16 range --
  including insertion immediately after a surrogate pair landing past both
  UTF-16 units, and insertion after an Odia word correctly counting through
  its 6 UTF-16 units first;
- multiple independent edits resolve correctly and are confirmed
  non-overlapping;
- an explicit overlap case and an explicit same-range-conflict case are
  both correctly flagged by `detectOverlaps` -- never silently merged, never
  resolved by array order;
- **immutable-source semantics are structurally guaranteed, not just
  tested empirically**: `resolveBatch` takes the same immutable `source`
  for every proposal in a call, and reversing the proposal array order
  produces identical resolved ranges for both proposals -- resolution
  cannot depend on "what came before" in the batch;
- an anchor that itself repeats is rejected (`anchorAmbiguousOccurrences`);
  a missing anchor is rejected (`anchorZeroOccurrences`); an invalid
  ordinal is rejected (`invalidOrdinal`); a fully empty reference is
  rejected (`emptyReference`).

Two of these tests route resolved proposals through the **real, unmodified
committed `IntelligenceSafetyAuthority`** (not a reimplementation):

- A proposal resolved via a **minimal-diff anchor insertion** (comma
  inserted immediately after "invoked", not touching "Section 302 IPC" at
  all) is **autonomously accepted** as a safe punctuation-only edit, even
  though a `.deterministicallyResolved` protected span exists earlier in
  the same sentence. This is the capability V1.3C's whole-segment approach
  could not express -- proof that exact, narrow addressing lets safe edits
  coexist with protected content in the same sentence, which whole-segment
  replacement cannot do.
- A second proposal whose resolved range *does* intersect that protected
  span is rejected outright (`.intersectsResolvedSpan`), regardless of
  content -- confirming textual addressing does not bypass protected-span
  safety semantics.
- A separately resolved, perfectly unambiguous lexical substitution
  ("done" → "did") is rejected by the real Safety Authority
  (`.unsupportedEditCategory`) -- confirming successful resolution is
  categorically not permission to apply an edit.

## Granite live-model experiment results (raw)

All attempts below are single-shot (not repeated 5x each, given this
milestone's focus on contract-design signal rather than statistical
reliability -- V1.3C already established `granite4:3b`'s baseline
reliability at 25/25 on simpler schemas). Distinguishing, per instructions:
(1) tool/protocol engagement, (2) contract compliance, (3)
resolution outcome (computed from the real resolver/hand-traced), and,
where applicable, (4) Safety Authority disposition.

| Case | Engagement | Compliance | Resolution | Notes |
|---|---|---|---|---|
| **LA1** — Candidate A, insertion, no anchor field available | tool called | valid (2 required fields present) | resolves (whole-sentence unique match) | Model expressed insertion by echoing the WHOLE sentence as `sourceText` and the corrected whole sentence as `replacementText` -- the same whole-segment strategy V1.3C observed. Structurally valid and resolvable, but only because the sentence itself is unique in isolation; this strategy does not scale to longer passages. |
| **LA2** — Candidate A, repeated text, asked to edit the *second* occurrence specifically | tool called | valid | resolves, but **to the wrong intended target** | With no occurrence/context field available, the model silently defaulted to editing near the first occurrence and additionally inserted an unrequested comma. This is not a resolver failure -- the resolver would have bound this proposal exactly where the model pointed it -- it is direct evidence that Candidate A **cannot express** "which occurrence" at all; the model's own output quietly ignored the explicit instruction it could not satisfy through the schema. |
| **LB1** — Candidate B/C, repeated text, asked for the *second* occurrence | tool called | valid | `occurrence: 2` correctly identifies the intended target; **`leftContext` supplied is over-broad** (`"the accused said"`, which spans back past the first occurrence rather than the immediately-adjacent text) | The model correctly used the `occurrence` field. It also volunteered a `leftContext` value that violates the "immediately adjacent" contract this resolver enforces. Applying the resolver's actual precedence (occurrence narrows first, then context is applied as an *additional* filter on the survivor) means this specific combination would need the resolver to tolerate a redundant, non-adjacent context value gracefully rather than treating it as a second, stricter constraint -- an open question, not yet resolved here (see below). |
| **LB2** — Candidate B/C, repeated text, no correction actually needed | tool called | valid | correct no-op (`sourceText == replacementText`), `occurrence: 1` supplied even though harmless for a no-op | Correct zero-edit behavior, expressed via identical source/replacement text plus a (here unnecessary but harmless) occurrence value. |
| **LD1** — Candidate D, mid-sentence insertion via anchor | tool called | valid (`anchorText`, `anchorSide` both present and correct) | resolves correctly | The model chose `insertedText: "."` where a comma would arguably be the better real-world punctuation choice -- a proposal-*quality* issue, not a schema or resolution issue; the anchor mechanism itself was used correctly. |
| **LD2** — Candidate D, end-of-sentence insertion | tool called | valid | resolves correctly, to the true end of source | The model did **not** use the `atEnd` boolean provided for exactly this purpose (it explicitly set `atEnd: false`); instead it anchored on the **entire sentence** and inserted "after" it -- which is functionally equivalent and resolves to the identical location. Evidence that a model may not use a convenience field even when offered one, but can still express the same intent through a more general mechanism. |
| **LM1 (first attempt)** — multi-edit array, vague instructions | tool called | **non-compliant** — required `sourceText` field omitted from the only array entry, and only one entry was produced instead of two independent edits | not resolvable (missing field) | A genuine contract-compliance failure for the multi-edit array shape under loosely-specified instructions. |
| **LM1 (retry, explicit instructions)** — multi-edit array, precisely specified | tool called | valid (2 entries, both required fields present) | **both entries resolve to the same ambiguous target** (`sourceText: "the"`, no occurrence/context on either) | "the" occurs 3 times in the supplied source (verified by direct string search). With no per-item disambiguator, both proposed edits would be rejected as `ambiguousOccurrences(3)` by the resolver. This is decisive evidence that a multi-edit array wrapper does **not** by itself solve the addressing-ambiguity problem -- each array item needs the same occurrence/context capability a single proposal needs. |

## Unicode results

Covered entirely in the deterministic resolver tests (no live-model Unicode
test was run this milestone, since V1.3C already exercised Odia/emoji
against real Granite output and the deterministic tests here isolate the
*addressing* question specifically): exact resolution and correct UTF-16
range derivation confirmed for Odia/Indic text, a genuine non-BMP
surrogate-pair emoji, and mixed Indic+emoji+ASCII source, including
insertion immediately following each.

## Repeated-text / ambiguity results

The clearest, most decisive finding of this milestone: **Candidate A alone
cannot express which repeated occurrence is intended, and a real model
using Candidate A silently defaults to an unintended target rather than
signaling the ambiguity itself** (LA2). Candidate B (occurrence) and
Candidate C (context) both deterministically resolve the same case when
the model supplies the relevant field, and the model *can* supply an
occurrence value correctly (LB1) -- but may also supply an imprecise
context value alongside it, which the deterministic tests show the
resolver's own logic (context as an independent filter applied after
occurrence) does not yet gracefully handle when the two discriminators are
redundant but not both maximally precise. This is recorded as an open
resolver-design question, not resolved by this milestone.

## Insertion results

Both the anchor mechanism (before/after) and the absolute boundary flags
(`atStart`/`atEnd`) resolve correctly in the deterministic tests. Live
model evidence (LD1, LD2) shows Granite can use the anchor mechanism
correctly for both mid-sentence and end-of-sentence insertion, including
substituting a whole-sentence anchor for an explicit end-of-source flag it
was offered but chose not to use.

## Multi-edit / overlap / conflict results

Deterministically: multiple independent edits resolve correctly and are
confirmed non-overlapping; an explicit overlap case and an explicit
same-range conflict case are both flagged by `detectOverlaps`, never
silently merged. Live model evidence shows a genuine compliance risk for
multi-edit schemas specifically: without an explicit, precise instruction,
Granite may omit required per-item fields (LM1 first attempt); even once
compliant, it does not automatically supply per-item disambiguation for
repeated short target strings (LM1 retry) -- the resolver would correctly
reject both entries in that retry as ambiguous, which is safe (fails
closed) but means the model's proposal would be entirely useless as
submitted, not partially useful.

## Protected-span / Safety Authority results

Both tested through the real, unmodified `IntelligenceSafetyAuthority`: a
minimal-diff proposal resolved via anchor addressing, positioned entirely
outside a protected span despite the span existing earlier in the same
sentence, is autonomously accepted; a proposal whose resolved range
intersects the protected span is rejected outright regardless of content.
This directly demonstrates the architectural advantage minimal-diff
addressing has over V1.3C's whole-segment approach for protected-content
coexistence, while confirming textual addressing does not weaken the
protected-span safety semantics in any way.

## Observed failure examples worth remembering

1. Model silently ignores an explicit instruction it has no schema field to
   satisfy (LA2), rather than declining or asking for clarification.
2. Model supplies a correct disambiguator (`occurrence`) alongside an
   imprecise, non-adjacent one (`leftContext`) in the same proposal (LB1).
3. Model chooses a general-purpose mechanism (whole-sentence anchor) over a
   more specific convenience field it was offered (`atEnd`) for the exact
   case that field exists for (LD2).
4. Model omits a required field entirely under loosely-specified
   instructions, but complies once instructions are explicit (LM1 first
   attempt vs. retry) -- consistent with V1.3C's general observation that
   Granite's compliance is sensitive to instruction precision, unlike
   Qwen2.5's total non-engagement regardless of framing.
5. Model produces a compliant multi-edit array whose individual entries are
   still unresolvable due to unaddressed repeated-text ambiguity (LM1
   retry) -- proving array-level compliance and item-level resolvability
   are independent properties that must both be evaluated.

## Contract trade-offs (no blended score; explained directly)

- **Candidate A** is the smallest representation and is sufficient for
  unique, single-occurrence edits and insertion-by-whole-segment-echo, but
  cannot express "which occurrence" at all -- and, per LA2, a model may
  silently violate instructions it can't satisfy through the schema rather
  than surfacing the ambiguity. Not sufficient alone for a system that must
  handle repeated common words/punctuation, which judicial dictation will.
- **Candidate B (occurrence)** adds minimal schema surface and was used
  correctly by Granite in the one case tested, but requires the model to
  *count* occurrences correctly across the passage -- an arithmetic-like
  burden analogous to (if smaller than) the UTF-16 offset problem this
  investigation exists to avoid. Not yet stress-tested for counting
  reliability at scale.
- **Candidate C (context)** is more "natural" for a model to supply (local
  textual context rather than a count) and was also demonstrated, but this
  milestone surfaced a real open question: what should the resolver do
  when a supplied context value is directionally correct but not maximally
  precise (LB1)? A production contract choosing this candidate needs an
  explicit answer, not an implicit one.
- **Candidate D (anchor insertion)** worked correctly in both tested cases
  and degrades gracefully to a more general mechanism when a convenience
  field is unused (LD2) -- the anchor concept appears robust for insertion
  specifically.
- **Multi-edit arrays** introduce a real, distinct compliance risk (missing
  required fields under vague instructions) *and* do not by themselves
  solve per-item addressing ambiguity -- whichever single-proposal
  candidate is chosen, its disambiguation fields need to be repeated at
  the per-item level for a multi-edit contract, not assumed solved by the
  array wrapper.
- Across every candidate and every case, **UTF-16 arithmetic was never
  required of the model**, and the deterministic resolver correctly
  derived exact UTF-16 ranges in every Unicode case tested, including a
  genuine surrogate pair -- directly supporting the working hypothesis
  that the model can identify *what* should change while PratiLekh
  deterministically determines *where*.

## Supported conclusions

- A bare exact-source/replacement representation (Candidate A) is provably
  insufficient for repeated text, and a real model's behavior under that
  insufficiency is to silently produce an incorrect result rather than
  signal the gap -- this is a contract-design limitation, not a model
  failure, since the schema gave it no way to express the correct answer.
- Both occurrence (Candidate B) and context (Candidate C) discriminators
  are independently sufficient to resolve repeated-text ambiguity
  deterministically, and Granite 4 3B can supply at least the occurrence
  form correctly in the one case tested here.
- Anchor-based insertion addressing (Candidate D) works correctly and is
  robust to a model choosing an alternate-but-equivalent way of expressing
  the same intent.
- Deterministic resolution of exact model-facing references into correct
  internal UTF-16 coordinates is fully supported, including for Odia/Indic
  text and non-BMP emoji, without requiring the model to perform any
  UTF-16 arithmetic itself.
- The deterministic resolver and the real, unmodified V1.0 Safety Authority
  compose correctly: minimal-diff addressing allows safe edits to coexist
  with protected content in the same sentence (an improvement V1.3C's
  whole-segment approach could not offer), while protected-span
  intersection and lexical-mutation rejection both remain fully intact.
- Multi-edit array schemas introduce their own, independent compliance and
  addressing risks that are not automatically solved by adding an array
  wrapper around a single-proposal shape.

## Unsupported conclusions (explicitly not established)

- This milestone does **not** establish which exact contract (B vs. C, or
  a combination) is best for production -- both worked in the one case
  each was tested against; neither was stress-tested at volume, under
  repeated occurrence counts beyond two, or across a broad fixture set the
  way V1.3C tested engagement/compliance.
- It does **not** establish how the resolver should behave when a model
  supplies multiple discriminators that partially disagree (LB1's
  imprecise-but-correct-direction `leftContext` alongside a correct
  `occurrence`) -- this is flagged as an open question, not answered.
- It does **not** establish multi-edit reliability at scale -- only two
  live attempts were made, one non-compliant and one compliant-but-still-
  ambiguous.
- It does **not** establish legal-domain quality, Indian proper-noun
  handling, or any correction precision/recall claim -- out of scope for
  this milestone by design.
- It does **not** prove any candidate is safe "in general" -- this is
  additional targeted evidence (deterministic tests plus a modest number
  of live-model probes), not a safety proof.

## Recommended model-facing contract

**The evidence does not yet justify selecting one final contract, and this
report does not force a winner.** What it does support: a production
contract should combine (a) exact `sourceText`/`replacementText` as the
core (Candidate A), (b) at least one repeated-text disambiguator --
`occurrence` and/or `leftContext`/`rightContext` (Candidates B/C), with
the redundant-discriminator resolver-precedence question above resolved
explicitly before adoption, (c) an anchor-based insertion mechanism
(Candidate D) rather than requiring an empty-string sentinel for pure
insertions, and (d) explicit, precise per-array-item instructions and
disambiguation fields if a multi-edit array shape is adopted at all. None
of this is a finalized schema -- it is a shortlist of components this
milestone's evidence supports, still requiring a dedicated design pass and
broader testing before being written into any production contract.

## Open questions

1. How should the resolver handle a supplied `occurrence` and a supplied
   `leftContext`/`rightContext` that disagree in precision (correct
   direction, wrong exact boundary)? Reject as a mismatch, prefer
   `occurrence`, or something else -- not decided here.
2. Does Granite (or any future candidate model) reliably *count*
   occurrences correctly at higher repeat-counts (3+, not just 2) and
   across longer passages closer to real dictation length?
3. Does per-item disambiguation, if added to a multi-edit array schema,
   actually resolve the ambiguity observed in LM1's retry, or introduce its
   own new compliance failures at that added complexity?
4. Should insertion prefer the anchor mechanism universally (as LD2
   suggests a model may default to it anyway), and drop the `atStart`/
   `atEnd` convenience fields entirely, or keep them for cases with no
   good nearby anchor (e.g., an empty source)?
5. This milestone used single-shot live-model attempts per case, not
   V1.3-style repeated trials -- reliability *rates* for any candidate
   remain unmeasured; only existence-of-capability was shown.

## Recommended next milestone

A dedicated, repeated-trial (V1.3-style, 5+ attempts per condition)
comparison of Candidate B vs. Candidate C vs. a combined B+C representation
against a broader repeated-text/insertion/multi-edit corpus, specifically
targeting open questions 1-3 above, before any production contract
proposal is written. This should remain an experimental investigation
under `Evaluation/Intelligence/Experimental/`, not a production
implementation milestone.

## Repository state at completion

See the final report for exact `git diff --stat` / `git status --short`.
No files were staged as part of this milestone; everything remains
uncommitted and unstaged for architectural review, per instructions.
