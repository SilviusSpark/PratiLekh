# Intelligence V1.29 — Stage S2: Comparison Execution Tooling

**Tooling construction and offline validation only.** No model was loaded or run, Ollama was not started, no
candidate (baseline included) saw the 66-entry development corpus or the 44-entry V1.23 benchmark, and nothing under
`Evaluation/References/intelligence-v1-comparison-dev/`, the V1.27 tooling (`ComparisonProtocol/`), the S1 artifact,
the V1.23/V1.25 artifacts or `Sources/` changed. S3 (screening) has not begun. Authority: the committed V1.27
protocol (`V1_27_MODEL_COMPARISON_PROTOCOL.md`, `protocol.json`) and the V1.28 S1 artifact.

## 1. What was built (`Evaluation/Intelligence/ComparisonExecution/`)

| File | Role |
|---|---|
| `ComparisonExecutionEntryTypes.swift` | corpus-isolation seam (§2): entry schema only, no benchmark loader/path/pin |
| `ComparisonExecutionPlan.swift` | pinned plan: candidate order, 390 steps, contract arm, request constants, every input/tooling hash; canonical plan SHA-256 |
| `ComparisonExecutionRecords.swift` | the raw per-call record and JSON-lines coding |
| `ComparisonExecutor.swift` | sequential executor with an injected proposer; no model/network symbol |
| `ComparisonScoring.swift` | per-entry scoring from a raw record (V1.23 adjudication + V1.25 outcome semantics); audit comparison |
| `ComparisonAnalysis.swift` | metric groups, gates G1–G3, A1/McNemar, ranking, probe trigger, audit flag, markdown report |
| `ComparisonProvider.swift` | the only `LLMClient`-linked piece: builds the frozen request config, one call per step |
| `ComparisonLiveRunner.swift` | guarded S3 entry point (built, **not run**) |
| `ComparisonAnalysisRunner.swift` | offline re-analysis of `records.jsonl` (no model, no `LLMClient`) |

Also: `scripts/intelligence_v1_comparison_s3_run.sh`, `scripts/intelligence_v1_comparison_s3_analyze.sh`,
`scripts/test_intelligence_v1_comparison_s2.sh`, three test files (`Tests/IntelligenceV1ComparisonS2*.swift`), and the
proposed plan `Evaluation/References/intelligence-v1-comparison-s2/S3_PROPOSED_RUN_PLAN.json`. Existing frozen scoring
code (`CapabilityAdjudicator`, `CapabilityMetrics`, `SupplementaryOutcome`, the V1.17 harness pipeline, the V1.27 corpus
loader and hazard-fixture replay) is reused unmodified, not re-implemented, except for the one per-entry loop noted in §3.

## 2. Isolation: the benchmark is not in the binary

The V1.23A scoring code is written against `CapabilityCorpus.Entry`, which lives in the same file as the benchmark loader,
its path and its pin; the frozen files may not be edited. So the execution build **does not compile
`CapabilityCorpus.swift`**. `ComparisonExecutionEntryTypes.swift` supplies, under the same names, only the `Correction`/`Entry`
schema (text-identical to the frozen declaration — a parity test slices and compares both) and an entries container. There is
no `load`, `relativePath`, `frozenSHA256` or `frozenEntryCount` to call. Defence in depth:

1. **Compile-level:** `scripts/test_intelligence_v1_comparison_s2.sh` type-checks 10 probe programs against the exact execution
   source set (`CapabilityCorpus.load`, `.frozenSHA256`, `.relativePath`, `.frozenEntryCount`, `SupplementaryArtifacts`,
   `CapabilityRunManifest`, `CapabilityFrozenRun`, `CapabilityPreflight`, `ComparisonFreeze`, `ComparisonOverlap`); every one
   must fail, with a positive control that compiles.
