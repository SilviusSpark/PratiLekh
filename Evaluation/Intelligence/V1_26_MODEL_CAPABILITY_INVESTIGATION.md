# Intelligence V1.26 — Model Capability Investigation

**Investigation only.** Baseline: `main` at `847914b85059e159fcd06723026f459493a4c558`. No model
or Ollama inference was run, the frozen 44-entry benchmark was **not** exposed to any model, no
model was downloaded, and no production code, V1.21 contract, prompt, safeguard, corpus,
V1.23/V1.25 artifact or evaluation semantics changed. Structure: **A. Repository evidence →
B. Externally verified facts → C. Interpretation → D. Candidate shortlist → E. Proposed
experiment → F. What this does not establish.** Statements are labelled by provenance;
nothing in B is repository evidence and nothing in C/D/E is observed.

---

## A. Repository evidence

### A1. Why V1.23 reached only 4/18 complete warranted outcomes (from `V1_23_RESULTS/trials.json`)
The 14 non-complete warranted entries decompose exactly as follows:

| Cause | Entries | Count |
|---|---|---|
| Abstention (`edits: []`) | PUNC-001…006, WS-001…003, CAP-003, CAP-005 | **11** |
| Strict-parser rejection (omitted required `replacementText`) | MULTI-001 | 1 |
| Whole-sentence edit combining two corrections, rejected by the Authority as `unsupportedEditCategory` | MULTI-002 | 1 |
| Correct pair proposed, addressing-rejected (supplied `leftContext` did not match) | MULTI-003 | 1 |

Warranted-entry behavior by correction type (model proposals, any disposition):
- **Terminal period / comma:** 0 of 8 warranted entries needing a terminal period (PUNC-001/002/004/005/006,
  MULTI-001/003 endings) or the comma (PUNC-003) received a proposal. With V1.20's 0/9 punctuation
  trials (same instruction text), that is **0 of 17** punctuation-class trials across two runs.
- **Run-together words:** 2 of 5 entries containing one produced a split proposal (MULTI-002, MULTI-003);
  the 3 isolated cases (WS-001…003, `thewitness`, `beganpromptly`, `statementwas`) abstained.
- **Name capitalization:** the same names get opposite treatment in different sentences:
  `sita devi filed the complaint` → abstained, but `sita devi wasexamined…` and
  `ram das and sita devi appeared…` → proposed; `geeta rani …` abstained; `ram das`/`mohan lal` → proposed.
- **Edit form:** 7 of 9 edits that resolved addressing quote the whole text as `sourceText`, despite the
  V1.21 smallest-span instruction (V1.25 form adherence: 0/9 exact expected pairs).
- **Protocol:** 43/44 responses parsed; 44/44 engaged the tool; 0 provider failures.

### A2. Prior `granite4:3b` evidence in the repository
- **V1.3C (older, simplified tool, 11 fixtures):** the model made punctuation *deletion* and *insertion*
  edits in some fixtures (double comma removed; appositive commas added) but echoed the source unchanged
  for a missing-terminal-punctuation fixture; it silently "cleaned up" double spaces and an Odia string
  inside its own `sourceText` echo (3 of 11 non-literal quotes), and attempted one lexical rewrite.
- **V1.19 (same model, same schema, 5 short fixtures incl. "the accused was present in court"):** with the
  instruction text lacking one sentence (Arm A) **all 15 responses proposed an edit** (protocol-noncompliant:
  `schemaVersion` omitted); after adding the single sentence requiring `schemaVersion` (Arms B/C),
  **0 of 30 responses proposed any edit.** The raw per-call log was not preserved, so *which* edits Arm A
  proposed (e.g. whether punctuation) cannot be re-verified.
