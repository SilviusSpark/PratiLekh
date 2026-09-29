# V1.14 autonomous-edit-policy investigation corpora

Investigation only: nothing here changes the production classifier or Safety
Authority. This README **pre-registers** the candidate invariants, labeling rubric
and protocol before any evaluation code or corpus existed.

## What the current predicates accept (measured, `IntelligenceEditClassifier`)

- **punctuation-only**: strip every `Character.isPunctuation` from both strings and
  compare. That set is wide: `. , ; : ? !` **and** apostrophes, quotes, brackets,
  `/`, `\`, `%`, `&`, `@`, `#`, `*`, `_`, hyphen/en/em dashes, ellipsis, `§`, the
  danda `।`. (Not: `₹ $ + = < > ~ ^ | \` °`.) So `Hon'ble→Honble`, `15%→15`,
  `u/s→us`, `5,000/-→5,000`, `PW-1→PW1`, `Ext. P-1→Ext. P1`, `a@b.com→ab.com`,
  `"yes"→yes` and `(only)→only` are all autonomous.
- **whitespace-only**: strip all whitespace (no newlines) and compare. So
  `Ram Das→RamDas`, `12th July→12thJuly`, `Section 376A→Section 376 A` and
  `thewitness→the witness` are autonomous.
- **capitalization-only**: `lowercased()` equal. So `IPC→ipc`, `ipc→IPC`,
  `PW→pw`, `CrPC→Crpc` are autonomous, as are legitimate sentence-start fixes.

## Labeling rubric

Each item is one proposed edit (`source` → `replacement`, optionally with left/right
context or an occurrence, resolved by the production resolver) on a text.

- **legit** — repairs presentation without changing how alphanumeric text is
  segmented or what identifier/acronym/quantity/attribution it records: sentence and
  clause punctuation, spacing around punctuation, collapsing repeated spaces,
  capitalizing sentence starts / proper nouns / acronyms, fixing run-together words.
- **dangerous** — changes token segmentation of alphanumeric text (word merge or
  split, letter/digit boundary), removes or alters structural punctuation that is
  part of a word, identifier, abbreviation, quantity or quotation
  (`'`, `-`, `/`, `.` inside a token, `%`, `/-`, quotes, brackets, `@`, `#`), or
  destroys an acronym's/identifier's case.
- **ambiguous** — reasonable reviewers differ; reported, excluded from false
  acceptance / false rejection.

Labels are the implementer's judgment; the same caveat as V1.12/V1.13 applies
(synthetic, implementer-authored, no prevalence claim). Judgments were fixed by this
rubric before results were seen.

## Candidate invariants (defined before evaluation; each applies only to its class)

Notation: a *word-forming* scalar has general category `L*`, `M*` or `N*`. The edit
is analysed on the whole text with the span replaced (`before + expected + after`
vs `before + replacement + after`), so neighbours outside the span are visible.

| Id | Class | Demote the edit if … |
|---|---|---|
| **W-A** | whitespace | a whitespace gap is created or deleted (empty ↔ non-empty) between two word-forming scalars (merges or splits a token; includes letter/digit boundaries). Collapsing a non-empty gap to another non-empty gap is allowed. |
| **W-B** | whitespace | any changed gap is not one of: collapse to a single space; trim at text start/end; delete a gap immediately before `. , ; : ? ! ।`; insert a single space immediately after one of those before a word-forming scalar (an allowlist of routine spacing repairs). |
| **P-A** | punctuation | any changed punctuation run contains a character outside `. , ; : ? ! ।` (a class allowlist: apostrophes, hyphens, slashes, quotes, brackets, `% & @ # *` … are never autonomous). |
| **P-B** | punctuation | a changed punctuation run sits between two word-forming scalars (intra-token punctuation: `Hon'ble`, `co-operate`, `S.K.`, `u/s`, `P-1`). |
| **C-A** | capitalization | an uppercase letter becomes lowercase inside a token whose cased letters are all uppercase and number ≥ 2 (acronym lowering). |
| **C-B** | capitalization | a changed letter is not the first scalar of its token (mid-token case change). |
| **C-C** | capitalization | a changed letter lies in a token containing a decimal digit (alphanumeric identifier). |
| **C-D** | capitalization | any uppercase becomes lowercase (raise-only policy). |

