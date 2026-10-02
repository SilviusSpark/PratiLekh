# Intelligence V1.27 — Model Comparison Development Corpus & Protocol

**Pre-registration / freeze milestone.** Baseline: `main` at `d163bd0f29d52a4c7e473693f53a79b87e3f6044`.
No model was run, no model was downloaded, no candidate was executed, and the frozen 44-entry
V1.23 benchmark was **not** exposed to any model. No production Intelligence, V1.21 contract,
V1.23/V1.25 artifact or frozen corpus changed. This document is the human-readable protocol; the
machine-readable frozen artifacts are in `Evaluation/References/intelligence-v1-comparison-dev/`
and are content-addressed by `FREEZE_MANIFEST.json`.

## 1. Frozen artifacts

| Artifact | Purpose |
|---|---|
| `corpus.json` | development corpus (66 entries), pinned in `ComparisonCorpus.frozenSHA256` |
| `hazard_fixture.json` | 21 stored hazard/negative/positive proposals replayed with no model |
| `candidates.json` | candidate/configuration registry and request parameters |
| `contract_variant.json` | baseline contract identity and the single pre-registered variant |
| `protocol.json` | stages, freeze boundaries, metrics, gates, advancement, run-count decision, unresolved decisions |
| `FREEZE_MANIFEST.json` | SHA-256 of every artifact and of the checking tooling; overlap-check summary |

Tooling: `Evaluation/Intelligence/ComparisonProtocol/` (corpus loader, overlap checker, fixture replay,
freeze/manifest, runner), `scripts/intelligence_v1_comparison_freeze.sh`,
`scripts/test_intelligence_v1_comparison_protocol.sh`, `Tests/IntelligenceV1ComparisonProtocolTests.swift`.
Once committed, these artifacts are **immutable** for the subsequent comparison experiment (section 9). Any
change to a frozen artifact or to the tooling changes the manifest and fails a test.

## 2. Development corpus

**Size and composition: 66 synthetic entries** (1.5× the 44-entry benchmark), driven by the V1.23/V1.26
failure modes rather than by convenience:

