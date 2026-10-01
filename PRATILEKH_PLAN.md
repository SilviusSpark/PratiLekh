# PratiLekh Plan

PratiLekh is a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice) being adapted
into a dictation tool for Indian courts.

This document is the living roadmap. Update it as phases complete or scope changes — it's
the source of truth for "what's done" and "what's next" across sessions.

## Product principle

**PratiLekh records the judge's dictation, not the courtroom.** The judge determines what
forms part of the judicial record; the application assists in accurately capturing and
formatting that dictation without independently interpreting the proceeding.

PratiLekh is a **judge-centric dictation application**, not a courtroom transcription system.
Concretely, this rules out (not merely "later," but **out of scope**):

- Speaker diarization used to distinguish courtroom participants
- Judge / Witness / Counsel identification or role assignment
- Automatic Q&A generation from a recorded proceeding
- Verbatim courtroom transcription of a multi-party proceeding

"Evidence/deposition support" means accurately recording **what the judge dictates for the
record** (including where the judge dictates a witness's answer, a question put, or a
procedural note) — not independently capturing or structuring a multi-party exchange. The
codebase already contains `SpeakerDiarizationService.swift` and
`MeetingTranscriptionService.swift` (inherited from FluidVoice's meeting-transcription
feature) — these are **not building blocks for PratiLekh's roadmap**. No phase below builds on
them. Whether to remove them entirely is a separate, later decision, not made here.

## Cross-cutting architecture principles

These apply across multiple phases and should not be re-litigated per-phase:

1. **Four distinct stages, not one blended pipeline:**
   - *Recognition assistance* — helping the STT engine recognize names, places, and legal
     terminology (hints/boosting fed to the ASR provider).
   - *Deterministic normalization* — rule-based conversion of recognized text into correct
     legal forms: statutory citations, abbreviations, case numbers, dates, amounts,
     witness/exhibit references. No AI involved; must be pure and testable.
   - *Judicial templates/commands* — deliberate, user-triggered insertion or formatting
     (boilerplate, headers, numbering). Explicit user action, not inferred.
   - *AI cleanup* — optional, later-stage language improvement. Not the primary mechanism for
     correcting legal facts, and not invoked until the deterministic stages exist.
2. **Provenance is preserved end-to-end.** Recognizer output, deterministic-normalized text,
   optional AI-proposed text, and final output must remain distinguishable at each stage, so a
   future accuracy problem can be traced to the stage that introduced it, rather than to
   "the transcript" as an undifferentiated blob.
3. **Vocabulary is provider-agnostic.** No architectural coupling to Parakeet (or any single
   STT engine) for how legal vocabulary is expressed. A vocabulary pack's canonical entries are
   translated into whatever a given provider needs via a provider-specific adapter.
4. **Vocabulary is modular, not a single dictionary.** Packs are versioned, independently
   loadable/updatable, and combine under explicit precedence rules (built-in < jurisdictional <
   user, or similar — defined in Phase 1, not assumed here).
5. **Minimize churn in large upstream files.** `ASRService`, `ContentView`, and `SettingsStore`
   are large, FluidVoice-inherited files. New functionality should plug in through narrow,
   well-defined extension points rather than accreting logic directly into them.
6. **Court Privacy Mode is a policy, not a preset.** It will eventually govern STT/AI provider
   eligibility, networking, analytics, feedback/diagnostics that could contain transcript text,
   history/audio retention, and local API exposure — as an enforceable policy other subsystems
   consult, not a checkbox that toggles a few UI options. Not implemented until Phase 6, and
   only stubbed earlier if an earlier phase's interface genuinely needs the hook.

## Decisions on record

- **Product scope**: judge-centric dictation only (see Product principle above) — this
  supersedes an earlier draft of this plan that included speaker-role and courtroom-transcript
  phases.
- **Language scope**: Indian English only for now, via the existing Whisper provider. Hindi /
  regional-language support remains deferred, not ruled out.
- **AI post-processing**: cloud LLM providers stay available but off by default; on-device
  processing is the default path. AI legal cleanup (Phase 7) will be conservative and
  meaning-preserving — legal identifiers (names, statutory provisions, case numbers, dates,
  amounts) must not depend primarily on generative correction; they're the deterministic
  engine's responsibility (Phase 3).
- **Analytics**: disabled entirely (PostHog key cleared in `Info.plist`). Do not re-enable or
  point telemetry at a third party without an explicit ask.
- **Vocabulary content comes after architecture.** Phase 1 builds the pack format,
  precedence rules, and recognition/normalization boundary; Phase 2 is the first phase that
  populates real legal content.

## Phase 0 — Fork Identity & Rebranding — ✅ Complete

Bundle ID, product name, entitlements, scheme, storage-folder migration, analytics disabled,
README rewritten, build verified (`./build.sh unsigned` succeeds). Signing: no signing identity
is installed on this machine; the decision (2026-09-22) was to build unsigned for now rather
than set up a Team ID — `DEVELOPMENT_TEAM` deliberately left at the original vendor's value.

Committed as `7b782dade34d4ec810a8c01a714bbbbb3908e508` on `main`.

## Phase 1 — Legal Language Architecture — ✅ Complete

**Purpose:** build the foundation before any legal content exists, so Phase 2 onward is
populating data into a designed system rather than growing an ad hoc one.

**Delivered** (`Sources/Fluid/LegalLanguage/`, 12 files — `Packs/`, `Resolution/`,
`Recognition/`, `Normalization/`, plus the `LegalLanguageCoordinator` facade):
- A versioned vocabulary/resource **pack** format (`LanguagePack`: id, semantic version, kind,
  recognition entries, normalization entries), with a `PackLoader` that validates schema/version
  and a `PackRepository` in-memory holder.
- **Precedence and override rules** (`PrecedenceResolver`): `user > jurisdiction > builtin`,
  rank derived from `pack.kind` (order-independent), override never mutates a lower-precedence
  pack's stored entries. Same-rank/same-value contributions deduplicate to a clean resolution;
  same-rank/different-value contributions produce a structured `PackConflict`, never a silent
  pick. Recognition entries resolve differently from normalization entries: recognition is a
  pure alias union (no conflict concept — two packs' hints for the same term are never
  ambiguous), while normalization is a value-producing mapping where disagreement is genuine
  ambiguity.
- **Provider-specific vocabulary adapters** (`ProviderCapabilityResolver`,
  `RecognitionVocabularyAdapter`): a name-keyed, PratiLekh-side capability lookup — deliberately
  *not* a change to `TranscriptionProvider` or any provider file. Every key was verified against
  the real `name` property in each provider's source (not guessed). Only `FluidAudioProvider`'s
  real (Apple Silicon) implementation has a confirmed recognition-hint mechanism today
  (`ParakeetVocabularyStore` + `AsrManager.configureVocabularyBoosting`, cap 256 terms); every
  other current provider name safely resolves to `.none` rather than an assumed capability.