Named bundles: **core** = W-A + P-B + C-A + C-C; **core+P-A** = core + P-A;
**allowlist** = W-B + P-A + C-D.

## Protocol

1. **Development tier** (`development.json`) is used to run and sanity-check the
   invariants; findings may lead to documented refinements of a rule.
2. Rule definitions are then **frozen** (the rules source file's SHA-256 is pinned in
   the harness).
3. The **validation tier** (`validation.json`) is authored after the freeze and scored
   once, without tuning; its SHA-256 is pinned.
4. Effective-pipeline evaluation: every edit is judged by the real classifier and the
   real Authority with V1.11-derived spans and V1.13 numeric spans, so measured gaps
   are those that remain **after** existing protections. An invariant's benefit is
   the dangerous edits it demotes among those still autonomous; its cost is the
   legitimate edits it demotes among those still autonomous.

## Development iteration record (before the freeze)

The first development run (156 entries) led to three documented refinements, made
**before** the validation corpus existed:

1. **Labeling correction:** one development entry (inserting an extra space before
   `IPC` in an already-spaced gap) was labeled dangerous but is harmless spacing;
   it was removed (155 entries remain).
2. **C-A → C-A2:** the all-caps acronym rule missed mixed-case acronyms/names
   (`CrPC→crpc`, `McDonald→Mcdonald`). **C-A2** demotes any uppercase→lowercase
   change in a token containing at least two uppercase letters. C-A is retained as a
   measured candidate; the bundles use C-A2.
3. **W-A split into W-A1 (merges only) and W-A2 (splits only)** — "token structure"
   is two separable rules with different costs — plus a bundle
   **core-merge-only+P-A** = W-A1 + P-B + P-A + C-A2 + C-C. W-A remains the union.

## Freeze record

Rules file `Evaluation/Intelligence/Experimental/AutonomousEditInvariants.swift`
SHA-256 at freeze: `0bba9d9930fcd792e2043c42469b3d40821fda5764d1237cbd5ba68c642a26f7`. Development corpus SHA-256 at freeze:
`7854a3f02dea82d5cc0050707e6a82876099f0fcf218d5f1dec162965feaa3a2`. The validation corpus was authored after this record and scored once
without tuning.

### Freeze addendum: identifier rename (no behavior change)

After validation, SwiftLint's inclusive-language rule flagged the identifiers
`wsWhitelist`/`punctWhitelist` and the bundle name "whitelist". They were renamed to
`wsAllowlist`/`punctAllowlist`/"allowlist" (and the README wording likewise). This
is a **pure rename**: all 162 recorded numbers were re-extracted and are identical
before and after (only the bundle's key name changed). The rules-file SHA-256 was
re-pinned to `b20b001153fbecffaede9eec736c50d462a759990469350c9bd42b004416aafe` (the freeze-time hash above is the pre-rename file).


## V1.15 fresh validation (frozen)

`fresh.json` (128 entries) was authored independently for V1.15, checked
mechanically to share no text with `development.json`, `validation.json`, or the
V1.12/V1.13 corpora, and scored once against the **unmodified** rules file above
(SHA-256 `b20b001153fbecffaede9eec736c50d462a759990469350c9bd42b004416aafe`,
identical to the V1.14 freeze). `fresh.json` SHA-256 at freeze:
`f8ed62da0c3426c9d6f27f4fd91385dd162782f54e493fcf4cacee661a3496d6`. See `V1_15_FRESH_AUTONOMOUS_POLICY_VALIDATION.md` for results,
including two newly-discovered hazard sub-shapes and one disclosed (uncorrected)
corpus artifact with zero effect on any measurement.
