# Intelligence V1.17 — Controlled Local-Model Integration Harness

## 1. Status and scope

Evaluation infrastructure only. **No dictation/`ContentView` wiring, no reviewer UI, no
new safety rule or recognizer, no insertion/addressing expansion, and no prompt/schema/
policy/model tuning** — see §4 for exactly what was and was not done after the real-model
run. Nothing under `Sources/Fluid/` changed. The deterministic Intelligence chain
(`ModelFacingGenerationContract`, `ModelFacingEditTransportParser`,
`IntelligenceAddressingResolver`/`Bridge`, `IntelligenceEditComposition`,
`IntelligenceSafetyAuthority` including the V1.16 gate) is exercised exactly as committed,
never modified.

V1.17 adds a standalone harness (`Evaluation/Intelligence/Harness/`) connecting the
existing, unmodified local `LLMClient` to the existing, unmodified Intelligence
deterministic chain, for one purpose: prove the chain handles a real local model's actual
output safely, end to end, before any live-dictation integration is considered.

## 2. Architecture

```
<sampleID>.txt (raw, post-ASR-like text)
  -> LegalDictationProcessor.process            (real production normalization)
  -> ProtectedSpanDerivation.derive (V1.11)
     + NumericStructuralProtection.spans (V1.13)
  -> IntelligenceHarnessProvider.propose         (LLMClient.shared.call, real local provider)
  -> IntelligenceProviderResponse(bridgingFrom:)  (existing V1.2 bridge)
  -> IntelligenceEditComposition.evaluate         (existing V1.7/V1.6/V1.0 chain, unmodified)
  -> IntelligenceHarnessReportFormatter           (adjudication-focused plain-text report)
```

Two compile targets enforce a hard separation between "is the harness's own plumbing
correct" and "what does a real model do":

- **`scripts/test_intelligence_harness.sh`** — compiles `Evaluation/Intelligence/Harness/`'s
  deterministic core (`IntelligenceHarnessPipeline`/`Types`/`LegalPack`/`Fixtures`/
  `ReportFormatter`) against the real LegalLanguage + Intelligence sources only. **No
  `LLMClient`, no network, no model anywhere in this build.** Runs
  `Tests/IntelligenceHarnessPipelineTests.swift`: 9 hand-written fixtures, each supplying
  its own stand-in `IntelligenceProviderResponse` (including a literal adversarial
  duplicate-JSON-key payload), asserting the exact expected bucket/reason via
  `precondition`. This is the hard gate that must pass before any model-quality run — so an
  integration bug in the harness can never be confused with a real model's behavior.
- **`scripts/intelligence_harness_run.sh`** — additionally links `LLMClient`,
  `DebugLogger`, `FileLogger`, `ThinkingParsers` (confirmed standalone-compilable: all four
  import only `Foundation`/`Darwin`) and `IntelligenceHarnessProvider`/`Runner`. The only
  place a real provider is ever called. Fail-closed by construction: a thrown `LLMClient`
  error is caught in `IntelligenceHarnessProvider.propose` and reported as
  `.providerFailure` — `IntelligenceHarnessPipeline.evaluate` (and therefore every
  Intelligence/composition type) is never invoked for that sample.

`--tier synthetic|real-dictation` is mandatory on every live run and is stamped into every
report line and output filename, so the two evidence tiers can never be silently combined.
`--text-dir`/`--out` are refused if they resolve inside the Git repository (same discipline
`Evaluation/Runner/EvalRunner.swift` already enforces).

A harness-local `applyAccepted` helper replays only `.autonomouslyAccepted` edits,
right-to-left, to compute the "would-be output" shown in each report. This duplicates (in
~10 lines) the already-tested algorithm `IntelligenceSafetyAuthority.applyAcceptedEdits`
already uses internally, rather than changing `IntelligenceEditComposition`'s public shape
to expose its deliberately-discarded `resultingText` — accepted edits are already
guaranteed pairwise non-overlapping by the Authority itself, so the replay cannot conflict.
No Composition API change was made; implementation did not prove one necessary.

## 3. Deterministic verification (no model, no network)

All 9 fixtures in `IntelligenceHarnessFixtures.swift` passed via
`scripts/test_intelligence_harness.sh`, exercising every report bucket:

| Fixture | Proves |
|---|---|
| F-A zero edits | a well-formed empty-edits response evaluates with zero proposals, unchanged would-be output |
| F-B safe punctuation | a terminal, routine-punctuation edit outside any protected span is `autonomouslyAccepted(punctuationOnly)` |
| F-C intersects resolved span | a proposal changing a statutory number (`302`→`304`) inside an applied `Section 302 IPC` normalization is `rejected(intersectsResolvedSpan)` — **never accepted, never even review-only** |
| F-D unsupported category | a word-level content change (`accused`→`defendant`) is `rejected(unsupportedEditCategory)` |
| F-E addressing no match | a hallucinated quote (`pled`, never in the source) is `addressingRejected(noLiteralMatch)` |
| F-F malformed duplicate key | a duplicate top-level JSON key fails the whole response, never silently resolved to the last value |
| F-G free text instead of tool call | a response with prose and no tool call fails the whole response as `unexpectedTextContent` |
| F-I V1.16 gate (word merge) | `"Ram Das"→"RamDas"`, outside any protected span, is `reviewOnly(wordBoundaryMerged)` via the V1.16 gate specifically |
| F-J repeated text by occurrence | `occurrence=2` on twice-repeated text resolves to the second occurrence and is autonomously accepted |

