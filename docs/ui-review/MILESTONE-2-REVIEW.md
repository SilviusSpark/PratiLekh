# PratiLekh milestone 2 review

1 October 2026. Local, unsigned SwiftUI implementation on `codex/ink-paper-milestone`. Accepted milestone 1 work is preserved. Nothing was pushed, published, distributed or redirected. Further screen rollout is paused at this checkpoint.

## Changes

- Recording uses the shared primary action, typography and ink/paper surfaces. A single status identifies ready, listening, final transcription, subsequent text processing, cancellation, error, model loading or an unavailable model. Stop transcribes; Cancel uses the existing discard handler. The floating overlay's Stop uses the same output-route resolver as the existing shortcut, including onboarding's sandbox. Existing shortcuts and capture/delivery algorithms remain intact.
- The floating bottom overlay and its menus resolve light/dark appearance from the existing preference. Teal waveforms, a restrained border and the document/pen mark replace black/white decorative chrome. Medium/large/small overlays have text actions; the compact pill has separate, labeled Stop and Cancel icons and expands from 100 to 140 points to fit them. The rotating border is removed; Reduce Motion suppresses the processing sweep and dismissal movement.
- History keeps its native split, search, comparison, playback, copy, export and deletion wiring. Container-constrained widths allow the main window to remain exactly 800×500. Transcript text is 16-point system type with readable Hindi fallback; selection and added-text highlights use restrained teal. Metadata adapts to available width, empty processing groups are omitted, Copy is primary, and deletion remains behind a separate menu/divider or explicit clear confirmation.
- Optional-AI setup has one provider action in its card, with Back and Skip for now in the footer. The content clips within its viewport and has 48 points of bottom clearance, allowing the hero mark to scroll entirely away.
- The history feedback sheet explicitly discloses the upstream service and reviewed payload instead of claiming anonymity or improvement of “our model.” The success alert and one model-recovery display string name PratiLekh. No endpoint, feed, updater policy or processing behavior changed. No location badge is shown without a session-specific verified route; the formatting menu heading no longer makes an on-device claim.

## Screenshot evidence

These are captures of the running built application, not mockups. Files containing `synthetic` show debug-only, in-memory state/data fixtures. They are not evidence of successful audio capture, transcription, cloud processing, permission denial or provider failure. Native floating-panel captures visibly say “Synthetic overlay state.” Embedded overlay captures are separately named; the native panel was captured after closing the main window. Onboarding examples remain explicitly illustrative.

| Surface | Light | Dark |
|---|---|---|
| Real ready recording workspace, 800×500 | [Light](m2-recording-ready-light-800x500-live.png) | [Dark](m2-recording-ready-dark-800x500-live.png) |
| Listening controls, synthetic, 800×500 | [Light](m2-recording-listening-light-800x500-synthetic.png) | [Dark](m2-recording-listening-dark-800x500-synthetic.png) |
| Actual floating panel, synthetic listening | [Light](m2-overlay-floating-light-synthetic.png) | [Dark](m2-overlay-floating-dark-synthetic.png) |
| History comparison, synthetic, 800×500 | [Light](m2-history-light-800x500-synthetic.png) | [Dark](m2-history-dark-800x500-synthetic.png) |
| Hindi history, synthetic, 800×500 | [Light](m2-history-hindi-light-800x500-synthetic.png) | [Dark](m2-history-hindi-dark-800x500-synthetic.png) |
| History error fallback, synthetic, 800×500 | [Light](m2-history-error-light-800x500-synthetic.png) | [Dark](m2-history-error-dark-800x500-synthetic.png) |
| Optional AI scroll bottom, 940×700 | [Light](m2-optional-ai-light-940x700-bottom.png) | [Dark](m2-optional-ai-dark-940x700-bottom.png) |

[Complete screenshot inventory](MILESTONE-2-SCREENSHOTS.md) includes ready/listening/transcribing/processing/cancelled/permission-error/loading fixtures in both appearances, long bilingual text, contrast checks, compact overlay, empty search and onboarding top views. Minimum-window images are 1600×1000 and 1880×1400 pixels at 2× display scale. Captures were re-encoded as PNG without cropping, compositing or retouching.

## Verification

