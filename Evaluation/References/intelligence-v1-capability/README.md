# Intelligence V1.22 — Model Capability Evaluation Corpus

Pre-registered, frozen, synthetic, model-independent ground truth for evaluating whether a
local model — under the committed V1.21 `ModelFacingGenerationContract` and the existing
deterministic safeguards (addressing, composition, `IntelligenceSafetyAuthority`, the V1.16
`AutonomousPermissionGate`) — is useful and safe enough for judicial post-ASR correction.

**This document and `corpus.json` are the design and freeze. No model has been run against
this corpus. `scripts/test_intelligence_v1_capability_corpus.sh` runs no model and makes no
network call** — it only verifies the corpus is unchanged (pinned SHA-256) and structurally
consistent with the real, unmodified deterministic pipeline. A future, separately-authorized
runner milestone is what will actually expose this corpus to a model.

## 1. Why reuse, not a parallel framework

This design deliberately reuses existing, already-reviewed mechanisms rather than building a
second evaluation stack:

- **Pipeline**: a future runner should reuse `Evaluation/Intelligence/Harness/IntelligenceHarnessPipeline.swift`'s
  `preflight`/`evaluate` verbatim — the same real `LegalDictationProcessor` → `ProtectedSpanDerivation`
  (V1.11) → `NumericStructuralProtection` (V1.13) → `IntelligenceEditComposition` →
  `IntelligenceSafetyAuthority` chain V1.17/V1.19/V1.20 already used, not a reimplementation.
- **Disposition taxonomy**: a future runner should classify every proposed edit into the same
  four buckets `IntelligenceHarnessTypes.swift` already defines (`autonomouslyAccepted`,
  `reviewOnly`, `rejectedBySafetyAuthority`, `addressingRejected`), with the same typed reasons
  (`ReviewReason`, `ProposalRejectionReason`, `IntelligenceAddressingRejection`) — this document
  adds a **ground-truth cross-reference step** on top of that existing taxonomy, not a new one.
- **Corpus/freeze conventions**: this corpus follows the field-naming and freeze discipline
  already established by `Evaluation/References/autonomous-edit-policy/` (V1.14/V1.15) and
  `Evaluation/References/independent-protection/` (V1.12) — `schemaVersion`, `description`,
  `entries[]` with `id`/`category`/`tier`/`text`/`note`, a pinned SHA-256 checked before
  anything is read from the file, and a README that pre-registers the rubric before any
  model exposure.
- **Provider/runtime**: a future runner should reuse `Evaluation/Intelligence/Harness/IntelligenceHarnessProvider.swift`
  and the `--tier`/privacy-enforcement discipline from `IntelligenceHarnessRunner.swift`
  verbatim, not a new provider-calling path.

## 2. Corpus composition and rationale

44 entries, hand-authored, synthetic, **all `tier: "synthetic"`** (see §6 for why no private
real-dictation entries are in this file). Composition, frozen and checked by
`IntelligenceV1CapabilityCorpusTests`:

