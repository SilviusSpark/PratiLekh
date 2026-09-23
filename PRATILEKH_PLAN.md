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

**Not yet committed to git** — see the commit recommendation delivered alongside this plan
revision.

## Phase 1 — Legal Language Architecture

**Purpose:** build the foundation before any legal content exists, so Phase 2 onward is
populating data into a designed system rather than growing an ad hoc one.

**Principal deliverables:**
- A versioned vocabulary/resource **pack** format (schema + version field, load/merge order).
- **Precedence and override rules** between built-in, jurisdictional, and user vocabulary —
  defined explicitly, not implied by load order accidents.
- A clear data/code separation between **recognition vocabulary/hints** (what gets fed to an
  ASR provider to improve recognition) and **deterministic text normalization** (what
  transforms already-recognized text into correct legal form) — these are different concerns
  today conflated in `ParakeetVocabularyStore`'s single-provider vocabulary boosting.
- **Provider-specific vocabulary adapters** — an abstraction so a pack's canonical vocabulary
  can be translated into Parakeet boosting terms, Whisper prompt tokens, or a future engine's
  format, without the pack format itself knowing about any one engine.
- A **pure, testable legal-normalization boundary** — a module with no UI/ASR side effects,
  taking recognized text in and returning normalized text plus provenance metadata out.
- A **provenance model** carried through the pipeline (see cross-cutting principle 2).
- Extension-point design for `ASRService`, `ContentView`, and `SettingsStore` that keeps this
  system's growth out of those files as much as possible.

This phase produces interfaces, protocols, and minimal scaffolding/tests — not real legal
content.

## Phase 2 — Indian Legal Core

**Purpose:** populate the first real vocabulary/normalization pack using Phase 1's
architecture.

**Principal deliverables:**
- **Indian Legal Core** pack, prioritizing current law — BNS (Bharatiya Nyaya Sanhita), BNSS
  (Bharatiya Nagarik Suraksha Sanhita), BSA (Bharatiya Sakshya Adhiniyam) — while retaining IPC,
  CrPC, and the Indian Evidence Act for legacy-case dictation.
- Recognition hints and citation-normalization rules for statutory references under both the
  new and legacy codes.
- Common procedural/judicial terminology and Latin legal maxims as recognition hints.
- Explicitly deferred to later extensions of this same pack mechanism: CPC, other common
  statutes, and broader procedural vocabulary.

## Phase 3 — Legal Normalization Engine

**Purpose:** build out deterministic normalization beyond statutory citations, using the
boundary defined in Phase 1.

**Principal deliverables:**
- Case number normalization.
- Date and amount normalization per legal-drafting convention.
- Witness/exhibit reference normalization — formatting what the judge dictates (e.g., "Exhibit
  P-1", "the witness's statement"), not inferring references from a multi-party transcript.
- Abbreviation expansion/contraction rules.
- A normalization test suite that runs independent of ASR and UI.

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
