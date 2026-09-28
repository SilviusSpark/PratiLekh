# Intelligence V1.11 — Protected-Span Derivation

## 1. Status and scope

V1.11 derives `ProtectedSpan` values in the exact UTF-16 coordinate space of
`NormalizationOutcome.normalized` from the verified V1.10 provenance:
`Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift`. It is
deterministic and model/provider-independent — no search, text relocation or
inferred attribution — and changes neither the Safety Authority nor V1.8
composition. It is **not wired into dictation** and applies nothing.

Standalone runner: `scripts/test_protected_span_derivation.sh` (it needs both the
LegalLanguage and Intelligence source sets, so it has its own script; whitelisted
in `.gitignore`).

## 2. Derivation API

```swift
ProtectedSpanDerivation.derive(from: NormalizationOutcome)
    -> Result<NormalizationProtectedSpans, ProtectedSpanDerivationFailure>
```
- `NormalizationProtectedSpans { normalizedText, entries }`; `entries[i]` =
  `{ span: ProtectedSpan, pass, step, sourceRange }` (origin fields are
  diagnostics only); `.spans` yields `[ProtectedSpan]`. `normalizedText` is the
  `source` to hand to composition, so spans and source travel together.
- Ordering is deterministic: final location, length, pass order, step. Spans are
  never merged, deduplicated or trimmed.
- Reuses `NormalizationReplay` as the source of truth: derivation first replays
  (and thereby verifies) the provenance.

## 3. Span-kind mapping (existing Authority semantics, unchanged)

| Provenance | `ProtectedSpanKind` | Authority effect |
|---|---|---|
| applied normalization | `.deterministicallyResolved` | any overlapping proposal rejected (`intersectsResolvedSpan`) |
| declined normalization | `.deterministicallyUnresolved` | overlapping proposal review-only (`intersectsUnresolvedSpan`) |

One span per provenance record (verified over an exhaustive 1,463-dictation corpus).

## 4. Exact projection rules

A record indexes the input of its `(pass, step)`. Its span *after its own step*
is `[start', start' + n)`: `start'` = record start shifted by the net length
change of the *other* applied records of that step that end at or before it; `n`
= replacement length (applied) or preserved text length (declined). It is then
carried through every later step (replay order; record-less steps are identity)
by mapping its two boundaries independently through that step's applied
replacements `[a,b) → L`:

- boundary `≥ b` → shifted by `L − (b − a)`;
- boundary `≤ a` → unaffected;
- boundary **strictly inside** `(a,b)` → **no exact image → unprojectable** (never
  given an invented coordinate);
- boundary exactly at `a` or `b` is a boundary, not "inside": adjacency and
  exact-boundary coincidence are well defined;
- a later replacement wholly inside the span resizes it (nested); one exactly
  equal to the span maps the span onto the replacement's output; a zero-length
  replacement at a boundary is ambiguous and reported.

Finally each span is **verified against the actual final text**: expected content
is the record's replacement/trigger with wholly-nested later replacements applied.

## 5. Failure semantics (who owns what)

| Situation | Result |
|---|---|
| provenance inconsistent or tampered (`NormalizationReplay` rejects it) | `.failure(.invalidProvenance(NormalizationReplay.Failure))` — no span trusted |
| valid provenance, some span not projectable without ambiguity | `.failure(.unprojectable([UnprojectableProtectedSpan]))` — **every** such span listed (kind, origin, and the later change that blocks it); no partial result offered |
| projected span disagrees with the final text (unreachable for valid provenance) | `.failure(.projectionVerificationFailed(…))` |
| otherwise | `.success` |

A failure can never silently become omitted protection: there is no partial span
list to misuse, and passing `[]` to composition would be an explicit caller
decision. What a caller does on failure (e.g. skip Intelligence for that text) is
future wiring policy, not decided here.

## 6. Edge-case decisions

Boundaries before/after length-changing replacements (shift vs unchanged);
adjacency and touching spans (shared boundary, no overlap); exact-boundary
coincidence (span mapped onto the later replacement's output); wholly nested later
replacement (span resizes, both spans kept); span wholly consumed by a *larger*
later replacement, and partial intersection (unprojectable); nested/cross-pass
(lookup → statutory → witness, applied and declined mixed); multiple sequential
lookup steps; empty replacement (a deterministic deletion yields a zero-length
resolved span at that point — Authority semantics: an edit crossing it intersects,
an edit merely touching it does not); Unicode/Odia/non-BMP (UTF-16 offsets past
surrogate pairs); overlapping/identical resulting spans (kept, never merged — the
Authority already resolves overlaps most-restrictive-wins).

## 7. End-to-end Authority results

`NormalizationOutcome → derived spans → IntelligenceEditComposition → unmodified
Safety Authority`, on `"distt. section three zero two I P C then P W one and
section three hundred twenty three I P C stands"` (lookup `distt.→District`), five
individually safe capitalization edits:

| Edit | No spans (pre-V1.11) | With derived spans |
|---|---|---|
| `District→DISTRICT` (resolved lookup output) | accepted | rejected `intersectsResolvedSpan` |
| `Section→SECTION` (resolved statutory) | accepted | rejected `intersectsResolvedSpan` |
| `PW-1→pw-1` (resolved witness) | accepted | rejected `intersectsResolvedSpan` |
| `section three→Section three` (declined statutory) | accepted | **review-only** `intersectsUnresolvedSpan` |
| `stands→Stands` (outside every span) | accepted | accepted |

plus crossing-into vs merely-adjacent-to a span, and the unprojectable case (typed
failure, no spans).

## 8. Tests

`Tests/ProtectedSpanDerivationTests.swift` (19 tests): kind mapping; length-changing
projection; adjacency/touching; nested resize; exact equality; before/after shifts;
partial intersection and span-inside-larger-replacement (unprojectable); every
unprojectable span reported; sequential lookup steps; zero-length spans; Unicode;
cross-pass; overlap kept; deterministic order; failure ownership (tampered /
unprojectable / success); an exhaustive corpus (every record → one span; **0
unprojectable** for realistic production pipeline shapes); and the two end-to-end
tests above.

## 9. Is the protected-span safety gap closed? What remains?

**The deterministic-normalization protection gap is closed at the derivation
level**: resolved and unresolved normalization regions now receive their
intended, existing protections in the Authority, in the correct coordinates, with
typed failure ownership. It is **not closed in any live path** — nothing calls it.

Still open before dictation integration or live-model evaluation:
1. **Wiring policy** (not built): obtaining the outcome at the ContentView seam,
   deriving, composing, and the fail-closed behavior on `.failure`.
2. **`.independentlyProtected` spans**: dates, amounts, case numbers, exhibits and
   proper names have no recognizer; the Authority can only review-gate them once
   something supplies spans. Surface edits (capitalization of a name or date) are
   still autonomously acceptable there today.
3. **Edit application** (composition returns no text) and review-only handling/UI.
4. **Live-model evaluation** against the V1 contract (occurrence accuracy, `null`
   optionals, over-broad spans, Unicode fidelity) — not authorized.

**The warning stands: do not wire Intelligence into dictation** until (1)–(3) are
resolved and live-model behavior has been evaluated.