- A **pure, testable legal-normalization boundary** (`LegalNormalizer` protocol +
  `LookupTableNormalizer`, Phase 1's one conformance): evaluates each resolved-table entry
  independently against the input text. A cleanly resolved match is applied; a conflicted match
  is left unchanged in the output and recorded as declined. One `NormalizationOutcome` may
  legitimately contain both applied and declined changes — an unrelated conflict never blocks
  an otherwise-safe transformation elsewhere in the same text. "No matching trigger" is always
  `unchanged`, never `declined`; `declined` is reserved for genuine, resolver-detected ambiguity.
- **Provenance**, scoped to what Phase 1 needs: `NormalizationOutcome` carries `recognized`
  (untouched input), `normalized`, `appliedChanges`, `declinedChanges`. No speculative
  `.aiProposed`/`.final` stage wrapper — extend when those stages actually exist (Phase 7+).
- **Zero changes to any existing FluidVoice production source file** — confirmed via `git diff`
  showing only new files plus a narrowly-scoped `.gitignore` exception (to track the new test
  runner without registering it in the hosted XCTest target). `ASRService`, `ContentView`,
  `SettingsStore`, `TranscriptionProvider`, `ParakeetVocabularyStore`, and every provider file
  are untouched. No live wiring into the transcription pipeline — the complete flow (fixture
  pack → loading → precedence resolution → recognition adaptation → normalization →
  `NormalizationOutcome`) is proven by coordinator-level tests using fixture packs only.
- **Tests**: 5 standalone `xcrun swiftc`-compiled assertion suites under `Tests/`, run via
  `scripts/test_legal_language.sh` — following this repo's existing pure-logic test convention
  (same pattern as `scripts/test_provider_model_verification.sh`) rather than the Xcode-hosted
  `FluidDictationIntegrationTests` target, since that target requires per-file
  `project.pbxproj` registration (no synchronized group, unlike `Sources/Fluid`) and no such
  edit was made.

**Deferred, as designed:** any real pack content (Phase 2), overlapping/tokenized trigger
matching (documented limitation, revisit in Phase 3 if real content needs it), live recognition-
hint wiring into any provider, Court Privacy Mode hooks, AI cleanup.

## Phase 2 — Indian Legal Core — ✅ Complete

**Purpose:** populate the first real vocabulary pack using Phase 1's architecture, scoped to
actual trial-court/Magistrate dictation rather than a general legal glossary.

**Delivered:**
- `Sources/Fluid/Resources/indian_legal_core.default.json` — the built-in Indian Legal Core
  pack (`id: indian-legal-core`, `kind: builtin`, `version: 1.0.0`), **77 recognition entries,
  0 normalization entries**, across six categories: BNS/BNSS/BSA (current codes), IPC/CrPC/
  Indian Evidence Act (legacy codes, coexisting without any conversion mapping), CPC/civil
  procedure, cross-cutting judicial/procedural terminology (the largest category — bail/
  remand/custody, cognizance/charge/plea, evidence recording, sentencing — curated from live
  research against India Code, MHA/BPRD official texts, and Supreme Court judgment usage
  rather than model memory), institutional/role abbreviations, and a deliberately trimmed set
  of trial-relevant Latin expressions (appellate/precedent-only Latin — ratio decidendi, obiter
  dicta, stare decisis, de novo, review/curative petition, cross-objection, first appeal — was
  researched and then excluded as out of scope for trial-court dictation, not merely deferred
  for lack of evidence).
- `Sources/Fluid/LegalLanguage/Packs/BuiltInPacks.swift` — the minimum production integration
  seam (`BuiltInPacks.indianLegalCore(bundle:)`, loads the bundled JSON via `PackLoader`).
  Nothing calls it yet — the pack is proven via coordinator-level tests only. No live wiring
  into `ASRService` or any provider was made or attempted.
- **Zero normalization entries by design**: every candidate normalization proposed during
  curation (statute-abbreviation casing, "Hon'ble" expansion, charge-sheet spelling variants)
  was explicitly stripped per review decisions; recognition aliases carry written variants
  (e.g. `BNS`, `chargesheet`/`charge sheet`, `panchanama`) instead.
- **No speculative phonetic aliases** — aliases are real written forms/abbreviations only
  (verified against source), not guessed ASR-hint spellings. Empirical alias tuning against
  FluidAudio's actual vocabulary-boosting mechanism is deferred, not attempted from memory.
- **Zero changes to any existing FluidVoice production file** — only `scripts/test_legal_language.sh`
  (our own Phase 1 file) was modified, to add the new pack's test to the suite.

**Curation note**: "Panchnama" (not "Panchanama") was chosen as canonical — both spellings are
used in Supreme Court judgments with no formal standardization, but "panchnama" is the more
common form across recent SC usage and secondary legal sources; "panchanama" is retained as a
recognition alias, not normalized between the two.

**Curation methodology and provenance** (lightweight record, not a runtime data field —
no per-entry source metadata was added to the Phase 1 schema):
- **Statutory terminology** (statute names, short titles, official abbreviations) was sourced
  from primary official material: India Code (indiacode.nic.in) bare-act text and Ministry of
  Home Affairs / BPRD gazette-adjacent publications — for BNS, BNSS, BSA, IPC, CrPC, the Indian
  Evidence Act, and CPC.
- **Practical judicial/procedural terminology** (bail/remand/custody vocabulary, charge and
  plea terminology, evidence-recording terms, sentencing terminology, institutional
  abbreviations, common expressions) was sourced from judicial usage evidence — Supreme Court
  judgment text, official/government-adjacent handbooks, and established legal-practice
  sources — since these terms aren't statutorily "named" the way an Act's short title is.
- These two source tiers were kept distinct throughout curation: a statute's official name is
  authoritative by definition; a procedural term's inclusion depended on demonstrated usage,
  not just plausibility.
- The pack is deliberately scoped to **trial-court/Magistrate dictation** (bail, remand,
  cognizance, charge, evidence recording, sentencing, common civil orders), not a general
  legal glossary — appellate/precedent-discussion Latin (ratio decidendi, obiter dicta, stare
  decisis, de novo, review/curative petition, cross-objection, first appeal) was researched and
  deliberately excluded as out of scope for that focus, not left out for lack of evidence.
- **No speculative phonetic aliases** were encoded (e.g. no "bee en es"-style spelled-out
  guesses) — aliases are real written forms/abbreviations only. Empirical ASR-hint tuning
  against FluidAudio's actual vocabulary-boosting mechanism is a separate, deferred task.
- **Current and legacy statutes intentionally coexist with zero conversion mappings** between
  them (no IPC↔BNS, CrPC↔BNSS, or Evidence Act↔BSA correspondence) — both eras are independently
  valid vocabulary, and section-correspondence tables are explicitly out of scope, not just
  unimplemented.

## Phase 3 — Legal Normalization Engine — 🚧 In progress (3C/3C.1, 3D, 3F.A, 3F.B, 3G.A committed; broader Phase 3 open)

**Purpose:** build out deterministic normalization beyond statutory citations, using the
boundary defined in Phase 1.

**Core principle:** format what was dictated; never complete what was not dictated. Ambiguous
or unsupported legally significant structures are preserved as dictated, never guessed.

**Phase 3A — engine principles (established):** deterministic rule composition; partial
success (one rule's decline never blocks another's safe application); a three-way outcome
distinction (no candidate / applied / explicitly declined); span provenance for every applied
or declined transformation; idempotence/stability where practical; no silent cross-rule
overlap resolution; strict separation from future AI cleanup (Phase 7 owns protection of
legal identifiers from generative alteration).

**Phase 3B — rule-family method (established):** each family is a bounded design, reviewed
against a human-readable golden corpus (positives, idempotence, declines, near-misses,
dangerous negatives, mixed outcomes) *before* implementation.

**Phase 3C / 3C.1 — first implemented slice, not completion of Phase 3.** Two families:
1. *Statutory provision references* — `section N`, `section N <statute>`, and enumerated
   `sections N, N and N <statute>`; unsupported shapes (read with, sub-sections, ranges,
   ambiguous cross-statute compounds, statute-less lists) decline and are preserved.
2. *Prosecution/defence witness references* — `PW-n` / `DW-n`; attached self-correction
   declines.

Design decisions on record:
- Current and legacy statutes (BNS/BNSS/BSA vs. IPC/CrPC/Evidence Act) are never automatically
  converted.
- **Parsing is separate from rendering.** The normalizer produces a structured
  `StatutoryProvisionReference` (ordered provisions, optional statute, source span). The
  current neutral renderer emits expanded notation, e.g. `Sections 294, 323, 341 and 506 IPC`.
  A future Phase 4 Judicial Dictation Profile/setting may render the same parsed structure as
  `u/s 294/323/341/506 of IPC`. Such a preference changes presentation only — never detected
  provisions, dictated order, statute identification, ambiguity decisions, provenance, or legal
  meaning.
- Provenance: applied/declined changes carry an optional `range` into the input text of the
  pass that produced them; nil only where no meaningful span exists (Phase 1 table lookups) or
  none can be determined reliably.
- **Isolation (3C):** the rule code itself is UI/ASR-free and tested standalone; live
  activation is Phase 3D below.

**Phase 3D — live activation of the existing deterministic normalization (Slices A+B).**
`LegalDictationProcessor` (`LegalLanguage/`) owns the bundled Indian Legal Core and the
coordinator. `ContentView` calls it on finalized dictation after all deterministic ASR/spoken-
punctuation/spoken-send handling and *before* optional AI, in both AI-bearing pipelines (live
stop and "reprocess"). The full result (with provenance) is kept in scope for a future Phase 7
validator. Always on, no Settings UI. Not touched: streaming preview, `ASRService`, providers,
recognition boosting, custom dictionary (runs before legal normalization, unchanged), history
schema. Leading-capitalization protection: if an *applied* legal change owned the first token
(provenance span at the start of the pass input), GAAV lowercase-first-letter and context-aware
capitalization do not lowercase it (`NormalizationOutcome.protectsLeadingCapitalization`, passed
as a defaulted parameter to those two formatters, in both AI-bearing pipelines). Text that
merely looks canonical is not protected; this is not a general protected-span system (Phase 7).
Known gap: history "undo AI" restores pre-legal raw text. Recognition-hint delivery to the one
capable provider (Slice C), custom-dictionary reconciliation (D) and AI protected-span
validation (E) remain deferred.

**Phase 3F — Statutory Number Safety.** Driven directly by real-audio evidence (Phase 3E.2A's
D02/D03, confirmed and extended by 3E.2B's N-series) that `SpokenNumberParser`'s naive digit/tens
string concatenation silently corrupts mixed-form provision numbers (`three twenty three` →
`3203`, not `323`), and that `"hundred"` silently partially-applies (`three hundred twenty three`
→ `Section 3 ...`).

- **3F.A (✅ committed, `18313d7`) — fail-closed safety, no grammar expansion:** an unsupported
  numeric continuation (`"hundred"`, optionally `"hundred and ..."`) now declines the whole
  candidate instead of partially applying; `hundred` itself remains unimplemented. A fragmented
  statute abbreviation recognized as broken-apart letters (e.g. `B and S S` for `BNSS`) no longer
  donates its first letter to the provision as a spurious suffix (`144B`) — a narrow,
  detection-only guard (`StatuteRecognizer.looksLikeFragmentedAlias`, ≥3 known letters, at most
  one literal `"and"` as a positional wildcard, never rewritten/asserted to mean any letter)
  declines instead. Legitimate suffixes (`376A`, `498A`, `120B`) remain fully supported.
  Acknowledged, evidence-scoped gap: `B S S` with no `"and"` gap is not yet handled — no real-audio
  evidence of that exact shape exists.
- **3F.B (✅ committed, `89a2846`) — the bounded grouped-number
  grammar:** `[leading digit] + tens-word + [trailing digit]`, combined arithmetically, supporting
  the demonstrated natural forms (`thirty four`→`34`, `one forty four`→`144`, `three twenty
  three`→`323`, `three seventy six`→`376`, `one twenty five`→`125`) while preserving all
  pure digit-by-digit forms and the pre-existing `one twenty`→`120`/`one twenty B`→`120B` idiom.
  `hundred` remains unsupported, protected by 3F.A. Because the grammar is bounded (never
  greedily re-enters), the unsupported-continuation guard was generalized to also decline when a
  digit/tens word is left immediately adjacent to an already-complete grouped result. Shared with
  `WitnessReferenceNormalizer` (same parser) — confirmed semantically appropriate and covered by
  a regression test. **Deterministic offline probe** (real code, no audio) against the committed
  N01–N12 corpus: 11/12 correct, N10 (`five hundred six`) correctly declines — this was a
  text-level result at the time; now superseded by the real-audio validation below.

**Real-audio validation of Phase 3F (both 3F.A and 3F.B), reusing the existing N01–N12
recordings unchanged, compared directly against the original pre-3F baseline.** Same audio,
same provider (Parakeet TDT v2, English Only) in both runs — baseline at commit `cefc209`
(`/Users/kumarspandan/pratilekh-eval-results/2026-09-27T090531Z/`), post-3F at `HEAD` `785921c`
(`/Users/kumarspandan/pratilekh-eval-results-post-3fb/2026-09-27T104836Z/`); both private,
local diagnostic-result locations, not repository artifacts. `postASRDeterministic` WER/CER was
identical between the two runs (12.9% / 3.5%), so the same recordings produced the same
observable upstream text both times — any change in `legalNormalized` is attributable to the
Phase 3F code change, not a different sample.

- **3F.B result:** all five grouped-number corruptions present in the baseline were corrected
  on the same audio — N01 `304→34`, N03 `1404→144`, N05 `3203→323`, N07 `3706→376`, N11
  `1205→125`. Stated carefully: Phase 3F.B corrected 5/5 previously-corrupted grouped-number
  cases in this fixed N-series real-audio sample — not a claim that generalizes beyond this
  corpus. N03 and N11 reached fully correct end-to-end statutory citations; N01/N05/N07 obtained
  the correct number but remained incomplete because the statute word (`IPC`) had already been
  lost/misrecognized (as `it c`) before legal normalization ever saw it.
- **3F.A result:** N10 (`five hundred six`) went from a partial corruption (`Section 5 hundred
  six...`) to an unchanged, safe decline. N04/N12 (`BNSS` recognized as fragmented letters `B
  and S S`) went from false-positive suffix-like transformations (`Section 144B`/`Section
  125B`) to safe declines.
- **Critical-token result:** corrupted critical tokens 7 (baseline) → 0 (post-3F); incorrect
  transformations 3 → 0; regressions found: 0.
- **On the normalized WER/CER appearing worse** (baseline 13.6%/4.6%, post-3F 14.0%/6.3%): not
  a regression. A safe decline retains longer original spoken text, which can score worse by
  edit distance than a shorter-but-legally-corrupted transformation would have. The metrics that
  track legal safety (corrupted tokens, incorrect transformations) moved in the intended
  direction. Another concrete case against reading WER alone as a legal-dictation quality signal.
- **Remaining unresolved, evidence only, no solution selected:** (1) `IPC` observed as `it c` in
  several N-series takes; (2) `BNSS` sometimes observed as fragmented letters (`B and S S`); (3)
  `five hundred six` remains deliberately unsupported but now fails safely; (4) date/year
  phrasing reliability remains unresolved (see below); (5) internal sentence-boundary
  punctuation remains unresolved (see below). At the time of this run, (1) and (2) were upstream
  of the legal-normalization boundary this evaluation could observe, with no finer attribution
  possible — Phase 3G.A below narrows this further.

**Phase 3F status:** 3F.A — implemented, committed, and real-audio validated. 3F.B —
implemented, committed, and real-audio validated against the fixed N01–N12 corpus. Phase 3F
eliminated the known deterministic statutory-number corruptions targeted by the phase and
converted the tested unsupported/ambiguous forms to fail-closed behavior. Remaining failures in
the fixed real-audio sample are either upstream of legal normalization or deliberately
unsupported. Phase 3F does not universally solve statutory dictation — it does not touch
statute-word recognition, `hundred`, dates, or punctuation.

**Phase 3G.A — Provider-transcript observability (✅ committed, `08a2f24`, real-audio
validated).** Adds one new observable value, `providerTranscript`: the text returned across the
`TranscriptionProvider` boundary (`transcribeFinal`/`transcribeFile`), captured before PratiLekh's
own filler removal, custom-dictionary substitution and spoken-punctuation formatting. Exposed only
at the Local API/evaluation seam (`ASRService`'s `...ForAPI` functions, `InferenceAPIController`,
`EvalRunner`; reported as its own field on `SampleRunRecord`, not inserted into the scored `stages`
list, so it does not change what `postASRDeterministic` is scored against — see
`Evaluation/README.md`). **Not necessarily raw acoustic/token decoder output** — a
`TranscriptionProvider` implementation may already perform its own internal processing before
returning this string, and that remains opaque to PratiLekh. No production transcription or
normalization behavior changed.

*Real-audio validation, reusing the same N01–N12 recordings and provider (Parakeet TDT v2, English
Only), against commit `08a2f24`:*
- **Attribution result for the six previously known statute-degradation cases** (N01, N04, N05,
  N06, N07, N12): **6/6 already present in `providerTranscript`**, i.e. at the provider-return
  boundary, upstream of PratiLekh's filler-removal/custom-dictionary/spoken-punctuation
  preprocessing. **0/6 introduced between `providerTranscript` and `postASRDeterministic`; 0/6
  first introduced by legal normalization.** This is *not* an acoustic-decoding finding — it
  attributes where relative to PratiLekh's own code the degradation exists, not why the provider
  produced it; provider-internal processing before the returned string is not observable.
  Correctly recognized cases (unaffected): N02, N03, N08, N09, N11. N10 remains an intentional
  grammar-scope safe-decline, not a recognition failure — its text is accurate.
- **Regression check, full 28-sample N/P/Y corpus against the prior post-3F baseline:**
  `postASRDeterministic` and `legalNormalized` were byte-for-byte identical to the prior post-3F
  run for every sample (0 differences). The five Phase 3F.B grouped-number corrections remain
  correct, N10 still fails closed, N04/N12 still safely decline, no new incorrect
  legal-normalization transformation appeared. Phase 3G.A introduced no measured
  production-pipeline behavioral change.
- **Instrumentation limitation:** all 28 real-audio samples happened to have `providerTranscript
  == postASRDeterministic`, because none of these specific recordings exercised filler removal,
  custom-dictionary substitution, or a literal spoken-punctuation word. The committed synthetic
  evaluation tests (`scripts/test_evaluation.sh`) separately demonstrate the instrumentation can
  represent a genuine divergence when one exists. This real-audio run does not comprehensively
  validate every preprocessing transformation.

**What this rules out, and what it does not decide:** this evidence rules out PratiLekh's own
currently-observed deterministic preprocessing interval as the source of the six statute
degradations. It does **not** yet select the next intervention. Remaining, unranked candidate
directions: recognition-side improvements if the existing local ASR stack supports them; a
constrained text-based PratiLekh Intelligence layer; or, eventually, audio-aware intelligence if
later evidence justifies it. A **read-only investigation** of whether the current
Parakeet/FluidAudio stack exposes safe contextual vocabulary biasing, hotwords, boosting,
prompting, decoding controls, or an equivalent mechanism suitable for legal/statutory terminology
followed directly — see "Phase 3G.B" immediately below for what it found and what was
subsequently tested.

**Phase 3G.B — Legal-vocabulary recognition-boosting experiment (bounded A/B experiment; no
source, test, or configuration file was committed for it).** The read-only investigation found
that the exact installed FluidAudio revision already contains a CTC-based vocabulary-rescoring
mechanism, already wired by `FluidAudioProvider` into the same manager used for final Parakeet
TDT v2 transcription, inactive only because `SettingsStore.vocabularyBoostingEnabled` defaults to
`false`. Phase 3G.B tested it directly: boosting was enabled via the existing (non-source) runtime
configuration surface — the user-level `parakeet_custom_vocabulary.json` file and the
`VocabularyBoostingEnabled` user default, both outside the Git repository — with a
canonical-terms-only vocabulary (`IPC`, `BNSS`, `BNS`, `CrPC`, `CPC`; no aliases, no observed-error
forms), and the pre-existing threshold configuration left completely unchanged (`alpha: 2.8`,
`minCtcScore: -2.2`, `minSimilarity: 0.72`, `minCombinedConfidence: 0.64`, `minTermLength: 3`).
Enabling boosting caused the already-shipped CTC model (`parakeet-ctc-110m`) to be
downloaded/loaded for the first time on this machine — the model the already-integrated feature
needs to run, not a new project dependency or a newly implemented capability. The full 28-sample
N/P/Y corpus was re-run and compared against the Phase 3G.A baseline; experimental
settings/vocabulary were restored to their exact prior state afterward (verified byte-for-byte),
and no tracked source file was changed.

*Result:* across all 28 samples, `providerTranscript`, `postASRDeterministic`, and
`legalNormalized` were all identical to the baseline — 0 differences in any field, for any sample.
For the six known degraded cases (N01, N04, N05, N06, N07, N12): 0/6 fully corrected, 0/6
partially improved, 6/6 unchanged, 0/6 worsened. The five already-correct statute cases (N02,
N03, N08, N09, N11) all remained unchanged: 5/5 preserved. No new legal-term substitution was
observed, no previously correct transcript regressed, no P/Y sample acquired a registered legal
term. **No harmful effect was observed in this fixed corpus** — not generalized to "vocabulary
boosting is safe": a statement about this one run, this one vocabulary, these unchanged
thresholds only.

**Correct interpretation (do not overreach):** this establishes only that, under the existing
untuned thresholds, this five-term canonical-only vocabulary, and this fixed corpus, enabling the
mechanism produced no measurable transcript benefit or harm. It does **not** establish that
vocabulary boosting can never help, that lower thresholds or aliases would help, that the CTC
spotter failed to detect the terms, that it detected but rejected them, or that vocabulary
boosting is production-safe more broadly. No threshold tuning or alias addition is recommended
from this evidence alone.

**Observability limitation:** `ASRResult.ctcDetectedTerms`/`ctcAppliedTerms` exist inside the
installed FluidAudio dependency but are discarded by `FluidAudioProvider` before returning
`ASRTranscriptionResult` (not modified in this experiment). The existing `BOOST_HIT` log line is
**not** evidence of CTC detection or application — it is a plain case-insensitive substring check
against the already-produced transcript text. Phase 3G.B therefore cannot currently distinguish
"candidate not detected," "candidate detected but not applied," "candidate applied," or any other
internal rescoring behavior for the six target cases. A reliable A/B latency comparison was also
not available from existing surfaces and was not obtained.

A **read-only Phase 3G.C architecture investigation** followed directly, into the smallest safe
diagnostic seam for exposing already-computed CTC rescoring metadata during evaluation — see
"Phase 3G.C" immediately below for what it found and the resulting decision.

**Phase 3G.C — CTC rescoring observability investigation (read-only; no code, config, or
dependency change).** Traced the exact installed FluidAudio source (not upstream documentation)
for `ASRResult.ctcDetectedTerms`/`ctcAppliedTerms` and the full CTC rescoring decision path.

*`ctcDetectedTerms`/`ctcAppliedTerms` are not useful as-is:* both are `[String]?`, populated only
from `RescoreOutput.replacements`, and every `RescoringResult` that ever enters that array is
constructed with `shouldReplace == true` (the one code path that appends to it hardcodes this).
The two fields are therefore effectively equivalent in the installed revision, and both are
non-empty only when a replacement was already accepted and substituted into the transcript. A
rejected candidate leaves no trace in either field — they cannot distinguish "not detected" from
"detected but rejected," and carrying them through PratiLekh would add no diagnostic information
beyond the boosted-vs-baseline `providerTranscript` comparison Phase 3G.A/B already perform.
**Decision: the contemplated structural `ctcDetectedTerms`/`ctcAppliedTerms` diagnostic seam will
not be implemented** — it would not answer the question it was proposed to answer.

*The actual decision path (ordering matters):* candidate vocabulary term → transcript/string-
similarity gating first → only if that gate passes, CTC acoustic scoring over the relevant audio
window → boosted vocabulary CTC score compared against the original-phrase CTC score → accept/
reject → accepted, non-overlapping replacements applied → only applied replacements reach the
returned CTC metadata. The mechanism is not unconditional audio-based reconsideration of every
word; it first requires the existing decoded text to already be textually similar enough to a
registered vocabulary term.

*Rejected-candidate evidence exists but is discarded:* once a candidate clears the similarity gate
and reaches CTC evaluation, FluidAudio computes the candidate term, original phrase, similarity,
both raw CTC scores, the boosted score, the audio span, and a decision reason — discarded
immediately for rejected candidates rather than retained on `ASRResult`. Exposing it structurally
would require modifying FluidAudio itself, not just PratiLekh's wrapper.

*Existing debug logging:* Debug builds already emit this candidate-level CTC comparison
information through Apple's unified logging when a candidate reaches CTC evaluation. A live
debug-level log capture during a future run could observe this without source modification — but
this was not captured during Phase 3G.B, cannot retroactively explain that run, and no further
recognition experiment is currently authorized (not recorded as a planned next step).

*Source-informed inference on `IPC`/`BNSS` (inference, not runtime proof that a specific gate
fired during Phase 3G.B):* for `IPC → it c`, the individual observed fragments have low string
similarity to `IPC`; the plausible concatenated form `itc` is closer but still below the
configured `minSimilarity`; and the installed compound-matching path requires the vocabulary term
to be at least 4 characters, so three-character targets (`IPC`, `BNS`, `CPC`) never use that
multi-word compound path at all. For `BNSS → B and S S`, the four-character term can enter
compound matching, but plausible fragment combinations from the observed text still land below
the configured similarity threshold.

*Threshold-field trace limitation (narrow, do not generalize):* `minCtcScore` and
`minCombinedConfidence` exist in the loaded vocabulary configuration, but Phase 3G.C did not
establish that they participate in the active term-centric `evaluateCTCMatch` acceptance
comparison, which directly compares the boosted vocabulary CTC score against the original-phrase
CTC score. This is a trace gap for this specific code path, not a claim those fields are unused
everywhere in FluidAudio.

**Architectural decision: the current recognition-tuning branch is closed after Phase 3G.C.** No
current authorization for threshold tuning, aliases, another vocabulary-boosting experiment,
modifying the three-character compound-length rule, modifying FluidAudio, exposing
rejected-candidate score structures, a production vocabulary-boosting default, or a Phase 3G.D
recognition experiment. This is an evidence/scope decision, not proof that recognition-side
improvement is impossible — the evidence establishes only that continuing this path would now move
beyond cheaply evaluating an existing, already-integrated mechanism and toward
developing/modifying a specialized legal-ASR rescoring subsystem, a materially larger undertaking
than the phase's original scope.

**Next planned activity — performed (investigation/design only, zero implementation).** The
read-only architecture investigation/design of a constrained, local PratiLekh Intelligence layer
was carried out across three follow-on milestones: a read-only Intelligence-layer safety/output-
contract investigation; a read-only investigation into whether FluidVoice's own local "Fluid
Intelligence" runtime is a viable PratiLekh dependency (it is not — an ownership/maintainability
decision, not a criticism of FluidVoice); and a Version 1 text-only proposal/validator contract
design (`Text-Only Intelligence Baseline / Safety Contract V1`) plus a further audio-aware
architecture research investigation. **Full record lives in [`CLAUDE.md`](CLAUDE.md)'s "PratiLekh
Intelligence architecture" section** — summarized here: the recommended long-term architecture is
hybrid and staged (Parakeet first-pass ASR → deterministic normalization → an Intelligence
Proposal Engine → a Deterministic Safety Authority), governed by the invariant **"the model is
replaceable, the safety contract is not"** and a three-way task split (recognition repair /
dictation interpretation / surface polishing), each with different evidence requirements and risk
profiles. The Text-Only Intelligence Baseline (span-based proposals, exact source-text matching,
independently re-derived edit categories, three-way protected-span semantics — resolved /
unresolved / independently-protected, never treated as equivalent — and a zero-unsafe-accepted-
edits raw-count target) was implemented and committed (`Sources/Fluid/Intelligence/Safety/`,
`Transport/`, `Generation/` — V1.0/V1.1/V1.2, zero LLM/model/network integration); it is planned
as Intelligence V1 in a four-generation, non-committal roadmap (V1 safety architecture, V2
recognition evidence, V3 audio-aware, V4 domain adaptation — see `CLAUDE.md` for the full
breakdown). Since then, a local-model evaluation track (V1.3, `granite4:3b` found to be the first
tested viable **protocol** candidate — not a selected production model) and a model-facing
addressing-contract investigation (V1.4/V1.4B/V1.4C) were carried out entirely under
`Evaluation/Intelligence/Experimental/`, with zero production code changes, and V1.5 froze that
contract into a normative, model-independent design record:
[`Evaluation/Intelligence/V1_5_ADDRESSING_CONTRACT_FREEZE.md`](Evaluation/Intelligence/V1_5_ADDRESSING_CONTRACT_FREEZE.md).
**The addressing contract is designed and frozen. V1.6 has since implemented its deterministic
addressing layer in production (`Sources/Fluid/Intelligence/Addressing/`, see
[`Evaluation/Intelligence/V1_6_PRODUCTION_ADDRESSING_RESOLVER.md`](Evaluation/Intelligence/V1_6_PRODUCTION_ADDRESSING_RESOLVER.md),
which also records three clarifications to the freeze); V1.7 then added the model-facing wire
contract, strict parser and response adapter
([`Evaluation/Intelligence/V1_7_MODEL_FACING_WIRE_CONTRACT.md`](Evaluation/Intelligence/V1_7_MODEL_FACING_WIRE_CONTRACT.md),
which supersedes the V1.5 §16 pipeline diagram), and V1.8 composed the chain into one deterministic entry
point that returns structured outcomes and applies nothing
([`Evaluation/Intelligence/V1_8_COMPOSITION_BOUNDARY.md`](Evaluation/Intelligence/V1_8_COMPOSITION_BOUNDARY.md)).
V1.9 then investigated protected-span derivation from normalization provenance, proved the coordinate model, and found a provenance gap that blocks a lossless derivation ([`Evaluation/Intelligence/V1_9_PROTECTED_SPAN_COORDINATE_FINDINGS.md`](Evaluation/Intelligence/V1_9_PROTECTED_SPAN_COORDINATE_FINDINGS.md)); nothing was derived; V1.10 then closed that gap by making normalization provenance typed, locatable and replay-reconstructable ([`Evaluation/Intelligence/V1_10_NORMALIZATION_PROVENANCE_FOUNDATION.md`](Evaluation/Intelligence/V1_10_NORMALIZATION_PROVENANCE_FOUNDATION.md)). V1.11 then derived protected spans from that provenance ([`Evaluation/Intelligence/V1_11_PROTECTED_SPAN_DERIVATION.md`](Evaluation/Intelligence/V1_11_PROTECTED_SPAN_DERIVATION.md)). V1.12 then investigated independent protection (dates, amounts, case numbers, exhibits, names) and recommended a narrow numeric-token gate over category recognizers ([`Evaluation/Intelligence/V1_12_INDEPENDENT_PROTECTION_FINDINGS.md`](Evaluation/Intelligence/V1_12_INDEPENDENT_PROTECTION_FINDINGS.md)); nothing was built. V1.13 then implemented that numeric-token mechanism as category-agnostic numeric structural protection, validated on a corpus frozen before implementation ([`Evaluation/Intelligence/V1_13_NUMERIC_STRUCTURAL_PROTECTION.md`](Evaluation/Intelligence/V1_13_NUMERIC_STRUCTURAL_PROTECTION.md)). V1.14 then investigated whether the classifier's autonomous categories need a structural invariant and recommended (not yet implemented) tightening generic policy over new recognizers for most of the remaining gap ([`Evaluation/Intelligence/V1_14_AUTONOMOUS_EDIT_POLICY_FINDINGS.md`](Evaluation/Intelligence/V1_14_AUTONOMOUS_EDIT_POLICY_FINDINGS.md)). V1.15 then re-validated that recommendation, unmodified, against a genuinely fresh frozen corpus, confirmed it, and identified where such an invariant should live architecturally ([`Evaluation/Intelligence/V1_15_FRESH_AUTONOMOUS_POLICY_VALIDATION.md`](Evaluation/Intelligence/V1_15_FRESH_AUTONOMOUS_POLICY_VALIDATION.md)); nothing was implemented. V1.16 then implemented that recommendation as a separate, narrow deterministic `AutonomousPermissionGate` consumed by `IntelligenceSafetyAuthority` (not folded into the classifier) — exactly the five validated rules, `.reviewOnly` disposition only, boundary-directed scanning with a fail-closed resource bound, and exact reproduction of the already-published V1.14/V1.15 aggregate numbers against all three frozen corpora via a new production-parity replay harness ([`Evaluation/Intelligence/V1_16_AUTONOMOUS_PERMISSION_GATE.md`](Evaluation/Intelligence/V1_16_AUTONOMOUS_PERMISSION_GATE.md)). V1.17 then built a standalone evaluation harness connecting the existing `LLMClient` to the existing, unmodified Intelligence chain and ran a real local model (`granite4:3b` via Ollama) across separate synthetic and private real-dictation evidence tiers; all 10 real responses engaged tool calling but omitted the required `schemaVersion` field and so failed closed at the strict parser, with zero edits reaching autonomous acceptance — a protocol-compliance finding only, establishing neither correction quality nor model safety, with no tuning done in response ([`Evaluation/Intelligence/V1_17_CONTROLLED_LOCAL_MODEL_INTEGRATION_HARNESS.md`](Evaluation/Intelligence/V1_17_CONTROLLED_LOCAL_MODEL_INTEGRATION_HARNESS.md)). V1.18 then investigated (read-only) why `granite4:3b` omitted `schemaVersion`, exonerating PratiLekh's request construction and `LLMClient`'s serialization (byte-for-byte proof plus a raw-`curl` reproduction bypassing `LLMClient`), finding Ollama's template showed no stripping logic and a same-family cross-model control (`granite4:350m`) correctly produced `schemaVersion`, and concluding model protocol adherence for `granite4:3b` under this exact runtime is the best-supported failure boundary (12/12 omissions) — with no prompt/schema/model tuning performed ([`Evaluation/Intelligence/V1_18_MODEL_PROTOCOL_COMPLIANCE_INVESTIGATION.md`](Evaluation/Intelligence/V1_18_MODEL_PROTOCOL_COMPLIANCE_INVESTIGATION.md)). V1.19 then ran a single pre-frozen, hashed, 3-arm/45-call experiment testing whether instructional presentation alone could fix this: the frozen production instructions (Arm A) scored 0/15 compliance (all missing `schemaVersion`, reproducing V1.18 exactly), while adding one explicit requirement sentence (Arm B) and a further minimal example (Arm C) both reached 15/15 — with no measurable benefit from the example over the explicit sentence, and the recorded limitation that all 30 compliant responses happened to propose zero edits, so compliance on a non-empty edit remains untested; Arm B is recorded as the smallest experimentally-supported candidate instruction change, explicitly not production-approved ([`Evaluation/Intelligence/V1_19_PROTOCOL_ADHERENCE_EXPERIMENT.md`](Evaluation/Intelligence/V1_19_PROTOCOL_ADHERENCE_EXPERIMENT.md)). None of it is wired into dictation; insertion, edit application, live wiring of the protected-span derivation, `.independentlyProtected` spans and live model integration do not exist yet.** See `CLAUDE.md`'s "Intelligence V1.3A–V1.19" section
for the summary and open risks (Unicode fidelity, mutually-consistent-but-wrong addressing
evidence, over-broad literal spans, word-split/punctuation-split-token residuals).

