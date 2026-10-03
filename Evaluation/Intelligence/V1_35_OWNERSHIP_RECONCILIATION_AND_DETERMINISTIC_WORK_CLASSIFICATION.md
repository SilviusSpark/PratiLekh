# Intelligence V1.35 — Ownership reconciliation and deterministic-work classification (policy specification v1.2 addendum)

**Documentation and specification only.** No model was run; no production code, Authority, gate or contract changed; no deterministic transformation or predicate was implemented; **no operation is authorized**;
no conformance corpus was created. This is a **new prospective policy version** — *v1.2 = v1.1 (V1.34) plus this addendum*. V1.34 (v1.1) and V1.32 (v1.0) are **left byte-unchanged** and remain historical;
their text is incorporated by reference where this addendum does not supersede it (§0). Authority: V1.31 (invariants I1–I10, PO-A–PO-H), V1.32, V1.33 (PO-I, PO-K), V1.34 (ownership prerequisite, register, capability map).
`scripts/check_intelligence_v1_35_spec_consistency.sh` verifies this addendum's consistency and that V1.32 and V1.34 are byte-unchanged.

## 0. Versioning and what this addendum supersedes

0.1 v1.0 (V1.32) and v1.1 (V1.34) remain historical and unedited (bytes pinned). `[RC-1]`
0.2 **v1.2 supersedes v1.1 prospectively** for: §7 (the Authorization Register), §13 (prospective T2 areas), §13A (evidence capability map), §24–§27 (Part III and the next milestone), and the register-related statements in §3 and
§23's status line. Every other v1.1 clause (definitions, tiers, invariants, §6/§6A ownership prerequisite, §8 lifecycle, §9 predicate contract, §10–§12, Part II design) **is carried over unchanged and by reference.** `[RC-2]`
0.3 Historical area ids (A1…A5 of v1.0/v1.1) are **preserved** so earlier versions stay interpretable; §6 maps each to its v1.2 disposition. No state is inherited through a retirement, split or reclassification. `[RC-3]`
0.4 No prior experiment or result is rescored or relabelled. `[RC-4]`

## 1. Adopted decisions (normative from v1.2)

| # | Decision |
|---|---|
| **PO-O** | **Interior sentence-initial capitalization belongs to future deterministic processing, not Intelligence.** It remains **blocked** pending safe sentence-boundary evidence/specification. **Ownership is not authorization or implementation.** |
| **PO-P** | **General whitespace normalization belongs to deterministic processing**, subject to a **separately specified preservation policy**. **Ownership is not authorization or implementation.** |
| **PO-J** | **Spelled-date forms are record-sensitive unless deterministic evidence establishes participation in a date structure.** Month/day **lexical plausibility alone cannot authorize normalization.** |
| **A4 disposition** | **Per-matter vocabulary is retired as an autonomous correction area.** A future *verified* per-matter vocabulary is **evidence infrastructure**; **every operation that consumes it requires its own ownership, classification and authorization.** |
| **A5 disposition** | **The lexicon is distinguished from the word-split operation.** The lexicon is **evidence infrastructure**. **Ownership of the split operation remains unresolved pending PO-N.** |
| **PO-M** | **Remains unresolved** (the authorization standard for a T2 rule). |
| **PO-Q** | **Retired.** It was the former bundled question "confirm ownership for A3, A4, A5"; it is **superseded by the individual dispositions** above and in §6 (A3 → unresolved, new item PO-R; A4 → retired as correction; A5 → split). |

Carried unchanged: PO-A–PO-H (V1.31 §A), PO-I and PO-K (V1.33 §A), the ownership prerequisite (v1.1 §6A, `[O-1]`–`[O-7]`), and the statement that **no operation is authorized**.

## 2. Five kinds of thing (normative classification)

Every item the earlier register tracked is exactly one of the following. The kind determines *where it is tracked*, not whether it is allowed.

1. **Correction operation** — an edit that changes text. Its *owner* is one of Intelligence, deterministic processing, or downstream presentation formatting (`[O-1]`).
2. **Evidence infrastructure** — a versioned, curated *artifact or capability* that supplies evidence to operations (a lexicon, a vocabulary, a boundary or date-structure observable). It is **not a correction and not a register entry.** `[RC-5]`
3. **Deterministic-processing candidate** — a correction operation whose owner is **deterministic processing**. It is not an Intelligence operation: the Intelligence tiers and lifecycle (T1–T4, L0–L5) do not govern it. It is tracked in the deterministic-work ledger (§4) and
   remains subject to the repository's existing rule that each new deterministic normalization family needs its own design/legal-domain review before implementation. Ownership here is neither authorization, implementation, nor a normative T1 classification. `[RC-6]`
