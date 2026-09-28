# Intelligence V1.4B — Addressing Contract Selection Findings

EXPERIMENTAL evidence only. Not production Intelligence behavior. Does not
change `Sources/Fluid/Intelligence/` (V1.0/V1.1/V1.2 remain completely
unmodified and authoritative).

## Verified starting repository state

Branch `main`, `HEAD` `b84bd26560c413c97fa2bb8786325cf24e064aa0`, 26 ahead
of `origin/main` / 0 behind, nothing pushed. The three expected uncommitted
V1.4 artifacts (`V1_4_ModelFacingResolver.swift`, `V14ResolverTests.swift`,
`V1_4_MODEL_FACING_CONTRACT_FINDINGS.md`) were present and untouched; the
gitignored `scripts/test_v1_4_experimental_resolver.sh` was present on disk
as expected. All verified directly with Git before any work began; matched
exactly. Nothing was deleted, reset, stashed, or overwritten.

## Inherited V1.4 findings (not reopened)

Exact-source resolution, UTF-16 derivation (including Odia/emoji), anchor
insertion, absolute-boundary insertion, fail-closed ambiguity/zero-match/
context-mismatch, overlap/conflict detection, and immutable-source
semantics for multi-edit batches were all established in V1.4 and are
treated as settled unless new evidence directly contradicts them. **No
contradiction was found in V1.4B.** Candidate A remains established as
insufficient alone for repeated text (reconfirmed as a regression guard,
not re-litigated).

## Exact V1.4B research questions

Q1 (occurrence reliability), Q2 (context reliability), Q3 (combined B+C
reliability and redundancy value), Q4 (contradictory-discriminator
semantics) -- see below for each, answered with raw counts.

## Candidate contracts tested

- **B**: `sourceText`, `replacementText`, optional `occurrence` (1-based,
  per schema description).
- **C**: `sourceText`, `replacementText`, optional `leftContext`/
  `rightContext`.
- **B+C**: all of the above fields available simultaneously.

## Exact model/runtime used

`granite4:3b` via local Ollama `0.34.4`, OpenAI-compatible endpoint, cloud
disabled and reverified before inference. `temperature: 0`, `num_ctx: 2048`,
`seed` varied 42/43/44 across the 3 trials per condition (to get genuine
independent samples rather than byte-identical repeats at a fixed seed).
No other model was downloaded; the V1.3 model ladder was not resumed.

## Fixed fixture corpus (defined before execution; ground truth independent of model output)

| ID | Repetition | Category | Target | Intended occurrence/position |
|---|---:|---|---|---|
| REP2_R1_last | 2 | R1 easy, distinct context | `"the witness"` | 2nd (last) |
| REP2_R1_first | 2 | R1 easy, distinct context | `"the witness"` | 1st |
| REP3_R2_middle | 3 | R2 similar context | `"the accused"` | 2nd (middle) |
| REP3_R3_first | 3 | R3 distant discriminator (1st/2nd occurrences share identical immediate neighbors) | `"the witness paused"` | 1st |
| REP5_R4_middle | 5 | R4 adversarial list (occurrences 1-3 share identical neighbors) | `"the item"` | 3rd (middle) |
| REP10_R1_nonedge | 10 | R1 easy, distinct context, high count | `"the item"` | 7th (non-edge) |
| REP2_R5_odia | 2 | R5 Unicode (Odia), insertion | Odia place name | 2nd (last) |
| REP2_R5_emoji | 2 | R5 Unicode (emoji), insertion | 😊 (non-BMP) | 1st |
| UNIQUE_1, UNIQUE_2 | 1 (unique) | control | n/a | n/a |
| MULTIEDIT | mixed (2 repeated + 1 unique) | confirmatory probe | n/a | n/a |

A bounded reduction was applied per the milestone's own allowance: 3 trials
per condition (not 5), and one representative target-position combination
per repetition level/category rather than the full position cross-product,
given the number of dimensions already covered (8 fixtures × 3 candidates
× 3 trials = 72 live calls for the core matrix, plus 18 for unique-target
controls and 3 for the multi-edit probe = 93 total live interactions).
This is documented here as required, not silently reduced.

## Trial methodology

Each trial was an independent, fresh single-turn interaction (no
conversational carry-over, no teaching from prior failures). The same
instructions were used for every trial of the same candidate/fixture pair,
varying only the seed. Malformed/incomplete model output was never
silently repaired before evaluation.