| Category | n | Why |
|---|---|---|
| punctuation-correction-warranted | 10 | the largest observed failure (0/17 punctuation trials so far): 6 terminal periods, 2 commas, 2 question marks |
| capitalization-correction-warranted | 8 | name capitalization was inconsistent across sentences: 5 names, 3 place/court names |
| whitespace-correction-warranted | 6 | isolated run-together words abstained in V1.23 |
| multi-edit-correction-warranted | 8 | independent corrections incl. two **triples** so partial outcomes can occur (none did in V1.23) |
| multi-sentence-correction-warranted | 6 | V1.25 limitation: single-sentence texts cannot separate whole-text, whole-sentence and minimal spans |
| clean-control | 12 | matched minimal pairs (each folds to a warranted entry's corrected text; tested) |
| hazard (6 types × 2) | 12 | model-eliciting bait for resolved span, intra-token, merge, acronym, digit-case, protected numeric |
| ambiguous (manual) | 4 | reported raw, never auto-scored |

Scored entries 62 (38 correction-warranted with 50 individual corrections, 12 controls + 12 hazards expecting
no change); manual 4. **Size justification:** the corpus can resolve only large effects (for a 10-entry
category, 0/10 vs 5/10 is distinguishable, Fisher exact p ≈ 0.03; 0/10 vs 3/10 is not), which is what a
screening stage for elimination needs; punctuation is oversampled because it is the dominant discriminating
failure. It is not sized for fine ranking or production-readiness claims.

**Validated against production code (test):** each entry's premise holds in the real pipeline — hazard
categories produce the intended protected spans, all other entries carry zero protected spans and are
unchanged by legal normalization, every expected correction occurs exactly once and non-overlapping, and
feeding the ground truth back through the real chain is autonomously accepted and yields exactly the fully
corrected text (a deterministic ceiling, so no entry is unattainable by construction).

## 3. Overlap / contamination check

**Prohibited overlap** between any development subject (entry or fixture text) and any frozen entry:

| Rule | Prohibited |
|---|---|
| P1 | exact raw-text equality |
| P2 | equality after folding (lower-case, non-alphanumeric runs → one space) |
| P3 | an expected correction `(source, replacement)` exactly equal to a frozen pair |
| P4 | reuse of a frozen personal-name token (tokens of every frozen capitalization-only name correction) |
| P5 | any shared run of four consecutive folded words |
| P6 | near-duplication: normalized edit similarity of folded texts ≥ 0.80 |
| P7 | reuse of a frozen digit-bearing token (identifiers, amounts, dates, numbers) |

**Allowed:** shared domain vocabulary (statute acronyms, ordinary legal words, sentence frames under four
words). Development-internal checks: identical raw text anywhere, or identical folded text within the same
expectation group (a warranted entry and its control are an intentional minimal pair).

**Result at freeze: 0 violations across 87 subjects (66 entries + 21 fixture texts) × 44 frozen entries; 0
internal duplicates.** Each rule is shown by test to fire on an injected violation, and on the real
benchmark (a copied frozen text; a reused frozen name). During authoring the checker caught two genuine
collisions before the freeze — a near-duplicate (P6) and a shared correction pair `court → court.` (P3) —
which were fixed in the unfrozen corpus; its first internal-duplicate rule also wrongly flagged minimal
pairs and was refined. The frozen benchmark is read by exactly two files (`ComparisonFreeze`,
`ComparisonFreezeRunner`), only through its pinned loader and only for this text-level check (static guard).

## 4. Stored hazard-edit fixtures (model-independent containment)

V1.23's model proposed none of the hazard edits, so safeguards went unexercised by candidates. 21 stored
proposals are replayed through the real, unmodified chain: 12 hazards (one per hazard entry), 5 general
negatives (lexical rewrite, hallucinated quote, no-op, combined wide edit, overlapping pair) and 4 positive
controls that must be autonomously accepted (so containment is not blanket rejection). **Result: 21/21 as
documented; no hazard or negative is autonomously accepted.** Expectations come from the documented rules;
two were initially too narrow (naming only gate rule P-B for apostrophe/slash removal, where the routine-
punctuation allowlist P-A also applies and is reported first) and were corrected to accept either rule
before the freeze.

## 5. Candidate / configuration registry

Request parameters: parity with V1.23 (stream false, temperature 0, `tool_choice` auto, 60 s limit,
`maxRetries` 1), one model resident, Ollama 0.34.4. Per-model settings that cannot be avoided (e.g. a thinking
switch) require a pre-registered amendment before inference.

| Id | Tag | Role | Identity status |
|---|---|---|---|
| CAND-BASE | `granite4:3b` | baseline control | fully pinned (V1.23A: manifest `89962fcc…`, GGUF `6c026838…`, template, config) |
| CAND-001 | `granite4.1:3b` | same-family successor | registry-observed, not pulled |
| CAND-002 | `qwen3:4b-instruct-2507-q4_K_M` | strongest non-thinking dense candidate | registry-observed, not pulled; params layer (119 B) |
| CAND-003 | `phi4-mini:latest` | different family, in the V1.3C ladder | registry-observed, not pulled; mutable tag |
| CAND-004 | `ministral-3:3b` | Mistral-family edge model | registry-observed, not pulled; params layer (21 B), vision weights |
| CAND-OPT-001 | `qwen3.5:4b` | optional wave 2 | not registered (thinking on by default) |

**Verifiability:** the baseline is verified from local files. For the others only the registry's small
manifest JSON (config/layer digests and sizes) was read — no weights downloaded. Because the fetch tool
transcribes text, its transcription was **control-validated**: the fetched `granite4:3b` manifest matched
the locally pinned digests and sizes exactly. Local manifest digests stay `null` until an authorized pull,
which must reproduce the registry-observed model-layer digest or the stage halts (`phi4-mini:latest` is a
mutable tag, so this check is what freezes it). The `params` layers set default sampling options the harness
does not send; their contents (behind signed third-party redirects) were deliberately not fetched and must be
recorded at pull time and frozen, never tuned. Exclusions (gemma4, ≥ 7B, gemma3:4b, llama3.2, qwen2.5:1.5b,
granite4:350m) are recorded with reasons. Every candidate's license and license source are recorded (all four
primary candidates are Apache-2.0 or MIT); a license must be acceptable for the intended use before any
production adoption (PO-4). Multimodal packaging (ministral-3 includes vision weights) is not exclusionary if
text-only execution fits locally; its resource cost is recorded. Candidate digests and params-layer contents
observed at S1 go into a new stage artifact; `candidates.json` is not edited.

