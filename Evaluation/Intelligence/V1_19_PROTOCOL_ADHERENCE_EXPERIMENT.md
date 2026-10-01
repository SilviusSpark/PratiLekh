# Intelligence V1.19 — Protocol Adherence Experiment

## 1. Status and scope

Investigation/experiment only. **No change to `ModelFacingGenerationContract`,
`ModelFacingEditTransportParser`, any addressing/composition/Safety Authority code, the
V1.17 harness, or any dictation path.** Nothing under `Sources/Fluid/` or
`Evaluation/Intelligence/Harness/` changed. **No production contract change was made or
promoted** — Arm B is recorded below as an experimentally-supported *candidate*, not a
production decision.

**Question investigated:** following V1.18's finding that `granite4:3b` reliably omits the
required `schemaVersion` field under the frozen production contract, can instructional
presentation alone — with no schema, parser, or policy change — make the model satisfy the
existing V1 wire contract reliably?

**Method:** a single, pre-frozen three-arm experiment, hashed before any model call,
executed start to finish with no mid-run edits, against the real, unmodified
`ModelFacingGenerationContract.toolDefinition` (schema) and the real, unmodified
`ModelFacingEditTransportParser.parse` (compliance classification). All 45 calls used
identical model, runtime, schema and generation parameters — only the system instruction
text varied by arm. The experiment binary, full per-call log, and raw responses were
written under `/tmp/v119/` during the investigation and were **never copied into this
repository** — this document records the frozen matrix, hashes and results in enough
detail to reproduce the experiment from the already-committed V1.7 contract source.

## 2. The frozen matrix (hashed before the first inference call)

**Arms** (Arm A is `ModelFacingGenerationContract.instructions` read verbatim from the real
committed source at experiment time — never hand-transcribed):

| Arm | Construction | SHA-256 | Length |
|---|---|---|---|
| A-baseline | `ModelFacingGenerationContract.instructions`, unmodified | `19862dde1546c22253db3094c597659dfdaab8a41efbcf92d1d188ac6446e973` | 1927 chars |
| B-explicit-requirement | A + one added sentence (below) | `249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88` | 2055 chars |
| C-structural-example | B + one minimal example (below) | `b1bb1476fb84cff9f514c72b981f63539f4deee136b98987a0df40bcfa73fb20` | 2113 chars |

- Arm B's addition (exact text): *"Every tool call you make must include the top-level
  field `"schemaVersion": 1`. A tool call that omits schemaVersion is invalid."*
- Arm C's addition on top of B (exact text): *"Minimal valid example:
  `{"schemaVersion": 1, "edits": []}`"* — deliberately an empty-`edits` example, to
  demonstrate pure structural form without biasing the model toward any specific edit
  content.

**Samples:** 5 short, controlled, synthetic, non-private texts (`E1`–`E5`, e.g. "the
accused was present in court", "Ram Das appeared as a witness"), each individually hashed
at experiment time (hashes recorded in the full run log, not reproduced here since the
sample *text* itself is already given in full in §4 of the prior investigation report and
is non-sensitive).

**Repetitions:** 3 per sample per arm → **15 trials per arm, 45 total.**

**Held constant across all 45 calls, verified by hash where applicable:**
- Model: `granite4:3b`.
- Runtime/endpoint: local Ollama, `http://localhost:11434/v1/chat/completions`.
- Tool schema: `ModelFacingGenerationContract.toolDefinition`, hash
  `d7a7cc2347d9f9f2b21561e0073f5fef183125edca916f658f9e62130265cc98` — identical object for
  every call across all three arms.
- Generation parameters: `temperature=0`, `stream=false`, `tool_choice=auto`.
- Compliance classification: the real, unmodified `ModelFacingEditTransportParser.parse`.

**Sample/repetition rationale (recorded before running):** 5×3=15 per arm was chosen to let
a near-0% or near-100% result be distinguished from occasional/flaky compliance — a single
trial per sample cannot separate "reliable" from "lucky" — while remaining consistent with
the small-sample scale already used in V1.17 (10 trials established a 0/10 baseline) and
V1.18. No arm, sample, or parameter was added, removed, or adjusted after this matrix was
defined and hashed.

## 3. Results (raw counts, no blending)

| Arm | Tool engagement | Protocol compliance (conditional on engagement) | Failure reasons |
|---|---|---|---|
| A-baseline | 15/15 | **0/15** | `missingField("schemaVersion")` × 15 |
| B-explicit-requirement | 15/15 | **15/15** | — |
| C-structural-example | 15/15 | **15/15** | — |

**Zero HTTP errors, zero tool-engagement failures, zero multiple-tool-call responses across
all 45 trials.** Every one of Arm A's 15 failures was the identical reason: a missing
top-level `schemaVersion` field, matching V1.18's finding exactly. Arms B and C reached
the same compliance ceiling (15/15 each) — **the structural example in Arm C produced no
measurable protocol-compliance benefit beyond the explicit instruction in Arm B.**

## 4. The confound (recorded, not interpreted further)

Every one of Arm A's 15 responses proposed an actual (mostly genuine, occasionally
no-op) edit. **All 30 of Arm B's and C's responses proposed zero edits.** This is an
important, directly observed confound: the added instruction may have shifted the model
toward a more conservative/literal response mode generally, not specifically toward
including `schemaVersion`. Per the experiment's explicit scope, correction quality was not
evaluated and this observation is not interpreted beyond stating it.

