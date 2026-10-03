# Intelligence V1.34 — Autonomous correction policy specification **v1.1** and evidence capability map

**Specification and documentation only.** No model was run; no production code, Authority, gate, contract or `Sources/` file changed; **no operation, rule or predicate is
authorized by this document**; no runtime evidence was collected; **no conformance corpus was created or frozen**; no experiment or result was rescored or relabelled.
This is a **new version** of the V1.32 normative specification; the V1.32 file is left byte-unchanged (§0).
Authority: V1.31 (adopted decisions PO-A–PO-H, invariants I1–I10), V1.32 (v1.0), and V1.33 (adopted PO-I and PO-K; discrepancies X1/X2).

**Structure.** §0 versioning. **Part I (§1–§13A) is the normative specification.** Part II (§14–§23) is the design of a future model-free conformance evaluation (nothing built).
Part III (§24–§26) classifies open questions and records the areas retired from Intelligence ownership. §27 is the next milestone. Clause ids (e.g. `[O-2]`) are stable;
`scripts/check_intelligence_v1_34_spec_consistency.sh` verifies this document's internal consistency, its fidelity to V1.31/V1.33, and that V1.32 is byte-unchanged.

---

## 0. Versioning and the relationship to v1.0

0.1 **V1.32 (policy specification v1.0) remains historical and unedited.** Its bytes are pinned by the consistency script. `[VER-1]`
0.2 **v1.1 supersedes v1.0 prospectively** from the commit that introduces it. Where v1.0 and v1.1 differ, v1.1 governs. `[VER-2]`
0.3 **Clause identifiers are stable.** A clause carried over unchanged keeps its id and text. Clauses changed or added in v1.1: `[T-6]`, `[C-6]`, `[O-1]`…`[O-7]`, `[L-1]` (ownership precondition),
`[L-6]`, `[V-3]` (X1 correction), `[R-1]` (wording: ownership), `[R-2]`…`[R-4]` (new), `[MAP-1]`, `[MAP-2]`, `[VER-1]`…`[VER-4]`; §3 (adds PO-I, PO-K), §7 (reconciled register), §13 (revised), §13A (new), §23 (gate adds ownership), Part III, §27. Every other clause is v1.0 text. `[VER-3]`
0.4 **No result is rescored or relabelled, and no authorization or lifecycle state is inherited through a rename or split.** v1.0's area A2 is *split* into A2a and A2b below; each new id carries only the state this
document states for it explicitly (none was ever authorized, so nothing is lost or gained). A retired area has no state. `[VER-4]`
0.5 **What v1.1 corrects from V1.33:** X1 (how user settings reach the Intelligence input — v1.0 §13 and `[V-3]`) and X2 (the deterministic formatter does *not* own interior sentence-initial capitalization — v1.0 §13 A2, B-A2.5).

---

# Part I — Normative specification

## 1. Status and language

1.1 The words MUST, MUST NOT, SHOULD and MAY are normative. This specification is **implementation-independent**: it constrains observable policy
behavior, not any type, file or algorithm. It does not describe, and is not derived from, the current Safety Authority or gate.
1.2 Version: **policy specification v1.1 (V1.34 draft until frozen by commit)**. Changing any normative clause requires a new version and an explicit
Product Owner decision; a defect found later is disclosed and fixed by a new version, never silently edited.
1.3 Precedence: PO-A–PO-K (§3) > invariants (§5) > the remaining clauses > the informative notes and Part II/III.

## 2. Definitions

- **Source** `S₀`: the immutable text presented to Intelligence for one proposal batch.
- **Edit**: a proposed replacement of a contiguous span of `S₀` by a replacement text. **Net effect** of an edit: the minimal difference between `S₀`
  and the text with the edit applied (not the span the proposer chose).
- **Token**: a maximal run of word-forming characters; the **token sequence** of a text is its tokens, case-folded, ignoring punctuation and whitespace.
- **Record-sensitive token**: a token or region whose change could change a fact, identity, number, date, statute, name, scope of a clause, or the form
  of something deliberately dictated, including everything inside a protected span (§5, I2).
- **Class / subclass**: a named kind of edit by what it changes in information (§13 and V1.31 §5). **Classification** (§6) is the deterministic act
  of assigning an edit to a subclass.
- **Tier**: the policy position of a subclass (§4). **Authorization**: the recorded, versioned state of a rule (§7–§8). The two are independent.
- **Observable**: a named, typed, versioned value produced by a deterministic stage with recorded provenance (§12) and consumed by a predicate.
- **Evidence predicate**: a pure, deterministic function from (`S₀`, an edit, declared observables) to a verdict (§9). **Verdict**: `Verified`,
  `Denied(reason)` or `Unknown(reason)`.
- **Rule**: a (subclass, predicate-id@version) pair together with its authorization record.
- **Autonomous**: applied to the transcript without explicit judge action.
- **Owner / ownership**: which layer is responsible for an operation — *Intelligence*, *deterministic processing* (the stages that precede the hand-off) or *downstream presentation formatting* (the stages after it). A decision is recorded with a Product Owner reference (§6A).
- **Not Intelligence-owned (NIO)**: an operation whose confirmed owner is not Intelligence. **Unresolved ownership**: no owner has been confirmed.
- **Evidence capability map**: the mapping of §13A. **Evidence categories E1–E5** are defined in §13A.

## 3. Frozen and adopted Product Owner decisions

**3.1 Decisions frozen from V1.31 §A (verbatim; MUST be preserved).**

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

**3.2 Decisions adopted at V1.33 (verbatim from V1.33 §A; normative from v1.1).**

**PO-I — segment finality.**
- The current hotkey-session segment has **no finality semantics**.
- **Hotkey release is an acquisition boundary, not evidence** of sentence, utterance, paragraph or dictation finality.
- **No future rule may infer finality merely from segment end or hotkey release.**
- **No finality signal and no target-field context is introduced in this milestone** (options I-2 and I-3 of §10 are therefore not adopted here; they remain unexamined future
  possibilities that would need their own decision).