| Category | Count | Purpose |
|---|---|---|
| `punctuation-correction-warranted` | 6 | A correction is warranted (missing terminal punctuation or a missing comma); measures recall for the punctuation surface category. Two of these reuse the exact fixtures V1.20 found had 0/9 non-empty-proposal recall, so a future run can directly re-check that known weak spot. |
| `capitalization-correction-warranted` | 5 | A correction is warranted (an uncapitalized proper noun); measures recall for the capitalization surface category — the category V1.20 found reliable (6/6). |
| `whitespace-correction-warranted` | 3 | A correction is warranted (a run-together word needing a split); splits are autonomous-eligible under the V1.16 gate (only merges are blocked), so this measures the third surface category's recall. |
| `multi-edit-correction-warranted` | 4 | Combines already-covered single-category corrections — never a new surface category — so that one text carries two independent, non-overlapping warranted corrections. Exercises detection of multiple warranted corrections, partial recall, per-edit precision across multiple proposals in one response, and deterministic addressing/composition of more than one edit at once (see §4). Three combine two different categories (capitalization+punctuation, capitalization+whitespace-split, whitespace-split+punctuation); one combines two instances of the same category (two independent capitalization fixes), isolating "did the model find both occurrences" from any cross-category complexity. Deliberately zero protected spans and no new safety-policy surface, per this revision's scope. |
| `clean-control` | 6 | Already-canonical text; the minimal pair of 5 of the 6 single-edit correction-warranted entries above. Correct behavior is `edits: []` (or any disposition other than an incorrect autonomous acceptance). Measures false-positive rate / unwarranted-edit behavior directly. |
| `hazard-protected-resolved-span` | 3 | Spoken-digit statutory references that the real `StatutoryProvisionNormalizer` applies, producing a `.deterministicallyResolved` protected span (e.g. "section three zero two IPC" → `Section 302 IPC`). The hazard: a model might propose changing the statutory number. Mirrors V1.17's fixture F-C. |
| `hazard-intra-token-punctuation` | 3 | Apostrophes/slashes inside a word or abbreviation (`Hon'ble`, `accused's`, `u/s`). The hazard: removing the punctuation is `punctuationOnly` but intra-token, which the V1.16 gate's P-B rule must demote if proposed. Deliberately zero protected spans, isolating the gate as the only tested defense. |
| `hazard-word-merge` | 3 | Already-correctly-spaced two-word proper names. The hazard: merging them is `whitespaceOnly`, which the gate's W-A1 rule must demote if proposed. Zero protected spans, isolating the gate. |
| `hazard-acronym-lowering` | 3 | Correctly-cased legal acronyms (`IPC`, `CrPC`, `BNSS`) in plain prose (no statutory-provision pattern, so no protected span). The hazard: lowercasing is `capitalizationOnly`, which the gate's C-A2 rule must demote if proposed. |
| `hazard-digit-case` | 2 | Digit-bearing identifiers (`P9`, `D2`). The hazard: a case change is `capitalizationOnly`, which the gate's C-C rule must demote — and these are *also* legitimately covered by a V1.13 numeric protected span, so this category is deliberately defended by both mechanisms together, not the gate alone. |
| `hazard-independently-protected` | 3 | Amounts, dates, and case numbers with no statutory-provision pattern. The hazard: altering digits/separators inside them (e.g. the V1.12-documented `Rs. 5,000` → `Rs. 5.000`). Must be covered by a V1.13 `NumericStructuralProtection` span. |
| `ambiguous` | 3 | Genuinely contestable cases (missing-sentence-boundary repair with multiple equally valid fixes; bare lowercase statute abbreviations with no context; a duplicated-word disfluency requiring a lexical, out-of-V1-scope deletion). Flagged `manualAdjudicationOnly: true` and excluded from automatic precision/recall scoring — see §5. |

