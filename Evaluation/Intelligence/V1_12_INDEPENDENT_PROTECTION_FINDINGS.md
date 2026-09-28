# Intelligence V1.12 — Independent Protection Investigation

## 1. Status and scope

> **Follow-up (V1.13):** the numeric-token mechanism recommended here was implemented and validated on a fresh, frozen corpus — see `V1_13_NUMERIC_STRUCTURAL_PROTECTION.md`. This document is the record of the investigation.

Investigation and evaluation only. **No production recognizer was built**; nothing
under `Sources/` changed, no `ProtectedSpan` of kind `.independentlyProtected` is
produced by any production path, and no model was called. Everything below is
deterministic and model/provider-independent.

Artifacts:

| Artifact | Role |
|---|---|
| `Evaluation/References/independent-protection/corpus.json` | 299-entry labeled corpus (text only; no audio) |
| `Evaluation/Intelligence/Experimental/IndependentProtectionCandidateDetectors.swift` | *Experimental* candidate signals (measurement instruments, not proposals) |
| `Evaluation/Intelligence/Experimental/IndependentProtectionInvestigation.swift` | Harness: real normalization → real V1.11 derivation → real classifier → real Authority |
| `scripts/test_independent_protection_investigation.sh` | On-demand runner; pins every number quoted below |

## 2. Method, and its limits

- **Corpus.** `text` is dictation input to the real legal normalization pipeline;
  gold `expressions` are exact substrings of the *normalized* text (the Intelligence
  source). Two tiers: **development** (234 entries) — authored while the candidate
  signals were shaped; **held-out** (65 entries) — authored after the signals were
  frozen and scored **without tuning**. Held-out results are the honest measure of
  generalization; development results are optimistic by construction. **Disclosure:**
  the category-agnostic numeric-run signal of §6 was introduced *after* the held-out
  tier exposed the recognizers' brittleness. It is a one-line digit-run pattern not
  fitted to any held-out form, but its held-out result is therefore **not** a
  pre-registered test; the fresh held-out corpus required by the V1.13 acceptance
  criteria (§9) is the real validation.
- **Limits.** The corpus is synthetic and authored by the implementer to expose
  boundary cases. It is **not** a sample of real judicial dictation and supports **no
  prevalence estimate**. The only real-audio evidence used is the existing Phase 3E
  results (see §4). n is small (e.g. 14 held-out names, 7 held-out case numbers).