2. **Source-set guards:** the runner, analyzer and test scripts compile exactly the Swift-declared source lists; none contains a
   forbidden file (`CapabilityCorpus/Manifest/LiveRunner/…`, `SupplementaryEvaluator`, `ComparisonFreeze*`, `ComparisonOverlap`).
3. **Content guards:** no execution-path file contains a benchmark path, pin, `V1_23_RESULTS`, or loader token; the only
   `Evaluation/References/*` folders named are the development, S1 and S2 ones; the core tooling has no `URLSession`,
   `URLRequest`, `Process(`, or `LLMClient.` symbol; only the provider and live runner touch a model or network.
4. **Executor structure:** one proposer call site, only after a successful preflight; no `while`/`repeat` (no retry loop); a
   `developmentCorpus` run is refused unless the corpus is the pinned one and the plan is complete; fixture runs are stamped
   `toolingFixture` and the analyzer refuses them as development evidence.

The development corpus is loaded only by `ComparisonCorpus.load` (pinned SHA-256, composition checked). The plan builder verifies
every frozen artifact and the S1 artifact against pinned hashes before reading them.

## 3. Pre-registered design, as implemented

- **Plan.** Candidates in S1/registry order (`CAND-BASE`, `CAND-001`…`CAND-004`; `CAND-OPT-001` unregistered and excluded); per
  candidate, 66 screening steps in corpus order, then the protocol's fixed 12 audit entries in protocol order; 5 × 78 = 390 steps;
  a candidate's steps are contiguous (one model resident). The plan fixes this before any call; no output can add, skip, repeat or
  reorder a step. Request constants (stream false, temperature 0, `tool_choice` auto, 60 s, `maxRetries` 1, base URL, Ollama
  0.34.4) are asserted equal to the frozen registry's `requestParameters`; parity with the V1.17 harness request is tested.
- **Baseline vs variant.** S3's plan is the `V1.21-production` arm; the pinned instructions/tool hashes are enforced, and the
  executor refuses instructions that do not match the plan's arm. `V-balanced-abstention` is a separate enum case, reconstructed
  from `contract_variant.json` and refused unless its hash is the pre-registered `b6a8575f…`; it is reachable only by code for the
  conditional S4 stage (no CLI flag, not hashed into the S3 plan, no S4 runner exists).
- **Scoring.** Adjudication/metrics are the frozen V1.23A code; outcome states, U1/U2/U3 monitors and form adherence are the
  frozen V1.25 code. `ComparisonScoring` re-states `SupplementaryEvaluator`'s per-entry loop because that file also loads the V1.23
  benchmark artifacts; a parity test (part B of the S2 test script) runs both on identical synthetic raw outputs across five
  behaviours and requires identical final text, outcome state, counterfactual state, accepted edits, U0, U2/U3 observations, licensed
  sets and edit-form tallies. Scoring is a pure function of (entry, record).

## 4. How S3 outputs and provenance are captured

