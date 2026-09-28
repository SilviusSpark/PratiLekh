# V1.13 numeric-structural-protection validation corpus (frozen)

Written and frozen **before** any V1.13 production code existed. Its SHA-256 is
pinned in `Tests/NumericStructuralProtectionTests.swift`; any later edit breaks
that test, so a change requires a documented labeling correction (see
`Evaluation/Intelligence/V1_13_NUMERIC_STRUCTURAL_PROTECTION.md`).

The corpus is **fresh**: it was authored for V1.13 and shares **no text** with the
V1.12 corpus (checked mechanically before freezing). Like V1.12's it is synthetic
and implementer-authored, so it validates the mechanism's behaviour, not
prevalence in real dictation.

## Pre-registered mechanism (the rule under test)

1. A *digit* is a Unicode scalar whose general category is `Nd` (decimal digit) in
   any script (Latin, Odia, Devanagari, Arabic-Indic, fullwidth, mathematical, ...).
   `No`/`Nl` numeric characters (`½`, `²`, `Ⅻ`) are **not** digits (documented gap).
2. A *digit run* is a maximal sequence of consecutive digits.
3. Two consecutive digit runs are joined into one *numeric span* when the text
   between them (the *gap*) is non-empty and contains **no letter (category `L*`),
   no combining mark (`M*`) and no line break** (`U+000A`, `U+000B`, `U+000C`,
   `U+000D`, `U+0085`, `U+2028`, `U+2029`). Any other character may appear in a gap:
   spaces, tabs, NBSP, punctuation, symbols, currency signs, format characters.
4. The span covers from the first digit of the first run to the last digit of the
   last run. Digits only; nothing is inferred about what a number means.
   Whitespace-separated numerals are therefore one span (rule 3), a decision made
   because deleting the whitespace merges the numerals and changes the value.

## Labeling guideline

`expressions` lists, per entry, the exact substrings that are intended numeric
spans under the rule above. Each must occur exactly once in `text` and must be
covered completely by a single span. Labels were written by hand and then
cross-checked against an independent Python implementation of the rule *before*
freezing.

## Hazard oracle (independent of the labels)

Acceptance is not judged from the labels alone. For every text, every single
surface edit (delete or replace a punctuation character with one of `, . - / :`,
delete a horizontal-whitespace character or a whole whitespace run, insert one of
`, . - / :` or a space between any two scalars) that the production classifier would
let Intelligence apply autonomously is generated **over the whole text**, and it is a
*digit-structural hazard* if it changes either (a) the list of digit runs of the
text, or (b) the sequence of separator characters (`, . / : -`) lying directly
between two digits. Every such hazard must be blocked by the independent spans
(not autonomously accepted by the real Safety Authority).

## Acceptance criteria (pre-registered)

1. 0 digit-structural hazard edits escape.
2. Every labeled expression is covered completely by a single span.
3. Digit-free text receives no span.
4. Protected characters outside labeled expressions are at most 2% of all characters.
5. Latin, Odia and Devanagari decimal digits work.
6. Deterministic and idempotent output.
7. Zero-length insertion edge behavior is explicitly tested.
8. Composition with V1.11 spans and the V1.8 Authority path is tested.
