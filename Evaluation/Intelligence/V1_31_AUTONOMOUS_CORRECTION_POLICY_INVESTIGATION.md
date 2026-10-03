# Intelligence V1.31 — Model-independent autonomous correction policy investigation

**Investigation and documentation only.** No model was run; no production Intelligence code, Safety Authority, autonomous-permission
gate, contract, corpus, result or label was changed; no S3/V1.23/V1.25 result was rescored or relabelled. Out of scope and untouched:
text-channel fallback parsing, prompt/contract tuning, new model comparison, Granite addressing experiments, fine-tuning/PIM,
live-dictation integration, and any implementation of the policy below.

**How to read this document.** §A records the **adopted decisions** (Product Owner / architecture rulings made after the investigation).
§1–§9 and §11 are the **investigation findings and proposals** they were made on; where a proposal is narrower or broader than an adopted
decision, §A governs. §7's probe is **diagnostic evidence**, not a defect list. Observed model behavior appears only in §8 as illustration of
a policy fixed beforehand, never as a reason to widen autonomy.

## A. Adopted decisions (these govern)

| # | Decision |
|---|---|
| **PO-A** | **Model output alone never confers autonomous permission.** A model-proposed edit may be autonomous only when deterministic code independently verifies a *pre-authorized T2 evidence predicate*. T1 remains deterministic processing, not model Intelligence. |
| **PO-B** | Sentence-initial capitalization and terminal-period insertion are *potential* T2 classes but are **presently non-autonomous**: the required deterministic sentence-boundary and abbreviation evidence does not yet exist. |
| **PO-C** | Names, titles and places are **not autonomously inferred or corrected from model judgment.** A future *verified per-matter vocabulary* may support separately specified deterministic/T2 operations. |
| **PO-D** | Grammar, style and lexical changes may become **future review-only (T3) suggestions**; never autonomous from linguistic plausibility alone. |
| **PO-E** | **Punctuation provenance** (dictated vs ASR vs deterministic) is an *architectural goal where technically derivable*. Feasibility is **not assumed**, and nothing is implemented in V1.31. |
| **PO-F** | A versioned, curated deterministic **lexicon may contribute evidence for word splitting but is not by itself sufficient authorization** for arbitrary splits. Curatorship remains unresolved. |
| **PO-G** | **Review UX is deferred.** T3 defines policy scope but has **no production application path** until separately designed. |
| **PO-H** | **Policy-invariant violation is the architectural zero-tolerance safety definition** (the Safety Authority's governing harm). Corpus answer-key foreignness (U1) remains an *evaluation metric* and must not be conflated with it. |
| **PO-2 / PO-3** | Unresolved (minimum absolute usefulness; production latency/resource thresholds). |

**Current authorization state (normative): no T2 class is currently authorized**, because no required deterministic evidence predicate has yet been
specified *and* authorized for any class. Consequently no model-proposed edit is autonomous under the adopted policy today.

**Consequences that follow directly (not new decisions):** (i) no autonomous model-proposed edit exists in the adopted policy until a T2
class has a pre-authorized evidence predicate that code verifies; PO-B and PO-C say the first candidates (terminal period, sentence-initial
capital, names/titles) currently lack one; (ii) the T1 classes are implemented, if at all, in the deterministic pipeline; a model proposal that
merely equals a T1 rule confers nothing; (iii) T3 is policy vocabulary only today — no suggestion is shown or applied anywhere; (iv) the *current*
Authority was built under the earlier V1.14–V1.16 policy and is **not** claimed to be defective against the adopted one (§7).

## 1. Premises (from the committed architecture)

1. **Dictated judicial expression is authoritative.** PratiLekh records the judge's dictation (`CLAUDE.md` product principle). Format what
   was dictated; never complete or reinterpret what was not.
2. **The words are authoritative; much of the surface is not dictated.** Speech carries words. Punctuation, capitalization and spacing in the
   transcript come from the ASR provider and deterministic formatting, except where the judge explicitly dictates them (spoken punctuation).
   Surface edits are therefore *transcription formatting*, but some surface carries legal significance (a title/name capital, a clause-scope
   comma, a question mark), so "surface" is not automatically "harmless".
3. **Deterministic code decides what reaches the transcript; the model proposes** (the standing invariant). The model is untrusted evidence.
4. **Autonomy is a property of a rule, not of an edit that looks reasonable.** A class is licensed by a stated, testable rule fixed before
   looking at any model output.
5. **Intelligence must not silently become an editor.** Anything beyond information-neutral normalization must be visible and judge-controlled.

## 2. The boundary: four zones

| Zone | Question that identifies it | Example | Default |
|---|---|---|---|
| **Transcriptional / deterministic** | Is the correct output a *function of the text alone* by a rule one sentence long, with no choice among readings? | collapse a doubled space; normalize NBSP | code, not model; autonomous |
| **Linguistically plausible** | Would a competent reader usually agree, yet the output is *not* derivable by such a rule (it uses judgment or world knowledge)? | comma after "however"; capitalizing "counsel" | review-only at most |
| **Editorial** | Does it change *wording*, add/remove/reorder words, or choose a style? | grammar fix, deleting a repeated word, rephrasing | not autonomous; outside the V1 surface capability |
| **Meaning- or record-sensitive** | Could it change a fact, identity, number, date, statute, name, scope of a clause, or the form of something deliberately dictated? | digit change, name capital, restrictive comma, lowering "Court" | prohibited autonomously; abstain or surface the ambiguity |

An edit's zone is determined by what it *changes in information*, not by its Unicode class ("capitalization-only" spans all four zones:
sentence-initial "The" is transcriptional; "Kishore Mohanty" asserts an identity).

