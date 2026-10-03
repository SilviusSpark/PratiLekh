# Intelligence V1.32 — Autonomous correction policy: normative specification and conformance-evaluation design

**Specification and design only.** No model was run; no production Authority, autonomous-permission gate, contract or `Sources/` file changed; no T2
rule or predicate was implemented or authorized; **no conformance corpus was created or frozen**; no existing corpus, result or label was altered.
Authority: the committed V1.31 document (`V1_31_AUTONOMOUS_CORRECTION_POLICY_INVESTIGATION.md`, §A adopted decisions) and repository documentation.
The *current* Authority's behavior and the V1.23/V1.25/S3 model outputs do **not** define anything below; they appear only as historical
motivation or illustration (§13, §A-notes).

**Structure.** Part I (§1–§13) is the **normative specification**. Part II (§14–§23) is the **design** of a future model-free conformance
evaluation (nothing in it is built). Part III (§24–§26) classifies open questions. §27 is the next milestone. Clause identifiers (e.g. `[F-2]`)
are stable references for later case expectations; `scripts/check_intelligence_v1_32_spec_consistency.sh` verifies the document's internal
consistency and its fidelity to V1.31.

---

# Part I — Normative specification

## 1. Status and language

1.1 The words MUST, MUST NOT, SHOULD and MAY are normative. This specification is **implementation-independent**: it constrains observable policy
behavior, not any type, file or algorithm. It does not describe, and is not derived from, the current Safety Authority or gate.
1.2 Version: **policy specification v1 (V1.32 draft until frozen by commit)**. Changing any normative clause requires a new version and an explicit
Product Owner decision; a defect found later is disclosed and fixed by a new version, never silently edited.
1.3 Precedence: PO-A–PO-H (§3) > invariants (§5) > the remaining clauses > the informative notes and Part II/III.

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

## 3. Frozen Product Owner decisions (verbatim from V1.31 §A; MUST be preserved)

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

**Current authorization state: no T2 class is currently authorized**, because no required deterministic evidence predicate has yet been specified
*and* authorized for any class (§7). Consequently no model-proposed edit is autonomous under this specification today.

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

## 7. Authorization Register (normative state)

7.1 The register records, per rule, its lifecycle state (§8), predicate id and version, observables required, the Product Owner authorization record
(who, when, exact versions), and revocations. It is append-only; an entry is never edited in place.
7.2 **Register state at v1 (current):**

| Area | Subclass | Tier ceiling | Predicate | State | Autonomy today |
|---|---|---|---|---|---|
| Punctuation | terminal period at end of a segment | T2 | — | **NOT AUTHORIZED** (proposed; predicate unspecified, §13 A1) | none |
| Capitalization | sentence-initial capitalization (model proposal) | T2 | — | **NOT AUTHORIZED** (proposed; predicate unspecified, §13 A2) | none |
| Capitalization | month/day-name capitalization | T2 | — | **NOT AUTHORIZED** (proposed; predicate unspecified, §13 A3) | none |
| Names/titles/places | operation supported by a verified per-matter vocabulary | T2 | — | **NOT AUTHORIZED** (vocabulary does not exist; §13 A4) | none |
| Whitespace | word split supported by lexicon evidence | T3 (T2 only with additional specified evidence) | — | **NOT AUTHORIZED** (§13 A5) | none |

7.3 No other subclass is a T2 candidate in this specification. Adding one requires §8 from the beginning. `[R-1]`

## 8. Lifecycle of a future T2 rule

States are strictly ordered; no state may be skipped, and an entry into a later state without the recorded completion of the earlier one is void. `[L-1]`

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
12.3 User settings that change the text (for example options that remove a trailing period or lowercase a first letter) and provider-originated facts
(for example ASR-inserted punctuation) are **recorded facts with provenance**; they are never evidence of the judge's intent unless a predicate states so
explicitly and that use is covered by its authorization. `[V-3]`
12.4 A lexicon or vocabulary observable records id, version, content hash and the record of who authorized that version (curatorship is open, PO-F). `[V-4]`
12.5 If punctuation provenance (dictated / provider / deterministic stage) is not derivable, a predicate that needs it returns `Unknown(missingObservable)`;
its derivability is not assumed (PO-E). `[V-5]`

## 13. Prospective T2 areas — can a predicate presently be specified?

**Method.** For each area, the question is whether a predicate meeting §9 can be written *from product semantics alone, without inventing heuristics*. Where
not, the missing observables and blockers are recorded and the area stays **NOT AUTHORIZED** at L0. Repository facts are cited only as evidence of what
is *unknown at the Intelligence boundary*, never as the definition of the policy. (Facts read from `ASRService.swift`: the deterministic formatting stage
can optionally strip a trailing period or lowercase a leading capital, and chains continuous-dictation segments using preceding text, so the text
Intelligence receives may be one segment of a longer dictation and its surface may reflect user settings.)