One `ComparisonCallRecord` per step, appended to `records.jsonl` as the step ends (a crash keeps everything so far): run id,
global sequence, candidate id/tag, contract arm and the instructions/tool-definition SHA-256, phase (screening/audit), entry id and
ordinal, the raw input text, the exact user message (`legalNormalized`), a canonical request fingerprint, preflight failure, start/
end timestamps, wall-clock latency around the single call, provider failure text, the model's free text and thinking, every tool
call's name and **raw undecoded arguments**, and `/api/ps` snapshots after each candidate's first and last call (GPU/CPU placement
and loaded size for PO-3, recorded not gated). No judgement is stored: every metric is recomputed from records by the committed
deterministic chain (`scripts/intelligence_v1_comparison_s3_analyze.sh`), so a later reader can only reproduce, never reinterpret.
**Lifecycle evidence is a separate file.** Every non-proposer request the runner makes (identity probes, resident-model checks, the
`keep_alive: 0` unload and its verification) is a `ComparisonLifecycleEvent` in `lifecycle.jsonl` with its own sequence, endpoint,
canonical request body, HTTP status, resident models afterwards and `countsAsInference: false`. Such events never appear in
`records.jsonl`, never receive a step number and never enter a count, latency statistic or metric (the executor times only the
proposer call, and the analyzer reads only proposer records). `ComparisonLifecycleAudit` verifies, and the analyzer **requires**
(`--lifecycle`, refusing otherwise): proposer records == plan steps; no event marked as inference; exactly one unload per
candidate in plan order, each exactly the canonical keep_alive-0 body for that tag, no prompt content, after that candidate's last
proposer call, followed by a verification showing no resident model; one run id. The report carries a "Runtime lifecycle
accounting" section. Alongside it the run directory holds `plan.json` (the approved plan), `run_info.json` (plan hash, HEAD, tree state, Ollama version).
The live runner refuses an in-repo `--out`: records contain corpus text. The plan's canonical SHA-256 pins the S1/V1.27 artifacts,
the deterministic chain sources, the execution tooling, the scripts and the S2 tests; a drift in any changes the hash and the
committed `S3_PROPOSED_RUN_PLAN.json` stops matching (tested).

## 5. Validation performed (offline; no model, no network)

`scripts/test_intelligence_v1_comparison_s2.sh` (A execution build, B parity build, C negative compiles) — all pass. A covers: plan
shape/order/determinism/committed-file equality and refusal under tampering of the registry, protocol, variant spec, S1 artifact
and a non-pinned corpus; arm separation; executor mechanics with scripted proposers (one call per step, provider failure recorded and
never retried, hooks, refusals, JSONL round trip); scoring (oracle complete, strict-parser failures, missing/duplicated/wrong tool
calls, whole-text rewrite is `wholeText` width yet outcome-complete), audit comparison, exact McNemar values, G1/G2/G3, A1,
ranking with no registry tie-break (first-place tie → no finalist and stop; tie across the S4 cutoff → no population and stop; an S3-ineligible candidate in the top two stays ineligible), probe trigger, halt flag, lifecycle-evidence verification (and its refusals: inference-marked event, missing/extra unload, prompt in an unload, model still resident, unload before the last call, run-id mismatch, proposer count ≠ plan), record/plan mismatch refusals; the isolation guards. B covers the shadow-schema identity, V1.25
scoring parity, request parity, and that the synthetic tooling fixtures (13 hand-authored non-evaluation entries, never copied or
transformed from either corpus) are disjoint from **both** corpora under rules P1–P7 (and that the check does flag a copied entry).
Also green, unchanged: the V1.27 protocol/freeze tests (one stale static guard amended, §6.1), the V1.28 S1 tests, the V1.22/V1.23A/
V1.25 suites, the V1.17 harness test, `scripts/test_intelligence_safety.sh`, and the V1.27 freeze script (canonical manifest hash
`fa5c3110…` still reproduces). `swiftlint --strict` is clean on every new/changed Swift file. The live runner and analyzer were
type-checked, not executed. `./build.sh unsigned` was not re-run (no `Sources/` change).

## 6. Protocol ambiguities, defects and architect rulings (pre-exposure, before the S2 freeze)

Defect found and amended: **(D1) stale V1.27 test guard.** `IntelligenceV1ComparisonProtocolTests` refused any
`scripts/*comparison*run*` file ("S2 is a later milestone"). It is not in the freeze manifest (which hashes the artifacts and
the five `ComparisonProtocol` sources); it now allows exactly `intelligence_v1_comparison_s3_run.sh`. No frozen artifact changed.

Rulings on points the protocol left implicit (implemented in `ComparisonAnalysis`/`ComparisonScoring`, fixed before any inference):

