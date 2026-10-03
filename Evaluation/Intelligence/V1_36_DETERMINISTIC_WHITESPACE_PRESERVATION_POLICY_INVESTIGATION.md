# Intelligence V1.36 — Deterministic whitespace preservation policy investigation (DP-2)

**Investigation and specification only.** No model was run; no production code, Authority, gate or contract changed; **no whitespace canonicalizer was implemented**; **DP-2 is not promoted to T1**; no conformance corpus was created;
Intelligence policy is unchanged; **nothing is authorized.** Authority: V1.31–V1.35 (invariants I1–I10, PO-A–PO-K, ownership prerequisite `[O-1]`–`[O-7]`, PO-P: general whitespace normalization belongs to deterministic processing *subject to a separately specified
preservation policy*, and PO-P's statement that ownership is not authorization or implementation). Evidence: the repository source (read) and `scripts/intelligence_v1_36_whitespace_probe.sh` (executes the two deterministic components that compile standalone — legal normalization and the Safety Authority).
V1.32, V1.34 and V1.35 are byte-unchanged (pinned by `scripts/check_intelligence_v1_36_whitespace_policy_consistency.sh`).

**Status of what follows.** §3–§6 are a **proposed** preservation policy for the deterministic whitespace owner. It becomes normative only if the Product Owner adopts it (PO-S, §10); until then it is a proposal derived from the adopted invariants and product semantics, not a decision.
Statements about the app-target stages (filler removal, dictionary, spoken-punctuation rendering) are **read from source and not executed**; statements about legal normalization and the Authority are **executed** (§7).

## 1. Premises (from product semantics and adopted policy)

- **P-1 What the traced pipeline does and does not produce (narrowed).** In the **currently traced dictation pipeline**, **no identified mechanism intentionally produces a run of two or more `U+0020` between ordinary tokens.** Whitespace between tokens is the separator the provider inserts;
  the only whitespace the pipeline deliberately *authors* comes from explicit spoken formatting commands (`SpokenFormattingAction`: new line, new paragraph, tab, space), which the spoken-punctuation renderer emits only as its **enumerated whitespace forms** — exactly `\n`, `\n\n`, `\t` and a single `U+0020` — after removing the preceding horizontal whitespace and skipping the
  following horizontal whitespace (`render`, ASRService+SpokenPunctuationFormatting.swift:933–1003). **This is a statement about the traced pipeline, not a claim that no dictation mechanism could ever express multiple spaces**: other stages (provider output, the user-authored custom dictionary, future stages, content outside the traced path) are not shown never to produce such a run, only
  not to do so *intentionally* in what was traced.
- **P-2 Origin is lost.** After rendering, command-generated whitespace is indistinguishable from provider-generated whitespace of the same character (V1.33 §3, §4). Any rule that may alter tabs or newlines therefore cannot know whether it is altering an authored command.
- **P-3 Unicode whitespace is not interchangeable.** U+0020, tab, newline, U+00A0 (no-break), U+2009 and other spaces, and zero-width/join controls (which Indic scripts use for conjunct rendering and which are *not* whitespace) differ in layout and sometimes in meaning. Equivalence is **not assumed**.
- **P-4 Repeated whitespace is not assumed erroneous.** A run is only a candidate for canonicalization where the premise (P-1) and the operation's placement give no reason to think it carries dictated meaning.
- **P-5 Segment edges are acquisition boundaries** (PO-I). Whitespace at the start or end of a session's text concerns joining with text outside the segment, which the continuous-dictation formatter handles after the hand-off.

## 2. Where whitespace is created or changed today (current behavior; not policy)

| Stage (order) | Whitespace effect | Evidence |
|---|---|---|
| Provider (`transcribeFinal`) | opaque; Whisper trims leading/trailing whitespace and newlines of its text; others unknown | WhisperProvider.swift:321 (read) |
| Filler removal (default on) | splits on **U+0020 only**, drops filler tokens (with their attached punctuation), re-joins with **one** U+0020: collapses every run of U+0020, trims leading/trailing U+0020 of the whole text, **even when no filler is present**; leaves tabs, newlines, NBSP; collapses spaces adjacent to a newline too (indentation made of spaces becomes one space) | ASRService.swift:5759 (read, not executed) |
| Custom dictionary | user regex trigger→replacement; a whitespace-only replacement consumes `[ \t]*` around the trigger | ASRService.swift:5790, :5818 (read) |
| Spoken-punctuation rendering (twice) | non-command text verbatim; around a command removes preceding **horizontal** whitespace (`CharacterSet.whitespaces`, which includes tab and NBSP), skips following horizontal whitespace, emits the command's own whitespace | SpokenPunctuationFormatting.swift:933–1020 (read) |
| Spoken-send (default off) | strips a trailing send phrase and trailing whitespace/punctuation | SpokenSendParser.swift:52 (read) |
| Legal normalization | **executed (§7 A):** phrases match across *any* whitespace between their words and the matched span is rewritten with single U+0020; whitespace outside matched spans is preserved exactly | probe A |
| Presentation formatters (after the hand-off) | continuous-dictation spacing adds a leading/trailing space; terminal-autocomplete spacing | ASRService.swift:5905 (read) |

## 3. Proposed normative whitespace taxonomy

Four dispositions: **(1) must preserve**, **(2) potentially canonicalizable under a deterministic rule**, **(3) ambiguous / context-dependent (so preserved)**, **(4) outside the proposed whitespace owner's scope**.

| Id | Class | Disposition | Rationale from product semantics and invariants |
|---|---|---|---|
| **WS-1** | a single U+0020 between two tokens | **(1) must preserve** | it is the token separator; removing it merges tokens (I1) |
| **WS-2** | a run of ≥2 U+0020 between two non-whitespace characters on one line | **(2) potentially canonicalizable** | in the traced pipeline no identified mechanism *intentionally* produces it (P-1), so its run length is not known to carry dictated meaning; token sequence unchanged (I1); information-neutrality rests on that premise and on the placement precondition of §5 (I3). Conditions in §5 (DP-2a) |
| **WS-3** | leading/trailing whitespace of the whole text | **(4) outside scope** (presentation-owned segment-junction spacing) *— by analogy to PO-K; confirmation requested (PO-T)* | P-5; the continuous formatter adds/depends on it |
| **WS-4** | tab characters | **(1) must preserve** | authored by the tab command or provider layout; origin lost (P-2) |
| **WS-5** | newline and paragraph boundaries (`\n`, `\n\n`) | **(1) must preserve** | authored layout (P-2); changing them changes record structure |
| **WS-6** | indentation/alignment (spaces or tabs after a newline) | **(1) must preserve** | possibly deliberate layout; a run here is *not* WS-2 (it adjoins a newline, not two non-whitespace characters) |
| **WS-7** | spaces before a newline (line-end spaces) | **(3) ambiguous → preserve** | invisible in most displays but can be a Markdown hard line break; information-neutrality unproven (I3, I10) |
| **WS-8** | whitespace adjacent to punctuation (a space before `. , ; : ? !`; a missing space after) | **(3) ambiguous → preserve** | depends on the mark's role (sentence-final, abbreviation, identifier/date separator, quotation); needs mark-role evidence that does not exist (E3) and interacts with punctuation provenance; deleting or inserting a space inside `Cr.P.C`, `s/o`, `12 . 07` changes record structure (I2) |
| **WS-9** | whitespace inside or touching protected spans (resolved/declined normalizations, numeric structure, identifiers, acronyms) and between digit-bearing tokens | **(1) must preserve** (the normalizer owns the interior of its own spans) | I2; V1.11/V1.13 |
| **WS-10** | whitespace generated by explicit spoken formatting commands | **(1) must preserve** | authored (P-1); I4 analogue |
| **WS-11** | non-U+0020 whitespace and format characters (U+00A0, U+2009, U+3000, zero-width/join controls, …) | **(1) must preserve** | P-3: not interchangeable; join controls are not whitespace and must never be touched |
| **WS-12** | whitespace effects produced as a side effect of other stages (filler removal, dictionary, punctuation conversion, legal normalization) | **(4) outside scope as a *source*; the *results* are inputs** to the whitespace owner | those stages own their own content changes; their whitespace side effects are current behavior, not policy (§7) |
| **WS-13** | composition of several individually plausible whitespace edits | **governed by WP-6/WP-7** (single-pass canonical function; idempotent; stage-order constrained) | I5, D-1…D-5 |

## 4. Proposed preservation invariants

- **WP-1 Token-sequence invariance.** A whitespace transformation leaves the case-folded, punctuation- and whitespace-stripped token sequence unchanged. It never merges, splits, inserts or deletes tokens. *(I1)*
- **WP-2 Character scope.** Only `U+0020` is eligible for canonicalization. Every other whitespace character and every format/join control MUST be preserved. *(P-3)*
- **WP-3 Authored layout is preserved.** Tabs, newlines, paragraph breaks, indentation and line-end spaces MUST NOT be changed, because explicit-command whitespace cannot be told from provider whitespace (P-2). *(I4 analogue)*
- **WP-4 Record-token protection.** No change inside, across, or between digit-bearing tokens of a protected span, numeric structure, identifier, acronym or abbreviation; the interior of a normalizer-owned span belongs to that normalizer. *(I2)*
- **WP-5 Information neutrality.** A canonicalization must be derivable by a one-sentence rule independent of meaning, whose premise (P-1) is evidenced. If the information content of the whitespace is unknown, it is preserved. *(I3, I10)*
- **WP-6 Single-pass canonical function.** The transformation is a pure function of the text that is **idempotent** and **creates no new defect** (no doubled, leading or trailing whitespace; no token merge/split), and it is judged on net effect, not on any span. *(I5, I6)*
- **WP-7 Composition and placement.** It is applied after every stage that can create runs (dictionary, spoken punctuation, filler removal) and in a position that does **not invalidate legal-normalization provenance coordinates** (V1.10: ranges index the input of their pass); any later content-changing stage re-triggers it or the result is not claimed canonical. Edits it makes are independent of any other whitespace-affecting stage. *(D-1…D-5)*
- **WP-8 Attribution and reversibility.** Any implementation records the rule id/version and the original run so the change is auditable and exactly reversible. *(I7; a requirement on a future implementation, not on the pipeline today)*
- **WP-9 Segment edges are out of scope** (WS-3) until their ownership is decided (PO-T).
- **WP-10 Ambiguity preserves.** Where a class is ambiguous (WS-7, WS-8) or a context observable is missing, the text is left unchanged. *(I10; fail closed)*

## 5. Candidate deterministic transformation (a possible narrow subset of DP-2; not promoted, not authorized, not implemented)

**DP-2a — ordinary-space run collapse.** *Replace each maximal run of two or more `U+0020`, whose two neighbours are non-whitespace characters on the same line, by a single `U+0020`.*

Conditions that bound it (each from §4): the run consists **only** of `U+0020` (WP-2); neither neighbour is whitespace, so a run touching a newline, a tab or a text edge is **not** this rule (WP-3, WP-9); the run is outside any protected span and between two tokens at least one of which is not digit-bearing (WP-4); it changes no token (WP-1). It is a function of the text and the protected spans only — both already
available (E1) It is idempotent and creates no new defect (WP-6).

**Rationale and precondition (clarified).** DP-2a remains a *future deterministic T1 candidate*. Its lack of origin provenance is acceptable **only if** the operation's eventual placement and specification establish that **intentional multi-space input cannot reach it**, or supply **equivalent deterministic evidence**
(for example by specifying that it runs only on text that has passed through stages known not to carry intended multi-space input, or by recording the origin of any run). **V1.36 itself does not establish that implementation precondition**: P-1 describes the traced pipeline; it does not prove that no intentional run can arrive at a given insertion point. The rule's justification therefore remains conditional on the
placement/specification work that a later, separately authorized milestone would do.

**Evaluated and rejected as candidates** (kept as preserved or ambiguous, with the reason): trimming spaces before a newline (Markdown hard break; WS-7); stripping or normalizing indentation (WS-6); replacing NBSP/thin/ideographic spaces by U+0020 (WS-11, P-3); removing the space before, or inserting one after, punctuation (WS-8: role evidence missing; breaks abbreviations such as `Cr.P.C`); collapsing multiple newlines (WS-5);
trimming segment edges (WS-3, out of scope); inserting a missing space or splitting a run-together token (changes the token sequence; that is A5-S/UO-2, not whitespace normalization).

## 6. Explicit exclusions

Anything that changes tabs, newlines, paragraph structure, indentation, line-end spaces, non-U+0020 whitespace, format/join controls, punctuation-adjacent spacing, spaces inside protected/owned spans or between digit-bearing tokens, segment-edge whitespace, or the token sequence. Executing explicit spoken formatting commands is a different operation (command execution) and is not
whitespace *normalization*.

## 7. Evidence: executed probe (`scripts/intelligence_v1_36_whitespace_probe.sh`; illustrative, new synthetic texts, no model, not a corpus)

### A. Legal normalization on whitespace variants (real `LegalDictationProcessor`)

| id | note | input | output | output == input |
|---|---|---|---|---|
| L1 | baseline: single spaces | `the·court·cited·section·three·zero·two·IPC·today` | `the·court·cited·Section·302·IPC·today` | false |
| L2 | doubled spaces outside the phrase | `the·court·cited··section·three·zero·two·IPC··today` | `the·court·cited··Section·302·IPC··today` | false |
| L3 | doubled space inside the phrase (keyword/number) | `the·court·cited·section··three·zero·two·IPC·today` | `the·court·cited·Section·302·IPC·today` | false |
| L4 | doubled spaces between spoken digits | `the·court·cited·section·three··zero··two·IPC·today` | `the·court·cited·Section·302·IPC·today` | false |
| L5 | tab inside the phrase | `the·court·cited·section\tthree·zero·two·IPC·today` | `the·court·cited·Section·302·IPC·today` | false |
| L6 | newline inside the phrase | `the·court·cited·section\nthree·zero·two·IPC·today` | `the·court·cited·Section·302·IPC·today` | false |
| L7 | NBSP inside the phrase | `the·court·cited·section\u00A0three·zero·two·IPC·today` | `the·court·cited·Section·302·IPC·today` | false |
| L8 | leading/trailing spaces around the text | `··the·court·cited·section·three·zero·two·IPC·today··` | `··the·court·cited·Section·302·IPC·today··` | false |
| L9 | layout away from any rule: newline + indentation + tab | `first·point\n····second·point\n\tthird·point` | `first·point\n····second·point\n\tthird·point` | true |
| L10 | doubled space inside a witness reference | `the·PW··two·witness·was·examined` | `the·PW-2·witness·was·examined` | false |

### B. Current Authority disposition of whitespace edits (real, unmodified)

| id | edit | disposition |
|---|---|---|
| E1 | collapse two ordinary spaces: `read··the` → `read·the` | autonomouslyAccepted(whitespaceOnly) |
| E2 | add a trailing space (creates a doubled space): `he·denied` → `he·denied·` | autonomouslyAccepted(whitespaceOnly) |
| E3 | tab to space: `one\tcolumn` → `one·column` | autonomouslyAccepted(whitespaceOnly) |
| E4 | NBSP to ordinary space: `of\u00A0Monday` → `of·Monday` | autonomouslyAccepted(whitespaceOnly) |
| E5 | remove the space before a full stop: `served·.` → `served.` | autonomouslyAccepted(whitespaceOnly) |
| E6 | remove line indentation (spaces after a newline): `····second` → `second` | autonomouslyAccepted(whitespaceOnly) |
| E7 | remove two trailing spaces before a newline: `line··` → `line` | autonomouslyAccepted(whitespaceOnly) |
| E8 | insert a space inside an abbreviation: `Cr.P.C` → `Cr.·P.C` | autonomouslyAccepted(whitespaceOnly) |
| E9 | collapse a doubled space between digit groups: `12··34` → `12·34` | reviewOnly(ReviewReason.intersectsIndependentlyProtectedSpan) |
| E10 | thin space to ordinary space: `of\u2009five` → `of·five` | autonomouslyAccepted(whitespaceOnly) |

**What the executed evidence shows.**
- **Legal normalization is whitespace-tolerant inside a phrase and whitespace-preserving outside it.** A tab, a newline, an NBSP or a doubled space between the words of a rule's phrase is accepted, and the owned span is rewritten with single spaces (L3–L7, L10); doubled spaces, leading/trailing spaces and layout (newline, indentation, tab) *outside* spans are returned exactly (L2, L8, L9). So the normalizer owns whitespace *inside* its spans (consistent with WP-4) and can silently drop a newline or tab that sat between the words of a matched phrase.
- **The current Authority accepts most whitespace-only edits autonomously**, including tab→space (E3), NBSP/thin-space→space (E4, E10), removing indentation (E6), removing line-end spaces (E7), inserting a space inside an abbreviation (E8), removing the space before a full stop (E5) and adding a trailing space (E2). Only the edit between digit groups is held (E9, protected numeric structure).

## 7A. Discovered deterministic-boundary issue DB-1 (legal normalization; not a DP-2 defect; not repaired here)

The executed probe shows that **a matched legal-normalization span can consume embedded tab or newline whitespace**: a tab, a newline or an NBSP between the words of a matched phrase (L5, L6, L7) is replaced when the span is rewritten, so layout that sat *inside* the phrase is lost. This is a property of the legal normalizer's owned-span semantics, discovered while mapping
whitespace; it is **not** a defect of DP-2 or of the proposed whitespace policy (which leaves the interior of normalizer-owned spans to the normalizer, WP-4), and it is **not repaired, specified away or classified as correct or incorrect in V1.36**. It is recorded as an open boundary question for the deterministic-processing specification: whether a normalizer span may consume authored
layout whitespace, and whether such matches should instead decline. No change is made; nothing is authorized.

## 8. Comparison with the current pipeline (current behavior vs the proposed policy; nothing here validates or condemns existing behavior)

| Current behavior | Relation to the proposed policy |
|---|---|
| Filler removal collapses runs of U+0020 between tokens | **coincides in effect with DP-2a** for that case — but only as a side effect of a content-deleting stage, unspecified as an operation, and *unconditional on fillers being present* |
| Filler removal collapses space runs adjacent to a newline (indentation) and trims leading/trailing U+0020 of the text | **goes beyond DP-2a**: touches WS-6 (indentation made of spaces) and WS-3 (segment edges). Deterministic ≠ validated: it would not satisfy WP-3/WP-9 as stated |
| Filler removal leaves tabs, newlines, NBSP | consistent with WP-2/WP-3 |
| Custom dictionary whitespace replacement consumes `[ \t]*` | touches tabs (WP-2/WP-3); user-authored data, not a policy statement |
| Spoken-punctuation rendering | preserves unrelated text verbatim; removes horizontal whitespace (incl. tab/NBSP) *adjacent to a command* and emits authored whitespace: consistent with WS-10; the removal of adjacent tab/NBSP is a command-scope effect not covered by this policy |
| Legal normalization | owns whitespace inside matched spans; outside, preserved (consistent with WP-4/WP-9); it can drop a newline or tab *inside* a matched phrase — **recorded as discovered issue DB-1 (§7A)**, not a DP-2 defect, not repaired |
| Authority permits whitespace edits autonomously (probe B) | **mismatch with PO-P**: general whitespace normalization is now deterministic-processing-owned, so under `[O-3]` Intelligence should neither apply nor propose it; the Authority predates that ownership. Several permitted edits (E3, E4, E6, E7, E8, E10) violate WP-2/WP-3/WP-4/WP-5 as proposed. Diagnostic only; no change is made |
| Presentation spacing (continuous, terminal) | segment-junction spacing, presentation-owned (WS-3); not touched by this policy |

## 9. Can DP-2 be narrowed into a specifiable T1 candidate?

**Yes — DP-2a is sufficiently specified to be a *future T1 candidate*.** It is stated as a function with a closed domain (a pure-`U+0020` run between two non-whitespace characters on one line), explicit exclusions, no model or external data, observables that already exist (the text and protected spans), idempotence, and no recorded provenance of origin — which is acceptable only under the placement/equivalent-evidence precondition of §5 (not established here). The rest of DP-2 (WS-3…WS-13 other than WS-2) is **preserved,
ambiguous, or out of scope** and is not specifiable as a canonicalization. DP-2a is **not promoted** (T1 membership needs a separate normative specification of the deterministic pipeline and the repository's normalization-family design review), **not authorized, not implemented**, and depends on the Product Owner adopting the policy and the narrowed premise P-1 (PO-S) **and** on the placement/specification precondition of §5, which this investigation does not establish.

## 10. Unresolved Product Owner decisions (genuinely necessary)

- **PO-S** — adopt (or amend) the preservation policy of §3–§6, in particular the narrowed premise P-1 (in the traced pipeline no identified mechanism intentionally produces a run of two or more ordinary spaces between tokens; not a claim about all possible mechanisms).
- **PO-T** — ownership of **segment-edge (junction) whitespace**: presentation-owned (as proposed by analogy to PO-K) or part of the deterministic whitespace owner.
- **PO-U** — whether any non-`U+0020` whitespace class (tab runs, NBSP, other spaces) should *ever* be canonicalized by any owner; the proposal is **never** (WP-2).
- Carried: PO-G, PO-L (not needed here), PO-2, PO-3. Placement relative to legal normalization is an architectural requirement (WP-7), not a decision.

## 11. What would have to be true before a whitespace conformance suite could be frozen (nothing is built or frozen now)

1. The Product Owner has adopted the preservation policy (PO-S) and decided PO-T and PO-U, and the adopted policy is frozen as a versioned normative specification.
2. The candidate rule (DP-2a, or whichever subset is adopted) is specified as a **function** — domain, Unicode scope, exclusions, stage placement and its relation to normalization provenance (WP-7) — so every expected output is derivable from the specification text alone, as an **exact string**.
3. An **independent invariant checker** is specified for WP-1…WP-6 (token sequence, record tokens, layout preservation, idempotence, no-new-defect), implemented separately from the transformation under test.
4. The conformance design of V1.32 Part II is adapted for a deterministic function (expectations are exact outputs, not tiered autonomy): positive, *preserve* (every WS class whose disposition is (1), (3) or (4) must be shown unchanged), boundary, Unicode (each non-U+0020 class), composition/idempotence and provenance-coordinate cases; reported by class, never blended.
5. Disjointness from every existing corpus under the V1.27 overlap rules, with the check shown sensitive.
6. Ambiguous classes receive only *preserve* expectations that the adopted policy actually decides; undecided classes are excluded rather than labelled.
7. The deterministic-pipeline design review required for any new normalization family has been completed, and the conformance-readiness conditions of V1.32 §23 that apply are met.

## 12. Smallest justified next milestone

**V1.37 — Product Owner decision record on PO-S, PO-T and PO-U (documentation only).** Everything in §9 depends on adoption of the policy and the narrowed premise P-1 and on the two scope decisions; none needs new evidence (the DP-2a placement precondition of §5 is a specification task for a later milestone). If adopted, the following milestone would be the specification of DP-2a as a deterministic-pipeline function (still without implementation or corpus). An optional, independent evidence step — executing the app-target stages
(filler removal, dictionary, spoken-punctuation rendering) in the app's own test target to turn §2's read-from-source statements into executed ones — is *not* required for the decision and is not recommended before it.

## 13. Product Owner decisions received after this investigation — recorded for the next version, **not** part of the proposed policy above

These decisions were communicated after §3–§12 were written. They are **recorded here for the next version/decision record and are deliberately not folded into the proposed policy of §3–§6**, which stays as the investigation's proposal; the next version will incorporate them as adopted text.

- **PO-S:** adopt the proposed whitespace policy **subject to the narrowed P-1 clarification** (traced-pipeline statement only; DP-2a's origin-provenance gap acceptable only under the placement/equivalent-evidence precondition of §5).
- **PO-T:** **segment-edge whitespace remains outside DP-2 ownership.**
- **PO-U:** **non-U+0020 whitespace is preserve-only under the current policy**; any future canonicalization requires a **separately specified operation and justification**.

Not decided by these: DB-1 (legal-normalizer consumption of embedded layout whitespace), the DP-2a placement specification, promotion of DP-2a to T1, authorization or implementation of anything.
