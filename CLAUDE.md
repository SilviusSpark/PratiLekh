# CLAUDE.md

Persistent instructions and session-handoff memory for Claude Code sessions in this repo.
Read this first, every session. This file is memory, not a diary — it records current
decisions/architecture/state, not how we got here. When in doubt about current uncommitted
work, trust `git status`/`git diff` over this file's prose.

## What this project is

PratiLekh — a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice) (macOS menu-bar
dictation app) adapted into a dictation tool for Indian courts: a virtual stenographer for
recording evidence and drafting judgements/orders. On-device speech-to-text is the core; the
fork adds Indian legal terminology and legal-document formatting on top of FluidVoice's
existing architecture.

**Read [`PRATILEKH_PLAN.md`](PRATILEKH_PLAN.md) for the full phased roadmap and the reasoning
behind each decision.** This file is the fast-orientation summary; that one is the detailed
record. Keep both updated as phases complete.

## Product principle (do not violate)

**PratiLekh records the judge's dictation, not the courtroom.** It is a judge-centric
dictation application, not a courtroom transcription system. The judge decides what is
dictated and therefore what enters the judicial record.

**Explicitly out of scope for the roadmap** — do not propose or build toward these:
- Speaker diarization used to distinguish courtroom participants
- Judge/Witness/Counsel speaker-role transcription
- Automatic courtroom Q&A reconstruction
- Verbatim evidence recording as a multi-speaker transcript

(`SpeakerDiarizationService.swift`/`MeetingTranscriptionService.swift` exist in the inherited
codebase but are not building blocks for this roadmap — see Architecture map below.)

## Milestone / commit state

| Phase | Status | Commit |
|---|---|---|
| 0 — Fork identity & rebrand | ✅ committed | `7b782dade34d4ec810a8c01a714bbbbb3908e508` |
| 1 — Legal Language Architecture | ✅ committed | `272518518ce7ccefedac71a74e48940c174dfdc0` |
| 2 — Indian Legal Core (77 recognition entries, 0 normalization entries, source-curated, current+legacy statutes coexist, no phonetic aliases, pack loadable but **not wired into live ASR**) | ✅ committed | `db250c455a7b733b1a80c8eb109cec2f8066e1dd` |
| 3C + 3C.1 — First normalization rule families (statutory provisions, PW/DW witness refs) | **implemented locally, NOT committed** | — |

Branch `main`, 3 commits ahead of `origin/main`, nothing pushed. **Do not claim a Phase 3
commit exists — verify with `git log`/`git status` before stating commit state to the user.**
As of this writing, `git status` shows Phase 3C/3C.1 as modified/untracked files in
`Sources/Fluid/LegalLanguage/` and three new `Tests/*.swift` files — inspect current
`git status`/`git diff` directly rather than trusting this table if time has passed.

**Phase 3 is not complete as a whole.** 3C+3C.1 is an independently-committable first
checkpoint (two rule families only). Not wired into `ASRService`, `ContentView`,
`MenuBarManager`, any provider, or the live transcription pipeline. Phase 4 has not begun.
Exhibits, case numbers, dates, amounts, and broader abbreviations remain deferred — each needs
its own design/legal-domain review pass before implementation, not opportunistic addition.

## Tech stack

- Swift 5.9, Swift Package Manager, macOS 15.0+ (Sequoia) target, SwiftUI + AppKit.
- Xcode project: `PratiLekh.xcodeproj`, scheme `PratiLekh`, main target `fluid` (internal
  Xcode target name, not user-facing — left unchanged during the rebrand).
- Key SPM dependencies (see `Package.swift`): `AppUpdater`, `FluidAudio` (altic-dev fork —
  Parakeet/diarization), `PromiseKit`, `DynamicNotchKit`, `transcribe-cpp-swift` (Whisper GGUF).
- No backend/server — fully local-first macOS app. Only network calls: one-time Hugging Face
  model downloads, and (if a user opts in) outbound calls to a cloud LLM for post-processing.
- Bundle ID: `in.pratilekh.app` (`.debug` suffix for debug builds).

## Build, test, lint

```bash
./build.sh unsigned          # unsigned debug build (no signing identity needed) -- part of the acceptance gate for every change
./build.sh                   # signed debug build (needs a Team ID -- see below)
xcodebuild test -project PratiLekh.xcodeproj -scheme PratiLekh -destination 'platform=macOS'
./scripts/format-and-lint.sh # swiftformat + swiftlint --strict (auto-installs via brew if missing)
./scripts/test_legal_language.sh  # standalone Legal Language Architecture test suite (see below)
```