1. **G1 denominators (accepted as implemented).** "Responses" = calls that returned a response (no provider failure, no preflight
   failure). Tool engagement = responses containing the expected tool name / responses. Strict-parser compliance = responses with
   exactly one correctly-named tool call that the strict parser accepted / responses with exactly one correctly-named tool call.
   Pass = numerator × 100 ≥ denominator × 95; an empty denominator fails. G2 counts provider failures over the screening pass;
   preflight failures (model-independent) are reported separately.
2. **Audit disagreement (accepted).** An audited entry disagrees iff the trial kind, the ordered per-edit disposition buckets, or
   the autonomous outcome state differ between the screening attempt and the audit attempt. Raw-text-only differences are reported
   separately as `rawOutputDiffers` and are not disagreements. Two or more disagreements for a model stop the experiment before S5.
3. **Span width (accepted, report-only).** minimal / whole-sentence / whole-text; the sentence splitter ends a sentence after
   `.`/`?`/`!` followed by whitespace, so an abbreviation such as "Rs. 5" can split a sentence — a known, accepted limitation of a
   metric that feeds no gate, stop, ranking or selection.
4. **Ranking has only the four V1.27 keys** (complete count ↓, punctuation non-empty ↓, calls > 30 s ↑, on-disk bytes ↑). Registry
   order is **not** a tie-breaker; it only orders tied candidates for deterministic presentation. An exact tie after all four keys
   stays unresolved: if it is for first place, **no finalist is selected** and the run stops for review (`finalistTie`,
   `reviewStops`, `haltBeforeS5`).
5. **S4 "top two"** = the two best screened **non-baseline** candidates by the same four keys, **regardless of G1–G3/A1
   eligibility**; S4 results can never rehabilitate an S3-ineligible candidate (eligibility is final at S3). An exact tie straddling
   the cutoff (2nd vs 3rd) is not broken: the population is left empty, `probeCutoffTie` lists the tied candidates, and the run stops
   for review. A tie wholly inside the top two does not straddle the cutoff.
6. **Cold-start latency is kept; there is no warm-up.** The first call of a candidate includes any model load and counts toward its
   latency, the 60 s limit, G2 and "calls above 30 s".
7. **Lifecycle/unload evidence (§4).** Between candidates the runner sends `POST /api/generate` `{"keep_alive":0,"model":<tag>}` with
   no prompt. It is recorded only in `lifecycle.jsonl`, never as a proposer record.

Remaining limits (unchanged): `LLMClient` exposes no HTTP body, finish reason or token usage, so "raw" means provider-returned content,
thinking and raw tool-call argument text; candidates' params-layer defaults other than `temperature` apply as recorded in S1; nothing is tuned.

## 7. S3 invocation (not executed)

After this milestone is committed (the runner requires a clean tree) and the architect approves the plan hash, and with Ollama
started by the Product Owner (`ollama serve`; the runner never starts it):

```
scripts/intelligence_v1_comparison_s3_run.sh --preflight-only --execute-plan 472f3807e47d904cbbf0d83c70cd679f45c0efde17c4e611579241bb58651e58 --out ~/pratilekh-v129-s3-results
scripts/intelligence_v1_comparison_s3_run.sh --execute-plan 472f3807e47d904cbbf0d83c70cd679f45c0efde17c4e611579241bb58651e58 --out ~/pratilekh-v129-s3-results
scripts/intelligence_v1_comparison_s3_analyze.sh --records <run dir>/records.jsonl --lifecycle <run dir>/lifecycle.jsonl --write <run dir>/report.md
```

The proposed plan hash for the finalized S2 state is `472f3807e47d904cbbf0d83c70cd679f45c0efde17c4e611579241bb58651e58`; `scripts/test_intelligence_v1_comparison_s2.sh --write-plan` regenerates it, and any edit to a hashed input changes it.

## 8. Not done / not authorized

No candidate run, no screening, no S4 runner, no finalist freeze, no benchmark access, no PO-2/PO-3 resolution, no prompt/contract
tuning, no production Intelligence change, no integration. S3 needs its own explicit authorization.