## Raw results -- protocol engagement and structural compliance

72/72 core-matrix calls engaged the tool mechanism except exactly one
condition: **`REP2_R5_emoji` under Candidate C engaged 0/3 times** (the
model produced no tool call at all, all 3 trials, for the emoji-insertion
task specifically under the context-only schema). Every other condition
(71/72) engaged 3/3. Structural compliance (both required fields present)
was violated in exactly one further condition: `REP2_R5_odia` under
Candidate B supplied a correct `sourceText` but **omitted the required
`replacementText` field entirely**, 3/3 trials.

## Q1 -- Occurrence (Candidate B) reliability, by repetition level

Restricting to the 4 fixtures where the model targeted the genuinely
repeated **short fragment** directly (not a whole-segment workaround --
see below): `REP2_R1_last`, `REP2_R1_first`, `REP3_R3_first`,
`REP5_R4_middle` -- **Candidate B correctly resolved 4/4 (100%)**, with the
correct occurrence value supplied in every trial (occurrence 2, 1, 1, and 3
respectively, matching the true 1-based positions exactly).

On the two fixtures where the model instead expressed `sourceText` as an
**entire, already-unique clause/sentence** (`REP3_R2_middle`,
`REP10_R1_nonedge`) rather than the short repeated fragment, the supplied
`occurrence` value did not correspond to "which occurrence of this exact
string" (the schema's literal definition) but appeared to reflect "which
numbered line/sentence in the passage" -- since the whole-clause string is
already unique (1 occurrence), any `occurrence` value other than 1 is
out-of-range, and the model supplied `occurrence: 2` and `occurrence: 7`
respectively (matching the sentence's ordinal position in the prose, not
the string's own occurrence count). Both were correctly rejected
(`invalidOrdinal`) -- a safe rejection, but a compliance/precision issue,
not a resolver defect.

**No repetition-level degradation was observed within the genuine
short-fragment subset** (correct at repetition 2 and 3 and 5 -- the
non-edge, high-repetition case, `REP10_R1_nonedge`, only failed under B
because the model chose the whole-clause strategy there, not because
occurrence-counting itself degraded at 10 repetitions).

## Q2 -- Exact-context (Candidate C) reliability, by repetition level

**Candidate C resolved 0/4 of the genuine short-fragment cases correctly.**
Classified precisely:

- `REP2_R1_last`: `contextMismatch` -- context supplied did not exactly
  match the literal source.
- `REP2_R1_first`: `contextMismatch`.
- `REP3_R3_first` (the deliberately hard R3 case, adjacent occurrences with
  identical immediate neighbors): `ambiguousOccurrences(2)` -- the model
  did not supply context precise/extensive enough to distinguish the first
  two occurrences (a correct, safe outcome for a genuinely hard case, but
  still a failure to produce a usable proposal).
- `REP5_R4_middle`: `contextMismatch`.

On the two whole-clause-workaround fixtures, Candidate C fared better:
`REP3_R2_middle` resolved correctly (the model's `leftContext`/
`rightContext` were the full neighboring sentences and matched exactly),
while `REP10_R1_nonedge` still failed (`contextMismatch`). Both of these
"successes" are attributable to the model sidestepping short-fragment
addressing entirely, not to genuine short-fragment context disambiguation.

**Context reliability did not clearly improve or degrade across repetition
levels within this sample -- it was uniformly unreliable for genuine
short-fragment targeting at every repetition level tested (2, 3, 5).**

## Q3 -- Combined B+C reliability

**3/4 correct on the genuine short-fragment subset** -- one fewer than
Candidate B alone. The regression: `REP2_R1_first` under B+C supplied a
correct `occurrence: 1` (as B alone did, correctly) but *also* supplied
`rightContext: "testified about the incident"` -- missing the leading
space present in the real source (`" testified about the incident."`).
Under strict AND-composition (both discriminators must independently
match), this single missing space caused the whole proposal to be rejected
(`contextMismatch`), where Candidate B alone (without the context field
available to volunteer) would have succeeded. **This is direct evidence
that adding a redundant discriminator field can reduce reliability**, not
just add safety margin -- protocol compliance did not clearly improve with
B+C, and one concrete case shows it can degrade.

On the two whole-clause-workaround fixtures, B+C matched B's failure on
`REP3_R2_middle` (same `invalidOrdinal` cause) and uniquely *succeeded* on
`REP10_R1_nonedge` (occurrence: 1, valid because the model's whole-clause
`sourceText` was unique) -- the only condition where B+C outperformed both
B and C individually.

**Does redundancy provide useful independent evidence?** In the one case
where both discriminators were supplied and could be compared
independently against ground truth (not just against each other), the
occurrence value was consistently more precise and reliable than the
context value across every trial observed. Redundancy did not "fail
safely toward the better answer" in the `REP2_R1_first` regression --
instead, the correct discriminator (occurrence) was invalidated by the
incorrect one (context) under strict composition.

## Verification that matters most: does the resulting document end up correct?

Because raw span/start-position comparisons alone can be misleading when a
model legitimately chooses a broader (whole-clause) but still-correct
edit, every successfully-resolved proposal across the entire experiment
was independently checked by **applying it to the source and comparing the
resulting full document against the true intended corrected document**
(defined from ground truth, independent of the model). Two cases initially
flagged by a naive start-position check as "wrong location"
(`REP3_R2_middle` under C, `REP10_R1_nonedge` under B+C) were, on this
stricter check, **both confirmed to produce the exactly correct final
document** -- the model's whole-clause strategy changed nothing else in
the span, so the net result was identical to a minimal-diff edit.

**Result: every single successfully-resolved proposal in this experiment
(9/9 across all fixtures and candidates) produced the exactly correct
final document. Zero silent semantic mistargeting was observed at the
document level**, even though two cases required the stricter
whole-document check rather than a naive span comparison to confirm this.

## Q4 -- Contradictory-discriminator semantics (deterministic policy experiments)

Three explicit policies were implemented and tested deterministically (no
Ollama), each as its own separately-testable resolver path (see
`V1_4B_PolicyExperiments.swift` / `V14BResolverTests.swift`, 9 new
passing tests):

- **P1 (strict agreement)**: both discriminators must independently
  resolve, and to the *same* location, or the whole proposal is rejected.
  Tested: agreement resolves; a genuine contradiction (`occurrence`
  pointing to one location, `context` uniquely identifying a different
  one) is rejected; occurrence-valid/context-invalid is rejected;
  context-valid/occurrence-invalid is rejected; both-invalid is rejected.
- **P2 (occurrence-primary, optional corroboration)**: only `occurrence`'s
  own success/failure decides the outcome; context is checked but never
  overrides. Tested: this policy resolves to the *occurrence-indicated*
  location even when supplied context uniquely disagrees and points
  elsewhere -- confirmed directly, by construction, that P2 carries a real
  silent-mistargeting risk whenever the two discriminators genuinely
  disagree. It also resolves when occurrence is valid and context is
  invalid, but rejects (without even inspecting context) whenever
  occurrence itself is invalid -- even in cases where context alone would
  have resolved correctly.
- **P3 (discriminator fallback)**: if either discriminator alone resolves
  and the other fails, accept the one that resolved. If both resolve but
  disagree, this implementation still rejects rather than guessing (tested
  explicitly) -- the "fallback" applies only when exactly one discriminator
  is usable, not as a tiebreaker between two disagreeing valid answers.

**The default fail-closed hypothesis (reject rather than choose between
disagreeing discriminators) was validated as achievable without giving up
useful fallback behavior**: P3 recovers both "occurrence valid, context
broken" and "context valid, occurrence broken" cases (both observed as
real live-model behavior in Q3/Q1 above) while still refusing to guess on
a genuine two-valid-but-disagreeing contradiction, exactly like P1 does for
that specific case. P2 was the only policy shown to carry an unrejected
silent-mistargeting risk, and is not recommended.

