# CLAUDE.md

Persistent instructions for Claude Code sessions in this repo. Read this first, every session.

## What this project is

PratiLekh — a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice) (macOS menu-bar
dictation app) being adapted into a dictation tool for Indian courts: a virtual stenographer
for recording evidence and drafting judgements/orders. On-device speech-to-text is the core;
the fork adds Indian legal terminology, Indian names/places, and legal-document formatting on
top of FluidVoice's existing architecture.

**Read [`PRATILEKH_PLAN.md`](PRATILEKH_PLAN.md) for the phased roadmap, what's done,
what's next, and decisions already made.** Keep it updated as phases complete — it's the
cross-session memory for this project, don't let it go stale.

## Tech stack

- Swift 5.9, Swift Package Manager, macOS 15.0+ (Sequoia) target, SwiftUI + AppKit.
- Xcode project: `PratiLekh.xcodeproj`, scheme `PratiLekh`, main target `fluid` (internal
  Xcode target name, not user-facing — left unchanged during the rebrand).
- Key SPM dependencies (all fetched from GitHub, see `Package.swift`): `AppUpdater`,
  `FluidAudio` (altic-dev fork — Parakeet/diarization), `PromiseKit`, `DynamicNotchKit`,
  `transcribe-cpp-swift` (Whisper GGUF inference).
- No backend/server — fully local-first macOS app. The only network calls are one-time
  Hugging Face model downloads (Whisper/Parakeet/Nemotron/Cohere) and, if a user opts in,
  outbound calls to a cloud LLM provider for post-processing.
- Bundle ID: `in.pratilekh.app` (`.debug` suffix for debug builds).

## Build, test, lint

```bash
./build.sh unsigned          # unsigned debug build (no signing identity needed)
./build.sh                   # signed debug build (needs a Team ID — see below)
xcodebuild test -project PratiLekh.xcodeproj -scheme PratiLekh -destination 'platform=macOS'
./scripts/format-and-lint.sh # swiftformat + swiftlint --strict (auto-installs via brew if missing)
```

- **Two distinct test mechanisms exist, don't conflate them.** `Sources/Fluid` is a
  `PBXFileSystemSynchronizedRootGroup` — new files there are picked up automatically, no
  `project.pbxproj` edit needed. The `FluidDictationIntegrationTests` XCTest target is **not**
  synchronized — every file is an explicit `PBXFileReference`/`PBXBuildFile` entry, so adding a
  new XCTest file requires a `project.pbxproj` edit. For pure-logic code with no UI/ASR/audio
  dependency, prefer this repo's other existing convention instead: a standalone
  `@main`-enum `Tests/*.swift` file with `precondition`-based assertions, compiled and run via
  `xcrun swiftc -parse-as-library <sources> <test file> -o <bin> && <bin>` from a
  `scripts/test_*.sh` runner (see `scripts/test_provider_model_verification.sh`,
  `scripts/test_legal_language.sh`) — zero `project.pbxproj` involvement.

- `DEVELOPMENT_TEAM` in the pbxproj is currently the original FluidVoice vendor's Team ID
  (`V4J43B279J`) — this needs to be the user's own team for signed builds. Don't change it
  yourself without being asked; prefer `./build.sh unsigned` for verification builds.
- Built debug app lands at `DerivedData/Build/Products/Debug/PratiLekh Debug.app`.

## Architecture map (for fast orientation, avoid re-exploring from scratch)

- **ASR providers** — protocol `TranscriptionProvider` (`Sources/Fluid/Services/TranscriptionProvider.swift`).
  Implementations: `WhisperProvider` (GGUF via transcribe.cpp, 99 languages incl. Hindi),
  `FluidAudioProvider`/`ParakeetRealtimeProvider` (Parakeet TDT, English-only, Apple Silicon),
  `NemotronProvider` (~40 languages), `ExternalCoreMLTranscriptionProvider` ("Cohere
  Transcribe", 14 languages), `AppleSpeechProvider`/`AppleSpeechAnalyzerProvider`. All run
  on-device; models download once from Hugging Face.
- **Custom vocabulary** — two systems: `SettingsStore.CustomDictionaryEntry` (trigger→replacement
  pairs, UserDefaults) and `ParakeetVocabularyStore` (JSON, vocabulary-boosting for Parakeet
  only, currently capped at 256 terms). Bulk import/export via `DictionaryTransferService`.
  Default bundled seed: `Sources/Fluid/Resources/parakeet_custom_vocabulary.default.json`.
- **AI post-processing** — `LLMClient.swift` (provider-agnostic, OpenAI-compatible: OpenAI,
  Groq, Ollama, custom endpoints) plus a proprietary closed-source local model ("Fluid
  Intelligence", `PrivateAIProvider.swift`/`PrivateAIIntegrationService.swift`) — this fork
  can configure or bypass it but not modify its internals (no source access). Prompt behavior
  is driven by `SettingsStore.DictationPromptProfile` (`SettingsStore.swift:247`) — named,
  freeform system prompts, selectable globally or per-app. This is the extension point for
  document-type formatting (evidence transcript / judgement draft / order).
- **Speaker diarization** — `SpeakerDiarizationService.swift` + `MeetingTranscriptionService.swift`,
  inherited from FluidVoice's meeting-transcription feature. **Out of scope for PratiLekh** —
  see the Product principle in `PRATILEKH_PLAN.md`: PratiLekh records the judge's dictation,
  not the courtroom. Don't build features on top of these two files.
- **Persistence** — SQLite (`TranscriptionHistoryDatabase.swift`, one JSON blob per row) under
  `~/Library/Application Support/PratiLekh/`. Dictionary, vocabulary, audio history, and
  private-AI cache all share that same top-level folder.

## Workflow rules specific to this fork

- **Confidentiality first.** This app handles courtroom evidence and draft judgements.
  Analytics/telemetry is disabled (PostHog key cleared in `Info.plist`) — don't re-enable it
  or add a new telemetry destination without an explicit ask. Cloud LLM post-processing is
  opt-in and off by default; don't flip that default.
- **Storage folder migration.** All persisted state lives under one shared
  `Application Support/PratiLekh/` folder. If you ever rename a storage folder or on-disk
  schema again, add a migration (see `AppSupportMigration.swift` for the existing pattern) —
  don't silently orphan a user's dictionary/history/vocabulary.
- `README.md` was fully rewritten for PratiLekh (kept an Attribution section crediting
  upstream FluidVoice/GPLv3 — don't drop that when editing further).
- **Don't touch `DEVELOPMENT_TEAM`** in the pbxproj or `scripts/check-team-id.sh`'s
  `OFFICIAL_TEAM_ID` without being asked — those are signing-identity decisions that belong
  to whoever is building/distributing the app. Current state: deliberately left at the
  original vendor's Team ID; the user opted to build unsigned (`./build.sh unsigned`) for now
  rather than set up a signing identity.
- **Run `./scripts/format-and-lint.sh` before considering a Swift change done** — this repo
  enforces `swiftlint --strict`.
- **Judge-centric, not courtroom-centric.** PratiLekh records the judge's dictation, not the
  courtroom — no speaker diarization, Judge/Witness/Counsel identification, automatic Q&A
  generation, or verbatim multi-party transcription. See the Product principle in
  `PRATILEKH_PLAN.md` before proposing anything in that direction.
- **Architecture before content.** Legal vocabulary/normalization work follows the phased
  design in `PRATILEKH_PLAN.md` (Legal Language Architecture → Indian Legal Core →
  Normalization Engine → ...) — don't jump straight to seeding a large dictionary or wiring
  AI-based legal-fact correction; check which phase's foundation needs to exist first.
