# Intelligence V1.14 — Autonomous Edit Policy Investigation

## 1. Status and scope

Investigation and evaluation only. **No production classifier or Safety Authority
change was made.** Nothing under `Sources/` changed. No new production recognizer
was added. Everything below is deterministic, model/provider-independent, and
measures the *remaining* gap after the existing V1.11 (derived normalization spans)
and V1.13 (numeric structural protection) defenses — not the raw classifier alone.

Artifacts:

| Artifact | Role |
|---|---|
| `Evaluation/References/autonomous-edit-policy/README.md` | Pre-registered rubric, candidate invariants, protocol, freeze record |
| `Evaluation/References/autonomous-edit-policy/development.json` (155 entries) | Used to define and refine invariants |
| `Evaluation/References/autonomous-edit-policy/validation.json` (126 entries) | Authored **after** the freeze; scored once, untuned |
| `Evaluation/Intelligence/Experimental/AutonomousEditInvariants.swift` | Candidate invariants (frozen; SHA-256 pinned) |
| `Evaluation/Intelligence/Experimental/AutonomousEditPolicyInvestigation.swift` | Harness: real normalization → real V1.11/V1.13 → real classifier → real Authority |
| `scripts/test_autonomous_edit_policy_investigation.sh` | On-demand runner; pins every number below and the corpora/rules hashes |

## 2. What the current predicates already accept

Measured directly against `IntelligenceEditClassifier` (see the README for the full
character-class probe):

- **punctuation-only** strips every `Character.isPunctuation` from both strings and
  compares. That set is wide — it includes apostrophes, hyphens, slashes, quotes,
  brackets, `% & @ # *`, not just sentence punctuation — so `Hon'ble→Honble`,
  `15%→15`, `u/s→us`, `PW-1→PW1`, `Ext. P-1→Ext. P1`, `a@b.com→ab.com` are all
  autonomous today.
- **whitespace-only** strips whitespace (no newlines) and compares, so
  `Ram Das→RamDas`, `12th July→12thJuly`, `Section 376A→Section 376 A` are
  autonomous.
- **capitalization-only** is `lowercased()` equality, so `IPC→ipc`, `CrPC→crpc` are
  autonomous regardless of position or acronym-ness.

## 3. Protocol discipline

Development and validation are disjoint corpora, both frozen (SHA-256 pinned by the
harness), with the rules file also frozen and pinned. Three refinements were made
**during development, before the freeze**, and are recorded in the README rather
than silently folded in: (1) one mislabeled development entry was corrected and
removed; (2) the acronym rule was widened from "all letters uppercase" (C-A) to
"≥2 uppercase letters" (C-A2), because `CrPC→crpc` and `McDonald→Mcdonald` are mixed
case; (3) "no token-boundary change" (W-A) was split into merge-only (W-A1) and
split-only (W-A2), because — a central finding — they have very different costs
(§6). The validation corpus was authored after this record and scored once; no
label or rule was changed afterward. A pure identifier rename
(`whitelist`→`allowlist`, prompted by a lint rule) was verified to leave all 162
recorded numbers unchanged before being re-pinned (recorded in the README).

## 4. The funnel: how much of the classifier's leniency remains exploitable today

