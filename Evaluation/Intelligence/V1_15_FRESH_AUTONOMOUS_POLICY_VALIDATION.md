# Intelligence V1.15 — Fresh Autonomous-Policy Validation

## 1. Status and scope

Investigation/validation only. **No `Sources/` file changed, no production policy was
implemented, no model/provider work was done.** The V1.14 recommended bundle
(`core-merge-only+P-A`) and its component invariants were evaluated **unmodified**
against a genuinely fresh corpus. The only code change is to the investigation
harness (`AutonomousEditPolicyInvestigation.swift`): a third tier and its pins.
`AutonomousEditInvariants.swift` — the frozen rule definitions — is **byte-for-byte
unchanged**: its SHA-256 (`b20b0011…6aafe`) is identical to the value V1.14 pinned,
verified before and after this milestone.

> **Measurement superseded by V1.16 (`V1_16_AUTONOMOUS_PERMISSION_GATE.md`).** Same
> script as V1.14 (`scripts/test_autonomous_edit_policy_investigation.sh`), same
> caveat: this document's pinned `fresh.*` numbers were measured against the
> classifier/Authority **as it existed before V1.16**'s gate was wired in. Re-running
> the script's pinned `precondition`s against the current production Authority will
> now fail as expected — see the V1.14 document's note for the full explanation. The
> fresh corpus and every pinned number here are preserved unchanged; V1.16's
> production-parity replay (`scripts/test_autonomous_permission_gate.sh`) reproduces
> this document's `fresh.json` aggregate numbers exactly against the current,
> gate-equipped Authority.

## 2. Fresh corpus construction and freeze evidence

`Evaluation/References/autonomous-edit-policy/fresh.json` (128 entries: 51 legit, 67
dangerous, 10 ambiguous) was authored independently — new sentences, names, statutes
and case references not drawn from V1.14's corpora. **Freshness was checked
mechanically**: its texts were compared against the full text sets of the V1.12, V1.13
and both V1.14 corpora (751 prior entries) — **zero overlap**.

Two corrections were made, both *before* any measurement existed (the run either
hadn't been executed or had hard-crashed with a structural error, not produced a
score):
1. One placeholder entry lacking a real edit was removed before the first run
   (129→128 entries).
2. One entry's edit failed to resolve at all (a context string that didn't match
   its target) — a resolution bug, not a labeling judgment — fixed before the run
   could produce any output.

After that point **the corpus was not touched again**, including one item (§5)
identified only after scoring; it is disclosed, not corrected, to keep the
scored-then-reported discipline honest. The frozen corpus is pinned by SHA-256
(`f8ed62da…3496d6`) in the harness, alongside the (unchanged) rules-file hash and
both V1.14 corpus hashes — a change to any of the four fails the test.

## 3. Measurements (fresh tier; V1.14 development/validation shown for comparison)

### Funnel — how much of the classifier's leniency remains after V1.11/V1.13

| | n | classifier | +V1.11 | +V1.13 (effective) |
|---|---|---|---|---|
| legit | 51 | 50 | 50 | 50 |
| dangerous | 67 | 67 | 67 | 66 |
| ambiguous | 10 | 10 | 10 | 10 |

Consistent with V1.14: existing protections remove only a handful of dangerous
cases; the large majority (66/67) remain autonomously acceptable before any V1.14
invariant is applied.

### Recommended bundle (`core-merge-only+P-A`): benefit and cost

| Corpus | Dangerous blocked (of remaining) | Legit demoted (of remaining) | Ambiguous demoted |
|---|---|---|---|
| V1.14 development | 65/71 (91.5%) | 1/68 | 4/12 |
| V1.14 validation | 58/67 (86.6%) | 1/48 | 3/10 |
| **V1.15 fresh** | **55/66 (83.3%)** | **1/50** | 3/10 |