## 3. Policy tiers

- **T1 — Deterministic-safe.** Correct by a stated rule on the text alone. **Deterministic processing, not model Intelligence** (PO-A): it
  belongs in the formatting/normalization stages that precede Intelligence. A model proposal equal to a T1 rule is redundant, not a licence.
- **T2 — Conditionally safe (autonomous only with verified, pre-authorized deterministic evidence).** The model may propose it; it is applied
  without review *only if* code independently verifies the class's evidence predicate, which must itself have been authorized beforehand
  (PO-A). A T2 class **without a specified, implemented, authorized predicate is presently non-autonomous** (PO-B, PO-C); the evidence listed
  in §5 is a *necessary-condition sketch*, not an authorization.
- **T3 — Model-proposable, review-only.** Would be shown to the judge as a suggestion and never applied without explicit acceptance. **Policy scope
  only:** no production application path exists until review UX is separately designed (PO-G).
- **T4 — Prohibited / abstain.** Never applied autonomously and not suggested as an edit; if the text is ambiguous the right behavior is to
  leave it unchanged (optionally flag the ambiguity).

## 4. Governing invariants

- **I1 Token-sequence invariance.** An autonomous edit leaves the sequence of word tokens unchanged, comparing case-folded and ignoring
  punctuation and whitespace. (Adding, removing, substituting, reordering, splitting or merging words is never autonomous without separate
  lexicon evidence, and even then only for splits/merges.) *Rationale:* dictated wording is authoritative.
- **I2 Record-token immutability.** No autonomous edit alters a record-sensitive token: digit-bearing tokens, statute/exhibit/case/date/amount
  forms, acronym- or identifier-shaped tokens, anything inside a protected span, and — because they cannot be detected structurally —
  *tokens whose case the edit would assert or remove* unless the evidence in §5 licenses it. Names/titles/defined terms are record-sensitive.
- **I3 Information neutrality / rule-derivability.** An autonomous edit adds or removes no information: the result must be derivable by a
  one-sentence rule stated before the edit, independent of meaning. If it requires choosing among readings or world knowledge, it is not autonomous.
- **I4 Authored marks are authoritative.** A punctuation or formatting mark the judge dictated (or a deterministic stage produced) is never
  changed or removed. Autonomy, where any, is limited to *adding* a mark at a position that holds none. (Requires punctuation provenance — a
  current gap, §7; deriving it is an architectural goal whose feasibility is not assumed, PO-E.)
- **I5 Independence and non-interaction.** Edits in a batch are judged independently *and* jointly: an edit's evidence may not be produced by
  another edit in the same batch (e.g. a period added to create the sentence boundary that licenses the next capital); dependent chains take
  the lowest tier in the chain.
- **I6 Net-effect evaluation.** The decision is made on the minimal difference actually applied, not on the span the model chose (a
  whole-sentence span with a one-letter change is judged as that one letter), and the result must not introduce new surface defects
  (doubled/trailing whitespace, a mark following a mark).
- **I7 Evidence is deterministic and attributable.** Evidence is computed by code; model confidence/rationale never counts. Every autonomous
  application records *which rule* licensed it and the original span, so it is auditable and exactly reversible.