**PO-K — deterministic-processing ownership.**
- **Intelligence does not own terminal punctuation or segment-initial capitalization.** They remain **presentation concerns in the existing downstream formatting layer**.
- This decision **does not classify or validate** the existing GAAV / smart-capitalization formatters as T1 under V1.32 (§7 stays diagnostic; those formatters are not
  promoted, and their lowering/stripping behaviour remains unqualified under I2/I4).
- **Interior sentence-initial capitalization and general whitespace ownership remain unresolved.**
- **Nothing is implemented and no formatting behavior is moved.**

**Current authorization state (normative): no operation is authorized.** No T2 class is currently authorized, because no required deterministic evidence predicate has yet been specified
*and* authorized for any class (§7). Consequently no model-proposed edit is autonomous under this specification today. The ownership reconciliation of §6A/§7 authorizes nothing.

## 4. Tier semantics (normative)

4.1 **T1 — deterministic processing.** The correct output is a function of the text alone by a stated rule with no choice among readings. T1
operations belong to deterministic processing stages, not to model Intelligence (PO-A); a model proposal equal to a T1 rule confers nothing.
4.2 **T2 — conditionally autonomous.** A model-proposed edit MAY be autonomous only if all of: (a) it classifies into a subclass whose rule is in state
**Authorized** (§8) *and* implemented; (b) that rule's predicate returns `Verified` for this edit; (c) every invariant in §5 holds. Otherwise it is not
autonomous. A T2 subclass without an authorized rule is presently non-autonomous (PO-B, PO-C).
4.3 **T3 — review-only (policy scope).** An edit that, in future, MAY be shown to the judge as a suggestion and MUST NOT be applied without explicit
acceptance. T3 defines scope only: it has **no production application path** until review UX is separately designed (PO-G).
4.4 **T4 — prohibited / abstain.** An edit MUST NOT be applied autonomously and is not offered as an edit; where the text is ambiguous the system leaves it
unchanged.
4.5 A subclass's tier is a **classification fact** (§6); a T2 tier is a *capability ceiling*, never a permission.
4.6 **Not Intelligence-owned.** An operation whose confirmed owner is not Intelligence (§6A) has no Intelligence tier: Intelligence MUST NOT apply or propose it, whatever a predicate would return. `[T-6]`

## 5. Governing invariants (frozen from V1.31 §4; verbatim)

*(Section references inside this verbatim block — e.g. “§7” — refer to the V1.31 document, not to this one.)*

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

## 6. Classification versus authorization

6.1 **Classification** assigns an edit to a (class, subclass) and thereby a tier, deterministically, from `S₀` and the edit alone. It MUST NOT depend on a
category claimed by the proposer, on model confidence or rationale, or on the proposer's span (net effect decides, I6). `[C-1]`
6.2 Classification MUST NOT confer autonomy. An edit is autonomous only by §4.2, which requires an authorized rule *and* a `Verified` verdict. `[C-2]`
6.3 **Authorization is a property of a rule, not of an edit, a model, or an observed outcome.** `[C-3]`
6.4 A subclass whose classification cannot be determined unambiguously is **unclassified** and MUST be treated as T4. `[C-4]`
6.5 Classification MAY be implemented independently of any predicate; a classification result is reported separately from an authorization result
(§17). `[C-5]`
6.6 Policy-level outcomes are exactly: **Autonomous** (§4.2), **Suggestion-eligible** (T3; no application path), **Not autonomous**, **Prohibited** (T4).
Mapping these onto any implementation's disposition vocabulary is an implementation matter and is not normative here.
6.7 Classification and authorization presuppose **ownership** (§6A): an edit in a subclass whose ownership is not confirmed as Intelligence is not Intelligence-applicable, and no tier predicate can change that. `[C-6]`

## 6A. Ownership — a prerequisite to classification and authorization

6A.1 **Owner set and decisions.** Every operation has at most one decided owner among **Intelligence**, **deterministic processing**, **downstream presentation formatting**. Ownership is decided by the Product
Owner, recorded in the register with the decision reference, and versioned. `[O-1]`
6A.2 **Ownership precedes classification and authorization.** Intelligence tiers (T2, T3) apply only to operations whose owner is **confirmed as Intelligence**. For any other operation Intelligence is not applicable, and
no tier, predicate or verdict can make it applicable. `[O-2]`
6A.3 **Excluded operations.** For an operation whose confirmed owner is not Intelligence, Intelligence MUST NOT apply, propose or suggest it; an edit in that class is classified *not Intelligence-owned* and is not autonomous
and not suggestible, regardless of any predicate (`[T-6]`). `[O-3]`
6A.4 **Unresolved or unconfirmed ownership fails closed.** Intelligence MUST NOT act autonomously on such an operation. The operation MAY be recorded at L0, but it MUST NOT leave L0 until ownership is confirmed as Intelligence
(`[L-1]`). `[O-4]`
6A.5 **Ownership is not authorization and not validation.** Assigning an operation to another owner neither authorizes nor validates that owner's behavior: for example, the PO-K decision does not classify the existing
GAAV or smart-capitalization formatters as T1, and does not endorse their behavior under I2/I4. `[O-5]`
6A.6 **Satisfying a tier predicate can never create ownership.** An operation outside Intelligence ownership cannot become autonomous Intelligence by meeting any evidence condition. `[O-6]`
6A.7 **A change of owner is a new register id** with its own starting state; nothing is inherited (`[VER-4]`). `[O-7]`

## 7. Authorization Register (normative state, reconciled at v1.1)

7.1 The register records, per subclass, its **ownership** (with decision reference), tier ceiling, lifecycle state (§8), predicate id@version, observables, the Product Owner authorization record, and revocations. It is
append-only; an entry is never edited in place. `[R-2]`
7.2 **Register state at v1.1 — no operation is authorized:**