4. **Presentation-owned operation** — a correction operation owned by the downstream presentation formatting layer (PO-K). Intelligence MUST NOT apply, propose or suggest it (`[O-3]`); the owner's behavior is neither validated nor authorized here (`[O-5]`). `[RC-7]`
5. **Prospective Intelligence/T2 operation** — a correction operation whose owner is **confirmed as Intelligence** and that has a possible predicate. **Only such operations may appear in the Intelligence register** (§4.1). `[RC-8]`

**Consumption rule.** Evidence infrastructure may exist without any operation using it. Each operation that consumes an infrastructure artifact is a *separate* subclass that needs its own ownership, classification and authorization; the artifact's availability
or verification confers none of them (`[O-2]`, `[O-6]`). `[RC-9]`

## 3. Ownership map after reconciliation (operation / infrastructure)

| Item | Kind | Owner / disposition | Basis |
|---|---|---|---|
| A1 terminal-period correction | correction operation | **presentation-owned** (outside Intelligence); retired | PO-K, PO-I |
| A2a segment-initial capitalization | correction operation | **presentation-owned** (outside Intelligence); retired | PO-K |
| A2b interior sentence-initial capitalization | correction operation | **deterministic-processing candidate; blocked** (pending safe sentence-boundary evidence/specification); **removed from prospective T2** | PO-O |
| General whitespace/typographic normalization (v1.1 M5) | correction operation | **deterministic-processing candidate** (preservation policy to be specified separately) | PO-P |
| A3 date-structure-dependent normalization | correction operation | **ownership unresolved** (routes in §5; *not inferred from PO-J*) | PO-J, PO-R pending |
| A4 per-matter vocabulary | **evidence infrastructure** | retired as a correction area; infrastructure record EI-2 | A4 disposition, PO-C |
| A5-L general-word split lexicon | **evidence infrastructure** | infrastructure record EI-3 | A5 disposition |
| A5-S word-split operation | correction operation | **ownership unresolved** (PO-N); T3 default stands | A5 disposition, I1, PO-F |

## 4. Reconciled ledgers (normative state at v1.2) — **no operation is authorized**

**4.1 Intelligence register (prospective T2/T3 operations with confirmed Intelligence ownership): EMPTY.** No confirmed Intelligence-owned prospective T2 correction operation remains. Nothing has been kept or invented to avoid an empty register. `[REG-1]`

**4.2 Deterministic-work ledger (not an Intelligence register; no Intelligence lifecycle applies; no authorization):**

| Id | Operation | Owner | Status |
|---|---|---|---|
| DP-1 | interior sentence-initial capitalization (v1.0/v1.1 A2b) | deterministic processing (PO-O) | **BLOCKED**: needs safe sentence-boundary evidence/specification (boundary semantics, abbreviation handling, intentionally-lowercase tokens); consumes EI-1; not authorized, not implemented |
| DP-2 | general whitespace/typographic normalization (v1.1 M5) | deterministic processing (PO-P) | ownership decided; **needs a separately specified preservation policy** before any rule; not authorized, not implemented |

**4.3 Evidence-infrastructure ledger (not corrections; no operation is thereby authorized):**

| Id | Artifact / capability | Origin | Status |
|---|---|---|---|
| EI-1 | abbreviation lexicon / handling (sentence-boundary evidence) | A2b / DP-1 | does not exist; governance unresolved (PO-L) |
| EI-2 | verified per-matter vocabulary | A4 | does not exist (no schema, source, ingestion); governance and confidentiality unresolved (PO-L); consumers: none yet |
| EI-3 | curated general-word split lexicon | A5-L | does not exist; curatorship unresolved (PO-L); consumers: none yet |
| EI-4 | date-structure evidence (an observable establishing participation in a date structure) | A3 / PO-J | semantics do not exist; consumers: none yet; not a decision that any route is taken |

**4.4 Unresolved-ownership operations (neither Intelligence nor deterministic-processing candidates until decided; Intelligence MUST NOT act, `[O-4]`):**