- **V1.20 (Arm B instructions = today's V1.21):** punctuation fixtures 0/9 non-empty; capitalization 6/6.
- **Earlier ladder (V1.3B/V1.3C):** `qwen2.5:1.5b` never engaged the tool for text-processing (0/15 framing
  matrix); `granite4:350m` engaged but omitted required fields (G4: 3/5). The planned continuation —
  Qwen3 1.7B, Qwen3 4B, Phi-4 Mini — was **never downloaded or tested** because the ladder stopped at
  `granite4:3b`. No other model has ever been run on the correction task.

### A3. Contract facts relevant to formulation
The V1.21 instructions and the tool description each state "Prefer proposing zero edits … when nothing
clearly needs changing"; they forbid changing any word/name/date/amount/statute/identifier; they require
literal quoting of the smallest span, a 1-based `occurrence` for repeats, optional `leftContext`/`rightContext`
that "must be copied exactly", no null/empty optional fields, and (since V1.21) an explicit
`schemaVersion` sentence. The edit is expressed as a literal source-quote plus replacement, not as a
corrected passage.

### A4. Environment (measured/recorded)
- Apple M1 **MacBook Air, 8 GB** unified memory; 47 GB free disk; Ollama 0.34.4 reported
  `total_vram="5.3 GiB"`, `default_num_ctx=4096`; V1.3C recorded only 65–130 MB unused memory during
  inference of a 2.5 GB resident model. Installed locally: `granite4:3b`, `granite4:350m`, `qwen2.5:1.5b`.

---

## B. Externally verified facts (fetched 2026-10-01; vendor/registry statements, not repository evidence)

| Model (Ollama tag) | Params | Ollama size | Context | Tools tag | License | Notes |
|---|---|---|---|---|---|---|
| `granite4:3b` ("micro") — baseline | 3.4B (GGUF) | 2.1 GB | 128K | yes | Apache 2.0 | released Oct 2025 |
| `granite4.1:3b` | 3B dense | 2.1 GB | 128K | yes | Apache 2.0 | released Apr 2026; HF card claims IFEval 82.3 %, BFCL v3 60.8 % (vendor-reported) and "improved post-training (SFT + RL)" |
| `qwen3:4b-instruct` (= `4b-instruct-2507`, q4_K_M) | 4.0B (3.6B non-embedding) | 2.5 GB | 256K | yes (family tag) | Apache 2.0 | non-thinking only; card recommends temperature 0.7 / top-p 0.8 / top-k 20 |
| `phi4-mini` | 3.8B | 2.5 GB | 128K | yes | MIT | function calling advertised; Ollama entry last updated ~1 year ago; needs Ollama ≥ 0.5.13 |
| `ministral-3:3b` | 3B | 3.0 GB | 256K | yes (+vision) | Apache 2.0 | needs Ollama ≥ 0.13.1; vision components included in size |
| `qwen3.5:4b` (optional) | 4B | 3.4 GB | 256K | yes (+vision, thinking) | Apache 2.0 | **thinking enabled by default** (disabled via `chat_template_kwargs`); ~7 months old |
| `qwen3.5:2b` (optional) | 2B | 2.7 GB | 256K | yes | (HF card checked for 4B only) | same thinking default |
| `llama3.2:3b` | 3B | 2.0 GB | 128K | yes | not verified this session (Meta's custom Llama community license, per prior knowledge) | Ollama entry ~2 years old |
| `gemma3:4b` | 4B | 3.3 GB | 128K | **not listed** | Gemma Terms of Use | cannot use the tool-calling contract as listed |
| `gemma4:e2b` / `e4b` | "effective" 2B/4B | 4.6–7.5 / 6.6–9.5 GB | 128K | function calling | not checked | smallest build exceeds this machine's ~5.3 GiB GPU budget |
| `qwen3:8b`, `granite4.1:8b`, `ministral-3:8b` | 8B | 5.2 / 5.3 / 6.0 GB | — | yes | — | exceed the practical budget on 8 GB |

Not externally verifiable in this session: any public benchmark of post-ASR *surface-edit* (punctuation /
capitalization / whitespace) capability for any candidate. Published IFEval/BFCL numbers (only checked for
`granite4.1:3b`) measure different abilities and are not evidence for this task.

Sources: [Ollama granite4](https://ollama.com/library/granite4), [granite4.1](https://ollama.com/library/granite4.1),
[qwen3](https://ollama.com/library/qwen3) / [tags](https://ollama.com/library/qwen3/tags),
[phi4-mini](https://ollama.com/library/phi4-mini), [ministral-3](https://ollama.com/library/ministral-3),
[qwen3.5](https://ollama.com/library/qwen3.5), [gemma3](https://ollama.com/library/gemma3),
[gemma4](https://ollama.com/library/gemma4), [llama3.2](https://ollama.com/library/llama3.2),
Ollama [tools filter](https://ollama.com/search?c=tools); Hugging Face cards:
[granite-4.1-3b](https://huggingface.co/ibm-granite/granite-4.1-3b),
[Qwen3-4B-Instruct-2507](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507),
[Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B),
[Phi-4-mini-instruct](https://huggingface.co/microsoft/Phi-4-mini-instruct).

---

## C. Interpretation

### C1. Capability vs. formulation vs. interaction
- **Evidence consistent with a model-capability limitation:** the whole-sentence `sourceText` habit (7/9 under V1.21; V1.3C's contract
  instructed whole-text echoes, so it is not comparable), non-literal quoting of whitespace/Indic text (V1.3C), a missing required field (MULTI-001),
  an incorrect `leftContext`, no-op proposals, and a lexical rewrite attempt all recur across different
  contracts and runs; the model also never produced a punctuation proposal in 17 correction-class trials
  under this instruction text. These are properties of a 3B-class model quantized to Q4_K_M and are not
  obviously fixable by wording.
- **Evidence consistent with a task/contract-formulation limitation:** the instructions twice prefer zero
  edits and forbid changing words, while the task being tested asks for *less common* edits (adding
  terminal punctuation to an unpunctuated fragment); the output format asks the model to quote literal
  source spans, the property it handles worst; optional context fields invite errors (MULTI-003); the
  corpus's unpunctuated lower-case fragments may read as normal dictation rather than errors. Nothing in
  the repository isolates any of these as a cause — none was varied.
- **Evidence of model × contract interaction (the strongest signal):** V1.19 changed one sentence and the
  non-empty rate on identical fixtures moved from 15/15 to 0/30; V1.3C's different, simpler contract
  (always return both fields, echo when unchanged) produced punctuation edits that V1.21 does not.
  Name capitalization flipping by sentence (A1) is further sensitivity to surface context at temperature 0.
- **Not determined:** whether a different contract would raise `granite4:3b`'s punctuation recall, whether
  other models of the same size class behave differently under the *unchanged* contract, and whether the
  abstention is a capability gap or a calibration/priors effect. These are separate questions that a
  design varying both factors can separate; the repository currently varies neither beyond the above.

### C2. Granite prompt work first, or model selection first?
**Model comparison first, with a single pre-registered contract probe included in the same controlled
experiment — not open-ended Granite prompt iteration.** Reasons: (1) only one model has ever been run on
the V1 correction contract and corpus, so no result can say how much of the 4/18 is Granite-specific; (2) the repository's own ladder
plan (Qwen3 4B, Phi-4 Mini) was never executed and a newer same-family model (`granite4.1:3b`, April 2026)
now exists as a cheap control; (3) the V1.19 evidence says contract wording matters, but tuning wording
on one weak model risks fitting the production contract to that model and consuming the benchmark's
held-out value; (4) a two-factor design (model × {frozen V1.21, one pre-registered variant}) answers the
capability/formulation/interaction question directly, whereas Granite-only prompting cannot.

---

## D. Candidate shortlist (8 GB M1, Ollama, strict tool-call contract)

Selection filters: tool-calling listed on Ollama; open weights with a permissive license verified in B;
≤ ~3.5 GB on disk at Q4 so one model fits the ~5.3 GiB GPU budget with the default 4096 context;
runs on the installed Ollama 0.34.4.

| Rank | Candidate | Role in the comparison | Why / risks |
|---|---|---|---|
| Control | `granite4:3b` | frozen baseline | already measured on V1.23; same quantization/digest pinned in V1.23A |
| 1 | `granite4.1:3b` | same-family successor | isolates "newer post-training" from "different family"; Apache 2.0; vendor-claimed IFEval/BFCL gains; same size/template conventions |
| 2 | `qwen3:4b-instruct` (2507) | strongest non-thinking dense small model candidate | Apache 2.0; non-thinking only (no thinking-handling confound); 2.5 GB; risk: card recommends sampling above temperature 0 — greedy decoding is a known degeneration risk, to be recorded not tuned |
| 3 | `phi4-mini` | different family; was in the repository's planned ladder | MIT; 3.8B; function calling advertised; older (≈ 1 year) |
| 4 | `ministral-3:3b` | Mistral-family edge model | Apache 2.0; 3.0 GB (vision components inflate size); needs Ollama ≥ 0.13.1 (already satisfied) |
| Optional wave 2 | `qwen3.5:4b` (or `2b`) | newest family | Apache 2.0 (4B checked); thinking on by default and vision weights make it a protocol/runtime confound; include only if wave 1 is inconclusive and a thinking-off setting is pre-registered |
| Excluded | `gemma4:e2b/e4b`, 8B-class models, `gemma3:4b`, `llama3.2:3b`, `qwen2.5:1.5b`, `granite4:350m` | — | size over budget; no tools tag; older/license unverified; or already failed the protocol gate (V1.3B/V1.3C) |

No candidate has verified post-ASR editing evidence (B); the ranking is by task-relevant *prerequisites*
(tool output, permissive license, fit), not by expected quality.

---

## E. Proposed controlled comparison (not implemented, not run)

**Principle:** the frozen 44-entry V1.23 benchmark is **unavailable to candidate screening and to
contract development**. It is never used for model selection, contract iteration or tuning. Only a
**frozen finalist** configuration (model, contract and parameters fixed and hashed beforehand) may later
receive **one** confirmatory run on it; any iteration after that run requires a new confirmatory corpus.
Development and screening use a separate, disjoint corpus.

**Next milestone (V1.27) is a freeze, not a run.** V1.27 performs **no model inference**. It should create
and freeze, and the architect should approve, before any candidate is exposed to anything:
1. **A disjoint development corpus.** New synthetic texts and names mirroring the V1.22 category structure,
   with its size decided and justified in V1.27 (not fixed here), frozen by SHA-256, with an automated test
   that no text or expected-correction source overlaps the frozen benchmark. It also includes a
   deterministic **stored-hazard-edit fixture** (known dangerous proposals replayed through the real chain
   with no model) to address V1.23's weak hazard exercise independently of model behavior.
2. **Candidate and configuration identities.** The final candidate list (from section D) with pinned
   Ollama manifest digests, runtime version and defaults, the unchanged V1.21 contract hash, and at most
   **one** pre-registered contract variant (instructions only; same schema and parser; one stated hypothesis;
   to be used only for the contract probe below). Obtaining digests may require model downloads
   (roughly 10 GB for the four primary candidates; 47 GB free); that needs explicit permission and is
   decided in V1.27.
3. **The comparison protocol.** Request parameters (parity with V1.23 unless a documented, pre-registered
   per-model setting such as a thinking switch is unavoidable), one-model-resident sequencing, the number of
   attempts per entry, and the stages below with their trigger conditions.
4. **Metrics and advancement criteria.** Fixed before inference; thresholds set by the architect, not invented
   here. Metrics stay separate and are never blended: protocol compliance and tool engagement; non-empty rate
   by category; outcome states and U1 (V1.24/V1.25 semantics); exact-pair U0 and edit-form adherence; correct
   abstention on controls and hazards; deterministic runtime-safety observations U2/U3; per-call latency and
   peak memory; provider failures. The unsafe-edit criteria stay hard (U0 reported as in V1.23; U1/U2/U3
   must be 0).
5. **A repeated-run decision, justified before inference.** Whether to repeat runs, and how many times, is an
   explicit protocol decision, not a default: V1.27 must state what variance question repeats would answer
   (e.g. whether temperature-0 outputs are reproducible in this runtime), why a single pass is or is not
   sufficient for the advancement criteria, and what the extra calls cost. V1.23's single-attempt benchmark
   rule does not automatically carry over to the development corpus, and neither does repetition.

**Subsequent stages (each separately authorized; scale determined by V1.27's pre-registration, not by this
document):**
- **Screen under the unchanged V1.21 contract:** the baseline and the frozen candidate list on the
  development corpus only.
- **Contract probe (conditional on a pre-registered trigger, e.g. abstention-dominated screening results):**
  the single pre-registered variant on the baseline and the top one or two screened models, same corpus and
  rules, yielding the model × contract comparison needed to separate capability, formulation and interaction.
- **Confirmation (one shot):** the frozen finalist runs once on the frozen benchmark via the committed V1.23A
  runner and manifest procedure, with `granite4:3b`'s existing V1.23 result as comparator and no change to
  the configuration after seeing the result.

---

## F. What this investigation does not establish
- Why `granite4:3b` abstains: no factor was varied; C1 lists hypotheses, not findings.
- That any candidate is better than `granite4:3b` on this task; external model facts concern size, license
  and advertised capabilities only.
- Anything about the real-dictation tier, other languages/scripts, or hazards beyond the deterministic evidence.
- Several external facts are vendor or registry statements fetched on one date (listing ages are relative);
  the `llama3.2` license and Qwen3.5-2B license were not verified.

## Checks performed
Read the V1.23 trials/report and corpus, V1.3C/V1.19/V1.20 records and the V1.21 contract text; decomposed
the 14 non-complete warranted entries; checked local hardware and installed models from the filesystem
(Ollama not running); verified external facts against the Ollama library, tools-filter pages and
Hugging Face model cards. No inference, no download, no repository code change.