| Id | Subclass | Ownership | Tier ceiling | Predicate | State | Autonomy today |
|---|---|---|---|---|---|---|
| **A1** | terminal-period correction | **OUTSIDE INTELLIGENCE OWNERSHIP** (PO-K: presentation concern) | — | — | **RETIRED from Intelligence — not a T2 rule; no lifecycle state** | none |
| **A2a** | segment-initial capitalization | **OUTSIDE INTELLIGENCE OWNERSHIP** (PO-K: presentation concern) | — | — | **RETIRED from Intelligence — not a T2 rule; no lifecycle state** | none |
| **A2b** | interior sentence-initial capitalization | **UNRESOLVED** (decision PO-O pending; candidates: Intelligence, new deterministic processing, neither) | T2 only if owned by Intelligence | — | **L0 / NOT AUTHORIZED — blocked** (cannot leave L0, `[O-4]`) | none |
| **A3** | month/day-name capitalization | not excluded by any adopted decision; **unconfirmed** (alternative route: a future deterministic date normalizer, PO-J) | T2 | — | **L0 / NOT AUTHORIZED** (ownership unconfirmed) | none |
| **A4** | operation supported by a verified per-matter vocabulary | not excluded (PO-C names a future verified vocabulary as possible support); **unconfirmed** | T2 | — | **L0 / NOT AUTHORIZED** (vocabulary does not exist; ownership unconfirmed) | none |
| **A5** | word split supported by a curated lexicon | not excluded (I1 and PO-F permit lexicon evidence for splits); **unconfirmed** | T3 default; T2 ceiling only if additional evidence is specified (§13 A5) | — | **L0 / NOT AUTHORIZED** (ownership unconfirmed) | none |

7.3 No other subclass is a T2 candidate in this specification. Adding one requires ownership confirmation and then §8 from the beginning. `[R-1]`
7.4 **A5 determination.** v1.0 listed A5 as "T3 (T2 only with additional specified evidence)". This is *derived from, not a new decision beyond*, the already-adopted policy: invariant I1 forbids autonomous word splitting "without
separate lexicon evidence, and even then only for splits", and PO-F says a curated lexicon "may contribute evidence for word splitting but is not by itself sufficient authorization for arbitrary splits". Together these mean a
split is **not excluded** from T2 (the ceiling stays T2) but is **T3 unless additional evidence beyond a lexicon is specified**; none is, so A5 is effectively T3-only today and is retained in the register at L0, unchanged in status
from v1.0. `[R-3]`
7.5 **Reconciliation of v1.0's five areas.** A1 → retired (outside ownership). A2 → split: A2a retired; A2b L0 / blocked. A3, A4, A5 → unchanged (L0 / NOT AUTHORIZED), with ownership recorded as *unconfirmed* rather than assumed.
The reconciliation changes ownership and register presentation only; it authorizes nothing and moves no lifecycle state. `[R-4]`

## 8. Lifecycle of a future T2 rule

States are strictly ordered; no state may be skipped, and an entry into a later state without the recorded completion of the earlier one is void. **A subclass may leave L0 only after its ownership is confirmed as Intelligence (§6A, `[O-4]`).** `[L-1]`

| State | Name | Entry requirement | Output |
|---|---|---|---|
| **L0** | Proposed subclass | named subclass with the information it changes, its zone (V1.31 §2), and why autonomy (not T3) is wanted | register entry (state L0) |
| **L1** | Evidence predicate specified | a predicate meeting the contract §9, with every observable defined and available in principle, no heuristic invented to fill a gap | predicate id@version + spec text |
| **L2** | Conformance defined | the conformance requirements of Part II for this subclass (case roles, expectations derivable from the specification text alone), *without* freezing a corpus | conformance definition |
| **L3** | Explicitly authorized | recorded Product Owner decision naming the exact predicate version, observable versions and conformance definition, with the accepted residual-risk statement | authorization record |
| **L4** | Implementation authorized | a separate authorization to implement | implementation milestone authorization |
| **L5** | Evaluated and enabled | a separately authorized conformance evaluation passes its pre-registered criteria, then a separate decision enables the rule | enablement record |

8.2 Any change to a predicate, an observable's producer or version, or a lexicon/vocabulary version creates a **new rule version** that returns to L1 and
requires re-authorization. Authorization binds exact versions. `[L-2]`
8.3 Authorization MAY be revoked at any time; a revoked rule is non-autonomous immediately. `[L-3]`
8.4 L3 is not implied by L2, nor L5 by L4. Evidence that a model's edits happened to be acceptable MUST NOT substitute for any state. `[L-4]`
8.5 A pair rule or dependent-edit rule (§11) follows the same lifecycle. `[L-5]`
8.6 A subclass retired from Intelligence ownership has no lifecycle state; it is recorded in the register as retired and cannot be re-entered at L0 without a new ownership decision and a new register id. `[L-6]`

## 9. Evidence-predicate contract (implementation-independent)

A predicate specification MUST contain, and an implementation MUST honor, all of the following.

- **EP-1 Identity and version.** A stable id (`T2.<area>.<name>`), an integer version, and a content hash of its specification text. `[EP-1]`
- **EP-2 Domain.** The subclass(es) and exact edit shapes it applies to. Outside its domain it returns `Denied(outOfDomain)`. `[EP-2]`
- **EP-3 Required observables.** Each by name, type, producer stage, producer version, and an **availability requirement**: which observables MUST be
  present. A missing, stale (version mismatch) or unverifiable observable yields `Unknown(missingObservable)`. `[EP-3]`
- **EP-4 Decision semantics.** A **pure, total, deterministic** function of (`S₀`, the edit, the declared observables): no randomness, clock, locale
  dependence not declared, network, model call or hidden state; identical inputs give identical verdicts; defined for every input in its domain. The
  function MUST be fully specified in the predicate text (rule/table/lexicon-based); probabilistic, learned or otherwise not fully specified components are
  **inadmissible** as evidence (consequence of PO-A and I7; revisable only by an explicit future Product Owner decision). `[EP-4]`
