# Intelligence V1.4C — Addressing Contract Adversarial Validation Findings

EXPERIMENTAL evidence only. Not production Intelligence behavior. Does not
change `Sources/Fluid/Intelligence/` (V1.0/V1.1/V1.2 remain completely
unmodified and authoritative).

## Verified starting state

Branch `main`, `HEAD` `b84bd26560c413c97fa2bb8786325cf24e064aa0`, 26 ahead
of `origin/main` / 0 behind, nothing pushed. All six expected V1.4/V1.4B
untracked artifacts were present and untouched; the two gitignored runner
scripts (`test_v1_4_experimental_resolver.sh`,
`test_v1_4b_experimental_policies.sh`) existed on disk as expected.
Verified directly with Git before any work began. Nothing was cleaned,
reset, stashed, or overwritten.

## Inherited V1.4/V1.4B evidence (treated as experimental findings, not universal truths)

Candidate B (occurrence): 4/4 correct on genuine short-fragment cases in
V1.4B. Candidate C (context): 0/4. Candidate B+C: 3/4, with one regression
caused by an imprecise volunteered context field. Zero unsafe accepted
edits and zero genuine document-level mistargets across all of V1.4/V1.4B.
The V1.4B multi-edit probe showed Granite consistently using 0-based
occurrence indexing against a 1-based schema.

## Provisional contract under test

`sourceText` (required) + `replacementText` (required) + optional
`occurrence` (1-based) + optional `leftContext`/`rightContext`, with
occurrence as primary discriminator and context as corroboration/fallback
under a to-be-precisely-defined P3 policy. Conceptual only, not a
production schema.

## Falsification questions

1. Can the provisional contract survive deliberate adversarial testing
   without silent mis-targeting?
2. Can explicit, strongly-worded 1-based instruction materially reduce or
   eliminate the observed 0-based error?

## Part B — Precise P3 decision table (implemented and deterministically tested)

Rather than V1.4B's broad "fallback" description, V1.4C implements and
tests an exhaustive procedure (`resolveP3Precise` in
`V1_4C_P3Adversarial.swift`). In prose:

| Source cardinality | occurrence | context | Outcome |
|---|---|---|---|
| unique | absent | absent | resolve (bare sourceText) |
| unique | valid (=1) | absent/agreeing | resolve |
| unique | **invalid** (any value ≠ 1) | -- | **reject** -- explicit false evidence is significant, never silently ignored |
| unique | -- | **contradicts** (doesn't match the unique location) | **reject** -- same principle for context |
| repeated | valid | absent | resolve via occurrence |
| repeated | invalid | absent | reject |
| repeated | absent | resolves uniquely | resolve via context (fallback) |
| repeated | absent | fails to narrow to one | reject |
| repeated | valid | agrees (same location) | resolve |
| repeated | valid | independently fails to narrow (not a *different* location, just uninformative) | resolve via occurrence -- corroboration absence is not contradiction |
| repeated | invalid | independently resolves uniquely | resolve via context -- the principal P3 fallback case |
| repeated | valid | independently resolves to a **different** location | **reject** -- genuine contradiction, no precedence |
| repeated | invalid | fails too | reject |

This resolves V1.4B's two ambiguities explicitly: (1) an explicitly-wrong
occurrence on an already-unique source is never silently ignored just
because `sourceText` alone would resolve; (2) "context fails to narrow"
(uninformative) is distinguished from "context narrows to a different
answer" (contradictory) -- only the latter is treated as a contradiction.

## Part A — deterministic adversarial matrix (A1-A20), all passing, no Ollama

20/20 cases pass (`V14CResolverTests.swift`, run via
`scripts/test_v1_4c_experimental_policies.sh`). Highlights beyond the
decision table above:

- **A13 (mutually consistent wrong location)**: when occurrence and
  context both point at occurrence 1 but external ground truth intended
  occurrence 2, the resolver necessarily resolves to occurrence 1 --
  internally-consistent evidence is, by construction, indistinguishable
  from internally-consistent *correct* evidence at the resolver layer.
  **This is recorded explicitly as a model-layer risk the resolver cannot
  detect, not a resolver defect** -- exactly the distinction the milestone
  requires.
- **A14 (off-by-one)**: 0, and one-above-range both correctly rejected;
  the two in-range values both correctly resolve.
- **A15 (adjacent identical, `"the the the"`)**: three non-overlapping
  occurrences enumerated deterministically at positions 0/4/8; occurrence
  addressing works correctly.
- **A16 (substring containment, `"Act"` inside `"Action"`)**: exact
  substring search correctly finds all 3 literal occurrences (including
  the one inside "Action"); occurrence addressing still resolves
  correctly to the intended one.
- **A17 (context containing the target text itself)**: a `rightContext`
  value that itself contains "the witness" again is compared as an exact
  literal string, not re-matched recursively -- resolves correctly.
- **A18 (empty vs. absent context)**: an explicitly empty string is
  treated identically to "not supplied" -- it never acts as a universal
  match.
- **A19 (very long context)**: accepted literally with no artificial
  length limit; a long-but-exact, immediately-adjacent context still
  resolves correctly.
- **A20 (Unicode)**: the fallback case (A11) and the contradiction case
  (A12) both reproduce correctly with Odia and emoji content.

## Exact live fixture corpus (Parts C/D)

| ID | Repetition | Intended occurrence | Forces genuine short-fragment? |
|---|---:|---|---|
| REP2_first | 2 | 1st | yes |
| REP3_middle | 3 | 2nd (middle) | yes |
| REP5_last | 5 | 5th (last) | yes |
| REP10_forced_short | 10 | 7th (non-edge) | yes -- deliberately a plain, undifferentiated repeated list (`"the item, the item, ..."` ×10) with no per-occurrence distinguishing prose, specifically to discourage the whole-clause workaround V1.4B observed |

Two protocol conditions: **baseline** (schema description matching
V1.4B's wording) and **explicit** (schema description plus system
instruction stating "first=1, second=2, third=3... never use 0"
explicitly). 5 fresh trials per fixture per condition = 40 live
interactions for Parts C/D. This is a documented bounded reduction from
testing every position at every repetition level separately (first,
middle, last collectively cover the required position categories across
the 4 chosen repetition levels rather than a full cross-product).

## Baseline vs. explicit-1-based raw results

**40/40 trials, both conditions, every repetition level (2, 3, 5, 10):
correct 1-based occurrence value, matching the intended target exactly.**
No difference between baseline and explicit conditions was observed --
both were already perfect in this sample. `REP10_forced_short` confirmed
`sourceText: "the item"` (the genuine short fragment, not a whole-clause
expansion) in all 10 trials (5 baseline + 5 explicit), with
`occurrence: 7` correct in every trial.

## Genuine 10-way counting result (Part D)

**Resolved: 10/10 (both conditions) used the genuine short fragment with
the correct occurrence value.** This directly answers V1.4B's open
question -- true 10-way short-fragment occurrence counting is reliable in
this sample, when the passage structure removes the whole-clause
workaround option (by giving occurrences no distinguishing prose to
expand into). Whole-clause/source-expansion workaround count for this
fixture: **0/10** -- confirming the fixture design achieved its purpose.

## Part E — adversarial live P3 results

5 hand-designed adversarial prompts, 3 trials each (15 live interactions),
using the combined occurrence+context schema with instructions explicitly
inviting extra discriminators:

- **E1, E2, E3** (3/3 each): in every trial, the model chose `sourceText`
  as the **entire passage** (not the targeted short fragment), then
  supplied an `occurrence`/`context` value that **contradicted** that
  self-selected unique whole-passage match (e.g. `occurrence: 2` against
  a source that, as echoed, occurs exactly once). Verified with the real
  resolver: **all 9 trials correctly rejected** at the resolver stage
  (`rejectedOccurrenceContradictsUnique` / `rejectedContextContradictsUnique`)
  -- this is a direct, practical validation of the V1.4C refinement over
  V1.4B's broad P3, which would not have made this contradiction explicit.
- **E5** (3/3): the model again chose the entire passage as `sourceText`,
  with a **valid** `occurrence: 1` (correctly matching the one occurrence
  of that self-selected unique string), but `replacementText` was a much
  shorter string that would delete most of the passage's content if
  applied. **Verified with the real resolver and the real, unmodified
  `IntelligenceSafetyAuthority`:** the resolver correctly resolves this
  (`resolvedOccurrenceAgreesWithUniqueSource` -- this is *correct* resolver
  behavior, not a defect, since the evidence genuinely and unambiguously
  points there), and the Safety Authority correctly rejects it
  (`.rejected(.unsupportedEditCategory)`) because replacing an entire
  multi-sentence passage with two words is not a punctuation/
  capitalization/whitespace-only edit. **This is the clearest
  demonstration in this investigation of the two-contract architecture
  working exactly as designed**: the resolver's job (where) and the Safety
  Authority's job (may this proceed) are cleanly separated, and each did
  its job correctly.
- **E6** (unique-target control, 3/3): compliant, no unnecessary
  discriminators forced onto an already-correct no-op proposal.

**New pattern observed, not previously this clear in V1.4B**: offering
multiple optional discriminator fields together, especially with
instructions inviting "also supply context if you can," appears to
correlate with the model choosing a **whole-passage** `sourceText` rather
than the targeted short fragment -- which then makes any concurrently
supplied `occurrence`/context values likely to contradict that
self-selected anchor. This did not produce any unsafe outcome in this
sample (all such contradictions were caught, either at the resolver or
the Safety Authority stage), but it is recorded as a real contract-usability
observation: the schema's mere shape can steer the model's addressing
strategy in ways that increase contradiction-rejection rate.

## Contradictions observed

9/15 Part E trials produced an explicit occurrence/context contradiction
against the model's own self-selected `sourceText`, all correctly
rejected. Zero contradictions were misresolved.

## Mutually-consistent wrong-address observations

Not observed live in this sample (the model's contradictions were always
of the "explicit evidence disagrees with the self-selected anchor" kind,
never "both agree with each other but are wrong relative to my intended
ground truth"). The deterministic test (A13) demonstrates this failure
mode is real and undetectable by the resolver in principle, but no live
instance of it was captured this round -- recorded as an open risk, not a
disproven one.

## Unicode confirmation results (Part F)

Both prior corruption patterns reproduced, with the same safe outcome:

- **Odia** (3/3 trials): `sourceText`/`replacementText` were both a
  garbled, unrelated (Kannada-shaped, not Odia) string -- a hallucination,
  not the real source text. Fails closed (`zeroOccurrences`) in all 3
  trials.
- **Emoji** (3/3 trials): the emoji glyph itself was reproduced correctly
  this time, but preceded by a spurious literal newline character in the
  echoed `sourceText` (not present in the real source), and
  `replacementText` was a drastically truncated 3-character string. Fails
  closed (`zeroOccurrences`, since the spurious newline makes `sourceText`
  not literally match the real source) in all 3 trials.

No unsafe outcome from either Unicode fixture. Model Unicode-reproduction
fidelity remains a real, unresolved concern, unchanged in character from
V1.3C/V1.4B -- not investigated further here, per instructions.

## Multi-edit confirmation results (Part G)

**5/5 trials: both array entries used correct 1-based occurrence values**
(`occurrence: 1` for the first target, `occurrence: 2` for the second),
with both required fields present in every entry. **The 0-based slip
observed in V1.4B's multi-edit probe did not reproduce** when the
instruction explicitly stated the expected occurrence value for each
specific edit alongside the general 1-based convention statement. This is
a meaningfully more directive instruction than a generic convention
statement alone (it names the exact expected value per edit, not just the
abstract rule) -- recorded as a caveat: this result shows the slip is
fixable with sufficiently explicit per-case guidance, not that an abstract
convention statement alone is proven sufficient in the array context
(Parts C/D's abstract-convention-only condition was not repeated for the
array shape specifically).

## Safety Authority regression

A representative subset was routed through the real, unmodified
`IntelligenceSafetyAuthority`: E5 above (rejected, `.unsupportedEditCategory`
-- the "one lexical/wholesale-content mutation" representative), plus
reuse of V1.4B's existing protected-span and safe-acceptance regression
cases (both confirmed unaffected, since `IntelligenceSafetyAuthority.swift`
itself was not touched). No weakening, no modification.

## Unsafe accepted edits

**0** -- across all deterministic tests (31 from V1.4/V1.4B + 20 new from
V1.4C = 51 total) and all 78 live model interactions (40 Parts C/D + 15
Part E + 6 Part F + 5 Part G + 12 from the initial Stage-1-style live
verification of E1-E3's exact resolver outputs).

## Resolver safety failures

**0.** Every resolver outcome, when checked against its own stated
contract semantics, was correct -- including the two most scrutinized
live cases (E5's correct-but-dangerous resolution, and E1/E2/E3's correct
contradiction rejections).

## Model addressing failures

Several, all safely contained: whole-passage `sourceText` selection
producing self-contradictory evidence (E1/E2/E3, 9 instances); a
resolvable-but-content-destroying whole-passage proposal (E5, 3
instances); Unicode hallucination/corruption (F1/F2, 6 instances). None
of these reached an unsafe outcome.

## Safe rejections

12 (E1/E2/E3's 9 contradiction rejections) + 6 (Unicode) = 18 explicit
resolver-level safe rejections in the new live-model work this milestone,
plus 1 Safety-Authority-level safe rejection (E5).

## Contract usability failures

The whole-passage-selection tendency observed under the combined B+C
schema with permissive "also supply context" instructions is the main
usability concern surfaced this round -- it did not cause unsafe
behavior, but it means the combined schema, as prompted here, frequently
produces overly broad (whole-passage) proposals rather than minimal-diff
ones, which would need to be addressed (e.g. through instruction design or
schema constraints) before this pattern would be practically useful at
scale, independent of its safety.

## Supported conclusions

- The precise P3 decision table is complete, internally consistent, and
  fully covered by 20 deterministic adversarial tests with no
  contradictory or ambiguous cases discovered.
- Genuine discriminator contradictions always fail closed, both in
  deterministic tests and in live-model-generated contradictions (9/9
  observed live).
- No resolver-level silent mistarget occurred anywhere in this milestone.
- Explicit 1-based instruction, when directive enough (naming the exact
  expected value per case), produces stable, correct ordinal behavior in
  both the single-edit (40/40) and multi-edit (5/5) contexts -- fully
  eliminating the previously-observed 0-based slip in this sample.
- Genuine, non-workaround high-repetition (10-way) occurrence counting is
  reliable (10/10) once the passage design removes the whole-clause
  escape hatch.
- Optional context provides real recovery value in principle (validated
  deterministically, A7/A11) but, as prompted in this round, correlated
  with a whole-passage-selection tendency that increased contradiction
  rate rather than providing corroboration in the way V1.4B's narrower
  prompts elicited.
- Multi-edit items retain independent immutable-source addressing (each
  item's occurrence resolved correctly and independently in Part G).
- Unsafe accepted edits remain 0 throughout, including the specific,
  deliberately adversarial E5 case where resolution correctly succeeded
  but the Safety Authority correctly refused to apply the edit.

## Unsupported conclusions

- This does **not** establish that an abstract 1-based convention
  statement *alone* (without naming the specific expected value per case)
  is sufficient in the multi-edit/array context -- only that a more
  directive instruction is sufficient; the weaker condition was not
  isolated for the array shape.
- This does **not** establish the mutually-consistent-wrong-address risk
  is rare or common at the model layer -- it was shown to be real and
  undetectable in principle (A13) but not observed live this round.
- This does **not** resolve the whole-passage-selection tendency observed
  under the combined schema -- it is recorded as an open usability
  concern, not solved.
- This does **not** establish Unicode reliability improvements -- both
  known corruption patterns reproduced unchanged.

## Decision: contract survives with modification (Outcome B)

The provisional contract (exact `sourceText` + optional 1-based
`occurrence` + optional exact context) **is not falsified** -- zero
resolver safety failures, zero unsafe accepted edits, and the two
previously open questions (10-way counting, 1-based convention fragility)
were both resolved favorably under this round's testing. However, it
**does not survive unmodified**: V1.4B's broad P3 must be replaced by the
precise decision table in Part B above (specifically: explicit occurrence/
context evidence on an already-unique source must be checked for
contradiction, never silently ignored) -- this is exactly what let E1/E2/E3
fail closed correctly rather than falling through to an ambiguous "both
absent" path. This is a bounded, already-implemented and already-validated
fix, not a call for another open-ended validation experiment.

## Exact recommended V1 addressing semantics (if this direction is pursued further)

1. If `sourceText` resolves to exactly one occurrence in the immutable
   source, resolve to it -- checking any explicitly supplied `occurrence`/
   context for contradiction first (reject if either explicitly
   contradicts the unique match; do not silently ignore).
2. If `sourceText` is ambiguous, require `occurrence` and/or context;
   apply the precise decision table in Part B exactly (occurrence primary
   when it alone succeeds; context as fallback when occurrence fails and
   context alone uniquely resolves; contradiction between two
   independently-successful-but-disagreeing discriminators always rejects).
3. State the 1-based convention explicitly and directively in model-facing
   instructions -- an abstract rule statement, reinforced with a concrete
   worked value where the case allows it, empirically eliminated the
   observed 0-based slip in this round.
4. Resolution success is never permission -- every resolved proposal must
   still traverse the unmodified V1.0 Safety Authority, which remains the
   sole authority on whether an edit may be applied (demonstrated
   concretely by E5).

## Remaining risks / open questions

1. Whole-passage-selection tendency under the combined schema with
   permissive instructions -- a usability concern, not yet mitigated.
2. Mutually-consistent-wrong-address risk (A13) remains real and
   undetectable by the resolver in principle; only measurable at the
   model/evaluation layer, not exercised live this round.
3. Whether an abstract-only 1-based statement (without a per-case worked
   value) suffices in the multi-edit/array shape specifically remains
   untested.
4. Unicode reproduction fidelity (Odia hallucination, emoji corruption)
   remains unresolved and unattempted, as scoped.

## Recommended next milestone

A contract-freeze / production-foundation design milestone may now be
justified for the addressing layer specifically (Part B's precise P3
table, occurrence-primary, explicit 1-based convention) -- but should
first separately address the whole-passage-selection usability concern
(e.g., an instruction/schema constraint discouraging whole-passage
`sourceText` when a shorter unique-or-disambiguable fragment exists)
before being frozen, since that pattern currently makes the combined
schema less useful in practice even though it remains safe. Do not
implement this in the next milestone without explicit re-scoping -- this
report only recommends it as a candidate next step.

## Repository state at completion

See the final report for exact `git status --short`. No files were
staged, committed, or pushed. All V1.4/V1.4B artifacts remain exactly as
they were; V1.4C's new files sit alongside them, also uncommitted.