- **I8 Fail closed.** Unknown, unprovable, or resource-exceeded ⇒ not autonomous.
- **I9 Rule-first licensing.** A class becomes autonomous only through a pre-stated rule, a frozen conformance suite showing the Authority
  assigns the intended tier, and Product Owner sign-off — never because an observed model edit looks right.
- **I10 Ambiguity is never resolved autonomously.** If two readings differ in legal meaning, the system does not choose.

**What any autonomous category must demonstrate (the licence):** (a) the one-sentence rule; (b) the deterministic evidence predicate and its
inputs; (c) I1/I2 preserved by construction; (d) idempotence (re-applying the rule proposes nothing further); (e) a conformance corpus with
positives, near-miss negatives and hazards, assessed model-free; (f) rule-id attribution in the disposition; (g) PO acceptance of the rule's
residual risk. Absent any of these, the class is T3 or T4.

## 5. Taxonomy

Evidence predicates are *necessary* conditions for T2; none is implemented today unless stated.

| Class | Subclass | Tier | Evidence / reason |
|---|---|---|---|
| **Whitespace / typographic** | collapse repeated spaces; trim leading/trailing; remove space before closing punctuation; add space after sentence punctuation; NBSP→space; normalize quote/dash glyphs | **T1** | context-free rule; must be idempotent and leave no doubled/trailing space (I6). Quote/dash glyphs only outside tokens. |
| | add a space that yields a doubled/trailing space | **T4** | creates a new defect (I6) |
| | split a run-together token | **T3**; a curated deterministic lexicon may contribute evidence but **is not sufficient authorization for arbitrary splits** (PO-F; curatorship unresolved) | changes token sequence (I1) |
| | split a name-/identifier-shaped token; merge two tokens | **T4** | identity / token sequence |
| | introduce a line/paragraph break | **T4** | layout is user-triggered |
| **Punctuation** | terminal period at end of a segment that has no terminal mark | **potential T2 — presently non-autonomous** (PO-B) | needs deterministic end-of-segment/boundary evidence; addition only (I4); today's provenance gap (PO-E) |
| | internal sentence-boundary period | **T3** | changes segmentation |
| | comma (introductory adverb, list, serial) | **T3** | stylistic, not rule-derivable |
| | comma that can change clause scope (restrictive vs non-restrictive, conditions) | **T4** | meaning-sensitive |
| | question / exclamation mark | **T3** | statement vs question is information |
| | change or delete an existing mark (including dictated marks) | **T4** | I4 |
| | intra-token marks (apostrophe, hyphen, slash, abbreviation dots) | **T3** | inside words/identifiers |
| | quotation marks / brackets | **T3** | scope of quoted testimony |
| **Sentence-initial capitalization** | raise the first letter of a lowercase ordinary word after a verified sentence boundary or at segment start | **T1** where the deterministic formatter already owns it; for a model proposal **potential T2 — presently non-autonomous** (PO-B) | would need: boundary verified by code *including an abbreviation exclusion* ("viz.", "Rs.", "Smt."); all-lowercase alphabetic token; outside protected spans; not produced by another edit (I5). None of this evidence exists yet |
| | raise after an unverified/abbreviation period | **T3** | no boundary evidence |
| | lower a sentence-initial letter | **T4** | lowering changes a deliberate form |
| **Proper names / legal terms / titles** | raise a name- or place-shaped token | **T3**; never inferred from model judgment (PO-C). A *future verified per-matter vocabulary* may support a separately specified deterministic/T2 operation | identity assertion; no evidence source exists today |
| | raise a title/role ("Counsel", "Registrar", "Court", "State") | **T3**; not autonomous from model judgment (PO-C); any lexicon route would need its own specification | "the court" vs "the Court" differs in meaning |
| | month/day names (closed calendar lexicon) | **potential T2 — presently non-autonomous** (no predicate authorized) | closed set, no ambiguity; still needs a specified predicate (PO-A) |
| | lower any such token; acronym / identifier case; digit-bearing token case | **T4** | I2 |
| **Numeric / statutory forms** | spelled→digit, statute/section/witness forms | **T1 only inside the deterministic Phase-3 normalizers' grammar** | model proposals touching these: **T4** (protected spans) |
| | any digit, date, amount, case/exhibit number change; separators inside numeric structure | **T4** | I2 |
| **Grammatical** | agreement, tense, article, word choice | **never autonomous**; **future T3 suggestions** (PO-D) | wording change (I1); outside the V1 surface capability |
| | delete an immediately repeated word | **T3** | dictated word removed ("had had", "that that" are legitimate) |
| **Lexical substitution** | ASR homophone / mishearing repair, legal-term repair | **never autonomous**; **future T3** at most (PO-D) | recognition repair needs acoustic/vocabulary evidence (V2/V3 design) |
| **Ambiguity-resolving** | any edit whose purpose is to choose between readings (e.g. comma deciding "no he…" vs "no, he…") | **T4** | I10 |
| **Structural / multi-span** | independent T1/T2 edits on disjoint spans | each at its own tier | I5 |
| | dependent edits (one creates the evidence for another) | lowest tier in the chain | I5 |
| | wide span with a small net change | judged on net effect | I6 (the span is not the decision) |
| | edit touching a protected span, even if the net change is elsewhere | currently review-only/reject; acceptable fail-safe | conservative relative to I6 |

