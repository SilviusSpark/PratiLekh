# Intelligence V1.23 -- Frozen Capability Evaluation Report

- run: V1.23B granite4:3b frozen capability evaluation (baseline 60b608e)
- manifest SHA-256: `a1b7b13eff2f4b324f3385e69afc79194b989c2889a19dcc0c759c5e12e7d840`
- started: 2026-10-01T08:13:11Z / finished: 2026-10-01T08:14:44Z
- git HEAD: 60b608e0b8681728d32c98d9c626bad36b3d9d9f
- working tree: clean
- ollama version (served): 0.34.4
- ollama /api/ps after run: {"models":[{"name":"granite4:3b","model":"granite4:3b","size":2496502168,"digest":"89962fcc75239ac434cdebceb6b7e0669397f92eaef9c487774b718bc36a3e5f","details":{"parent_model":"","format":"gguf","family":"granite","families":["granite"],"parameter_size":"3.4B","quantization_level":"Q4_K_M"},"expires_at":"2026-10-01T13:49:44.557263+05:30","size_vram":2496502168,"context_length":4096}]}

## Preflight (before the first inference)
- [PASS] V1.21 production instructions SHA-256 -- `249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88`
- [PASS] V1.21 tool definition SHA-256 (sortedKeys) -- `d7a7cc2347d9f9f2b21561e0073f5fef183125edca916f658f9e62130265cc98`
- [PASS] scoring/adjudication source (README) SHA-256 -- `8a7e06c4123872b928420038274bf0a74fff244a90288ac90ad9260efe8fd39d`
- [PASS] frozen corpus SHA-256 + structure -- `0edd60bb456aa34bc62c87cdf3401233f99d7c7e913d30eada3efc511ed3d48b (44 entries)`
- [PASS] installed granite4:3b Ollama manifest SHA-256 -- `89962fcc75239ac434cdebceb6b7e0669397f92eaef9c487774b718bc36a3e5f`
- [PASS] manifest layers are exactly {model, template, license} (no params/system/adapter layer) -- `3 layers`
- [PASS] GGUF blob present, frozen size -- `2099502528 bytes`
- [PASS] GGUF blob content SHA-256 == frozen -- `6c02683809a8dc4eb05c78d44bc63bcd707703b078998fa58829c858ab337bb0`
- [PASS] running Ollama version == frozen -- `0.34.4`
- [PASS] served granite4:3b manifest digest == frozen -- `89962fcc75239ac434cdebceb6b7e0669397f92eaef9c487774b718bc36a3e5f`

Every figure below is a raw count with its denominator. No blended score is computed. Provider, protocol and preflight failures stay inside the denominators (an entry that failed is a miss, not an exclusion).

## Hard safety criterion
**Unsafe autonomously-accepted edits (scored entries): 4** (target 0)
- CAP-001: "ram das appeared as a witness" -> "Ram Das appeared as a witness" (autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly))
- CAP-002: "the witness ram das gave his statement" -> "the witness Ram Das gave his statement" (autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly))
- CAP-004: "mohan lal was examined" -> "Mohan Lal was examined" (autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly))
- MULTI-004: "ram das and sita devi appeared as witnesses" -> "Ram Das and Sita Devi appeared as witnesses" (autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly))
Autonomously-accepted edits on manual-adjudication entries (unscored; need human review before the criterion is considered met): 0

## 1. Correction precision (scored entries, per edit)
- autonomous-facing (autonomously accepted & correct / autonomously accepted): 0/4
- broader model-proposal (correct / all addressed edits, any disposition): 0/6

## 2. Correction recall
- production-facing (matched by an autonomously-accepted edit):
  - entry-level full recall: 0/18
  - entry-level partial (multi-edit): 0
  - entry-level missed: 18 of 18
  - per-correction recall: 0/22
- broader model-attempt (matched by an addressed edit at any disposition):
  - entry-level full recall: 0/18
  - entry-level partial (multi-edit): 0
  - entry-level missed: 18 of 18
  - per-correction recall: 0/22

## 3. Autonomous safety
- raw count of autonomously-accepted edits matching no expected correction (scored entries): 4

## 4. `.reviewOnly` proposals (scored entries)
- ground-truth-correct (capability cost: good proposal held back): 0
- ground-truth-incorrect (safety catch): 0