**The cost replicates exactly: one legitimate edit demoted on fresh data too, and it
is the same driver** — an ASR all-caps word lowered by the acronym guard (C-A2)
(`WITNESS→witness`, the same shape as V1.14's `ODISHA→Odisha`). Every other bundle
component (P-A, P-B, W-A1, C-C) again cost **zero** legitimate edits on fresh data,
matching V1.14 exactly.

The benefit percentage is somewhat lower (83.3% vs 87–92%) because two hazard
sub-shapes not present in either V1.14 corpus appear in the fresh one (§4) — this is
new coverage information, not noise or a change in the invariants' behavior.

### Per-hazard remaining-autonomous count (fresh; compare to V1.14 §5 table — near-identical)

acronymCase 7/7, alphanumericIdentifier 6/6, designatorCase 4/4, digitLetterBoundary
6/6, identifierCase 2/3 (1 already contained by V1.13's numeric spans), intraToken
Punctuation 10/10, midTokenCase 3/3, spelledNumber 6/6, structuralPunctuation 8/8,
wordMerge 9/9, wordSplit 5/5 — the same shape as V1.14, confirming the gap
characterization generalizes.

## 4. New evidence from fresh data (neither falsifying nor requiring architectural review)

Two hazard *sub-shapes*, absent from both V1.14 corpora, surfaced only in fresh data.
Both are consistent with the **same recurring pattern** already flagged for
`designatorCase`: a structural invariant's "token" is a run of word-forming Unicode
scalars, and punctuation inside a name/abbreviation splits that run, which can put
the punctuation-adjacent fragment below a threshold defined in terms of the whole
name/abbreviation. Three observed instances (`designatorCase`, this milestone's two)
share this token-boundary sensitivity to punctuation; that is evidence of a
recurring limitation of the token-scanning approach, not proof of one single
formally-identified root cause covering every case — no attempt was made here to
establish that stronger claim:

1. **A single-word abbreviation's terminal period, followed by a space, is not
   caught by P-B.** `viz. the arrears` → `viz the arrears` (deleting the period in
   `"viz."`) is not "intra-token" by the invariant's definition, because a space
   already separates the period from the next word — unlike the glued multi-period
   abbreviations V1.14 tested (`w.e.f.`, `S.K.`, `T.S.`, no internal spaces). `P-A`
   also does not catch it (`.` is in the routine-punctuation allowlist). This is a
   narrower gap within the already-documented `intraTokenPunctuation`/
   `structuralPunctuation` residual, not a new hazard class.
2. **An apostrophe inside a proper name defeats the acronym guard.** `O'Connell` →
   `O'connell` is not blocked by C-A2, because the apostrophe (punctuation, not
   word-forming) splits the name into two word-forming tokens (`O`, `Connell`), each
   containing only **one** uppercase letter — below C-A2's "≥2 uppercase letters"
   threshold — even though the whole name is capitalized as a unit. This fits the
   same pattern as the already-flagged `designatorCase` gap
   (punctuation-adjacent single-uppercase-letter tokens): punctuation-splitting a
   structural invariant's token boundary in a way that does not track a logical
   identifier or name. That the two share this pattern is observed, not a claim
   that a single mechanism has been formally shown to explain both.

**Assessment against the stop condition:** this is not material falsification. The
recommended bundle's aggregate benefit (83.3%) and exact cost (1 legitimate edit,
same driver) replicate closely; no invariant's zero-cost property is contradicted;
no previously-safe case became unsafe. It **sharpens** the known residual-risk
boundary (§8 of the V1.14 document) rather than opening a new one — no rule was
changed, and none is proposed here.

## 5. Disclosed corpus artifact (no effect on any measurement)

One `legit`-labeled fresh entry (`AF-019`) turned out, on inspection after scoring,
to express an unintended compound edit (a combined space-and-punctuation change)
that the real classifier scores as `.other` — outside all three autonomous
categories, for a reason unrelated to any V1.14 invariant. This is corpus-authoring
noise, not a system finding: because it was never autonomous under the raw
classifier, it never entered the "legit remaining autonomous" pool and **affected
zero pinned numbers** (verified by inspection of the `.other` classification path).
Per this milestone's freeze discipline, it is disclosed rather than corrected: the
frozen corpus and its hash are exactly what was scored.

## 6. Architecture-boundary finding: where should an autonomous-permission structural
   invariant live? (`IntelligenceEditClassifier` vs. a distinct gate)

Inspected the actual code responsibilities, not a redesign:

- **`IntelligenceEditClassifier.classify(from:to:)`** takes only the two strings
  being compared (`expectedSourceText`, `replacementText`). It has **no access to
  surrounding text** — it cannot know whether a deleted space sits between two
  word-forming characters, because it never sees what comes before or after the
  edited span. Every V1.14/V1.15 invariant that matters (the merge/split
  distinction, intra-token punctuation, mid-token/identifier capitalization) is
  fundamentally a *neighboring-context* question. Implementing them inside
  `classify` would require changing its signature to accept surrounding context —
  widening a type whose committed contract and tests are exactly "classify from the
  two strings alone" — and would blur its one job (edit-shape classification) with
  a second, context-dependent one (safety permission).
- **`IntelligenceSafetyAuthority.validate`** already has everything an invariant
  needs at the exact point it currently calls `classify` (step 7 of its documented
  pipeline): the full immutable `source` and the proposal's `range`, from which
  the text immediately before and after the edit is trivially available. It already
  performs the structurally analogous job of downgrading a `.autonomouslyAccepted`
  classification to `.rejected`/`.reviewOnly` based on additional deterministic
  information the classifier does not have (protected-span intersection, overlap)
  — precisely the shape an autonomous-permission structural invariant would need.

**Recommendation: a distinct, narrow, dedicated deterministic type — analogous to
`ProtectedSpanDerivation` and `NumericStructuralProtection` — consumed by
`IntelligenceSafetyAuthority` as an additional input alongside protected spans, not
merged into `IntelligenceEditClassifier`.** This preserves the classifier's existing
narrow contract and tests unchanged, keeps `IntelligenceSafetyAuthority` as the
sole "may this proceed" decision point (its committed role), and matches the
project's established pattern of small, single-purpose, independently-testable
deterministic components feeding the Authority rather than growing any one of them.
It would slot into the Authority's pipeline as a new step alongside (not replacing)
protected-span intersection, downgrading `.autonomouslyAccepted` the same way an
unresolved span already does. **Not implemented; this is architectural guidance for
a future, separately-authorized production milestone.**

## 7. Recommendation on production promotion

**The V1.14 recommendation survives fresh validation.** The evidence supports
promoting `core-merge-only+P-A` (punctuation allowlist, no-intra-token-punctuation
rule, merge-only whitespace blocking, acronym capitalization guard, digit-bearing
identifier capitalization guard) to a future, explicitly-authorized production
milestone, implemented as a new deterministic gate consumed by
`IntelligenceSafetyAuthority` (§6) — **not implemented in this milestone.** The two
newly-discovered sub-shapes (§4) should be added to that future milestone's own
test corpus; they do not change the recommendation's direction.

## 8. What remains unresolved (unchanged, now with sharper boundaries)

- **Word splits** (`constable→const able` vs. legitimate `witnessreached→witness
  reached`) remain unresolved — structurally identical, no free deterministic
  signal found on fresh data either.
- **Punctuation-adjacent single-uppercase-letter / single-abbreviation-word
  gaps** (`designatorCase`, and now `O'Connell`-style names and `viz.`-style
  terminal periods) fit a recurring pattern, observed on independent fresh data:
  a structural invariant's word-forming-run "token" does not always track a
  logical name or abbreviation once punctuation is inside it. This is evidence
  of a shared limitation of the token-scanning approach across three observed
  cases, not a formally-proven single root cause — no solution is proposed;
  per this milestone's instructions, this is not escalated to "requires
  architectural review" beyond the boundary finding already made in §6, since
  resolving it would mean either a lexicon (rejected in V1.12/V1.14 for
  cost/generalization reasons) or a different token definition whose own
  cost/benefit is untested.
- Corpora remain synthetic and implementer-authored; this is investigation-tier
  evidence (deterministic code exercised by hand-written text), not real-model or
  real-dictation evidence — no live model or real judicial audio was used anywhere
  in V1.12–V1.15.

## 9. Files changed / tests run

- **New:** this document; `Evaluation/References/autonomous-edit-policy/fresh.json`.
- **Changed (harness/reporting only):** `AutonomousEditPolicyInvestigation.swift`
  (third tier, fresh-corpus hash pin, 159 new pinned measurements). **Unchanged:**
  `AutonomousEditInvariants.swift` (hash verified identical).
- **Not touched:** any `Sources/` file; `development.json`/`validation.json` and
  their pinned hashes (re-verified unchanged).
- Ran `scripts/test_autonomous_edit_policy_investigation.sh` (all three tiers, all
  hash checks and all pinned numbers pass) and `swiftlint --strict` on both
  experimental files (0 violations).