- Final unsigned application build: passed; compiler/dependency warnings remain. Log: `/private/tmp/pratilekh-m2-build.log`.
- Strict lint of the eight touched UI files: zero violations. `git diff --check`: passed. ASRService has only one literal display-copy replacement; its algorithms were not edited.
- History presentation checks: all four groups passed (final/raw/empty copy semantics and immutable entries; audio availability and cancellation; Unicode/punctuation/bounded comparison; model display IDs and round trips). Log: `/private/tmp/pratilekh-m2-history-tests.log`.
- Isolated history persistence boundary executable: all nine groups passed, including 8,400-entry migration, exact round trips, loading/error/retry, deletion, late audio, restart, stale legacy data, rapid writes and stats boundaries. It used temporary files and a unique preference suite, not the user's history. Log: `/private/tmp/pratilekh-m2-history-boundary.log`.
- Running UI: exact main 800×500 and onboarding 940×700 layouts; history search/no-results, selection, comparison toggle and metadata scroll reachability; 1,740-character English/Hindi transcript to its end; real ready recording controls; synthetic primary/selected/disabled/error/loading states; compact native panel fit; optional-AI setup/Back/Skip keyboard reachability and clean mark clearance. Native sidebar Up/Down and Return verified again. After explicit focus stops were added, Tab reaches Start recording in the real app without activating it; the empty practice field was verified and cleared.
- Reduce Motion and Increase Contrast were temporarily enabled in macOS and inspected on long history and compact overlay, then both restored to off. The processing-sweep suppression is also verified in source; a fixture is not proof of live audio animation timing.
- Original onboarding progress, appearance and saved window preferences restored. No recording was started, permission changed, model downloaded, transcript deleted or feedback sent during review.

## Limits and retained failures

**Full spoken VoiceOver traversal remains unverified until a reliable human pass is completed.** Main-window fixture accessibility exposes distinct Stop/Cancel labels and state values. Native nonactivating-panel automation exposes only a dialog container; that is not a VoiceOver traversal pass. Live capture/stop/cancel timing, spoken shortcut activation, actual audio playback/export and destructive production-history operations were not exercised. Their existing wiring remains in place; presentation and persistence tests cover their underlying value/data boundaries, not every interaction.

The first minimum-size history attempts exposed an AppKit constraint loop when the native split tried to expand the window. It was corrected by constraining the split to its container and reverified in running captures. A Tab check under default macOS navigation reached the practice editor before the recording action; explicit focus stops were added to recording buttons. The final Tab check passes and has a real-app focus screenshot; no practice text from the check was saved to history.

The prior baseline investigation failures remain unchanged and documented: autonomous edit-policy `fresh.ambiguousRemaining` was 8 versus expected 10; independent-protection `strat.development.category.digitEscaped` was 3 versus expected 15. Both were reproduced on unchanged HEAD during milestone 1. No processing code or historical expectations were altered to make them pass. See [revision baseline results](REVISION-REVIEW.md).

## Files and remaining decisions

Milestone 2 touches `UI/RecordingView.swift`, `UI/WelcomeView.swift`, `UI/TranscriptionHistoryView.swift`, `UI/HistoryTextComparisonView.swift`, `UI/OnboardingAIEnhancementStepView.swift`, `Views/BottomOverlayView.swift`, `Views/NotchContentViews.swift`, and `ContentView.swift`. `Services/ASRService.swift` changes only the product name in one recovery message. Debug review cases are compiled out of release builds. Documentation and native screenshot artifacts accompany the changes.

[Updated branding/destination audit](DESTINATION-AUDIT.md) and [raw source inventory](remaining-branding.json) retain protected identifiers, historical/third-party identity and attribution. Newly inventoried history reporting posts reviewed raw/final text, model name and comments to `https://altic.dev/api/fluid/examples`. Supported PratiLekh help, issues, feedback, release notes and signed updater policy remain product decisions outside this milestone. `/Applications/FluidVoice.app` remains the unusual-launch fallback; normal packaged launches use the current bundle. Other screen branding is deferred, and stored transcripts and genuine source-app metadata are unchanged.

An unrelated untracked Intelligence evaluation review document appeared during this UI session. It was left untouched and is excluded from the milestone 2 file list.
