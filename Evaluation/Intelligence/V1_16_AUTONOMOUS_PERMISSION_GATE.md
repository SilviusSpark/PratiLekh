# Intelligence V1.16 — Autonomous Permission Gate

## 1. Status and scope

V1.16 implements the production policy V1.14/V1.15 recommended: a **separate,
narrow, deterministic type** — `Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift`
— consumed by `IntelligenceSafetyAuthority` as a new pipeline step. It downgrades
specific structurally-dangerous punctuation-only/capitalization-only/whitespace-only
edits from `.autonomouslyAccepted` to `.reviewOnly`, using exactly the five validated
invariants below. It is **not** folded into `IntelligenceEditClassifier` (V1.15's
architecture-boundary finding: the classifier is a pure two-string diff with no
surrounding-context access, and these invariants need context the classifier does not
receive). Nothing else in the pipeline changed: parsing, addressing, composition,
protected-span derivation and numeric structural protection are untouched. **Not
wired into dictation.**

## 2. The five validated rules

Ported unmodified in *effect* from the frozen `AutonomousEditInvariants.swift`
(V1.14/V1.15's experimental rules file, still byte-for-byte unchanged and still used
only by the historical investigation scripts — see §6):

| Rule | Category it constrains | Blocks |
|---|---|---|
| **P-A** | punctuation-only | A changed punctuation character outside the routine allowlist (`. , ; : ? ! ।`) |
| **P-B** | punctuation-only | Any punctuation change immediately adjacent to a letter/digit on both sides (intra-token) |
| **W-A1** | whitespace-only | A whitespace run collapsing from non-empty to empty where both flanks are word-forming (a merge) — **merge-only**; a split (empty → non-empty) is never blocked by this rule |
| **C-A2** | capitalization-only | A capitalization change inside a token that has ≥2 uppercase letters (an acronym/identifier shape), when the change lowers case |
| **C-C** | capitalization-only | Any capitalization change inside a token that also contains a digit |

These are exactly the `core-merge-only+P-A` bundle V1.14 recommended and V1.15
re-validated on a fresh corpus — no rule was added, removed, or retuned. `.other`
classification (edits that are none of punctuation/capitalization/whitespace-only)
is never routed through the gate at all; it is unconditionally `.rejected`, as
before V1.16.

Deliberately **not** addressed (per V1.14/V1.15's explicit scope, and per this
milestone's own instruction not to expand it): word splits (`witness reached` /
`const able` are structurally identical without a dictionary), the single-letter
designator residual (`Ext. P-9` lowering `P`), and the `viz.`/`O'Connell`-style
punctuation-split token-boundary cases V1.15 flagged as a recurring but unresolved
pattern.

## 3. Boundary-directed scanning, not a fixed permissive window

Each rule needs to know what surrounds the edit (whether a flanking character is a
letter, whether a token contains an uppercase run or a digit, whether a punctuation
run continues). Rather than copying a fixed-size context window (which would either
be too small for some tokens or copy whole-document prefixes/suffixes for others),
`AutonomousPermissionGate` scans outward from the edit boundary, one `Unicode.Scalar`
at a time via `String.Index`, stopping as soon as the rule's own question is
answered (e.g. the first non-letter ends a token scan; the first non-punctuation ends
a punctuation-run scan).

**Resource bound, fail-closed:** `maxBoundaryScan = 64` scalars in each scan
direction. This exists only so a pathological input (e.g. one 10,000-scalar token
with no boundary) cannot make a single proposal's evaluation unbounded — it is
**not** a permissiveness threshold. Every caller treats `exceededBound == true` as
"block" (i.e. `.reviewOnly`), never as "the answer is unknown, so permit." No
observed case in any of the three frozen corpora (§5) approaches this bound; it
exists for defense against inputs the corpora don't represent.

## 4. Authority integration

`ProposalDisposition.ReviewReason` gained five new flat cases
(`.nonRoutinePunctuationChanged`, `.intraTokenPunctuationChanged`,
`.wordBoundaryMerged`, `.acronymCapitalizationLowered`,
`.identifierCapitalizationChanged`), one per `AutonomousPermissionBlock` case, via an
exhaustive `AutonomousPermissionBlock.reviewReason` mapping — never a generic
"blocked by gate" catch-all, so a `.reviewOnly` disposition always states which rule
fired.

In `IntelligenceSafetyAuthority`, after a surviving candidate is classified as
`.punctuationOnly`, `.capitalizationOnly`, or `.whitespaceOnly` (all earlier
steps — range validity, source-text match, no-op rejection, overlap, protected-span
intersection — unchanged and evaluated first, exactly as before V1.16), the gate is
consulted once. A block downgrades the disposition to `.reviewOnly(reason)`; no
block leaves `.autonomouslyAccepted(classification)` exactly as before V1.16. The
gate is **never** consulted for `.other` and **never** produces `.rejected` — its
only effect is narrowing what was already going to be autonomous into review-only.

