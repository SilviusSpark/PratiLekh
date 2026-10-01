# Intelligence V1.18 — Model Protocol-Compliance Investigation

## 1. Status and scope

Investigation only. **No change to `ModelFacingGenerationContract`, `ModelFacingEditTransportParser`,
any addressing/composition/Safety Authority code, the V1.17 harness, or any dictation path.**
Nothing under `Sources/Fluid/` or `Evaluation/Intelligence/Harness/` changed. **No corrective
prompt experiment, schema change, or model tuning was performed** — every call in this
investigation used the existing, frozen `ModelFacingGenerationContract` verbatim.

**Question investigated:** why did `granite4:3b` omit the required `schemaVersion` field in
10/10 tool calls during V1.17's real-model smoke test
(`Evaluation/Intelligence/V1_17_CONTROLLED_LOCAL_MODEL_INTEGRATION_HARNESS.md` §4)?

**Method:** throwaway standalone Swift probes compiled against the real, unmodified
`ModelFacingGenerationContract.swift`/`LLMClient.swift` (reading their actual committed
behavior, never a reimplementation), plus direct `curl` calls to a locally-restarted
`ollama serve`. All probes, request/response bodies and logs were written under `/tmp`,
**never committed and not preserved in this repository** — this document and its
methodology description are sufficient to reproduce the investigation from the already-committed
V1.7/V1.17 sources without needing the original scratch files.

## 2. Evidence at each boundary

**(a) `ModelFacingGenerationContract` (read directly, unmodified):** declares
`"required": ["schemaVersion", "edits"]` at the top level of `parameters`, and
`"required": ["sourceText", "replacementText"]` on each edit item. Confirmed by dumping
`ModelFacingGenerationContract.toolDefinition` as a Swift literal in a probe — exactly as
committed.

**(b) What the V1.17 harness constructs:** `IntelligenceHarnessProvider.propose` builds
`messages: [system=instructions, user=normalizedText]`, `tools:
[ModelFacingGenerationContract.toolDefinition]` — reviewed directly against the committed
V1.17 source; no discrepancy from the contract.

**(c) What `LLMClient` serializes/sends — byte-for-byte evidence:** called the real,
unmodified `LLMClient.shared.buildChatCompletionsBody(config)` directly, inspected the
returned dictionary, serialized it with `JSONSerialization` exactly as
`LLMClient.buildRequest` does internally, then **re-parsed those exact bytes** to confirm
what a receiver would see. Result: `required: ["schemaVersion", "edits"]` survived every
step intact. `buildChatCompletionsBody` passes `config.tools` through with zero
transformation (`body["tools"] = config.tools`) — **`schemaVersion`'s requiredness survives
request serialization completely, with no PratiLekh-side stripping at any layer.**

**(d) Raw-curl reproduction, bypassing `LLMClient` entirely:** sent the exact
byte-identical serialized request body (from (c)) directly to `http://localhost:11434/v1/chat/completions`
via `curl`, never invoking any PratiLekh/`LLMClient` code for the response side. Result:
identical to the V1.17 harness's finding — the model engaged tool-calling and omitted
`schemaVersion`. **This rules out `LLMClient`'s response-parsing/streaming-reconstruction
code as a contributor**, since that code never ran in this reproduction at all.

**(e) Ollama's own rendering template (read directly from the local installation, no
inference run):** `ollama show --template granite4:3b` prints the exact Go template Ollama
uses to build this model's prompt. The tool-rendering logic is:
```
{{- range $_, $tool_body := .Tools }}
    {{- $tools_system_message = print $tools_system_message "\n" (json $tool_body) }}
{{- end }}
```
This re-serializes whatever Ollama holds for each tool generically via Go's `json` template
function — **the template itself contains no field-selection or stripping logic.**
`OLLAMA_DEBUG=1` logging was enabled during a real call and inspected; it logs
`prompt_len`/token counts but not the rendered prompt's literal text at this verbosity —
**the final rendered prompt was not captured byte-for-byte.** This is the one boundary not
directly observed as raw text in this investigation.

## 3. The `granite4:3b` finding — exact count

**12/12 `granite4:3b` calls omitted `schemaVersion`:** the 10 calls already recorded in
V1.17 (4 synthetic + 6 private real-dictation samples), plus 2 additional calls made during
this investigation (different short sample texts, via direct `curl`, bypassing `LLMClient`).
**All 12/12 otherwise engaged tool-calling correctly** — well-formed `edits` arrays with
correct `sourceText`/`replacementText` (and, in earlier V1.17 samples, correct
`occurrence`/`leftContext` usage). The omission is specific to `schemaVersion`; every other
required/optional field the model chose to use was well-formed.