## 6. Ambiguous cases — decision procedure

For any proposed edit, evaluated by deterministic code:
1. **Protected?** Intersects a protected span / alters a record-sensitive token ⇒ T4 (resolved span: reject; unresolved/independent: review-only).
2. **Token-sequence invariant (I1)?** Case-folded, punctuation- and whitespace-stripped token sequence changed ⇒ T4 (T3 only for lexicon-backed recognition repair, which is outside V1).
3. **Which single dimension changed** (whitespace / punctuation / capitalization)? More than one, or a newline ⇒ T4.
4. **Class rule and evidence (§5).** Autonomous only if the class has a *pre-authorized* T2 predicate that code verifies (none is authorized today ⇒
   nothing is autonomous; T1 operations belong to deterministic processing); a T3-class edit ⇒ review-only in policy terms (no application path yet);
   a T4-class edit ⇒ reject.
5. **Net-effect and interaction checks (I5, I6).** Dependent or defect-creating ⇒ lowest applicable tier.
6. **Residual ambiguity (I10).** If two readings differ in legal meaning, or the evidence predicate is inconclusive ⇒ do not apply; at most surface the ambiguity.

Rule of thumb for borderline cases: *when an edit "looks obviously right" but no pre-stated rule derives it, it is T3.* Reasonableness is not
evidence (I9).

## 7. Comparison with the current autonomous policy

**What the code does (verified by reading `IntelligenceEditClassifier`, `AutonomousPermissionGate`, `IntelligenceSafetyAuthority`).** An edit is
autonomous iff: it overlaps no other proposal; it intersects no protected span; the classifier (a character-level diff of
`expectedSourceText`→`replacementText`, independent of any claimed category) calls it punctuation-only, capitalization-only or
whitespace-only (a newline-introducing edit is `other`); and the gate's five structural rules do not block (P-A non-routine punctuation,
P-B intra-token punctuation, W-A1 word *merge*, C-A2 lowering inside an acronym-shaped token, C-C case change inside a digit-bearing token).
`other` ⇒ rejected; a gate block or an unresolved/independent protected span ⇒ review-only; a resolved span ⇒ rejected. Model confidence is
never used. The accepted disposition records only the *classification*, not a rule or evidence.

**Provenance of the comparison — read before the table.** The current Authority implements the V1.14–V1.16 policy, which was validated against
corpora of dangerous *structural* edits. The tier policy in §A and §3–§5 did not exist when it was built. The probe below is therefore
**diagnostic evidence of the distance between the current Authority and the adopted framework**, not a list of defects against a specification the
code was ever required to meet. Nothing here says the current policy was wrong for its purpose.

**Probe (reproducible, model-free, illustrative — not a corpus).** `scripts/intelligence_v1_31_policy_probe.sh` runs 32 hand-authored edits
(new texts; none from the V1.23 benchmark or the V1.27 development corpus; no model produced any edit) through the real preflight and the
unmodified Authority and prints today's disposition beside the tier this document assigns. The per-class tier is a *proposal under the adopted
framework*; "T1/T2" rows read as *potential classes whose required deterministic processing/evidence does not yet exist* (PO-A, PO-B).

