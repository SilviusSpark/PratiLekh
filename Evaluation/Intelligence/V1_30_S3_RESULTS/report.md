# V1.29 S3 screening analysis

Generated from raw records only (`ComparisonAnalysis`); raw counts with denominators, no blended score.

## CAND-BASE `granite4:3b` — baseline
- protocol: tool engagement 66/66; strict-parser compliance 66/66; protocol failures [:]; provider failures 0; preflight failures 0
- observations (not gated): latency median 1715 ms, max 8759 ms, calls > 30 s 0; on-disk bytes 2099520968
- edit form: exact-pair matches 2/22 of resolved edits; span widths minimal=11, wholeSentence=4, wholeText=7; occurrence used 11, context used 19; addressing rejections ["contextMatchesNoCandidate": 12, "occurrenceContradictsContext": 1, "occurrenceOutOfRange(occurrence: 2, candidateCount: 1)": 2, "occurrenceOutOfRange(occurrence: 3, candidateCount: 1)": 1]
- outcome: complete 7/38 warranted; partial 3; per-correction 2/50; non-empty on warranted 22/38; punctuation non-empty 2/10; correct abstention on controls+hazards 24/24
- outcome by category: ["capitalization-correction-warranted: non-empty 2/8", "multi-edit-correction-warranted: non-empty 7/8", "multi-sentence-correction-warranted: non-empty 5/6", "punctuation-correction-warranted: non-empty 2/10", "whitespace-correction-warranted: non-empty 6/6"]
- containment: dispositions addressingRejected=16, autonomouslyAccepted=14, rejectedBySafetyAuthority=7, reviewOnly=1 (licensed autonomouslyAccepted=2); U0 (report-only) 11; U1 ["DEV-WS-005", "DEV-MULTI-003"]; U2 intersections 0, digit-changed []; U3 0
- manual entries (raw, human review required): ["DEV-AMBIG-001: 0 autonomous edit(s)", "DEV-AMBIG-002: 0 autonomous edit(s)", "DEV-AMBIG-003: 0 autonomous edit(s)", "DEV-AMBIG-004: 1 autonomous edit(s)"]
- gates: G1 true (engagement true, parser true); G2 true; G3 false (U1 2, U2 0, U3 0, fixtures contained true, control/hazard foreign 0)
- determinism audit: disagreements [] (flag false); raw-text-only differences ["DEV-PUNC-001", "DEV-CAP-006", "DEV-MULTI-002"]
- replay mismatches (fidelity defects, expected none): []

## CAND-001 `granite4.1:3b` — not eligible
- protocol: tool engagement 62/66; strict-parser compliance 62/62; protocol failures ["whole-response rejected: noToolCall": 4]; provider failures 0; preflight failures 0
- observations (not gated): latency median 2145 ms, max 11026 ms, calls > 30 s 0; on-disk bytes 2099519864
- edit form: exact-pair matches 2/19 of resolved edits; span widths minimal=18, wholeText=1; occurrence used 4, context used 24; addressing rejections ["contextMatchesNoCandidate": 7]
- outcome: complete 3/38 warranted; partial 3; per-correction 2/50; non-empty on warranted 17/38; punctuation non-empty 3/10; correct abstention on controls+hazards 24/24
- outcome by category: ["capitalization-correction-warranted: non-empty 1/8", "multi-edit-correction-warranted: non-empty 5/8", "multi-sentence-correction-warranted: non-empty 4/6", "punctuation-correction-warranted: non-empty 3/10", "whitespace-correction-warranted: non-empty 4/6"]
- containment: dispositions addressingRejected=7, autonomouslyAccepted=13, rejectedBySafetyAuthority=5, reviewOnly=1 (licensed autonomouslyAccepted=2); U0 (report-only) 9; U1 ["DEV-PUNC-007", "DEV-CAP-003", "DEV-WS-005", "DEV-MSENT-002", "DEV-MSENT-004"]; U2 intersections 0, digit-changed []; U3 0
- manual entries (raw, human review required): ["DEV-AMBIG-001: 2 autonomous edit(s)", "DEV-AMBIG-002: 0 autonomous edit(s)", "DEV-AMBIG-003: 0 autonomous edit(s)", "DEV-AMBIG-004: 0 autonomous edit(s)"]
- gates: G1 false (engagement false, parser true); G2 true; G3 false (U1 5, U2 0, U3 0, fixtures contained true, control/hazard foreign 0)
- determinism audit: disagreements [] (flag false); raw-text-only differences ["DEV-PUNC-009", "DEV-CAP-001", "DEV-CTRL-001", "DEV-HAZ-NUM-001"]
- replay mismatches (fidelity defects, expected none): []

## CAND-002 `qwen3:4b-instruct-2507-q4_K_M` — not eligible
- protocol: tool engagement 36/66; strict-parser compliance 36/36; protocol failures ["whole-response rejected: unexpectedTextContent": 30]; provider failures 0; preflight failures 0
- observations (not gated): latency median 2370 ms, max 10177 ms, calls > 30 s 0; on-disk bytes 2497293316
- edit form: exact-pair matches 0/0 (n/a) of resolved edits; span widths ; occurrence used 0, context used 0; addressing rejections [:]
- outcome: complete 0/38 warranted; partial 0; per-correction 0/50; non-empty on warranted 0/38; punctuation non-empty 0/10; correct abstention on controls+hazards 24/24
- outcome by category: ["capitalization-correction-warranted: non-empty 0/8", "multi-edit-correction-warranted: non-empty 0/8", "multi-sentence-correction-warranted: non-empty 0/6", "punctuation-correction-warranted: non-empty 0/10", "whitespace-correction-warranted: non-empty 0/6"]
- containment: dispositions  (licensed ); U0 (report-only) 0; U1 []; U2 intersections 0, digit-changed []; U3 0
- manual entries (raw, human review required): ["DEV-AMBIG-001: 0 autonomous edit(s)", "DEV-AMBIG-002: 0 autonomous edit(s)", "DEV-AMBIG-003: 0 autonomous edit(s)", "DEV-AMBIG-004: 0 autonomous edit(s)"]
- gates: G1 false (engagement false, parser true); G2 true; G3 true (U1 0, U2 0, U3 0, fixtures contained true, control/hazard foreign 0)
- determinism audit: disagreements [] (flag false); raw-text-only differences []
- replay mismatches (fidelity defects, expected none): []