## 5. Production-parity validation against all three frozen corpora

**Hard acceptance gate for this milestone:** `Tests/AutonomousPermissionGateProductionParityTests.swift`
(`GateParityReplayTests`, run via `scripts/test_autonomous_permission_gate.sh`) reads
the three corpora V1.14/V1.15 already froze
(`Evaluation/References/autonomous-edit-policy/{development,validation,fresh}.json`),
verifies each against its already-pinned SHA-256 before doing anything else, then
replays every entry through the **real production pipeline** — `LegalDictationProcessor`
normalization → `ProtectedSpanDerivation` → `NumericStructuralProtection` →
`IntelligenceAddressingResolver` → `IntelligenceSafetyAuthority.validate` with the
V1.16 gate active — and asserts the result reproduces the **already-published**
V1.14/V1.15 aggregate numbers exactly (copied from their findings documents, not
re-derived from the old experimental harness, which measured a different,
pre-gate Authority — see §6):

| Corpus | Legit autonomous | Dangerous autonomous | Acronym-guard demotion |
|---|---|---|---|
| `development.json` | 67/69 (expected 67) | 6/74 (expected 6) | `AD-010` |
| `validation.json` | 47/48 (expected 47) | 9/68 (expected 9) | `AV-010` |
| `fresh.json` | 49/51 (expected 49) | 11/67 (expected 11) | `AF-007` |

All three match exactly. This is the same one-legitimate-edit-lost-per-tier cost
V1.14/V1.15 already documented (the acronym-capitalization guard, C-A2, demoting a
legitimate all-caps→title-case correction such as `ODISHA`→`Odisha`) — V1.16
reproduces it in production rather than introducing a new cost.

## 6. Why the old investigation scripts now fail their own pins, and why that's expected

`scripts/test_independent_protection_investigation.sh` (V1.12) and
`scripts/test_autonomous_edit_policy_investigation.sh` (V1.14/V1.15) each contain
`precondition`-pinned numbers measured by running their own experimental detectors
through the classifier/Authority **as it existed before V1.16** — i.e. with no
autonomous-permission gate. Now that the gate is a real `IntelligenceSafetyAuthority`
step, those two scripts' own internal replay paths (which link against
`Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift` for compilation,
since `ProposalDisposition` now references it, but do not themselves consult it the
same way production code order does) produce different — generally *fewer* hazard
escapes — counts than their pinned expectations, and their `precondition` calls
abort with "pinned evidence changed."

This is **expected, not a regression**: both scripts already self-identify as
"EXPERIMENTAL", "investigation only", and "not part of the normal acceptance gate"
in their own header comments, and neither is part of `./build.sh unsigned` or the
`scripts/test_intelligence_safety.sh` acceptance suite. A short note has been added
to the top of each affected finding document
(`V1_12_INDEPENDENT_PROTECTION_FINDINGS.md`, `V1_14_AUTONOMOUS_EDIT_POLICY_FINDINGS.md`,
`V1_15_FRESH_AUTONOMOUS_POLICY_VALIDATION.md`), following this repository's existing
"Amended by" precedent (`V1_5_ADDRESSING_CONTRACT_FREEZE.md`'s "Amended by V1.6"
note), explaining that their pinned numbers are a **historical, pre-V1.16
measurement**, pointing to §5 above as the measurement that *is* current. **Nothing
about the two scripts' pinned numbers, their frozen corpora, or `AutonomousEditInvariants.swift`
was changed or repinned** — only the compile list (the new source file, required
because `ProposalDisposition.swift` now references it) and the explanatory notes
above. Anyone running either script going forward will see a `precondition` failure
with a clear, discoverable explanation rather than an unexplained crash that looks
like a new defect.

## 7. What this does and does not establish

- **Established:** the exact five-rule bundle V1.14 recommended and V1.15
  re-validated is now live in `IntelligenceSafetyAuthority`, reproduces both
  documents' published numbers exactly against all three frozen corpora, and adds
  no new legitimate-edit cost beyond the one already documented per corpus.
- **Not established, and not attempted:** word-split detection, the designator/
  single-letter residual, the `viz.`/`O'Connell` punctuation-split pattern, any new
  recognizer, any change to `IntelligenceEditClassifier`'s two-string diff contract,
  any change to protected-span derivation or numeric structural protection, edit
  application, or any model/provider/dictation wiring. All remain exactly as
  undecided as V1.14/V1.15 left them.

**Do not wire Intelligence into dictation from this milestone** — that decision is
independent of this gate and has not been made.
