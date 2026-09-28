# Intelligence V1.9 — Protected-Span Derivation: Coordinate Findings and Provenance Gap

> **Update (V1.10):** gaps G1–G3 below were closed by
> `V1_10_NORMALIZATION_PROVENANCE_FOUNDATION.md` (typed pass identity, located
> lookup provenance, replay-based reconstruction). This document remains the
> record of the state at V1.9; its statements about "today's" provenance are
> historical.

## 1. Outcome

Phase 1 (prove coordinate semantics first) was carried out against the real
production normalization code. **The coordinate model is fully established, but
a lossless protected-span derivation cannot be built from the provenance that
exists today**, so — per the milestone's stop condition — **no derivation layer
was implemented.** The gap is small and precisely identified (§5); the only
committed changes are characterization tests that pin the proven coordinate
model, one structural hand-off check, and this document. No production code
changed.

> **Warning — carried forward:** until protected spans can be derived
> losslessly, Intelligence must **not** be wired into dictation. Without spans,
> callers of `IntelligenceEditComposition` pass none, so resolved-span
> rejection and review-only protection do not trigger.

## 2. What text Intelligence receives

`ContentView` (both AI-bearing pipelines) sets
`legalNormalizedText = legalNormalization.normalized` and hands exactly that
string to AI post-processing. GAAV / continuous-dictation formatting and
literal formatting all run *after* AI. So the immutable `source` for a future
Intelligence stage is exactly `NormalizationOutcome.normalized` — no text change
between normalization and that hand-off (`scripts/test_legal_language.sh` now
checks the hand-off structurally, alongside the existing seam checks).

## 3. Proven coordinate model

The pipeline is `R --Lookup--> L --Statutory--> S --Witness--> N`, where `R` =
`NormalizationOutcome.recognized`, `N` = `.normalized` (= the Intelligence
source), and `L`, `S` are intermediate texts that **`NormalizationOutcome` does
not retain**.

| Fact | Evidence |
|---|---|
| Ranges are **UTF-16** `NSRange`s | `"😊😊 section three zero two I P C"`: statutory range location 5 (= 2+2+1), not 3 Characters |
| A range indexes the **input of the pass that produced it — pre-change** — never the pass's output or `N` | statutory range substring of the input equals `trigger`; the same range is out of bounds in `N` |
| Within one pass, every change indexes that pass's **original input** (none is shifted by sibling changes); applied changes are reported end-backward (descending location) | 3 statutory changes in one dictation, each range verified against `R` |
| **Statutory ranges are in `L`** (= `R` in production today, see below) | verified against `R` |
| **Witness ranges are in `S`, not `R` and not `N`** | `"section two nine four and section three two three I P C then P W one …"`: witness range `{37,7}` = `"P W one"` in `S`; the same range in `R` is `"ee two "` and in `N` is `"PW-1 th"` |
| Declined changes follow the same convention, and their text is preserved verbatim in `N` — but their **recorded range is not an `N` coordinate** once an earlier change changed length | statutory decline after an applied change: recorded range ≠ final position |
| **Lookup-table changes (applied and declined) have no range**, and **one record covers every occurrence** of a trigger | `"distt."` twice → one `applied` record, `range == nil` |
| When lookup applies, later ranges are in `L`, not `R` | statutory range no longer matches `R` |
| **Applied provenance is sufficient to reconstruct `N` exactly, iff each change's pass is known**: apply statutory changes to `R`, then witness changes to that result | reconstruction equals `normalized` |

Mapping a pass-input range to `N` is therefore a *piecewise shift* through the
replacements of that pass and of every later pass; an endpoint strictly inside a
replaced span has no exact image and must fail closed (not observed in a
7,371-dictation sweep, but structurally possible, e.g. a witness replacement
inside a statutory-declined span).

Current production has **only the builtin pack, which ships 0 normalization
entries**, so the lookup stage never fires today (`L == R`); the lookup gap
(G2) is latent, becoming live with any user/jurisdiction pack that has
normalization entries.

## 4. Losslessness assessment

- **Applied statutory/witness changes:** mappable and reconstruction-verifiable,
  but only via the loosely-typed `sourcePackID` family string (the code comment
  says it is "reused loosely … to mean which rule family produced this").
- **Declined changes:** **not attributable to a pass from the record.**
- **Lookup changes/declines:** **not locatable at all.**

## 5. Provenance gaps

- **G1 — no typed pass identity.** `AppliedNormalizationChange` has
  `trigger`, `replacement`, `sourcePackID`, `range`; `DeclinedNormalization` has
  `trigger`, `candidates`, `reason`, `range`. A range's coordinate space
  (`L` vs `S`) cannot be read off a decline; the flat
  `appliedChanges`/`declinedChanges` lists lose pass boundaries (ordering is
  mixed: statutory descending, then witness ascending). (Recorded by a test
  that observes the two records' stored properties.)
- **G2 — lookup provenance has no locations** (above), and its replacements
  shift every later coordinate by an unrecorded amount.
- **G3 — intermediate texts are not retained** (recoverable by re-running the
  pipeline, which is re-derivation, not provenance).
- **G4 — replaced-span boundary rule undefined** (endpoint inside a replaced
  span; witness change inside a declined statutory span).

**Evidence for the size of the gap (probe, not committed):** attributing each
decline by testing two hypotheses — "statutory-input coordinates" vs
"witness-input coordinates" — mapping to `N` and requiring exact text equality
with the recorded `trigger`, resolved **all 10,656 declines across 7,371
generated dictations uniquely and correctly** (0 ambiguous, 0 wrong, 0
unverifiable). This shows a workaround is plausible; it is **not** a proof of
losslessness (attribution stays inferential and could be ambiguous for repeated
text at coinciding offsets), and it is exactly the kind of offset inference the
milestone forbids without a proven mapping, so it was not adopted.

## 6. Options (for the architect)

- **A (recommended): record typed pass identity in provenance.** Stamp each
  applied and declined record with the producing pass (a small typed identifier
  set by `LegalNormalizationPipeline`, not a string convention), and make lookup
  either carry ranges or an explicit "unlocatable" marker. Derivation then
  becomes a small, provable layer: pass-ordered piecewise shift, verified per
  span (`N[mapped] == replacement` for applied, `== trigger` for declined),
  failing closed on any mismatch. Touches Phase 3 provenance types (approval
  needed), not the Safety Authority or V1.8.
- **B: hypothesis-verified attribution** with no provenance change — works on the
  evidence above but inferential; ambiguity would have to fail closed as
  *unprotected*, which weakens safety.
- **C: applied-only partial derivation** — leaves declined
  (`.deterministicallyUnresolved`) regions unprotected and silently drops
  lookup; contradicts the three-way protected-span semantics.

The same typed pass identity would also serve later evaluation/provenance
needs (e.g. judge-verified data) without building any collection now.

## 7. What was committed

`Tests/NormalizationProvenanceCoordinateTests.swift` (in
`scripts/test_legal_language.sh`): 8 characterization tests pinning every fact in
§3 and the current shape of the two provenance records (G1). They record
observed behavior and do not prescribe a solution; any future provenance change
would revisit them deliberately. A structural check that the AI hand-off text is
`legalNormalization.normalized`. No `Sources/` change; V1.8 composition and the
Safety Authority are untouched.
