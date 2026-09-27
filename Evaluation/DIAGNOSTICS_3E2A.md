# Phase 3E.2A — controlled diagnostic baseline

Ten synthetic diagnostic cases (`References/diagnostics-3e2a/D01.json` .. `D10.json`) prepared to
investigate three behaviors observed in real judicial dictation trials. **This is a measurement
milestone: no production behavior was changed to make any case pass.** An `apply`/`noCandidate`
expectation records the *desired* outcome; the run reveals whether the current system reaches it.

Uses the existing Phase 3E.1 machinery unchanged (schema, runner, scorer, metrics) — no evaluation
code changes were needed to represent or run these cases; see the milestone's implementation report
for why.

## The three investigations

**A. Section-number phrasing (D01–D03)** — same provision (Section 323 IPC) dictated three ways:
digit-by-digit (D01, works reliably in manual use), mixed digit+tens (D02), and hundreds-form (D03).
Compare each sample's `postASRDeterministic` (did the words survive?) against its `legalNormalized`
output and normalization outcome (`correctApplication`/`incorrectTransformation`/etc.) to see whether
a divergence from D01 is a recognition difference or a normalization gap. **Do not expand the
statutory parser because a case fails here** — that is a Phase 3 grammar decision for later, not
this milestone's job.

**B. Year/date phrasing (D04–D05)** — same date, two spoken year forms. Neither implies any date
normalization; both use `legalExpectations: noCandidate`. Compare the two samples' `postASRDeterministic`
text directly against each other and against their `date` critical token's `spokenForms` to see
whether one phrasing survives recognition/formatting more reliably than the other.

**C. Sentence punctuation (D06–D10)** — the *same* intended passage, dictated as **five separate,
independent recordings**. Each carries `intendedFinal` (the correctly punctuated sentence) against
`reference` (the words with no punctuation, since none is spoken). The existing `formatting`
score (`comparable`, `caseDifferences`, `punctuationDifferences`) already measures exactly this —
no new positional-diff machinery was built. **Read each of the five result files individually** —
`D06.result.json` .. `D10.result.json` — not just the run's aggregate summary, to see which sentence
boundaries got a full stop in which run.

## Recording and running

1. Record ten short audio clips of the "Dictated text" in each `D0N.json`'s `reference` field, in
   your own voice, in a **private directory outside this repository** (e.g. `~/pratilekh-eval-audio/`).
   Name them `D01.<ext>` .. `D10.<ext>` (`wav`/`m4a`/`mp3`/`flac`/`caf`/`aiff`). For D06–D10, record
   five genuinely separate takes of the same passage — do not reuse one recording or its output.
2. Launch PratiLekh with its Local API enabled (Settings; off by default — this tooling never
   changes it).
3. Run, with results going to a private directory outside the repo:
   ```
   scripts/eval_run.sh --references Evaluation/References/diagnostics-3e2a \
     --audio ~/pratilekh-eval-audio --out ~/pratilekh-eval-results
   ```
4. Read `summary.txt` for the aggregate, then open each `D0N.result.json` for that sample's
   `stages` (full text at both observable stages), `criticalTokens` (state/transition per stage),
   `normalization` (outcome, only where a legal expectation applies), and `formatting`.

## Recorded baseline observation (snapshot, not a regression requirement)

Under a perfect-ASR assumption (offline text input identical to each `reference`), against the
Indian Legal Core pack and normalizer as of commit `e916cbc` (Phase 3E.1):

| Case | `legalNormalized` output | Normalization outcome |
|---|---|---|
| D01 | `Section 323 IPC.` | `correctApplication` (matches the desired `Section 323 IPC`) |
| D02 | `Section 3203 IPC.` | `incorrectTransformation` |
| D03 | `Section 3 hundred twenty three IPC.` | `incorrectTransformation` |

This snapshot is **not enforced by the automated test suite** for D02/D03 — only D01 (the reliable
baseline) is asserted strictly in `Tests/Diagnostics3E2ATests.swift`. D02's and D03's exact outputs
are recorded here as a diagnostic finding, not a regression requirement: a future, deliberate fix to
the statutory-number parser is expected to change these two rows without needing any test edit.
Re-run `scripts/eval_run.sh` against the diagnostic references to get current numbers rather than
trusting this table if time has passed.

Findings, as currently understood from this snapshot (not yet root-caused against real audio):
- **D02** (`three twenty three`): `SpokenNumberParser` concatenates every recognized digit/tens word
  positionally ("three"->3, "twenty"->20, "three"->3, joined as `3`+`20`+`3` = `3203`) rather than
  reading "twenty-three" as one two-digit unit. This is the parser's documented, approved shape for a
  different case ("one twenty" -> "120"); D02 exercises the same mechanism with an extra trailing
  digit word, producing a 4-digit number.
- **D03** (`three hundred twenty three`): confirmed to be the parser consuming only its supported
  prefix ("three") and stopping at "hundred" (outside its digit/tens vocabulary), so only the
  substring "Section three" is replaced ("Section 3"); the remainder is left untouched. This is a
  parser-boundary finding, not a bug in candidate detection — the rule declines to guess past its
  supported grammar, exactly as designed; it simply was not designed to reject the whole candidate
  when only a *prefix* of the number parses, which is what produces the partial, incorrect result.

## Attribution limits (read before classifying a failure)

`postASRDeterministic` is **not** raw ASR — it already includes filler removal, custom dictionary
and spoken-punctuation formatting. If a case fails, the observable stages **cannot** by themselves
distinguish "the provider misheard the words" from "one of those three deterministic steps altered
them" — both precede the only stage this milestone can see. Where that ambiguity applies, report it
as a limitation rather than guessing which of the three caused it. Only the transition into
`legalNormalized` is attributable specifically to the legal normalizer (assuming
`postASRDeterministic` is treated as that stage's input, which it is).

Ordinary WER is **not** legal-aware: if D02/D03 legitimately produce `323` where the dictated words
were "three twenty three" / "three hundred twenty three", WER penalizes the word-level difference
even though the number might be exactly right. Critical-token state/transition is the intended
measure for that; do not read WER alone as a verdict on legal correctness.

## Suggested (not automatic) failure classification

Based on what the stage outputs and existing outcome types actually show, not on speculation:

| Observation | Likely category |
|---|---|
| `postASRDeterministic` doesn't contain the dictated words/number at all (critical token `wrong` from stage one) | recognition failure (attribution limited — see above) |
| A statute name/number is heard but garbled specifically around legal vocabulary | legal-vocabulary recognition failure |
| Critical token `spoken` -> `canonical` | normalization recovery |
| Correct words in, but `legalExpectations` `apply` not reached (`missedOpportunity`) | normalization miss |
| Critical token `spoken`/`canonical` -> `wrong` (`corrupted`) alongside `incorrectTransformation` | normalization corruption |
| `legalExpectations: noCandidate` and no candidate is produced, but `formatting.punctuationDifferences` > 0 | formatting/punctuation failure |
| The same divergence recurs across D02/D03-style cases without an existing rule family to cover it | unsupported recurring requirement |

Do not force a row above onto a case where the evidence doesn't support it — say the evidence is
inconclusive instead.
