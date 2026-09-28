# Intelligence V1.13 — Numeric Structural Protection

## 1. Status and scope

V1.13 implements the mechanism V1.12 recommended: a **category-agnostic,
deterministic, model/provider-independent** function that emits
`.independentlyProtected` spans over numeric structure —
`Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift`. It does
not infer what any number means, has no lexicon, no per-category pattern, no
spelled-number recognizer and no name detection; the Safety Authority and classifier
are unchanged; nothing is wired into dictation.

**Acceptance criteria were pre-registered and validated on a genuinely fresh,
frozen corpus; all passed** (§5). Read §7 for what that does and does not show.

## 2. Phase A — the frozen validation corpus

`Evaluation/References/numeric-structural-protection/` (`README.md` + `corpus.json`)
was written **before any production code existed** (`git status` showed only that
directory untracked when it was frozen). It pre-registers the rule, the labeling
guideline, the hazard oracle and the acceptance criteria, and fixes the corpus by
SHA-256 (`2aefbc42dceb3bf0aae127bc3a6a17116026e5e3022bb13c331c69c349853a86`), which
`Tests/NumericStructuralProtectionTests.swift` recomputes — a post-hoc edit fails
that test and would have to be a documented labeling correction (**none was made**).

- **192 entries** (124 positive, 48 boundary, 20 negative) in 12 groups: dates/times
  (25), amounts (20), case/reference numbers (20), statutory/witness/exhibit numbers
  (20), ordinary non-legal numbers (15), whitespace-separated numerals (15),
  punctuation-linked runs (15), Odia digits (12), Devanagari digits (12), digit-free
  negatives (20, incl. Odia/Devanagari text, spelled numbers, roman numerals), Unicode
  and boundary cases (13: astral/fullwidth/Arabic-Indic digits, NBSP, ZWJ, RTL marks,
  combining marks, keycap emoji, line separators, `½`/`²`/`Ⅻ`), and 5 realistic prose
  paragraphs. 244 labeled numeric expressions; 23 entries contain no decimal digit.
- **Fresh:** authored for V1.13; shares **no text** with the V1.12 corpus (checked
  mechanically before freezing).
- **Labels cross-checked before freezing** against an independent Python
  implementation of the pre-registered rule: they agreed on every entry except four
  *authoring* defects (a labeled substring occurring twice in its text, so it could not
  be located uniquely), fixed by rewording those texts **before** freezing. No label was
  changed after any production result existed.
- Like V1.12's, it is synthetic and implementer-authored: it validates the mechanism's
  behaviour, not prevalence in real dictation.

## 3. Exact detector semantics

1. A *digit* is a Unicode scalar of general category `Nd` in any script (Latin, Odia,
   Devanagari, Arabic-Indic, fullwidth, mathematical, …). `No`/`Nl` numeric characters
   (`½`, `²`, `Ⅻ`) are **not** digits — a documented gap.
2. A *digit run* is a maximal sequence of consecutive digits.
3. Two consecutive digit runs join into **one span** when the *gap* between them
   contains **no letter (`L*`), no combining mark (`M*`) and no line break**
   (`U+000A`–`U+000D`, `U+0085`, `U+2028`, `U+2029`). Any other character may appear
   in a gap: spaces, tabs, NBSP, punctuation, symbols, currency signs, format
   characters.
4. A span runs from the first digit of its first run to the last digit of its last
   run; kind `.independentlyProtected`. Coordinates are UTF-16 of the input text.