**Deferred (each needs its own design/domain review before implementation):** exhibit
references (needs research into Indian exhibit conventions), case numbers, dates, amounts,
broader abbreviation rules, and any live-pipeline integration.

**Remaining deliverables for Phase 3 as a whole:**
- Case number normalization.
- Date and amount normalization per legal-drafting convention.
- Exhibit reference normalization — formatting what the judge dictates, not inferring
  references from a multi-party transcript.
- Abbreviation expansion/contraction rules.
- Approved live-pipeline integration.
- Normalization test suite independent of ASR and UI (in place: `scripts/test_legal_language.sh`).

## Phase 4 — Judicial Dictation Profiles

**Purpose:** layer document-type-aware dictation profiles on top of the existing
`SettingsStore.DictationPromptProfile` system, now informed by normalized text rather than raw
ASR output.

**Principal deliverables:**
- Profile definitions for the judge's own dictation modes (e.g., evidence-recording dictation,
  judgement-drafting dictation, order dictation) — single-speaker framing throughout, per the
  product principle.
- Integration point between the Phase 3 normalization engine's output and profile/prompt
  selection.

## Phase 5 — Judicial Voice Commands & Templates

**Purpose:** deliberate, user-triggered structure — distinct from AI cleanup because it's
deterministic and explicitly invoked, not inferred.

