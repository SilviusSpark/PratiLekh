# Intelligence V1.30 — S3 findings and post-hoc analysis

**No inference in this milestone.** The S3 run (V1.29, plan `472f3807…`, HEAD `7da97bad…`) is immutable evidence. Nothing was
re-run, S4 was not run, the V1.23 benchmark was not touched, no contract/prompt was tuned and no production Intelligence behavior
changed. Part A is the preregistered record (what S3 measured, by the frozen rules). Part B is **post-hoc explanatory analysis:
non-preregistered and non-scoring** — it re-labels, re-ranks and re-classifies nothing.

## A. Preserved and verified evidence

`Evaluation/Intelligence/V1_30_S3_RESULTS/` (files copied byte-for-byte from the run directory, hashed in `SHA256SUMS`):
`records.jsonl` (390 proposer records), `lifecycle.jsonl` (18 non-proposer events), `plan.json`, `run_info.json`, `report.md` (the
committed analyzer's output), `server_requests.log` (only the Ollama `[GIN]` request lines of the run — all other server output,
which contains machine paths, is deliberately omitted), and `posthoc_entries.json` (derived by `scripts/intelligence_v1_s3_posthoc.sh`).
No private path appears in any copied file.

`scripts/verify_intelligence_v1_s3_evidence.sh` independently verifies (and passes): every hash; `plan.json` is byte-identical to the
committed `S3_PROPOSED_RUN_PLAN.json` and `run_info.json` names the approved hash `472f3807…`; the 390 records are exactly the plan's
steps 1–390 in one run, development-corpus evidence only, baseline contract (`249ebb6a…`, tool `d7a7cc23…`, corpus `e164297e…`); the
committed analyzer, run on the stored `records.jsonl` + `lifecycle.jsonl`, reproduces `report.md` (lifecycle verification passes: 5
unloads, one per candidate, `keep_alive` 0, no prompt, each followed by an empty process list); the server saw exactly 390
`/v1/chat/completions` and 5 `/api/generate` requests (the 5 unloads) — i.e. no inference outside the 390 planned calls.

**One cosmetic tooling defect, disclosed not fixed (the S2 inputs are frozen):** `ComparisonAnalysis` prints the "addressing
rejections" dictionary in arbitrary key order, so re-running the analyzer yields a `report.md` that differs on that one line (same
counts). The verifier compares that line as a sorted set and every other line verbatim. No count, gate or ranking is affected.

### Preregistered results (as reported by the frozen analyzer; unchanged)

| Model | G1 | G2 | G3 | complete /38 | partial | per-correction /50 | non-empty warranted /38 | punctuation non-empty /10 | A1 |
|---|---|---|---|---|---|---|---|---|---|
| `granite4:3b` (baseline) | pass | pass | **fail** (U1=2) | 7 | 3 | 2 | 22 | 2 | — |
| `granite4.1:3b` | **fail** (62/66 engagement) | pass | **fail** (U1=5) | 3 | 3 | 2 | 17 | 3 | fail (p=0.125) |
| `qwen3:4b-instruct-2507-q4_K_M` | **fail** (36/66) | pass | pass | 0 | 0 | 0 | 0 | 0 | fail (p=0.0156) |
| `phi4-mini:latest` | **fail** (0/66) | pass | pass | 0 | 0 | 0 | 0 | 0 | fail (p=0.0156) |
| `ministral-3:3b` | **fail** (4/63) | **fail** (3 provider failures) | **fail** (U1=1) | 0 | 0 | 0 | 3 | 0 | fail (p=0.0156) |

U2 = U3 = 0 for every model; all 21 stored hazard fixtures were contained; correct abstention on the 24 controls+hazards was 24/24
for four models and 22/24 for `ministral-3:3b`. The fixed 12-entry audit had **0 disagreements for every model** (`haltBeforeS5` not
set; no review stops). **No candidate is eligible; there is no finalist; there is no tie.** The S4 probe trigger did **not** fire
(baseline non-empty rate 22/38 ≈ 0.58 ≥ 0.50), so its population is empty and S4 was not run. Latency/resource (report-only): the
first call of each model was its slowest (8.8–11.3 s, cold load included, no call > 30 s afterwards or at all); medians 1.1–2.4 s; every model
loaded fully on the GPU (loaded sizes 2.50–3.18 GB). PO-2 and PO-3 remain unresolved.

## B. Post-hoc explanatory analysis (NON-PREREGISTERED, NON-SCORING)

