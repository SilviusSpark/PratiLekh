# Supervisor revision checkpoint

Local branch: `codex/ink-paper-milestone`. Further screen rollout remains paused. No processing, persistence, updater, corpus or historical expectation changes; no commit, push or distribution.

## Changes

- Onboarding navigation has a fixed, independent footer. Model and optional-AI content scroll within the remaining space with 32pt bottom clearance. Model headings and cards are compact; the default cards and their controls fit at 940×700. Expanded models scroll to the final row above navigation.
- “Choose your language” uses the shared teal primary button. Welcome presents a primary setup action only while setup is incomplete. “Go to practice” scrolls to the practice area; “Start Recording” is the recording action. No duplicated “Try dictation” entry points.
- Completed setup rows have one check indicator, a short task name, compact padding, and a single accessible completion value. Pending rows retain guidance and an action.
- Active models use a readable status, not a disabled button. Delete is a quiet borderless action below a divider for both active and downloaded inactive models.
- “Optional AI formatting” uses two labeled illustrative punctuation/paragraph examples. Every word and number is preserved, with case/punctuation only changing. Cloud text leaves the device when enabled; a configured local endpoint processes text on its host. The built-in AI branch describes local processing. No provider was enabled or contacted during review.
- Legacy Apple Speech is labeled “may use Apple’s servers”: `AppleSpeechProvider.swift:84` sets `requiresOnDeviceRecognition = false`. This corrects copy without changing recognition behavior. The newer Apple Speech route and downloaded local models retain on-device labels.
- Sidebar buttons support Tab, plain Up/Down focus movement, and native activation. Modified arrow shortcuts are ignored by this handler so VoiceOver can receive them. Disabled primary buttons use readable secondary text on a neutral, outlined surface.

## Updated evidence

These are screenshots of the actual compiled application, not mockups. Sizes describe the full macOS window, including title bar: main 800×500 points (1600×1000 PNG); onboarding 940×700 points (1880×1400 PNG). A DEBUG-only opt-in launch setting sizes the real window after macOS window restoration. No production sizing behavior changes.

| Screen | Light | Dark |
| --- | --- | --- |
| Welcome, exact minimum | [Light](welcome-light-800x500.png) | [Dark](welcome-dark-800x500.png) |
| Landing, shared primary | [Light](onboarding-light-940x700.png) | [Dark, Increase Contrast](onboarding-dark-940x700-contrast.png) |
| Compact models | [Light](models-light-940x700.png) | [Dark](models-dark-940x700.png) |
| Optional AI, top | [Light](optional-ai-light-940x700-top.png) | [Dark](optional-ai-dark-940x700-top.png) |
| Optional AI, scroll bottom | [Light](optional-ai-light-940x700-bottom.png) | [Dark](optional-ai-dark-940x700-bottom.png) |
| Increase Contrast, welcome | [Light](welcome-light-800x500-contrast.png) | [Dark](welcome-dark-800x500-contrast.png) |

Additional running evidence: [expanded models at scroll bottom](models-expanded-bottom-940x700.png), [Hindi and long text at 800×500](welcome-practice-hindi-800x500.png). Text was synthetic, entered directly in the practice editor, then cleared; it was not processed or saved as a transcript.

**Synthetic preview evidence:** [light fixture](fixture-states-light.png), [dark fixture](fixture-states-dark.png). These are screenshots of a DEBUG-only fixture hosted in the application, visibly labeled synthetic. It reuses setup rows, the microphone panel and shared buttons for denied permission, loading, unavailable microphone, error text and disabled/primary states. Actions are no-ops. They verify presentation, not real permission denial, downloads, recovery or processing. The error sentence is fixture copy, not a simulated live service error alert.

The earlier unsuffixed screenshot set belongs to the initial milestone and is superseded for these revised surfaces.

## Verification

- Unsigned application build: passed. Existing compiler warnings include dependency framework symlink diagnostics; build succeeds.
- Scoped strict SwiftLint: 14 files, zero violations. Whitespace diff check: passed.
- Focused SettingsNavigationStateTests: 18 passed, zero failures. This run includes the completed layout/style changes; the final modifier-mask adjustment and legacy privacy string were subsequently built and checked in the running app.
- Exact minimum layouts: inspected both appearances. Welcome/practice and sidebar scroll independently, with fixed Help/Settings. Onboarding navigation remains fixed while optional AI and expanded models scroll. Initial optional-AI content can extend beyond the viewport; scrolling reveals all provider controls and the bottom footnote with clearance.
- Hindi: 660 characters of repeated synthetic Devanagari at 800×500, readable wrapping and independent editor scrolling; Copy/Clear controls reachable. Text cleared afterward.
- Keyboard: landing Return, onboarding Tab/Back focus, sidebar plain arrows/Tab/native activation checked. Modified arrow commands excluded from custom sidebar handling. Full keyboard traversal across unrelated screens is outside this checkpoint.
- Reduce Motion: macOS switch temporarily enabled during onboarding review. Landing, model expansion and optional-AI navigation exercised; identity surfaces avoid moving glow/scale effects. Native indeterminate progress remains a system control. Original switch restored to off.
- Increase Contrast: macOS switch temporarily enabled and light/dark welcome plus dark landing/models inspected. Primary, selected and static completion states remain readable; disabled state additionally inspected in fixtures. Original contrast setting restored to off. This is a visual acceptance check, not a full contrast certification for every inherited control.
- Accessibility: tree exposes each completed task and its completion value separately, pending actions, model status, sidebar selection, text-entry label and disabled buttons. VoiceOver was temporarily enabled and its process confirmed running. Modified-key traversal was attempted, but the automation surface did not provide reliable spoken feedback or a distinct VoiceOver cursor. **Full spoken VoiceOver traversal remains unverified and requires a human pass.** VoiceOver restored to off.
- No OS microphone/accessibility permissions were revoked or granted. The final unsigned review build reports text-insertion access unavailable, so welcome includes its setup action; screenshots reflect that actual state. Permission-denied/loading/error combinations use the labeled fixture.
- Saved onboarding completion/progress and original system theme restored after capture. No model download, activation, deletion, recording, feedback submission or provider setup was performed.

## Baseline investigations preserved

The initial milestone attempted all 21 `scripts/test_*.sh` runners plus the paste-key runner: 20 passed, two failed. Both failures were reproduced from unchanged HEAD in an isolated baseline archive:

- Autonomous edit policy investigation: `fresh.ambiguousRemaining` is 8; pinned expectation 10.
- Independent protection investigation: `strat.development.category.digitEscaped` is 3; pinned expectation 15.

No investigation code, historical assertions or corpora were altered to make these pass. This copy/layout revision does not rerun or reinterpret those historical results.

## Remaining decisions and scope

The [destination audit](DESTINATION-AUDIT.md) remains applicable: upstream help, issue, feedback, release/changelog and automatic/manual updater destinations are unchanged. The `/Applications/FluidVoice.app` fallback remains unchanged; a normal app bundle path takes precedence. Updater policy and PratiLekh-owned help/feedback destinations require the owner’s decision. The [remaining-branding inventory](remaining-branding.json) records broader product copy and protected internal/historical references. No further recording/history/settings rollout is included.

Changed Swift files for this revision: `ContentView.swift`, `UI/WelcomeView.swift`, `UI/OnboardingAIEnhancementStepView.swift`, `Theme/NativeButtonStyles.swift`, `Theme/Components/SetupComponents.swift`, `Theme/Components/OnboardingComponents.swift`, `Theme/Components/WindowSizingComponents.swift`. Review documents and the screenshots above are updated/additional evidence.