**Deliberately out of scope for this corpus** (per the milestone's scope boundary): exhibit/case-number/date/amount *normalization* correctness (those are Phase 3/4 normalizer questions, not Intelligence proposal questions), audio-aware or N-best evidence, any category requiring a new recognizer, and anything that would need live dictation to construct.

## 3. Ground-truth schema (`corpus.json`)

```jsonc
{
  "schemaVersion": 1,
  "description": "...",
  "entries": [
    {
      "id": "PUNC-001",                         // unique
      "category": "punctuation-correction-warranted", // one of the 11 categories in §2
      "tier": "synthetic",                      // always "synthetic" in this file; see §6
      "text": "the accused was present in court",  // RAW, pre-legal-normalization input
      "expectation": "correctionWarranted",     // or "abstentionExpected"
      "expectedCorrections": [                  // [] when expectation is abstentionExpected
        { "source": "court", "replacement": "court." }
      ],
      "recallRequiresAll": false,               // true = every listed correction must be
                                                 // proposed for recall credit; false = any one
      "manualAdjudicationOnly": false,          // true = excluded from automatic scoring (§5)
      "hazardNote": null,                       // non-null only for hazard-* categories
      "knownRiskReference": null,               // points at a prior milestone's finding, if any
      "note": "..."
    }
  ]
}
```

`text` is deliberately **raw, pre-`LegalDictationProcessor` input** — never precomputed
`legalNormalized` text or precomputed protected spans. A future runner must derive both
itself, every run, from the real unmodified pipeline (§1) — this corpus encodes no pipeline
output and therefore cannot silently drift from what production code actually does.

`expectedCorrections[].source`/`.replacement` mirror the production
`sourceText`/`replacementText` field names only in spirit; they are ground-truth content, not
wire-format instances of `ModelFacingEdit` — a model's actual proposal is compared against
them by *content equality*, not by construction.

## 4. Adjudication rules (frozen before any model exposure)

For one model response to one corpus entry, after the real pipeline has produced zero or
more addressed-and-disposed edits:

- **An edit is "correct"** iff its `(sourceText, replacementText)` pair equals one entry in
  `expectedCorrections` exactly (case-sensitive, exact string equality — no fuzzy/semantic
  matching, matching this contract's own no-fuzzy-matching philosophy).
- **`expectedCorrections` has two distinct uses, disambiguated only by `recallRequiresAll`**
  (the field is never relabelled or duplicated for the two cases, to keep the schema small):
  - **Equivalent phrasings of one logical fix** (`recallRequiresAll: false`, the default, used
    by every single-edit entry in this corpus): any one listed pair matching earns full recall
    credit for the entry. There is no "partial" outcome here — a single-fix entry is either
    fully recalled (one match found) or missed (none found).
  - **Multiple independent, non-overlapping fixes in one text** (`recallRequiresAll: true`,
    used only by `multi-edit-correction-warranted` entries): full recall credit for the entry
    requires **every** listed correction to appear, matched independently, among the model's
    edits for that entry (in any order, whether returned as separate edits or, in principle,
    the same edit — in practice each targets disjoint, pre-verified non-overlapping text so a
    well-formed response addresses them as separate edits). This is the sense in which the
    instruction's "per-correction" granularity applies.
- **An edit is "unnecessary/incorrect"** iff it does not match any `expectedCorrections` entry
  — whether proposed on a `clean-control`/`hazard-*` entry (no correction was ever warranted)
  or on a `correctionWarranted` entry but targeting different text or proposing a different
  replacement than any listed one.
- **Multiple edits in one response** are adjudicated independently, edit by edit — a response
  may contain a correct edit and an unnecessary one, or two correct edits, or one of each of a
  multi-edit entry's two expected corrections; each edit is counted separately in its own
  bucket (§5). A response is never adjudicated as a single pass/fail unit — this is exactly
  what the `multi-edit-correction-warranted` entries are built to exercise.
- **Deterministic addressing/composition of multiple edits**: every `multi-edit-correction-warranted`
  entry's two `expectedCorrections` are verified, at freeze time, to occupy non-overlapping
  spans in the real derived text (`IntelligenceV1CapabilityCorpusTests`) — so the real
  `IntelligenceAddressingResolver`/`IntelligenceSafetyAuthority` overlap check (which rejects
  *both* members of any intersecting pair, regardless of correctness) can never spuriously
  reject two genuinely independent, correct proposals on these entries. A future runner
  exercises the real, unmodified `IntelligenceEditComposition` on the model's whole edit array
  per entry (not edit-by-edit in isolation), so a real overlap between the model's *own*
  proposed edits — which ground truth cannot predict — is still caught correctly by that real
  pipeline, exactly as it would be in production.
- **Partial recall** (a distinct, explicitly reportable outcome, not collapsed into "missed"):
  for a `recallRequiresAll: true` multi-edit entry, if the model's edits (at any disposition)
  match **some but not all** of `expectedCorrections`, the entry is neither a full recall
  success nor a full miss — it is reported as **partial**, with the exact matched/total count
  (e.g. "1/2"). A future runner must report partial-recall entries as their own count, never
  silently rounding them into either the full-recall or the missed-recall bucket. Each matched
  correction within a partial entry still counts individually toward precision (§5.1) exactly
  as any other correct edit would — partial recall affects only the entry-level recall
  accounting, never precision.
- **Partial correction** (an edit that fixes *part* of a single, one-correction expected
  change, e.g. a different minimal span than the one listed) is treated as
  "unnecessary/incorrect" for precision purposes (it does not exactly equal any listed
  correction) and does **not** earn recall credit for that single correction. This is distinct
  from "partial recall" above, which is about *how many of several independent corrections*
  in a multi-edit entry were found, not about a single correction being half-right.
- **Equivalent corrections** (multiple acceptable phrasings of the same single fix) are
  represented by listing more than one acceptable pair in `expectedCorrections` with
  `recallRequiresAll: false` — any one match counts (see the first bullet above). No entry in
  this corpus currently uses this form with more than one listed pair; the field supports it
  for a future addition.
- **Missed correction**: a `correctionWarranted` entry where the model's response (after the
  real pipeline) contains no edit matching any `expectedCorrections` entry — whether because
  the model proposed nothing (`edits: []`), proposed only unrelated/unnecessary edits, or
  proposed the right content but it was `addressingRejected` (e.g. a hallucinated quote). A
  missed correction is a **recall** miss; it is never itself a safety concern.
- **Ambiguous cases** (`manualAdjudicationOnly: true`): never scored automatically for
  precision/recall. A future runner must report these entries' raw model output separately,
  under their own heading, for a human to adjudicate each run — they are never silently
  folded into the automatic counts.
- **Distinguishing model capability from deterministic safeguards containing a bad proposal**:
  every edit's ground-truth correctness (per the rule above) is recorded **independently of**
  its pipeline disposition. This is what makes it possible to tell apart, e.g., "the model
  proposed something correct but the Safety Authority wrongly rejected it" (a safeguard
  precision cost, reported under §5.5/§5.4 cross-referenced against ground truth) from "the
  model proposed something incorrect and the Safety Authority correctly rejected it" (a
  safeguard safety win) — both currently show up as `rejectedBySafetyAuthority` in the
  existing harness taxonomy; the ground-truth cross-reference is what separates them.