Method: `scripts/intelligence_v1_s3_posthoc.sh` re-derives each record's journey with the committed scoring chain and prints it
(`posthoc_entries.json`). For each topic: **(1)** model proposal, **(2)** parser/protocol, **(3)** deterministic
addressing/permission/Safety Authority, **(4)** resulting classification. These observations explain; they do not change an S3
classification and do not show that any alternative contract, prompt, ground truth or model would have done better.

### B1. Baseline U1 cases (`DEV-WS-005`, `DEV-MULTI-003`) — why zero-tolerance fired

- **`DEV-WS-005`** (`the registrar returnedthe file to counsel`; licensed: `returnedthe`→`returned the`). (1) The model proposed two
  capitalizations — `the registrar returned`→`the Registrar returned` and `the file to counsel`→`the file to Counsel` — and **never the
  licensed whitespace split**. (2) Valid schema-conforming call. (3) Both resolved by unique source and were classified
  capitalization-only and **autonomously accepted** (no protected span, no gate rule applies to ordinary capitalization). (4) Final text
  `the Registrar returnedthe file to Counsel` ∉ L(entry) → `foreign`, U1.
- **`DEV-MULTI-003`** (`however kishore mohanty did not appear`; licensed: `however`→`however,` and `kishore mohanty`→`Kishore Mohanty`).
  (1) One edit, `however`→`However`. (2) Valid. (3) Capitalization-only, autonomously accepted. (4) `However kishore mohanty…` ∉ L → `foreign`.
- **What this shows:** both U1 outcomes are *edit-form-plausible surface edits that the narrow ground truth does not license* (a
  sentence-initial capital; a title capital), made autonomously because the deterministic safeguards cover protected content and
  edit *category*, not "is this correction licensed by this corpus". The classification is correct by the frozen rule (U1 is relative to
  the licensed set) and PO-5 keeps it zero-tolerance. It is **not** evidence of a safeguard defect: no protected span was touched
  (U2=U3=0). Whether such capitalizations are acceptable product behavior is a Product Owner question this evidence cannot answer.

### B2. Baseline U0 pattern (11 exact-pair violations, report-only)

Of the 11 scored autonomous edits matching no expected pair, **8 are outcome-compatible** with the licensed set (they produce text in
L): wider-than-expected spans that yield the licensed result — e.g. `the incident took place near cuttack`→`…Cuttack` for the licensed
`cuttack`→`Cuttack` (`DEV-CAP-006`, `DEV-CAP-008`), `the noticewas served personally`→`the notice was served personally`
(`DEV-WS-001`, `-004`), `DEV-MSENT-003`, `DEV-MSENT-004` and the partial `DEV-MULTI-002`, `DEV-MSENT-005`. The other **3 are the U1 edits above**.
Only 2 of the baseline's autonomous edits (`DEV-WS-006`, `DEV-MULTI-004`) were exact pairs. Span-width tallies: minimal 11,
whole-sentence 4, whole-text 7. So U0 mostly measures *edit form* (the V1.21 "smallest span" instruction is followed unevenly), not
outcome damage — exactly the V1.24 form-vs-outcome distinction, now with a second dataset.

### B3. Autonomous edits on manual entries (not scored; for human review)

- **`DEV-AMBIG-004` (baseline):** `the witness said no he was not there`→`…said no, he was not there` (whole-sentence span, punctuation-only,
  autonomously accepted). A plausible comma, but the entry is manual precisely because the intended reading is ambiguous
  (“no he was not there” vs “no, he was not there”); the edit resolves the ambiguity in one direction autonomously.
- **`DEV-AMBIG-001` (`granite4.1:3b`):** `the arguments were concluded the judgment was reserved`→`…concluded The Judgment was reserved`
  (two capitalization-only edits, resolved by context-only and corroborated-unique-source addressing, both autonomously accepted). The
  intended boundary (`concluded. The judgment…` vs a capitalized noun phrase) is the ambiguity; the edit capitalizes "Judgment" as if a
  proper noun, which is unlikely under either reading but is a judgment for the reviewer. Human review is required before any safety conclusion on either.
- Both are real model proposals that the deterministic gate treats as ordinary surface edits; the manual-entry design correctly
  excluded them from automatic scoring.

### B4. Granite 4.0 vs 4.1

- **Proposals (1):** 4.0 proposed edits on 29 entries (edit dispositions: 16 addressing-rejected, 14 autonomously accepted, 7
  Safety-rejected, 1 review-only); 4.1 on 23 entries (7 / 13 / 5 / 1). 4.1 follows the minimal-span instruction better (18 minimal, 0
  whole-sentence, 1 whole-text, versus 11 / 4 / 7) but does not exceed 4.0's complete count in any category (4.0 vs 4.1: capitalization 2 vs 0,
  whitespace 3 vs 2, multi-sentence 2 vs 1, punctuation 0 vs 0, multi-edit 0 vs 0); it proposed on punctuation entries slightly more often
  (3/10 vs 2/10). Over the 62 scored non-manual entries the paired outcomes were: 45 unchanged/unchanged, 3 complete→complete,
  3 complete→unchanged, 1 complete→foreign, 2 partial→unchanged, 1 partial→partial, 2 unchanged→partial, 3 unchanged→foreign,
  1 foreign→unchanged, 1 foreign→foreign.