## Unicode results

Both Unicode fixtures were substantially worse than the ASCII fixtures,
**independent of the B/C/B+C choice** -- this is a Unicode-reproduction
problem, not an addressing-contract problem:

- `REP2_R5_odia` under Candidate B: the model reproduced the Odia text in
  `sourceText` **correctly**, but omitted the required `replacementText`
  field entirely (a structural compliance failure). Under Candidates C and
  B+C, the model instead produced an unrelated, garbled non-Odia string
  for `sourceText` (a hallucination, similar to a failure mode already
  observed in V1.3C) -- correctly rejected (`zeroOccurrences`) in both
  cases.
- `REP2_R5_emoji`: under Candidate B and B+C, the emoji was **reproduced
  as two literal newline characters** in the model's JSON output instead
  of the actual glyph -- a specific, reproducible corruption pattern, not
  ordinary hallucination -- correctly rejected (`zeroOccurrences`) in both
  cases. Under Candidate C, the model did not call the tool at all (0/3),
  the only complete non-engagement observed in the whole experiment.

**No unsafe outcome resulted from either Unicode fixture under any
candidate** -- every failure mode here was safely caught by structural
compliance checking or exact-match rejection. But Unicode input reliability
itself remains a real, unresolved concern for this model, independent of
which addressing contract is chosen.