**Principal deliverables:**
- A command grammar for invoking templates by voice (boilerplate insertion, section headers,
  numbering conventions).
- A versioned template-pack format, consistent with the vocabulary-pack approach from Phase 1.

## Phase 6 — Court Privacy Mode

**Purpose:** formalize Court Privacy Mode as an enforceable policy layer, per cross-cutting
principle 6.

**Principal deliverables:**
- A policy interface/service that other subsystems (ASR provider selection, AI provider
  eligibility, analytics, feedback/diagnostics, history/audio retention, local API) consult
  rather than each independently checking a setting.
- Enforcement across the surfaces listed above.
- If an earlier phase's design genuinely needs a hook into this policy sooner, stub the
  interface then — but don't build enforcement early.

## Phase 7 — AI Legal Cleanup

**Purpose:** optional, conservative AI-assisted language cleanup, layered strictly after
deterministic normalization.

**Principal deliverables:**
- An AI cleanup stage that only ever operates on already-normalized text, with provenance
  preserved (so an AI-introduced change is always distinguishable from a deterministic one).
- Guardrails ensuring legal identifiers (names, statutory provisions, case numbers, dates,
  amounts) are protected from generative alteration — passed through unchanged, or flagged for
  the judge's review rather than silently rewritten.
- Judicial meaning preservation as a hard constraint on this stage, not an aspiration.