- **Gotcha:** `scripts/format-and-lint.sh` runs SwiftFormat in *write* mode and rewrites large
  parts of the inherited FluidVoice tree (~100 files, e.g. injecting `self.`). Never use it as a
  read-only check for scoped changes; lint specific files with `swiftlint lint --strict <paths>`.
- **Two distinct test mechanisms, don't conflate them.** `Sources/Fluid` is a
  `PBXFileSystemSynchronizedRootGroup` — new files there are picked up automatically, no
  `project.pbxproj` edit needed. The `FluidDictationIntegrationTests` XCTest target is **not**
  synchronized — every file is an explicit `PBXFileReference`/`PBXBuildFile` entry, so a new
  XCTest file needs a `project.pbxproj` edit. For pure-logic code with no UI/ASR/audio
  dependency, prefer this repo's standalone convention instead: a `@main`-enum `Tests/*.swift`
  file with `precondition`-based assertions, compiled and run via
  `xcrun swiftc -parse-as-library <sources> <test file> -o <bin> && <bin>` from a
  `scripts/test_*.sh` runner — zero `project.pbxproj` involvement.
- **`scripts/test_legal_language.sh`** is this pattern applied to the whole Legal Language
  Architecture. **Any new file under `Sources/Fluid/LegalLanguage/` must be added to that
  script's `task_sources` list, and any new `Tests/*.swift` file must be added to its
  compile/run loop** — forgetting either produces a confusing "cannot find type" compile error,
  not a silent skip. Standalone binaries have **no app bundle**, so `Bundle.main` resource
  lookups (`BuiltInPacks.indianLegalCore()`) don't resolve inside them — pass file paths as
  `CommandLine.arguments` instead (see `IndianLegalCorePackTests.swift`). Test new Phase 3
  normalizers independently (fixture packs, no live ASR) before any live integration is
  ever attempted.
- Golden-corpus tests for normalizers should cover: positives, idempotence, declines,
  near-misses, dangerous negatives (input that *resembles* a valid pattern but must not
  transform because doing so could alter legal meaning), mixed applied+declined outcomes,
  candidate-boundary cases (e.g. cross-statute references that must stay independent), and a
  standing bucket for regressions found later.
- Existing standalone regression scripts (`scripts/test_*.sh`, `Tests/run_paste_key_cache_tests.sh`)
  must continue to pass after any change — run them alongside the legal-language suite.
- `DEVELOPMENT_TEAM` in the pbxproj is currently the original FluidVoice vendor's Team ID
  (`V4J43B279J`) — don't change it yourself without being asked; prefer `./build.sh unsigned`.
- Built debug app lands at `DerivedData/Build/Products/Debug/PratiLekh Debug.app`.

## Architecture map — inherited FluidVoice code