| Id | Operation | Open question |
|---|---|---|
| UO-1 | A3 date-structure-dependent normalization | which route (§5), decision **PO-R** |
| UO-2 | A5-S word split | **PO-N** (what suffices beyond a lexicon, and therefore the owner) |

**4.5 Presentation-owned:** A1, A2a (§3). **4.6** Every ledger above carries **no authorization**. `[REG-2]`

## 5. A3 — remaining possible routes under the adopted record-sensitivity rule (none implemented, authorized or chosen)

PO-J makes a spelled date record-sensitive **unless deterministic evidence establishes participation in a date structure**, and says lexical plausibility alone cannot authorize normalization. A closed month/day list plus a context pattern, as v1.1's A3 outlined,
is therefore **not an admissible basis** by itself. What remains (ownership **not** inferred from PO-J):

- **R-a — Deterministic date-structure normalization.** A future deterministic-processing family recognizes date structures itself (producing EI-4 as part of the normalizer) and renders the date; any month-name rendering is a consequence of the recognized structure. Owner would be deterministic processing;
  it would need its own family design/legal-domain review. *Compatible with PO-J.*
- **R-b — Intelligence T2 consuming EI-4.** An Intelligence-owned capitalization edit verified by a predicate that reads a deterministic date-structure observable. *Compatible with PO-J only if EI-4 exists* (today E3) and only if ownership were decided as Intelligence (PO-R); it would also have to
  justify why R-a does not simply do the work.
- **R-c — T3 review-only suggestion.** Never autonomous; no application path until review UX exists (PO-G).
- **R-d — Leave as dictated.** The default: a spelled date is record-sensitive and is not touched.
- **Excluded by adopted decisions:** any route whose authority is month/day lexical plausibility alone (including a closed-list T2 predicate).

Because ownership is unresolved, A3 is **UO-1**, not an Intelligence-register entry, and Intelligence MUST NOT act on it (`[O-4]`). `[RC-10]`

## 6. Historical id mapping (v1.0 → v1.1 → v1.2)

| v1.0 id | v1.1 disposition | v1.2 disposition |
|---|---|---|
| A1 terminal period | retired (outside Intelligence ownership) | **unchanged: retired, presentation-owned** |
| A2 (v1.0) | split into A2a / A2b | see below |
| A2a segment-initial capitalization | retired (outside Intelligence ownership) | **unchanged: retired, presentation-owned** |
| A2b interior sentence-initial capitalization | L0 / NOT AUTHORIZED; ownership unresolved; blocked | **removed from prospective T2; deterministic-processing candidate DP-1, blocked** (PO-O) |
| A3 month/day names | L0 / NOT AUTHORIZED; ownership unconfirmed | **superseded**: closed-list T2 basis excluded by PO-J; recorded as **UO-1** (ownership unresolved; routes §5) |
| A4 per-matter vocabulary | L0 / NOT AUTHORIZED; ownership unconfirmed | **retired as a correction area**; verified vocabulary = **evidence infrastructure EI-2** |
| A5 split lexicon | L0 / NOT AUTHORIZED; effectively T3 | **split**: **A5-L → evidence infrastructure EI-3**; **A5-S → unresolved-ownership item UO-2** (PO-N); T3 default stands |
| (v1.1 M5) whitespace | ownership unresolved (PO-P pending) | **deterministic-processing candidate DP-2** (PO-P) |

No lifecycle state or authorization is inherited through any row (`[RC-3]`); none existed.

## 7. Evidence capability map (revised for v1.2; descriptive, no implementation requirement)

**Rule.** Missing capability is recorded, **not** turned into a requirement: absence of an observable blocks only the operation that declares it (`[EP-3]`); the map creates **no blanket pipeline or data-collection requirement** and introduces **neither a finality signal nor target-field context**
(PO-I remains authoritative). Evidence categories E1–E5 are those of v1.1 §13A (E1 available now; E2 technically observable but not recorded; E3 semantics do not exist; E4 external/contextual data required; E5 inappropriate to collect without a separately justified use case). `[RC-11]`