- **Protocol (2):** 4.1 returned **no tool call and empty text on 4 entries** (`DEV-WS-002`, `-MSENT-001`, `-MSENT-005`, `-CTRL-011`),
  failing G1 engagement (62/66) although parser compliance was perfect when it did call (62/62). 4.0 had 66/66 and 66/66.
- **Deterministic layer (3):** 4.0's context fields (19 context uses) were frequently inconsistent with the source: 12
  `contextMatchesNoCandidate` + 4 occurrence rejections out of 16 addressing rejections, **none** of whose literal pairs equals an
  expected pair; 4.1 had 7 such rejections and one rejected edit whose literal pair was an expected pair. Safety rejections were
  mostly `noOpProposal` (replacement equal to source: 6 for 4.0).
- **U1 (4):** 4.1's five U1 edits are of the B1 kind plus two with visible defects: `DEV-MSENT-002` `he denied`→`he denied ` (a
  *trailing space added* — whitespace-only, so autonomously accepted — leaving a double space, not the licensed capital) and
  `DEV-MSENT-004` `The report`→`The Report` (capitalizes instead of splitting `reportwas`); plus `DEV-PUNC-007` (period at the end of the
  sentence where the licensed correction is a comma after `sides`) and `DEV-CAP-003` (a whole-sentence capitalization including
  `Counsel`). **Reading:** 4.1 is not an improvement over 4.0 on this corpus (3 vs 7 complete; paired McNemar p=0.125) and it adds a
  tool-engagement failure; the data do not show why (different family member, different sampling defaults and template are
  confounds that S3 did not isolate).

### B5. Qwen3-instruct and Phi4-mini non-engagement

- **`qwen3:4b-instruct`:** (1) never proposed an edit: on the 36 responses where it called the tool, every call was the empty
  proposal `{"edits":[],"schemaVersion":1}` (key-sorted by the runtime); on the other 30 it answered with the bare text `[]` and no tool
  call. (2) Those 30 are whole-response rejections (`unexpectedTextContent`) — counted against engagement (36/66), though the strict
  parser accepted all 36 calls. (3) Nothing reached addressing or the Safety Authority. (4) All outcomes `unchanged`; 24/24 correct
  abstention is therefore vacuous (it abstains from everything). Engagement was independent of category (it engaged on both warranted and clean entries).
- **`phi4-mini`:** (1) answered in plain text on 66/66. On 57 it returned a rewritten sentence — on 33 of 38 warranted entries the text
  differs from the input (e.g. `DEV-PUNC-001` → `the petition was dismissed for want of prosecution.`), i.e. the model often *did
  recognize a correction* but expressed it as free text; on 9 it printed a pseudo-tool-call (`sourceText: …\nreplacementText: …`). 20 of 66
  texts equal the input. (2) Every response failed the "expected tool call" policy (0/66 engagement). (3) Nothing reached addressing. (4) All
  `unchanged`. **Not established:** that a different framing would make it comply (V1.3B found the same class of non-engagement for another
  small model); S3 tested only the frozen V1.21 contract.

### B6. Ministral protocol/provider failures

- (1) On 59 responses it put the **correct JSON payload in the message text** (`{"schemaVersion":1,"edits":[]}`) instead of calling the tool
  — right schema, wrong channel. On the 4 responses where it did call the tool it proposed edits on 3 (one to `DEV-CAP-002`,
  `The report was prepared by Kishore Mohanty`, a whole-text capitalization that is outside the licensed pair — the lone U1 — and one that
  injected markdown into the replacement, `submitted **his** report` (`DEV-WS-006`, rejected by the Safety Authority as an unsupported edit category); a third, `he`→`He`, was
  addressing-rejected as ambiguous). (2) Three calls failed at the *runtime*, not the
  parser: HTTP 500 `tool 'propose_literal_transcript_eds' not found` (a **garbled tool name**, `DEV-PUNC-008`) and `tool 'schemaVersion' not found`
  (the model emitted the *field name* as the tool name, `DEV-CTRL-002`, `-008`). Those are provider/runtime failures by the protocol (G2),
  never retried. (3) Of its 3 proposed edits, addressing rejected 1, the Safety Authority rejected 1 and one was autonomously accepted (the U1 above). (4) 0 complete.
