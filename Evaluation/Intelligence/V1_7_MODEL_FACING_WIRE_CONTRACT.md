# Intelligence V1.7 — Model-Facing Wire Contract & Strict Parser

## 1. Status and scope

V1.7 builds the production boundary in front of the V1.6 addressing layer:

```
provider raw arguments
  -> ModelFacingResponseAdapter     (tool-call policy)
  -> ModelFacingEditTransportParser (strict wire parse)   -> [ModelFacingEdit]
  -> IntelligenceAddressingBridge   (V1.6; resolve vs. immutable source)
  -> [IntelligenceProposal]
  -> IntelligenceSafetyAuthority    (unmodified; sole semantic authority)
```

It is deterministic, model-independent and **not wired into dictation**. No
model is invoked. Insertion, UI, ASR changes, fuzzy matching, Safety Authority
changes and V1.6 resolver changes are out of scope; none were needed (no V1.6
defect was found).

**This supersedes the V1.5 §16 pipeline diagram**, which placed the V1.1
transport parser ahead of the resolver. That parser only understands the
internal `rangeStart`/`rangeLength` contract and cannot parse the model-facing
shape; the model-facing counterpart is `ModelFacingEditTransportParser`.

| File | Role |
|---|---|
| `Transport/ModelFacingEditTransportParser.swift` | Strict wire parser, typed `ModelFacingEditParseFailure`, `ModelFacingEditTransportLimits`, `ParsedModelFacingEditBatch` |
| `Generation/ModelFacingGenerationContract.swift` | Tool name, tool schema, instructions |
| `Generation/ModelFacingResponseAdapter.swift` | `extractEdits` (policy + parse) and `resolveEdits` (… + V1.6 bridge); does **not** call the Safety Authority |

Tests (all run by `scripts/test_intelligence_safety.sh`):
`ModelFacingEditTransportParserTests`, `ModelFacingGenerationContractTests`,
`ModelFacingResponseAdapterTests`.

## 1a. Contract identity: two distinct contracts

| | **V1 model-facing contract** (this milestone) | **Legacy internal / UTF-16 contract** (V1.1/V1.2) |
|---|---|---|
| Tool | `propose_literal_transcript_edits` | `propose_transcript_edits` |
| Root key | `edits` | `proposals` |
| Addressing | literal `sourceText` + optional 1-based `occurrence` / exact context | model-computed UTF-16 `rangeStart`/`rangeLength` + `expectedSourceText` |
| Model supplies id / category | never | yes (`id`, `claimedCategory`) |
| Parser | `ModelFacingEditTransportParser` | `IntelligenceProposalTransportParser` |
| Status | the V1 delivery contract going forward | retained unmodified for compatibility and its own tests |

The legacy contract's `IntelligenceProposal` remains the strict *internal*
type that the V1.6 bridge emits; it is no longer intended as the shape a model
is asked to produce.

**Scope of this schema.** It is the **V1 Intelligence capability contract**:
correction-oriented, surface edits (punctuation/capitalization/whitespace)
against an immutable source. It is deliberately model- and provider-independent
and is **not** a permanent definition of all future Intelligence capabilities
(recognition repair, dictation interpretation, audio-aware evidence, ...).
Those would be separate contracts with their own evidence and review; no
speculative richer-intent abstraction is introduced here, and `ModelFacingEdit`
should not be stretched to carry one.

## 2. Wire contract

