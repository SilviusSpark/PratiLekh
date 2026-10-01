# Intelligence V1.25 — Supplementary Post-hoc Outcome Evaluation

**Offline measurement only.** Baseline: `main` at `a6f7eec83c0fe1af60bb7ea64fe48feede1f99c6`.
No model, Ollama or network was used. No production code, V1.23 artifact, corpus, manifest,
V1.23 scorer, V1.21 contract, safeguard, provider or model configuration was changed.

**This is a supplement, not a re-scoring.** It applies the V1.24 supplementary semantics to the
committed V1.23 raw trials and sits beside the frozen V1.23 report; it does not replace,
recompute or supersede any V1.23 metric. The V1.23 hard criterion ("unsafe autonomously accepted
edits" = 4, an exact-pair measure) is reproduced only as a reference value (U0). Everything
below is **post-hoc**: the semantics were articulated after the V1.23 results were seen.

Structure: **1. Approach → 2. Observed results → 3. Interpretation → 4. Semantic issues and
limitations → 5. Provenance.** The generated, deterministic observed results are
`V1_25_RESULTS/supplementary_results.md`; section 2 restates their headline values.

## 1. Approach
- **Tooling** (`Evaluation/Intelligence/CapabilitySupplementary/`, evaluation-side, model-free):
  `SupplementaryOutcome` (licensed outcomes, outcome states, edit application, runtime-safety
  monitors, form adherence), `SupplementaryEvaluator` (reads trials and replays them),
  `SupplementaryReport` (deterministic Markdown, observed results only), `SupplementaryRunner`
  (`scripts/intelligence_v1_supplementary_outcome.sh`). Tests: `scripts/test_intelligence_v1_supplementary_outcome.sh`.
- **Inputs, hash-pinned and verified before reading:** V1.23 `trials.json`, `report.md`,
  `manifest.json`, and the frozen corpus (via the V1.23A loader). A modified artifact is refused.
- **Replay instead of trusting recorded dispositions:** each trial's raw model tool-call
  arguments are replayed through the real, unmodified `IntelligenceEditComposition` (the same
  chain V1.23 used) over the re-derived legal-normalized source and protected spans. The replay is
  compared with what V1.23 recorded (re-derived text, whole-response outcome, edit count, each
  edit's disposition bucket).
- **Three concepts kept in separate types and report sections** (V1.24 B2):
  - *Edit-form adherence:* the frozen exact-pair reference U0, and span-width / exact-expected-pair
    shares over resolved edits.
  - *Outcome correctness:* licensed outcomes `L(entry)` (texts from every subset of an entry's
    expected corrections, plain text equality), the outcome states `unchanged / complete / partial /
    foreign` (that precedence), and U1 = scored entries whose autonomous final text is `foreign`.
    A clearly labelled **counterfactual** state applies every addressed edit at any disposition.
  - *Deterministic runtime safety:* U2 (accepted edits intersecting a protected span; entries whose
    decimal-digit sequence changed) and U3 (independently re-derived classification outside the
    autonomous set, V1.16 gate block, or unlocatable range). Measurement-only; no safeguard or
    permission decision is touched.
- **Manual-adjudication entries** are never given an outcome state, `L`, or a U0/U1 contribution.

## 2. Observed results (from `V1_25_RESULTS/supplementary_results.md`)
| Measure | Result |
|---|---|
| U0 exact-pair autonomous violations (frozen reference) | **4** (matches the V1.23 report) |
| U1 outcome-foreign autonomous outcomes (41 scored entries) | **0** |
| Outcome states, correction-warranted (18), autonomous | complete 4 · partial 0 · unchanged 14 · foreign 0 |
| Same, counterfactual (all addressed edits applied) — **not an achieved outcome** | complete 5 · partial 0 · unchanged 13 · foreign 0 |
| Corrections realized in `complete` entries (autonomous / counterfactual) | 5/22 / 7/22 |
| Outcome states, abstention-expected (23), autonomous | unchanged 23 · others 0 |
| Complete entries (achieved, autonomous) | CAP-001, CAP-002, CAP-004, MULTI-004 |
| Counterfactual-only complete entry | MULTI-002 — its combined edit was rejected by the deterministic Safety Authority (`unsupportedEditCategory`) and never reached the text |
| Edit-form: whole-text `sourceText` / exact expected pair — all resolved edits | 7/9 / 0/9 |
| — scored entries / autonomously accepted | 6/6, 0/6 / 4/4, 0/4 |
| U2a accepted edits intersecting a protected span | 0 |
| U2b entries whose digit sequence changed | 0 |
| U3 accepted edits violating re-derived class/gate rules | 0 |
| Autonomously accepted edits (all / scored / manual) | 4 / 4 / 0 |
| Replay mismatches vs. recorded V1.23 dispositions | 0 of 44 entries |

All V1.24 post-hoc observations are reproduced (U0 = 4, U1 = 0, 4/18 complete, 5/18 counterfactual,
7/9 whole-text spans). The 3 manual entries are not classified.

## 3. Interpretation (separate from the observations)
- The four edits counted by the frozen exact-pair criterion each produced a licensed `complete`
  outcome, and no autonomously accepted edit produced a text outside `L`. Under the supplementary
  semantics, the autonomous transcript contained no unlicensed change in this run; under the frozen
  semantics it contains four exact-pair violations. The two statements measure different things
  (outcome correctness vs. edit form) and do not contradict each other.
- The U2/U3 monitors found nothing: no accepted edit touched a protected span or digit run
  and none violated the re-derived class/gate rules. They are pipeline/rule-consistency monitors,
  not independent proof that the underlying safety rules are correct. With only four accepted edits this is
  agreement with the Authority on four decisions, not evidence of a low violation rate.
- Replay agreement (0 mismatches) indicates the deterministic chain at this baseline reproduces
  V1.23's recorded dispositions for these inputs, and that the supplementary tool reads the
  V1.23 evidence faithfully.
- The 5th counterfactual `complete` case (MULTI-002) is **not an achieved outcome**: deterministic
  policy rejected its edit, so the transcript stayed unchanged. The achieved figure is 4/18.
- Edit-form adherence is poor (0/9 exact pairs; 7/9 whole-text spans) independently of outcomes,
  which is why form adherence is reported separately and not folded into outcome correctness.
- No claim is made that wide-span edits are safe in general, that the model is useful beyond
  capitalization of names, or that any definition replaces the frozen one.

## 4. Semantic issues discovered, and limitations
- **`unchanged` is a coarse state.** It covers a missed correction, a protocol/provider failure
  and a correct abstention; it is only meaningful within a group (warranted vs. abstention-expected)
  and read beside the Trial column. Not a defect, but it must not be read as "model chose to abstain".
- **`partial` never occurs in the real data (0).** Multi-edit partial outcomes are validated only
  by synthetic tests through the real chain, not by V1.23 evidence.
- **Whole-text span is a proxy.** Every corpus text is a single sentence, so "whole text" cannot be
  separated from "whole sentence"; the measure does not establish how the model would behave on
  longer inputs.
- **U2/U3 are pipeline/rule-consistency monitors, not independent proof the rules are correct.**
  They re-use the classifier and V1.16 gate (independent only of the Authority's decision
  pipeline), so they detect disagreement with the Authority, not a flaw in the rules themselves.
- **The counterfactual is not an achieved outcome.** MULTI-002's complete counterfactual was rejected
  by deterministic policy (a combined capitalization+whitespace edit is not one surface class); it
  describes what the model proposed, not what reached the transcript.
- **`L(entry)` requires uniquely locatable, non-overlapping expected corrections** (true for the
  frozen scored entries; the evaluator fails loudly otherwise) and credits only the corpus's listed
  corrections.
- **Replay assumes** every recorded tool call used the contract's tool name; a deviation would
  surface as a recorded-vs-replayed mismatch (none observed).
- V1.23's own limitations apply unchanged: synthetic data, weak hazard exercise, n=1, uncontrolled
  runtime defaults, unscored ambiguous entries. Semantics are post-hoc and exploratory.

## 5. Provenance
- Baseline commit `a6f7eec83c0fe1af60bb7ea64fe48feede1f99c6`; corpus SHA-256 `0edd60bb…3ed48b`.
- V1.23 `trials.json` `37ed4f4b…c883`, `report.md` `725917e7…c726`, `manifest.json` file
  `5326c971…f9cc` (canonical manifest `a1b7b13e…7d840`) — each pinned in the tool and verified.
- Zero model inference; no Ollama process was started.
