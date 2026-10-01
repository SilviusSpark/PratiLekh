# Intelligence V1.20 — Non-Empty Protocol Compliance Validation

## 1. Status and scope

Investigation only. **No change to `ModelFacingGenerationContract`, `ModelFacingEditTransportParser`,
any addressing/composition/Safety Authority code, the V1.17 harness, or any dictation path.**
Nothing under `Sources/Fluid/` or `Evaluation/Intelligence/Harness/` changed. **No production
contract change was made; Arm B was not promoted.**

**Question investigated:** V1.19 found Arm B (the production instructions plus one explicit
`schemaVersion`-requirement sentence) achieved 15/15 protocol compliance, but all 30 of its
compliant responses (Arms B and C combined) happened to propose zero edits. V1.20 asks the
question V1.19 explicitly left open: **does Arm B's protocol compliance survive when
`granite4:3b` must construct a real, non-empty V1 edit proposal, not just an empty one?**

**Method:** a single, pre-frozen experiment, hashed and integrity-checked before any model
call, executed start to finish with no mid-run edits. Reused the real, unmodified,
already-committed `IntelligenceHarnessPipeline.preflight`/`.evaluate` (V1.17),
`ModelFacingEditTransportParser.parse`, and `IntelligenceSafetyAuthority` (via the harness's
composition call) for every measurement — none of this was reimplemented. The experiment
binary, full 15-trial log, and raw responses were written under `/tmp/v120/` and were
**never copied into this repository** — this document records the frozen design, hashes,
and results in enough detail to reproduce the experiment from the already-committed V1.7
contract and V1.17 harness sources.

## 2. Frozen design and integrity verification

**Arm B instruction:** reconstructed identically to V1.19 (the same `ModelFacingGenerationContract.instructions`
plus the same explicit `schemaVersion`-requirement sentence) and **verified by a `precondition`
check — before any network call — against V1.19's recorded hash.** Result: **match confirmed
exactly**, `sha256=249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88`. The
tool schema hash (`d7a7cc2347d9f9f2b21561e0073f5fef183125edca916f658f9e62130265cc98`) also
matched V1.18/V1.19 exactly — the identical, unmodified `ModelFacingGenerationContract.toolDefinition`
was used throughout.

**Fixtures:** 5 short, controlled, synthetic texts, each engineered to require exactly one
unambiguous, harmless, predetermined transformation, each individually hashed at experiment
time:
- 3 punctuation fixtures (a missing trailing period, twice, and a missing comma).
- 2 capitalization fixtures (a lowercase proper noun, "ram das", requiring "Ram Das").

All 5 fixtures were confirmed to produce **zero protected spans** after real
`LegalDictationProcessor` normalization, so no fixture's measurement is confounded by legal
normalization or protected-span intersection.

**Repetitions:** 3 per fixture → **15 trials total.** Same scale/rationale as V1.19: enough
to distinguish reliable from occasional behavior at the per-fixture level without inflating
the call budget.

**Held constant throughout:** `granite4:3b`, local Ollama (`http://localhost:11434/v1/chat/completions`),
`temperature=0`, `stream=false`, `tool_choice=auto`, the real unmodified V1 tool schema, the
real unmodified strict transport parser.

## 3. Results (raw counts, no blending)

| Measurement | Result |
|---|---|
| Tool engagement | **15/15** |
| Strict V1 protocol compliance (parses successfully) | **15/15** |
| …of which non-empty `edits` | **6/15** |
| …of which valid empty `edits` (`{"schemaVersion":1,"edits":[]}`) | **9/15** |
| HTTP errors / non-engagement / multiple-tool-calls / parse failures of any kind | **0 / 0 / 0 / 0** |

**By fixture type:**
- Punctuation fixtures (3 fixtures × 3 reps = 9 trials): **0/9 non-empty** — every trial
  returned a valid, protocol-compliant empty-edits response.
- Capitalization fixtures (2 fixtures × 3 reps = 6 trials): **6/6 non-empty.**

**Of the 6 non-empty trials, every measurement was clean:**
- Structurally complete (valid `sourceText`/`replacementText`, parser-accepted): **6/6.**
- Addressing resolution (no `addressingRejected`): **6/6 resolved.**
- Predetermined transformation represented (frozen, pre-registered substring check,
  non-scoring): **6/6 true.**
- Safety Authority disposition: **6/6 `autonomouslyAccepted`**, 0 `reviewOnly`, 0
  `rejectedBySafetyAuthority`.

## 4. Interpretation