```
{ "schemaVersion": 1,
  "edits": [ { "sourceText": "...", "replacementText": "...",
               "occurrence": 2, "leftContext": "...", "rightContext": "..." } ] }
```
Required per edit: `sourceText`, `replacementText`. Optional: `occurrence`
(integer), `leftContext`, `rightContext` (strings). Root key is `edits`, not
`proposals`; tool name is `propose_literal_transcript_edits` (distinct from
V1.2's `propose_transcript_edits`), so the two contracts cannot be confused.
A V1.1-shaped payload fails here with `unknownField("proposals")`.

## 3. Parser semantics

Same discipline as V1.1, using the same unmodified `RawJSONObjectKeyScanner`:

- whole-response, all-or-nothing structural parsing (one bad edit fails the batch);
- duplicate-key rejection (root and per edit) and unknown-field rejection
  (including escaped spellings of known keys, and any model-supplied `id`,
  offsets or category);
- no type coercion: string fields must be JSON strings — **`null` is rejected**
  for optional fields too (instructions say to omit, not null); `occurrence` and
  `schemaVersion` must match `-?(0|[1-9][0-9]*)` in ASCII digits and fit an
  `Int` (rejects `1.0`, `1.5`, `2e0`, `"2"`, `01`, `+1`, non-ASCII digits,
  overflow);
- bounds (own constants, independent of V1.1's): payload 1,000,000 bytes; 500
  edits; 10,000 UTF-16 units per text field; 200,000 aggregate;
- text preserved exactly: no trimming, no Unicode normalization, no repair;
  lone surrogate escapes, invalid escapes and raw control characters fail
  closed;
- failures name fields only, never transcript text.

### `occurrence: 0` — decided ownership boundary

**The wire parser owns lexical integer-ness only; addressing owns the value.**
`0`, negatives and out-of-range ordinals parse successfully and are judged by
`IntelligenceAddressingResolver` (`occurrenceOutOfRange`, or the frozen
fallback where independently unique context rescues an invalid occurrence).
Rejecting `0` in the parser would (a) duplicate validation, (b) abort the whole
batch for one item's bad ordinal, and (c) make the frozen "invalid occurrence +
uniquely matching context resolves" rule unreachable. Only values that are not
representable as an `Int` are rejected structurally. Likewise an empty
`sourceText` parses and is rejected per edit (`emptySourceText`); an empty
context string parses and is treated by the resolver as not supplied. The
schema therefore declares no `"minimum": 1`; the 1-based rule lives in the
instructions and the schema descriptions.

## 4. Generation contract

The schema mirrors the parser exactly (tested by deriving payloads from the
schema and feeding them to the real parser: required/optional fields, declared
types, `maxItems` = the enforced constant, no undeclared fields). Instructions
state: literal source text only (copied exactly, never paraphrased or
normalized); smallest correction-bearing span (prompt-level only — nothing
downstream shrinks a span); `occurrence` counted from 1 (first = 1, second = 2,
third = 3, never 0), needed only for repeated text, omitted for unique text;
context is optional literal extra evidence; omit optional fields, never send
null/empty; no UTF-16 offsets, ids or categories (extra fields reject the
response). V1 surface scope, protected-content warnings and zero-edit
preference are retained.

## 5. Compatibility decisions

The V1.2 `IntelligenceGenerationContract`, `IntelligenceProviderResponseAdapter`
and V1.1 `IntelligenceProposalTransportParser` are **unmodified and retained**:
the old adapter/contract are used by their own tests and by
`Tests/FluidDictationIntegrationTests/LLMClientRequestBodyTests.swift`, so
removal would have been an accidental migration. `IntelligenceProviderResponse`
(raw arguments) is reused unchanged, so the `LLMClient` bridge covers both
contracts. `ModelFacingResponseAdapter` deliberately mirrors the V1.2
tool-call policy rather than refactoring the V1.2 adapter; both suites assert
the same response-shape cases. Which contract a future live milestone
delivers to a model is a later decision; the old UTF-16 contract still asks the
model for offsets.

## 6. Open / not built

Insertion; live-model use and dictation wiring; empirical evidence on whether
models emit `null` optionals despite the instructions (strict rejection
currently fails the whole batch — revisit only with live evidence); the V1.5
§14 risks (consistent-but-wrong evidence, model Unicode fidelity, over-broad
spans under multi-discriminator prompting) are unchanged.
