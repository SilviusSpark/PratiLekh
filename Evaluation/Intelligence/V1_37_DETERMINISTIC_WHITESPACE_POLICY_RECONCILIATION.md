# Intelligence V1.37 — Deterministic whitespace policy reconciliation (policy specification v1.3 addendum)

**Documentation and specification only.** No model was run; no production code, Authority, gate or contract changed; no whitespace processing was implemented; **nothing is promoted to T1**; **no operation is authorized**; no conformance corpus was created; DB-1 was not investigated or fixed;
production behavior was not inspected (existing V1.36 citations are reused as written). This is a **new prospective policy version** — *v1.3 = v1.2 (V1.35 addendum) + this addendum*. V1.32 (v1.0), V1.34 (v1.1), V1.35 (v1.2) and **V1.36 are left byte-unchanged** and remain historical; their text is incorporated by reference where this addendum
does not supersede it. `scripts/check_intelligence_v1_37_whitespace_reconciliation_consistency.sh` verifies consistency and the byte-integrity of all four.

## 0. Versioning and what this addendum supersedes

0.1 V1.32, V1.34, V1.35 and V1.36 remain historical and unedited (bytes pinned). `[WA-1]`
0.2 **v1.3 supersedes v1.2 prospectively** for: the deterministic-work ledger entry DP-2 (V1.35 §4.2) and the capability-map entry M2 (V1.35 §7), which this addendum replaces (§5, §6); and it **adopts** the V1.36 whitespace preservation policy (§1). Everything else in v1.2 (the ownership reconciliation, the empty Intelligence register, the other ledgers,
the other capability-map entries, the invariants and the ownership prerequisite) is carried over unchanged and by reference. `[WA-2]`
0.3 Historical ids are preserved: V1.35's **DP-2** and V1.36's **DP-2a** remain traceable (§4). No state is inherited through the retirement of DP-2; none existed. No prior experiment or result is rescored. `[WA-3]`

## 1. Adopted decisions (normative from v1.3)

| # | Decision |
|---|---|
| **PO-S** | **Adopt the V1.36 whitespace preservation policy** (premises P-1…P-5, taxonomy WS-1…WS-13, invariants WP-1…WP-10, the DP-2a definition and the exclusions of V1.36 §3–§6) **with its narrowed P-1.** P-1 is evidence about the **currently traced pipeline only** and **does not establish that intentional multiple-`U+0020` input can never reach a future operation.** |
| **PO-T** | **Segment-edge whitespace is outside DP-2 ownership.** |
| **PO-U** | **Non-`U+0020` whitespace is preserve-only under the current policy.** Any future canonicalization requires a **separately specified operation and justification.** |

**1.1 P-1, as adopted (verbatim from V1.36 §1).**

> - **P-1 What the traced pipeline does and does not produce (narrowed).** In the **currently traced dictation pipeline**, **no identified mechanism intentionally produces a run of two or more `U+0020` between ordinary tokens.** Whitespace between tokens is the separator the provider inserts;
>   the only whitespace the pipeline deliberately *authors* comes from explicit spoken formatting commands (`SpokenFormattingAction`: new line, new paragraph, tab, space), which the spoken-punctuation renderer emits only as its **enumerated whitespace forms** — exactly `\n`, `\n\n`, `\t` and a single `U+0020` — after removing the preceding horizontal whitespace and skipping the
>   following horizontal whitespace (`render`, ASRService+SpokenPunctuationFormatting.swift:933–1003). **This is a statement about the traced pipeline, not a claim that no dictation mechanism could ever express multiple spaces**: other stages (provider output, the user-authored custom dictionary, future stages, content outside the traced path) are not shown never to produce such a run, only
>   not to do so *intentionally* in what was traced.

`[WA-4]`

**1.2 Policy adoption is not candidate readiness.** PO-S adopts a *preservation policy* — what whitespace must be preserved and the one narrow class that may become a candidate. It does **not** make any operation a T1 member, authorize it, implement it, or satisfy any blocker of §4. In particular **PO-S does not satisfy the DP-2a placement blocker**: a narrowed P-1 about the traced
pipeline cannot establish that intentional multi-space input cannot reach a *future* operation at its insertion point. `[WA-5]`

