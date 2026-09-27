# Phase 3E.2B — targeted repetition diagnostics

Twenty-eight synthetic diagnostic cases (`References/diagnostics-3e2b/N01.json` .. `N12.json`,
`Y01.json` .. `Y10.json`, `P01.json` .. `P06.json`), following directly from the Phase 3E.2A
findings. **Measurement only — no production behavior was changed to make any case pass.**
Reuses the Phase 3E.1/3E.2A machinery unchanged; see the implementation report for why no new
evaluation infrastructure was needed.

## A. Statutory-number pronunciation (N01–N12)

Six provision numbers (34, 144, 323, 376, 506, 125), each dictated two ways as an odd/even pair.
`legalExpectations` records the desired outcome (e.g. `Section 34 IPC`) for both members of a
pair — never a rewrite of current behavior — so a run's normalization-outcome classification is
itself the comparison.

**Recorded baseline observation (snapshot, not a regression requirement), verified text-based
under a perfect-ASR assumption against the real `LegalDictationProcessor`:**

| Pair | Phrasing | `legalNormalized` | Outcome |
|---|---|---|---|
| N01/N02 | "thirty four" / "three four" | `Section 304 IPC.` / `Section 34 IPC.` | incorrect / **correct** |
| N03/N04 | "one forty four" / "one four four" | `Section 1404 BNSS.` / `Section 144 BNSS.` | incorrect / **correct** |
| N05/N06 | "three twenty three" / "three two three" | `Section 3203 IPC.` / `Section 323 IPC.` | incorrect / **correct** |
| N07/N08 | "three seventy six" / "three seven six" | `Section 3706 IPC.` / `Section 376 IPC.` | incorrect / **correct** |
| N09/N10 | "five zero six" / "five hundred six" | `Section 506 IPC.` / `Section 5 hundred six IPC.` | **correct** / incorrect |
| N11/N12 | "one twenty five" / "one two five" | `Section 1205 BNSS.` / `Section 125 BNSS.` | incorrect / **correct** |

**Pattern (evidence, not yet confirmed against real audio for this corpus):** every digit-by-digit
phrasing above currently normalizes correctly; every phrasing mixing a tens-word with another
digit currently concatenates positionally into a garbled multi-digit number (the same mechanism
as the Phase 3E.2A D02 finding — e.g. "thirty"=30 + "four"=4 → `304`, not the arithmetic 34);
"hundred" falls outside `SpokenNumberParser`'s vocabulary and only a prefix is consumed (the same
mechanism as the D03 finding). **This reverses the odd=natural/even=control framing for five of
the six pairs** — for those five, the user's more natural mixed phrasing is the one currently
mishandled, and the digit-by-digit control is the one that works. N09/N10 is the one pair where
the framing holds as stated (N09, digit-by-digit, is both the natural phrasing and the one that
currently works). Do not treat this table as fixed until confirmed against real audio, and do not
expand `SpokenNumberParser` to make any incorrect case pass — a failure here is the point.

Each statute critical token proactively includes its lowercase form (`ipc`/`bnss`) as a
`spokenForm`, per the Phase 3E.2A D03 lesson — real audio's casing is unpredictable, and this
stops a harmless casing variant from reading as a lost statute identity.

## B. Year-expression phrasing (Y01–Y10)

Five independent trials of each of the two D04/D05 phrasings, alternating A/B by id
(`Y01`,`Y03`,`Y05`,`Y07`,`Y09` = "Two thousand twenty six"; `Y02`,`Y04`,`Y06`,`Y08`,`Y10` =
"Twenty Twenty Six") so recording order doesn't correlate with phrasing. All ten target the same
intended date, `12 July 2026`. No date-normalization family exists or is implied.

Uses the existing `date` critical token, unmodified: its `state()` per stage is `canonical` (a
correct digit representation was produced), `spoken` (this file's own exact phrasing survived,
still in words), or `wrong` (neither). That already gives the three categories asked for:
"recognizable correct date" = canonical or spoken; "canonical digit representation" = canonical
specifically; "incorrect or incomplete" = wrong. **Caveat:** matching is presence-based against
one exact string, so an alternate but still-correct digit rendering (different date-part order,
for instance) would also read as `wrong`. Read each result's stored `postASRDeterministic` text
directly before concluding a trial produced an incorrect date — don't rely on the token state
alone for that judgment.

## C. Sentence punctuation (P01–P06)

Three passages (each with two internal intended sentence boundaries and one final boundary),
each recorded as two independent takes — 6 samples, 12 internal boundaries total. `reference`
carries no punctuation (none is spoken); `intendedFinal` is the correctly punctuated passage —
the same design already used for D06–D10.

**No new evaluation machinery was added for boundary-level classification.** Each sample's result
file already stores its full `postASRDeterministic` text verbatim. With only two internal
boundaries per passage, and the sentence identified by its own distinct wording, the punctuation
character at each boundary (period / comma / missing / other) is directly legible by reading that
stored text — exactly the method already used to read the Phase 3E.2A D06–D10 results. The
existing `formatting.comparable` flag already reports the fifth required category ("not
comparable because recognition changed the surrounding words") for the sample as a whole. This
was judged sufficient rather than building a positional-diff subsystem for 12 boundaries; see the
3E.2B implementation report for the reasoning.

## Recording and running

Same procedure as `DIAGNOSTICS_3E2A.md`: record each case's `reference` text as a short private
audio clip named `<id>.<ext>` in a private directory outside the repo (P01–P06's two takes per
passage must be genuinely separate recordings), then:
```
scripts/eval_run.sh --references Evaluation/References/diagnostics-3e2b \
  --audio <private-audio-dir> --out <private-results-dir>
```

## Attribution limits

Identical to Phase 3E.2A: `postASRDeterministic` is not raw ASR — it already includes filler
removal, custom dictionary and spoken-punctuation formatting, so a failure at that stage cannot
be attributed to the provider specifically. Only the `postASRDeterministic → legalNormalized`
transition is attributable to the legal normalizer. Ordinary WER is not legal-aware: a correct
digit conversion (e.g. "three two three" → `323`) is penalized identically to a real word error.
