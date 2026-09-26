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

## Phase 3 — Legal Normalization Engine — 🚧 In progress (first slice implemented, uncommitted)

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

## Phase 10 — Dictation Accuracy Evaluation

**Purpose:** assess real-world accuracy of the assembled stack and decide whether further STT
investment is warranted.

**Principal deliverables:**
- An evaluation methodology and findings against representative Indian-legal dictation.
- A go/no-go recommendation on investigating an India-tuned STT model (e.g., an AI4Bharat
  model), as a distinct future effort if warranted — not assumed necessary today.

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