## 6. Baseline and contract variant

**Baseline for every stage: the unchanged V1.21 production contract** (instructions `249ebb6a…`, tool
definition `d7a7cc23…`).

**Variant decision: one variant, `V-balanced-abstention`, justified by evidence, used only in the
conditional probe.** Exact change: replace the single sentence

> Prefer proposing zero edits (an empty "edits" array) when nothing clearly needs changing.

with

> Propose every clearly needed edit in these three categories (missing or wrong punctuation, capitalization, or whitespace); propose zero edits (an empty "edits" array) only when the text needs no such change.

Resulting instructions hash `b6a8575f…` (pre-registered; test reconstructs it from the production string:
the sentence occurs exactly once, nothing else differs, the `schemaVersion` sentence is kept, tool definition,
schema and parser are unchanged). **Evidence:** 11 of 14 non-complete V1.23 warranted entries were
abstentions; punctuation 0/17 across V1.20 and V1.23; V1.19's one-sentence change moved the non-empty rate on
identical fixtures from 15/15 to 0/30; V1.21 states the abstention preference twice. **Hypothesis** and its
**limitations** are fixed in `contract_variant.json`: the tool description (part of the tool-definition hash)
still says "Prefer proposing zero edits" and is deliberately left unchanged, so a null result does not exclude
a tool-description effect; the evidence is from one model; no second variant may be introduced after any
inference without a new pre-registration and a new development corpus.

## 7. Metrics, gates and advancement

**Four separate metric groups, raw counts with denominators, no blended score:** (1) protocol and provider
(tool engagement, strict-parser compliance, provider failures never retried, latency, loaded size/processor);
(2) edit-form adherence (exact expected-pair matches / U0 reference, span width minimal vs whole-sentence vs
whole-text, optional-field use); (3) outcome correctness (V1.25 outcome states, non-empty rate by category,
complete-outcome and per-correction counts, U1, abstention on controls/hazards); (4) deterministic
containment / runtime safety (dispositions split by licensed vs not, U2/U3, hazard-fixture replay, manual
entries reviewed by a human).

**Objective hard gates (all required):** G1 strict-parser compliance ≥ 0.95 and tool engagement ≥ 0.95
(baseline V1.23: 43/44, 44/44); G2 **zero provider/runtime failures** on the full pass; G3 U1 = U2 = U3 = 0
(zero-tolerance for foreign outcomes), every hazard fixture contained, zero foreign outcomes on
controls/hazards. **GPU/CPU placement, loaded size, memory and per-call latency are not gates**: they are
recorded separately for every candidate as observations for the later PO-3 assessment. **U0 (exact-pair
autonomous violations) is report-only** and is not an advancement gate.

**Advancement (relative to the baseline measured in the same stage):** eligible = G1–G3 and
complete-outcome count ≥ baseline + 5 of the 38 warranted entries with exact McNemar two-sided p < 0.10.
These are screening conventions chosen before any data, not production thresholds. Ranking is
lexicographic, never blended: complete count, punctuation non-empty rate, calls above 30 s, on-disk size.
At most one finalist; none if no candidate is eligible. **Contract probe trigger:** baseline non-empty rate on
scored warranted entries < 0.50 (V1.23 reference 8/18). **Probe models:** baseline + top two screened.
Probe readings (formulation effect, interaction, capability limit) are descriptive labels, not decisions.

**Product Owner decisions.** *Resolved:* **PO-1** U0 is report-only, not an advancement gate; **PO-4**
multimodal packaging is not exclusionary if text-only execution fits locally (resource cost recorded), and each
candidate's license is recorded and must be acceptable for the intended use before production adoption;
**PO-5** U1/foreign outcomes stay zero-tolerance under G3. *Unresolved:* **PO-2** the minimum absolute
usefulness for any production use (no finalist is a production-readiness claim); **PO-3** production
latency and memory/resource thresholds (only observations are recorded).

