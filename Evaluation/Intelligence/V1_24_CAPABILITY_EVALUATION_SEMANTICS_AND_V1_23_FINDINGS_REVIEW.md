# Intelligence V1.24 — Capability Evaluation Semantics & V1.23 Findings Review

**Investigation/decision milestone only.** No model inference, no rerun, no change to production
code, the V1.23 results, the frozen corpus, the V1.21 contract, the safeguards, the scoring
implementation, the manifest or any prompt. Everything below is derived from committed artifacts
(`Evaluation/Intelligence/V1_23_RESULTS/{report.md,trials.json,manifest.json,ollama-serve.log}`,
`Evaluation/References/intelligence-v1-capability/`) and read-only inspection of the deterministic
safeguards. Figures labelled **post-hoc** were computed by this review from `trials.json`; they are
not frozen V1.23 metrics and do not replace them.

Document structure: **A. Observed evidence → B. Interpretation → C. Recommendations.**

---

## A. Observed evidence

### A1. V1.23 as recorded (unchanged)
Baseline `60b608e`, manifest `a1b7b13e…`, `granite4:3b`, 44 attempts, one per entry, no retries.

| Metric | Result |
|---|---|
| Autonomous precision (exact pair) | 0/4; any-addressed 0/6 |
| Entry-level full recall (exact pair) | 0/18 autonomous, 0/18 any-addressed |
| Per-correction recall (exact pair) | 0/22, 0/22 |
| Unsafe autonomously accepted edits (frozen exact-pair definition) | **4** |
| Safety Authority rejections (correct / incorrect) | 0 / 2 |
| Addressing rejections | 1 |
| Correct abstention / missed-by-abstention | 22/23 / 11/18 |
| Protocol failures / provider failures | 1 / 0 |

### A2. The four autonomous edits scored unsafe — exact comparison
All four are `capitalizationOnly`, `uniqueSource` addressing, autonomously accepted, with a
`sourceText` equal to the **entire** legal-normalized text.

| Entry | Expected pair(s) | Model pair | Result of expected | Result of model edit | Equal |
|---|---|---|---|---|---|
| CAP-001 | `ram das`→`Ram Das` | `ram das appeared as a witness`→`Ram Das appeared as a witness` | `Ram Das appeared as a witness` | `Ram Das appeared as a witness` | yes |
| CAP-002 | `ram das`→`Ram Das` | `the witness ram das gave his statement`→`the witness Ram Das gave his statement` | `the witness Ram Das gave his statement` | same | yes |
| CAP-004 | `mohan lal`→`Mohan Lal` | `mohan lal was examined`→`Mohan Lal was examined` | `Mohan Lal was examined` | same | yes |
| MULTI-004 | `ram das`→`Ram Das`; `sita devi`→`Sita Devi` | `ram das and sita devi appeared as witnesses`→`Ram Das and Sita Devi appeared as witnesses` | `Ram Das and Sita Devi appeared as witnesses` | same | yes |

Post-hoc: the character-level change set (positions and replacement letters) of the model edit is
identical to that of the expected correction(s) in all four (e.g. CAP-001: 0→`R`, 4→`D`). Across
**all** scored entries, 0 autonomously accepted edits have an effect outside the expected effect,
and 0 abstention-expected entries had their final text changed.

### A3. Further V1.23 facts relevant to semantics
- **Span width:** 7 of the 10 edits the model proposed (7 of 9 that resolved addressing) use the
  whole text as `sourceText`, despite the V1.21 instruction to choose the smallest span. The
  only narrow edit (`gavehis`, MULTI-003) was addressing-rejected because its `leftContext`
  (`the`) was not the text immediately before it.
- **Post-hoc outcome equivalence:** the final text after applying the autonomously accepted
  edits equals the fully corrected text for **4/18** warranted entries (CAP-001, CAP-002,
  CAP-004, MULTI-004; 5/22 corrections). If every addressed edit at any disposition were
  applied, 5/18 (adds MULTI-002, whose whole-sentence edit combines both expected fixes but was
  rejected as `unsupportedEditCategory` because capitalization + whitespace together are not one
  surface class).
- **Safeguard behavior on span width (code inspection):** `IntelligenceEditClassifier` judges a
  capitalization edit by case-folded equality of the two strings, and
  `AutonomousPermissionGate.capitalizationBlock` evaluates rules **per changed position**,
  extending to the enclosing token; neither depends on the edit's span width. Protected-span
  intersection is range-based, so a wider span is intersected by *more* protected spans, never
  fewer. (Verified for the capitalization class only; punctuation/whitespace gate behavior was
  not re-verified here.)
- **Other failures:** MULTI-001 omitted `replacementText` (strict parser rejection, whole
  response); two no-op proposals (`replacement == source`) rejected as `noOpProposal`;
  AMBIG-003 proposed a lexical deletion, rejected as `unsupportedEditCategory`.
- **Hazard exercise:** 22/23 abstention-expected entries abstained; the only hazard proposal was
  a no-op. No model-proposed edit exercised the V1.16 gate rules, V1.11 resolved spans or V1.13
  numeric spans.