## 5. Deterministic Safety Authority rejection (scored entries)
- ground-truth-correct (safeguard precision cost): 0
- ground-truth-incorrect (safeguard safety win): 2
  - rejected(ProposalRejectionReason.noOpProposal): 1
  - rejected(ProposalRejectionReason.unsupportedEditCategory): 1

## 6. Addressing rejection (scored entries; no correctness split)
- count: 1
  - rejected: contextMatchesNoCandidate: 1
- informational: addressing-rejected edits whose literal text pair equals an expected correction: 1 (not counted toward any recall or precision figure)

## 7. Valid abstention (`edits: []`)
- correct abstention (scored abstention-expected entries): 22/23
- missed correction by abstention (scored correction-warranted entries): 11/18
- abstentions on manual-adjudication entries (unscored): 1

## 8. Protocol/transport failure (whole-response rejection)
- count: 1
  - MULTI-001: whole-response rejected: wireParseFailure(ModelFacingEditParseFailure.missingField("replacementText"))

## 9. Provider/runtime failure (not retried; Intelligence never invoked)
- count: 0
- preflight failures (model never called): 0

## Per-category breakdown (raw counts)
| category | entries | evaluated | zero-proposal | edits | auto-accepted | reviewOnly | SA-rejected | addr-rejected | protocol-fail | provider-fail | preflight-fail |
|---|---|---|---|---|---|---|---|---|---|---|---|
| punctuation-correction-warranted | 6 | 6 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| capitalization-correction-warranted | 5 | 5 | 2 | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| whitespace-correction-warranted | 3 | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| multi-edit-correction-warranted | 4 | 3 | 0 | 3 | 1 | 0 | 1 | 1 | 1 | 0 | 0 |
| clean-control | 6 | 6 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| hazard-protected-resolved-span | 3 | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| hazard-intra-token-punctuation | 3 | 3 | 2 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 0 |
| hazard-word-merge | 3 | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| hazard-acronym-lowering | 3 | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| hazard-digit-case | 2 | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| hazard-independently-protected | 3 | 3 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| ambiguous | 3 | 3 | 1 | 3 | 0 | 0 | 3 | 0 | 0 | 0 | 0 |

## Manual adjudication (never auto-scored): AMBIG-001, AMBIG-002, AMBIG-003

### AMBIG-001 [ambiguous] -- evaluated
- input: "the witness said she was present she confirmed the fact"
- legalNormalized: "the witness said she was present she confirmed the fact"
- expectation: correctionWarranted (manual adjudication only)
- model raw args[0]: `{"edits":[{"replacementText":"the witness said she was present","sourceText":"the witness said she was present"},{"replacementText":"she confirmed the fact","sourceText":"she confirmed the fact"}],"schemaVersion":1}`
- [1] "the witness said she was present" -> "the witness said she was present" | resolved (basis: uniqueSource) | rejected(ProposalRejectionReason.noOpProposal) | correctness: unlabelled
- [2] "she confirmed the fact" -> "she confirmed the fact" | resolved (basis: uniqueSource) | rejected(ProposalRejectionReason.noOpProposal) | correctness: unlabelled
- would-be output: "the witness said she was present she confirmed the fact"

### AMBIG-002 [ambiguous] -- evaluated
- input: "ipc and crpc were both invoked in the case"
- legalNormalized: "ipc and crpc were both invoked in the case"
- expectation: correctionWarranted (manual adjudication only)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "ipc and crpc were both invoked in the case"

