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

Local `main` is 13 commits ahead of `origin/main`, 0 behind, nothing pushed. Verify current
ahead/behind state with Git rather than relying on this document.

**Phase 3 is not complete as a whole.** 3C+3C.1 is the committed first checkpoint (two rule
families only). **Phase 3D Slices A+B (committed, `0abf627`)** live-activate that normalization at one
`ContentView` seam (see below); recognition boosting, custom-dictionary reconciliation and AI
protection are not done. **Phase 3F.A (committed, `18313d7`)** adds fail-closed safety to the
statutory-number grammar; **Phase 3F.B (committed, `89a2846`)** adds the bounded grouped-number
grammar itself — see "Phase 3F" below. Phase 4 has not begun.
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

For (1) and (2): both are upstream of the legal-normalization boundary this evaluation can
currently observe. Do not attribute either specifically to the ASR provider, the custom
dictionary, or spoken-punctuation processing — that attribution is not observable from
`postASRDeterministic` alone.

**Phase 3F status:** 3F.A — implemented, committed, **and real-audio validated**. 3F.B —
implemented, committed, **and real-audio validated** against the fixed N01–N12 corpus. Phase
3F eliminated the known deterministic statutory-number corruptions targeted by the phase and
converted the tested unsupported/ambiguous forms to fail-closed behavior. Remaining failures in
the fixed real-audio sample are either upstream of legal normalization or deliberately
unsupported. **Phase 3F does not universally solve statutory dictation** — it does not touch
statute-word recognition, `hundred`, dates, or punctuation.

## Evaluation framework (Phase 3E.1, `Evaluation/`)

Standalone tooling to measure where dictation fails, stage by stage. **Governing principle: the
reference is what the judge dictated, not what an evaluator or model thinks was intended; never
reward substituting a "better" provision/statute/fact/date/amount.** Synthetic references live in
`Evaluation/References/synthetic/*.json`; **audio (even of synthetic scripts) and all run results
stay outside Git** (the runner refuses in-repo `--out/--audio/--text-dir`). Stages are
`postASRDeterministic` (`/v1/transcribe` output: after fillers, custom dictionary, spoken
punctuation — NOT raw ASR; raw provider text is not observable) and `legalNormalized`. Metrics are
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
2. **`postASRDeterministic` text** — useful, but not raw provider output; it cannot currently
   distinguish provider decoding from filler removal, custom dictionary, or spoken-punctuation
   formatting, all of which run before this observable point.
3. **Deterministic offline probes** (e.g. the Phase 3F.B N01–N12 result above) — prove what the
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
   real-audio validated), 3F.B (bounded grouped-number grammar, real-audio validated), and the
   post-3F N01–N12 real-audio validation itself (see "Phase 3F" above for the full findings).
2. **Exact current `HEAD`:** `785921c7a64f1e1769684891ff02e9d85dd32586` ("Update project handoff
   after Phase 3F"), branch `main`, 13 ahead of `origin/main`/0 behind, nothing pushed. Immediately
   preceded by `89a2846f3ee3c773adef7f68d67e72629958f915` (Phase 3F.B), which is immediately
   preceded by `18313d7a52d344c6ccd09fd02eb2ed776681290a` (Phase 3F.A).
3. **No pending production/test change set.** Phase 3F.A and 3F.B are both fully committed; no
   Swift source, test, or fixture changes are outstanding. Verify with `git status`/`git log`
   before trusting this if time has passed.
4. **What 3F.A changed:** see "Phase 3F" above — `hundred`-continuation fail-closed decline;
   fragmented-statute/suffix-ambiguity fail-closed decline. No grammar expansion. Now confirmed on
   real audio (N10, N04/N12), not just unit tests.
5. **What 3F.B changed:** the bounded grouped-number grammar itself (see "Phase 3F" above) —
   `[leading digit] + tens-word + [trailing digit]`, combined arithmetically. Now confirmed on real
   audio: 5/5 previously-corrupted grouped-number cases in the fixed N01–N12 corpus fixed, 0
   regressions.
6. **Real-audio validation result (complete, not just deterministic offline):** corrupted critical
   tokens 7→0, incorrect transformations 3→0, 0 regressions, comparing the identical N01–N12
   recordings before (`cefc209`) and after (`785921c`) Phase 3F — see "Phase 3F" above for the full
   case-by-case breakdown and the private result-directory paths.
7. **Most important open evidence areas (none yet investigated, no solution selected):** (a)
   statute-word recognition — `IPC` observed as `it c` in several N-series takes, upstream of the
   observable legal-normalization boundary; (b) `BNSS` observed as fragmented letters (`B and S
   S`) in some takes, same observability limit; (c) date/year phrasing reliability — no repeated
   advantage for either phrasing established across 15 real-audio trials total; (d) punctuation —
   strongly reproduced comma-for-internal-boundary pattern (22/22 across two rounds), provider-
   vs-app attribution still unresolved; (e) `five hundred six`-style `hundred` dictation remains
   deliberately unsupported (now fails safely, not corrupted) — whether to expand the grammar to
   cover it is an open product question, not yet decided.
8. **Exact immediate next action:** none of the above is pre-selected. The next architectural
   decision is to choose, from the accumulated Phase 3E/3F evidence (this file's "Phase 3F",
   "Evaluation framework", "Three layers of evidence" and "Diagnostic lessons" sections), among:
   improving observability into upstream statute recognition, date/year handling, sentence-boundary
   punctuation, or deliberately expanding the unsupported number grammar (e.g. `hundred`) if
   product requirements justify it. That choice needs explicit review and approval before any
   implementation starts — do not begin any of these now.
9. **Must NOT be started yet:** date normalization, punctuation/sentence-boundary heuristics,
   recognition boosting (Slice C), custom-dictionary reconciliation (Slice D), AI protection
   (Slice E), raw-ASR instrumentation, expanding the `hundred`/number grammar, another
   normalization family, evaluation-framework redesign, UI/history work, Phase 4 — none of these
   are authorized by any evidence gathered so far.
