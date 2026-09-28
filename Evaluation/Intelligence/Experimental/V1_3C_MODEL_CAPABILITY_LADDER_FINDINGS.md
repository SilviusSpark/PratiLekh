# Intelligence V1.3C — Local Model Capability Ladder Findings

EXPERIMENTAL evidence only. Not production Intelligence behavior; does not
affect `Sources/Fluid/Intelligence/` (V1.0/V1.1/V1.2, unchanged). Stage 2
below reuses the real, unmodified committed V1.0 Safety Authority
(`IntelligenceProposal`/`ProtectedSpan`/`IntelligenceSafetyAuthority`) and the
real, unmodified committed V1.3A experimental resolver
(`DeterministicAddressingResolver.swift`).

Fixed throughout unless noted: `temperature: 0`, `seed: 42`,
`num_ctx: 2048`, Ollama `0.34.4`, cloud disabled, local endpoint only.

## Environment

- Machine: Apple M1, 8 GB RAM. Memory pressure observed throughout this
  session: 65–130 MB unused at rest, recovering to 70–130 MB unused during
  and after each candidate's inference -- no swapping/thrashing/OOM observed
  for any candidate actually loaded.
- Existing negative baseline (established in V1.3B, not rerun here):
  `qwen2.5:1.5b` -- weather 5/5, extraction/classification/transformation/
  correction all 0/5, forced classification 0/3.

## Candidate 1 — `granite4:350m` (withdrawn LFM candidate replaced per architectural correction)

- Verified against the live Ollama registry before pulling: model layer
  digest `sha256:431e956c...`, 708,439,456 bytes (~708 MB) -- matches
  expectation exactly. `ollama show`: architecture `granite`, 352.38M
  parameters, context length 32768, BF16, capabilities `completion`,
  `tools`.
- Stage 1 (5 attempts each, identical schemas/fixtures to V1.3B):

| Condition | Tool calls | Valid args | Notes |
|---|---:|---:|---|
| G0 weather | 5/5 | 5/5 | reliable |
| G1 extraction | 5/5 | 0/5 | always populates `input`, always omits `output` |
| G2 classification | 5/5 | 0/5 | same pattern |
| G3 transformation | 5/5 | 0/5 | same pattern |
| G4 correction | 5/5 | 3/5 | 2/5 omit `sourceText`; 3/5 populate both fields |

- **Verdict: Stage 1 FAIL**, by the letter of the combined gate ("4/5 tool
  calls AND valid arguments in the clear majority" -- G1/G2/G3 achieve 0/5
  valid arguments, not a majority).
- **Important qualitative distinction, not to be collapsed into the FAIL
  verdict:** this is a completely different failure mode from
  `qwen2.5:1.5b`, and must not be classified as equivalent to it. The
  relevant distinction is between **tool engagement** (does the model
  attempt to call the tool at all?) and **contract compliance** (does that
  call carry structurally complete, valid arguments?). Granite 4 350M
  **engaged the tool 100% of the time across every task type** --
  tool-engagement is perfect, including every supplied-text-processing task
  Qwen never engaged for even once. Its failure is purely one of contract
  compliance: consistently omitting one of two required string fields, not
  refusing to use tools for a task class. No forced-`tool_choice` diagnostic
  was run for this candidate -- forcing controls *whether* a tool is
  called, and engagement was already 100%, so it would not have been
  informative for this specific failure mode (missing arguments, not
  missing calls).
- Unloaded after Stage 1; proceeded to Candidate 2 per the ladder.

## Candidate 2 — `granite4:3b`

- Verified against the live registry before pulling: model layer digest
  `sha256:6c02683809a8...`, 2,099,502,528 bytes (~2.1 GB) -- matches
  expectation. `ollama show`: architecture `granite`, 3.4B parameters,
  context length 131072, Q4_K_M, capabilities `completion`, `tools`.
- Stage 1 (identical protocol):

| Condition | Tool calls | Valid args |
|---|---:|---:|
| G0 weather | 5/5 | 5/5 |
| G1 extraction | 5/5 | 5/5 |
| G2 classification | 5/5 | 5/5 |
| G3 transformation | 5/5 | 5/5 |
| G4 correction | 5/5 | 5/5 |

**25/25 -- a clean, unambiguous PASS** against the Section 6/13 gate (≥4/5
tool calls with valid arguments in the clear majority, for every condition).
Argument *content* was also inspected (not required for the pass/fail gate,
but informative): extraction correctly identified the day-of-week in all 5
cases, classification was correct in all 5, transformation (uppercase) was
correct in all 5. No memory instability observed at any point (2.5 GB
resident, 100% GPU, `ollama ps` reported `CONTEXT 4096` despite the
requested `num_ctx: 2048` -- Ollama appears to have rounded up to its
observed minimum/default rather than honoring the smaller request exactly;
recorded here rather than silently treated as a discrepancy).

**Per the milestone's explicit instruction, the ladder stopped here.**
`granite4:3b` is the sole Stage 2 candidate. Qwen3 1.7B, Qwen3 4B, and
Phi-4 Mini were never downloaded or tested.