| id | class | tier | current disposition | relation |
|---|---|---|---|---|
| W1 | whitespace: collapse repeated space | T1 | autonomous (whitespaceOnly) | autonomous; adopted policy needs deterministic processing/evidence not yet present |
| W2 | whitespace: add trailing space (creates doubled space) | T4 | autonomous (whitespaceOnly) | broader than T4 (prohibited) |
| W3 | whitespace: split run-together token | T3 | autonomous (whitespaceOnly) | broader than T3 (review-only) |
| W4 | whitespace: split inside a name-shaped token | T4 | autonomous (whitespaceOnly) | broader than T4 (prohibited) |
| W5 | whitespace: merge two words | T4 | review-only (wordBoundaryMerged) | not autonomous (review-only; T4 prohibits autonomy) |
| W6 | whitespace: introduce a line break | T4 | rejected (unsupportedEditCategory) | agrees |
| P1 | punctuation: terminal period where none exists | T2 | autonomous (punctuationOnly) | autonomous; adopted policy needs deterministic processing/evidence not yet present |
| P2 | punctuation: comma after introductory adverb | T3 | autonomous (punctuationOnly) | broader than T3 (review-only) |
| P3 | punctuation: comma that changes clause scope | T4 | autonomous (punctuationOnly) | broader than T4 (prohibited) |
| P4 | punctuation: replace existing period with comma | T4 | autonomous (punctuationOnly) | broader than T4 (prohibited) |
| P5 | punctuation: delete an existing comma | T4 | autonomous (punctuationOnly) | broader than T4 (prohibited) |
| P6 | punctuation: question mark added | T3 | autonomous (punctuationOnly) | broader than T3 (review-only) |
| P7 | punctuation: replace period with question mark | T4 | autonomous (punctuationOnly) | broader than T4 (prohibited) |
| P8 | punctuation: intra-token apostrophe | T3 | review-only (nonRoutinePunctuationChanged) | agrees |
| C1 | capitalization: sentence-initial after a terminal period | T2 | autonomous (capitalizationOnly) | autonomous; adopted policy needs deterministic processing/evidence not yet present |
| C2 | capitalization: raise ordinary non-initial word (title) | T3 | autonomous (capitalizationOnly) | broader than T3 (review-only) |
| C3 | capitalization: raise a name-shaped token | T3 | autonomous (capitalizationOnly) | broader than T3 (review-only) |
| C4 | capitalization: lower a title | T4 | autonomous (capitalizationOnly) | broader than T4 (prohibited) |
| C5 | capitalization: lower an acronym | T4 | review-only (acronymCapitalizationLowered) | not autonomous (review-only; T4 prohibits autonomy) |
| C6 | capitalization: lower a sentence-initial letter | T4 | autonomous (capitalizationOnly) | broader than T4 (prohibited) |
| C7 | capitalization: raise after an abbreviation period | T3 | autonomous (capitalizationOnly) | broader than T3 (review-only) |
| C8 | capitalization: month name (closed lexicon) | T2 | autonomous (capitalizationOnly) | autonomous; adopted policy needs deterministic processing/evidence not yet present |
| C9 | capitalization: identifier case | T4 | review-only (intersectsIndependentlyProtectedSpan) | not autonomous (review-only; T4 prohibits autonomy) |
| N1 | numeric: change a digit inside an applied statutory normalization | T4 | rejected (intersectsResolvedSpan) | agrees |
| N2 | numeric: spelled amount to digits | T4 | rejected (unsupportedEditCategory) | agrees |
| N3 | numeric: change a date separator | T4 | review-only (intersectsIndependentlyProtectedSpan) | not autonomous (review-only; T4 prohibits autonomy) |
| G1 | grammar: delete a repeated word | T3 | rejected (unsupportedEditCategory) | stricter than T3 (rejected) |
| G2 | grammar: agreement | T4 | rejected (unsupportedEditCategory) | agrees |
| L1 | lexical: homophone substitution | T3 | rejected (unsupportedEditCategory) | stricter than T3 (rejected) |
| A1 | ambiguity: comma choosing a reading | T4 | autonomous (punctuationOnly) | broader than T4 (prohibited) |
| S1 | structural: whole-sentence span, one-letter capital | T2 | autonomous (capitalizationOnly) | autonomous; adopted policy needs deterministic processing/evidence not yet present |
| S2 | structural: span merely containing protected digits | T2 | review-only (intersectsIndependentlyProtectedSpan) | not autonomous (potential T1/T2 class) |

