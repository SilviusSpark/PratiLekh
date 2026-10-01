# Intelligence V1.21 — Explicit Schema-Version Instruction Promotion

## 1. Status and scope

The first production code change in the Intelligence track since V1.16. Promotes the single
instruction change V1.19/V1.20 experimentally validated — adding one explicit
`schemaVersion`-requirement sentence to `ModelFacingGenerationContract.instructions` — and
nothing else. **No other prompt wording changed; the tool schema, the transport parser, the
addressing/composition/Safety Authority code, the permission gate, the V1.17 harness, and
the dictation path are all untouched.** Not wired into dictation.

## 2. Exact production change

`Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift`: one new
paragraph appended to the end of `instructions`, verbatim, exactly the sentence V1.19/V1.20
validated as "Arm B":

```
Every tool call you make must include the top-level field "schemaVersion": 1. A tool call that omits schemaVersion is invalid.
```

No other line in `instructions` changed. The Arm C structural example was **not** added
(out of scope for this milestone, per instruction). `toolDefinition` (the JSON schema) is
byte-for-byte unchanged.

## 3. Hash-equivalence proof (hard acceptance criterion)

The promoted `ModelFacingGenerationContract.instructions` was hashed exactly as V1.19/V1.20
did (SHA-256 over the UTF-8 bytes of the string) and compared against V1.19's frozen Arm B
hash:

```
actual:   249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88
expected: 249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88
MATCH: true
```

**Exact match, first attempt — no adjustment to the historical evidence was needed or made.**
The production contract text is now byte-for-byte identical to the text V1.19 ran 15 times
and V1.20 ran 15 more times (30 total real-model trials: 15/15 and 15/15 protocol compliance
respectively, including 6/6 clean on non-empty proposals per V1.20).

## 4. Regression test added (drift detection)

`Tests/ModelFacingGenerationContractTests.swift` gained two new tests, run via the existing
`scripts/test_intelligence_safety.sh`:

- `testInstructionsContainTheV1_21SchemaVersionRequirementSentence` — a readable,
  human-diagnosable substring check for the exact promoted sentence.
- `testInstructionsHashMatchesTheFrozenV1_19ArmBEvidence` — the byte-for-byte SHA-256 check
  against the same frozen hash verified in §3, so any future accidental edit to
  `instructions` (even a single character) fails this suite immediately, with a message
  explicitly warning against "fixing" the test by updating the hash rather than
  re-validating.

Both tests passed on first run, alongside the existing 17 tests in this file's suite.

## 5. Scope boundaries honored

Per explicit instruction, the following were **not** done: the Arm C structural example was
not added; the tool schema and parser are unchanged; generation parameters (temperature,
etc., which live only in evaluation/experiment code, not in this contract) were not touched;
addressing, Safety Authority, the permission gate, and harness behavior are unchanged; the
punctuation/empty-edit recall gap V1.20 flagged was not addressed (it is a separate,
unresolved, future question); no additional prompt engineering was performed; Intelligence
remains unwired from live dictation. `granite4:3b` was **not** rerun to reconfirm V1.19/V1.20
— the hash-equivalence proof in §3 is the acceptance criterion, and it was met exactly, so no
implementation reason emerged to justify a reconfirmation run.

## 6. Tests, build, lint

- `scripts/test_intelligence_safety.sh` — 11/11 suites PASS, including the two new drift
  tests.
- `scripts/test_intelligence_harness.sh` — 9/9 fixtures PASS, unaffected (the V1.17 fixtures
  construct stand-in provider responses directly and do not depend on `instructions` text).
- `scripts/test_protected_span_derivation.sh` — PASS, unaffected, same numbers as before.
- `scripts/test_autonomous_permission_gate.sh` (V1.16 hard gate) — PASS, same parity numbers
  as before.
- `swiftlint lint --strict` on both changed files — 0 violations.
- `./build.sh unsigned` — BUILD SUCCEEDED.

## 7. What this milestone does and does not establish

**Establishes:** the production model-facing instructions now contain exactly the sentence
experimentally shown (V1.19, V1.20) to take `granite4:3b`'s `schemaVersion` compliance from
0/15 to 15/15, including on non-empty proposals, under the exact runtime/schema this
contract already uses. The hash proof makes this a verified fact about the committed source,
not an assertion.

**Does NOT establish:** that this change improves correction quality, recall (V1.20's
punctuation-fixture 0/9 finding remains unresolved and unaddressed), or safety beyond what
was already evidenced by the deterministic V1.0–V1.16 suites and the V1.17/V1.20 real-model
runs. Does not wire Intelligence into dictation. Does not authorize any further prompt
engineering, model comparison, or live integration.

## 8. Not authorized by this milestone

Addressing the punctuation/empty-edit recall gap, adding the Arm C example or any other
prompt change, any further live-model experiment, dictation wiring, model
comparison/ranking/selection, and resuming the closed recognition-tuning branch — none of
these were done and none are authorized by this document.