Output is a pure function of the text: ascending, non-overlapping and never adjacent
spans; re-protecting a span's own text yields exactly that span. It was written fresh
for production (scalar scan, not V1.12's ASCII-oriented regex): it handles astral
digits and surrogate pairs, uses general categories rather than `\d`, and has a
defined gap rule instead of a fixed joiner set.

**Deliberately unprotected:** letters and words attached to a number from outside
(`12th`, `Rs.`, `Ext.P-`), so word-structural damage (`12thJuly`, `Ram Das`→`RamDas`)
and spelled numbers/dates are out of scope, as is anything with no `Nd` digit.

## 4. Whitespace-separated numerals (decision, made before implementation)

**One span.** Numerals separated only by non-letter, non-mark, non-line-break
characters are protected together, gap included (`12 34`, `1234 5678 9012`,
`Rs. 5 000`, `294 323 506`, `12  34`, tab- or NBSP-separated, and punctuation-plus-space
gaps such as `2026. 5` or `294, 323, 506`). Reason: deleting the whitespace between
`12 34` merges the numerals and changes the value, and a whitespace-only edit is
autonomously acceptable, so the gap has to be inside the span; likewise `2026. 5` →
`2026.5`. A line break, a letter or a mark separates spans (line-break edits are not
autonomous anyway). **Cost, accepted:** a legitimate collapse of a double space
between two numerals is demoted to review-only; ordinary lists of numbers protect
their separators.

## 5. Results on the frozen corpus (all acceptance criteria passed)

| Criterion | Result |
|---|---|
| 1. 0 digit-structural hazard edits escape | **5,831 hazard edits** (whole-text oracle, real classifier, real Authority): **0 escape**; with no spans all 5,831 escape, so the oracle is live |
| 2. every labeled expression covered completely by one span | **244/244**; spans equal the labels in **192/192** entries |
| 3. no protection on digit-free text | **0 spans in all 23** digit-free entries (and every entry with a digit has a span) |
| 4. protected characters outside labeled expressions ≤ 2% | **0 / 8,116 (0.000%)** |
| 5. Latin, Odia, Devanagari digits | Odia: 357 hazards, 0 escapes, all covered; Devanagari: 357 hazards, 0 escapes, all covered |
| 6. deterministic, idempotent | repeated calls identical; text-only dependence; re-protecting a span's text yields exactly that span |
| 7. zero-length insertion edges explicit | insertion immediately before the first digit or after the last digit is **not** blocked (`,` `.` space); insertion at any position strictly inside is blocked (`review-only`); a boundary-touching positive-length edit is outside, one reaching in is not autonomous |
| 8. composition with V1.11 and the V1.8 path | tested end to end (§6) |

Per-group hazards/escapes were 0 in every group. **Additional, non-corpus evidence:**
a seeded randomized test (1,500 random strings over Latin/Odia/Devanagari digits,
joiners, spaces, tabs, line breaks, letters and marks) found 13,584 hazard edits and
**0 escapes** — never tuned against.

Protected-character *share*: 15.0% of all corpus characters (the corpus is
number-dense by design) but **2.0% in the five realistic prose paragraphs** (37 of
1,871) — the realistic-density figure.

## 6. Composition with V1.11-derived spans

`NormalizationProtectedSpans.spansIncludingNumericStructure` returns the V1.11 spans
followed by `NumericStructuralProtection.spans` of the **same** `normalizedText`
(spans and source cannot be mismatched). Composition is plain concatenation: nothing
is merged, deduplicated or trimmed, V1.11 spans are preserved verbatim and first, and
overlaps (e.g. the digits inside a resolved `Section 302 IPC`) are resolved by the
Authority's existing most-restrictive-wins rule. End to end
(`NormalizationOutcome → derived + numeric spans → V1.8 composition → unmodified
Authority`) on a text with a witness ref, date, amount, statutory citation and a
space-separated numeral pair: `12.07.2026→12072026`, `5,000→5.000` and `12 34→1234`
were autonomously accepted with V1.11 spans alone and are **review-only** with the
numeric spans; `Section→SECTION` and `302→3,02` (an independent span nested inside a
resolved one) are **rejected** (resolved wins); `stands→Stands` is accepted; and
`Ram Das→RamDas` is still accepted (names are out of scope).

## 7. What this does and does not establish

- **Independent where it matters, not everywhere.** The escape criterion uses a
  whole-text oracle independent of the labels and of the detector, on a corpus frozen
  before the detector existed; that is genuine validation of the mechanism against
  digit-structural hazards. The coverage criterion is *not* independent: labels were
  written to the same pre-registered rule (and cross-checked against an independent
  Python implementation of that rule), so 244/244 and 192/192 mostly confirm the
  implementation matches its specification, including for Odia/Devanagari/astral
  digits.
- **Scope of the oracle.** It covers single surface edits from a fixed menu
  (delete/replace punctuation with `, . - / :`, delete a space or a whole whitespace
  run, insert `, . - / :` or a space between scalars). Multi-edit combinations across
  proposals are handled only by the Authority's overlap rules.
- **Still unprotected:** spelled numbers/dates/amounts (the dominant real-ASR date
  form), word-structural damage, names, `No`/`Nl` numeric characters, and text with
  no decimal digit. Corpus and randomized text are synthetic; no real-dictation
  prevalence was measured.
- **Cost:** ordinary numbers and their separators are protected; double-space
  collapses between numerals are demoted to review.
- **Review-only, not forbidden:** independent spans demote edits, they do not block
  them outright.
- **Still not wired into dictation. The do-not-wire warning stands.**

## 8. Files

Production: `Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift`.
Tests: `Tests/NumericStructuralProtectionTests.swift` (run by
`scripts/test_protected_span_derivation.sh`). Frozen data:
`Evaluation/References/numeric-structural-protection/`.