- **EP-5 Verdicts.** `Verified` only if the specified conditions are met. `Denied(reason)` when they are specified as unmet. `Unknown(reason)` when they
  cannot be decided (missing/contradictory observable, resource bound exceeded, ambiguous). Reason codes are a closed, versioned set. `[EP-5]`
- **EP-6 Only denial can follow from failure.** Any verdict other than `Verified`, any error, and any resource-bound exhaustion MUST deny autonomy. A
  predicate MUST NOT fall back to model judgment, claimed category, confidence, rationale or a default-allow. `[EP-6]`
- **EP-7 Narrowing only.** A predicate can only deny; it MUST NOT override a protected span, an invariant (§5), a T4 classification, or the
  authorization state. `[EP-7]`
- **EP-8 Locality and idempotence.** It declares its **evidence region** (the span of `S₀` its decision reads) and states idempotence: after the edit,
  re-evaluation of the same rule proposes nothing further. `[EP-8]`
- **EP-9 Resource bound.** A declared worst-case bound; exceeding it yields `Unknown(resourceBound)`, never a permissive result. `[EP-9]`
- **EP-10 Attribution.** Every autonomous application MUST record: predicate id@version, the observable ids/versions (or content hashes) consulted, the
  verdict and reason, the original span and text, and the replacement, sufficient to reproduce the decision and to reverse the edit exactly (I7). `[EP-10]`
- **EP-11 Composition.** It declares its interaction behavior per §11. `[EP-11]`
- **EP-12 Conformance reference.** It cites its conformance definition (L2). `[EP-12]`

## 10. Failure, missing evidence and ambiguity

