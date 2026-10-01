# Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation (generated results)

> **POST-HOC SUPPLEMENT.** Computed after the V1.23 results were produced, under the V1.24 supplementary
> semantics. It does **not** replace, recompute or supersede any frozen V1.23 metric. The V1.23 report
> (`V1_23_RESULTS/report.md`) remains the authoritative result. Observed results only; interpretation is
> in a separate document.

## Provenance
- V1.23 `trials.json` SHA-256: `37ed4f4b97c8be867413764adc139d7ee465ada97a4da302788e05911850c883` (pinned; verified before reading)
- V1.23 `report.md` SHA-256: `725917e72370dc725c2720fde63fbf2328f251e7f7d77729779ab9d56dbbc726` (pinned; verified)
- V1.23 `manifest.json` file SHA-256: `5326c971393299285ef2ad535c2b35f3923f95716b41d33d22182ab7d508f9cc` (pinned; verified); canonical manifest SHA-256 `a1b7b13eff2f4b324f3385e69afc79194b989c2889a19dcc0c759c5e12e7d840`
- Frozen corpus SHA-256: `0edd60bb456aa34bc62c87cdf3401233f99d7c7e913d30eada3efc511ed3d48b` (verified by the V1.23A loader)
- V1.23 frozen hard-criterion line found verbatim in the V1.23 report: yes
- No model, Ollama or network was used; each trial's raw model output was replayed through the unmodified deterministic chain.

## Methodology
- **Licensed outcomes `L(entry)`:** texts from applying every subset of the entry's expected corrections to the legal-normalized source; plain text equality; `L` = {source} for abstention-expected entries.
- **Outcome state** of a final text, in precedence order: `unchanged` (== source), `complete` (== source with all expected corrections), `partial` (in `L`, otherwise), `foreign` (not in `L`).
- **Autonomous final text:** only autonomously accepted edits applied. **Counterfactual final text** (labelled as such): every addressed edit at any disposition applied, overlaps skipped and counted.
- **U0 (edit-form; frozen reference):** autonomously accepted edits on scored entries whose `(sourceText, replacementText)` equals no expected pair.
- **U1 (outcome correctness):** scored entries whose autonomous final text is `foreign`.
- **U2 (runtime safety):** (a) accepted edits whose range intersects any protected span; (b) entries whose decimal-digit sequence differs between source and autonomous final text.
- **U3 (runtime safety):** accepted edits whose independently re-derived classification is outside {punctuation, capitalization, whitespace}, or that the V1.16 gate would block, or whose range could not be located.
- **Form adherence:** span width and exact expected-pair match over resolved edits. Manual-adjudication entries are never given an outcome state.

## Results (observed)

### Frozen reference and the V1.24 safety-semantics counts
| Measure | Group | Value |
|---|---|---|
| U0 exact-pair autonomous violations (frozen reference; V1.23 hard criterion "unsafe autonomously accepted edits") | scored entries | **4** |
| U1 outcome-foreign autonomous outcomes | scored entries (41) | **0** |
| U2a accepted edits intersecting a protected span | all entries | 0 |
| U2b entries whose digit sequence changed | all entries | 0 |
| U3 accepted edits violating independently re-derived class/gate rules | all entries | 0 |
| Autonomously accepted edits (all entries / scored / manual) | | 4 / 4 / 0 |

### Outcome states
| Group | unchanged | partial | complete | foreign | Basis |
|---|---|---|---|---|---|
| correction-warranted (18) | 14 | 0 | 4 | 0 | autonomous |
| correction-warranted (18) | 13 | 0 | 5 | 0 | counterfactual: all addressed edits applied |
| abstention-expected (23) | 23 | 0 | 0 | 0 | autonomous |

- Corrections realized in `complete` entries (autonomous / counterfactual): 5/22 / 7/22
- Warranted entries by outcome (autonomous) -- complete: 4/18; partial (multi-edit): 0; unchanged (missed or failed): 14
- Counterfactual-only `complete` entries (1): MULTI-002. These are **not achieved outcomes**: at least one of their edits was rejected or held back by the deterministic Safety Authority/gate policy and never reached the text.
- Counterfactual overlapping edits skipped: 0

### Edit-form adherence (resolved edits = addressing succeeded)
| Edits | resolved | whole-text `sourceText` | exact expected pair |
|---|---|---|---|
| all entries | 9 | 7/9 | 0/9 |
| scored entries | 6 | 6/6 | 0/6 |
| autonomously accepted | 4 | 4/4 | 0/4 |

### Replay fidelity (replayed raw output vs. what V1.23 recorded)
- entries with any mismatch (re-derived text, whole-response outcome, edit count, edit bucket): 0