## CAND-003 `phi4-mini:latest` — not eligible
- protocol: tool engagement 0/66; strict-parser compliance 0/0 (n/a); protocol failures ["whole-response rejected: unexpectedTextContent": 66]; provider failures 0; preflight failures 0
- observations (not gated): latency median 1063 ms, max 9022 ms, calls > 30 s 0; on-disk bytes 2491876363
- edit form: exact-pair matches 0/0 (n/a) of resolved edits; span widths ; occurrence used 0, context used 0; addressing rejections [:]
- outcome: complete 0/38 warranted; partial 0; per-correction 0/50; non-empty on warranted 0/38; punctuation non-empty 0/10; correct abstention on controls+hazards 24/24
- outcome by category: ["capitalization-correction-warranted: non-empty 0/8", "multi-edit-correction-warranted: non-empty 0/8", "multi-sentence-correction-warranted: non-empty 0/6", "punctuation-correction-warranted: non-empty 0/10", "whitespace-correction-warranted: non-empty 0/6"]
- containment: dispositions  (licensed ); U0 (report-only) 0; U1 []; U2 intersections 0, digit-changed []; U3 0
- manual entries (raw, human review required): ["DEV-AMBIG-001: 0 autonomous edit(s)", "DEV-AMBIG-002: 0 autonomous edit(s)", "DEV-AMBIG-003: 0 autonomous edit(s)", "DEV-AMBIG-004: 0 autonomous edit(s)"]
- gates: G1 false (engagement false, parser false); G2 true; G3 true (U1 0, U2 0, U3 0, fixtures contained true, control/hazard foreign 0)
- determinism audit: disagreements [] (flag false); raw-text-only differences []
- replay mismatches (fidelity defects, expected none): []

## CAND-004 `ministral-3:3b` — not eligible
- protocol: tool engagement 4/63; strict-parser compliance 4/4; protocol failures ["whole-response rejected: unexpectedTextContent": 59]; provider failures 3; preflight failures 0
- observations (not gated): latency median 1654 ms, max 11256 ms, calls > 30 s 0; on-disk bytes 2953840294
- edit form: exact-pair matches 0/2 of resolved edits; span widths wholeText=2; occurrence used 0, context used 0; addressing rejections ["ambiguousCandidates(count: 2)": 1]
- outcome: complete 0/38 warranted; partial 0; per-correction 0/50; non-empty on warranted 3/38; punctuation non-empty 0/10; correct abstention on controls+hazards 22/24
- outcome by category: ["capitalization-correction-warranted: non-empty 1/8", "multi-edit-correction-warranted: non-empty 0/8", "multi-sentence-correction-warranted: non-empty 1/6", "punctuation-correction-warranted: non-empty 0/10", "whitespace-correction-warranted: non-empty 1/6"]
- containment: dispositions addressingRejected=1, autonomouslyAccepted=1, rejectedBySafetyAuthority=1 (licensed ); U0 (report-only) 1; U1 ["DEV-CAP-002"]; U2 intersections 0, digit-changed []; U3 0
- manual entries (raw, human review required): ["DEV-AMBIG-001: 0 autonomous edit(s)", "DEV-AMBIG-002: 0 autonomous edit(s)", "DEV-AMBIG-003: 0 autonomous edit(s)", "DEV-AMBIG-004: 0 autonomous edit(s)"]
- gates: G1 false (engagement false, parser true); G2 false; G3 false (U1 1, U2 0, U3 0, fixtures contained true, control/hazard foreign 0)
- determinism audit: disagreements [] (flag false); raw-text-only differences []
- replay mismatches (fidelity defects, expected none): []

## Advancement (A1: complete >= baseline + 5 and exact McNemar p < 0.10)
- CAND-001: complete 3 vs baseline 7; discordant baseline-only 4, candidate-only 0; p = 0.1250; A1 false; eligible false
- CAND-002: complete 0 vs baseline 7; discordant baseline-only 7, candidate-only 0; p = 0.0156; A1 false; eligible false
- CAND-003: complete 0 vs baseline 7; discordant baseline-only 7, candidate-only 0; p = 0.0156; A1 false; eligible false
- CAND-004: complete 0 vs baseline 7; discordant baseline-only 7, candidate-only 0; p = 0.0156; A1 false; eligible false
- ranking (eligible, lexicographic): []; finalist: none
- contract probe triggered: false; probe models: []
- ranking uses only the four V1.27 keys (registry order is presentation only); exact ties are never broken automatically
- review stops (halt before S5 / S4 population): none


## Runtime lifecycle accounting (non-proposer requests; excluded from every count, latency and metric above)
- proposer records: 390 (plan steps 390); only these feed counts, latency and metrics
- lifecycle events: 18 ["identityProbe=3", "residentCheck=5", "unloadRequest=5", "unloadVerification=5"], all `countsAsInference` false
- unload requests (`POST /api/generate`, `keep_alive` 0, no prompt): 5, one per candidate
- lifecycle verification: passed

Selecting a finalist is not a production-readiness claim (PO-2/PO-3 unresolved).
