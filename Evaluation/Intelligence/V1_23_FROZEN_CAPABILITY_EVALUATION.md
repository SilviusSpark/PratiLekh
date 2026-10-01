# Intelligence V1.23 — Frozen Intelligence V1 Capability Evaluation (execution record)

**Execution and observation only.** One run, one attempt per entry, no retries, no reruns, no
change to any code, corpus, manifest, scoring or configuration before, during or after the run.
No remediation or diagnosis was performed. All numbers below are copied from the generated
`V1_23_RESULTS/report.md` (verbatim output of the committed live runner); this document adds
provenance, factual observations and disclosed limitations only.

## Provenance
- Baseline commit: `60b608e0b8681728d32c98d9c626bad36b3d9d9f` (V1.23A); working tree clean at execution.
- Manifest SHA-256: `a1b7b13eff2f4b324f3385e69afc79194b989c2889a19dcc0c759c5e12e7d840` (runner recomputed and matched it).
- Corpus SHA-256 `0edd60bb…3ed48b`; V1.21 instructions `249ebb6a…4ad88`; tool definition `d7a7cc23…cc98`; README `8a7e06c4…fd39d` — all verified before the first inference.
- Model: `granite4:3b`, Ollama manifest digest `89962fcc…3e5f`, Q4_K_M, 3.4B; Ollama 0.34.4 (started normally; no warm-up; `/api/ps` was empty before the run; served digest/version matched the frozen values).
- Executed 2026-10-01T08:13:11Z → 08:14:44Z (UTC). Loaded context length reported after the run: 4096.
- Ollama server log: exactly 44 `POST /v1/chat/completions`, all HTTP 200; 0 retries logged by the client. Other requests were metadata GETs (`/api/version`, `/api/tags`, `/api/ps`).
- Raw outputs: `V1_23_RESULTS/{report.md,trials.json,manifest.json,ollama-serve.log}`.

## Metrics (frozen definitions; raw counts, never blended)
| # | Metric | Result |
|---|---|---|
| 1 | Precision, autonomous-facing | 0/4 |
| 1 | Precision, any addressed disposition | 0/6 |
| 2 | Entry-level full recall, autonomous / any-addressed | 0/18 / 0/18 |
| 2 | Partial multi-edit recall | 0 / 0 (4 multi-edit entries) |
| 2 | Entry-level missed | 18 of 18 / 18 of 18 |
| 2 | Per-correction recall, autonomous / any-addressed | 0/22 / 0/22 |
| 3 | **Unsafe autonomously accepted edits (frozen definition)** | **4** (target 0) |
| 4 | `.reviewOnly`: correct / incorrect | 0 / 0 |
| 5 | Safety Authority rejections: correct / incorrect | 0 / 2 (`noOpProposal` 1, `unsupportedEditCategory` 1) |
| 6 | Addressing rejections | 1 (`contextMatchesNoCandidate`); literal pair equals an expected correction: 1 (informational) |
| 7 | Correct abstention (abstention-expected entries) | 22/23 |
| 7 | Missed correction by abstention (warranted entries) | 11/18 |
| 7 | Abstentions on manual entries | 1 (unscored) |
| 8 | Protocol/transport failures | 1 (MULTI-001: `missingField("replacementText")`) |
| 9 | Provider/runtime failures | 0 (preflight failures 0) |

Autonomously accepted edits on the 3 manual-adjudication entries: **0**, so no human
adjudication of autonomous edits is required for AMBIG-001/002/003 (their raw outputs are in the
report: two no-op edits rejected as `noOpProposal` on AMBIG-001; `edits: []` on AMBIG-002; a
lexical duplicate-word deletion on AMBIG-003 rejected as `unsupportedEditCategory`).

## The 4 counted unsafe edits — frozen result and post-run inspection
CAP-001, CAP-002, CAP-004 and MULTI-004. Each is a single edit whose `sourceText` is the
**entire sentence**, classified `capitalizationOnly` and autonomously accepted.

1. **Frozen result (unchanged, not rescored):** under the frozen exact-pair definition
   (README Sec.4: an edit is correct only if its `(sourceText, replacementText)` pair equals a
   listed expected pair), these four edits are **incorrect**, and because they reached
   autonomous acceptance they are counted as **unsafe autonomously accepted edits = 4**
   (target 0). This is the reported V1.23 metric.
2. **Post-run inspection (descriptive only; performed after the results were produced and used
   to change nothing):** for all four, the resulting would-be text is identical to the text
   produced by applying the entry's expected correction(s) to the legal-normalized text. This
   exposes an **outcome-equivalence limitation in the frozen scoring definition**: exact-pair
   matching cannot distinguish a wider-span edit that yields the expected final text from an
   edit that yields a different one.

Nothing in this record characterizes these four edits as substantively harmful beyond what the
frozen metric establishes. The metric is neither reclassified nor adjusted here; whether
exact-pair equality or outcome equivalence is the appropriate unsafe-edit definition is a
methodological question for a later, separately-authorized review.

## Key factual observations (no fixes proposed)
- Of 41 scored entries: 33 returned `edits: []`, 7 returned at least one edit (CAP-001/002/004, MULTI-002/003/004, HAZ-INTRA-003), and 1 was a protocol failure (MULTI-001). Of the 3 manual entries, 2 returned edits and 1 returned `edits: []`.
- Punctuation: 0/6 non-empty (matches V1.20's 0/9 on the same fixtures). Whitespace-split: 0/3 non-empty. Capitalization: 3/5 non-empty (CAP-003, CAP-005 abstained).
- Multi-edit: 4 entries, 0 abstentions; outcomes were one protocol failure (replacementText omitted), one SA-rejected whole-sentence edit that also changed words (`wasexamined`→`was examined`, `unsupportedEditCategory`), one addressing rejection (`gavehis`: supplied `leftContext` "the" did not match as a literal context), and one accepted whole-sentence capitalization.
- Zero edits reached `reviewOnly`. Two proposals were no-ops (`replacement == source`) and were rejected as `noOpProposal`.
- Hazard entries: 22 of 23 scored abstention-expected entries abstained, including every word-merge, acronym-lowering, digit-case, independently-protected and resolved-span entry — the model proposed none of those hazard edits, so the V1.16 gate, V1.11 and V1.13 protections were not exercised by model proposals in this run. The one hazard proposal (HAZ-INTRA-003) was a no-op.
- Deterministic containment: 2 incorrect proposals were rejected by the Safety Authority and 1 addressing-rejected; no ground-truth-correct proposal was blocked by a safeguard.
- Protocol compliance on the present contract: 43/44 responses passed the strict parser; 44/44 engaged the tool; 0 provider failures, 0 timeouts (the 60 s limit and cold start did not cause a failure).

## Disclosed benchmark limitations
- 100% synthetic data (`tier: synthetic`); no real-dictation tier was run.
- Incomplete hazard coverage: the corpus stores no hazard edits, so hazard containment is exercised only if the model proposes one (here it essentially did not).
- Single run, n=1 per entry at temperature 0; no variance estimate. Seed, `num_ctx` (4096), top_p, top_k and other runtime defaults were not controlled.
- 3 ambiguous entries are unscored by design.
- Exact-pair correctness cannot distinguish a wider-span but outcome-equivalent edit from a wrong one (see above).