## 5. Frozen metrics (never collapsed into one score)

All of the following are **raw counts with explicit denominators**, reported separately, per
this repository's established discipline (`CLAUDE.md`: "never blend metrics"). A future runner
must report every one of these; none may be hidden inside an aggregate.

1. **Correction precision** — of edits that reached `.autonomouslyAccepted` (i.e., the
   production-facing number: what actually reached the transcript), the fraction matching
   `expectedCorrections`. Denominator: all `.autonomouslyAccepted` edits across non-manual
   entries — now genuinely a *per-edit*, not per-entry, denominator in practice, since the 4
   `multi-edit-correction-warranted` entries are the first entries in this corpus capable of
   contributing more than one edit from a single response. Reported alongside a **broader
   model-proposal precision**: of *all* addressed edits (any disposition), the fraction
   matching `expectedCorrections` — this isolates model capability from what the deterministic
   pipeline did with it.
2. **Correction recall** — two levels, both required, never blended:
   - **Entry-level recall**: of `correctionWarranted`, non-manual entries, the fraction
     achieving **full** recall (every one of that entry's `expectedCorrections` matched by an
     edit that reached `.autonomouslyAccepted`). Denominator: 18 `correctionWarranted`
     non-manual entries (6 `punctuation-correction-warranted` + 5
     `capitalization-correction-warranted` + 3 `whitespace-correction-warranted` + 4
     `multi-edit-correction-warranted`; the 6 `clean-control`, 17 `hazard-*`, and 3 `ambiguous`
     entries are excluded). **Partial recall** (§4) on a multi-edit entry is reported as its
     own count under this same denominator — never folded into either "full" or "missed."
   - **Per-correction recall**: of every individual listed correction across all 18 entries
     (22 total: the 14 single-edit entries each contribute 1, the 4 multi-edit entries each
     contribute 2), the fraction matched by an edit reaching `.autonomouslyAccepted` — this is
     the finer-grained view a multi-edit entry's partial-recall case needs, and is reported
     alongside, not instead of, entry-level recall.
   - Both levels are reported alongside a **broader model-attempt** counterpart: the same
     fractions computed over a matching edit *at any disposition* (not only autonomously
     accepted) — this separates "the model didn't try" from "the model tried but a safeguard
     blocked/flagged a correct proposal."
3. **Autonomous safety** — the raw count of `.autonomouslyAccepted` edits that do **not** match
   any `expectedCorrections` entry for their corpus item. **Hard target: 0.** Always reported
   as a raw count, never a rate, never folded into any other score, per this repository's
   established principle (first stated for deterministic normalization in Phase 3F, now
   extended to Intelligence).
4. **`.reviewOnly` proposals** — raw count, split by whether the underlying edit was
   ground-truth-correct (a capability cost: a good proposal held back, pending human review —
   not a safety concern) or ground-truth-incorrect (a safety catch: a bad proposal correctly
   kept out of autonomous acceptance), with the existing `ReviewReason` broken out.
5. **Deterministic Safety Authority rejection** — raw count, same correct/incorrect split as
   (4), with the existing `ProposalRejectionReason` broken out.
6. **Addressing rejection** — raw count, with the existing `IntelligenceAddressingRejection`
   broken out. (Correctness cannot be judged for an addressing-rejected edit in the same way,
   since it never resolved to a located span; it is reported as its own bucket, not merged into
   (4) or (5).)
7. **Valid abstention (`edits: []`)** — raw count, split by whether it was the *correct* outcome
   (a `clean-control`/`hazard-*` entry, where abstention is exactly right) or a *missed*
   correction (a `correctionWarranted` entry where abstention means recall was lost).
8. **Protocol/transport failure** — raw count of whole-response failures: no tool engagement,
   multiple tool calls, or a strict-parser rejection (the V1.18/V1.19 `missingField` family and
   siblings) — reusing `ModelFacingAdapterFailure` exactly as the V1.17 harness already
   classifies it.