**Counts (diagnostic).** Of 32: current autonomy is *broader than T3* on **6** and *broader than T4* on **9** (15 together); **5** agree; **5** are
autonomous potential-T1/T2 classes whose required processing/evidence is not yet present; **1** potential-T2 edit is not autonomous (S2);
**4** T4 edits are review-only, i.e. not autonomous; **2** T3 edits are rejected where the framework only *scopes* a future suggestion. The 15
broader-than-policy cases concentrate in three places: whitespace splits and doubled/trailing whitespace; scope- or meaning-bearing punctuation
and alteration of existing marks; and capitalization that asserts or removes identity/role.

**Distance inventory (current Authority vs adopted framework) — diagnostic, not defect findings.**
- **D1 — whitespace-only is a coarse class.** It admits token *splits* (W3, W4) and edits that create doubled/trailing whitespace (W2); the gate
  blocks merges only. I1/I6 are not enforced by the class.
- **D2 — punctuation-only does not separate adding from altering, nor scope-bearing marks.** Adding a clause-scope comma (P3), a question mark (P6),
  replacing or deleting an existing mark (P4, P5, P7) and a reading-choosing comma (A1) are autonomous when the mark is in the routine set and not
  intra-token. There is no punctuation provenance (PO-E; feasibility not assumed), so a dictated mark cannot be told from an inserted one (I4).
- **D3 — capitalization-only does not separate sentence-initial from name/title assertion, nor raising from lowering.** Title/name raises (C2, C3),
  a raise after an abbreviation period (C7) and lowering a title or sentence-initial letter (C4, C6) are autonomous; only acronym lowering and
  digit-bearing tokens are guarded. No sentence-boundary or abbreviation evidence exists (PO-B), and no verified vocabulary (PO-C).
- **D4 — record-sensitivity is structural only.** Digits, normalized provisions and numeric structure are protected; names, titles, places,
  spelled dates and defined terms are not (the V1.12 finding stands).
- **D5 — interaction and attribution.** Proposals are judged independently except for pairwise overlap, so a dependent chain (I5) is not
  detected, and accepted edits carry the classification only, no rule id (I7). *(Read from code; the probe evaluates single edits.)*
- **D6 — conservative behavior (fail-safe).** A span that merely contains a protected number is review-only even when the net change is elsewhere
  (S2); acronym-lowering, identifier-case and date-separator edits (C5, C9, N3) and word merges (W5) are review-only where the framework prohibits
  autonomy — not autonomous, so consistent with it.
- **D7 — grammar/lexical proposals are rejected outright** (G1, L1), consistent with V1's surface-edit capability; the framework only reserves
  future T3 suggestion scope (PO-D) with no application path (PO-G).
- **Agreements.** `other` never autonomous; newline insertion; applied-normalization digits (N1); spelled-amount conversion (N2); grammar agreement
  (G2); intra-token apostrophe review-only (P8).
- **Autonomous potential-T1/T2 cases (W1, P1, C1, C8, S1).** Each is autonomous today without a deterministic evidence predicate and, for T1, outside
  the deterministic pipeline; under PO-A/PO-B they are classes for which authorization would first have to be *specified*.

## 8. Illustrations from earlier evidence (not used to derive or relabel anything)

Reading the framework against known cases, *after* it was written: a title/name raise like `registrar`→`Registrar` or a "However"-type raise is a
C2/C3/C1-class edit — T3 (or T2 only with the evidence above) — so under this policy it would be a *suggestion*, not an autonomous edit; the
`he denied`→`he denied ` trailing space is W2 (T4); a comma resolving "no he was not there" is A1 (T4); a whole-sentence span with a one-letter
net change is S1 (judged on net effect). This says nothing about whether those V1.23/V1.25/S3 labels or classifications were right: the frozen
ground truths and results are unchanged and remain defined by their own rules. The point is only that the *current Authority's* autonomy is
broader than the adopted framework would grant, a property of the deterministic layer that is independent of any model — and, per PO-H, the
safety definition is policy-invariant violation, which is distinct from the corpus answer-key measure those results used.

## 9. Implications for future evaluation design

1. **License by rule, not by a corpus's answer key (PO-H).** U1 ("final text outside the entry's licensed set") remains a valid *evaluation metric* but is
   not the Safety Authority's harm definition; it couples a measure to author-chosen corrections. A policy-based safety measure — *an autonomous edit violated invariant I1/I2/I3/I4/I5/I6* — can be computed on any text without
   hand-listing every acceptable edit, and is independent of what a given corpus happens to license.