## Unique-target control results

All 6 conditions (2 fixtures × 3 candidates), 3 trials each: **100%
compliant, and the model never volunteered an unnecessary discriminator**
when the target was already unique -- `occurrence`/`leftContext`/
`rightContext` were correctly omitted in every trial, for every candidate
schema offered. This directly supports allowing (not requiring) these
fields to be omitted when `sourceText` alone already resolves uniquely.

## Multi-edit probe

3/3 trials engaged the tool and produced a 2-item array with both required
fields present in every entry (a regression from V1.4's first, vaguely-
instructed attempt, which had omitted a required field -- explicit
per-item instructions resolved that specific compliance issue, consistent
with V1.3's general finding that Granite's compliance is sensitive to
instruction precision). However, **all 3 trials used `occurrence: 0` for
the first target's index instead of the schema's specified 1-based
convention** (`occurrence: 1` for the correctly-resolved second target).
Under the resolver's strict 1-based semantics, this caused the first
edit's proposal to be rejected (`invalidOrdinal`) in all 3 trials, while
the second edit (unique target, occurrence largely irrelevant but still
supplied as `1`, correctly) resolved successfully every time. **This is a
convention-precision failure, not an addressing-capability failure**: the
model's *intent* (target the first occurrence) was correct; the *encoding*
of that intent (0-based vs. the specified 1-based) was not. Both proposals
resolved against the same immutable original source regardless of
application order (confirmed structurally, matching V1.4's guarantee) --
immutable-source semantics compose correctly across multi-edit items with
their own discriminators.

## Safety Authority regression check

A representative subset (3 of the 9 successfully-resolved live-Granite
proposals, spanning both genuine short-fragment and whole-clause-strategy
cases) was routed through the real, unmodified `IntelligenceSafetyAuthority`.
All 3 were correctly classified `autonomouslyAccepted(.capitalizationOnly)`
-- including the whole-clause `REP10_R1_nonedge` case, confirming the real
classifier correctly derives the true edit category (capitalization-only)
even when the resolved span is broader than the minimal diff.

## Unsafe accepted edits count

**0** -- across the entire V1.4B investigation: the deterministic policy
tests, the resulting-document verification of all 9 successfully-resolved
live proposals, and the 3-case Safety Authority regression check.

## Observed failure examples worth remembering

1. A model may express `sourceText` as an entire clause/sentence rather
   than a short fragment, sidestepping the repeated-text problem by making
   its own reference trivially unique -- but then supply an `occurrence`
   value reflecting the clause's *position in the prose* rather than the
   schema's literal "which occurrence of this exact string" definition,
   causing an otherwise-fine proposal to be rejected as `invalidOrdinal`.
2. A single missing leading space in a supplied `rightContext` value
   converted an otherwise-correct B+C proposal into a rejected one, even
   though the accompanying `occurrence` value was independently correct.
3. Odia text can be reproduced correctly in `sourceText` while the
   `replacementText` field is dropped entirely -- a compliance failure
   independent of Unicode correctness itself.
4. A non-BMP emoji was reproduced as two literal newline characters in
   JSON output -- a specific, reproducible corruption pattern distinct
   from ordinary text hallucination.
5. A 0-based vs. 1-based occurrence convention mismatch, applied
   consistently across 3 independent trials, shows this is not
   trial-to-trial noise but a stable (if incorrect, relative to the
   specified schema) convention the model applied.

## B+C policy comparison (P1 / P2 / P3)

No blended score. Trade-offs, directly:

- **P1 (strict agreement)** is the safest: it never accepts a disagreement,
  at the cost of rejecting cases where one discriminator is simply wrong
  and the other is right (a usability cost, not a safety cost).
- **P2 (occurrence-primary)** is the least safe of the three: it can
  silently resolve to the occurrence-indicated location even when a
  uniquely-resolving context value disagrees, with no signal that a
  disagreement occurred at all.
- **P3 (discriminator fallback)** captures P1's safety on genuine
  contradictions (both valid, disagreeing → reject) while additionally
  recovering the "one discriminator broken, the other fine" cases observed
  as real live-model behavior in this experiment (`REP2_R1_first`'s B+C
  regression, and `REP10_R1_nonedge`'s occurrence-only success) --
  **P3 is the only policy of the three that would have recovered
  `REP2_R1_first`'s real observed B+C failure without weakening rejection
  of genuine contradictions.**

## Candidate C context-semantics findings

No clean bounded-context rule emerged from this experiment. The model's
supplied context length varied enormously across trials -- from a single
adjacent word to an entire neighboring sentence -- with no evidence it was
solving a "minimum sufficient context" optimization; it appeared to supply
whatever came to hand (often the entire rest of an adjacent sentence),
and even then frequently got the exact boundary wrong (a missing or
mismatched space, in particular). **This is recorded as a disadvantage of
Candidate C as tested**: without an explicit, enforced bounded-context
rule (which this experiment did not define or test, per instructions not
to force an optimization the model wasn't shown capable of), context
reliability for genuine short-fragment disambiguation was poor (0/4).

## Contract-complexity trade-offs

- **B** is the simplest schema addition (one optional integer field) and
  showed the highest genuine short-fragment reliability (4/4) in this
  sample.
- **C** adds two optional string fields and showed no genuine short-
  fragment reliability (0/4) in this sample, plus the only complete
  non-engagement observed (Unicode/emoji case).
- **B+C** adds all three fields and showed no reliability improvement over
  B alone on genuine short-fragment cases (3/4, one regression), with its
  only net gain confined to a whole-clause-workaround case that B and C
  each separately failed for different reasons.

## Supported conclusions

- Occurrence (Candidate B) is more reliable than exact context (Candidate
  C) for genuine short-fragment repeated-text disambiguation in this
  sample: 4/4 vs. 0/4.
- Redundancy (B+C) does not clearly improve reliability over B alone, and
  demonstrably can reduce it when an imprecise but non-load-bearing
  context value is volunteered alongside a correct occurrence value.
- A fail-closed contradiction policy (P1 or P3) can be implemented without
  giving up useful fallback behavior; P3 specifically recovers real
  observed single-discriminator failures while still rejecting genuine
  two-valid-but-disagreeing contradictions, and is the only tested policy
  that would have recovered a real regression observed in this experiment.
- Deterministic resolution to exact UTF-16 coordinates, followed by the
  real, unmodified V1.0 Safety Authority, continues to compose correctly:
  0 unsafe accepted edits, 0 genuine document-level mistargeting, across
  every successfully-resolved proposal in this investigation.
- Model reliability is sensitive to precise field-naming conventions
  (1-based vs. 0-based occurrence) and to Unicode reproduction fidelity
  (Odia field omission; emoji-to-newline corruption) in ways independent
  of which addressing candidate is chosen.

## Unsupported conclusions (explicitly not established)

- This does **not** establish occurrence reliability at counts beyond what
  was tested when the model is actually attempting short-fragment
  targeting at high repetition (the one repetition-10 fixture happened to
  elicit a whole-clause strategy from the model rather than genuine
  10-way occurrence counting).
- This does **not** establish that Candidate C could never work with a
  differently-specified bounded-context rule -- only that, as tested
  (unbounded, model-chosen context length), it was unreliable.
- This does **not** establish general Unicode reliability conclusions
  beyond the two specific fixtures tested (one Odia, one emoji case).
- This does **not** establish legal-domain quality, precision/recall, or
  production readiness -- out of scope by design.
- This does **not** prove P1 or P3 safe "in general" -- this is targeted
  policy evidence from a bounded set of hand-constructed contradiction
  cases plus the real live-model regressions observed, not an exhaustive
  proof.

## Selected model-facing addressing contract

**Candidate B (occurrence) is selected as the primary repeated-text
discriminator**, on the evidence that it was more reliable than context in
every genuine short-fragment case tested (4/4 vs. 0/4), simpler (one
field vs. two), and did not exhibit the specific regression risk observed
when combined with context. This is Outcome 1 from the decision framework.

**Candidate C is not rejected as impossible, but is not selected as
primary**: it may still have value as optional corroboration under a
strict, non-load-bearing policy (see below), but this experiment does not
support it as the primary mechanism.

**Recommended combined semantics**: allow `leftContext`/`rightContext` to
remain in the schema as optional corroborating fields (matching
`REP10_R1_nonedge`'s and `REP3_R2_middle`'s cases where context alone or
combined with occurrence recovered a case B's strict schema-literal
reading would not have), but apply **Policy P3 (discriminator fallback,
reject on genuine two-valid contradiction)**, not P1's strict-agreement-
always-required rule and not P2's occurrence-always-wins rule. This
directly reflects the observed evidence: P3 is the only tested policy that
recovers both real observed regressions (`REP2_R1_first`'s broken context
alongside correct occurrence; a hypothetical broken-occurrence/correct-
context case, not observed live but deterministically validated) without
accepting a genuine contradiction.

## Exact deterministic semantics recommended for supplied/omitted/contradictory discriminators

1. If `sourceText` alone resolves to exactly one occurrence, resolve to it
   regardless of whether `occurrence`/context fields are present (matching
   the unique-target control's finding that fields are correctly omitted
   when unnecessary, and should not be forced).
2. If `sourceText` is ambiguous (2+ occurrences) and `occurrence` is
   supplied and valid (in range), and `leftContext`/`rightContext` are
   either absent or resolve to the *same* location as `occurrence`,
   resolve to that location.
3. If `sourceText` is ambiguous, `occurrence` is invalid or absent, and
   context resolves to exactly one location, resolve to that location
   (Policy P3's fallback).
4. If both `occurrence` and context are independently valid but resolve to
   *different* locations, reject outright (`.rejectedContradiction`) --
   never guess, never prefer one field by default.
5. If neither discriminator resolves the ambiguity, reject
   (`.rejectedBothInvalid`).
6. `occurrence` is 1-based; this must be stated explicitly and
   unambiguously in the model-facing instructions, given the observed
   0-based convention slip -- and deterministic code should not attempt to
   silently guess which convention was intended.

## Remaining open questions

1. Whether an explicit, enforced bounded-context rule (e.g., "supply
   exactly the N characters immediately before/after") would materially
   improve Candidate C's reliability -- not tested here, since this
   experiment deliberately did not force an untested optimization.
2. Whether genuine (non-whole-clause-workaround) short-fragment occurrence
   reliability holds at repetition counts of 10+ -- the one repetition-10
   fixture tested did not elicit genuine short-fragment targeting from the
   model.
3. Whether explicitly instructing the model on the 1-based convention (as
   already attempted here) more emphatically, or providing a worked
   example, resolves the observed 0-based slip -- not tested, to avoid an
   unbounded prompt-tuning loop within this milestone.
4. Whether the Unicode reproduction issues (Odia field-omission, emoji
   corruption) are specific to this model/runtime or a broader pattern --
   not investigated further here, out of this milestone's scope.
5. Whether Policy P3's fallback behavior remains safe under a larger,
   more adversarial set of contradiction cases than the ones
   hand-constructed and observed here.

## Recommended next milestone

A small, targeted follow-up validating Policy P3 specifically (not P1 or
P2) against a broader deterministic adversarial contradiction corpus, plus
one additional live-model check of whether explicit 1-based-convention
instruction (a documented worked example, not iterative prompt-tuning)
resolves the observed 0-based occurrence slip -- before any production
contract proposal is written. This remains an experimental investigation
under `Evaluation/Intelligence/Experimental/`, not production
implementation.

## Repository state at completion

See the final report for exact `git status --short`. No files were staged
as part of this milestone; everything (V1.4 and V1.4B artifacts alike)
remains uncommitted and unstaged for architectural review, per
instructions. `scripts/test_v1_4_experimental_resolver.sh` and the new
`scripts/test_v1_4b_experimental_policies.sh` both remain gitignored and
were not tracked, per instructions not to change `.gitignore` yet.