## Phase 8 — Case Context & Metadata

**Purpose:** extend history with case-level context.

**Principal deliverables:**
- Extend `TranscriptionHistoryEntry` (JSON-blob-per-row schema, low migration cost) with case
  number, court, parties, date.
- Filtering/search in `TranscriptionHistoryView.swift`.

## Phase 9 — Odisha Court Language Pack

**Purpose:** first jurisdiction-specific pack, exercising Phase 1's pack/precedence mechanism
with real jurisdictional content.

**Principal deliverables:**
- Odisha court names, place names, and locally common personal-name patterns as a jurisdiction
  pack layered over the Indian Legal Core per the precedence rules from Phase 1.

## Phase 10 — Dictation Accuracy Evaluation — 🚧 Foundation and first baseline in progress

**Purpose:** assess real-world accuracy of the assembled stack and decide whether further STT
investment is warranted.

**Principal deliverables:**
- An evaluation methodology and findings against representative Indian-legal dictation.
- A go/no-go recommendation on investigating an India-tuned STT model (e.g., an AI4Bharat
  model), as a distinct future effort if warranted — not assumed necessary today.

**Work done so far (session-labeled "Phase 3E.1"/"Phase 3E.2A" while implemented, substantively
this phase's methodology-and-findings deliverable, done ahead of strict phase order the same way
Phase 4 was earlier noted to draw on Phase 3 — see "Note on deviation" below):**