2. **Model-free policy-conformance suite first.** Before any model is evaluated again, measure whether the *Authority* assigns the intended tier
   to a frozen, pre-registered catalog of edits per subclass (positives, near-misses, hazards). This isolates the deterministic layer, which S3
   showed is not where models fail but is where autonomy is defined.
3. **Report tiers separately; never blend.** Autonomous-applied, review-suggested, rejected and abstained outcomes are distinct; a T3 suggestion is
   useful only if the PO says suggestions count, and must not be folded into an autonomous recall.
4. **Form vs outcome stays separate** (V1.24): a wide span with the licensed net effect is not a safety event under I6.
5. **New confirmatory corpora are required for any tuning** (the development corpus is spent); stored-edit fixtures are the cheapest way to cover rare
   hazards model-free.
6. **Edit provenance (rule id, original span) belongs in the result type** so any later evaluation can ask "which rule licensed this?".

## 10. Remaining unresolved policy questions (after the adopted decisions)

The decisions in §A settle the framework; they leave these open, none implemented or assumed:
1. **Evidence predicates are unspecified.** No T2 class has an authorized, implementable predicate: sentence-boundary detection and the abbreviation
   exclusion list (PO-B); the form of a per-matter vocabulary and how it is verified and versioned (PO-C); the closed calendar-lexicon predicate; the
   exact end-of-segment rule for a terminal period.
2. **Punctuation provenance feasibility (PO-E).** Whether dictated, ASR-inserted and deterministic marks can be told apart at the Intelligence
   boundary is unknown; until known, I4 cannot be enforced and "addition only" is the only safe reading.
3. **Lexicon curatorship (PO-F).** Who curates, versions and audits a split lexicon, and what *else* must accompany lexicon evidence for a split to be
   authorized (the decision says lexicon evidence alone is insufficient).
4. **Review UX and acceptance semantics (PO-G).** Deferred; T3 has no application path.
5. **Which T1 operations are implemented, where, and with what idempotence/defect guarantees.** T1 is deterministic processing, outside Intelligence;
   its specification is not part of this milestone.
6. **How policy conformance is measured** (§11), including how an "evidence predicate verified by code" is itself tested.
7. **Dependent-edit and attribution semantics** (I5, I7): the result-type changes (rule id, original span, joint evaluation) needed to make them
   enforceable.
8. **Existing:** PO-2 minimum absolute usefulness and PO-3 production latency/resource thresholds.

## 11. Recommended next milestone — V1.32: specify the adopted policy and design its conformance evaluation (no implementation)

Before any Authority/gate change and **before any conformance corpus is created or frozen**, V1.32 should be a specification-and-design milestone:
1. **Freeze the adopted policy as a normative specification:** the tiers, invariants I1–I10 as amended by §A, the autonomy-licence requirements, and
   the explicit statement that no T2 class is currently authorized.
2. **Define the evidence-predicate interface** every future T2 class must satisfy (inputs, determinism, fail-closed behavior, attribution, idempotence,
   resource bounds) *without* authorizing any particular predicate.
3. **Enumerate which evidence predicates remain underspecified** (list in §10.1) and what information would specify each — marking them as blockers for
   a frozen corpus rather than guessing them.
4. **Design the model-free conformance evaluation:** what a case is (source, edit, expected tier, rule/predicate reference, rationale), tier-level
   and subclass-level reporting without blending, pre-registered disjointness from every existing corpus (V1.27 overlap rules), how policy-invariant
   violations (PO-H) are measured independently of corpus answer keys, how a "not yet authorized" T2 class is represented (expected: non-autonomous),
   and what exact statements the evaluation may and may not support.
5. **Decide the readiness gate for the corpus:** the conformance corpus is created and frozen only once the classes it covers have unambiguous
   expected tiers. Classes with open predicates are either excluded or labelled provisional by an explicit, pre-registered rule.

V1.32 changes no code, creates no corpus, and runs no model. A later, separately authorized milestone would build and freeze the conformance corpus
(the revised form of the earlier "V1.32" idea), and only after that and Product Owner review would any change to the Authority or gate be considered.

## 12. What this document does not establish

That the per-class tier assignments are final (they are proposals under the adopted framework, and the T2 predicates are unspecified); that any evidence
predicate is implementable at acceptable cost or false-block rate; that punctuation provenance is derivable; that the current Authority is defective
(it implements the V1.14–V1.16 policy as designed); or anything about any model. The probe is 32 diagnostic illustrations, not a measurement of coverage.
