# Intelligence V1.8 — Deterministic Composition Boundary

## 1. Status and scope

V1.8 adds one model/provider-independent, deterministic entry point that
composes the already-committed V1 chain:

```
IntelligenceProviderResponse + immutable source (+ caller's protected spans)
  -> ModelFacingResponseAdapter.extractEdits     (V1.7: tool-call policy + strict parse)
  -> IntelligenceAddressingBridge.bridge         (V1.6: per-edit addressing isolation)
  -> IntelligenceSafetyAuthority.validate        (unmodified; one batch call)
  -> IntelligenceCompositionResult               (structured; no text)
```

`Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift`.
It contains **no policy of its own** — every decision is made by one of those
components (proved by a parity test against calling them by hand). It knows
nothing about Granite, Ollama, prompts, providers or runtimes; it calls no
model, mutates no transcription, is not wired into dictation, and **applies no
edit and returns no resulting text**. Out of scope and unbuilt: insertion,
dictation wiring, live models, UI, new safety policy, legacy-contract removal.

The correction-oriented model-facing contract remains a versioned **V1
capability subset**. The result carries the wire `schemaVersion`; no
speculative richer-intent abstraction (KEEP/IGNORE/FORMAT/…) was added.

## 2. API

```swift
IntelligenceEditComposition.evaluate(
    response: IntelligenceProviderResponse,
    source: String,
    protectedSpans: [ProtectedSpan] = []
) -> Result<IntelligenceCompositionResult, ModelFacingAdapterFailure>
```

Narrowest type decision: existing types are reused rather than wrapped. The
whole-response failure type is `ModelFacingAdapterFailure` (already exactly the
transport/batch domain; exposed as `IntelligenceEditComposition.Failure`). The
only new result types are `IntelligenceCompositionResult` and
`IntelligenceComposedEdit`, needed because no existing type can hold an edit's
addressing outcome *and* its Authority disposition together. Existing
`ProposalDisposition`, `IntelligenceAddressingRejection`,
`IntelligenceAddressingBasis`, `IntelligenceProposal` and `ModelFacingEdit` are
embedded unchanged.

## 3. Result semantics — three distinct domains, never flattened

| Domain | Where it appears | Meaning |
|---|---|---|
| Transport / batch failure | `.failure(ModelFacingAdapterFailure)` | Response shape or wire payload rejected (all-or-nothing). Nothing was addressed or evaluated; no partial result exists. |
| Addressing rejection | `IntelligenceComposedEdit.stage == .addressingRejected(reason)` | The edit could not be located exactly once in the source. Never became a proposal; never reached the Authority. |
| Safety Authority disposition | `stage == .evaluated(proposal:basis:disposition:)` | The edit resolved to a strict proposal and the unmodified Authority returned `.autonomouslyAccepted`, `.reviewOnly` or `.rejected`. **Resolution is not permission.** |

`IntelligenceCompositionResult { schemaVersion, edits }`: one
`IntelligenceComposedEdit { index, id, edit, stage }` per model edit, **in
original order**, ids `p<index+1>` assigned to rejected and evaluated edits
alike (identity never depends on another edit's outcome). Convenience
partitions — `accepted`, `reviewOnly`, `rejectedBySafetyAuthority`,
`addressingRejected` — are exhaustive and disjoint (tested). A zero-edit
response is a valid success with an empty `edits`.

**No text is returned or applied.** The result's only stored properties are
`schemaVersion` and `edits` (asserted structurally via reflection, plus a check
that the Authority's would-be resulting text appears nowhere in it). The
Authority's own applied-text output (`resultingText`) is computed internally by
its existing API and deliberately discarded. A later application milestone must
consume `accepted` explicitly; nothing here converts a rejected or review-only
proposal into text, and `reviewOnly` is never reported as accepted.

## 4. Decision: Safety Authority is invoked once over the whole batch

Not per proposal. Overlap/conflict rejection is inherently pairwise across the
batch, so per-proposal invocation would silently defeat it: two individually
safe, overlapping edits would each be accepted. Tested: each alone is accepted;
together both are rejected `overlapsAnotherProposal`, in either order.
Addressing-rejected edits are excluded from the batch (no range → cannot
overlap or conflict), and the Authority's one-outcome-per-input, input-order
results are attributed back to edits by position (tested for parity with
calling the components directly). If that invariant were ever violated, the
composition fails closed to `.rejected(.invalidRange)` — the same fallback the
Authority uses for its own unreachable case — never to acceptance.

## 5. Caller responsibilities

The caller supplies the immutable `source` and the Authority's `protectedSpans`
(the composition never derives spans; spans change only dispositions, never
addressing — tested). Mapping `NormalizationOutcome` provenance to
`ProtectedSpan` values, and deciding what to do with `accepted`/`reviewOnly`,
are later milestones.

## 5a. Coupling to the V1 capability shape (kept narrow)

The composition is coupled to the current correction-oriented V1 capability
shape at exactly one point: the `ModelFacingResponseAdapter.extractEdits` call
that turns a response into `[ModelFacingEdit]`. Everything after it consumes
resolved, strict `IntelligenceProposal` values and the unmodified Authority, and
the result types carry no model, provider, prompt or runtime detail. A future,
different capability contract would add its own extraction stage in front of
the same addressing/Authority stages rather than reshape this boundary; no
richer-intent abstraction is introduced now.

## 6. Observations and open items

- Authority rejection reasons `invalidRange`, `rangeConversionFailed` and
  `sourceTextMismatch` are unreachable through this chain (the bridge derives
  every range and expected text from the real source); the Authority's own
  suite covers them.
- Still open, unchanged: applying accepted edits; review-only handling/UI;
  protected-span derivation from normalization provenance; insertion; live-model
  evaluation against the V1 contract (including `null` optionals, over-broad
  spans and occurrence accuracy); the V1.5 §14 risks; which delivery contract
  (V1 model-facing vs legacy UTF-16) a live milestone uses.
