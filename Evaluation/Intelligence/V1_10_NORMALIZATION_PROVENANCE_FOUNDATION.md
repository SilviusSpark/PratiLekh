# Intelligence V1.10 — Normalization Provenance Foundation

## 1. Status and scope

V1.10 closes the provenance gaps found in V1.9 so that a later milestone can map
provenance into final normalized coordinates deterministically. It changes
normalization *provenance* only: **normalization behavior and output are
preserved exactly** (differentially tested), no `ProtectedSpan` is derived, and
nothing in Intelligence, the Safety Authority, ASR or dictation wiring changed.
`Sources/Fluid/LegalLanguage/`, `Evaluation/Runner/EvalRunner.swift` (one
mechanical optional-chaining fix) and tests only.

## 2. Provenance API / type changes

| Change | Where |
|---|---|
| `NormalizationPassID` (`lookupTable`, `statutoryProvision`, `witnessReference`) — typed producing-pass identity | `LegalNormalizer.swift` |
| `AppliedNormalizationChange` / `DeclinedNormalization`: added `pass`, `step`; **`range` is now non-optional `NSRange`** | same |
| `LegalNormalizer` protocol: added `var passID: NormalizationPassID` | same |
| `NormalizationOutcome`: added `passes: [NormalizationPassID]` (run order, including passes that changed nothing) | `NormalizationOutcome.swift` |
| `LegalNormalizationPipeline`: records `passes`; `precondition`s unique pass ids (a configuration invariant) | same |
| `LookupTableNormalizer`: per-occurrence located records; one step per table entry | `LookupTableNormalizer.swift` |
| `NormalizationReplay.steps(of:)`: executable reconstruction/verification, typed failures | new `NormalizationReplay.swift` |

`sourcePackID` is unchanged and no longer used for anything pass-related
(tested with a lookup entry whose pack id collides with a Phase 3 label).

## 3. Exact coordinate invariants (the contract; documented in `LegalNormalizer.swift`)

1. `range` is an explicit UTF-16 `NSRange` (NSString offsets).
2. A record's coordinate space is `(pass, step)`: `range` indexes the exact text
   that was the **input of that step — before its changes** — never its output,
   another pass's text, or the final text.
3. `trigger` is exactly the text at `range` in that input space.
4. Passes run in `NormalizationOutcome.passes` order; a pass is a sequence of
   steps in ascending `step`. All of a step's records index that step's own input
   and do not overlap. Statutory and witness passes are single-step (`step == 0`).
   The lookup pass has one step per resolved-table entry, in table order, each
   against the text left by the previous entry (`step` = table index).
5. A step's output = its input with each applied record's `range` replaced by its
   `replacement`; declined records mark examined-and-preserved spans and do not
   change text.
6. Therefore `R --(passes, steps, applied records)--> N` is exactly reproducible
   from `NormalizationOutcome` alone; intermediate texts need not be stored.

## 4. Lookup provenance solution

Previously: one aggregate record per table entry, `range == nil`, covering every
occurrence, with later coordinates shifted by unrecorded amounts. Now each
occurrence is located directly (NSString search with the same non-literal,
non-overlapping, left-to-right comparison `replacingOccurrences` uses) and
recorded individually — applied **and** declined — in its step's input; the output
text is built from those same located occurrences, so provenance and text agree by
construction. Nothing is inferred later.

Sequential semantics are kept: entries apply in table order against the running
text (so a later entry can act on text an earlier one produced — `step` records
exactly which text each record indexes), and an entry is considered only if its
trigger occurs in the **original** input (unchanged gate). Two documented
refinements: (a) an entry that passes the gate but whose trigger an earlier entry
consumed now records nothing (previously a phantom, unlocatable aggregate;
output unchanged); (b) `trigger` is the exact matched text, differing from the
table trigger only for a canonically-equivalent match. Production is unaffected
today: the builtin pack ships 0 normalization entries.

## 5. Reconstruction proof and tests

`NormalizationReplay.steps(of:)` replays `recognized` through `passes`/steps,
verifying per record: range in bounds, `trigger` equals the text at `range`, no
overlap within a step; and that the final text equals `normalized`. Any
inconsistency is a typed failure (`unknownPass`, `rangeOutOfBounds`,
`triggerMismatch`, `overlappingRecords`, `finalTextMismatch`), never best effort.

`Tests/NormalizationProvenanceFoundationTests.swift` covers: typed identity on
every record and pass order; identity independent of `sourcePackID`; every lookup
occurrence located; length-changing sequential steps and the original-input gate;
consumed-entry (no phantom); declined occurrences located; adjacent/overlapping
candidates; canonical equivalence; a **600-case differential test of output text
against the pre-V1.10 algorithm** (odd Unicode, Odia, emoji, chained entries);
exact `R → L → S → N` reconstruction with the intermediate texts asserted; empty
and no-op passes; decline-only pass as an identity step; Unicode/Odia/non-BMP with
UTF-16 ranges; an **exhaustive 1,463-dictation corpus** all replaying exactly;
and fail-closed replay on tampered provenance (out-of-bounds, negative, shifted,
mismatched trigger, overlapping, unknown pass, wrong final text, missing record).
`NormalizationProvenanceCoordinateTests` (V1.9) keeps the still-valid coordinate
semantics (UTF-16, pre-change per-step input, descending order within a pass,
witness ranges in the statutory output) and was updated where the contract
intentionally changed (lookup now located; typed identity replaces the "no pass
identity" observation).

## 6. Compatibility impact

- Normalized text and the Phase 3 records' content are unchanged; existing
  normalizer/coordinator/processor suites pass. `protectsLeadingCapitalization`
  now excludes `pass == .lookupTable` explicitly (previously those records had no
  range and never matched), preserving its behavior exactly.
- Source-breaking type changes: `range` non-optional (call sites using `range?`
  / `.map` on it: `EvalRunner`, `protectsLeadingCapitalization`, and four test
  files, all updated); record initializers require `pass` and `range`;
  `NormalizationOutcome` has a `passes` member; conformers of `LegalNormalizer`
  need `passID` (only the three in-tree normalizers exist).
- Lookup counts of `appliedChanges`/`declinedChanges` are now per occurrence
  rather than per entry (evaluation output for lookup would grow; no lookup entries
  ship today). The evaluation JSON schema is unchanged and does not yet expose
  `pass`/`step`.
- Pre-existing lint violations in `Tests/LookupTableNormalizerTests.swift` (8
  `multiline_arguments`, present at V1.9's HEAD) were left untouched.

## 7. Is V1.11 protected-span derivation now deterministically possible?

**Yes, the coordinate problem is closed.** For any record, its range in the
step-input space maps to final `N` coordinates by a piecewise shift through the
applied replacements of every *later* step (replayable via
`NormalizationReplay`, with per-step verification that the mapped text equals the
`replacement` for applied records / `trigger` for declined ones). The remaining
V1.11 decisions are policy, not missing provenance: how to treat a span whose
endpoint falls strictly inside a later replaced span (e.g. a witness replacement
inside a declined statutory span) — recommended: fail closed with a typed
outcome — and how to represent applied-then-later-replaced changes. Provenance for
diagnostics/evaluation (and any later judge-verified data) is preserved in full
structured form; no such system was built.