F-C and F-I are the two load-bearing demonstrations: a locally-plausible but dangerous edit
is rejected outright even though it is well-formed and correctly addressed, and the V1.16
gate specifically (not just protected spans) independently blocks a structurally dangerous
edit outside any protected span.

## 4. First real-model observation

**Exact, verbatim record — nothing beyond what was actually observed:**

- **Model:** `granite4:3b` (3.4B, Q4_K_M) — the same research/protocol candidate V1.3C
  identified, run via **Ollama**, the local OpenAI-compatible runtime (`ollama serve`,
  `http://localhost:11434/v1`), already installed and already holding this model on this
  machine from the prior V1.3 research track.
- **Samples:** 4 controlled/synthetic samples (short, hand-written, clean text) and 6
  existing **private** real-dictation-derived samples (the raw, post-ASR text already
  captured in a prior real-audio diagnostic run, `pratilekh-eval-results-post-3fb/
  2026-09-27T104836Z/{N01,N03,N05,N10,P01,Y01}.result.json`'s
  `observedNormalization.input` field) — **kept as two separate evidence tiers**, run and
  reported independently, never combined in one invocation or one output file.
- **Result, all 10 samples across both tiers:**
  - All 10 provider calls **succeeded** (real HTTP round trips to the local Ollama server,
    non-streaming, `tool_choice: "auto"`, temperature 0).
  - All 10 responses **engaged tool calling** correctly — the model called
    `propose_literal_transcript_edits` with a well-formed `edits` array (literal
    `sourceText`/`replacementText` pairs, in several cases correctly using
    `occurrence`/`leftContext`).
  - All 10 responses **omitted the required `schemaVersion` field.**
  - All 10 therefore **failed closed** at the existing, unmodified strict wire parser
    (`ModelFacingEditTransportParser`), reported as
    `wireParseFailure(ModelFacingEditParseFailure.missingField("schemaVersion"))` —
    the exact same typed failure this parser's own adversarial test suite already covers.
  - **Zero edits reached autonomous acceptance.** Zero edits reached review-only or
    rejected-by-Authority either — no edit was individually addressed at all, because the
    whole response failed before any per-edit processing began. Zero crashes, zero
    exceptions, zero special-casing needed anywhere in the Intelligence chain.

## 5. What this run does and does not establish

**Establishes:**
- **Mechanical end-to-end integration**: a real local model, called through the existing,
  unmodified `LLMClient`, reached and engaged the existing, unmodified V1 model-facing
  contract, across two independently-evidenced tiers (synthetic and real-dictation-derived
  text).
- **A protocol-compliance finding**: under this harness's exact request framing (the frozen
  `ModelFacingGenerationContract` instructions, delivered as a system message, with the
  normalized text as the user message, non-streaming, temperature 0), `granite4:3b`
  consistently omits `schemaVersion` even while otherwise constructing a well-formed
  `edits` array.
- That the existing strict parser's fail-closed behavior, previously proven only against
  synthetic adversarial fixtures, **also holds against genuinely unscripted real-model
  output** — nothing had to be relaxed, patched, or special-cased to keep the system safe
  when a real model didn't comply with the schema.

**Does NOT establish, and this run cannot speak to:**
- **Model correction quality** — whether `granite4:3b`'s proposed edits (had they carried
  `schemaVersion`) would have been *good* corrections. No proposal reached the addressing
  or Safety Authority stage in any of the 10 samples, so there is no adjudicated edit to
  judge quality from.
- **Model safety** — whether the model would ever propose an unsafe edit that reaches
  autonomous acceptance. No proposal crossed the strict transport boundary in this run, so
  the Safety Authority was never exercised against a real model proposal here; its
  behavior against real proposals remains evidenced only by the deterministic fixtures in
  §3 and by the V1.0–V1.16 adversarial test suites, not by this run.
- Anything about other models, other prompt framings, or other providers.

**This is a protocol-compliance observation only, from one run, one model, one prompt
framing — not a verdict on `granite4:3b`, not a verdict on this contract's viability, and
not a basis for comparing to any other model.**

## 6. What did not change in response to this result

Per explicit instruction, confirmed by `git status`/`git diff` before this document was
written: **no change was made to `ModelFacingGenerationContract` (schema or instructions),
`ModelFacingEditTransportParser`, `IntelligenceAddressingResolver`/`Bridge`,
`IntelligenceSafetyAuthority`/`AutonomousPermissionGate`, any frozen V1.12/V1.14/V1.15/V1.16
evidence, the harness's own behavior, or any dictation-path code, after observing the
`schemaVersion`-omission result.** The result is recorded as evidence only. Whether to
adjust the contract, the prompt, or try a different model is an explicit, separate,
not-yet-authorized decision for a future milestone.

## 7. Privacy

The 6 real-dictation samples' raw text, and both generated report files, were written only
to a path outside the Git repository (a session scratch directory) and were never copied
into this repository. Nothing from them appears in this document beyond the sample IDs and
the aggregate finding above (per §4) — no dictation text is quoted here.

## 8. Housekeeping

`ollama serve` was started by this session (to exercise the harness against a real local
model) and has been stopped after the run completed; it was not otherwise needed. The
already-pulled `granite4:3b`/`granite4:350m`/`qwen2.5:1.5b` models were not removed (left
exactly as the prior V1.3 research track left them).

## 9. Not authorized by this milestone

Resuming the recognition-tuning branch, any prompt/schema/policy change in response to
§4's finding, any dictation/`ContentView` wiring, a reviewer UI, insertion/addressing
expansion, any new recognizer, and comparing `granite4:3b` against any other model —
none of these were done and none are authorized by this document.