- **ASR providers** — protocol `TranscriptionProvider` (`Sources/Fluid/Services/TranscriptionProvider.swift`).
  Implementations: `WhisperProvider` (GGUF via transcribe.cpp, 99 languages incl. Hindi),
  `FluidAudioProvider`/`ParakeetRealtimeProvider` (Parakeet TDT, English-only, Apple Silicon),
  `NemotronProvider` (~40 languages), `ExternalCoreMLTranscriptionProvider` ("Cohere
  Transcribe", 14 languages), `AppleSpeechProvider`/`AppleSpeechAnalyzerProvider`. All on-device.
- **Legacy custom vocabulary** — `SettingsStore.CustomDictionaryEntry` (trigger→replacement,
  UserDefaults) and `ParakeetVocabularyStore` (JSON, Parakeet-only boosting, capped at 256
  terms). Superseded in spirit by the Legal Language Architecture below, but not migrated or
  removed — they still run unchanged.
- **AI post-processing** — `LLMClient.swift` (provider-agnostic OpenAI-compatible) plus a
  proprietary closed-source local model ("Fluid Intelligence") — can be configured/bypassed,
  not modified (no source access). Prompt behavior: `SettingsStore.DictationPromptProfile`.
- **Speaker diarization** — `SpeakerDiarizationService.swift`/`MeetingTranscriptionService.swift`
  — **out of scope for PratiLekh**, see Product principle above.
- **Persistence** — SQLite (`TranscriptionHistoryDatabase.swift`, JSON blob per row) under
  `~/Library/Application Support/PratiLekh/`.

## Legal Language Architecture (this fork's own code, Phases 1–3)

Conceptual pipeline (durable, do not deviate without a design pass):
**recognition → deterministic formatting → deterministic legal normalization → optional AI
cleanup (later) → final output.** AI must never silently alter protected legally-significant
content (names, statute identifiers, section numbers, case numbers, dates, amounts,
witness/exhibit identifiers); that protection/validation mechanism belongs to a future AI
phase, not Phase 3.

**Core normalization principle:** format what was dictated; never complete what was not
dictated. Deterministically restructure information the judge actually said; never infer or
supply legally-significant information that wasn't dictated. Prefer preserving uncertain text
over guessing.

**Phase 1/2 architecture (stable, do not redesign):**
- Modular, versioned `LanguagePack`s (`Packs/LanguagePack.swift`); precedence `user >
  jurisdiction > builtin` (`Resolution/PrecedenceResolver.swift`); same-rank conflicts are
  surfaced as `PackConflict`, never silently picked.
- Recognition vocabulary and deterministic normalization are separate concerns with separate
  resolved types (`ResolvedRecognitionVocabulary` vs. `ResolvedNormalizationTable`).
- Provider-agnostic recognition-hint architecture (`Recognition/`); only *verified* provider
  capabilities are mapped in `ProviderCapabilityResolver` — currently only
  `"FluidAudio (Apple Silicon Optimized)"`'s confirmed vocabulary-boosting mechanism; every
  other provider name safely defaults to `.none` rather than a guess.
- **Indian Legal Core** (`Sources/Fluid/Resources/indian_legal_core.default.json`) is the first
  builtin pack: 77 recognition entries, 0 normalization entries. Current codes (BNS, BNSS, BSA)
  and legacy codes (IPC, CrPC, Indian Evidence Act) are independently valid vocabulary —
  **never automatically convert between them.** Odisha/jurisdiction-specific terminology
  belongs in a later, separate jurisdiction pack (not built yet). Speculative phonetic ASR
  aliases (e.g. "bee en es") are deferred until empirical testing against the real ASR
  pipeline — the pack contains only real written forms/abbreviations.
- `BuiltInPacks.swift` loads the bundled pack via `Bundle.main` — nothing in the app calls it
  yet; it's exercised by tests only.

**Phase 3A/3B safety decisions (govern all normalizer design, current and future):**
- Deterministic rule composition; one rule/family's decline never blocks another's safe
  application in the same pass (partial success).
- Three-way outcome distinction, always: no candidate / applied candidate / explicitly
  declined candidate. Tests must assert the specific one, not just "nothing applied."
- Span-level provenance for every applied/declined transformation.
- Ambiguity or uncertainty → preserve the original text, never guess.
- A recognized-but-unsupported structure declines explicitly (with a reason), distinct from
  "no candidate detected at all."
- Cross-family/cross-candidate overlap is never silently resolved by execution order alone
  unless an explicit, tested specificity relationship justifies it.
- Normalization should be idempotent where practical; text outside a rule's owned span is
  preserved exactly (punctuation *inside* an owned span, e.g. between a number and its
  statute, is fair game to change as part of that citation's reformatting).
- No live pipeline integration until a phase explicitly approves it.

**Phase 3C + 3C.1 implementation (current, uncommitted — verify against `git status` for
drift):**

*Engine evolution* (Phase 1 files, extended, not redesigned): `NormalizationContext`
(minimal — optional resolved table + optional resolved recognition vocabulary, no speculative
fields); `LegalNormalizer` protocol now takes that context instead of a bare table;
`AppliedNormalizationChange`/`DeclinedNormalization` gained an immutable `range: NSRange?`
(init parameter, default nil) — an NSRange into the input text of the pass that produced the
change (not the post-replacement text); Phase 3 rules populate it with the owned/examined
source span, Phase 1 table lookups leave it nil;
`LookupTableNormalizer` adapted to read `context.resolvedTable` (pack schema
untouched); `LegalLanguageCoordinator.normalize` composes
`LookupTableNormalizer → StatutoryProvisionNormalizer → WitnessReferenceNormalizer`.

*Shared parsing primitives* (`Normalization/`): `WordTokenizer` (exact-range word tokenizer);
`SpokenNumberParser` (strict digit/tens-word parser only — "three zero two"→"302", "one
twenty"→"120", plus one optional trailing letter suffix; no "hundred" multiplier, no general
NLP, declines rather than guesses on anything else); `StatuteRecognizer` (matches Phase 2's
Indian Legal Core statute entries by their existing canonical/alias text — including
individually-spelled-letter forms like "I P C" — not a second vocabulary).

*Rule families implemented (exactly two; everything else remains deferred — exhibits, case
numbers, dates, amounts, broader abbreviations):*
1. **Statutory provision references** (`StatutoryProvisionNormalizer.swift`) — supports
   `section <number>` (bare, no statute invented), `section <number> <statute>`, and
   `sections <2+ enumerated numbers> <statute>` (comma and/or "and" enumeration — the syntax
   used doesn't change the result). One optional trailing letter suffix, disambiguated against
   a following spelled-out statute abbreviation. Provision order is preserved exactly, never
   sorted or deduplicated. Declines (whole candidate, text preserved) on: malformed/incomplete
   numbers; uncertainty directly attached to a number or to a *mentioned* statute (never a
   bare-number fallback when a statute was doubted — absence and doubt are different); `read
   with`; sub-sections; ranges; the ambiguous cross-statute compound with an omitted second
   `section` keyword (`section 302 IPC and 101 BNS`); a multi-provision list with no statute
   at all. `section 302 IPC and section 101 BNS` (each with its own `section` keyword) stays
   two independent references, never merged.
   - **Parse/render separation (durable architectural decision):** the normalizer only
     produces a `StatutoryProvisionReference` (`StatutoryProvisionReference.swift`: ordered
     provision numbers, optional statute, source span) — it never encodes an output format.
     `StatutoryProvisionRenderer.renderDefault` is the one Phase 3C renderer, producing neutral
     expanded text (e.g. `Sections 294, 323, 341 and 506 IPC`). Comma presence in the dictated
     input must never select a different rendering. A future compact renderer (`u/s
     294/323/341/506 of IPC`) can be added later as a second render function — that's a Phase
     4+ Judicial Dictation Profile/Settings preference, **not built now**, and when it exists
     it changes rendering only, never detected provisions, their order, statute
     identification, ambiguity/decline decisions, provenance, or legal meaning.
2. **Witness references** (`WitnessReferenceNormalizer.swift`) — `prosecution witness`/`PW`/`P
   W` + number → `PW-<n>`; `defence witness`/`DW`/`D W` + number → `DW-<n>` (optional "number"
   connector word supported). Self-correction directly attached to the reference (including
   one that restates the role, e.g. "or was it PW two") declines; a hedge elsewhere in the
   sentence does not block it. Exhibit normalization is explicitly deferred (needs separate
   research into Indian exhibit conventions).

*Tests* (all via `scripts/test_legal_language.sh`): `LanguagePackTests`,
`PrecedenceResolverTests`, `RecognitionVocabularyAdapterTests`, `LookupTableNormalizerTests`,
`LegalLanguageCoordinatorTests`, `SpokenNumberParserTests`, `StatutoryProvisionNormalizerTests`,
`WitnessReferenceNormalizerTests`, `IndianLegalCorePackTests` — 9/9 passing as of this writing.
All 8 existing standalone regression scripts and `./build.sh unsigned` also green as of this
writing. Re-verify all of the above before trusting this statement if time has passed.

## Workflow rules specific to this fork

- **Confidentiality first.** Analytics/telemetry is disabled (PostHog key cleared in
  `Info.plist`) — don't re-enable it or add a new telemetry destination without an explicit
  ask. Cloud LLM post-processing is opt-in and off by default; don't flip that default.
- **Storage folder migration.** All persisted state lives under one shared
  `Application Support/PratiLekh/` folder. If you ever rename a storage folder or on-disk
  schema again, add a migration (see `AppSupportMigration.swift`) — don't silently orphan a
  user's dictionary/history/vocabulary.
- `README.md` was fully rewritten for PratiLekh (kept an Attribution section crediting
  upstream FluidVoice/GPLv3 — don't drop that when editing further).
- **Don't touch `DEVELOPMENT_TEAM`** in the pbxproj or `scripts/check-team-id.sh`'s
  `OFFICIAL_TEAM_ID` without being asked.
- **Lint scoped Swift changes before considering them done** (`swiftlint lint --strict <changed
  files>`; see the format-and-lint gotcha above) — this repo enforces `swiftlint --strict`.
- **Judge-centric, not courtroom-centric** — see Product principle above; don't propose
  diarization/roles/Q&A/verbatim-transcript work.
- **Architecture before content, and one rule family at a time.** Each new normalization rule
  family needs its own design/legal-domain review pass (see `PRATILEKH_PLAN.md` for the
  Phase 3A/3B/3C review pattern) before implementation — don't add a new family opportunistically
  alongside unrelated work, and don't expand an approved family's grammar without a matching
  review.

## Next action (as of this handoff)

Phase 3C + 3C.1 (including the span-provenance fix and `PRATILEKH_PLAN.md` closeout) is
implemented, verified and staged but **not committed** — commit only after explicit approval.
**Do not begin Phase 4 or another normalization family before that commit lands and is
explicitly approved.** Each further family (exhibits, case numbers, dates, amounts) needs its
own design/domain review first.