- **Framework (`Evaluation/`, standalone, no app dependency):** JSON reference schema (dictated
  `reference`, optional `intendedFinal`, critical tokens, `legalExpectations`); a runner
  (`scripts/eval_run.sh`) that transcribes fixed private audio via the app's Local API or reads
  post-ASR text, replays it through the real `LegalDictationProcessor`, and writes per-sample
  JSON + a text summary. Metrics stay unblended: WER/CER, exact critical-token
  state/transition (`preserved`/`recovered`/`unrecovered`/`corrupted`), normalization outcomes
  (`correctApplication`/`correctDecline`/`correctNoCandidate`/`missedOpportunity`/`falsePositive`/
  `incorrectTransformation`/`notEvaluable`), and formatting (case/punctuation) — never a single
  blended score. **Governing principle: the reference is what the judge dictated, not what an
  evaluator or model thinks was intended.** Audio (even of synthetic scripts) and all run results
  stay outside Git; only synthetic reference JSON is committed. `postASRDeterministic` is the
  provider's `/v1/transcribe` output after filler removal, custom dictionary and spoken
  punctuation — **not raw ASR**. Since Phase 3G.A (see "Phase 3" above), audio runs also expose
  `providerTranscript` — the provider's own returned text immediately before that preprocessing —
  but this is still not raw acoustic/token decoder output, since a provider may already perform
  its own opaque internal processing before returning it.