- Observed pattern: the model understands the payload but cannot reliably emit it through Ollama's tool-call channel; whether this is a model,
  template or runtime-parser issue is **not established** (S1 recorded that the `ministral-3` template renders tools and ships default
  sampling options; nothing here isolates the cause).

### B7. What 0/12 behavioral audit disagreements do and do not establish

- **Establish:** for each model, a second attempt on 12 stratified entries, immediately after its full pass, in the same resident
  session at temperature 0, gave the same trial kind, the same ordered disposition buckets and the same outcome state on all 12
  (60 pairs in total) — so on this evidence the *behavioral* classification of a response was reproducible, and the
  `haltBeforeS5` nondeterminism stop was not triggered.
- **Also observed, honestly:** raw output was not always byte-identical — 7 of 24 `granite` audit pairs (3 for 4.0, 4 for 4.1) differ only
  in JSON key order (`schemaVersion` first vs `edits` first), which the protocol's semantic comparator deliberately ignores; all 7 are
  canonically equal. So token-level output is not perfectly stable even at temperature 0, but nothing meaningful changed.
- **Do not establish:** determinism of the other 54 entries per model; stability across a fresh model load, another day, another
  Ollama build or another machine; independence of the two attempts (same warm context/runtime state); or any statement about the
  models' correctness. Twelve pairs cannot exclude a low-rate flip, and an always-empty model (Qwen, Phi) is trivially "stable".

## C. Conclusions

**What S3 establishes.** Under the frozen V1.21 contract, the registered runtime (Ollama 0.34.4), the 66-entry development corpus and the
frozen metrics: (i) no registered candidate was eligible and the baseline `granite4:3b` stays the best-performing model, with complete 7/38
but failing G3 because of two U1 edits; (ii) three of four candidates cannot reliably use the required tool-call channel under this contract
(Qwen 36/66 with only empty proposals, Phi 0/66, Ministral 4/63 plus runtime failures); (iii) the 4.1 successor is not better than 4.0 here;
(iv) the deterministic safeguards behaved as designed on real model output — U2=U3=0, every hazard contained, including the first
model-proposed protected-span edit (`Exhibit D14`→`Exhibit D-14`, review-only); (v) the behavioral audit was stable; (vi) the execution tooling
and lifecycle accounting worked end to end (390 records, 5 unloads, nothing else inferred).

**What S3 does not establish.** That any model is production-ready or unready beyond this contract and corpus (PO-2/PO-3 unresolved); why
any candidate failed (model, template, sampling defaults, runtime tool parser and the contract are confounded); that a different contract,
prompt, tool framing, ground truth or runtime would change an outcome (the single registered variant was never probed — the S4 trigger did not
fire); that the narrow ground truth is the right product standard for capitalization (B1); results on the V1.23 benchmark, on real
dictation, or beyond temperature 0; per-model stability beyond 12 entries.

**Is the V1.27 comparison sequence closed with no finalist?** Yes, as registered: S3 produced no eligible candidate, so S5 selects no
finalist, S4 did not trigger, and S6 (the one-shot benchmark confirmation, reserved for a frozen finalist) has no subject. The protocol is
closed; the benchmark remains unexposed. This closes the *comparison*, not the question of whether local post-dictation correction is viable.

**Evidence-supported candidate directions for the next investigation (none implemented; each needs its own authorization):**
1. **Model-independent calibration of what autonomy should license** (B1–B3): the U1 edits are plausible surface edits outside a narrow
   ground truth; a Product Owner decision on whether capitalization/comma additions of this kind are acceptable, informed by a
   non-model analysis of the ground-truth's coverage, would clarify whether the zero-tolerance bar or the corpus is the binding constraint.
2. **Tool-channel reliability as its own question** (B5, B6): two models produce correct-looking output in the wrong channel (Phi's rewritten
   sentence, Ministral's JSON-in-text). Separating "can the model produce the edit" from "can the runtime/template deliver a tool call" needs a
   pre-registered, contract-level or runtime-level experiment (including whether text-channel payloads should ever be parseable — a
   safety-architecture decision, not a convenience).
3. **Granite-family behavior** (B4): the baseline's strengths (whitespace/multi-sentence, 24/24 abstention) and weaknesses (punctuation 2/10,
   edit-form, context-field misuse) are specific enough to guide a Granite-only investigation of the span/context addressing fields.
4. Not supported by this evidence: more candidate screening against this corpus, reopening S4, or tuning on the development corpus without
   a new pre-registered confirmatory corpus (the corpus is now exposed to all five configurations).
