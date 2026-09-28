# Intelligence V1.6 — Production Addressing Resolver

## 1. Status and scope

V1.6 promotes the validated experimental V1.4/V1.4C resolver into production
code under `Sources/Fluid/Intelligence/Addressing/`, implementing the V1.5
frozen addressing contract with three **explicit clarifications/corrections**
(§3). It is deterministic, model-independent, provider-independent, and
**not wired into dictation**. It adds no wire JSON/schema/parser, changes no
`IntelligenceGenerationContract` text, calls no model, does not implement
insertion, and does not modify the V1.0 Safety Authority, the V1.1 transport
parser, or the V1.2 generation contract.

Components:

| File | Role |
|---|---|
| `ModelFacingEdit.swift` | Narrow model-facing type: `sourceText`, `replacementText`, optional 1-based `occurrence`, optional exact `leftContext`/`rightContext`. No id, no category, no range. |
| `IntelligenceAddressingResolver.swift` | Pure `resolve(edit, in: source)` → resolved UTF-16 `NSRange` + `IntelligenceAddressingBasis`, or a typed `IntelligenceAddressingRejection`. |
| `IntelligenceAddressingBridge.swift` | Resolves a batch against one immutable source and emits standard `IntelligenceProposal` values; per-item outcomes; does not apply anything. |

Tests: `Tests/IntelligenceAddressingResolverTests.swift`,
`Tests/IntelligenceAddressingBridgeTests.swift`, both run by
`scripts/test_intelligence_safety.sh`.

## 2. Production resolver semantics (exact)

*Candidates* = every UTF-16 start position where `sourceText` literally
occurs, **overlapping matches included**, in source order. *Occurrence valid*
= within `1...candidates.count`. *Context supplied* = `leftContext` or
`rightContext` non-empty (empty string ≡ absent). A candidate *matches* the
context iff every supplied side literally matches around it; `C` = matching
candidates.

1. empty `sourceText` → reject `emptySourceText`
2. no candidates → reject `noLiteralMatch`
3. context supplied and `C` empty → reject `contextMatchesNoCandidate`
   (unique or repeated source; any occurrence)
4. unique source: occurrence ≠ 1 → reject `occurrenceOutOfRange`; otherwise
   resolve (`uniqueSource`, or `uniqueSourceCorroborated` if occurrence/context
   was supplied)
5. repeated source, valid occurrence `o`:
   - no context → resolve `o` (`occurrence`)
   - `o ∉ C` → reject `occurrenceContradictsContext`
   - `|C| == 1` → resolve `o` (`occurrenceCorroboratedByContext`)
   - `|C| > 1` → resolve `o` (`occurrenceWithNonNarrowingContext`)
6. repeated source, invalid occurrence:
   - no context → reject `occurrenceOutOfRange`
   - `|C| == 1` → resolve that candidate (`contextFallbackForInvalidOccurrence`)
   - `|C| > 1` → reject `ambiguousCandidates`
7. repeated source, no occurrence:
   - no context → reject `ambiguousCandidates` (never "first match")
   - `|C| == 1` → resolve (`contextOnly`); `|C| > 1` → reject `ambiguousCandidates`

Matching is exact UTF-16 code-unit comparison: no case folding, no Unicode
normalization, no fuzzy/semantic relocation, no span shrinking. Rejections
carry only counts/ordinals, never transcript text.

## 3. V1.6 clarifications/corrections to the V1.5 freeze

The V1.5 document is left intact as the historical record; where it differs,
**this document governs the production implementation.**