10.1 Failure, missing evidence, an unverifiable observable, contradictory observables, resource-bound exhaustion, an internal error and ambiguity
(I10) MUST each result in **no autonomy**. `[F-1]`
10.2 No component MAY substitute model judgment (or the proposer's claims) for missing deterministic evidence. `[F-2]`
10.3 Where two readings differ in legal meaning, the specification requires abstention; a predicate cannot be written to choose between them. `[F-3]`
10.4 A denial is not an error and MUST be reported with its reason code; it MUST NOT be retried with relaxed conditions. `[F-4]`

## 11. Composition and dependent edits

11.1 Every edit is evaluated against the immutable `S₀`, never against another edit's result. `[D-1]`
11.2 Two edits are **dependent** if either (a) the evidence region of one intersects or touches the changed region of the other, or (b) the verdict of
either edit, re-evaluated against `S₀` with the other applied, differs from its verdict on `S₀` or reads a different evidence region. `[D-2]`
11.3 Dependent edits are **not autonomous** unless a pair/dependency rule for exactly that combination is authorized under §8. `[D-3]`
11.4 Independent autonomous edits MUST yield the same result in any application order, and the combined result MUST satisfy §5 as a whole (token
sequence and record-token invariants over the full text, not edit by edit). `[D-4]`
11.5 Overlapping proposals are not autonomous. A batch beyond a declared size bound is `Unknown(resourceBound)`. `[D-5]`

## 12. Provenance requirements

12.1 Every observable carries an id, producer stage, producer version, and a hash of its inputs, and is reproducible from the source, declared
configuration and the producer version. `[V-1]`
12.2 Observables MUST be produced by deterministic stages; **no observable may be derived from model output.** `[V-2]`
12.3 User settings that change the text *before the Intelligence hand-off* (filler removal and its word list, the custom dictionary, spoken-punctuation conversion
and its prefix and rule tables, spoken-send) and provider-originated facts (for example ASR-inserted punctuation) are **recorded facts with provenance**; they are never evidence
of the judge's intent unless a predicate states so explicitly and that use is covered by its authorization. Settings applied *after* the hand-off (presentation formatting such
as first-letter lowering, trailing-period removal, context-aware capitalization) do not shape `S₀`; they act on Intelligence output and are not evidence available to a
predicate (corrects v1.0's example, per V1.33 finding X1). `[V-3]`
12.4 A lexicon or vocabulary observable records id, version, content hash and the record of who authorized that version (curatorship is open, PO-F). `[V-4]`
12.5 If punctuation provenance (dictated / provider / deterministic stage) is not derivable, a predicate that needs it returns `Unknown(missingObservable)`;
its derivability is not assumed (PO-E). `[V-5]`

## 13. Prospective T2 areas — can a predicate presently be specified? (revised at v1.1)

**Method.** For each area still in the register, the question is whether a predicate meeting §9 can be written *from product semantics alone, without inventing heuristics*. Where not, the missing observables and
blockers are recorded and the area stays at L0. Repository facts are cited only as evidence of what is *unknown at the Intelligence boundary*, never as the definition of the policy.

**Corrected repository facts (V1.33 X1/X2; replaces v1.0's paragraph).** The text presented to Intelligence (`S₀`) is the output of: provider text → filler removal → custom dictionary → spoken-punctuation conversion (applied twice)
→ spoken-send parse → legal normalization. The **presentation formatters — GAAV (strip a trailing period / lowercase the first letter), continuous-dictation spacing and context-aware first-letter capitalization, literal
formatting, terminal spacing — run after the hand-off**, are user-preference driven (default off), and act on Intelligence's *output*; they do not shape `S₀`. The continuous formatter capitalizes or lowercases only the **first letter
of a session's text** using the target field's preceding text; nothing in the pipeline capitalizes **interior** sentence starts (so v1.0 B-A2.5's "the pipeline already has context-aware capitalization" holds for the segment-initial
letter only).

| Area | Status | Specifiable now? |
|---|---|---|
| **A1** Terminal period | **retired from Intelligence ownership** (PO-K) | n/a |
| **A2a** Segment-initial capitalization | **retired from Intelligence ownership** (PO-K) | n/a |
| **A2b** Interior sentence-initial capitalization | L0, ownership unresolved, blocked | No: B-A2b.1…A2b.4 |
| **A3** Month/day-name capitalization | L0, NOT AUTHORIZED | No (outline only): B-A3.1…A3.3 |
| **A4** Per-matter-vocabulary operations | L0, NOT AUTHORIZED | No: B-A4.1…A4.5 |
| **A5** Word split with lexicon evidence | L0, NOT AUTHORIZED (T3 default) | No: B-A5.1…A5.4 |

**A1 and A2a — retired.** PO-K places terminal punctuation and segment-initial capitalization in the downstream presentation layer; PO-I establishes that a segment has no finality semantics and that none may be inferred from segment
end or hotkey release. Consequently no Intelligence rule — T2 or otherwise — concerns these operations, and v1.0's blockers B-A1.1…B-A1.4 and B-A2.3 are retained only as the reasons they are not Intelligence-ownable here (an Intelligence-added
period could in any case be removed by a downstream preference). Retirement is an ownership decision; it neither authorizes nor validates the downstream formatters (`[O-5]`).

**A2b — interior sentence-initial capitalization (ownership unresolved; blocked).** *Product semantics available:* raising the first letter of a lowercase alphabetic token that begins an **interior** sentence; never lowering; outside protected
spans; not produced by another edit (D-2). Interior positions need **no** finality signal and **no** target-field context: both concern a session's boundaries, which A2b does not touch. *Blockers:*
- B-A2b.1 **Interior sentence-boundary determination** with an abbreviation exclusion ("viz.", "Rs.", honorific/title abbreviations): no specified boundary semantics and no abbreviation lexicon exists (E3, E4).
- B-A2b.2 **Abbreviation-lexicon governance:** existence, content, versioning and curator unresolved (PO-F extends).
- B-A2b.3 **Intentionally lowercase tokens** at an interior boundary (identifiers, unit/abbreviation forms): not specified.
- B-A2b.4 **Ownership (PO-O):** no component owns this today (X2); whether it is Intelligence T2, new deterministic processing, or neither is undecided. Until decided it fails closed (`[O-4]`).
*Not specifiable now.*

**A3 — Month/day-name capitalization (L0).** *Available:* a closed set of month and weekday names; raising only. *Blockers:*
- B-A3.1 **Homographs** ("may", "march", "august", "sat", "sun"): a closed list cannot verify intended use; a context pattern would have to be invented.
- B-A3.2 **Record-sensitivity:** whether the surface form of a spelled date is a record-sensitive token under I2 is a Product Owner question (PO-J); a future deterministic date normalizer (T1) may make the T2 route moot.
- B-A3.3 **No date-expression observable exists.**
- B-A3.4 **Ownership** unconfirmed (Intelligence vs the date-normalizer route).
*Not specifiable now.*

**A4 — Operations supported by a verified per-matter vocabulary (L0; PO-C).** *Available:* none beyond the decision that model judgment alone never suffices. *Blockers:*
- B-A4.1 the vocabulary does not exist (no schema, source or ingestion path); B-A4.2 governance (verification, per-matter versioning, confidentiality; never baked into global artifacts); B-A4.3 matching semantics; B-A4.4 operation scope
  (capitalization only; spelling normalization is lexical substitution, T3 at most, PO-D); B-A4.5 entity typing; B-A4.6 ownership unconfirmed.
*A user-level, user-curated store exists (custom dictionary) but it is a trigger→replacement table whose substitutions run upstream and are unrecorded; it is not an entity vocabulary.* *Not specifiable now.*

**A5 — Word split supported by a curated lexicon (L0; PO-F; see §7.4).** *Blockers:* B-A5.1 lexicon existence, content and curator; B-A5.2 the additional evidence that would complete authorization is undefined; B-A5.3 valid compounds, names and
Indian-language forms cannot be excluded by a lexicon alone; B-A5.4 a split changes the token sequence (I1); B-A5.5 ownership unconfirmed. *Not specifiable now; effectively T3.*

**T1 note.** Whitespace/typographic normalization, executing explicit spoken-punctuation commands, and the Phase-3 numeric/statutory normalizers are *deterministic processing* concerns, specified (if at all) in the deterministic pipeline's own
specification. They are not T2 rules and are not authorized or validated here (`[O-5]`). Ownership of **general whitespace/typographic normalization** is unresolved (PO-P).

## 13A. Evidence capability map

**Purpose.** For each operation still capable of becoming a T1 or T2 rule under adopted policy, map what evidence a rule would need against what exists. It is **descriptive and non-prescriptive**: it records gaps; it does *not* turn a gap into a
pipeline requirement. `[MAP-1]`

**Evidence categories** (each observable below is labelled with exactly one):
- **E1 — available now:** present at the Intelligence input or derivable from it deterministically.
- **E2 — technically observable but not recorded:** a stage computes or could expose it, but nothing records it.
- **E3 — semantics do not exist:** the concept is undefined in the product/pipeline.
- **E4 — requires external or contextual data:** needs a curated lexicon/vocabulary or data outside the text.
- **E5 — inappropriate to collect without a separately justified use case:** collecting it is a privacy/sensitivity or scope question that no current rule justifies.

**Non-requirement rule.** Absence of an observable only blocks the rules that declare it (`[EP-3]`); this map creates **no blanket pipeline requirement**. In particular, a **finality signal** and **target-field context** are *not* required
by any mapped operation and MUST NOT be introduced on the strength of this map: **PO-I remains authoritative** (hotkey release is not evidence of finality; no rule may infer it; neither is introduced). `[MAP-2]`

**Operations still capable of becoming T1/T2** (retired A1 and A2a are not mapped; classes that are T3/T4 are not mapped):

### M1 — A2b interior sentence-initial capitalization
- **Owner:** unresolved (PO-O).
- **Required policy facts:** an ownership decision; a definition of "interior sentence boundary"; an abbreviation-exclusion set and its governance; the set of intentionally lowercase tokens; independence/non-interaction (I5, D-2); I2 protected spans.
- **Required observables:** the text `S₀` (**E1**); protected spans (**E1**, derivable from normalization provenance, not wired); an interior sentence-boundary observable (**E3**); an abbreviation lexicon with id/version/curator (**E4**, does not exist).
- **Currently available:** `S₀`; protected spans.
- **Missing capability:** boundary semantics (E3); curated abbreviation lexicon (E4).
- **Provenance requirement:** lexicon id, version, content hash and authorization record (`[V-4]`); observables from deterministic stages (`[V-1]`, `[V-2]`). *Not required:* punctuation origin, settings snapshot, finality, field context (interior edits do not read them).
- **Unresolved PO / investigation:** PO-O (ownership); PO-L (lexicon governance); FE2 (boundary feasibility on real dictation).
- **Status:** L0 / NOT AUTHORIZED; blocked.

### M2 — A3 month/day-name capitalization
- **Owner:** unconfirmed (Intelligence vs a future deterministic date normalizer).
- **Required policy facts:** the closed name set; homograph disambiguation (not invented here); whether date surface forms are record-sensitive (PO-J); ownership.
- **Required observables:** `S₀` (**E1**); protected spans (**E1**); a date-expression observable (**E3**); the closed month/day list as a versioned table (**E4**, small and static, but a curated artifact).
- **Currently available:** `S₀`; protected spans.
- **Missing capability:** date-expression semantics (E3); versioned name table and its disambiguation context (E4/E3).
- **Provenance requirement:** table id/version/hash (`[V-4]`); the date-expression observable's producer and version (`[V-1]`).
- **Unresolved PO / investigation:** PO-J; FE4 (distribution of date expressions and homograph use).
- **Status:** L0 / NOT AUTHORIZED.

### M3 — A4 per-matter vocabulary operations
- **Owner:** unconfirmed.
- **Required policy facts:** vocabulary governance (verification, per-matter versioning, confidentiality), matching semantics, entity typing, operation scope (PO-C, PO-L).
- **Required observables:** `S₀` (**E1**); a per-matter vocabulary with id/version/hash/curator authorization (**E3** — no schema or source exists; **E4** — derived from matter data); a binding of the vocabulary to the matter (**E3**).
- **Currently available:** `S₀`. The user-level custom dictionary exists (**E1** as a store; its past substitutions are **E2**: computed upstream, unrecorded) but is not an entity vocabulary.
- **Missing capability:** the vocabulary and its governance (E3/E4).
- **Provenance requirement:** vocabulary id, version, content hash, matter binding, curator authorization (`[V-4]`); the vocabulary is never baked into global artifacts.
- **Unresolved PO / investigation:** PO-C follow-up and PO-L; FE5 (availability of sources; ingestion feasibility). *Ingesting matter documents is **E5** until a use case justifies it.*
- **Status:** L0 / NOT AUTHORIZED.

### M4 — A5 word split with lexicon evidence
- **Owner:** unconfirmed.
- **Required policy facts:** the additional evidence beyond a lexicon (PO-N, undefined); lexicon curatorship (PO-F, PO-L); exclusions for valid compounds, names and Indian-language forms.
- **Required observables:** `S₀` (**E1**); protected spans (**E1**); a versioned general-word lexicon with curator authorization (**E3** — none exists; **E4**).
- **Currently available:** `S₀`; protected spans. The custom dictionary can express user-specific splits but is not a curated lexicon (**E1** as a store, **E2** for its past effect).
- **Missing capability:** the lexicon and the sufficiency rule (E3/E4).
- **Provenance requirement:** lexicon id, version, hash and authorization record (`[V-4]`).
- **Unresolved PO / investigation:** PO-N, PO-L; FE6 (coverage and false-split rates, model-free).
- **Status:** L0 / NOT AUTHORIZED; effectively T3.

### M5 — General whitespace / typographic normalization (a T1 candidate; deterministic processing)
- **Owner:** unresolved (PO-P); if it belongs to deterministic processing it is **not an Intelligence rule at all**.
- **Required policy facts:** an ownership decision; a rule set (collapse repeated spaces, trim, spacing around punctuation) with idempotence and no-new-defect guarantees (I6).
- **Required observables:** the text (**E1**). No model evidence, no external data.
- **Currently available:** the text. Partial behaviour exists only as a side effect of filler removal (collapse on re-join), not as a specified standalone operation.
- **Missing capability:** a specified standalone operation; a stage-version stamp (**E2**: the stage exists but its version is not recorded).
- **Provenance requirement:** stage id and version if a future rule relies on the stage having run (`[V-1]`).
- **Unresolved PO / investigation:** PO-P. Whether T1 membership is ever *normatively* assigned is a separate decision (nothing is promoted here).
- **Status:** not an Intelligence register entry; ownership unresolved.

**Observables considered and deliberately *not* required by any mapped operation:** segment finality (**E3**); target-field context (**E4/E5**); the settings snapshot (**E2**); punctuation origin (**E2**: the spoken-punctuation stage creates dictated marks but nothing
records them; needed only by a rule that distinguishes dictated from provider marks, and none is mapped); provider confidence (not evidence, `[V-2]`); audio (**E5** for these uses). If a later decision creates a rule that needs one of them, it is
recorded then as that rule's declared observable (`[EP-3]`), subject to PO-I.

# Part II — Design of the future model-free conformance evaluation (nothing here is built)

## 14. Purpose and non-claims

14.1 Purpose: measure, with no model, whether an implementation of this specification (a) classifies edits as the specification says, (b) makes the
autonomy decision the specification requires (including denial when evidence is missing), and (c) never lets an autonomous edit violate an invariant.
14.2 It supports statements about *an implementation's conformance to this specification on the frozen cases*. It does not support statements about any
model's quality, about real-dictation coverage, or about the correctness of the specification itself.
14.3 Current Authority behavior MUST NOT be used to author, adjust or relabel any expectation (an expectation is derived from specification clauses only).

## 15. Case schema

A case is an immutable record:

| Field | Content |
|---|---|
| `caseId` | stable id; never reused |
| `schemaVersion`, `specVersion` | the schema and the policy specification version it is bound to |
| `family` | `predicate-conformance` \| `classification` \| `invariant` \| `composition` \| `authorization-state` (§23) \| `ownership` (§23: an edit in a retired or unresolved subclass; expected outcome derived from §6A) |
| `subclassId` | subclass (or `none`) |
| `role` | `positive` \| `negative` \| `boundary` \| `missingEvidence` \| `composition` \| `hazard` |
| `source` | the text `S₀` (synthetic; see provenance) |
| `observables` | snapshot of every observable supplied (ids, versions, content hashes, values), including protected spans; absent observables are listed as absent |
| `edits` | one or more edits (expected-source, replacement, range) |
| `expectations` | three separate blocks, §17 |
| `derivation` | for each expectation, the clause ids (`[C-1]`, `[EP-6]`, `[I3]`…) from which it follows, with a one-paragraph justification that does not mention any observed behavior |
| `provenance` | author, authoring date, method (hand-authored / template id), and the hash of the disjointness report (§21) |
| `status` | `frozen` only after §23 |

## 16. Case roles (structural requirements per included subclass)

For every included T2 subclass: at least one each of **positive** (autonomy permitted *because the predicate returns Verified*), **negative** (predicate
returns Denied), **boundary** (at the edge of a stated condition), and **missingEvidence** (a required observable absent/stale/unverifiable ⇒ autonomy
denied). For T3/T4 subclasses: **positive** (classified as intended) and **hazard** (a near-miss that must not be classified into a more permissive
tier). Composition cases per §20. Case counts are a construction-time decision justified in the readiness record; this design fixes no number.

## 17. Expectations are separated

Each case carries three independent expectation blocks, each citing clauses:
1. **Classification expectation** — {class, subclass, tier} (or `unclassified ⇒ T4`).
2. **Authorization expectation** — {autonomy: `permitted` \| `denied`; predicate id@version; verdict `Verified` \| `Denied(reason)` \| `Unknown(reason)`}. For a T2
   subclass this block may be frozen only if the predicate is at L2 or later (§23, R2/R3).
3. **Invariant expectation** — the set of invariants I1–I10 that *applying the edit* would violate (empty if none), independent of tier and of authorization.

An implementation passes a block only by matching that block; the blocks are never merged.

## 18. Reporting (no blended scores)

Reported as raw counts with denominators, by **tier** and by **subclass**, and by **role**: (a) classification agreement; (b) authorization agreement
(autonomy permitted/denied), with `missingEvidence` failures listed separately; (c) verdict agreement (Verified/Denied/Unknown + reason); (d) composition
agreement. **No composite score, rate-blend or threshold is defined by this design.** A hard criterion (§19) is a raw count that must be 0.

## 19. Policy-invariant violations independent of answer keys (PO-H)

19.1 The primary safety measure is the **number of autonomous applications that violate any invariant I1–I10**, a raw count with hard target 0, computed by an
**independent invariant checker** — a separate implementation, written from §5 and not from the implementation under test — applied to the *actual* result of
each case (the text before and after, the edit set, the observables). It uses no case answer key.
19.2 It is reported separately from the three expectation blocks. A violation is recorded even if the case's authorization expectation was `permitted`
(which would reveal a specification or case defect), and even if the implementation under test agrees with its own classification.
19.3 Corpus answer-key foreignness (a U1-type measure) is **not** part of conformance and MUST NOT be reported as a safety outcome of this evaluation (PO-H).

## 20. Composition and dependent-edit cases

Cases with two or more edits cover: independent edits (any order gives one result; joint invariants hold); dependent edits under D-2(a) and D-2(b) (expected:
not autonomous absent a pair rule); adjacent/touching edits; overlapping edits; a batch exceeding the size bound (expected `Unknown(resourceBound)`); and a
chain in which one edit would create another's evidence. The expected outcome is derived from §11, never from observation.

## 21. Disjointness from every existing corpus

The case texts and corrections MUST be disjoint, under the V1.27 overlap rules P1–P7 (reused unmodified), from **all** of: the V1.23 benchmark (44), the
V1.27 development corpus (66) and its 21 hazard fixtures, the S2 tooling fixtures (13), the V1.31 probe cases (32), and the V1.12 / V1.14 / V1.15 / V1.13
corpora (independent-protection, autonomous-policy development / validation / fresh, numeric-structure). Each corpus is enumerated by its pinned hash in a
disjointness report whose hash is recorded in every case's provenance; the check must also be shown sensitive by injected copies.

## 22. Freeze and versioning rules

22.1 The case set is frozen as one hashed manifest bound to the policy specification version, the schema version, the checking tooling hashes and the
disjointness report. 22.2 **Blind freeze:** expectations are written and reviewed *before* any implementation is run on any case; running an implementation on
unfrozen cases is not permitted to influence them. 22.3 Once frozen the set is immutable: a defect is disclosed and fixed in a new version, never repaired.
22.4 A change to the specification, a predicate version, or an observable version invalidates the affected cases' bindings; they must be re-versioned and re-frozen.
22.5 No expectation may cite an observed implementation or model output as justification.

## 23. Corpus-readiness gate

The conformance corpus MUST NOT be constructed until **all** hold:
- **R1** the policy specification is frozen (committed) at a version, and the Authorization Register exists with its current state;
- **R2** *every subclass to be included has an unambiguous normative expectation*: its tier is fixed by this specification and its classification rule is stated
  without discretion; a T2 subclass is included only if its **ownership is confirmed as Intelligence** (§6A) *and* its predicate is at **L2 or later** (specified, with observables defined and conformance defined);
- **R3** **a provisional, unspecified or underspecified predicate receives no frozen expected-autonomy label for that predicate.** Such a subclass is excluded
  from the predicate-conformance family. It MAY appear only in the separate **authorization-state family**, whose single expectation — *autonomy denied because
  the register records the rule as not authorized* — is derived from the register state (not from any predicate), is bound to a register version, and becomes
  invalid when that state changes. Likewise a **retired or unresolved-ownership** subclass MAY appear only in the **ownership family**, whose single expectation —
  *not Intelligence-applicable: not autonomous, not proposed, not suggested* — is derived from §6A and the register, bound to a register version;
- **R4** the disjointness tooling and register of corpora (§21) are ready and shown sensitive;
- **R5** the independent invariant checker (§19) is specified and its independence from the implementation under test is defined;
- **R6** the observable snapshot format and the case schema are fixed;
- **R7** the reporting template (§18) is pre-registered, including the statements the evaluation may and may not support;
- **R8** the Product Owner has authorized the scope of the case families to be built;
- **R9** the evaluation runner design is reviewed and guaranteed model-free.

**Present status against the gate: not ready, unchanged from v1.0.** R2/R3 cannot be met for any T2 subclass: none has confirmed Intelligence ownership with a predicate at L2 or later (A2b is
ownership-unresolved; A3, A4, A5 are at L0 with ownership unconfirmed and no predicate). The ownership reconciliation of v1.1 does not satisfy any gate condition.

---

# Part III — Open questions, by who or what can resolve them

## 24. Resolved normatively at v1.1

- **Ownership is an explicit prerequisite** to classification and authorization; an operation outside Intelligence ownership cannot become autonomous Intelligence by satisfying a tier predicate; unresolved ownership fails closed; ownership is neither authorization nor validation (§6A).
- **PO-I and PO-K are normative** (§3.2): no finality semantics, none inferable from segment end or hotkey release, no finality signal or field context introduced; Intelligence does not own terminal punctuation or segment-initial capitalization.
- **A1 and A2a are retired from Intelligence ownership; A2 is split** and nothing is inherited through the split (§0.4, §7.5).
- **A5's tier position is derived from adopted policy** (I1 + PO-F), not newly decided: T3 default, T2 ceiling not excluded, unchanged status (§7.4).
- **X1 and X2 are corrected where they affect the normative text** (`[V-3]`, §13); the V1.32 file is unchanged.
- **The evidence capability map is descriptive, with no blanket pipeline requirement** (§13A, `[MAP-1]`, `[MAP-2]`).
- The conformance design gains an ownership family and an ownership condition in the readiness gate; **the gate stays closed** (§23).
- All v1.0 resolutions (classification vs authorization, lifecycle, predicate contract, failure semantics, composition, provenance, register, case schema, disjointness, freeze, inadmissibility of learned evidence) carry over unchanged.

## 25. Unresolved Product Owner decisions

- **PO-O** ownership of interior sentence-initial capitalization (Intelligence T2 / new deterministic processing / neither) — blocks A2b.
- **PO-P** ownership of general whitespace/typographic normalization (M5).
- **PO-Q** ownership confirmation for each remaining T2 candidate (A3, A4, A5) — required before any can leave L0 (`[O-4]`).
- **PO-J** whether the surface form of a spelled date is record-sensitive (I2) and whether dates go to a future deterministic date normalizer (A3).
- **PO-L** governance of any abbreviation lexicon (A2b), split lexicon (A5) and per-matter vocabulary (A4), including matter-data confidentiality.
- **PO-M** the authorization standard: what residual-risk statement and conformance evidence suffice to authorize a T2 rule.
- **PO-N** what suffices alongside a split lexicon (A5; completing PO-F).
- **PO-G** review UX (T3 has no application path); **PO-2**, **PO-3**.
- Carried as an architectural goal, not a decision: **PO-E** punctuation provenance — recorded only if a future rule declares it needed (none is mapped).

## 26. Future evidence investigations

- **FE2** feasibility of a *deterministic* interior sentence-boundary rule with an abbreviation exclusion on real judicial dictation, without ML (A2b).
- **FE4** distribution of date expressions and homograph month-name use in real dictation (A3).
- **FE5** availability and ingestion feasibility of per-matter vocabulary sources (A4) — subject to the E5 caveat.
- **FE6** split-lexicon coverage and false-split rates, model-free, on real text (A5).
- **FE1′** (conditional) whether and how the spoken-punctuation stage could record which marks it generated — *only if* a future rule declares punctuation origin as a required observable.
- *Completed:* FE1 and FE7 were investigated in V1.33 (finality is established nowhere; formatters run after the hand-off; X1–X5). *No longer needed:* FE3 (frequency/cause of missing terminal marks) — A1 is retired.

## 26A. Areas retired from Intelligence ownership

| Id | Area | Decision | Note |
|---|---|---|---|
| A1 | terminal-period correction | PO-K | presentation concern; PO-I forbids inferring finality; no Intelligence rule |
| A2a | segment-initial capitalization | PO-K | presentation concern in the existing downstream formatting layer |

Retirement neither authorizes nor classifies the downstream behavior (`[O-5]`) and does not move any lifecycle state (no authorization existed).

---

# 27. Smallest justified next milestone

**V1.35 — ownership decision record (documentation only).** Nothing can leave L0 until ownership is confirmed (`[O-4]`), and the readiness gate cannot open without it (§23 R2). The smallest step is a short Product Owner decision record on
**PO-O, PO-P, PO-Q** (and PO-J where it decides A3's route), each answered from the options already framed (§13, §13A). Possible outcomes and their effect: if A3–A5 are not confirmed as Intelligence-owned and A2b goes to deterministic
processing or to "neither", **the autonomous-T2 track has no ready candidate**, the register shrinks accordingly, and the justified pivot becomes the review (T3) path (PO-G) or the deterministic-processing specification for
whitespace (M5) — a Product Owner choice. No predicate drafting, corpus, implementation or model is justified before ownership is decided.