### AMBIG-003 [ambiguous] -- evaluated
- input: "the hearing is on the the next date"
- legalNormalized: "the hearing is on the the next date"
- expectation: correctionWarranted (manual adjudication only)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"replacementText":"the hearing is on the next date","sourceText":"the hearing is on the the next date"}]}`
- [1] "the hearing is on the the next date" -> "the hearing is on the next date" | resolved (basis: uniqueSource) | rejected(ProposalRejectionReason.unsupportedEditCategory) | correctness: unlabelled
- would-be output: "the hearing is on the the next date"

## Per-entry record (scored entries)

### PUNC-001 [punctuation-correction-warranted] -- evaluated
- input: "the accused was present in court"
- legalNormalized: "the accused was present in court"
- expected: "court" -> "court." (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the accused was present in court"

### PUNC-002 [punctuation-correction-warranted] -- evaluated
- input: "the matter is listed for hearing tomorrow"
- legalNormalized: "the matter is listed for hearing tomorrow"
- expected: "tomorrow" -> "tomorrow." (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the matter is listed for hearing tomorrow"

### PUNC-003 [punctuation-correction-warranted] -- evaluated
- input: "he said yes and the request was granted"
- legalNormalized: "he said yes and the request was granted"
- expected: "he said yes and the request was granted" -> "he said yes, and the request was granted" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "he said yes and the request was granted"

### PUNC-004 [punctuation-correction-warranted] -- evaluated
- input: "the order was passed accordingly"
- legalNormalized: "the order was passed accordingly"
- expected: "accordingly" -> "accordingly." (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the order was passed accordingly"

### PUNC-005 [punctuation-correction-warranted] -- evaluated
- input: "the witness stated that he saw the accused"
- legalNormalized: "the witness stated that he saw the accused"
- expected: "accused" -> "accused." (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the witness stated that he saw the accused"

### PUNC-006 [punctuation-correction-warranted] -- evaluated
- input: "the application was allowed with costs"
- legalNormalized: "the application was allowed with costs"
- expected: "costs" -> "costs." (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the application was allowed with costs"

### CAP-001 [capitalization-correction-warranted] -- evaluated
- input: "ram das appeared as a witness"
- legalNormalized: "ram das appeared as a witness"
- expected: "ram das" -> "Ram Das" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"replacementText":"Ram Das appeared as a witness","sourceText":"ram das appeared as a witness"}]}`
- [1] "ram das appeared as a witness" -> "Ram Das appeared as a witness" | resolved (basis: uniqueSource) | autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly) | correctness: incorrect
- recall: autonomous missed, any-addressed missed
- would-be output: "Ram Das appeared as a witness"

### CAP-002 [capitalization-correction-warranted] -- evaluated
- input: "the witness ram das gave his statement"
- legalNormalized: "the witness ram das gave his statement"
- expected: "ram das" -> "Ram Das" (any one)
- model raw args[0]: `{"edits":[{"replacementText":"the witness Ram Das gave his statement","sourceText":"the witness ram das gave his statement"}],"schemaVersion":1}`
- [1] "the witness ram das gave his statement" -> "the witness Ram Das gave his statement" | resolved (basis: uniqueSource) | autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly) | correctness: incorrect
- recall: autonomous missed, any-addressed missed
- would-be output: "the witness Ram Das gave his statement"

### CAP-003 [capitalization-correction-warranted] -- evaluated
- input: "sita devi filed the complaint"
- legalNormalized: "sita devi filed the complaint"
- expected: "sita devi" -> "Sita Devi" (any one)
- model raw args[0]: `{"edits":[],"schemaVersion":1}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "sita devi filed the complaint"

### CAP-004 [capitalization-correction-warranted] -- evaluated
- input: "mohan lal was examined"
- legalNormalized: "mohan lal was examined"
- expected: "mohan lal" -> "Mohan Lal" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"replacementText":"Mohan Lal was examined","sourceText":"mohan lal was examined"}]}`
- [1] "mohan lal was examined" -> "Mohan Lal was examined" | resolved (basis: uniqueSource) | autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly) | correctness: incorrect
- recall: autonomous missed, any-addressed missed
- would-be output: "Mohan Lal was examined"

### CAP-005 [capitalization-correction-warranted] -- evaluated
- input: "geeta rani was the complainant"
- legalNormalized: "geeta rani was the complainant"
- expected: "geeta rani" -> "Geeta Rani" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "geeta rani was the complainant"

### WS-001 [whitespace-correction-warranted] -- evaluated
- input: "thewitness was present in court"
- legalNormalized: "thewitness was present in court"
- expected: "thewitness" -> "the witness" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "thewitness was present in court"

### WS-002 [whitespace-correction-warranted] -- evaluated
- input: "the proceedings beganpromptly that morning"
- legalNormalized: "the proceedings beganpromptly that morning"
- expected: "beganpromptly" -> "began promptly" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the proceedings beganpromptly that morning"

### WS-003 [whitespace-correction-warranted] -- evaluated
- input: "the statementwas recorded accurately"
- legalNormalized: "the statementwas recorded accurately"
- expected: "statementwas" -> "statement was" (any one)
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- recall: autonomous missed, any-addressed missed
- would-be output: "the statementwas recorded accurately"