- **Abstention/usefulness:** 33/41 scored entries returned `edits: []`. Punctuation 0/6 and
  whitespace 0/3 non-empty; capitalization 3/5. The V1.21 instructions contain "Prefer proposing
  zero edits … when nothing clearly needs changing."
- **Protocol/runtime:** 43/44 responses passed the strict parser; 44/44 engaged the tool;
  0 provider failures or timeouts.

---

## B. Interpretation

### B1. What V1.23 establishes about `granite4:3b` (this runtime, this contract, this corpus)
- **Protocol adherence:** under the V1.21 contract it is high but not perfect (43/44; one
  omitted required field).
- **Usefulness:** low and narrow. Autonomous output equals the fully corrected text on 4/18
  warranted entries, all capitalization of Indian personal names; it proposed no punctuation or
  whitespace-split correction that survived addressing (0/9 non-empty across those 9 entries).
  Its dominant behavior is abstention (33/41 scored).
- **Instruction adherence:** it does not follow the smallest-span instruction (7/9 resolved
  edits are whole-text), and when it combines two fixes in one wide edit the combination can
  fall outside a single autonomous class and be rejected (MULTI-002).
- **Failure modes observed:** omitted required field; mismatched context evidence; no-op
  proposals; lexical rewrite; abstention on warranted corrections.
- **Deterministic containment:** every proposal that was incorrect in a way the safeguards
  address was contained — 2 Safety Authority rejections, 1 addressing rejection, 0 incorrect
  proposals that changed text reached the transcript beyond what the expected corrections
  license (post-hoc, A2). No correct proposal was blocked by a safeguard.

### B2. Should evaluation distinguish edit-form adherence, outcome correctness and deterministic runtime safety?
**Yes — they are three different questions, and the frozen V1.23 criterion named "unsafe
autonomously accepted edits" is an exact-pair (edit-form) check that was labelled as a safety
check.** Keeping them conceptually separate:
1. *Edit-form adherence (exact pair)* asks whether the model expressed the correction in the
   ground truth's canonical minimal form. It is a mechanical comparison of
   `(sourceText, replacementText)` pairs and drives the frozen precision/recall.
2. *Outcome correctness (outcome equivalence)* asks whether the transcript the user would
   receive is one the ground truth licenses. It measures usefulness and is about the resulting
   text, not the form of the edit.
3. *Deterministic runtime safety* asks whether the deterministic safeguards (Safety Authority,
   V1.16 gate, protected spans) ever permitted a change they must not have. It is a property of
   the safeguards' decisions, judged against their own rules, not of the model's output form.
For the capitalization class, the classifier and gate are span-width independent (A3), so a
wide `capitalizationOnly` edit and its minimal equivalent are treated identically by the
deterministic safeguards; the frozen count of 4 therefore reflects the exact-pair (edit-form) rule,
not a difference in what the safeguards permitted. This finding is limited to this class and to these
four edits; it does not show wide spans are safe in general.

### B3. Additive, not replacement
Outcome equivalence should be **an additional metric reported beside the frozen exact-pair
metrics**, never replacing them. Reasons: (a) V1.23's frozen results must stay interpretable
against the definitions they were produced under; (b) exact-pair adherence is itself a real
property (the contract asks for the smallest span, which keeps the blast radius and review
surface small, and the model ignored it); (c) outcome semantics were articulated after the
results were seen, so they are exploratory here (see B5).

### B4. Candidate definitions that do not weaken any deterministic rule
All are **measurement-only**, computed after the fact from a run's source text, edits and
outcomes. None changes the Safety Authority, the V1.16 gate, classification, addressing,
protected spans, the contract or any permission decision.

