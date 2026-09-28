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
| 2 — Indian Legal Core (77 recognition entries, 0 normalization entries, source-curated, current+legacy statutes coexist, no phonetic aliases, pack loaded by `LegalDictationProcessor`; no recognition hints wired) | ✅ committed | `db250c455a7b733b1a80c8eb109cec2f8066e1dd` |
| 3C + 3C.1 — First normalization rule families (statutory provisions, PW/DW witness refs) | ✅ committed (working tree clean after commit) | `e76ed599ef978abd7d8e494db0ed6c9f6b4136ce` |
| 3D — Live legal normalization, Slices A+B (`LegalDictationProcessor`, `ContentView` seam, leading-capitalization protection) | ✅ committed | `0abf627` (full: `0abf627551be21153f833fa41215d90b396912ae`) |
| 3E.1 — Evaluation framework foundation (`Evaluation/`; substantively Phase 10's methodology deliverable, done early) | ✅ committed | `e916cbc` (full: `e916cbc4fbcfe1a10ba2021d30728b4ec8c1aaac`) |
| 3E.2A — First controlled diagnostic corpus (D01–D10) + a real-audio baseline run (private, not committed) | ✅ references/tooling + closeout committed | `5619375` corpus, `2cbccf1` closeout (D03 fixture fix + findings) |
| 3E.2B — Targeted repetition diagnostics (N01–N12 statutory-number, Y01–Y10 date, P01–P06 punctuation) + a real-audio run (private, not committed) | ✅ references/tooling committed | `cefc209` (full: `cefc209a0780948d5198b5ccc7bbf0ab11edc333`) |
| 3F.A — Fail-closed statutory-normalization safety (`hundred` continuation guard, fragmented-statute/suffix guard) | ✅ committed | `18313d7` (full: `18313d7a52d344c6ccd09fd02eb2ed776681290a`) |
| 3F.B — Bounded grouped-number grammar (`thirty four`→34, etc.) | ✅ committed | `89a2846` (full: `89a2846f3ee3c773adef7f68d67e72629958f915`) |
| 3G.A — Provider-transcript observability (`providerTranscript` stage, Local-API/evaluation seam only) | ✅ committed, real-audio validated | `08a2f24` (full: `08a2f24ac88ab44e6961f989ceceaefa9caf73c8`) |
| 3G.B — Legal-vocabulary recognition-boosting experiment (bounded runtime test, no committed code/config change — findings only) | ✅ documented | `25cfb32` (full: `25cfb327ea3a574f00050ec31364880890161a3e`) |
| 3G.C — CTC rescoring observability investigation (read-only; recognition-tuning branch closed) | ✅ documented | `f462ce1` (full: `f462ce11e2888752fd731d903b4f06d3e40d2a41`) |
| Intelligence V1 foundation — deterministic proposal/protected-span/validator types + adversarial unit tests (`Sources/Fluid/Intelligence/Safety/`); zero LLM/model/network integration | ✅ committed | `5d83c11` (full: `5d83c110bf374ea1c94a2511038d627669dfc34a`) |
| Intelligence V1.1 — Proposal transport/parsing boundary (`Sources/Fluid/Intelligence/Transport/`: strict JSON→native-proposal parser, provider-independent, structural-all-or-nothing); zero LLM/model/network integration | ✅ committed | `ca63584` (full: `ca635849e65ee9b583dfabf9e3b5189fc91d52c5`) |
| Intelligence V1.2 — Proposal generation contract & provider-envelope adapter (`Sources/Fluid/Intelligence/Generation/`: tool schema, instructions, minimal provider-independent response envelope, adapter enforcing expected-tool-call policy); entirely synthetic, zero LLM/network/provider-specific integration | ✅ committed | `7ff7a13` (full: `7ff7a1327ecb4cb0742c016dd306a5d56d361bb1`) |
| Intelligence V1.2 test-infrastructure repair (stale pre-rebrand `FluidVoice_Debug` imports fixed; 3 blocked raw-argument tests executed for real) | ✅ committed | `b5969ba` (full: `b5969baa5c5382c16740af41522c046c924881f8`) |
| Intelligence V1.3 — local-model evaluation: Qwen2.5 1.5B tool-engagement failure (V1.3B, 0/15 framing matrix) and Granite 4 3B protocol-viability success (V1.3C, 25/25 Stage 1) | ✅ documented | `cc6052e`, `7496074`, `b84bd26` |
| Intelligence V1.4/V1.4B/V1.4C — model-facing addressing contract search, selection (occurrence-primary, 1-based), and adversarial validation (20/20 deterministic, 40/40 live ordinal trials) | ✅ documented (experimental, `Evaluation/Intelligence/Experimental/`) | `1a6c7cb` (full: `1a6c7cba788fb82267cc62d12f2b594379a20812`) |
| Intelligence V1.5 — addressing contract freeze (design/documentation only; zero production code) | ✅ committed | `1a6c7cb` (full: `1a6c7cba788fb82267cc62d12f2b594379a20812`) |
| Intelligence V1.6 — production addressing resolver (`Sources/Fluid/Intelligence/Addressing/`: `ModelFacingEdit`, `IntelligenceAddressingResolver`, `IntelligenceAddressingBridge`; overlapping-literal + zero/one/multi-match context clarifications to V1.5; no wire schema/parser, no model, no dictation wiring, no insertion) | ✅ committed | see `git log` ("Add Intelligence production addressing resolver") |
| Intelligence V1.7 — model-facing wire contract & strict parser (`Transport/ModelFacingEditTransportParser`, `Generation/ModelFacingGenerationContract`, `Generation/ModelFacingResponseAdapter`; raw args → parser → `[ModelFacingEdit]` → V1.6 bridge → Safety Authority; V1.2 contract retained; no model, no insertion, no dictation wiring) | ✅ committed | see `git log` ("Add Intelligence model-facing wire contract") |
| Intelligence V1.8 — deterministic composition boundary (`Composition/IntelligenceEditComposition`: response + immutable source + caller protected spans → V1.7 adapter/parser → V1.6 bridge → unmodified Safety Authority → structured result; applies nothing, returns no text; no model, no dictation wiring) | ✅ committed | see `git log` ("Add Intelligence composition boundary") |
| Test-infrastructure verification milestone — root-caused and fixed the pre-existing `FluidDictationIntegrationTests` build failure (stale pre-rebrand `FluidVoice_Debug` module name in every test file's `@testable import`, plus one dead upstream `AudioRecoveryTestSupport` fallback); executed the 3 previously-blocked V1.2 raw-argument tests for real plus 1 new one, all passing | ✅ committed | `b5969ba` (duplicate row with the entry above; kept for history) |

Local `main` was 27 commits ahead of `origin/main`, 0 behind, nothing pushed, at V1.5 (`1a6c7cb`).
Verify current ahead/behind state with Git rather than relying on this document.

**Phase 3 is not complete as a whole.** 3C+3C.1 is the committed first checkpoint (two rule
families only). **Phase 3D Slices A+B (committed, `0abf627`)** live-activate that normalization at one
`ContentView` seam (see below); recognition boosting, custom-dictionary reconciliation and AI
protection are not done. **Phase 3F.A (committed, `18313d7`)** adds fail-closed safety to the
statutory-number grammar; **Phase 3F.B (committed, `89a2846`)** adds the bounded grouped-number
grammar itself — see "Phase 3F" below. **Phase 3G.A (committed, `08a2f24`)** adds observability of
the transcription provider's own returned text ahead of PratiLekh's deterministic preprocessing —
see "Phase 3G" below. Phase 4 has not begun.
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
- `BuiltInPacks.swift` loads the bundled pack via `Bundle.main`; `LegalDictationProcessor.shared`
  is its only production caller.

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

**Phase 3C + 3C.1 implementation (committed in `e76ed59`):**

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

**Phase 3D live integration (Slices A+B):** `LegalDictationProcessor` (`LegalLanguage/`) wraps
the builtin pack + `LegalLanguageCoordinator`; returns `NormalizationOutcome` (normalized text +
provenance). `ContentView` calls it in `processStoppedTranscription` (after spoken punctuation
and spoken-send, before AI) and in `reprocessDictationText`; the result stays in scope through
the AI branch for Phase 7. Always on, no setting. Streaming preview, `ASRService`, providers and
API/file paths are deliberately untouched (a test script check enforces that `Services/` never
references the processor). `pendingAIReprocessText` is intentionally left holding pre-legal text
because `reprocessDictationText` re-runs the deterministic chain itself.
Leading-capitalization protection: `NormalizationOutcome.protectsLeadingCapitalization(of:)`
(LegalDictationProcessor.swift) is true only when an *applied* change owned the first token; it is
passed as `preserveLeadingCapitalization:` (default false) to `ASRService.applyGAAVFormatting` and
`applyContinuousDictationFormatting` in both ContentView pipelines. Already-canonical text with no
applied change is deliberately not protected; general protected spans are Phase 7. The other
GAAV/continuous call sites (prompt test, history undo) are unchanged.
Known open items: history "undo AI" restores pre-legal raw text; custom dictionary runs *before*
legal normalization by design.

**Phase 3F — Statutory Number Safety** (`SpokenNumberParser.swift`,
`StatutoryProvisionNormalizer.swift`), driven directly by 3E.2A/3E.2B real-audio evidence of
`SpokenNumberParser` corrupting mixed-form provision numbers:

*3F.A (committed, `18313d7`) — fail-closed safety, no grammar expansion:*
- **Unsupported numeric continuation:** `"hundred"` immediately after a parsed digit run (e.g.
  `three hundred twenty three`, `three hundred and twenty three`, `five hundred six`) now
  declines the whole candidate (`DeclineReason.unclearValue`) instead of silently committing to
  the wrong short prefix (`Section 3 ...`). `hundred` itself remains unimplemented, by design.
- **Fragmented-statute / suffix ambiguity:** a trailing letter after a number (a candidate
  section-letter suffix, e.g. `376A`) is no longer assumed to be a genuine suffix when neither
  statute-match attempt succeeds. `StatuteRecognizer.looksLikeFragmentedAlias` narrowly detects
  when the letter plus what follows (tolerating **at most one** literal `"and"` as a positional
  wildcard — never rewritten or asserted to mean any specific letter) positionally matches a
  known statute alias's exact length (≥3 real letters required) — e.g. dictated `BNSS` recognized
  as broken-apart letters `B and S S` no longer donates its `B` to produce a spurious `144B`.
  Detection-only: never reconstructs/canonicalizes a statute, never returns a citable `Match`.
  Architecture: the alias-pattern detector lives beside `StatuteRecognizer`'s existing
  spelled-letter matching; the decline-vs-apply decision stays in
  `StatutoryProvisionNormalizer.resolveNumberAndStatute` (a new file-local `StatuteResolution`
  tri-state: `.found`/`.none`/`.ambiguousFragment`), which is shared by both the singular and
  plural (last-member) paths. Legitimate suffixes (`376A`, `498A`, `120B`, `376A IPC`) remain
  supported; a false-decline floor (≥3 known letters) was specifically tuned against a
  `"...120B and S. Roy filed an appeal"`-style counterexample. **Acknowledged, evidence-scoped
  gap:** `B S S` with no `"and"` gap is not currently handled by this rule — not a known
  production defect, since no real-audio evidence of that exact shape exists yet.

*3F.B (committed, `89a2846`) — the bounded grouped-number grammar
itself, in `SpokenNumberParser.parseGroupedCompound`:* `[leading digit] + tens-word +
[trailing digit]`, combined **arithmetically** (not string-concatenated) — `thirty four`→`34`,
`one forty four`→`144`, `three twenty three`→`323`, `three seventy six`→`376`, `one twenty
five`→`125`. Teens (`ten`..`nineteen`) never combine with a trailing digit (already encode both
digits). Preserves unchanged: all pure digit-by-digit forms, and the pre-existing `one
twenty`→`120` / `one twenty B`→`120B` idiom. Because the grammar is deliberately *bounded* (never
re-enters its own loop), `matchUnsupportedNumberContinuation` was generalized: a digit/tens word
immediately adjacent to an already-complete grouped result also declines now (pure digit-by-digit
parses can never leave such a token adjacent, so this only ever fires for the new bounded shape).
`hundred` remains unsupported, protected unchanged by 3F.A. Shared with `WitnessReferenceNormalizer`
(same `SpokenNumberParser`) — confirmed semantically appropriate (`PW twenty three` now correctly
→ `PW-23`, previously `PW-203`) and covered by one explicit regression test.
**Deterministic offline probe result** (real production code, `Evaluation/References/diagnostics-3e2b`
N01–N12, no audio involved): 11/12 correct; N10 (`five hundred six`) correctly remains unchanged/
declined. **This is a deterministic-code result, not real-audio end-to-end proof** — see "Three
layers of evidence" below.

**Real-audio validation of Phase 3F (both 3F.A and 3F.B) — the existing N01–N12 recordings
rerun unchanged after 3F, compared directly against the original pre-3F baseline.** Both
runs used the identical 3E.2B N01–N12 audio and the same provider (Parakeet TDT v2, English
Only); only the code changed. Result locations are private, local diagnostic-result
directories, not repository artifacts:
- Baseline: commit `cefc209` (pre-3F.A, pre-3F.B),
  `/Users/kumarspandan/pratilekh-eval-results/2026-09-27T090531Z/`.
- Post-3F: `HEAD` `785921c`, `/Users/kumarspandan/pratilekh-eval-results-post-3fb/2026-09-27T104836Z/`.
  28/28 samples processed without error in both runs.

*Evidence boundary check first:* `postASRDeterministic` WER/CER was **identical** between the
two runs (12.9% / 3.5%) — the same recordings produced the same observable upstream text both
times, so any change in `legalNormalized` is attributable to the code change, not a different
audio sample or a different recognition outcome. `postASRDeterministic` is still not raw ASR
(see "Three layers of evidence" below); it still cannot isolate provider decoding from custom
dictionary, filler removal, or spoken-punctuation processing.

*3F.B grouped-number result — confirmed on real audio, not just offline text:* all five
grouped-number corruptions present in the baseline were corrected on the same audio: N01 `304
→ 34`, N03 `1404 → 144`, N05 `3203 → 323`, N07 `3706 → 376`, N11 `1205 → 125`. Stated
carefully: **Phase 3F.B corrected 5/5 previously-corrupted grouped-number cases in this fixed
N-series real-audio sample** — this is not a claim that generalizes beyond this corpus. Of
those five, N03 and N11 reached the fully correct end-to-end statutory citation (e.g. `Section
144 BNSS`); N01/N05/N07 obtained the correct number but the overall citation remained
incomplete because the statute word (`IPC`) had already been lost/misrecognized as `it c`
before legal normalization ever saw it — a limitation upstream of the boundary this evaluation
can observe, not a 3F.B defect.

*3F.A safety result — confirmed on real audio:* N10 (`five hundred six`) went from a partial
corruption (`Section 5 hundred six...`) to an unchanged, safe decline. N04 and N12 (`BNSS`
recognized as fragmented letters `B and S S`) went from false-positive suffix-like
transformations (`Section 144B`, `Section 125B`) to safe declines.

*Critical-token result (the clearest single signal of this validation):* corrupted critical
tokens went from 7 (baseline) to **0** (post-3F); incorrect-transformation outcomes went from 3
to **0**; regressions found: **0** — nothing that previously worked or previously declined
safely became worse.

*The apparently worse normalized WER/CER is not a regression:* baseline `legalNormalized`
WER/CER was 13.6% / 4.6%; post-3F is 14.0% / 6.3%. A safe decline retains the longer original
spoken text, which can score worse by edit distance than a shorter-but-legally-corrupted
transformation would have. The metrics that actually track legal safety moved in the intended
direction (corrupted tokens 7→0, incorrect transformations 3→0). This is another concrete
instance of the "diagnostic lessons" note below: don't read WER alone as a legal-dictation
quality signal.

*What remains unresolved (evidence recorded, no solution selected):*
1. `"IPC"` was observed as `"it c"` in several N-series recordings.
2. `BNSS` was sometimes observed as fragmented letters (`"B and S S"`).
3. `five hundred six` remains deliberately unsupported, but now fails safely rather than
   corrupting.
4. Date/year phrasing reliability remains unresolved from Phase 3E diagnostics (see below).
5. Internal sentence-boundary punctuation remains unresolved from Phase 3E diagnostics (see
   below).

At the time of this run, (1) and (2) were upstream of the legal-normalization boundary this
evaluation could observe, with no finer attribution possible from `postASRDeterministic` alone —
see "Phase 3G.A" below, which narrows this further (both are already present at the provider-return
boundary, upstream of PratiLekh's own preprocessing).

**Phase 3F status:** 3F.A — implemented, committed, **and real-audio validated**. 3F.B —
implemented, committed, **and real-audio validated** against the fixed N01–N12 corpus. Phase
3F eliminated the known deterministic statutory-number corruptions targeted by the phase and
converted the tested unsupported/ambiguous forms to fail-closed behavior. Remaining failures in
the fixed real-audio sample are either upstream of legal normalization or deliberately
unsupported. **Phase 3F does not universally solve statutory dictation** — it does not touch
statute-word recognition, `hundred`, dates, or punctuation.

**Phase 3G.A — Provider-transcript observability (committed `08a2f24`, real-audio validated).**
Adds one new observable value, `providerTranscript`: the text returned across the
`TranscriptionProvider` boundary (`transcribeFinal`/`transcribeFile`), captured before PratiLekh's
own filler removal, custom-dictionary substitution and spoken-punctuation formatting. Exposed only
at the Local API/evaluation seam (`ASRService.transcribeSamplesForAPI`/`transcribeFileForAPI`,
`InferenceAPIController`, `EvalRunner`, reported as a sibling field on `SampleRunRecord` rather than
an entry in the scored `stages` list, so it doesn't shift what `postASRDeterministic` is scored
against — see `Evaluation/README.md`). **`providerTranscript` is not necessarily raw acoustic/token
decoder output** — a `TranscriptionProvider` implementation may already perform its own internal
processing before returning this string, and that processing remains opaque to PratiLekh. No
production transcription/normalization behavior was changed by this phase.

*Real-audio validation, reusing the same N01–N12 recordings and provider (Parakeet TDT v2, English
Only), against commit `08a2f24`:*
- **Attribution result for the six previously known statute-degradation cases** (N01, N04, N05,
  N06, N07, N12 — `IPC`→`it c`-style and `BNSS`→`B and S S`-style): **6/6 already present in
  `providerTranscript`**, i.e. present at the provider-return boundary, upstream of PratiLekh's
  filler-removal/custom-dictionary/spoken-punctuation preprocessing. **0/6 were introduced between
  `providerTranscript` and `postASRDeterministic`; 0/6 were first introduced by legal
  normalization.** This attributes *where relative to PratiLekh's own code* the degradation exists;
  it does **not** identify *why* the provider produced it — do not read this as an acoustic-decoding
  finding, since provider-internal processing before the returned string is not observable.
  Correctly recognized cases (unaffected): N02, N03, N08, N09, N11. N10 (`five hundred six`) is not
  a recognition-degradation case at all — the text is accurate; it remains an intentional
  grammar-scope safe-decline (3F.A), not corruption.
- **Regression check against the prior post-3F baseline, across the full 28-sample N/P/Y corpus:**
  `postASRDeterministic` and `legalNormalized` were both **byte-for-byte identical to the prior
  post-3F run for every sample** (0 differences). The five Phase 3F.B grouped-number corrections
  remain correct, N10 still fails closed, N04/N12 still safely decline, and no new incorrect
  legal-normalization transformation appeared. **Phase 3G.A introduced no measured
  production-pipeline behavioral change** in this fixed corpus.
- **Instrumentation limitation:** for all 28 real-audio samples, `providerTranscript` happened to
  equal `postASRDeterministic` exactly, because none of these specific recordings exercised filler
  removal, custom-dictionary substitution, or a literal spoken-punctuation word. This is a property
  of this fixed corpus's content, not a defect — the committed synthetic evaluation tests (stub-server
  cases in `scripts/test_evaluation.sh`) separately and directly demonstrate the instrumentation can
  represent a genuine divergence when one exists. **This real-audio run does not comprehensively
  validate every preprocessing transformation** — only that none of the three happened to fire here.

**What this evidence does and does not establish:** it rules out PratiLekh's own currently-observed
deterministic preprocessing interval (filler removal, custom dictionary, spoken-punctuation
formatting) as the source of these six statute degradations. **It does not yet select the next
intervention.** Remaining, unranked candidate directions include: recognition-side improvements, if
the existing local ASR stack supports them; a constrained text-based PratiLekh Intelligence layer;
or, eventually, audio-aware intelligence if later evidence justifies it. A **read-only
investigation** of recognition-side capabilities followed this question directly — see "Phase
3G.B" immediately below for what it found and what was subsequently tested.

**Phase 3G.B — Legal-vocabulary recognition-boosting experiment (bounded A/B experiment, not a
production change; no source, test, or configuration file was committed for it).** The read-only
recognition-stack investigation found that the exact installed FluidAudio revision already
contains a CTC-based vocabulary-rescoring mechanism, and PratiLekh's `FluidAudioProvider` already
wires it into the same manager used for final Parakeet TDT v2 transcription — inactive only
because `SettingsStore.vocabularyBoostingEnabled` defaults to `false`. Phase 3G.B tested this
mechanism directly: vocabulary boosting was enabled via the existing (non-source) runtime
configuration surface — the user-level `parakeet_custom_vocabulary.json` file and the
`VocabularyBoostingEnabled` user default, both entirely outside the Git repository — with a
**canonical-terms-only vocabulary** (`IPC`, `BNSS`, `BNS`, `CrPC`, `CPC`; no aliases, no observed
error forms such as `it c`/`B and S S`), and the pre-existing threshold configuration left
completely unchanged (`alpha: 2.8`, `minCtcScore: -2.2`, `minSimilarity: 0.72`,
`minCombinedConfidence: 0.64`, `minTermLength: 3`). Enabling boosting caused the already-shipped
CTC model (`parakeet-ctc-110m`) to be downloaded/loaded for the first time on this machine — this
is the model the already-integrated feature needs to run, not a new project dependency or a newly
implemented capability. The full 28-sample N/P/Y real-audio corpus was re-run under this
condition and compared against the Phase 3G.A baseline; the experimental settings/vocabulary were
restored to their exact prior state afterward (verified byte-for-byte), and no tracked source file
was changed to run this experiment.

*Result:* across all 28 samples, **`providerTranscript`, `postASRDeterministic`, and
`legalNormalized` were all identical to the baseline — 0 differences in any of the three fields,
for any sample.** For the six known degraded cases (N01, N04, N05, N06, N07, N12 — the `IPC`→`it c`
and `BNSS`→`B and S S` cases): 0/6 fully corrected, 0/6 partially improved, 6/6 unchanged, 0/6
worsened. The five already-correct statute cases (N02, N03, N08, N09, N11) all remained unchanged:
5/5 preserved. Across the full corpus, no new legal-term substitution was observed, no previously
correct transcript regressed, and no P/Y sample acquired a registered legal term. **No harmful
effect was observed in this fixed corpus** — this is deliberately not generalized to "vocabulary
boosting is safe": it is a statement about this one run, this one vocabulary, and these unchanged
thresholds only.

**Correct interpretation (do not overreach):** this experiment establishes only that, under the
existing untuned thresholds, this five-term canonical-only vocabulary, and this fixed corpus,
enabling the mechanism produced no measurable transcript benefit or harm. It does **not**
establish that vocabulary boosting can never help, that lower thresholds or aliases would help,
that the CTC spotter failed to detect the terms, that it detected but rejected them, or that
vocabulary boosting is production-safe more broadly. No threshold tuning or alias addition is
recommended from this evidence alone.

**Observability limitation:** `ASRResult.ctcDetectedTerms`/`ctcAppliedTerms` exist inside the
installed FluidAudio dependency but are discarded by PratiLekh's `FluidAudioProvider` wrapper
before returning `ASRTranscriptionResult` (not modified in this experiment). The existing
`BOOST_HIT` log line is **not** evidence of CTC detection or application — it is a plain
case-insensitive substring check against the already-produced transcript text, unrelated to
whether the rescoring pass itself found or attempted anything. **Phase 3G.B therefore cannot
currently distinguish** "candidate not detected," "candidate detected but not applied," "candidate
applied," or any other internal rescoring behavior for the six target cases. A reliable A/B
latency comparison was also not available from existing surfaces and was not obtained.

A **read-only Phase 3G.C architecture investigation** followed directly, into the smallest safe
diagnostic seam for exposing already-computed CTC rescoring metadata during evaluation — see
"Phase 3G.C" immediately below for what it found and the resulting decision.

**Phase 3G.C — CTC rescoring observability investigation (read-only; no code, config, or
dependency change).** Traced the exact installed FluidAudio source (not upstream documentation)
for `ASRResult.ctcDetectedTerms`/`ctcAppliedTerms` and the full CTC rescoring decision path.

*`ctcDetectedTerms`/`ctcAppliedTerms` are not useful as-is:* both are `[String]?`, populated only
from `RescoreOutput.replacements`, and **every `RescoringResult` that ever enters that array is
constructed with `shouldReplace == true`** (the one and only code path that appends to it,
`applyReplacement`, hardcodes this). Consequently the two fields are **effectively equivalent** in
this installed revision, and both are non-empty only when a replacement was already accepted and
substituted into the transcript. **A rejected candidate leaves no trace in either field** — they
cannot distinguish "not detected" from "detected but rejected," and carrying them through PratiLekh
would add no diagnostic information beyond the boosted-vs-baseline `providerTranscript` comparison
Phase 3G.A/B already perform. **Decision: the contemplated structural `ctcDetectedTerms`/
`ctcAppliedTerms` diagnostic seam will not be implemented** — it would not answer the question it
was proposed to answer.

*The actual decision path (ordering matters):* candidate vocabulary term → **transcript/string-
similarity gating first** → only if that gate passes, CTC acoustic scoring over the relevant audio
window → boosted vocabulary CTC score compared against the original-phrase CTC score → accept/
reject → accepted, non-overlapping replacements applied → **only applied replacements reach the
returned CTC metadata**. The mechanism is not unconditional audio-based reconsideration of every
word; it first requires the existing decoded text to already be textually similar enough to a
registered vocabulary term.

*Rejected-candidate evidence exists but is discarded:* once a candidate clears the similarity gate
and reaches CTC evaluation, FluidAudio computes the candidate term, original phrase, similarity,
both raw CTC scores, the boosted score, the audio span, and a decision reason — all of this is
thrown away immediately for rejected candidates rather than retained on `ASRResult`. Exposing it
structurally would require modifying FluidAudio itself, not just PratiLekh's wrapper.

*Existing debug logging:* Debug builds already emit this candidate-level CTC comparison
information through Apple's unified logging when a candidate reaches CTC evaluation. A live
debug-level log capture during a *future* run could observe this without any source modification —
but this was **not** captured during Phase 3G.B, cannot retroactively explain that run, and no
further recognition experiment is currently authorized (this is not recorded as a planned next
step — see "Architectural decision" below).

*Source-informed inference on `IPC`/`BNSS` specifically (inference, not runtime proof that a
specific gate fired during Phase 3G.B):* for `IPC → it c`, the individual observed fragments have
low string similarity to `IPC`; the plausible concatenated form `itc` is closer but still below
the configured `minSimilarity`; and — more importantly — the installed compound-matching path
requires the vocabulary term to be **at least 4 characters**, so three-character targets (`IPC`,
`BNS`, `CPC`) never use that multi-word compound path at all. For `BNSS → B and S S`, the
four-character term *can* enter compound matching, but plausible fragment combinations from the
observed text still land below the configured similarity threshold. These are reasoned inferences
from applying the installed, unmodified similarity formula to already-observed text — not a
confirmed runtime trace of what happened during Phase 3G.B.

*Threshold-field trace limitation (narrow, do not generalize):* `minCtcScore` and
`minCombinedConfidence` exist in the loaded vocabulary configuration, but Phase 3G.C did not
establish that they participate in the active term-centric `evaluateCTCMatch` acceptance
comparison, which directly compares the boosted vocabulary CTC score against the original-phrase
CTC score. This is a trace gap for this specific code path, not a claim that those fields are
unused everywhere in FluidAudio.

**Architectural decision: the current recognition-tuning branch is closed after Phase 3G.C.** No
current authorization for threshold tuning, aliases, another vocabulary-boosting experiment,
modifying the three-character compound-length rule, modifying FluidAudio, exposing
rejected-candidate score structures, a production vocabulary-boosting default, or a Phase 3G.D
recognition experiment. This is an **evidence/scope decision, not proof that recognition-side
improvement is impossible** — the evidence establishes only that continuing this path would now
move beyond cheaply evaluating an existing, already-integrated mechanism and toward
developing/modifying a specialized legal-ASR rescoring subsystem, which is a materially larger
undertaking than the phase's original scope.

**Next planned activity — performed; see "PratiLekh Intelligence architecture" immediately below
for the full record.** The read-only architecture investigation/design of a constrained, local
PratiLekh Intelligence layer (starting from the principles above) was carried out across three
follow-on milestones: a read-only Intelligence-layer safety/output-contract investigation, a
read-only investigation into whether FluidVoice's own local "Fluid Intelligence" runtime is a
viable PratiLekh dependency, and a Version 1 text-only proposal/validator design plus a further
read-only research investigation into the long-term (text-only vs. audio-aware vs. unified)
architecture question. **No Intelligence code has been implemented from any of this** — it is
design and research only.

## PratiLekh Intelligence architecture (investigated and designed — not implemented)

Three read-only/design-only milestones followed directly from the closed recognition-tuning
branch above, producing architecture decisions and a first proposal-contract design, but **zero
implementation**. Nothing in this section has been built; do not implement from it without an
explicit, separate implementation milestone (see "Next milestone" at the end of this section).

**Why Fluid Intelligence (FluidVoice's own local AI) is not a PratiLekh dependency — the lesson,
not the dependency.** A read-only investigation (no PratiLekh or FluidVoice files edited) confirmed
PratiLekh does not contain or link the proprietary `PrivateAIProviderBridge`; `PRIVATE_AI_PROVIDER`
is not enabled in this build — not set anywhere in `PratiLekh.xcodeproj`'s compilation conditions,
and never has been anywhere in this repo's Git history. The separately-installed
`/Applications/FluidVoice.app` on this machine confirms local AI post-processing is technically
real and viable: it runs a local MLX-based "Fluid Intelligence" runtime (a proprietary
`fluid-intelligence-mlx` helper process, spawned via `Process`/pipes, plus an in-process
`llama.cpp` fallback backend) against two custom-architecture model checkpoints (`fluid-1-nvfp4-mlx`,
a Gemma-4-family MLX model, and an MTP speculative-decoding drafter). None of this is reusable by
PratiLekh: the bridge's own dependency module (`FluidIntelligenceCore`) has no buildable/obtainable
form anywhere on this machine; the helper binary is proprietary and its exact pipe protocol is
unverified; the model checkpoints use custom architectures with no reusable inference code
available to PratiLekh. **This is an architectural ownership/maintainability decision, not a
criticism of FluidVoice** — PratiLekh's own generic `LLMClient` already has full, working support
for local OpenAI-compatible servers (Ollama and LM Studio are pre-existing built-in providers,
complete with local-endpoint detection and no-API-key handling) — that existing path is what
PratiLekh Intelligence is architecturally built around, not Fluid Intelligence.

**Governing principle (architectural invariant, not an experiment-specific observation):**
> The model is replaceable. The safety contract is not.
> The model proposes. Deterministic PratiLekh code decides what may affect the transcript.

The Intelligence model/provider must never become the sole authority over judicial transcript
content. No future milestone should weaken this invariant merely to make a correction easier to
apply.

**Three conceptually distinct Intelligence tasks — do not treat as one undifferentiated generative
rewrite; each has different evidence requirements and a different risk profile:**
1. **Recognition repair** — "what words did the judge actually say?" (e.g. ASR `it c` →
   acoustically supported `IPC`; a misrecognized Indian legal term or proper noun). Best long-term
   evidence may include original audio and recognition evidence. Legally consequential — the
   strictest treatment: never autonomous, review-only at most, regardless of how the proposal is
   backed.
2. **Dictation interpretation** — "what did the judge intend to retain after an explicit
   correction?" (`"15 March — sorry — 16 March"`, `"defendant — correction — plaintiff"`,
   `"three years — strike that — two years"`). Explicit corrections, false starts and repair
   structures belong here. An ambiguous correction must fail closed — preserve the original text,
   never silently delete substantive dictated speech — rather than guess at a reparandum boundary.
3. **Surface polishing** — "how should the retained dictation be written?" (punctuation,
   capitalization, whitespace, conventional formatting). Text alone is generally sufficient. This
   is the only category eligible for autonomous application in the V1 design below.

**Long-term architecture direction — hybrid and staged, not a single unrestricted speech-language
model:**
```
audio
→ first-pass ASR (currently Parakeet/FluidAudio)
→ deterministic ASR preprocessing
→ deterministic legal normalization
→ legalNormalized
→ PratiLekh Intelligence Proposal Engine
→ Deterministic Safety Authority
→ final transcript
```
Long-term, Intelligence may additionally consume bounded original-audio evidence, ASR
timestamps/alignment, decoder alternatives/N-best hypotheses if available, recognition
confidence/evidence if available, static legal-domain context, and dynamic case vocabulary — but
**targeted/bounded audio access is not a permanent invariant.** Prefer targeted audio
re-examination of spans the deterministic pipeline already flags as suspect, where that's cheap to
identify, while keeping broader utterance-level audio review open as a possibility if evaluation
ever shows first-pass error detection has insufficient recall. This remains an experiment
question, not a settled design.

**Static vs. dynamic vocabulary — do not conflate:**
- **Static legal-domain vocabulary** (IPC, BNS, BNSS, CrPC, CPC, BSA/Evidence Act, POCSO, NI Act,
  recurring judicial terminology) — prefer contextual biasing, vocabulary mechanisms,
  retrieval/context, or other evidence-backed adaptation before assuming fine-tuning is necessary.
- **Dynamic case vocabulary** (accused, complainant, witnesses, advocates, villages, police
  stations, organizations, unusual local place names) — fundamentally per-matter context; must
  not be baked into globally distributed model weights. Likely long-term design: a per-matter
  vocabulary/context mechanism supplied to recognition and/or Intelligence, not training.

**Training/fine-tuning decision.** Training a speech-language foundation model from scratch is
**not the plan**. Fine-tuning of any kind is **deferred** — no custom PratiLekh model should be
trained merely because training is technically possible. Sequence: establish the architecture,
evaluation methodology, and failure modes first; collect high-quality real judicial
dictation/reference data; only then determine empirically whether adaptation is required. Possible
future outcomes (none committed to): ASR/domain adaptation, LoRA/adapters for a second-pass model,
personal/on-device adaptation, synthetic-data augmentation, or no fine-tuning at all if contextual
mechanisms prove sufficient.

**Training/evaluation data principle** (for whenever a dataset is eventually built): conceptually
preserve, where applicable: original audio; first-pass ASR; deterministic intermediate text;
legal-normalized text; an authoritative human-validated final reference; alignment/timestamps
where available; legal-term, proper-name, and filler/disfluency annotations; explicit
correction/reparandum spans; supplied dynamic vocabulary. **The authoritative reference represents
what the judge actually dictated/intended to retain, not what an AI believes would be legally or
stylistically preferable** — the same governing principle the `Evaluation/` framework already
uses (see below). Real judicial dictation is the eventual gold standard; synthetic data may
bootstrap rare-term/entity/correction evaluation but must never silently replace real-data
validation.

**Text-Only Intelligence Baseline / Safety Contract V1 — designed, not implemented, not
discarded.** A complete design exists for a model-independent, span-based proposal/validator
contract operating on `legalNormalized` alone. Its purpose is understood primarily as proving the
safety architecture itself before audio complexity is added — not as a preview of final production
behavior. Major decisions preserved:
- Every proposal references the immutable `legalNormalized` source; exact `expectedSourceText`
  matching only — **no fuzzy source alignment**; a mismatch is always a rejection.
- Proposals are span-based (source range + expected text + replacement + category + optional
  confidence/rationale), never free-text replacement.
- The edit category a proposal claims for itself is **never trusted** — deterministic code always
  independently re-derives the actual character-level edit category from the two strings before
  deciding anything.
- Protected spans have **three distinct semantics, not two**: deterministically **resolved** (an
  applied normalization — no proposal at all permitted, not even review-only), deterministically
  **unresolved** (a declined normalization — review-only permitted, since a decline means "we
  don't know," not an alternative fact), and **independently protected** (dates, amounts, case
  numbers, exhibits, names — categories with no existing recognizer at all, handled by a
  deliberately coarse, over-inclusive heuristic gate, never a new Phase-3 normalizer).
  **Applied and declined normalization must never be documented or implemented as equivalent.**
- V1's autonomous-application scope is deliberately narrow: punctuation-only, capitalization-only,
  and whitespace-only edits outside any protected span, each with an exact, testable predicate.
  Everything else is review-only or forbidden for V1.
- Semantic proposal failures (bad range, source mismatch, overlap, excessive span) are isolated to
  the one proposal where safe; structural failures (malformed JSON, wrong schema version, no tool
  call) invalidate the whole response.
- Model-supplied confidence is **never an acceptance criterion**, for any reason, whether the
  proposal is text-only or (later) audio-backed.
- **Zero unsafe accepted edits is the hard target, reported as a raw violation count — never
  folded into an aggregate score.**

**Forward-compatibility decision.** Speculative audio-model fields (`acousticConfidence`,
`alignmentEvidence`, `candidateAlternatives`, or other model-specific evidence structures) are
**deliberately not frozen into V1** merely because they might be useful later. The requirement
instead: the proposal/disposition taxonomy must **remain extensible** so future proposal classes
such as `recognitionRepair` and `dictationCorrection` can be added later without breaking the
deterministic safety architecture already designed. Any audio-specific schema should be designed
only after the chosen audio/recognition-evidence source is experimentally understood — not now,
and not speculatively.

**Future recognition-evidence investigation (not yet performed).** Mature published
ASR-error-correction approaches often benefit from N-best hypotheses rather than requiring a full
audio-language model. **PratiLekh currently exposes only a single final transcription string
through its `TranscriptionProvider` abstraction** — no word timestamps, token/word confidence,
decoder scores, N-best hypotheses, or lattices are exposed today. Whether FluidAudio/Parakeet can
expose any of these is an important, currently-unanswered future investigation; if it can, an
intermediate architecture (`audio → Parakeet → transcript + decoder alternatives/recognition
evidence → Intelligence → deterministic validation`) may be viable before or alongside full
audio-aware Intelligence. **Do not claim this is currently supported — it is not; this is a
future investigation only.** Also preserved as an open question, explicitly not investigated in
this documentation milestone: whether the pinned `altic-dev/FluidAudio` dependency (see Tech
stack above) has drifted from the actively-developed public FluidAudio repository.

**Planning framework — Intelligence generations** (a roadmap concept, not a committed release
schedule; version names are planning labels, not released product versions):
- **Intelligence V1 — Safety Architecture.** Text-only proposal/validator experiment. Goal: prove
  an untrusted local model can propose changes while deterministic PratiLekh code controls what
  reaches output. This is the Text-Only Intelligence Baseline above.
- **Intelligence V2 — Recognition Evidence.** Investigate/use Parakeet timestamps, confidence,
  decoder alternatives, N-best hypotheses, or similar evidence where available. Goal: improve
  recognition-repair evidence without immediately requiring a second audio model.
- **Intelligence V3 — Audio-Aware Intelligence.** Introduce original-audio evidence where V2 is
  insufficient. Target capabilities: recognition repair, Indian legal terminology, Indian proper
  nouns, explicit mid-dictation correction resolution, improved disfluency handling. Recognition
  repair and dictation correction remain separately validated proposal classes even here.
- **Intelligence V4 — Domain Adaptation.** Only after sufficient validated data exists, determine
  whether fine-tuning/adaptation materially improves the system. Possible outcomes: ASR
  adaptation, second-pass model adapters, personal/local adaptation, or a decision that
  fine-tuning is unnecessary.

**Evaluation invariants for any future Intelligence** (extends the existing `Evaluation/` metrics
below — never replaces the "never blend metrics" principle): track separately, where applicable,
WER/CER, legal-term error rate, proper-noun error rate, statutory-reference exactness,
explicit-correction resolution accuracy, filler-removal precision/recall, deletion of substantive
dictated speech, hallucinated words, protected-fact mutation, punctuation/formatting, latency, and
memory. **Hard safety principle: a system that improves prose while changing a dictated legal fact
is a failure. Deletion of substantive speech and unsafe protected-fact mutation must be visible as
raw violations, not hidden inside aggregate scores** — the same discipline Phase 3F's WER-vs-safety
finding already established for deterministic normalization now applies to Intelligence too.

**Next milestone (the only currently-authorized Intelligence work).** Implement the
model-independent Text-Only Intelligence Safety Contract V1 foundation: proposal data types,
protected-span representation, the deterministic validator, and comprehensive deterministic unit
tests — with **zero LLM/model/network integration**. The purpose is to prove the safety boundary
first. Tests should eventually include deliberately hostile/mislabelled proposals such as attempts
to: change statute identity; change statutory numbers; change dates; change amounts; change names;
disguise a lexical change as punctuation/capitalization/whitespace; overlap protected spans; use
stale/mismatched source text; and submit overlapping/conflicting proposals. The required outcome
is that unsafe proposals cannot reach final output. **Only after that foundation passes should a
local text model be connected for the first real proposal-generation experiment** — not before,
and not as part of the same milestone that builds the foundation.

## Intelligence V1.3A–V1.8 (test-infra repair through deterministic composition boundary)

**This section is stale-prose-corrected as of the V1.5 milestone; the detailed evidence lives in
`Evaluation/Intelligence/Experimental/*.md` and `Evaluation/Intelligence/V1_5_ADDRESSING_CONTRACT_FREEZE.md`
— read those for full raw counts. This section is a pointer/summary, not a duplicate.**

Since Intelligence V1.2 was committed, the following happened, in order (all committed except
where noted): a test-infrastructure verification milestone (stale pre-rebrand `FluidVoice_Debug`
imports across `FluidDictationIntegrationTests`, fixed; the 3 blocked V1.2 raw-argument tests
executed for real and passed); **V1.3 — Local Model Evaluation Harness**, which installed Ollama
locally (cloud explicitly disabled throughout) and found `qwen2.5:1.5b` cannot engage tool-calling
for any supplied-text-processing task despite reliably engaging for a trivial factual/action tool
(V1.3B: 0/15 across a full framing matrix — tool name, description, user framing, and semantic task
class all ruled out as the cause); **V1.3C**, which then tested a Granite 4 escalation ladder and
found `granite4:3b` (3.4B params, Q4_K_M) is **the first tested model to qualify as a viable
protocol candidate** — 25/25 on the Stage 1 capability gate, and zero unsafe accepted edits /
zero source-resolution defects when its (imperfect) real output was run through the unmodified V1.0
Safety Authority. This is a protocol-capability finding only — legal-domain quality, proper-noun
handling, and correction precision/recall remain untested.

**V1.4 / V1.4B / V1.4C** then investigated, selected, and adversarially validated the **model-facing
addressing contract** — how a model expresses *which* text it means without ever computing UTF-16
offsets itself. Key results: a bare `sourceText`/`replacementText` representation cannot express
repeated-text disambiguation (a real model silently mis-targets rather than signaling the gap);
**occurrence (1-based) is the primary discriminator** (V1.4B: 4/4 correct vs. exact-context's 0/4 on
genuine short-fragment cases; V1.4C: 40/40 correct across repetition counts 2/3/5/10, including
genuine — non-workaround — 10-way short-fragment counting, 10/10); optional exact left/right context
provides corroboration/fallback under a precise, fully adversarially-tested decision table (V1.4C,
20/20 deterministic cases, superseding V1.4B's broader description); and — the single most important
confirmed property — **a proposal can resolve correctly and unambiguously while still being unsafe
to apply**, and the unmodified V1.0 Safety Authority catches this every time it was tested live
(V1.4C's `E5`: a real Granite proposal resolved to an entire two-sentence passage with a valid
occurrence, correctly identified by the resolver, then correctly rejected by Safety Authority as not
a punctuation/capitalization/whitespace-only edit). **Zero resolver safety failures and zero unsafe
accepted edits across all of V1.3C/V1.4/V1.4B/V1.4C.**

**V1.5** froze this into a normative, model-independent addressing contract
(`Evaluation/Intelligence/V1_5_ADDRESSING_CONTRACT_FREEZE.md`) — the decision table, field semantics
(occurrence is 1-based, `0` always invalid, never auto-corrected), the "smallest correction-bearing
span" model-facing instruction (a prompt guideline only — the resolver never shrinks or guesses a
model-selected span; the Safety Authority is what contains an over-broad-but-literal span), and an
explicit resolver-vs-Safety-Authority separation. **This is a design/documentation freeze only — no
production code exists for any of this yet.** `Sources/Fluid/Intelligence/` (V1.0/V1.1/V1.2) remains
completely unmodified throughout V1.3–V1.5; every experiment reused those committed types verbatim,
never a reimplementation. All experimental Swift/tests/scripts live under
`Evaluation/Intelligence/Experimental/`, deterministic and Ollama-free except where a file's own name
says otherwise. `granite4:3b` is a **research/protocol candidate only** — never document it as the
selected production model.

**V1.6** then implemented the frozen contract's *addressing layer* in production
(`Sources/Fluid/Intelligence/Addressing/`; full record in
`Evaluation/Intelligence/V1_6_PRODUCTION_ADDRESSING_RESOLVER.md`): `ModelFacingEdit` (narrow, no id/
category/range), `IntelligenceAddressingResolver` (pure, typed rejections), and
`IntelligenceAddressingBridge` (immutable-source batch → standard `IntelligenceProposal`; ids `p<n>`
1-based by original position, `claimedCategory = .other`, `expectedSourceText` from the real source;
per-item failure isolation; nothing applied). It **clarifies/corrects V1.5** (V1.5 is left intact as
history; the V1.6 doc governs): (1) overlapping literal matches are all candidates — the experimental
non-overlapping scan silently resolved `"aa"` in `"aaa"` to position 0; (2) supplied context matching
zero candidates is contradictory evidence and rejects (unique or repeated, any occurrence) — this
*corrects* V1.4C's A10; one match is informative; several is non-narrowing but does not contradict a
valid occurrence *inside* the matching set (an occurrence outside it rejects as
`occurrenceContradictsContext` — decided, architect-confirmed); (3) bridge metadata as above. Experimental `detectOverlaps` was not
promoted (V1.5's "mirrors the Authority" claim was inaccurate for same-position zero-length ranges);
`IntelligenceSafetyAuthority` stays sole authority on overlap/protected spans/classification.
Insertion, the model-facing wire schema/parser, `IntelligenceGenerationContract` (still asks for
UTF-16 offsets) and any model/dictation wiring remain **not built**. The V1.1 parser cannot parse the
model-facing shape, so the V1.5 §16 diagram's "V1.1 parser before resolver" step is still missing a
model-facing counterpart.

**V1.7** then built the model-facing wire boundary (`Evaluation/Intelligence/V1_7_MODEL_FACING_WIRE_CONTRACT.md`):
`ModelFacingEditTransportParser` (strict, all-or-nothing, duplicate/unknown-key rejection, no coercion,
own size bounds, root key `edits`), `ModelFacingGenerationContract` (tool `propose_literal_transcript_edits`,
schema mirroring the parser, instructions stating literal source / smallest span / 1-based occurrence /
optional context / no offsets-ids-categories), and `ModelFacingResponseAdapter` (raw arguments → parser →
V1.6 bridge; does not call the Safety Authority). **Decided ownership: the wire parser owns only lexical
integer-ness of `occurrence`; `0`/negative/out-of-range parse and are judged by addressing**, preserving
the frozen fallback rule and per-item isolation. This **supersedes the V1.5 §16 diagram** (the V1.1
parser cannot parse the model-facing shape). The V1.2 internal contract/adapter and V1.1 parser are
retained unmodified (still used by their tests and by `LLMClientRequestBodyTests`). No model is invoked and
nothing is wired into dictation; insertion remains unbuilt. The model-facing schema is the **V1 Intelligence
capability contract** (correction-oriented surface edits), distinct from the legacy internal/UTF-16
contract, and explicitly not a permanent definition of all future Intelligence capabilities — no
richer-intent abstraction is to be added speculatively.

**V1.8** then added the single deterministic composition entry point
(`Evaluation/Intelligence/V1_8_COMPOSITION_BOUNDARY.md`): `IntelligenceEditComposition.evaluate(response:source:protectedSpans:)`
→ `Result<IntelligenceCompositionResult, ModelFacingAdapterFailure>`, reusing V1.7 parsing, V1.6 addressing and
the unmodified Safety Authority with no policy of its own (parity-tested). Three domains stay distinct:
transport/batch failure (`.failure`), per-edit addressing rejection, and Safety Authority disposition
(`IntelligenceComposedEdit.stage`). The Authority runs **once over the whole resolved batch** (per-proposal
invocation would defeat pairwise overlap detection). The result carries `schemaVersion` and per-edit outcomes in
original order with stable `p<n>` ids, and **no resulting text — nothing is applied**. Model/provider/runtime
independent; still not wired into dictation. The V1 model-facing schema remains a versioned V1 capability
subset; no richer-intent abstraction was added.

**Known open risks, not solved by any of the above:** (1) mutually-consistent-but-wrong addressing
evidence — if a model's occurrence and context agree with each other but both misidentify the
intended occurrence relative to true intent, the resolver resolves consistently and correctly *per
its own contract*; this is provably undetectable by resolver consistency alone (V1.4C, test `A13`)
and is a model/evaluation-layer risk, not an addressing-layer defect; (2) Granite's Unicode fidelity
remains poor and unresolved (Odia text hallucinated into an unrelated script; a non-BMP emoji
reproduced with a spurious adjacent newline) — both failure classes fail closed every time observed,
and this is deliberately not "fixed" by the addressing contract; (3) offering multiple optional
discriminator fields together, under permissive prompting, correlated with the model choosing
whole-passage `sourceText` over minimal-diff spans — safe (contained by Safety Authority) but a real
efficiency/usability concern, not yet mitigated.

## Evaluation framework (Phase 3E.1, `Evaluation/`)

Standalone tooling to measure where dictation fails, stage by stage. **Governing principle: the
reference is what the judge dictated, not what an evaluator or model thinks was intended; never
reward substituting a "better" provision/statute/fact/date/amount.** Synthetic references live in
`Evaluation/References/synthetic/*.json`; **audio (even of synthetic scripts) and all run results
stay outside Git** (the runner refuses in-repo `--out/--audio/--text-dir`). Stages are
`providerTranscript` (Phase 3G.A, observability only, audio runs only: the transcription
provider's own returned text, before PratiLekh's preprocessing — still not raw ASR, since a
provider may already do its own internal processing), `postASRDeterministic` (`/v1/transcribe`
output: after fillers, custom dictionary, spoken punctuation), and `legalNormalized`. Metrics are
never blended: WER/CER, exact critical tokens with preserved/recovered/unrecovered/corrupted
transitions, normalization outcomes (false positives and incorrect transformations are severe),
formatting. Run with `scripts/eval_run.sh`, test with `scripts/test_evaluation.sh`; the Local API
must be enabled in the app first (off by default — its enable flag is read once at app launch,
with no live reload, so toggling it requires an app restart to take effect). Known limitation:
spoken-number vs digit forms count as WER errors (not addressed yet). See `Evaluation/README.md`.

**Diagnostic corpus + first real-audio baseline (Phase 3E.2A, `Evaluation/References/diagnostics-3e2a/`,
D01-D10, see `Evaluation/DIAGNOSTICS_3E2A.md` for the case-by-case guide):** measurement only, no
production change made from it. Findings from the first real-audio run (private results, not
committed):
- **D01–D03 (section-number phrasing):** for D01 (digit-by-digit, "three two three"), the text
  reaching `LegalDictationProcessor` was *already* digits (`Section 323 IPC`) — the Phase 3
  statutory normalizer's expected input never appeared, so this sample scored `notEvaluable`, not
  `correctApplication`. D01's correctness in that run is therefore not attributable to our
  normalizer; an earlier stage (which one is not observable from `postASRDeterministic`) already
  converted it. For D02 ("three twenty three") and D03 ("three hundred twenty three"), the spoken
  words survived recognition intact and the normalizer itself corrupted them — confirming the
  documented findings (digit/tens concatenation -> `3203`; "hundred" outside the supported grammar
  -> partial `Section 3`) with real audio.
- **D04 vs. D05 (date phrasing):** in this single-take pair, the phrasing earlier called *less*
  reliable produced a clean `12 July 2026`; the phrasing called *more* reliable came out with the
  day as an ordinal and the year phrase garbled — the opposite of the manual-trial impression. One
  take per phrasing; not a conclusion.
- **D06-D10 (punctuation, 5 independent takes of one passage):** both internal sentence boundaries
  became a comma in all 5/5 takes (never a full stop); the final (end-of-recording) boundary got a
  full stop in 4/5. Looks positionally systematic within this small sample, not random — but five
  takes of one passage/session doesn't establish it generalizes. `postASRDeterministic` cannot
  separate the ASR model's own punctuation from the app's spoken-punctuation formatting stage.
- **D03 fixture correction (closeout, `2cbccf1`):** the real run exposed real audio saying `ipc`
  in lowercase; the fixture's `spokenForms` was corrected to accept it (case-insensitive, existing
  schema mechanism), so a harmless casing difference no longer misreads as a lost statute identity.

Findings from D02/D03 directly motivated Phase 3F (statutory number safety, see above).

**Second diagnostic corpus + real-audio run (Phase 3E.2B, `Evaluation/References/diagnostics-3e2b/`,
N01–N12 statutory-number / Y01–Y10 date / P01–P06 punctuation, see `Evaluation/DIAGNOSTICS_3E2B.md`):**
measurement only, no production change made *from* this run (Phase 3F was designed/implemented from
the earlier 3E.2A evidence and a text-based/offline probe, not from this real-audio run). Findings
from the real-audio run (private results, not committed):
- **N01–N12 (statutory numbers, pre-3F.B code):** natural (mixed-form) phrasings correct 1/6, control
  (digit-by-digit) phrasings correct 3/6 — mostly reproducing 3E.2A's pattern, plus a **new failure
  mode**: in the two `BNSS` cases, the statute abbreviation was recognized as broken-apart letters
  (`B and S S`), which fed the (then-unfixed) letter-suffix logic and produced a spurious compound
  identifier (`144B`, `125B`) — the exact shape Phase 3F.A's fragmented-statute guard now declines.
  No upstream digit-canonicalization occurred in this run (0/12), unlike 3E.2A's D01 — ASR-side
  number handling is evidently not a reliable constant across sessions.
- **Y01–Y10 (date phrasing, 5 trials each family):** a `"twelve"`→`"twelfth"` substitution occurred
  at the *same* 4-of-5 rate in **both** phrasing families (symmetric, not favoring either) — the
  earlier D04/D05 single-pair difference did not reproduce as a phrasing effect. Day/month/year were
  semantically recognizable and correct in all 10 trials regardless; no canonical digit conversion
  occurred in any of them (0/10), unlike 3E.2A's one D05 success. No repeated advantage for either
  phrasing was established.
- **P01–P06 (punctuation, 3 new passages × 2 takes):** all 12/12 internal boundaries rendered as a
  comma (never a period) — the D06–D10 pattern reproduced across entirely different passages; 6/6
  final boundaries got a period (stronger than D06–D10's 4/5). Same attribution limit applies:
  `postASRDeterministic` cannot separate provider decoding from the app's own formatting stage.

## Three layers of evidence (keep these distinct when reasoning about any finding above)

1. **Real-audio evidence** — what actually happened when the user's recorded speech went through
   the app (the 3E.2A/3E.2B private runs above). Strongest evidence, but small samples.
2. **`providerTranscript` (Phase 3G.A)** — the text returned across the `TranscriptionProvider`
   boundary, before PratiLekh's filler removal, custom dictionary, or spoken-punctuation formatting.
   This separates "already present when the provider returned its text" from "introduced by
   PratiLekh's own preprocessing" — but it is **not raw acoustic/token decoder output**; a provider
   may already perform its own opaque internal processing before returning this string. Only
   available for audio evaluated via the Local API (see `Evaluation/README.md`).
3. **`postASRDeterministic` text** — the same value as before, after filler removal, custom
   dictionary, and spoken-punctuation formatting. Still not raw provider output.
4. **Deterministic offline probes** (e.g. the Phase 3F.B N01–N12 result above) — prove what the
   legal normalizer does with specific *text*; they do **not** prove the ASR will actually emit
   that text from speech.

## Diagnostic lessons worth remembering

- Ordinary WER can penalize a *desirable* spoken-number→digit conversion — read critical-token and
  normalization-outcome results, not WER alone, for legal correctness.
- `notEvaluable` (expected source span absent from the observed text) is distinct from a
  normalization failure — don't conflate an upstream recognition miss with a normalizer defect.
- Diagnostic fixtures encode *desired* behavior, not a freeze of known-bad output; a legitimate fix
  can change a baseline observation without needing a test edit (see D02/D03 above and 3F.B's N-series
  result).
- Exact-case differences (e.g. lowercase `ipc`) should be represented via the schema's existing
  case-insensitive `spokenForms`, not misread as lost statute identity (the D03 lesson, §above).

## Current Handoff (read this first in a new session)

1. **Completed:** Phases 0–2, 3C+3C.1, 3D (live activation), 3E.1 (evaluation framework), 3E.2A and
   3E.2B (diagnostic corpora + real-audio runs, findings above), 3F.A (fail-closed statutory safety,
   real-audio validated), 3F.B (bounded grouped-number grammar, real-audio validated), the post-3F
   N01–N12 real-audio validation, 3G.A (provider-transcript observability, real-audio validated),
   the recognition-side capability read-only investigation, 3G.B (legal-vocabulary
   recognition-boosting experiment — bounded, not a committed code/config change), and 3G.C
   (CTC rescoring observability investigation, read-only — see "Phase 3G.C" above). **The
   recognition-tuning branch (3G.A/B/C) is now closed** — see "Architectural decision" under
   "Phase 3G.C" above. Also completed: the full **PratiLekh Intelligence architecture**
   investigation/design track (read-only Intelligence-layer investigation, read-only
   FluidVoice/Fluid-Intelligence runtime-access investigation, Text-Only Intelligence Baseline /
   Safety Contract V1 design, and audio-aware architecture research) — see "PratiLekh Intelligence
   architecture" above. **No Intelligence code has been implemented.**
2. **Exact current `HEAD` at the time of writing this entry:** `7ff7a1327ecb4cb0742c016dd306a5d56d361bb1`
   ("Add Intelligence proposal generation boundary"), branch `main`, 22 ahead of `origin/main`/0
   behind, nothing pushed. Per this file's own opening instruction, trust `git log`/`git status`
   over this paragraph if time has passed. Immediately preceded by `ca63584` (Intelligence V1.1),
   `5d83c11` (Intelligence V1.0), `18dc992` (Intelligence architecture doc), `f462ce1` (Phase
   3G.C), `25cfb32` (Phase 3G.B).
3. **One pending, staged (not committed) test-only change set: the test-infrastructure
   verification milestone below (item 14).** All Intelligence V1.0/V1.1/V1.2 source is fully
   committed at the `HEAD` above; no `Sources/` changes are outstanding. Phase 3F.A, 3F.B and 3G.A
   remain fully committed. Phase 3G.B was a bounded runtime experiment (settings + a user-level
   vocabulary file, both outside the repository) and left no tracked-file changes. Phase 3G.C was
   read-only. Verify with `git status`/`git log` before trusting this if time has passed.
4. **What 3F.A changed:** see "Phase 3F" above — `hundred`-continuation fail-closed decline;
   fragmented-statute/suffix-ambiguity fail-closed decline. No grammar expansion. Confirmed on real
   audio (N10, N04/N12), not just unit tests.
5. **What 3F.B changed:** the bounded grouped-number grammar itself (see "Phase 3F" above) —
   `[leading digit] + tens-word + [trailing digit]`, combined arithmetically. Confirmed on real
   audio: 5/5 previously-corrupted grouped-number cases in the fixed N01–N12 corpus fixed, 0
   regressions.
6. **What 3G.A changed:** added the `providerTranscript` observable value at the Local
   API/evaluation seam only (see "Phase 3G.A" above) — no production transcription/normalization
   behavior changed. Real-audio validated: 0 differences from the prior post-3F run across all 28
   N/P/Y samples (both `postASRDeterministic` and `legalNormalized`), confirming no regression.
7. **Statute-degradation attribution result (the reason 3G.A was built):** for the six previously
   known degraded cases (N01, N04, N05, N06, N07, N12), **6/6 are already present in
   `providerTranscript`** — i.e. at the provider-return boundary, upstream of PratiLekh's
   filler-removal/custom-dictionary/spoken-punctuation preprocessing. 0/6 are introduced by that
   preprocessing; 0/6 are first introduced by legal normalization. This is **not** established as
   an acoustic-decoding finding — provider-internal processing before the returned string remains
   opaque. N02, N03, N08, N09, N11 remain correctly recognized; N10 remains an intentional
   grammar-scope safe-decline, not a recognition failure.
8. **What the 3G.B experiment found (bounded, canonical-terms-only, thresholds untouched):**
   enabling the already-integrated FluidAudio CTC vocabulary-rescoring mechanism produced **zero
   measured effect** on any of the 28 samples — 0/6 degraded cases corrected, 5/5 already-correct
   cases preserved, 0 false positives, 0 regressions. See "Phase 3G.B" above.
9. **What the 3G.C investigation found (read-only, resolves 3G.B's open question as far as it can
   be resolved without a FluidAudio change or a new live-captured run):** `ctcDetectedTerms`/
   `ctcAppliedTerms` are effectively equivalent in the installed FluidAudio revision and can never
   represent "detected but rejected" — every entry that ever reaches them already has
   `shouldReplace == true` by construction. Exposing them would add no information beyond the
   existing `providerTranscript` diff. **Decision: that diagnostic seam will not be built.**
   Source-informed inference (not runtime proof): `IPC`/`BNS`/`CPC` are 3 characters and therefore
   never qualify for the installed compound-word-matching path (which requires ≥4 characters),
   and hand-computed string similarities for the observed fragments (`it`/`c` vs `IPC`, and
   plausible `B`/`and`/`S`/`S` combinations vs `BNSS`) fall below the configured similarity
   threshold either way — suggesting these candidates most likely never reached CTC scoring at all,
   rather than being scored and rejected there. See "Phase 3G.C" above for the full trace.
10. **Instrumentation limitation to remember:** all 28 real-audio samples (in both the 3G.A baseline
    and the 3G.B experiment) happened to have `providerTranscript == postASRDeterministic`, because
    none of these specific recordings exercised filler removal, custom-dictionary substitution, or a
    literal spoken-punctuation word. The committed synthetic tests separately prove the
    instrumentation can represent a genuine divergence; this real-audio run does not comprehensively
    validate every preprocessing transformation.
11. **Most important open evidence areas:** (a) *ruled out*: PratiLekh's own deterministic
    preprocessing interval as the source of the six statute degradations (3G.A); (b) *measured and
    now substantially explained, not further pursued*: canonical-vocabulary CTC boosting produced no
    effect on this corpus (3G.B), most likely because the string-similarity/compound-length gates
    reject these specific short terms before CTC scoring ever runs (3G.C, inference) — this branch
    is now closed, not left as an open question to keep investigating; (c) date/year phrasing
    reliability — no repeated advantage for either phrasing established across 15 real-audio trials
    total; (d) punctuation — strongly reproduced comma-for-internal-boundary pattern (22/22 across
    two rounds), provider-vs-app attribution still unresolved; (e) `five hundred six`-style
    `hundred` dictation remains deliberately unsupported (now fails safely, not corrupted) — whether
    to expand the grammar to cover it is an open product question, not yet decided.
12. **The PratiLekh Intelligence investigation/design track is complete. Both V1.0 (safety
    contract) and V1.1 (transport/parsing) are committed** (`5d83c11`, `ca63584`) with V1.1's
    architectural decisions confirmed alongside V1.0's: overlapping proposals rejected outright
    (never merged/composed, never resolved by ordering); the dedicated protected-span intersection
    predicate approved over `NSIntersectionRange`; confidence/rationale remain omitted; strict
    unknown-field and duplicate-key rejection approved (Foundation's silent
    first-value/last-value collapsing and unknown-field leniency verified empirically, not
    assumed); the named transport/resource limits (payload ≤1MB, ≤500 proposals, ID ≤200 chars,
    text fields ≤10,000 chars, aggregate ≤200,000 chars) are explicitly transport bounds only, not
    semantic-safety permissions; duplicate proposal IDs rejected structurally. **Intelligence
    V1.2 — the model-facing generation contract and provider-response adapter — is now
    implemented** (staged, pending architectural review — not yet committed as of this entry):
    `Sources/Fluid/Intelligence/Generation/` (`IntelligenceGenerationContract`: the
    `propose_transcript_edits` tool schema, matching V1.1's wire contract exactly, plus concise
    V1-scope instructions; `IntelligenceProviderResponse`/`IntelligenceProviderToolCall`: a minimal,
    provider-independent synthetic envelope carrying **raw, undecoded** tool-call argument text;
    `IntelligenceProviderResponseAdapter`: enforces an expected-exactly-one-correctly-named-tool-call
    policy and hands the raw arguments straight to the unmodified V1.1 parser, never repairing or
    reinterpreting malformed output) plus adversarial adapter tests and full
    adapter→parser→authority end-to-end synthetic tests -- **now committed at `7ff7a13`**
    (`Tests/IntelligenceGenerationContractTests.swift`,
    `Tests/IntelligenceProviderResponseAdapterTests.swift`, run via
    `scripts/test_intelligence_safety.sh`) — **entirely synthetic, zero LLM/network/provider-specific
    integration**. **The `LLMClient.ToolCall` raw-argument gap flagged when this was first written
    is now resolved, minimally and additively:** `LLMClient.ToolCall` gained a `rawArguments: String`
    field, populated at all four of its response-construction sites (Responses-API streaming and
    non-streaming, Chat-Completions streaming and non-streaming) from the exact string already in
    scope there, before `JSONSerialization` ever decodes it — verified by tracing every construction
    site, not assumed; no existing consumer (`CommandModeService.swift`, the pre-existing
    `LLMClientRequestBodyTests.swift` suite) reads a fixed field count, so this is purely additive.
    `IntelligenceProviderResponse` remains a distinct type (kept for provider-independence, not
    because of this gap anymore); a small, isolated bridge
    (`IntelligenceProviderResponse+LLMClientBridge.swift`, deliberately its own file so the rest of
    `Generation/` keeps zero dependency on `LLMClient` and stays testable via the lightweight
    standalone convention) reshapes an already-obtained `LLMClient.Response` into it, carrying
    `rawArguments` through unchanged — no reserialization, no live `LLMClient` call anywhere in this
    milestone. Three new tests were added to the *existing* `LLMClientRequestBodyTests.swift`
    XCTest file (no new XCTest file, no `.pbxproj` edit) proving raw-argument preservation
    (including a duplicate-key and a whole-number-float case) through the real streaming
    accumulation path and into V1.1 rejection. **As of item 14 below, these 3 tests (plus a 4th,
    non-streaming one) have now actually been executed and pass — see item 14 for the fix that
    unblocked this and the real runtime evidence.** **Also unresolved and prominently flagged, not
    solved:** whether a local model can reliably compute UTF-16 offsets directly (the committed
    V1.1 wire contract's `rangeStart`/`rangeLength` representation) is architecturally doubtful and
    untested — no model was invoked to check. If offsets are wrong, the existing exact
    `expectedSourceText` match still fails closed (safety is unaffected), but proposal *usefulness*
    under this representation is an open question for the live-model milestone to actually measure,
    not something this synthetic milestone could resolve. See "PratiLekh Intelligence architecture"
    above for the full design record. **This is still not Intelligence V1 "generally complete"** —
    no live model or provider has been wired to any of this yet. **Exact immediate next action
    now:** architectural review of the staged test-infrastructure fix in item 14; only after that
    review and a commit should live-model wiring be considered, and only after the UTF-16 gap above
    is explicitly resolved.
14. **Test-infrastructure verification milestone (staged, not committed as of this entry) —
    the `FluidDictationIntegrationTests` build failure blocking the 3 V1.2 raw-argument tests is
    now root-caused and fixed.** Two distinct, unrelated stale-reference bugs were found in the
    test target, both inherited/pre-existing and unrelated to any Intelligence code:
    - **Root cause A (the real blocker for the whole target, discovered after fixing the
      previously-diagnosed issue below):** every one of the 21 files in
      `Tests/FluidDictationIntegrationTests/` still wrote `@testable import FluidVoice_Debug` —
      the app's **pre-rebrand** product name. Phase 0 (`7b782da`) renamed `PRODUCT_NAME` to
      `"PratiLekh Debug"` for the `fluid` target's Debug configuration, which (with no
      `PRODUCT_MODULE_NAME` override in `project.pbxproj`) changed the *derived* Swift module name
      to `PratiLekh_Debug` — confirmed directly from the actual built artifact
      (`DerivedData/Build/Products/Debug/PratiLekh_Debug.swiftmodule`), not inferred. The test
      target's imports were never updated to match, so `xcodebuild build-for-testing` failed on
      every single file with "Unable to resolve module dependency: 'FluidVoice_Debug'." Fix:
      mechanical `FluidVoice_Debug` → `PratiLekh_Debug` rename across all 22 occurrences (21 files;
      `AudioHardwareRecoveryTests.swift` had two — see below), including one large
      `#if canImport(FluidVoice_Debug)`-gated test class (`AudioRouteRecoveryIntegrationTests`,
      lines 852–1530) that would otherwise have started silently compiling itself out entirely
      once the module was renamed. No `project.pbxproj` change was needed or made.
    - **Root cause B (previously diagnosed, smaller in scope than first assumed):**
      `AudioHardwareRecoveryTests.swift` alone additionally had a dead
      `#if canImport(FluidVoice_Debug) ... #else @testable import AudioRecoveryTestSupport #endif`
      guard, inherited from upstream commit `0039d64` — `AudioRecoveryTestSupport` is not declared
      anywhere in this repo (`project.pbxproj`, `Package.swift`, or as a source target); Xcode's
      explicit-module dependency scanner appears to require resolving both branches of a
      `#if canImport` guard even though the condition should gracefully evaluate false under
      classic module resolution. Fix: removed the dead conditional, leaving the same unconditional
      `@testable import` all 21 sibling files already use.
    - **Regression discipline:** the mechanical rename shifted alphabetical import order in 9
      files, causing 9 new SwiftLint `sorted_imports` violations (`PratiLekh_Debug` sorts after
      `Foundation`, unlike `FluidVoice_Debug`); all 9 were corrected by hand, re-verified with
      `swiftlint lint --strict` (0 violations across all 21 touched files).
    - **Real runtime evidence obtained (not just compilation):** `xcodebuild build-for-testing`
      now succeeds; the 3 previously-blocked tests
      (`testRawArgumentsPreserveExactTextIncludingUnusualSpacing`,
      `testRawArgumentsPreserveDuplicateKeyForV11Rejection`,
      `testRawArgumentsPreserveWholeNumberFloatForV11Rejection`) all **passed** when actually
      executed, proving: exact raw-argument text (including unusual spacing) survives the real
      `LLMClient` streaming path unchanged; a duplicate `schemaVersion` key survives into
      `rawArguments` and is then correctly rejected by the real
      adapter→parser chain with `.transportParseFailure(.duplicateKey("schemaVersion"))`; a
      whole-number float (`1.0`) survives and is correctly rejected with
      `.transportParseFailure(.invalidFieldType("schemaVersion"))`. A 4th test,
      `testRawArgumentsPreserveExactTextNonStreamingChatCompletions`, was added (not requested by
      name, but within the milestone's explicit allowance to add "one additional focused test" if
      warranted) because all 3 original tests only exercised the streaming Chat-Completions
      delta-accumulation construction site; the new test covers the architecturally distinct
      non-streaming (single-shot, already-complete-JSON) construction site instead of expanding
      into a full 4-site matrix. All 4 pass.
    - **Full-target regression run:** the entire `FluidDictationIntegrationTests` target was run
      (534 tests). 533 passed; the 1 failure
      (`DictationE2ETests.testDictationEndToEnd_whisperTiny_transcribesFixture`, "Insufficient
      memory for Whisper Tiny") is an environmental/sandbox memory constraint loading a real
      Whisper GGUF model, unrelated to this fix or to any Intelligence code, and was left
      untouched. `scripts/test_intelligence_safety.sh`, `scripts/test_legal_language.sh`, all
      other `scripts/test_*.sh`, and `Tests/run_paste_key_cache_tests.sh` all still pass;
      `./build.sh unsigned` still succeeds; `git diff --check` is clean.
    - **Scope discipline:** only `Tests/FluidDictationIntegrationTests/*.swift` files were touched
      (21 files); no `Sources/` file, no `project.pbxproj` entry, and no Intelligence V1.0/V1.1/V1.2
      code or architecture was modified. This is test-infrastructure repair only, per this
      milestone's explicit scope. **Committed** (`b5969ba`, full: `b5969baa5c5382c16740af41522c046c924881f8`)
      — this item is otherwise historical/superseded; see "Intelligence V1.3A–V1.8" above for
      everything since, including the now-frozen addressing contract and its own open risks.
13. **Must NOT be started yet:** wiring any model/provider into production dictation, live
    production inference, audio-aware Intelligence, fine-tuning of any kind, legal-domain quality
    benchmarking, and Intelligence V2 all remain unauthorized — the V1.5 addressing-contract freeze
    (see "Intelligence V1.3A–V1.8" above) was design/documentation only; V1.6 implemented only its
    deterministic addressing layer (resolver + bridge, unwired). The model-facing wire schema/parser,
    insertion and everything downstream remain unstarted. The recognition-tuning branch remains closed — do not
    resume it: no threshold tuning, alias additions, another vocabulary-boosting experiment,
    modifying the three-character compound-length rule, modifying FluidAudio, exposing
    rejected-candidate score structures, a production vocabulary-boosting default, or a Phase 3G.D
    recognition experiment. Also not started: date normalization, punctuation/sentence-boundary
    heuristics, custom-dictionary reconciliation (Slice D), evaluation-framework redesign,
    UI/history work, and Phase 4 — none of these are
    authorized by any evidence gathered so far.