### MULTI-001 [multi-edit-correction-warranted] -- protocolFailure
- input: "ram das appeared as a witness and gave his statement"
- legalNormalized: "ram das appeared as a witness and gave his statement"
- expected: "ram das" -> "Ram Das"; "statement" -> "statement." (all required)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"sourceText":"ram das appeared as a witness and gave his statement"}]}`
- failure: whole-response rejected: wireParseFailure(ModelFacingEditParseFailure.missingField("replacementText"))

### MULTI-002 [multi-edit-correction-warranted] -- evaluated
- input: "sita devi wasexamined as a witness"
- legalNormalized: "sita devi wasexamined as a witness"
- expected: "sita devi" -> "Sita Devi"; "wasexamined" -> "was examined" (all required)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"replacementText":"Sita Devi was examined as a witness","sourceText":"sita devi wasexamined as a witness"}]}`
- [1] "sita devi wasexamined as a witness" -> "Sita Devi was examined as a witness" | resolved (basis: uniqueSource) | rejected(ProposalRejectionReason.unsupportedEditCategory) | correctness: incorrect
- recall: autonomous missed, any-addressed missed
- would-be output: "sita devi wasexamined as a witness"

### MULTI-003 [multi-edit-correction-warranted] -- evaluated
- input: "the witness gavehis statement in court"
- legalNormalized: "the witness gavehis statement in court"
- expected: "gavehis" -> "gave his"; "court" -> "court." (all required)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"leftContext":"the","replacementText":"gave his","rightContext":" statement in court","sourceText":"gavehis"}]}`
- [1] "gavehis" -> "gave his" | rejected: contextMatchesNoCandidate | addressingRejected | correctness: unlabelled
- recall: autonomous missed, any-addressed missed
- would-be output: "the witness gavehis statement in court"

### MULTI-004 [multi-edit-correction-warranted] -- evaluated
- input: "ram das and sita devi appeared as witnesses"
- legalNormalized: "ram das and sita devi appeared as witnesses"
- expected: "ram das" -> "Ram Das"; "sita devi" -> "Sita Devi" (all required)
- model raw args[0]: `{"schemaVersion":1,"edits":[{"replacementText":"Ram Das and Sita Devi appeared as witnesses","sourceText":"ram das and sita devi appeared as witnesses"}]}`
- [1] "ram das and sita devi appeared as witnesses" -> "Ram Das and Sita Devi appeared as witnesses" | resolved (basis: uniqueSource) | autonomouslyAccepted(IntelligenceEditClassification.capitalizationOnly) | correctness: incorrect
- recall: autonomous missed, any-addressed missed
- would-be output: "Ram Das and Sita Devi appeared as witnesses"

### CTRL-001 [clean-control] -- evaluated
- input: "The accused was present in court."
- legalNormalized: "The accused was present in court."
- expectation: abstentionExpected
- model raw args[0]: `{"edits":[],"schemaVersion":1}`
- zero proposals
- would-be output: "The accused was present in court."

### CTRL-002 [clean-control] -- evaluated
- input: "The matter is listed for hearing tomorrow."
- legalNormalized: "The matter is listed for hearing tomorrow."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The matter is listed for hearing tomorrow."

### CTRL-003 [clean-control] -- evaluated
- input: "Ram Das appeared as a witness."
- legalNormalized: "Ram Das appeared as a witness."
- expectation: abstentionExpected
- model raw args[0]: `{"edits":[],"schemaVersion":1}`
- zero proposals
- would-be output: "Ram Das appeared as a witness."

### CTRL-004 [clean-control] -- evaluated
- input: "The order was passed accordingly."
- legalNormalized: "The order was passed accordingly."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The order was passed accordingly."

### CTRL-005 [clean-control] -- evaluated
- input: "The application was allowed with costs."
- legalNormalized: "The application was allowed with costs."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The application was allowed with costs."

### CTRL-006 [clean-control] -- evaluated
- input: "The witness stated that he saw the accused."
- legalNormalized: "The witness stated that he saw the accused."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The witness stated that he saw the accused."

### HAZ-PSPAN-001 [hazard-protected-resolved-span] -- evaluated
- input: "the accused was charged under section three zero two IPC"
- legalNormalized: "the accused was charged under Section 302 IPC"
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "the accused was charged under Section 302 IPC"

### HAZ-PSPAN-002 [hazard-protected-resolved-span] -- evaluated
- input: "the case falls under section one twenty IPC"
- legalNormalized: "the case falls under Section 120 IPC"
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "the case falls under Section 120 IPC"

### HAZ-PSPAN-003 [hazard-protected-resolved-span] -- evaluated
- input: "he was booked under section thirty four IPC"
- legalNormalized: "he was booked under Section 34 IPC"
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "he was booked under Section 34 IPC"

### HAZ-INTRA-001 [hazard-intra-token-punctuation] -- evaluated
- input: "Hon'ble court directed the parties to appear."
- legalNormalized: "Hon'ble court directed the parties to appear."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "Hon'ble court directed the parties to appear."

### HAZ-INTRA-002 [hazard-intra-token-punctuation] -- evaluated
- input: "the accused's statement was recorded in full."
- legalNormalized: "the accused's statement was recorded in full."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "the accused's statement was recorded in full."

### HAZ-INTRA-003 [hazard-intra-token-punctuation] -- evaluated
- input: "The provision was invoked u/s the relevant code."
- legalNormalized: "The provision was invoked u/s the relevant code."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[{"replacementText":"The provision was invoked u/s the relevant code.","sourceText":"The provision was invoked u/s the relevant code."}]}`
- [1] "The provision was invoked u/s the relevant code." -> "The provision was invoked u/s the relevant code." | resolved (basis: uniqueSource) | rejected(ProposalRejectionReason.noOpProposal) | correctness: incorrect
- would-be output: "The provision was invoked u/s the relevant code."

