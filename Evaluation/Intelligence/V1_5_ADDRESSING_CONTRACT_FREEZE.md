# Intelligence V1.5 — Addressing Contract Freeze

## 1. Status and scope

This document **freezes the V1 model-facing addressing semantics** —
consolidating the experimental investigation carried out across V1.3C
(model capability), V1.4 (contract search), V1.4B (candidate selection),
and V1.4C (adversarial validation). It is a **design/architecture record**,
not an implementation. No production code changed as part of this
milestone. `granite4:3b` remains a research/protocol candidate, not a
selected production model — this document defines a **model-independent**
contract deliberately, so any future tool-capable local model can be
evaluated against the same frozen semantics.

This freezes the *addressing layer only*: how a model-facing proposal's
textual reference is converted into an exact internal coordinate. It does
**not** freeze, replace, or modify the committed V1.0 Safety Authority, the
committed V1.1 transport parser, or the committed V1.2 generation contract
— those remain exactly as committed and are the authoritative production
boundary today. Nothing in this document is wired into the dictation
pipeline.

## 2. Evidence lineage

- **V1.3A/V1.3B/V1.3C** established that a real local model (`granite4:3b`)
  can reliably engage tool-calling for supplied-text-processing tasks
  (25/25 on Stage 1), and that a simplified, UTF-16-free proposal
  representation is viable in principle (Stage 2, zero unsafe accepted
  edits, zero source-resolution defects against the real, unmodified V1.0
  Safety Authority).
- **V1.4** searched the representation space (candidates A–D, multi-edit)
  and established that Candidate A (`sourceText`/`replacementText` alone)
  cannot express repeated-text disambiguation, that deterministic Swift
  code can derive exact UTF-16 coordinates (including for Odia and
  non-BMP emoji) without the model ever computing them, and that anchor-
  based insertion is viable.
- **V1.4B** compared occurrence (Candidate B) against exact context
  (Candidate C) for genuine short-fragment disambiguation: **B 4/4, C
  0/4, B+C 3/4** (one regression from an imprecise volunteered context
  field). Zero unsafe accepted edits; zero genuine document-level
  mistargets across all successfully-resolved proposals.