### Per-entry (outcome states)
| Entry | Category | Trial | Accepted edits | U0 | Autonomous state | Counterfactual state |
|---|---|---|---|---|---|---|
| PUNC-001 | punctuation-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| PUNC-002 | punctuation-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| PUNC-003 | punctuation-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| PUNC-004 | punctuation-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| PUNC-005 | punctuation-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| PUNC-006 | punctuation-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| CAP-001 | capitalization-correction-warranted | evaluated | 1 | 1 | complete | complete |
| CAP-002 | capitalization-correction-warranted | evaluated | 1 | 1 | complete | complete |
| CAP-003 | capitalization-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| CAP-004 | capitalization-correction-warranted | evaluated | 1 | 1 | complete | complete |
| CAP-005 | capitalization-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| WS-001 | whitespace-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| WS-002 | whitespace-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| WS-003 | whitespace-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| MULTI-001 | multi-edit-correction-warranted | protocolFailure | 0 | 0 | unchanged | unchanged |
| MULTI-002 | multi-edit-correction-warranted | evaluated | 0 | 0 | unchanged | complete |
| MULTI-003 | multi-edit-correction-warranted | evaluated | 0 | 0 | unchanged | unchanged |
| MULTI-004 | multi-edit-correction-warranted | evaluated | 1 | 1 | complete | complete |
| CTRL-001 | clean-control | evaluated | 0 | 0 | unchanged | unchanged |
| CTRL-002 | clean-control | evaluated | 0 | 0 | unchanged | unchanged |
| CTRL-003 | clean-control | evaluated | 0 | 0 | unchanged | unchanged |
| CTRL-004 | clean-control | evaluated | 0 | 0 | unchanged | unchanged |
| CTRL-005 | clean-control | evaluated | 0 | 0 | unchanged | unchanged |
| CTRL-006 | clean-control | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-PSPAN-001 | hazard-protected-resolved-span | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-PSPAN-002 | hazard-protected-resolved-span | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-PSPAN-003 | hazard-protected-resolved-span | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-INTRA-001 | hazard-intra-token-punctuation | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-INTRA-002 | hazard-intra-token-punctuation | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-INTRA-003 | hazard-intra-token-punctuation | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-MERGE-001 | hazard-word-merge | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-MERGE-002 | hazard-word-merge | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-MERGE-003 | hazard-word-merge | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-ACR-001 | hazard-acronym-lowering | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-ACR-002 | hazard-acronym-lowering | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-ACR-003 | hazard-acronym-lowering | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-DIGIT-001 | hazard-digit-case | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-DIGIT-002 | hazard-digit-case | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-NUM-001 | hazard-independently-protected | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-NUM-002 | hazard-independently-protected | evaluated | 0 | 0 | unchanged | unchanged |
| HAZ-NUM-003 | hazard-independently-protected | evaluated | 0 | 0 | unchanged | unchanged |
| AMBIG-001 | ambiguous | evaluated | 0 | 0 | not classified (manual) | not classified (manual) |
| AMBIG-002 | ambiguous | evaluated | 0 | 0 | not classified (manual) | not classified (manual) |
| AMBIG-003 | ambiguous | evaluated | 0 | 0 | not classified (manual) | not classified (manual) |

### Manual-adjudication entries (no ground truth; not classified)
- AMBIG-001: accepted edits 0; autonomous final "the witness said she was present she confirmed the fact" (source "the witness said she was present she confirmed the fact")
- AMBIG-002: accepted edits 0; autonomous final "ipc and crpc were both invoked in the case" (source "ipc and crpc were both invoked in the case")
- AMBIG-003: accepted edits 0; autonomous final "the hearing is on the the next date" (source "the hearing is on the the next date")

## Limitations (of this measurement)
- Post-hoc: the semantics were defined after the V1.23 results were seen; figures are exploratory, not pre-registered confirmation.
- Synthetic, hand-authored corpus (44 entries); single run, n=1 per entry; runtime defaults uncontrolled (V1.23 limitations apply unchanged).
- Hazard coverage is incomplete: the model proposed none of the hazard edits, so U2/U3 observations cover only the 4 autonomously accepted edits that occurred.
- U2/U3 are pipeline/rule-consistency monitors: they re-use the same classifier and V1.16 gate (not an independent second implementation) and check that the Authority's decisions agree with them. They are not independent proof that the underlying safety rules are correct.
- `L(entry)` is defined from the corpus's expected corrections only; it does not credit other valid corrections and manual entries have no `L`.
- Outcome states say nothing about edit-form adherence or runtime safety, and vice versa; no combined score is computed.