**1.3 What PO-T and PO-U decide and do not decide.** PO-T excludes segment-edge whitespace (leading/trailing whitespace of a session's text, V1.36 WS-3) from DP-2 ownership; it does **not** assign an owner (current behavior — junction spacing in the presentation layer, incidental trimming by filler removal — is neither validated nor authorized; the ownership of that whitespace is not decided here). PO-U makes every
whitespace character other than `U+0020` (tab, newline, NBSP, thin/ideographic spaces, etc.) **preserve-only**; "preserve-only" means no owner may alter it under this policy, and a future change requires a new, separately specified and justified operation entering the ledger through the ownership and review process. `[WA-6]`

## 2. Final whitespace ownership and preservation taxonomy (normative at v1.3)

Dispositions: **PRESERVE-ONLY** (no operation may alter it under this policy); **AMBIGUOUS → PRESERVE**; **OUTSIDE DP-2 OWNERSHIP**; **CANDIDATE (conditional)** (potentially canonicalizable, but not ready, §4).

| Id | Class | Final disposition | Basis |
|---|---|---|---|
| WS-1 | a single `U+0020` between two tokens | **PRESERVE-ONLY** | token separator (I1) |
| WS-2 | a run of ≥2 `U+0020` between two non-whitespace characters on one line | **CANDIDATE (conditional) — DP-2a**; *blocked, §4* | V1.36 WS-2; premise P-1 narrowed |
| WS-3 | leading/trailing whitespace of the whole text (segment edges) | **OUTSIDE DP-2 OWNERSHIP** (PO-T); no owner assigned here | PO-T, PO-I |
| WS-4 | tab characters | **PRESERVE-ONLY** | PO-U; authored/provider layout, origin lost |
| WS-5 | newline and paragraph boundaries | **PRESERVE-ONLY** | PO-U; authored layout |
| WS-6 | indentation/alignment (whitespace after a newline) | **PRESERVE-ONLY** | WP-3; adjoins a newline, so not WS-2 |
| WS-7 | spaces before a newline (line-end spaces) | **AMBIGUOUS → PRESERVE** | may be a Markdown hard break; I3/I10 |
| WS-8 | whitespace adjacent to punctuation | **AMBIGUOUS → PRESERVE** | depends on the mark's role; abbreviations/identifiers (I2) |
| WS-9 | whitespace inside or touching protected spans, or between digit-bearing tokens | **PRESERVE-ONLY** | I2; the interior of a normalizer-owned span belongs to that normalizer |
| WS-10 | whitespace generated by explicit spoken formatting commands | **PRESERVE-ONLY** | authored; I4 analogue |
| WS-11 | every non-`U+0020` whitespace character and every format/join control | **PRESERVE-ONLY** | PO-U; P-3 |
| WS-12 | whitespace side effects of other stages (filler removal, dictionary, punctuation conversion, legal normalization) | **OUTSIDE DP-2 OWNERSHIP as a source**; their results are inputs | each stage owns its own content changes; current side effects are behavior, not policy |
| WS-13 | composition of several individually plausible whitespace edits | **governed by WP-6/WP-7** | I5, D-1…D-5 |

The invariants **WP-1…WP-10 of V1.36 §4 are adopted as written**, with WP-2 read together with PO-U (only `U+0020` is *ever* eligible, and eligibility is not authorization) and WP-9 now decided by PO-T. `[WA-7]`

## 3. DP-2 reconciled

3.1 **The broad DP-2 concept ("general whitespace/typographic normalization", V1.35 DP-2 and V1.34 M5) is retired.** It is not an operation: the whitespace space is classified by §2, and every class except WS-2 is preserve-only, ambiguous/preserve, outside ownership, or requires a *separately specified future operation* (PO-U). `[WA-8]`
3.2 **DP-2a is the sole remaining deterministic whitespace candidate** arising from this policy. Definition (V1.36 §5, unchanged): *replace each maximal run of two or more `U+0020`, whose two neighbours are non-whitespace characters on the same line, by a single `U+0020`*, subject to the exclusions and invariants adopted in §1–§2: the run is pure `U+0020`; neither neighbour is whitespace; it is outside protected spans; it is not
between two digit-bearing tokens; it changes no token. Owner: deterministic processing (PO-P). `[WA-9]`
3.3 **DP-2a is, at v1.3: not T1; not authorized; not implemented; without a frozen conformance suite; BLOCKED** on the specification and placement items of §4. Nothing in the adoption of the policy changes any of those facts. `[WA-10]`

## 4. DP-2a blockers (none satisfied by this addendum)

- **B-1 Exact deterministic function specification.** The function must be specified exactly: domain and the definition of "same line" (including which characters terminate a line — `\n`, `\r`, and any other line separators), the definition of "digit-bearing" (Unicode decimal digits, per V1.13), the exact set of excluded spans and how they are identified, treatment of runs at text start/end (excluded by WS-3/PO-T), and the exact output for every input. *Does not exist.*
- **B-2 Placement specification establishing the intentional-input precondition.** The operation's position in the deterministic pipeline must be specified so that it **establishes that intentional multi-space input cannot reach it**, or the specification must supply **equivalent deterministic evidence** (for example recording the origin of any run). **PO-S does not satisfy this blocker** (§1.2): P-1 is evidence about the traced pipeline, not a proof about an insertion point.
- **B-3 Interaction with legal-normalization provenance and protected spans.** Protected spans are derived from the normalization outcome; a position *before* normalization means no spans exist yet to honor the exclusion, and a position *after* it changes the text whose provenance coordinates the replay verifies (V1.10). The placement specification must say how the protected-span exclusion is evaluated and how
  provenance coordinates stay valid (V1.36 WP-7), for example by treating the operation as a recorded pass. This is a specification task, not a resolved design.
- **B-4 The repository's deterministic-normalization-family design review** (existing rule: a new family needs its own review before implementation).
- **B-5 A separate decision on normative T1 classification.** Neither policy adoption nor a complete specification confers T1 membership.
- **Not a blocker of this addendum or of adopting the policy:** DB-1 (§7). B-3/B-2 may have to *account for* the existing legal normalizer's behavior but do not require DB-1 to be resolved.
`[WA-11]`

## 5. Deterministic-work ledger (revised; supersedes V1.35 §4.2 for DP-2; no authorization anywhere)

| Id | Operation | Owner | Status |
|---|---|---|---|
| DP-1 | interior sentence-initial capitalization (v1.0/v1.1 A2b) | deterministic processing (PO-O) | **unchanged:** BLOCKED (safe sentence-boundary evidence/specification; consumes EI-1); not authorized, not implemented |
| ~~DP-2~~ | general whitespace/typographic normalization (V1.35) | — | **RETIRED at v1.3** (§3.1); historical id preserved |
| **DP-2a** | ordinary-space run collapse (V1.36 §5) | deterministic processing (PO-P, under the adopted preservation policy) | **BLOCKED**: B-1…B-5 (§4); **not T1, not authorized, not implemented, no frozen conformance suite** |

Historical traceability: V1.34 *M5 whitespace* → V1.35 *DP-2* → V1.36 *DP-2 / DP-2a* → v1.3 *DP-2 retired, DP-2a sole candidate*. All other v1.2 ledgers (evidence infrastructure EI-1…EI-4, unresolved-ownership UO-1/UO-2, presentation-owned A1/A2a) are unchanged. `[WA-12]`

## 6. Evidence capability map — revised entry M2 (descriptive; no implementation requirement)

M1, M3, M4, M5 of V1.35 §7 are unchanged. **M2 is replaced:**

### M2 — DP-2a ordinary-space run collapse (deterministic-processing candidate; replaces V1.35's DP-2 entry)
- **Owner:** deterministic processing (PO-P), under the adopted preservation policy.
- **Required policy facts:** the adopted policy (PO-S, PO-T, PO-U) — **available**; an exact function specification (B-1) — **does not exist**; a placement specification establishing the intentional-input precondition or equivalent evidence (B-2) — **does not exist**; the rule for protected-span exclusion and provenance coordinates (B-3) — **does not exist**.
- **Required observables:** the text (**E1**); protected spans (**E1**, but derivable only *after* legal normalization — placement-dependent, B-3); the digit-bearing property of neighbouring tokens (**E1**, computable from the text); a line-structure determination (**E1**, once "line" is specified); and, *if* placement alone cannot establish the precondition, an **origin record for whitespace runs** (**E2/E3**: nothing records it today).
- **Currently available:** the text and (post-normalization) protected spans; the policy.
- **Missing capability:** the exact function; the placement specification; the provenance-coordinate treatment; and equivalent deterministic evidence if placement does not suffice. *Recorded as gaps, not as implementation requirements.*
- **Provenance requirement:** if implemented, stage/rule id and version and the original run (WP-8); not required of the pipeline today.
- **Unresolved PO / investigation:** none needed to *specify* the function; B-5 (T1 classification) is a separate decision; PO-I is unaffected (no finality signal or field context is required or introduced).
- **Status:** deterministic-processing candidate; **BLOCKED**; not T1, not authorized, not implemented.

**Rule (unchanged):** missing capability is recorded, **not** turned into a blanket pipeline or data-collection requirement (`[RC-11]` of v1.2). `[WA-13]`

## 7. DB-1 — separate deterministic-boundary issue (not resolved, not investigated here)

DB-1 (V1.36 §7A): a matched legal-normalization span can consume embedded tab or newline whitespace. It concerns **existing legal normalization**, is **not a DP-2/DP-2a defect**, and remains **open and unrepaired**. It is **not a blocker for adopting the DP-2a preservation policy**, and no specification above logically requires it to be resolved first. It is tracked as a deterministic-boundary issue for the legal-normalization
specification; whether a span may consume authored layout whitespace, or should decline, is undecided. `[WA-14]`

## 8. Intelligence T2 register and conformance readiness

8.1 **No Intelligence T2 candidate exists after v1.3.** The Intelligence register remains **EMPTY** (v1.2 §4.1, `[REG-1]`); this addendum adds nothing to it, and the empty register is **not reopened**. DP-2a is a deterministic-processing candidate, not an Intelligence operation; whitespace is preserve-only or outside ownership for Intelligence (`[O-3]`). `[WA-15]`
8.2 **The conformance-readiness gate remains closed — not ready.** No Intelligence T2 subclass has confirmed ownership and a predicate at L2 or later (the register is empty), and the V1.36 §11 preconditions for a *deterministic* whitespace conformance suite are not met (the function and placement are unspecified, B-1…B-5 are open). No conformance suite exists or is authorized. `[WA-16]`

## 9. Open items

**Product Owner decisions still unresolved:** PO-R (A3 route/ownership), PO-N (A5-S), PO-M, PO-L, PO-G, PO-2, PO-3; B-5 (T1 classification of any deterministic candidate); the ownership of segment-edge whitespace (decided *out of DP-2*, owner unassigned). **Resolved here:** PO-S, PO-T, PO-U.
**Specification work (no new evidence or decision needed):** B-1 and B-2/B-3 for DP-2a. **Future evidence investigations (unchanged, not started):** FE2, FE4, FE5, FE6. **Separate issue:** DB-1.

## 10. Smallest justified next milestone

**V1.38 — DP-2a exact deterministic function and pipeline-placement specification (documentation only).** It addresses B-1, B-2 and B-3 together because they are one specification problem: the exact function (domain, "line", "digit-bearing", exclusions, output), the exact insertion point in the deterministic pipeline, an argument — or equivalent deterministic evidence — that intentional multi-space input cannot reach it,
and the treatment of protected spans and normalization provenance. It would **not** implement the function, create a corpus, promote DP-2a to T1 (B-5 is a separate decision), run a model, or touch DB-1. Nothing else is both unblocked and independent of undecided Product Owner decisions or new evidence.