- **V1.4C** adversarially validated a *precise* fallback policy (superseding
  V1.4B's broader "P3" description), ran 20 deterministic adversarial
  cases (A1–A20, all passing), and 40 fresh live-model trials confirming
  correct 1-based occurrence addressing at every tested repetition level
  (2, 3, 5, 10) including genuine (non-workaround) 10-way short-fragment
  counting (10/10). A dedicated adversarial live round (Part E) produced
  the single most important confirmatory case: a proposal that resolved
  correctly and unambiguously, but whose effect would have been
  destructive, was correctly rejected by the unmodified Safety Authority
  — proof the resolver/Safety-Authority separation holds under real
  adversarial model output, not just hand-constructed fixtures.

Across all four milestones: **0 resolver safety failures, 0 unsafe
accepted edits, 0 genuine document-level mistargets.**

## 3. Normative model-facing contract (frozen)

A model-facing proposal conceptually carries:

```
sourceText: string           (required)
replacementText: string      (required)
occurrence?: integer          (optional, 1-based)
leftContext?: string          (optional, exact literal)
rightContext?: string         (optional, exact literal)
```

This is the **model-facing** contract. It is deliberately distinct from
the committed V1.1 **internal** contract (`IntelligenceProposal`: `id`,
`range: NSRange`, `expectedSourceText`, `replacementText`,
`claimedCategory`). The two are bridged by deterministic resolution — see
§11. The model-facing contract has no `id`, no `claimedCategory`, and no
UTF-16 range; it exists to be reliably *generated*, not to be *trusted*.

## 4. Field semantics

- **`sourceText`** — a literal substring of the immutable source for this
  Intelligence pass. Exact only: no fuzzy, semantic, case-folded, or
  normalized matching; no typo repair; no inferred relocation. Zero
  literal matches → reject.
- **`replacementText`** — the literal text that should replace
  `sourceText` if the proposal is ultimately accepted. Carries no
  addressing meaning; irrelevant to resolution.
- **`occurrence`** — **1-based**. First occurrence = 1, second = 2, third
  = 3. `0` is invalid, always. The model-facing instruction must state
  this explicitly (V1.4C: an instruction naming the exact expected value
  per case eliminated a previously-observed 0-based slip in 5/5 live
  multi-edit trials; a purely abstract convention statement alone was not
  separately isolated for the array shape and remains an open question —
  see §14). Deterministic code never auto-corrects `0` to `1` or guesses
  the convention.
- **`leftContext`/`rightContext`** — optional, exact literal text
  immediately adjacent to the intended `sourceText` occurrence in the
  source. Never fuzzy. An **absent** field and an **explicitly empty
  string** are not equivalent: an empty string is treated identically to
  absence (never a universal/wildcard match) — this was deterministically
  verified (V1.4C, A18).

## 5. Smallest correction-bearing source-span instruction (model-facing only)

The model-facing protocol instructs the model to select **the smallest
exact literal `sourceText` span necessary to express the proposed
correction** — e.g., a single word for a capitalization fix, not the
whole sentence; the punctuation mark and its immediate neighbor for a
punctuation fix, not a larger span, unless a larger span is genuinely
required to express the edit.

**This is a prompt/instruction-level guideline only.** It is explicitly
**not** enforced, inferred, or heuristically corrected by the deterministic
resolver:

- The resolver does **not** shrink a model-selected span.
- The resolver does **not** guess a "more minimal" intended edit.
- If the model supplies a large-but-literal, uniquely-resolvable span
  (including, in the degenerate case, an entire passage), the resolver
  resolves it exactly as the contract defines — correctly, per its own
  semantics — and the resulting edit's scope/category is then evaluated
  by the unmodified Safety Authority.

V1.4C's Part E `E5` case is the concrete proof this separation is
necessary and sufficient: a real live-model proposal selected an entire
two-sentence passage as `sourceText` with a valid, unambiguous
`occurrence`; the resolver correctly resolved it (this was *correct*
resolver behavior, not a defect); the Safety Authority correctly rejected
it (`.unsupportedEditCategory`) because replacing the whole passage with
two words is not a punctuation/capitalization/whitespace-only edit. No
resolver-level span-shrinking would have been necessary or appropriate —
the existing Safety Authority boundary already contains this risk.

## 6. Normative decision table

Source cardinality is determined solely by exact occurrences of
`sourceText` in the immutable source (never influenced by
`occurrence`/context values themselves).

| # | Source | Occurrence | Context | Resolve/Reject | Reason | Reaches Safety Authority? |
|---|---|---|---|---|---|---|
| 1 | unique | absent | absent | **Resolve** | bare unique match | yes |
| 2 | unique | valid (=1) or matches | agrees or absent | **Resolve** | explicit evidence agrees with the unique match | yes |
| 3 | unique | invalid (≠1) | — | **Reject** | explicit occurrence contradicts the unique match — never silently ignored | no |
| 4 | unique | — | contradicts (doesn't match the unique location) | **Reject** | explicit context contradicts the unique match — never silently ignored | no |
| 5 | repeated | valid, only discriminator | absent | **Resolve** | occurrence alone identifies exactly one location | yes |
| 6 | repeated | invalid, only discriminator | absent | **Reject** | out-of-range/invalid ordinal, no other evidence | no |
| 7 | repeated | absent | uniquely resolves | **Resolve** | context-only fallback | yes |
| 8 | repeated | absent | fails to narrow to one | **Reject** | ambiguous/insufficient context, no occurrence to fall back on | no |
| 9 | repeated | valid | independently agrees (same location) | **Resolve** | corroboration | yes |
| 10 | repeated | valid | independently fails to narrow (not a *different* location — merely uninformative) | **Resolve** | occurrence alone suffices; absent corroboration is not contradiction | yes |
| 11 | repeated | invalid | independently and uniquely resolves | **Resolve** | the principal constrained-fallback case | yes |
| 12 | repeated | valid | independently resolves to a **different** location | **Reject** | genuine contradiction — no precedence, never guess | no |
| 13 | repeated | invalid | invalid/fails too | **Reject** | both discriminators unusable | no |
| 14 | any | — | — | **Reject** | zero literal matches of `sourceText` at all (hallucinated/stale reference) | no |

This table is the exact, complete decision procedure validated by V1.4C's
20 deterministic adversarial tests (A1–A20) and exercised live against
real (imperfect) model output in V1.4C Part E, with zero resolver safety
failures.

**Row 3/4 is the refinement V1.4C introduced over V1.4B's broader "P3"
description**: V1.4B's implementation would, in some cases, silently fall
through to a context-only or bare-match resolution when occurrence was
supplied but wrong, because "context absent" and "context resolves via
bare match" were not distinguished. V1.4C's decision table makes this
explicit and closes that gap — explicitly supplied evidence, right or
wrong, is always significant. **This frozen contract adopts V1.4C's
semantics, not V1.4B's.**

## 7. Immutable-source semantics (Rule 1, Rule 12)

Every proposal in a single Intelligence-pass response resolves against
the **same, exact, unmodified immutable source**. Never sequentially
re-resolve a later proposal against text already mutated by an earlier
one. Overlap, conflict, and application ordering are evaluated only
**after** every proposal has been independently resolved against the
original immutable source — never interleaved with resolution itself.
Validated deterministically (V1.4, V1.4B, V1.4C: reversing proposal-array
order produces identical resolved ranges for every item).

## 8. Insertion semantics (Rule 11, unchanged from V1.4)

Anchor-based insertion (`anchorText` + `anchorSide: before/after`) and
absolute boundary insertion (`atStart`/`atEnd`) are preserved exactly as
experimentally validated in V1.4 — not redesigned in this milestone. A
repeated anchor requires the same occurrence/context disambiguation
discipline as any other repeated `sourceText`; an anchor with zero
literal matches fails closed.

## 9. Multi-edit semantics (Rule 12)

Each item in a multi-edit response carries its own independent addressing
evidence (`sourceText`, optional `occurrence`, optional context) and
resolves independently against the same immutable source (§7). V1.4C
confirmed this composes correctly with real model output: 5/5 live
multi-edit trials produced two independently-correct occurrence-resolved
items. Overlap/conflict detection across items happens only after all
items have resolved (§7).

## 10. Unicode semantics (Rule 13)

Deterministic resolution operates on exact Swift `String`/`NSString`
semantics throughout, which correctly derives UTF-16 coordinates for
Odia/Indic text and non-BMP (surrogate-pair) content without the model
ever being asked to compute an offset — validated repeatedly (V1.4, V1.4C
A20). **Known Granite model/protocol Unicode-fidelity failures are not
addressed by this contract and must not be hidden or normalized to make
them resolve**: V1.4B and V1.4C both observed real live-model
hallucination of Odia text into unrelated scripts, and emoji-adjacent
corruption (a spurious literal newline character preceding the glyph).
Both failure classes failed closed in every observed instance
(`zeroOccurrences`, since the model's own claimed `sourceText` did not
literally match the real source) — this is deliberately not "fixed" by
this contract; it is a known, recorded, fail-closed limitation of the
current research model, not the addressing architecture.

## 11. Conversion into the strict internal proposal (bridge, not a merge)

Once a model-facing reference resolves to an exact `NSRange` (§6), and
only then, deterministic code constructs a **committed, unmodified**
`IntelligenceProposal` (`id`, `range`, `expectedSourceText` — taken from
the **real immutable source** at the resolved range, never from the
model's own possibly-imprecise echo — `replacementText`,
`claimedCategory`). This native proposal is indistinguishable, from V1.0's
perspective, from any other `IntelligenceProposal` — the Safety Authority
requires no awareness that a model-facing addressing layer exists at all.

## 12. Safety Authority boundary (Rule 14)

**Resolver: where does the proposed edit apply, if anywhere, given only
the literal evidence supplied?**
**Safety Authority: may that resolved edit actually proceed?**

These are never combined. A correctly, unambiguously resolved proposal
may still be lexically unsupported, protected-span-intersecting, too
broad, or otherwise impermissible — deciding that is exclusively the
unmodified V1.0 `IntelligenceSafetyAuthority`'s responsibility, exercised
in this investigation against real model output without modification, and
without a single unsafe acceptance.

## 13. Failure taxonomy (kept separate, per V1.4B/V1.4C discipline)

- **Resolver safety failure** — deterministic code resolves contrary to
  its own contract semantics. **Observed count across V1.4–V1.4C: 0.**
- **Model addressing failure** — the model supplies incorrect/imprecise
  addressing evidence relative to ground truth (e.g. whole-passage
  `sourceText` selection, an imprecise context value, Unicode corruption).
  Observed repeatedly; always safely contained.
- **Safe rejection** — incorrect/incomplete/contradictory model output is
  correctly rejected by the resolver or the Safety Authority. The
  designed, expected outcome for model addressing failures.
- **Contract usability failure** — the contract or its prompting causes
  excessive rejection or awkward protocol behavior despite remaining
  safe. Observed: offering `occurrence`+context together, with permissive
  "also supply context" instructions, correlated with whole-passage
  `sourceText` selection and a higher contradiction-rejection rate (V1.4C
  Part E) — safe, but not yet efficient.

## 14. Known limitations / remaining risks (not solved by this freeze)

1. **Mutually-consistent-but-wrong addressing evidence cannot be detected
   by resolver consistency alone.** If a model's `occurrence` and context
   agree with each other but both misidentify the intended occurrence
   relative to a human's actual intent, the resolver will resolve
   consistently and correctly *per its own contract* — this is
   fundamentally a model/evaluation-layer risk, proven real and
   undetectable in principle by deterministic test A13, not yet observed
   live, and not solvable by addressing-layer changes.
2. **Model Unicode fidelity remains a known, unresolved, fail-closed
   limitation** — not a resolver defect, not fixed here.
3. **Over-broad literal span selection is a usability concern, not a
   safety one** — contained by the Safety Authority today (§5, §12), but
   makes the contract less efficient in practice than minimal-diff
   addressing would be, and was observed to correlate specifically with
   offering multiple optional discriminator fields together under
   permissive prompting (V1.4C).
4. **The 1-based convention fix (§4) was validated under a directive,
   per-case instruction style**; whether a purely abstract convention
   statement (without naming the expected value per case) is independently
   sufficient, especially in the multi-edit/array shape, was not isolated
   and remains open.

## 15. Experimental-to-production promotion assessment

| Component | File | Assessment |
|---|---|---|
| Exact-substring occurrence enumeration (`findExactOccurrences`) | `V1_4_ModelFacingResolver.swift` | **Suitable for direct promotion** (after review) — small, pure, exhaustively tested (V1.4/V1.4B/V1.4C), no external dependencies, matches the exact-match discipline already established by the committed V1.3A resolver pattern. |
| `resolveReference` (occurrence/context disambiguation core) | `V1_4_ModelFacingResolver.swift` | **Suitable after refactor** — logic is sound and validated, but the `ModelFacingReference` superset-of-all-candidates type was deliberately an experimental convenience (letting one function serve multiple candidate schemas at once); production would want a narrower, contract-specific type. |
| Anchor-based insertion resolution | `V1_4_ModelFacingResolver.swift` | **Suitable after refactor** — same reasoning as above. |
| Overlap/conflict detection (`detectOverlaps`) | `V1_4_ModelFacingResolver.swift` | **Suitable for direct promotion** (after review) — small, pure, already mirrors the committed `IntelligenceSafetyAuthority`'s own intersection semantics deliberately. |
| Precise P3 decision procedure (`resolveP3Precise`) | `V1_4C_P3Adversarial.swift` | **Suitable after refactor** — this *is* the recommended frozen decision table (§6) in code form; production adoption should promote this logic (not V1.4B's broader, superseded `V1_4B_PolicyExperiments.swift` policies), renamed/reshaped to match whatever concrete model-facing type production ultimately adopts. |
| V1.4B's P1/P2/P3 broad policies | `V1_4B_PolicyExperiments.swift` | **Experimental/reference only, should not be promoted** — superseded by V1.4C's precise table; P2 specifically was shown to carry an unrejected silent-mistargeting risk and must never be promoted. |
| UTF-16 range derivation via `NSString` | (implicit throughout, no separate module) | **Already production-proven** — this is exactly the existing `NSRange`/`NSString` convention already used throughout the committed codebase (e.g. `AppliedNormalizationChange.range`); nothing new to promote, only to reuse. |
| Experimental proposal types (`ModelFacingReference`, `ModelFacingProposal`) | `V1_4_ModelFacingResolver.swift` | **Experimental/reference only** — intentionally a broad superset type for comparing candidates; production needs a single, narrower, contract-specific type once the model-facing schema itself is finalized (a separate future milestone, not this one). |
| Test fixtures / adversarial matrix (A1–A20, etc.) | `V14ResolverTests.swift`, `V14BResolverTests.swift`, `V14CResolverTests.swift` | **Suitable as a starting regression corpus after promotion** — the adversarial cases (contradiction, ambiguity, Unicode, insertion, multi-edit) are exactly the kind of coverage a production resolver's test suite should retain; would need adapting to whatever concrete production type is adopted. |
| Live-model harness / experiment scripts | (Python, scratchpad only, not repository-tracked) | **Not for promotion** — these were throwaway research drivers, not reusable infrastructure; the *evidence* they produced is preserved in the findings documents, not the scripts themselves. |

**No production code change is recommended or made in this milestone.**
The above is guidance for a future promotion milestone, not an action
taken now.

## 16. Production-foundation recommendation

```
immutable ASR transcription
        |
local Intelligence model            (provider/model-independent; NOT frozen to granite4:3b)
        |
model-facing textual proposal contract    (S3-S6 above; NOT the same shape as the internal contract)
        |
strict parser / structural validation      (committed V1.1, unmodified)
        |
deterministic textual source resolver      (promotion candidate per S15, NOT yet built in Sources/)
        |
strict internal exact proposal             (committed V1.0 IntelligenceProposal, unmodified)
        |
existing V1.0 Safety Authority              (committed, unmodified, authoritative)
        |
accepted / review / rejected
        |
only then may accepted output affect transcription  (not yet implemented anywhere)
```

The model-facing contract and the strict internal proposal are, and
remain, **intentionally different contracts**, bridged only by the
deterministic resolver — never merged, never made interchangeable.

## 17. Explicit non-goals of this milestone and this contract

- Does **not** select `granite4:3b`, or any model, as the production
  Intelligence provider.
- Does **not** wire any model into the transcription pipeline.
- Does **not** modify, weaken, or reinterpret V1.0, V1.1, or V1.2.
- Does **not** implement the resolver in `Sources/Fluid/Intelligence/`.
- Does **not** solve Unicode fidelity, over-broad-span efficiency, or the
  mutually-consistent-wrong-evidence risk — all three are recorded as
  open limitations, not resolved.
- Does **not** authorize legal-domain quality evaluation, recognition
  repair, audio-aware Intelligence, or any further live-model
  experimentation as part of this milestone.