## 8. One run or repeated runs?

**Decision (exactly):** **one full screening pass per model, plus one fixed 12-entry second-attempt audit per
model.** *Variance question:* are temperature-0 outputs reproducible for identical requests in this runtime?
Sampling variance is expected to be near zero; the dominant uncertainty is finite-corpus (entry) variance,
which repeating the same entries cannot reduce, and advancement is paired entry by entry. *Audit:* 12 fixed,
stratified entries (listed in `protocol.json`) are re-run once per model in the same configuration. **Any
disagreement (disposition bucket or outcome state) is reported as nondeterminism. Observed outputs never
trigger additional screening passes.** If material nondeterminism appears (flag: two or more of the 12 entries
disagree for a model), the experiment **stops before finalist selection (S5) for architectural review.**
*Cost (informational, not a commitment):* 330 screening calls + 60 audit calls (≈ 390), probe up to 198, at
≈ 2 s/call for the baseline in V1.23 (larger models slower), plus ≈ 10 GB of downloads. *Contamination:*
repeats on the development corpus cannot contaminate the frozen benchmark, but repeated inspection raises the
pull to adapt the protocol, which the single variant, the no-automatic-escalation rule and the amendment rule
remove. The confirmation run keeps V1.23's rule: one attempt per entry, no repeats.

## 9. Stages and freeze boundaries

S0 freeze (this milestone, **FB0**) → S1 candidate acquisition and identity verification (explicit
authorization for downloads, **FB1**) → S2 execution tooling for the development corpus, unable to read the
frozen benchmark (**FB2**) → S3 screening, single pass + audit (**FB3**) → S4 conditional contract probe
(**FB4**) → S5 finalist freeze (**FB5**) → S6 confirmation. No stage before S3 involves inference.

**Frozen benchmark rules:** forbidden for candidate screening, contract development, variant development,
selection and tuning; usable only by **one fully frozen finalist, once**, in a separately authorized
confirmation milestone through the committed V1.23A runner and manifest procedure; the configuration cannot
change after seeing the result; any later iteration needs a new confirmatory corpus. **Amendments:** a
change after FB0 is a new, separately hashed document written *before* any inference of the stage it affects
and without reference to that stage's observed results; frozen artifacts are never edited; a change made after
observing results invalidates that stage for selection; the frozen benchmark can never justify an amendment.

**Immutability.** Once V1.27 is committed, the development corpus and every frozen protocol artifact
(`corpus.json`, `hazard_fixture.json`, `candidates.json`, `contract_variant.json`, `protocol.json`, as hashed
in `FREEZE_MANIFEST.json`) are immutable for the subsequent comparison experiment. Any defect discovered
after candidate exposure — an authoring error, an ambiguous premise, a stale assumption — is **disclosed and
qualified in that stage's report, never silently repaired**; correcting it requires a new, separately
pre-registered revision (new corpus hash, reported as such) that does not retroactively change what an
already-reported result was measured against.

## 10. Validation performed (offline)
Corpus pin/composition/tamper refusal; real-pipeline premises and deterministic ceiling for all 66 entries;
each overlap rule fires on injection, and the real development material has 0 violations against the real
frozen benchmark; 21/21 hazard fixtures contained, with detectors proven to fire; contract baseline hash and
variant reconstruction; candidate registry (baseline pinned to V1.23A, no fabricated local digests, license
set); protocol structure (stage order, no inference before S3, frozen-benchmark prohibitions, four metric
groups, unresolved decisions) — each also shown to fail under tampering; manifest determinism and drift guard;
the architectural decisions are enforced (no GPU gate, U0 report-only, zero-tolerance G3, one audit with no
automatic extra passes, PO resolutions, immutability clause, license recorded) and each is refused under
tampering; static guards (no provider/network symbols; frozen benchmark read by two files only; no execution
tooling).

## 11. What V1.27 does not establish
It makes no claim about any candidate's quality (none was run); the development corpus, like the benchmark, is
synthetic and small; the registry digests are registry-observed, not locally verified, until S1; advancement
margins are screening conventions, and absolute usefulness remains a Product Owner decision.
