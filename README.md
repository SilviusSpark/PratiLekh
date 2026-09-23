# PratiLekh

**On-device dictation for Indian courts.**

PratiLekh is a macOS menu-bar dictation app for recording evidence and drafting judgements,
orders, and depositions — a virtual stenographer that transcribes speech locally on your Mac
and is being tuned to recognize Indian legal terminology, Indian personal names, and Indian
place names.

It is a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice), an open-source
voice-to-text dictation app for macOS, adapted for the Indian courtroom setting. See
[**Attribution**](#attribution) below and [`PRATILEKH_PLAN.md`](PRATILEKH_PLAN.md)
for what's changed and what's planned.

> [!IMPORTANT]
> PratiLekh is local-first by design: speech-to-text runs on-device, and analytics/telemetry
> is disabled. AI-assisted formatting can optionally call a cloud provider, but that is
> **off by default** and must be explicitly enabled — appropriate given the confidentiality of
> courtroom evidence and draft judgements. See [Privacy](#privacy) below.

---

## Status

This fork is under active adaptation. Core dictation (on-device speech-to-text, Command Mode,
Write Mode, per-app prompt configuration) works today, inherited from FluidVoice. The
India-specific work — legal-term/name/place vocabulary, document-type formatting for evidence
vs. judgement drafting, courtroom speaker roles, and case metadata — is tracked phase-by-phase
in [`PRATILEKH_PLAN.md`](PRATILEKH_PLAN.md).

---

## Features

- **On-device speech-to-text** — multiple local speech models to choose from depending on
  language coverage, accuracy, and latency needs (see [Supported Models](#supported-models))
- **Command Mode** — control your Mac by voice: launch apps, run shortcuts, trigger system
  actions, and automate workflows without touching the keyboard
- **Write Mode** — write or rewrite text directly in any text field across any app. Select
  text and rewrite it, or dictate new content inline — useful for drafting and revising orders
  or judgements directly in your document editor
- **Live Preview** — real-time transcription overlay so you see words appear as you speak,
  useful for verifying accuracy while recording evidence
- **Custom Dictionary & Vocabulary Boosting** — teach the app specific words, names, and
  phrases so recognition improves over time; the seam being used to seed Indian legal
  terminology, names, and place names (see the plan doc)
- **Per-App / Per-Context Prompt Profiles** — assign different formatting instructions to
  different apps or contexts, so dictation output adapts to whatever you're drafting
- **AI Enhancement (opt-in)** — optional post-processing via a cloud provider (OpenAI, Groq,
  custom endpoint) or a local private AI model, for cleaner, better-formatted transcripts.
  Disabled by default — see [Privacy](#privacy)
- **Audio History** — optional local recording history with budget controls and ZIP export,
  so you can review past dictations without cloud storage
- **Global Hotkey** — instant voice capture from anywhere, no app switching needed
- **Smart Typing** — direct insertion into any app via accessibility APIs for reliable,
  app-independent text entry
- **Adaptive Theming** — light/dark theme that follows your system
- **Local-First** — your voice and text never leave your machine unless you explicitly opt in
  to a cloud AI provider; analytics/telemetry is disabled entirely in this fork

---

## Supported Models

| Model | Best for | Language support | Download size | Hardware |
| --- | --- | --- | --- | --- |
| Nemotron Speech 3.5 — Ultra Fast Low Latency | Streaming-capable multilingual dictation | ~40 languages | ~670 MB | Apple Silicon |
| Nemotron 3.5 Multilingual | Higher-accuracy multilingual dictation | ~40 languages | ~530 MB | Apple Silicon |
| [Parakeet Flash (Beta)](https://huggingface.co/nvidia/parakeet_realtime_eou_120m-v1) | Lowest-latency live English dictation | English | ~250 MB | Apple Silicon |
| Parakeet TDT v3 | Fast default multilingual dictation | [25 languages](#parakeet-tdt-v3-languages) | ~500 MB | Apple Silicon |
| Parakeet TDT v2 | Fastest English-only dictation | English | ~500 MB | Apple Silicon |
| Cohere Transcribe | High-accuracy multilingual dictation | [14 languages](#cohere-transcribe-languages) | ~1.4 GB | Apple Silicon |
| Apple Speech | Zero-download native macOS speech | System languages | Built-in | Apple Silicon + Intel |
| Whisper Tiny / Base / Small / Medium / Large | Broad compatibility, including Intel Macs; currently the best option for Indian-accented English and Hindi | [99 languages](#whisper-language-support) | ~75 MB to ~2.9 GB | Apple Silicon + Intel |

None of these models ship with Indian-legal-specific tuning out of the box — accuracy on
Indian names, places, and legal terms depends on the custom vocabulary/dictionary work
described in [`PRATILEKH_PLAN.md`](PRATILEKH_PLAN.md). Whisper is currently the
recommended starting point for Indian-accented English dictation.

### Parakeet TDT v3 Languages

Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian, Spanish, Swedish, and Ukrainian.

### Cohere Transcribe Languages

English, French, German, Italian, Spanish, Portuguese, Greek, Dutch, Polish, Mandarin, Japanese, Korean, Vietnamese, and Arabic.

### Whisper Language Support

Whisper supports up to 99 languages, including Hindi, depending on the model size you choose.

---

## Quick Start

PratiLekh is not currently published as a signed release or Homebrew cask — build it from
source (see [Building from Source](#building-from-source) below).

1. **Build and run** the app from Xcode or via `./build.sh`.
2. **Grant permissions** — PratiLekh will ask for microphone and accessibility access. Both
   are required for dictation and typing into other apps.
3. **Set your hotkey** — pick a global hotkey in settings that triggers voice capture from
   anywhere.
4. **Go through onboarding** — choose your voice model. Whisper (Medium or Large) is the
   recommended starting point for Indian-accented English dictation.
5. **Build out your custom dictionary** — add case-relevant names, places, and legal terms as
   you encounter recognition gaps (`Settings → Custom Dictionary`).
6. **(Optional) Enable AI enhancement** — only if you're comfortable with the provider's data
   handling for your use case. Off by default; see [Privacy](#privacy).

---

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon Mac for most models
- Intel Macs supported via Whisper and Apple Speech models
- ~1 GB disk space for a voice model
- Microphone access
- Accessibility permissions for typing

---

## Building from Source

```bash
git clone https://github.com/SilviusSpark/PratiLekh.git
cd PratiLekh
open PratiLekh.xcodeproj
```

Build and run in Xcode. All dependencies are managed via Swift Package Manager.

Run a signed Debug build using the script:

```bash
./build.sh
```

This needs an Apple Development signing identity for your own Team ID
(`Xcode → Settings → Accounts`, then `Manage Certificates`). A free Personal Team is
sufficient for local development. See `./build.sh` output for guidance if none is found.

The signed build is written to `DerivedData/Build/Products/Debug/PratiLekh Debug.app`.
Keep launching that product after each rebuild so macOS can preserve its Accessibility
authorization.

For CI, or to build without a signing identity at all:

```bash
./build.sh unsigned
```

Unsigned builds are tied to a specific executable version and may require Accessibility
permission to be removed and granted again after rebuilding.

### Run Integration Tests

```bash
xcodebuild test -project PratiLekh.xcodeproj -scheme PratiLekh -destination 'platform=macOS'
```

CI-equivalent unsigned run:

```bash
xcodebuild test -project PratiLekh.xcodeproj -scheme PratiLekh -destination 'platform=macOS' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### Formatting & Linting

```bash
./scripts/format-and-lint.sh
```

Runs SwiftFormat then `swiftlint --strict` (auto-installs both via Homebrew if missing).

---

## Development Notes

- See [`CLAUDE.md`](CLAUDE.md) for the architecture map, build/test conventions, and
  fork-specific workflow rules (useful context whether you're a human contributor or an AI
  coding assistant working in this repo).
- See [`PRATILEKH_PLAN.md`](PRATILEKH_PLAN.md) for the phased roadmap and design
  decisions made so far.
- `DEVELOPMENT_TEAM` in the Xcode project is set to whoever last configured signing locally —
  don't commit changes to it. If you have certificates for multiple teams, select one without
  changing the project by running `PRATILEKH_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./build.sh`.
- Optional pre-commit hook to guard against accidentally committing a different team ID:
  ```bash
  cp scripts/check-team-id.sh .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
  ```
  Update `OFFICIAL_TEAM_ID` in that script to your own team ID first.

---

## Privacy

PratiLekh is **local-first**. Speech-to-text runs entirely on-device. Your voice, audio, and
transcribed text never leave your machine unless you explicitly enable a cloud AI provider for
post-processing — which is off by default.

**Analytics/telemetry is disabled entirely in this fork** (the upstream PostHog integration
point still exists in code but its key is cleared, so no events are ever sent — see
`Sources/Fluid/Analytics/AnalyticsConfig.swift`).

**Never collected, regardless of settings:**

- Voice, raw audio, or transcribed text
- Selected text, prompts, or AI responses
- Terminal commands, window titles, file paths, clipboard, or typed content
- Any personal or private information

---

## Attribution

PratiLekh is a fork of [FluidVoice](https://github.com/altic-dev/FluidVoice) by
[altic-dev](https://github.com/altic-dev), licensed under the
[GNU General Public License, Version 3.0 (GPLv3)](LICENSE). Substantial credit for the core
dictation engine, on-device speech models integration, Command Mode, Write Mode, and overall
app architecture belongs to the upstream FluidVoice project and its contributors.

"Fluid Intelligence," referenced in some upstream code paths, is a separate, privately
maintained local AI runtime belonging to the upstream project — it is not part of this fork's
own code and this fork does not extend or redistribute it.

## License

This project is licensed under the [GNU General Public License, Version 3.0 (GPLv3)](LICENSE),
inherited from the upstream FluidVoice project.