- **Hazard measurement.** For every gold expression, every single-character surface
  edit (delete/replace a punctuation character, delete a space, insert punctuation or
  a space between two characters, flip a letter's case) was generated, classified by
  the **real** `IntelligenceEditClassifier`, and — for those the classifier would let
  Intelligence apply autonomously — run through the **real**
  `IntelligenceSafetyAuthority` with (a) V1.11's derived normalization spans and (b)
  those plus candidate independent spans. An edit "escapes" if it is still
  `.autonomouslyAccepted`.
- **Hazard classes** (a proxy for meaning change, not proof of it): *digit-structural*
  — digit runs merge/split, or an amount's thousands/decimal separator sequence
  changes (value-altering); *word-structural* — digits intact but alphabetic tokens
  merge/split (`12th July`→`12thJuly`, `twenty six`→`twentysix`, `Ram Das`→`RamDas`;
  damage to the recorded form); separator-only; spacing-only; capitalization-only
  (never structural — asserted).

## 3. Why independent protection is needed at all

`IntelligenceEditClassifier` accepts any edit whose punctuation-stripped, or
case-folded, or whitespace-stripped strings are equal. Checked directly:

| Edit | Classifier verdict |
|---|---|
| `12.07.2026` → `12072026` / `12,07,2026` | punctuation-only (autonomous) |
| `Rs. 5,000` → `Rs. 5.000` / `Rs. 5000` | punctuation-only (autonomous) — 5,000 vs 5 |
| `123/2019` → `1232019` | punctuation-only (autonomous) |
| `Ram Das` → `RamDas`; `the accused` → `theaccused`; `twenty six` → `twentysix` | whitespace-only (autonomous) |
| `12.07.2026` → `12.07.2027`; `Section 302 IPC` → `Section 320 IPC` | other (rejected) |

So lexical changes are already refused, but **surface edits that change a number's
value or a token's boundaries are autonomous today**. Of 15,341 single-character
edits inside the development gold expressions, 8,015 (52.2%) are structural (2,277
digit, 5,738 word); held-out: 2,798 of 5,269 (53.1%). With only V1.11's derived
spans, 7,980 of the 8,015 development structural edits (99.6%; the other 35 sit
inside one canonical entry that normalization happened to decline) and all 2,798
held-out ones are still **autonomously accepted**. Capitalization-only edits never
change structure.

## 4. Real-dictation evidence about form

Phase 3E (real Parakeet audio): dates arrived as capitalized **number words**
(`Twelve July Two thousand twenty six`; a `twelve`→`twelfth` substitution in 4/5
trials of each phrasing; **0/10 canonical digit conversions**), statutory numbers
arrived as words or mixed forms, and `IPC` was sometimes mis-recognized. **The
dominant real-audio date form observed so far is spelled, not digits.** Any
protection that recognizes only digit forms would miss it — a central finding for
§8.

## 5. Category evaluation

Detection = exact/covering match of a gold expression by the candidate signal
(dev → held-out, exact counts): dates 36/36 → **7/12** (2 partial, 3 missed); amounts
34/34 → **9/11**; quantities 16/16 → **4/6**; case numbers 33/33 → **4/7**; exhibits
26/26 → **8/8**; names 27+2 superset/36 → **5/14**; canonical legal refs 8/8 →
**2/4**; bare years 6/7. The collapse from development to held-out for every
lexicon/pattern recognizer except exhibits is the main evidence that
**enumerating forms per category does not generalize**: held-out misses were
format variants (`12-Jul-2026`, `12th July,2026`, `twelfth day of July two thousand
twenty six`), lexicon gaps (`CRLMC`, `ICC No.`, `O.S. No.`), unit gaps
(`kilograms`, `yards`), spelled amounts (`five lakh rupees`, `ten thousand rupees`),
and nested statutory sub-clauses (`Section 20(b)(ii)(C) NDPS Act`).

| Category | Why mutation matters | Realistic forms | Deterministic signals | Ambiguity / false positives | Span shape | Recognizer justified? |
|---|---|---|---|---|---|---|
| **Dates / times** | separator/digit edits change the date; spelled-form token merges damage it | `12.07.2026`, `12/7/2026`, `12th July 2026`, `July 12, 2026`, spelled `Twelfth July Two thousand twenty six` | digit runs; month word adjacent to a numeric/number-word token | `may`/`march` as words (no FP with adjacency); `12th class` (no FP); spelled forms are the dominant real form and generalize poorly (held-out 0/2 for spoken) | whole expression | digits: yes via the numeric gate (§6); spelled: not reliably yet |
| **Amounts** | `5,000`↔`5.000`, grouping edits change value | `Rs. 5,000/-`, `₹1,50,000`, `Rs. 1.5 crore`, spelled `Rupees five thousand only`, `five lakh rupees` | currency markers; digit runs; number-word runs | bare numbers, `Room No. 15`, citations (`2019 CriLJ 1500`) | numeric run | digits: yes via gate; spelled: defer |
| **Quantified terms (sentence, age, weight, delay)** | `7 years` vs `17 years`-class digit edits; age drives POCSO | `7 years`, `seven years`, `aged 16 years`, `2.5 kg`, `25 kg` | digit/number-word run + unit lexicon | unit lexicon gaps (held-out 4/6); head-counts (`five persons`) | numeric run | digits via gate; unit recognizer rejected (lexicon) |
| **Case/reference numbers** | `123/2019`→`1232019` | `Crl. Appeal No. 123 of 2019`, `CRLA No. 45/2020`, `BLAPL No. 4567 of 2022`, 16-char CNR | digits; closed case-type lexicon + `No.` | lexicon incomplete (held-out 4/7); `Mobile No.`, `Room No.`, `Accused No. 1` must not match | numeric run | lexicon recognizer **rejected**; digits via gate |
| **Exhibits / material objects** | `Ext. P-1`→`Ext. P1`, `ExtP-1` (form damage) | `Ext. P-1`, `Ext.P/1`, `Exhibit P1`, `M.O.I`, `Material Object No. 2`, `Exhibits P-1 to P-5` | small closed prefix set (`Ext`/`Exhibit`/`Ex.`/`M.O.`) | `Ex.` former, `ex parte`, `extended`, `Mo.` (Mohammad) — **0 false positives**, 8/8 held-out | whole expression | best precision, but adds only form-damage protection beyond digits: **defer** |
| **Names / person references** | only *token merge/split* (`Ram Das`→`RamDas`) — case flips never change identity | `Shri Ram Das`, `S/o Late Gopal Behera`, `accused Pramod Kumar Nayak`, unanchored `Ram Das stated…` | honorific / relation / role anchors only | capitalization is **not** identity (see below); `Shri Jagannath Temple`; names that are common words (`Rose`, `Guru`); lowercase ASR names | n/a | **generic rule rejected; anchored recognizer deferred** |
| **Already-canonical legal refs** (statutory/witness the normalizer never touched) | `Section 302 IPC` emitted by ASR gets **no** derived span | `Section 302 IPC`, `Sections 294, 323 and 506 IPC`, `PW-1` | closed statute list / `[PD]W-n` | nested sub-clauses and `302/34` missed held-out (2/4) | numeric run | digits covered by the gate; no separate recognizer |

### Names (deliberate emphasis)

- **Capitalization is not identity.** The rejected "capitalized runs are names"
  rule, measured: development — 451 detections, **409 false positives**, **57/57
  negative entries flagged**, and even excluding sentence-initial words 241
  detections, 205 false positives, 27/57 negatives flagged, covering only 24/36 names;
  held-out — 130 detections, 115 false positives, 7/7 negatives flagged.
  Capitalized non-persons (`Court`, `State of Odisha`, `Central Bureau of
  Investigation`, `Indian Penal Code`, place names, weekdays, sentence starts) swamp it.
- **Anchored signals are precise but low-recall.** Development: 27 exact + 2
  covering of 36, but the 5 *unanchored* names (`Ram Das stated…`,
  `According to Bimal Kumar Jena…`) were all missed; **held-out: 5 of 14 exact, 9
  missed** (unanchored, `S.I.`-titled, `@` alias), plus the false positive
  `Shri Jagannath Temple`. Real dictation names frequently appear unanchored and
  lowercase (`ram das`).
- **Protecting names would cost the useful edit.** The only autonomous edit that
  changes a name's *identity* is a token merge/split; capitalization edits never do.
  The one place Intelligence adds value on names — capitalizing a lowercase ASR name —
  is exactly what whole-span protection would demote to review-only.

## 6. The decisive comparison: category recognizers vs a category-agnostic numeric gate

A deliberately coarse signal — every run of digits joined by single separators
(`[,./:-]`) — measured against the same hazards (all counts are digit-structural
edits; "escaping" = still autonomously acceptable):

| Strategy | Development (2,277 digit hazards) | Held-out (647) | Negatives touched (dev / held-out) | Protected chars outside gold |
|---|---|---|---|---|
| category recognizers | 15 escape | **93 escape (14.4%)** | 2/57 · 1/7 | 1.2% · 1.0% |
| **numeric-run gate** | **0** | **0** | 12/57 · 2/7 | 0.5% · 0.4% |
| numeric-run + number-word runs | 0 | 0 | 15/57 · 2/7 | 1.0% · 0.5% |
| recognizers ∪ numeric-run | 0 | 0 | 13/57 · 3/7 | 1.5% · 1.4% |

The numeric gate blocks **every** digit-structural hazard on both tiers, including
forms it was never shaped for, because a digit-run merge or split can only happen
inside (or at a separator within) a digit run. It over-protects only digit-bearing
text that is unrelated to the listed categories (a room number, a citation), which in
judicial text are themselves facts; in the corpus it protected 0.4–0.5% of
characters outside gold expressions and touched 14 of 64 negative entries (those
that contain digits).

What it does **not** cover: (a) spelled numbers/dates/amounts — the dominant real
audio date form; adding number-word runs lowers word-structural escapes on dates
(935→535 dev) but touches more negatives (`one`, `second`), and is unvalidated on
unseen data; (b) word-structural damage (`Ram Das`→`RamDas`); (c) two numerals
separated by whitespace (`12 34`) stay separate runs — deleting that space merges
them (0 instances in the corpus, but a real boundary); (d) note `\d` in ICU matches
Odia and Devanagari digits (verified), so non-Latin numerals are covered, but no
corpus case exercises them.

## 7. Interaction with V1.11 derived spans

Independent spans compose by the Authority's existing most-restrictive-wins rule
(resolved rejects, unresolved/independent review-only); nesting is harmless.
Observed in the 12 mixed entries: names adjacent to resolved witness/statutory spans
(`PW-1 Ram Das`, `DW-2 Sk. Salim`), dates/amounts/exhibits disjoint from them,
one canonical `Section 302 read with Section 34 IPC` that normalization *declined*
(yielding an unresolved span). Findings:

1. **Canonical legal references are unprotected.** Only 1 of 12 gold canonical
   legal references (ASR-emitted `Section 302 IPC`, `PW-1`, …) is covered by a
   derived span — the normalizer leaves already-canonical text untouched, so V1.11
   derives nothing for it. The numeric gate covers their digits (`302`, `34`, `12`).
2. **Residual year after a normalized citation.** `section three zero two of the
   Indian Penal Code, 1860` normalizes to `Section 302 IPC, 1860`; the `, 1860`
   residue is outside the resolved span and (a bare-year signal missed it) is
   covered only by the digit gate.

## 8. Recommendations

| Category | Decision |
|---|---|
| Digit-bearing expressions (dates, amounts, case/reference numbers, quantified terms, exhibit numbers, statutory/witness numbers, years) | **IMPLEMENT NOW — as one category-agnostic numeric-token gate**, not as five recognizers |
| Spelled dates / amounts / quantities / case numbers | **DEFER** — dominant real form, but no signal validated on unseen data; candidate: month-anchored window + number-word runs, needing its own fresh held-out corpus |
| Case-type lexicon recognizer | **REJECT** — 4/7 held-out; lexicon can never be closed; digits are covered by the gate |
| Unit-lexicon quantity recognizer | **REJECT** — 4/6 held-out; digits covered by the gate |
| Bare-year recognizer | **REJECT** — ambiguous; digits covered by the gate |
| Exhibit recognizer | **DEFER** — highest precision (8/8, 0 FP) but only adds form-damage protection |
| Canonical statutory/witness re-recognition | **REJECT as separate work** — the numeric gate closes the value-altering hazard |
| Names: capitalization-based | **REJECT** — evidence above |
| Names: anchored recognizer | **DEFER** — recall 5/14 held-out, unanchored 0, FP on `Shri … Temple` |

### Decision for the architect (not implemented; touches Safety policy)

The structural hazards exist because the classifier's autonomous predicates are
permissive: punctuation-only accepts changes adjacent to digits, whitespace-only
accepts merging/splitting words. Tightening those predicates (e.g. no autonomous
edit may change the digit-run or word-token structure of the text) would address
name token-merge, spelled-number damage and the residual hazards **without any
detection**, but it is an Authority policy change that V1.11/V1.12 were told not to
make. It is complementary to, not a substitute for, the gate (which is
review-only-by-span and detection-based). Recommend the architect decide separately.

## 9. Proposed V1.13 scope and acceptance criteria

**V1.13 — numeric-token independent protection** (production, deterministic,
model/provider-independent, unwired): a narrow function from a normalized string to
`.independentlyProtected` spans over every run of decimal digits (Unicode `Nd`) joined by single
`, . / : -` separators, composing with V1.11 spans via the existing Authority rules.
No Authority change, no categories, no names.

Acceptance criteria (measurable):
1. **Fresh held-out corpus** (≥150 entries authored *before* implementation, at
   least half unseen-form/adversarial): **0** digit-structural hazard edits escape
   (this investigation's harness, re-run against the production function).
2. Every digit run in the corpus is covered by exactly one span; **no partial
   coverage** of a run.
3. **Zero spans on digit-free text** (every negative without digits); each span
   contains ≥1 digit; protected characters outside gold ≤ 2% of characters.
4. Boundary semantics verified against the Authority: a zero-length insertion
   immediately before/after a run is **not** blocked; one strictly inside is.
5. Unicode: Latin, Devanagari and Odia digits covered; NFC/NFD text unaffected.
6. Deterministic and idempotent; composition with V1.11 spans yields the existing
   most-restrictive dispositions (tested end to end through V1.8 composition).
7. The known gap (whitespace-separated numerals) is either closed with a defined
   rule or explicitly recorded with a test, not left implicit.

Separate later candidate (**V1.14**, needs its own fresh held-out corpus first):
spelled-number/date window recognition.

## 10. Remaining risks and open items

- Synthetic, small, implementer-authored corpus; held-out is only 65 entries and
  its category counts are small — direction is clear, magnitudes are not.
- The numeric gate is review-only-by-span: it demotes, rather than forbids, edits.
- Spelled numbers/dates (dominant real form) remain unprotected; names remain
  unprotected against token merge/split until the architect decides on policy.
- Numbers unrelated to the listed categories are over-protected (small, measured).
- Still **not wired into dictation**; edit application, review handling and live-model
  evaluation remain unbuilt. **The do-not-wire warning stands.**

## 11. Architect decisions recorded at finalization

Approved: narrow structural protection for digit-bearing text (V1.13); spelled
number/date/amount protection deferred; exhibit-specific recognition deferred;
broad capitalization/name detection rejected; no case-type or unit lexicons and no
canonical legal-reference recognizers; **no change to the Safety Authority or
classifier** (the predicate-tightening question in §8 remains an undecided,
separate design matter). The numeric-token signal was introduced after the original
held-out failures were observed, so its results here are **not** independent
validation; V1.13 must be validated on genuinely fresh evaluation data.