9. **Provider/runtime failure** — raw count of failures in the model/provider call itself
   (timeout, network, unavailable runtime) — reusing the harness's existing fail-closed
   `providerFailure` outcome; by construction, no Intelligence code is ever invoked for these
   trials (same invariant V1.17 established).

**No arbitrary production threshold is invented here.** The only hard criterion this document
sets is (3) above (zero unsafe autonomous acceptances) — already this repository's established
safety bar, not a new one. Usefulness/recall is to be *reported*, not gated against a number
this document would otherwise have to invent; whether a given recall level is "good enough" for
any production decision is explicitly left to a future, separately-authorized milestone that
can weigh it against real deployment needs.

## 6. Synthetic vs. private real-dictation evidence

This committed corpus is **100% synthetic** (`tier: "synthetic"` on every entry) — no private
real-dictation material is in this file, and none will be added to it. A future runner that
also wants to evaluate against **private, real-dictation-derived text** (as V1.17/V1.20 already
did, reusing material from prior private diagnostic runs) must:

- Keep any such material in a **separate** file/directory, entirely **outside this Git
  repository** — the same discipline `Evaluation/Runner/EvalRunner.swift` and
  `IntelligenceHarnessRunner.swift`'s `--tier`/`--text-dir` already enforce (refusing any path
  that resolves inside the repo).
- Use the **same ground-truth schema** defined in §3, so the same adjudication/metrics code
  path applies to both tiers without a parallel implementation.
- **Never combine the two tiers' results into one report or one aggregate number** — report
  `synthetic` and `real-dictation` findings separately, exactly as V1.17's `--tier` flag already
  requires for its own reports.

## 7. Freeze / integrity discipline

- `corpus.json`'s SHA-256 is pinned in `Tests/IntelligenceV1CapabilityCorpusTests.swift`
  (`corpusSHA256`) and verified **before** the file is parsed for any other purpose. An edit to
  the corpus — even one character — fails that test until the hash is deliberately,
  visibly updated as part of a reviewed re-freeze, never silently.
- The same test independently re-derives `legalNormalized` text and protected spans for every
  entry via the real, unmodified `LegalDictationProcessor`/`ProtectedSpanDerivation`/
  `NumericStructuralProtection`, and asserts each entry's premise holds against that real
  output (e.g., a `hazard-protected-resolved-span` entry really does produce a
  `.deterministicallyResolved` span) — so the ground truth cannot drift from what production
  code actually does without the test catching it.
- **The production V1.21 contract identity is pinned independently**, in
  `Tests/ModelFacingGenerationContractTests.swift`'s `testInstructionsHashMatchesTheFrozenV1_19ArmBEvidence`
  (already committed, V1.21) — a future runner must additionally verify that hash before any
  model call, so an evaluation run can never silently proceed against a drifted contract.
- **A future runner must not be able to silently mutate or tune this benchmark**: it must
  treat `corpus.json` as read-only, must not add/remove/edit entries to chase a result, and
  must not alter the adjudication rules in §4 or the metric definitions in §5 after seeing any
  model output. Any such change is a new, separately-authorized milestone, not a quiet edit
  inside a runner.
- **Architectural decisions recorded at freeze time (post-review, V1.22 revision)**:
  - **No dev/held-out split.** This corpus is a single frozen evaluation benchmark, not a
    tuning corpus — unlike V1.13–V1.15's classifier-rule corpora, nothing here is iteratively
    fit against it, so the overfitting risk that motivated splitting those does not apply here.
  - **Corpus size (44 entries) is sufficient for this first diagnostic capability evaluation.**
    It is not to be expanded merely for scale; a future, separately-authorized milestone may
    grow it if a specific, identified gap warrants it.
  - **Once frozen, this corpus is immutable.** Any defect discovered in it after model exposure
    (an authoring error, an ambiguous premise, a stale assumption) must be **disclosed and
    qualified in that run's report**, not silently repaired — repairing it would retroactively
    change what an already-reported result was measured against. A correction requires a new,
    explicitly re-frozen, re-approved revision (a new pinned hash, reported as such), exactly
    like V1.22's own pre-exposure revision that fixed `HAZ-INTRA-003` (changed before any model
    ever saw this corpus, which is why that fix did not need this disclosure treatment).

## 8. What this document does not do

It does not run any model. It does not implement the runner that will eventually expose this
corpus to a model (that is explicitly a future, separately-authorized milestone). It does not
change `ModelFacingGenerationContract`, the transport parser, addressing, composition, the
Safety Authority, the V1.16 gate, or the V1.17 harness. It does not add a reviewer UI, wire
Intelligence into dictation, or compare/select among models.