| Area | Specifiable now? | Verdict |
|---|---|---|
| **A1 Terminal period** | No | blocked: B-A1.1…A1.4 |
| **A2 Sentence-initial capitalization** | No | blocked: B-A2.1…A2.5 |
| **A3 Month/day-name capitalization** | No (outline only) | blocked: B-A3.1…A3.3 |
| **A4 Per-matter-vocabulary operations** | No | blocked: B-A4.1…A4.5 |
| **A5 Word split with lexicon evidence** | No | blocked: B-A5.1…A5.4 |

**A1 — Terminal-period insertion (potential T2; PO-B).** *Product semantics available:* a period added where no mark exists; addition-only (I4); not
inside a protected span. *Missing observables / blockers:*
- B-A1.1 **Segment finality.** What unit Intelligence receives and whether it is *complete* (the judge may continue, and continuous-dictation chaining appends
  segments) is a product semantic that is not defined at the Intelligence boundary. Without it "end of segment" has no meaning.
- B-A1.2 **Why no mark exists.** The absence of a terminal mark can result from a user setting, a provider omission, an incomplete utterance or the judge's
  deliberate choice; no observable distinguishes them (PO-E; V-3).
- B-A1.3 **Terminal exclusions.** Which trailing tokens must exclude a period (abbreviations, enumerations or list markers, headings, quoted text,
  identifiers, numerals) is not specified, and deriving it would be inventing a list.
- B-A1.4 **Ownership.** Whether this operation belongs to the deterministic formatting stage (T1) rather than to model-proposal evidence (PO-A) is undecided.
*Not specifiable now.* What would specify it: product definition of segment finality and of the exclusion rules, and an observable for punctuation provenance.

**A2 — Sentence-initial capitalization for a model proposal (potential T2; PO-B).** *Product semantics available:* raising the first letter of a lowercase
alphabetic token that begins a sentence; never lowering; outside protected spans; not produced by another edit (D-2). *Blockers:*
- B-A2.1 **Sentence-boundary determination** with an abbreviation exclusion ("viz.", "Rs.", honorific/title abbreviations): no specified boundary observable
  and no abbreviation lexicon exists.
- B-A2.2 **Abbreviation-lexicon governance:** existence, content, versioning and curator are unresolved (PO-F extends to this lexicon).
- B-A2.3 **Start-of-text semantics:** whether the start of the presented text is a sentence start depends on B-A1.1 (a continued segment is not).
- B-A2.4 **Intentionally lowercase tokens:** which lowercase-initial tokens at a boundary are deliberate (identifiers, unit or abbreviation forms) is not specified.
- B-A2.5 **Ownership:** whether this is T1 deterministic formatting (the pipeline already has context-aware capitalization settings) or T2 evidence is undecided.
*Not specifiable now.*

**A3 — Month/day-name capitalization (potential T2).** *Product semantics available:* a closed set of month and weekday names; raising only. *Blockers:*
- B-A3.1 **Homographs.** Several members are ordinary words ("may", "march", "august", "sat", "sun"); a closed list alone cannot verify the intended use,
  and a context pattern to separate them would have to be invented (no pattern is specified by product semantics).
- B-A3.2 **Record-sensitivity.** Whether the surface form of a spelled date is a record-sensitive token under I2 is a Product Owner question (spelled dates are
  currently outside any protected span); and whether dates should instead be normalized by a future deterministic date normalizer (T1) makes the T2 route
  possibly moot (date normalization is a deferred Phase-3 family).
- B-A3.3 **Observable:** no date-expression observable exists.
*An outline exists (closed set + required context) but it is not a predicate.* Not specifiable now.

**A4 — Operations supported by a verified per-matter vocabulary (names, titles, places; PO-C).** *Product semantics available:* none beyond the decision that
model judgment alone never suffices. *Blockers:*
- B-A4.1 **The vocabulary does not exist** (no schema, no source, no ingestion path).
- B-A4.2 **Governance:** who verifies entries, how they are versioned per matter, confidentiality of matter data (never baked into global artifacts).
- B-A4.3 **Matching semantics:** token boundaries, multi-word entries, collisions with ordinary words ("Rose", "Bench"), case-insensitive equality.
- B-A4.4 **Operation scope:** capitalization only, or spelling normalization to the vocabulary form (the latter is a lexical substitution: T3 at most, PO-D).
- B-A4.5 **Entity typing:** whether an entry licenses names, titles or places differently.
*Not specifiable now;* PO-C requires a separate specification once a vocabulary exists.

**A5 — Word split supported by a curated lexicon (PO-F).** *Product semantics available:* PO-F says lexicon evidence contributes but does not suffice. *Blockers:*
- B-A5.1 **Lexicon existence, content and curator** (unresolved).
- B-A5.2 **The additional evidence** that would complete authorization is undefined (the decision says lexicon evidence alone is insufficient but does not say
  what suffices).
- B-A5.3 **Valid compounds and names:** a lexicon cannot by itself exclude legitimate single tokens, names or Indian-language forms.
- B-A5.4 **Information change:** a split changes the token sequence (I1), so even a verified split carries the heaviest burden.
*Not specifiable now; remains T3 scope.*

**T1 note.** Whitespace/typographic normalizations (collapse repeated spaces, trim, spacing around punctuation) are T1: they are specified, if at all, in the
deterministic pipeline's own specification, not as T2 rules. They are not authorization candidates here.