**Resulting limitation, stated explicitly: V1.19 does not establish that Arm B's wording
remains protocol-compliant when `granite4:3b` emits a non-empty edit proposal.** All 30
compliant responses observed in this experiment happened to be zero-edit responses; whether
`schemaVersion` is still reliably included alongside a real, non-trivial `edits` array is
untested and unknown from this evidence.

## 5. What this experiment does and does not establish

**Establishes:** under this exact model, runtime, schema, and these exact controlled
samples, explicit instructional presentation of the `schemaVersion` requirement took
measured protocol compliance from 0/15 to 15/15; a minimal structural example added on top
produced no further measurable compliance benefit (also 15/15).

**Does NOT establish, and this experiment cannot speak to:**
- Correction quality — no proposed edit's correctness was evaluated (none of B/C's 30
  responses proposed any edit at all).
- Model safety — no proposal in this experiment reached addressing or the Safety Authority;
  compliance was measured at the transport-parser boundary only.
- Whether Arm B (or C) remains compliant on a non-empty edit proposal (§4's limitation).
- Generalization beyond `granite4:3b`, this runtime, this schema, or these 5 samples.
- Any ranking or comparison between models — no other model was run in this experiment.

## 6. What did not happen

Confirmed by `git status`/`git diff` before this document was written: **no mid-run prompt
change, no retry aimed at a preferred outcome, and no additional arm was introduced after
seeing any outcome.** The three arms, five samples, and all generation parameters were
defined and hashed once, before the first of the 45 calls, and never edited afterward. No
change was made to `ModelFacingGenerationContract`, the transport parser, the Safety
Authority, the V1.17 harness, or any dictation-path code. **Arm B is recorded as the
smallest experimentally-supported candidate instruction change — it is explicitly not
production-approved, and no production file was modified to adopt it.**

## 7. Diagnostic material

The experiment binary, full per-call log (all 45 raw responses), and sample/arm hashes were
written under `/tmp/v119/` during the investigation and were never copied into this
repository. They are not preserved — this document's §2–§4 record the frozen matrix, exact
arm wording, hashes, and results in enough detail to reproduce the experiment from the
already-committed V1.7 (`ModelFacingGenerationContract`) source, without needing the
original scratch files.

## 8. Smallest evidence-supported recommendation (not executed)

The evidence supports Arm B's added sentence as the smallest experimentally-supported
candidate change to the production instructions, **conditional on first closing the §4
gap** (confirming compliance holds when the model proposes a non-empty edit) before any
production adoption. This is a recommendation only — **no instruction variant has been
promoted, and no production file has been modified.**

## 9. Not authorized by this milestone

Promoting Arm B (or C) into production, any further live-model experiment, any
prompt/schema/parser/policy change, any model comparison/ranking/selection, any dictation
wiring, and resuming the closed recognition-tuning branch — none of these were done and
none are authorized by this document.