### M1 — DP-1 interior sentence-initial capitalization (deterministic-processing candidate)
- **Owner:** deterministic processing (PO-O).
- **Required policy facts:** a safe sentence-boundary specification; abbreviation handling; intentionally lowercase tokens; independence from other transformations; record-sensitive tokens untouched (I2).
- **Required observables:** the text (**E1**); protected spans / normalization provenance (**E1**); an interior sentence-boundary determination (**E3**); the abbreviation lexicon EI-1 (**E3/E4**).
- **Currently available:** the text and protected spans.
- **Missing capability:** boundary semantics and EI-1. *Not a requirement; a description of why DP-1 is blocked.*
- **Provenance requirement:** if a deterministic rule consumes EI-1, its id, version and authorization record (curatorship: PO-L). Not required: punctuation origin, settings snapshot, finality, field context.
- **Unresolved PO / investigation:** PO-L (lexicon governance); FE2 (feasibility of a deterministic boundary rule on real dictation).
- **Status:** deterministic-processing candidate, **blocked**; not authorized; not implemented.

### M2 — DP-2 general whitespace normalization (deterministic-processing candidate)
- **Owner:** deterministic processing (PO-P).
- **Required policy facts:** a **preservation policy** (what whitespace and layout the judge's text must keep) and a rule set with idempotence and no-new-defect guarantees (I6).
- **Required observables:** the text (**E1**). No model evidence, no external data.
- **Currently available:** the text. Partial behavior exists only as a side effect of filler removal (collapse on re-join), unspecified as an operation.
- **Missing capability:** the preservation policy and a specified standalone operation; a stage-version stamp (**E2**). *Not a requirement here.*
- **Provenance requirement:** stage id/version if a later consumer relies on it having run (`[V-1]`).
- **Unresolved PO / investigation:** the preservation policy itself (a specification task; no new data needed).
- **Status:** deterministic-processing candidate; ownership decided; **not authorized; not implemented**.

### M3 — UO-1 A3 date-structure-dependent normalization (ownership unresolved)
- **Owner:** unresolved (PO-R).
- **Required policy facts:** the chosen route (§5); PO-J's rule (record-sensitive unless a deterministic date-structure is established); if R-a, a normalization-family design review.
- **Required observables:** the text (**E1**); protected spans (**E1**); date-structure evidence EI-4 (**E3**); a versioned month/day name table (**E4**, small/static, still a curated artifact).
- **Currently available:** the text and protected spans.
- **Missing capability:** date-structure semantics (EI-4).
- **Provenance requirement:** the producing normalizer's id/version for EI-4; table id/hash (`[V-4]`).
- **Unresolved PO / investigation:** **PO-R**; FE4 (date-expression distribution).
- **Status:** unresolved ownership; Intelligence MUST NOT act; not authorized.

### M4 — UO-2 A5-S word-split operation (ownership unresolved)
- **Owner:** unresolved (PO-N).
- **Required policy facts:** what suffices beyond a lexicon (PO-N, undefined); I1 (token-sequence change); exclusions for valid compounds, names and Indian-language forms.
- **Required observables:** the text (**E1**); protected spans (**E1**); the split lexicon EI-3 (**E3/E4**).
- **Currently available:** the text and protected spans (the user-level custom dictionary can express user-specific splits but is not a curated lexicon).
- **Missing capability:** EI-3 and the sufficiency rule.
- **Provenance requirement:** lexicon id/version/hash/authorization (`[V-4]`).
- **Unresolved PO / investigation:** **PO-N**, PO-L; FE6 (coverage and false-split rates, model-free).
- **Status:** unresolved ownership; T3 default stands; not authorized.

### M5 — Evidence infrastructure EI-2 (per-matter vocabulary), no current consumer
- **Owner:** none for the artifact until governance is decided; *not a correction operation.*
- **Required policy facts:** governance (verification, per-matter versioning, confidentiality, never baked into global artifacts); schema; matching semantics (PO-L).
- **Required observables:** n/a (it *is* an observable source): the vocabulary with id/version/hash/curator (**E3**; derived from matter data, **E4**).
- **Currently available:** a user-level, user-curated custom dictionary (a trigger→replacement store; **E1** as a store, its past substitutions **E2**) — not an entity vocabulary.
- **Missing capability:** the verified vocabulary (E3/E4). *Ingesting matter documents is **E5** until a use case justifies it.*
- **Provenance requirement:** id, version, content hash, matter binding, curator authorization (`[V-4]`).
- **Unresolved PO / investigation:** PO-L; FE5. Consumption by any operation requires that operation's own ownership/classification/authorization (`[RC-9]`).
- **Status:** infrastructure record; no consumer; nothing authorized.

**Not mapped:** A1 and A2a (presentation-owned); classes at T3/T4. **Observables deliberately not required by any mapped item:** segment finality (E3); target-field context (E4/E5); the settings snapshot (E2); punctuation origin (E2); provider confidence (not evidence, `[V-2]`); audio (E5 here).

## 8. Is any confirmed Intelligence-owned prospective T2 operation left?

**No.** After reconciliation the Intelligence register (§4.1) is empty: A1 and A2a are presentation-owned; A2b is a deterministic-processing candidate; A4 is infrastructure; A5-L is infrastructure; A3 and A5-S have **unresolved** ownership (and A3's closed-list basis is excluded by PO-J);
whitespace is deterministic. The T2 track therefore has **no subject** at present. **T3** (review-only suggestions: for example grammar, style and lexical changes, PO-D) remains defined *policy scope* with no application path (PO-G); that is not a T2 candidate. `[REG-3]`

## 9. Conformance-readiness status (v1.1 §23 gate, unchanged)

**Closed — not ready.** The existing requirements are not met: R2 requires every included T2 subclass to have **confirmed Intelligence ownership** and a predicate at L2 or later; **none exists** (the register is empty). The *ownership family* of the conformance design (expected: not Intelligence-applicable) remains
describable, but the gate's other conditions (R1, R4–R9) are not satisfied either, and the readiness gate does not open because the register shrank. The v1.2 reconciliation satisfies no gate condition. `[REG-4]`

## 10. Open items, by who or what can resolve them

**Product Owner decisions (unresolved):** **PO-R** (route and ownership for A3 date-structure-dependent normalization, after PO-J); **PO-N** (A5-S: what suffices beyond a lexicon, hence the owner); **PO-M** (authorization standard — dormant while the Intelligence register is empty, still unresolved);
**PO-L** (governance of abbreviation lexicon EI-1, vocabulary EI-2, split lexicon EI-3, and any EI-4 curated table); the **DP-2 preservation policy** (a specification the Product Owner must approve); **PO-G** (review UX); **PO-2**, **PO-3**. PO-E remains an architectural goal, recorded only if a future rule needs it.
**Retired / resolved here:** PO-Q (retired), PO-O, PO-P, PO-J, A4 and A5 dispositions (adopted §1).
**Future evidence investigations:** **FE2** (deterministic interior sentence-boundary feasibility on real dictation) for DP-1; **FE4** (date-expression distribution) for UO-1; **FE5** (vocabulary sources) for EI-2 *(E5 caveat)*; **FE6** (split-lexicon coverage and false-split rates) for UO-2. None has been started.

## 11. Smallest justified next milestone

The next evidence work could concern deterministic sentence-boundary/capitalization (DP-1), the deterministic whitespace policy (DP-2), date normalization (UO-1), split-operation evidence (UO-2), or a future T3/review path. Their readiness differs:

| Candidate | What blocks it | Needs new evidence or data? | Needs an undecided PO decision? |
|---|---|---|---|
| DP-1 sentence-boundary / capitalization | no safe boundary specification; EI-1 does not exist | **yes** (FE2: real dictation) | yes (PO-L governance) |
| **DP-2 whitespace policy** | only a **preservation policy specification** | **no** | **no** (ownership decided, PO-P) |
| UO-1 date normalization | ownership route; EI-4 semantics | yes (FE4) | **yes** (PO-R) |
| UO-2 split operation | PO-N; EI-3 does not exist | yes (FE6) | **yes** (PO-N, PO-L) |
| T3 / review path | review UX | no | **yes** (PO-G) |

**Recommended: V1.36 — deterministic whitespace preservation-policy specification (documentation only).** It is the only candidate whose single blocker is a *specification* rather than new evidence, curated data, or an undecided ownership/UX decision; ownership is already decided (PO-P); it is independent of
every other open item; and the existing implicit behavior (whitespace collapse as a filler-removal side effect, V1.33 §7) is currently unspecified. It would define what whitespace and layout the judge's text must preserve and what a deterministic normalizer may change, as a specification
for the deterministic pipeline — **not** an Intelligence rule, not implemented, no corpus, no model, and not a normative T1 promotion. The others should wait for the decisions/evidence in §10.