## 4. Minimal cross-model control (no downloads, no tuning, no ranking)

Same exact request bytes from (c)/(d) above, only the `"model"` field changed, sent to the
two other already-installed, tool-capable local models (no model was downloaded for this
investigation):

- **`granite4:350m`** (same vendor family, same Ollama template as `granite4:3b`): one call
  **correctly included `"schemaVersion":1"`**. A second call, with different sample text,
  failed to engage tool-calling at all (returned free text instead) — a separate,
  independent reliability limitation of this much smaller model (inconsistent tool
  engagement), not evidence against the first result, and not a basis for ranking this
  model against `granite4:3b` for any other purpose.
- **`qwen2.5:1.5b`**: did not engage tool-calling at all under this framing (returned plain
  text) — consistent with the pre-existing V1.3B finding (0/15 tool engagement for this
  model on supplied-text-processing tasks). A different failure mode, uninformative about
  `schemaVersion` specifically.

**Why the `granite4:350m` result matters:** it is an existence proof. If the schema
(including `"required": ["schemaVersion","edits"]`) were stripped anywhere in PratiLekh's
request construction, `LLMClient`'s serialization, or Ollama's template rendering, **no
model could ever produce `schemaVersion` from this exact, unmodified pipeline** — yet one
did, from the identical rendered-template mechanism `granite4:3b` uses. This closes the gap
left by (e) empirically rather than by direct text capture.

## 5. Attribution

| Candidate | Verdict | Confidence / basis |
|---|---|---|
| PratiLekh request construction | **Exonerated** | High — direct literal inspection of the contract and harness construction |
| `LLMClient` serialization | **Exonerated** | High — byte-for-byte round-trip proof (§2c), and the omission reproduces identically via raw `curl` that never executes `LLMClient`'s code (§2d) |
| Ollama / OpenAI-compatible schema translation or tool handling | **Showed no evidence of stripping the required field, and is unlikely to be the cause** | High via the cross-model existence proof (§4) and the template's generic, non-selective serialization logic (§2e) — but this is indirect/structural evidence, not a literal byte-for-byte capture of the final rendered prompt, which was not obtained |
| **Model protocol adherence (`granite4:3b`, this exact runtime/framing) — best-supported failure boundary** | Best-supported, not proven beyond this evidence | High for *this model, this prompt framing, this runtime*: 12/12 omissions vs. the same-family smaller model's correct inclusion from the identical input and pipeline. **Not established:** *why* the model does this (e.g. whether it treats `schemaVersion` as non-content protocol metadata it does not feel obliged to echo) — determining that would require prompt-variation experiments, explicitly out of scope for this investigation |
| Cannot yet be distinguished | One residual gap | The literal rendered-prompt text `granite4:3b` actually received for an omitting call was not directly captured; its content was inferred from the template's generic logic plus the cross-model existence proof, not observed byte-for-byte |

## 6. What did not happen

Per explicit instruction, and confirmed by `git status`/`git diff` before this document was
written: **no change was made to the model-facing contract, the transport parser, any
addressing/composition/Safety Authority code, the V1.17 harness's behavior, or any
dictation-path code.** No prompt wording was changed and re-tested against the model; no
threshold or schema was adjusted; no model was tuned, fine-tuned, or re-prompted
iteratively. Every request sent during this investigation used the exact, frozen,
already-committed `ModelFacingGenerationContract` text. The one "next action" below is a
recommendation for a future, separately-authorized milestone — it was not attempted here.

## 7. Diagnostic material

All probes, generated request/response JSON bodies, and Ollama debug logs used for this
investigation were written under `/tmp` during the investigation session and were never
copied into this repository. They are not preserved — this document's §2–§4 record the
methodology and exact results in enough detail to reproduce the investigation from the
already-committed V1.7 (`ModelFacingGenerationContract`) and V1.17 (harness) sources,
without needing the original scratch files.

## 8. Smallest evidence-supported next action (recommendation only — not executed)

If a correction is ever authorized, the evidence points to a narrow, single-variable
experiment: whether more explicit/prominent instruction-level emphasis on `schemaVersion`
(an instructions-text change, not a schema shape change) changes `granite4:3b`'s behavior,
measured against the existing V1.17 harness and this same model. This is a recommendation
for a future, separately-authorized milestone — **not attempted, and not authorized by this
document.**

## 9. Not authorized by this milestone

Any prompt/schema/parser/policy change in response to this finding, any further live-model
experiment beyond the 2 additional `granite4:3b` calls and the 2 cross-model control calls
recorded above, any model comparison/ranking/selection, any dictation wiring, and resuming
the closed recognition-tuning branch — none of these were done and none are authorized by
this document.