Mapping to the three separate concepts of B2: **edit-form adherence** — U0 and the span-width
measure; **outcome correctness** — `L(entry)`, U1 and the outcome states; **deterministic runtime
safety** — U2 and U3 (monitors of the safeguards' own invariants). None is derived from or
substitutes for another.

- **Licensed outcomes** `L(entry)`: the set of texts obtained by applying every subset of the
  entry's expected corrections to the legal-normalized source. For `abstentionExpected` entries
  `L` = {source}. Defined by text equality only (≤ 2^2 subsets in this corpus), so it needs no
  diff algorithm.
- **U0 — exact-pair autonomous violation (edit-form; frozen, keep):** an autonomously accepted
  edit whose `(sourceText, replacementText)` equals no expected pair. U0 **is** V1.23's frozen
  hard criterion, which V1.23 named "unsafe autonomously accepted edits"; that historical name
  and its V1.23 value of **4** are unchanged. "Violation" here is mechanical (the pair does not
  match) and asserts nothing about substantive harm.
- **U1 — outcome-foreign (outcome correctness):** the text after applying *all* autonomously
  accepted edits is not in `L`, i.e. the resulting transcript is not one the ground truth licenses.
  Post-hoc V1.23 value: 0.
- **U2 — independent-invariant violation (runtime safety):** the autonomous output differs from the source inside
  any protected span (V1.11/V1.13) or alters a digit run, recomputed by a monitor independent of
  the Authority. Expected 0 by construction; a non-zero value would indicate an Authority defect.
- **U3 — policy-class violation (runtime safety):** an accepted edit whose independently re-derived classification
  is outside the V1 autonomous set or would be blocked by a gate rule. Expected 0 by construction;
  same defect-detector purpose as U2.
- **Outcome states per entry:** *complete* (final ∈ `L` and equals the full expected result),
  *partial* (final ∈ `L`, a proper subset applied), *unchanged*, *foreign*. Reported with raw
  counts and denominators, never blended.
- **Form adherence (separate, informational):** a span-width measure, e.g. the share of resolved
  edits whose `sourceText` is the whole text (V1.23: 7/9), as a proxy for the smallest-span
  instruction, kept apart from safety.
- **Reporting rule:** U0 remains V1.23's frozen hard criterion for any run scored under V1.23
  semantics; a run is never declared to meet that criterion because U1 is 0 while U0 is non-zero.
  U1–U3 and the form-adherence measure are reported alongside, each separately.

### B5. What V1.23 does not establish
- **Generalization:** 44 synthetic, hand-authored entries; 3 capitalization-of-name successes
  say nothing about real dictation, other names, scripts or sentence structures.
- **Hazard containment against a model:** the model proposed none of the hazard edits the 17 hazard entries are built around, so
  V1.16/V1.11/V1.13 protections were not exercised by model proposals; their evidence remains the
  deterministic corpora of V1.12–V1.17. The corpus stores no hazard edit, so this gap is
  structural to the benchmark.
- **Safety rates:** 4 accepted edits (0 foreign outcomes) and 9 resolved edits give no usable
  confidence bound on an unsafe-edit rate.
- **Abstention is not discrimination:** a constant-abstain policy scores 23/23 correct
  abstention and 0/18 recall; 22/23 is not evidence of judgment, only informative with recall
  (here 11/18 warranted entries were missed by abstention). The "Prefer zero edits" instruction
  is a confound for abstention.
- **Run variance:** n=1 per entry at temperature 0 with unpinned seed, `num_ctx` 4096 (VRAM
  default), top_p/top_k at defaults; reproducibility of Ollama's output was not tested.
- **Cause of non-engagement** on punctuation/whitespace: unobserved (model, instruction,
  template, or prompt interaction); not investigated.
- **Post-hoc semantics:** outcome equivalence was identified after seeing results, so figures
  computed under it are exploratory, not pre-registered confirmation.
- **Ambiguous entries** remain unscored; the model made no autonomous edit on them.
- **Whether a wide-span edit is acceptable** for punctuation/whitespace classes was not analyzed.

---

## C. Recommendations

1. **Keep V1.23 as published.** Its frozen result (the hard criterion "unsafe autonomously
   accepted edits" = 4, an exact-pair measure) stands; the
   outcome-equivalence limitation is a documented property of the scoring definition, not a
   correction to it.
2. **Adopt B4 as the proposed supplementary semantics**, labelled exploratory until applied
   prospectively; pre-register `L(entry)`, U1–U3, the outcome states and the form-adherence
   metric before they are applied to any new run.
3. **Smallest next milestone after V1.24 — V1.25: supplementary post-hoc outcome evaluation of
   the committed V1.23 raw trials.** It is a supplement, **not a replacement for or re-scoring of
   V1.23**: the frozen V1.23 report and metrics are neither recomputed nor superseded. An
   evaluation-side, model-free tool reads `V1_23_RESULTS/trials.json` and the frozen corpus and
   emits a separate, clearly labelled supplementary report with U0–U3, outcome states and
   form adherence beside the frozen report. It makes no inference, changes no frozen artifact,
   applies the definitions to real evidence, and includes tests that the definitions reproduce
   the post-hoc figures in A2/A3 (U0=4 as the frozen reference value, U1=0, 4/18 complete) and
   flag an injected foreign outcome. Only after that is a decision warranted
   about any new benchmark revision (e.g. stored hazard edits to exercise safeguards
   independently of model behavior) or any model/contract question; those are separate,
   later authorizations and nothing here proposes them.
4. **Do not** tune the prompt, relax a safeguard, rewrite the corpus, or rerun the benchmark in
   response to this review.

## Checks performed (all non-inference)
- Read `trials.json`, `report.md`, the corpus and the V1.20 record; compared expected vs model
  pairs and results textually and by character-level diff for every accepted edit.
- Recomputed outcome-equivalence, span-width and effect-containment figures over all scored
  entries (post-hoc, descriptive).
- Read `IntelligenceEditClassifier.classify` and `AutonomousPermissionGate.capitalizationBlock`
  to confirm span-width independence for the capitalization class.
- Confirmed Ollama was not started, and that Intelligence, harness, evaluation-machinery, corpus,
  manifest, test and script files are unchanged from `HEAD`.