---

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
| `family` | `predicate-conformance` \| `classification` \| `invariant` \| `composition` \| `authorization-state` (§23) |
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
  without discretion; a T2 subclass is included only if its predicate is at **L2 or later** (specified, with observables defined and conformance defined);
- **R3** **a provisional, unspecified or underspecified predicate receives no frozen expected-autonomy label for that predicate.** Such a subclass is excluded
  from the predicate-conformance family. It MAY appear only in the separate **authorization-state family**, whose single expectation — *autonomy denied because
  the register records the rule as not authorized* — is derived from the register state (not from any predicate), is bound to a register version, and becomes
  invalid when that state changes;
- **R4** the disjointness tooling and register of corpora (§21) are ready and shown sensitive;
- **R5** the independent invariant checker (§19) is specified and its independence from the implementation under test is defined;
- **R6** the observable snapshot format and the case schema are fixed;
- **R7** the reporting template (§18) is pre-registered, including the statements the evaluation may and may not support;
- **R8** the Product Owner has authorized the scope of the case families to be built;
- **R9** the evaluation runner design is reviewed and guaranteed model-free.

**Present status against the gate: not ready** (R2/R3 cannot be met for any T2 subclass while no predicate is specified; the register has no entry above L0).

---

# Part III — Open questions, by who or what can resolve them

## 24. Resolvable architecturally now — resolved by this specification

AQ1 classification is separate from authorization (§6); AQ2 the T2 rule lifecycle (§8); AQ3 the evidence-predicate contract (§9); AQ4 failure/missing-evidence/ambiguity
deny autonomy and never fall back to model judgment (§10); AQ5 composition and dependent-edit semantics (§11); AQ6 provenance requirements (§12); AQ7 authorization
binds exact versions and is revocable (§8.2–8.3); AQ8 the register and its current state (§7); AQ9 the conformance case schema, expectation separation, reporting and
independent invariant checking (§15–§19); AQ10 disjointness and freeze rules (§21–§22); AQ11 the corpus-readiness gate (§23); AQ12 learned/probabilistic components are
inadmissible as evidence (a consequence of PO-A/I7; revisable only by explicit PO decision).

## 25. Requiring Product Owner decisions

- **PO-I Segment finality.** What unit does Intelligence receive and may it be incomplete or continued? (blocks A1, A2)
- **PO-J Spelled dates.** Is the surface form of a spelled date record-sensitive (I2), and should dates be handled by a future deterministic date normalizer instead of T2? (A3)
- **PO-K Ownership.** Which of terminal punctuation, sentence-initial capitalization and typographic normalization belong to deterministic processing (T1) rather than Intelligence? (A1, A2)
- **PO-L Lexicon and vocabulary governance.** Curator, versioning and authorization of an abbreviation lexicon (A2), a split lexicon (A5; extends PO-F) and a per-matter vocabulary (A4, PO-C), including matter-data confidentiality.
- **PO-M Authorization standard.** What residual-risk statement and what conformance evidence suffice to authorize a T2 rule (zero invariant violations on a frozen suite is necessary; is it sufficient?).
- **PO-N What suffices alongside a split lexicon** (completing PO-F; A5).
- Carried: **PO-E** provenance feasibility is not a decision but an investigation (§26); **PO-G** review UX; **PO-2**, **PO-3**.

## 26. Requiring future evidence or investigation

- **FE1 Punctuation provenance derivability:** whether provider/pipeline stages expose dictated vs provider vs deterministic punctuation (investigation of the transcription providers and formatting stage). Blocks A1, A2 (PO-E).
- **FE2 Boundary feasibility on real judicial dictation:** how reliably a *deterministic* sentence-boundary rule with an abbreviation exclusion can be specified, using real (private) dictation, without ML (A1, A2).
- **FE3 Frequency and cause of missing terminal marks** (provider omission vs settings vs deliberate), measured on real dictation (A1).
- **FE4 Real distribution of date expressions and homograph month names** in judicial dictation (A3).
- **FE5 Availability of per-matter vocabulary sources** (case documents, cause lists) and ingestion feasibility (A4).
- **FE6 Split-lexicon coverage and false-split rates** measured model-free on real text (A5).
- **FE7 What the deterministic formatting stage already guarantees** (and under which settings), as a factual input to PO-K.

---

# 27. Smallest justified next milestone

**V1.33 — resolve the blockers that gate the corpus, starting with the two that need no new tooling:** (1) obtain the Product Owner decisions PO-I, PO-K
(and PO-J, PO-L, PO-M, PO-N as they become relevant) as a short decision record, and (2) perform the read-only investigation FE1 + FE7 (what the existing
providers/pipeline can expose about punctuation provenance and what the deterministic formatter already guarantees). These can change which areas ever
become T2 at all, so they come before any predicate drafting. **No corpus, no implementation, no model.** If the decisions move an area to T1 or T3, the
conformance design in Part II still stands unchanged for the remaining subclasses. A conformance corpus becomes appropriate only after §23's gate is met, which at
present would require at least one subclass reaching L2 — none is close.