- **First controlled diagnostic corpus (`Evaluation/References/diagnostics-3e2a/`, D01–D10)**
  investigating three behaviors reported from real trials: section-number phrasing (digit-by-digit
  vs. mixed vs. hundreds-form), year/date phrasing, and sentence-punctuation repeatability across
  five independent recordings of one passage. Each `legalExpectations` entry records the *desired*
  outcome (e.g. `Section 323 IPC`), not a rewrite of current parser behavior, so a run's
  classification is itself the diagnostic signal. D01 alone is a strict automated regression case;
  D02/D03's current (defective) outputs are recorded as a documented baseline observation in
  `Evaluation/DIAGNOSTICS_3E2A.md`, explicitly *not* frozen as a test requirement, so a future fix
  needs no companion test edit.
- **First real-audio baseline run (private results, not in Git) — findings:**
  - **Section numbers:** for the digit-by-digit phrasing (D01), the ASR/deterministic-formatting
    stage *already* emitted digits (`Section 323 IPC`) before the Phase 3 statutory normalizer ever
    ran — the normalizer's expected trigger text wasn't present, so this sample scored
    `notEvaluable` rather than `correctApplication`. That means D01's correctness in this run is
    **not** attributable to `StatutoryProvisionNormalizer`; which of the app's earlier stages
    performed the digit conversion is not observable from `postASRDeterministic` alone (evidence,
    not settled attribution). For the mixed (D02) and hundreds-form (D03) phrasings, the spoken
    words survived recognition intact (0% WER at that stage) and the corruption is specifically
    the normalizer's — confirming the previously-documented parser-boundary findings (digit/tens
    concatenation producing `3203`; "hundred" outside the supported grammar producing a
    partial `Section 3`) using real audio rather than synthetic text.
  - **Date phrasing (D04 vs. D05):** in this single-take pair, the phrasing manual trials called
    *less* reliable ("Twenty Twenty Six") produced a clean canonical date (`12 July 2026`), while
    the phrasing called *more* reliable ("Two thousand twenty six") came out with the day changed
    to an ordinal and the year phrase garbled. This contradicts the manual-trial impression rather
    than confirming it. One take per phrasing is evidence, not a conclusion — repeated recordings
    per phrasing would be needed before treating either direction as established. No date
    normalization was implemented or is proposed by this finding alone.
  - **Punctuation (D06–D10):** across all 5 independently recorded takes of the same passage, both
    *internal* sentence boundaries were rendered as a comma every single time (5/5), never a full
    stop, with the following word left lowercase; the *final* boundary (end of recording) got a
    genuine full stop in 4 of 5 takes. This looks positionally systematic within this small sample
    (internal pause vs. end-of-recording pause treated differently), not random per-boundary
    flakiness — but five takes of one passage in one session does not establish this generalizes.
    Attribution between the ASR model's own punctuation and the app's spoken-punctuation
    formatting stage is not resolvable from `postASRDeterministic` alone.