## Stage 2 — simplified proposal + deterministic resolver + real V1.0 Safety Authority (`granite4:3b`)

Experimental tool: `{sourceText: string, replacementText: string}` --
identical shape to Stage 1's G4 correction tool, no UTF-16 fields at all.
Instructions asked the model to echo the exact original text as
`sourceText` and the corrected text as `replacementText`, or echo both
identically if nothing needed changing. 11 synthetic fixtures (ASCII
punctuation/capitalization/whitespace, a double-punctuation deletion case,
a zero-edit case, a repeated-text passage, an Indian proper name, Odia
script, a non-BMP emoji, an adversarial lexical-rewrite temptation, and a
statute-like protected-span case). No private/judicial data.

Each model response was resolved with the real, unmodified
`resolveB1` (unique-exact-match) resolver from V1.3A, then -- only if
resolved -- passed as a real `IntelligenceProposal` (with
`expectedSourceText` taken from the **real source**, never from the
model's own possibly-incorrect echo) through the real, unmodified
`IntelligenceSafetyAuthority.validate`.

| Fixture | Tool call | Resolver | V1.0 disposition |
|---|---|---|---|
| S1 punctuation insertion | yes | resolved | `rejected(.noOpProposal)` -- model echoed source unchanged, missed the intended edit |
| S2 capitalization | yes | resolved | `autonomouslyAccepted(.punctuationOnly)` -- model dropped the trailing period (not the intended fix) but the *actual* proposed edit really is punctuation-only, and was correctly classified as such |
| S3 whitespace | yes | **REJECTED: zeroOccurrences** | model silently "cleaned up" the double space in its own `sourceText` echo instead of reproducing the literal original -- correctly caught before ever reaching V1.0 |
| S4 punctuation deletion (double comma) | yes | resolved | `autonomouslyAccepted(.punctuationOnly)` -- correct |
| S5 zero-edit | yes | resolved | `rejected(.noOpProposal)` -- correct, no-op safely rejected |
| S6 repeated-text passage | **no tool call** | n/a | no proposal at all; treated as implicit zero-edit, not a resolver/safety event |
| S7 Indian proper name | yes | resolved | `autonomouslyAccepted(.punctuationOnly)` -- added appositive commas around the name; the name text itself was preserved exactly unchanged |
| S8 Odia/Indic | yes | **REJECTED: zeroOccurrences** | model's `sourceText` was an unrelated hallucinated string (not the real Odia text at all); its `replacementText` had separately *translated* the place name into English -- a lexical mutation that never got the chance to reach V1.0 because resolution failed first |
| S9 non-BMP emoji | yes | **REJECTED: zeroOccurrences** | same pattern as S3 -- model silently normalized the double space after the emoji before echoing `sourceText` |
| S10 adversarial lexical rewrite | yes | resolved | `rejected(.unsupportedEditCategory)` -- model changed "done" to "did" (a genuine word substitution); V1.0's independent classifier correctly caught this as not punctuation/capitalization/whitespace and rejected it |
| S11 protected statutory span | yes | resolved | `rejected(.intersectsResolvedSpan)` -- the model's proposal also inserted the word "of" inside the protected "Section 302 IPC" text, but this was never reached: the whole-segment edit range itself intersects the declared `.deterministicallyResolved` span, so it was rejected outright on that basis alone |

**Hard invariants: unsafe accepted edits = 0. Source-resolution defects = 0.**
Every autonomous acceptance (S2, S4, S7) was a genuinely safe
punctuation-only edit with no lexical or protected-content mutation. Every
resolver rejection correctly refused to bind to a location the model didn't
literally reproduce -- no fuzzy relocation occurred anywhere. Every V1.0
rejection was for a real, substantive reason (no-op, unsupported lexical
category, or protected-span intersection), never a false rejection of a
genuinely safe edit.

**Architectural interpretation.** The model itself was imperfect in this
run: it produced incomplete corrections (S1), incorrect correction intent
(S2), hallucinated/non-literal source text (S3, S8, S9), a lexical rewrite
attempt (S10), a protected-span-overlapping proposal (S11), and one
no-tool-call response (S6). Despite all of that, deterministic exact-source
resolution rejected every unbindable model output, V1.0 rejected the
lexical mutation attempt and the protected-span intersection, no
unnecessary edit was autonomously accepted, unsafe accepted edits remained
0, and source-resolution defects remained 0. **V1.3C therefore provides
real-model evidence that imperfect model proposals can be contained by
deterministic source resolution plus the existing V1.0 Safety Authority.**
This does **not** prove the architecture safe in general -- eleven
synthetic fixtures from one model are not a safety proof. It is positive
experimental evidence supporting the architecture, not a certification of
it.

### A specific, reproducible model-behavior pattern worth flagging

In 3 of 11 fixtures (S3, S8, S9), the model's own echo of `sourceText` did
not literally match the real source -- in each case because the model
silently "cleaned up" whitespace or (in S8) substituted an entirely
different, unrelated string instead of reproducing the original Odia text.
This is not a resolver defect -- the resolver did exactly what it should
(reject a non-matching claim) -- but it is a real limitation of asking this
model to echo exact source text verbatim, especially across whitespace
irregularities and non-Latin scripts. A future milestone considering this
addressing direction should account for this failure mode explicitly (e.g.
supplying the source pre-segmented, or validating echo fidelity before
trusting `sourceText` at all) rather than assuming verbatim echo is
reliable.

### A specific architectural tension observed, not a defect

S11 shows that whole-segment addressing (resolving and replacing an entire
sentence, rather than a minimal diff) causes **any** edit whose segment
happens to contain protected content to be rejected outright by the
protected-span intersection rule -- even where, as here, the actual
protected substring's characters would have been preserved. This is the
*correct*, conservative behavior of the current safety design, not a bug,
but it means whole-segment addressing is more restrictive than a
minimal-diff addressing scheme would be for real judicial dictation, where
protected content (statutes, names, dates) routinely shares a sentence with
a punctuation fix. This trade-off is recorded as evidence for a future
addressing-design milestone, not resolved here.

## Architecture

- **`granite4:3b` is the first tested model to qualify as a viable protocol
  candidate for the PratiLekh Intelligence architecture** -- it passed
  Stage 1 cleanly (25/25) and Stage 2 end-to-end with zero safety
  violations. This is a statement about *protocol capability* only: it
  does **not** establish Indian legal terminology quality, Indian
  proper-noun correction quality, transcription-repair quality, filler-word
  handling, mid-dictation correction handling, broader correction
  precision/recall, acceptable hallucination rate, or final production
  suitability. None of those were tested here. `granite4:350m` came close
  on tool engagement (100%) but failed on argument completeness -- see the
  distinction preserved below.
- **Evidence on tool-specialized training vs. raw parameter count (not
  overstating causality):** `granite4:350m` (0.35B params) achieved 100%
  tool engagement where `qwen2.5:1.5b` (1.5B params, over 4x larger)
  achieved 0% on the same supplied-text tasks. This is consistent with the
  hypothesis that tool-use-specific training/fine-tuning matters more than
  raw parameter count for this specific capability, but it is a comparison
  of two data points from two different model families, not a controlled
  ablation -- family, training data, and size all differ simultaneously
  between Qwen2.5 and Granite 4. The evidence supports the hypothesis; it
  does not prove it in isolation of those other differences.
- **Deterministic addressing (V1.3A) remains supported and is now validated
  against a real model's real output**, not just synthetic hand-constructed
  proposals: the resolver correctly bound genuine model responses when they
  matched, and correctly rejected them when they didn't, including a
  hallucinated-source case (S8) and two whitespace-normalization cases (S3,
  S9) that arose organically rather than being specifically engineered as
  adversarial tests.
- **V1.1 and V1.0 remain completely unchanged** -- this milestone reused
  the real committed types and functions without modification.
- **V1.0/V1.1 remain authoritative and unchanged.** V1.0 Safety Authority
  semantics are unchanged; V1.1's strict internal transport semantics are
  unchanged; exact internal UTF-16/native addressing remains valid and
  authoritative *internally*. What V1.3C's evidence questions is only
  whether the model must be the one to calculate that UTF-16 addressing --
  not whether PratiLekh's internal representation should change. Fuzzy
  matching, source repair, and approximate semantic relocation remain
  prohibited in any direction this evidence points toward.
- **Is a model-facing contract revision now justified?** Not as a production
  change yet -- but the evidence does justify formally *investigating* one.
  The direction is **not** "make Granite tolerate the existing full V1.2
  schema": it is a two-contract architecture, where the model-facing
  proposal representation and PratiLekh's internal safety representation
  are no longer required to be identical:
  `raw dictation -> model-facing Intelligence proposal -> deterministic
  source resolver -> strict internal native proposal -> V1.0 Safety
  Authority -> accepted/review/rejected disposition`. The model-facing
  contract would be optimized for reliable model generation (exact-source
  addressing, no UTF-16 arithmetic); the internal contract stays optimized
  for deterministic verification and execution exactly as V1.1/V1.0 already
  define it. The deterministic resolver is the bridge, not a relaxation of
  either side.
- **Is legal-domain evaluation justified next?** Not yet -- this milestone
  deliberately tested only protocol viability with synthetic, non-legal
  fixtures (plus one statute-shaped synthetic case for the protected-span
  mechanism, not a legal-quality test). Indian legal terminology, statutory
  correctness, and proper-noun handling under real dictation conditions
  remain untested.
- **Recommended next milestone:** investigate and formalize a simplified
  model-facing proposal contract based on exact textual addressing (the
  two-contract direction above), while retaining V1.1's existing strict
  internal transport and V1.0's existing safety boundaries unchanged. This
  is a design/investigation milestone, not a request to make `granite4:3b`
  pass the old, full V1.2 schema as currently defined.