1. **Overlapping literal matches are candidates (correction).** The
   experimental `findExactOccurrences` scanned without overlap, so `"aa"` in
   `"aaa"` counted as one occurrence and a bare reference silently resolved to
   position 0 — contradicting "never guess". Production enumerates every
   literal start position. `"aa"` in `"aaa"` now has candidates {0, 1}: a bare
   reference rejects `ambiguousCandidates(2)`; `occurrence` 1/2 select them;
   context can select them. (V1.5 §15 promoted `findExactOccurrences` "for
   direct promotion" — that promotion was *not* carried out as written.)
2. **Context semantics (refinement of table rows 4, 10, 12, 13).** Supplied
   context matching **zero** candidates is contradictory evidence and rejects,
   uniformly for unique and repeated sources and regardless of occurrence
   (V1.5 row 10 resolved on occurrence when context "failed to narrow", which
   folded zero-match together with multi-match). Context matching **exactly
   one** candidate is informative. Context matching **several** is
   non-narrowing: it cannot select, but it does not contradict a valid
   occurrence that lies within `C`.
   - **Decided (architect-confirmed):** when context matches several
     candidates and the valid occurrence names a candidate *outside* `C`,
     production rejects (`occurrenceContradictsContext`) rather than resolving
     on occurrence. The context set actively excludes that location, the same
     evidence shape as the one-match/different-location contradiction (row 12);
     explicit contradictory evidence is never ignored. V1.5 row 10 would have
     resolved.
   - Consequence for V1.4C: **A10 is corrected**, not preserved. The
     experimental A10 expected `resolvedOccurrenceContextUninformative` for a
     valid occurrence plus context matching nowhere; production rejects
     `contextMatchesNoCandidate`. A4's outcome is unchanged (reject); only its
     reason name is unified.
3. **Bridge metadata (unspecified in V1.5 §11).** IDs are `p<n>`, `n` = 1-based
   original position, assigned to every item (rejected items keep their
   positional id; later ids never shift). `claimedCategory = .other`.
   `expectedSourceText` is read from the real immutable source at the resolved
   range.

Also recorded: V1.5 §15's claim that experimental `detectOverlaps` "mirrors"
the Authority's intersection semantics was inaccurate (it does not treat two
zero-length insertions at one position as intersecting). It was not promoted;
`IntelligenceSafetyAuthority` remains the sole authority over proposal
overlap/conflict, protected spans and edit classification.

## 4. Batch behavior

Every edit resolves against the same original immutable source; resolution is a
pure function of `(edit, source)`. Original order is preserved. An addressing
failure is isolated to its own item and reported (`rejections`); it never
aborts the batch and never influences another item (tested: mixed batches equal
per-item solo results; reversing the batch yields identical per-item results;
replacement text never affects resolution). Nothing is applied — only the
Safety Authority produces resulting text, from the resolved proposals.

## 5. Observations from testing

- **Sub-grapheme targets.** For canonically-decomposed text (`e` + U+0301),
  the base `e` is a valid literal candidate. Neither the resolver nor the
  unmodified Authority enforces grapheme boundaries; the Authority classifies
  the edit on the scalar text. A scalar-level capitalization (`e`→`E`) is
  accepted (result: `E` + U+0301, a proper capital É); a lexical change
  (`e`→`a`) is rejected `unsupportedEditCategory`. Recorded as observed
  behavior; the architect decided to keep it unchanged — V1.6 does not
  introduce grapheme-boundary policy.
- **Resolved ≠ permitted, re-confirmed deterministically** end to end: lexical
  edits, whole-passage spans, statute-number changes and no-ops all resolve
  and are then rejected by the Authority; protected-span intersection yields
  `intersectsResolvedSpan` / review-only per span kind; overlapping resolved
  edits are both rejected by the Authority, not the bridge.

## 6. Still open / out of scope

_(Update: the wire schema and parser item below was built in V1.7 — see `V1_7_MODEL_FACING_WIRE_CONTRACT.md`.)_

Insertion (`anchorText`/`atStart`/`atEnd`, V1.5 §8 — the experimental
insertion path still uses the pre-V1.4C occurrence-then-context filter and is
not promoted). The model-facing wire JSON/schema and its strict parser
(V1.5 §16 shows the V1.1 parser ahead of the resolver, but that parser only
understands the internal `rangeStart`/`rangeLength` shape).
`IntelligenceGenerationContract` still instructs UTF-16 offsets. Model
selection, live invocation, dictation wiring, and the V1.5 §14 open risks
(mutually-consistent-but-wrong evidence, Granite Unicode fidelity, over-broad
span usability) are unchanged.