- **D03 fixture correction (closeout, `2cbccf1`):** real audio produced lowercase `ipc`; the
  fixture's `spokenForms` was corrected (existing case-insensitive mechanism) so this casing
  difference no longer misreads as a lost statute identity.

**Second real-audio round (Phase 3E.2B, `Evaluation/References/diagnostics-3e2b/`, N01–N12
statutory-number / Y01–Y10 date / P01–P06 punctuation — tooling/corpus committed at `cefc209`;
real-audio results private, not in Git):**
- **N01–N12:** natural (mixed-form) phrasings correct 1/6, digit-by-digit controls correct 3/6 —
  mostly reproducing 3E.2A, plus a new failure mode: a `BNSS` abbreviation recognized as
  broken-apart letters (`B and S S`) fed the letter-suffix logic and produced a spurious
  compound (`144B`/`125B`) — exactly the shape Phase 3F.A's fragmented-statute guard now
  declines. No upstream digit-canonicalization occurred this round (0/12), unlike 3E.2A's D01.
- **Y01–Y10:** a `"twelve"`→`"twelfth"` substitution occurred at the *same* rate (4/5) in both
  phrasing families — symmetric, not favoring either; the D04/D05 single-pair difference did not
  reproduce as a phrasing effect. Day/month/year were semantically correct in all 10 trials; no
  canonical digit conversion occurred in any of them (0/10). No repeated phrasing advantage
  established.
- **P01–P06:** all 12/12 internal boundaries rendered as commas (never periods) — the D06–D10
  pattern reproduced across three entirely new passages; 6/6 final boundaries got a period.
  Provider-vs-app attribution remains unresolved (same limitation as 3E.2A).
- **Done:** these 3E.2B findings, together with the earlier D02/D03 evidence, motivated and were
  used to design/implement Phase 3F (both 3F.A and 3F.B, committed and now real-audio validated
  against this same N01–N12 corpus — see "Phase 3F" above for the full result), and subsequently
  Phase 3G.A (provider-transcript observability, committed and real-audio validated — see "Phase
  3G.A" above), the recognition-side capability read-only investigation, and Phase 3G.B (the
  legal-vocabulary recognition-boosting experiment — see "Phase 3G.B" above; a bounded experiment,
  not a committed code/config change). Recognition-hint boosting productionization (Slice C), date
  normalization, and punctuation/sentence-boundary heuristics remain out of scope until a
  deliberate decision is made from that evidence.

**Post-3F and post-3G.A real-audio validation are both complete** (see "Phase 3F" and "Phase
3G.A" above for the full case-by-case results: 5/5 grouped-number corruptions fixed, both
fail-closed guards confirmed on real audio, 0 regressions from 3F; and, from 3G.A, all six known
statute degradations attributed to the provider-return boundary, upstream of PratiLekh's own
preprocessing, with 0 regressions from 3G.A itself). The N01–N12 rerun is no longer a pending
action for either phase. Phase 3G.A's attribution rules out PratiLekh's deterministic
preprocessing interval as the source of the statute degradations but did **not** select the next
intervention. The read-only recognition-capability investigation, Phase 3G.B's bounded
canonical-vocabulary experiment (zero measured effect, no correction, no harm — see "Phase 3G.B"
above), and Phase 3G.C's read-only CTC observability investigation (see "Phase 3G.C" above) all
followed directly from that. **Phase 3G.C found that the two available CTC metadata fields cannot
distinguish "not detected" from "detected but rejected" in the installed FluidAudio revision, and
that the most likely explanation — by source-informed inference, not a runtime trace — is that the
three/four-character canonical terms never clear the string-similarity/compound-length gates
before CTC scoring runs at all.** **The recognition-tuning branch (3G.A/B/C) is now closed** as an
evidence/scope decision, not as proof recognition-side improvement is impossible — continuing it
would now mean developing/modifying a specialized legal-ASR rescoring subsystem, beyond this
phase's original scope. **The next planned activity — a read-only architecture
investigation/design of a constrained, local PratiLekh Intelligence layer — has since been
performed** (text-first baseline plus audio-aware research; see "Next planned activity — performed"
above and [`CLAUDE.md`](CLAUDE.md)'s "PratiLekh Intelligence architecture" section for the full
record). Design and research only — **still not authorized to implement** beyond the V1
safety-contract foundation described there.

## Note on deviation from the requested phase list

The requested roadmap is followed as given, in the same order, with one clarification rather
than a structural deviation: Phase 4 ("Judicial Dictation Profiles") is scoped to use Phase 3's
normalization output as an input, since document-type prompt profiles are more useful once
normalized text (correct citations, case numbers, etc.) exists to hand to them — this is a
sequencing dependency the codebase's existing `DictationPromptProfile` design makes natural,
not a reordering of the phases themselves.

## Architecture reference (for fast re-orientation)

- **ASR providers** (all on-device, protocol in `TranscriptionProvider.swift`): Whisper (GGUF,
  99 languages incl. Hindi), Parakeet (FluidAudio, English-only), Nemotron (~40 languages),
  Cohere/External CoreML (14 languages), Apple Speech/SpeechAnalyzer.
- **Existing vocabulary machinery** (Phase 1 will generalize/replace the single-provider parts
  of this): `SettingsStore.CustomDictionaryEntry` (trigger→replacement, UserDefaults),
  `ParakeetVocabularyStore` (JSON, Parakeet-only boosting, capped at 256 terms today),
  `DictionaryTransferService` (JSON import/export).
- **AI post-processing**: `LLMClient.swift` (provider-agnostic OpenAI-compatible client) +
  proprietary closed-source "Fluid Intelligence" local model (`PrivateAIProvider.swift`,
  `PrivateAIIntegrationService.swift`) — not something this fork can extend/modify, only
  configure or bypass.
- **Speaker diarization** (`SpeakerDiarizationService.swift`, `MeetingTranscriptionService.swift`)
  — inherited from FluidVoice's meeting-transcription feature, **out of scope for PratiLekh's
  roadmap** per the product principle above.
- **Persistence**: SQLite (`TranscriptionHistoryDatabase.swift`, JSON blob per row),
  `~/Library/Application Support/PratiLekh/` for dictionary/history/vocabulary/audio.
- **Build**: `PratiLekh.xcodeproj`, scheme `PratiLekh`, `./build.sh [unsigned|fi]`,
  `xcodebuild test -project PratiLekh.xcodeproj -scheme PratiLekh -destination 'platform=macOS'`.

See [`CLAUDE.md`](CLAUDE.md) for session-start conventions and workflow rules.