**V1.20 closes the specific non-empty protocol-adherence gap V1.19 left open, on the tested
cases: every one of the 6 non-empty proposals `granite4:3b` constructed under Arm B was
fully protocol-valid end to end** — correct `schemaVersion`, correct `edits` array, valid
`sourceText`/`replacementText`, correctly addressed, correctly classified, and correctly
autonomously accepted by the unmodified Safety Authority. This is the direct answer to
V1.20's question, and it is unambiguous: Arm B's protocol compliance does not degrade when
the model must construct a real, non-empty proposal.

**The 9/15 empty-edit responses on punctuation fixtures are not a protocol-compliance
failure.** Each one is a valid, well-formed, schema-compliant response
(`{"schemaVersion":1,"edits":[]}`) — exactly the wire-level outcome the strict parser is
designed to accept. V1.20 was designed and pre-registered to measure *whether a
constructed non-empty proposal remains protocol-valid*, not *whether the model chooses to
construct one*. The punctuation/capitalization split is accordingly recorded as a separate,
**model usefulness/recall finding** — whether the model recognizes a given fixture as
warranting a correction at all — not as evidence against protocol adherence.

**Unexpected behavior, recorded as evidence, not adapted to:** the split was 0/9 for all
three punctuation fixtures versus 6/6 for both capitalization fixtures — a clean, complete
split by edit type in this small sample. No prompt, fixture, or arm was changed in response
to this result.

## 5. What this experiment does and does not establish

**Establishes:**
- Arm B's protocol compliance (the `schemaVersion` fix V1.19 found) **survives unchanged
  when `granite4:3b` constructs a non-empty V1 proposal** — 6/6 clean on every measured
  dimension (structure, addressing, classification, Safety Authority acceptance,
  predetermined-transformation representation).
- **Arm B now has sufficient protocol evidence — across both the empty-edit case (V1.19)
  and the non-empty case (V1.20) — for a separate, future production-contract promotion
  decision to be made.** This document does not make that decision; it only establishes
  the protocol evidence is no longer incomplete in the way V1.19 flagged.

**Does NOT establish:**
- That `granite4:3b` reliably *recognizes when* a correction is warranted — the 0/9
  punctuation result is a real, unresolved recall/usefulness gap, not investigated further
  here (would require separate, differently-designed experiments).
- Any correction-quality conclusion (the 6/6 predetermined-transformation check is a
  frozen, non-graded presence check, not a quality score).
- Any safety conclusion beyond "these 6 specific proposals were correctly judged safe" —
  no proposal in this experiment was unsafe, so the Safety Authority's protective behavior
  was not exercised here; that remains evidenced only by the V1.17 deterministic fixtures
  and the V1.0–V1.16 adversarial suites.
- Generalization beyond `granite4:3b`, this runtime, this schema, these 5 fixtures, or this
  punctuation/capitalization split specifically.

## 6. Limitations

- Single model, single runtime, 5 fixtures, 3 repetitions — the 0/9 vs. 6/6 split is
  observed in this small sample only.
- The cause of the punctuation/capitalization split is **unknown** and was not
  investigated — doing so would require new, separately-designed and separately-authorized
  experiments.
- No fixture here exercised review-only or rejected-by-Authority dispositions, nor any
  protected-span interaction, nor a multi-edit response — the non-empty evidence is narrow
  (single-edit, single-category responses only).
- No correction-quality or safety scoring was performed or is claimed.

## 7. What did not happen

Confirmed by `git status`/`git diff` before this document was written: **no mid-run prompt
change, no selective retry, and no fixture or arm was added after seeing any outcome.** The
design was defined and hashed once, before the first of the 15 calls, and never edited
afterward. No change was made to `ModelFacingGenerationContract`, the transport parser, the
Safety Authority, the V1.17 harness, or any dictation-path code. **Arm B is not promoted by
this document** — it records that sufficient protocol evidence now exists for that decision
to be made separately, not that the decision has been made.

## 8. Diagnostic material

The experiment binary, full 15-trial log, and raw responses were written under `/tmp/v120/`
during the investigation and were never copied into this repository. They are not
preserved — this document's §2–§3 record the frozen design, exact hashes, and results in
enough detail to reproduce the experiment from the already-committed V1.7 contract and
V1.17 harness sources, without needing the original scratch files.

## 9. Not authorized by this milestone

Promoting Arm B into production, any further live-model experiment (including any
investigation into the punctuation/capitalization split), any prompt/schema/parser/policy
change, any model comparison/ranking/selection, any dictation wiring, and resuming the
closed recognition-tuning branch — none of these were done and none are authorized by this
document.