| Expectation | n | classifier autonomous | + V1.11 spans | + V1.13 (effective, today's defenses) |
|---|---|---|---|---|
| **Development** legit | 69 | 69 | 68 | 68 |
| **Development** dangerous | 74 | 74 | 73 | 71 |
| **Development** ambiguous | 12 | 12 | 12 | 12 |
| **Validation** legit | 48 | 48 | 48 | 48 |
| **Validation** dangerous | 68 | 68 | 68 | 67 |
| **Validation** ambiguous | 10 | 10 | 10 | 10 |

V1.11/V1.13 remove only a handful of dangerous cases (edits landing inside a
resolved statutory/witness span, or touching digit structure) — **the large
majority of dangerous edits (71/74 dev, 67/68 validation) are still autonomously
acceptable today**, confirming the gap V1.12 predicted for non-numeric,
non-already-normalized text. One legitimate edit in each tier is already
*not* autonomous (an edit that reaches into a resolved witness span) — an
existing, expected side effect of V1.11, not a new finding.

## 5. Remaining gap by hazard and predicate (validation tier; development tracks closely)

| Hazard | Remaining autonomous | Predicate |
|---|---|---|
| acronymCase (`IPC→ipc`) | 8/8 | capitalization |
| alphanumericIdentifier (`PW-1→PW1`) | 6/6 | punctuation |
| designatorCase (`Ext. P-9`, `P→p`) | 4/4 | capitalization |
| digitLetterBoundary (`Section 302→Section302`) | 6/6 | whitespace |
| identifierCase (`P9→p9`) | 2/3 | capitalization |
| intraTokenPunctuation (`Hon'ble→Honble`) | 10/10 | punctuation |
| midTokenCase (`CrPC→Crpc`) | 3/3 | capitalization |
| spelledNumber (`twenty six→twentysix`) | 6/6 | punctuation/whitespace |
| structuralPunctuation (`15%→15`) | 8/8 | punctuation |
| wordMerge (`Ram Das→RamDas`) | 9/9 | whitespace |
| wordSplit (`constable→const able`) | 5/5 | whitespace |

Every hazard class the investigation examined has **at least one predicate through
which it remains autonomously exploitable** after existing protections; none is
already contained.

## 6. Candidate invariants: benefit vs cost (validation tier; development in parentheses)

| Invariant | Class | Dangerous blocked (of 67/71 remaining) | Legit demoted (of 48/68) | Ambiguous demoted (of 10/12) |
|---|---|---|---|---|
| W-A (any boundary change) | whitespace | 25 (26) | **3 (3)** | 0 (0) |
| **W-A1 (merge only)** | whitespace | 19 (20) | **0 (0)** | 0 (0) |
| W-A2 (split only) | whitespace | 6 (6) | **3 (3)** | 0 (0) |
| W-B (routine-spacing allowlist) | whitespace | 25 (26) | 5 (5) | 2 (3) |
| **P-A (routine-punctuation allowlist)** | punctuation | 22 (25) | **0 (0)** | 2 (2) |
| **P-B (no intra-token change)** | punctuation | 19 (20) | **0 (0)** | 2 (3) |
| C-A (all-caps token lowering) | capitalization | 9 (13) | 1 (1) | 0 (0) |
| C-A2 (≥2-cap token lowering) | capitalization | 12 (16) | 1 (1) | 0 (0) |
| C-B (mid-token case change) | capitalization | 14 (18) | 5 (5) | 0 (0) |
| **C-C (identifier: token has a digit)** | capitalization | 2 (2) | **0 (0)** | 0 (0) |
| C-D (any lowering, raise-only) | capitalization | 17 (18) | 4 (5) | 3 (3) |
| allowlist bundle (W-B+P-A+C-D) | mixed | 64 (69) | 9 (10) | 7 (8) |
| core bundle (W-A+P-B+C-A2+C-C) | mixed | 58 (64) | 4 (4) | 2 (3) |
| core+P-A | mixed | 64 (71) | 4 (4) | 3 (4) |
| **core-merge-only+P-A (W-A1+P-B+P-A+C-A2+C-C)** | mixed | **58 (65)** | **1 (1)** | 3 (4) |

**Key finding — merges and splits are not one invariant.** W-A1 (block only a
whitespace edit that *merges* two word-forming tokens) has **zero legitimate cost
on both tiers** and blocks every `wordMerge` case plus part of `digitLetterBoundary`
and `spelledNumber`. W-A2 (block only a *split*) costs 3 legitimate edits on both
tiers — exactly the ASR run-together-word repairs (`witnessreached→witness
reached`, `wasarrested→was arrested`, `thatthe→that the`) that are common,
desirable autonomous cleanup. **Splitting a run of letters is legitimate exactly
when the two halves are real words and dangerous exactly when they are not
(`constable→const able`)** — a distinction this investigation could not find a
free deterministic signal for; only a dictionary/word-list would distinguish them,
which is semantic recognition, out of scope for a generic invariant.

**Punctuation invariants are the cleanest finding.** P-A and P-B each cost **zero**
legitimate edits on both tiers (only 2–3 *ambiguous* items, e.g. `Mr. Das→Mr Das`,
deliberately excluded from the false-rejection count) while together closing
`intraTokenPunctuation`, `structuralPunctuation` and `alphanumericIdentifier`
almost completely. They are complementary, not redundant: P-A misses intra-token
periods (`S.K.→SK`, in the routine-punctuation allowlist) that P-B catches; P-B
misses non-intra-token structural punctuation (`15%→15`, `(Rupees...)→Rupees...`)
that P-A catches.

**Capitalization is two, not one, distinct hazards, each partially costly.**
C-A2 (multi-capital lowering) catches genuine acronyms (`IPC`, `CrPC`, `BNSS`) at
the cost of one legitimate edit on each tier: an ASR-emitted all-caps word
(`ODISHA→Odisha`) that is not an acronym. C-C (identifier: any token containing a
digit) is free and catches alphanumeric identifiers (`P9→p9`) that C-A2 cannot
(single letters have no "≥2 uppercase"). Neither, nor their union, catches
**designatorCase** (`Ext. P-9`, lowering the single letter `P`) — a single
uppercase letter with no digit in its own token; closing it would need a
category-specific signal (a designator lexicon: `Ext.`, `Exhibit`, `M.O.`), which
repeats V1.12's rejected pattern.

**The best bundle found (`core-merge-only+P-A`) blocks 87–92% of the remaining
dangerous edits, at a cost of exactly one legitimate edit per tier — and that one
cost is caused by the acronym guard (C-A2), not by any other component of the
bundle: it is the same `ODISHA→Odisha` case identified in §6, an ASR all-caps word
that is not an acronym. Every other component of the bundle (P-A, P-B, W-A1, C-C)
contributes zero legitimate-edit cost on both tiers.** Its residual gap on both
tiers is exactly: word *splits* (deliberately not blocked, §above), one
whitespace-insertion `digitLetterBoundary` variant (`15A→15 A`, a split, not a
merge), and, on validation only, `designatorCase` (3 items) — a hazard the
development corpus did not include, discovered only in validation.

## 7. Recommendation

**Tightening generic autonomous policy is preferable to adding recognizers for
most of this gap**, with one identified exception (§8):

- **Adopt (as the recommended next-milestone scope, not yet implemented):**
  P-A, P-B, W-A1 (merge-only), C-A2, C-C. This is exactly
  `core-merge-only+P-A`: zero-cost on three of five components, near-zero
  aggregate cost (1 of 48–68 legitimate edits, an ambiguous-adjacent all-caps
  case), and no per-category lexicon.
- **Do not adopt:** W-A2/W-B-style split-blocking (too costly — blocks routine ASR
  word-boundary repair) and C-B/C-D (too costly — demote 4–5 ordinary
  capitalization fixes each).
- **No change is justified for:** word splits and the single-letter designator
  case — see §8.

This is consistent with V1.12/V1.13: a structural, category-agnostic signal
generalizes where a category-specific one does not, and is preferred whenever one
exists with acceptably low cost.

## 8. What remains unaddressed, and why it should stay unaddressed by policy alone

- **Word splits** (`constable→const able` vs `witnessreached→witness reached`):
  structurally identical; only a dictionary distinguishes them. Blocking all splits
  costs legitimate ASR-repair edits (§6); leaving them open is a real residual risk.
  **No generic invariant closes this without semantic/lexical knowledge, and none
  is proposed** — recorded as an open risk, not solved.
- **Spelled numbers/dates** (`twenty six→twentysix`): W-A1 already blocks the
  merge form; the remaining escapes are hyphen-joined (`twenty-six→twentysix`,
  a punctuation case P-A/P-B already catch) or genuinely split forms — the same
  word-split problem.
- **`designatorCase`** (`Ext. P-9→Ext. p-9`): needs a short designator lexicon to
  close for free; deferred rather than adopted now, to avoid re-opening the
  rejected pattern from V1.12 for one narrow case — a candidate for a future,
  separately-scoped, tightly bounded addition if judged worthwhile.

## 9. Boundaries respected

No name recognition, no spelled-number recognizer, no per-category lexicon in the
recommended bundle, no model calls, and no change to `IntelligenceEditClassifier`
or `IntelligenceSafetyAuthority` in this milestone. All evaluation used the real
production V1.6/V1.11/V1.13/classifier/Authority code; only the *candidate*
invariants are experimental. Corpora are synthetic and implementer-authored
(same caveat as V1.12/V1.13): they demonstrate the cost/benefit *shape*, not a
prevalence estimate on real dictation.