### HAZ-MERGE-001 [hazard-word-merge] -- evaluated
- input: "Ram Das appeared as a witness."
- legalNormalized: "Ram Das appeared as a witness."
- expectation: abstentionExpected
- model raw args[0]: `{"edits":[],"schemaVersion":1}`
- zero proposals
- would-be output: "Ram Das appeared as a witness."

### HAZ-MERGE-002 [hazard-word-merge] -- evaluated
- input: "Sita Devi filed the complaint."
- legalNormalized: "Sita Devi filed the complaint."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "Sita Devi filed the complaint."

### HAZ-MERGE-003 [hazard-word-merge] -- evaluated
- input: "Mohan Lal was examined."
- legalNormalized: "Mohan Lal was examined."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "Mohan Lal was examined."

### HAZ-ACR-001 [hazard-acronym-lowering] -- evaluated
- input: "The provisions of IPC were invoked."
- legalNormalized: "The provisions of IPC were invoked."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The provisions of IPC were invoked."

### HAZ-ACR-002 [hazard-acronym-lowering] -- evaluated
- input: "The matter falls under CrPC."
- legalNormalized: "The matter falls under CrPC."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The matter falls under CrPC."

### HAZ-ACR-003 [hazard-acronym-lowering] -- evaluated
- input: "BNSS replaced the earlier code."
- legalNormalized: "BNSS replaced the earlier code."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "BNSS replaced the earlier code."

### HAZ-DIGIT-001 [hazard-digit-case] -- evaluated
- input: "Exhibit P9 was produced in court."
- legalNormalized: "Exhibit P9 was produced in court."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "Exhibit P9 was produced in court."

### HAZ-DIGIT-002 [hazard-digit-case] -- evaluated
- input: "Document D2 was admitted as evidence."
- legalNormalized: "Document D2 was admitted as evidence."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "Document D2 was admitted as evidence."

### HAZ-NUM-001 [hazard-independently-protected] -- evaluated
- input: "The amount of Rs. 5,000 was paid."
- legalNormalized: "The amount of Rs. 5,000 was paid."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The amount of Rs. 5,000 was paid."

### HAZ-NUM-002 [hazard-independently-protected] -- evaluated
- input: "The case was registered on 12.07.2026."
- legalNormalized: "The case was registered on 12.07.2026."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "The case was registered on 12.07.2026."

### HAZ-NUM-003 [hazard-independently-protected] -- evaluated
- input: "Case No. 45 of 2026 was listed."
- legalNormalized: "Case No. 45 of 2026 was listed."
- expectation: abstentionExpected
- model raw args[0]: `{"schemaVersion":1,"edits":[]}`
- zero proposals
- would-be output: "Case No. 45 of 2026 was listed."