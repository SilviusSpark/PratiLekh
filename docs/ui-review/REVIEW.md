# Milestone 1 review checkpoint

**Updated supervisor revisions:** see [REVISION-REVIEW.md](REVISION-REVIEW.md) for the current implementation, exact-size screenshots and acceptance results. The following records the initial checkpoint.

Branch: `codex/ink-paper-milestone`. Local changes only; no commit, push, PR, release or distribution. Specification: supplied PRATILEKH_UI_UX_BRIEF.md, read directly from the owner's provided path.

## Implemented

- Shared light/dark warm-paper and ink surfaces, deep teal accents, system typography and script fallback, 4/8/12/16/24/32 spacing, flatter bordered cards and primary buttons.
- Original document-and-pen mark: SwiftUI vector, editable SVG, macOS app-icon sizes, monochrome 18pt menu-bar template at 1x/2x/3x. Small menu and app-icon assets visually inspected.
- Sidebar wordmark and pale selection; Configure / Use / Activity / Help destinations retained; quiet fixed Help/Settings footer; What's New label. Navigation uses native buttons in a scrolling sidebar and existing navigation handler. Keyboard traversal needs further audit against the former List behavior.
- Welcome headline and legal-drafting tagline, four-step checklist, next-incomplete-step primary action and Try dictation after setup. Completed rows remain readable rather than inheriting disabled-button dimming.
- Onboarding adapted to both appearances; permissions, shortcut, language/model choice, practice, and optional AI behavior retained. Onboarding presents actual model names and local processing; removes inherited percentage accuracy/speed presentation and generated upstream branding badge.
- Local AI names the existing optional runtime surface without activating PratiLekh Intelligence. Help's tooltip/hint explicitly says upstream documentation; destination unchanged.
- Practice text has a descriptive accessibility label, 16pt system font and line spacing. No pipeline, migration, persistence key, Keychain identifier or stored content edited.

The inherited Cyan accent option now uses adaptive brand teal. Other explicitly selected accent options remain supported; no stored preference is renamed or rewritten for the rebrand. Shared theme/component changes naturally affect their existing consumers outside these screens; individual screen rollout is paused.

## Evidence

All PNGs in this folder are captures of the running unsigned Debug application, not mockups. Most captures are 2362×1400 pixels (1181×700 points at 2x). Screens with scrollable content may show only their initial viewport. They are not evidence of exact minimum-width acceptance.

| Screen | Light | Dark |
|---|---|---|
| Shell and welcome | [light](welcome-light.png) | [dark](welcome-dark.png) |
| Onboarding landing | [light](onboarding-light.png) | [dark](onboarding-dark.png) |
| Languages | [light](languages-light.png) | [dark](languages-dark.png) |
| Speech models | [light](models-light.png) | [dark](models-dark.png) |
| Permissions | [light](permissions-light.png) | [dark](permissions-dark.png) |
| Practice | [light](practice-light.png) | [dark](practice-dark.png) |
| Optional AI | [light](optional-ai-light.png) | [dark](optional-ai-dark.png) |

[Hindi and long-text capture](hindi-long-text.png) uses synthetic visual-test text entered directly in the welcome editor. This tests text rendering and scrolling, not Hindi recognition or legal-language processing. The sample was cleared; no recording or cloud call was made.

## Verification results

- `./build.sh unsigned`: final build succeeded.
- Scoped SwiftLint: 0 violations across the shared Theme folder and changed UI sources.
- `git diff --check`: clean.
- Existing SettingsNavigationStateTests: 18 passed, 0 failures.
- All 21 existing `scripts/test_*.sh` plus paste-key cache runner attempted: 20 passed, 2 failed. Failures reproduce identically on an archived, unchanged HEAD:
  - autonomous-edit-policy investigation: fresh.ambiguousRemaining = 8, pinned expectation 10.
  - independent-protection investigation: strat.development.category.digitEscaped = 3, pinned expectation 15.
  No evidence, expectation or processing code changed to make these pass.
- Running app inspected in light and dark. Existing microphone/accessibility authorization became ready after initialization; no permissions revoked or re-granted. Setup state temporarily reset for UI verification, then original onboarding completed/current-step/skip/validation/language values restored. Original System appearance restored.
- Return/default-action onboarding navigation works. Native focus ring observed on onboarding Back; accessibility tree exposes named setup, model, microphone and sidebar controls. Full VoiceOver traversal and all keyboard routes are not certified.
- Calculated solid-token contrast: light primary/window 13.48:1, secondary/card 6.04:1, accent/card 6.32:1; dark primary/card 13.27:1, secondary/card 7.40:1, accent/card 7.90:1. This does not certify every rendered hover, disabled, semantic-state or focus pairing.

## Outstanding acceptance checks

- Exact main 800×500 and onboarding 940×700 dimensions: native resize attempts did not change the captured window; minimum-width acceptance remains unverified.
- Full keyboard navigation parity, VoiceOver traversal, Increase Contrast and Reduce Motion under actual system settings; exhaustive state contrast.
- Microphone-denied, download/error/loading, unavailable-device and local-runtime-installed onboarding branches not exhaustively exercised. No model downloaded/deleted or provider enabled for screenshots.
- Menu-bar icon asset legibility checked at native 18px; actual menu-bar OS rendering and release-build OS-facing names require further verification. Debug window/permission names intentionally reflect the actual Debug bundle.
- Existing example AI transformations are inherited illustrations, not evidence of legal correction accuracy.
- Global zero-branding acceptance is deferred: reachable Settings, Feedback, release notes, service messages and other screens still contain product-owned upstream references. See the destination audit and raw location inventory.

## Decisions for the owner

Choose supported help, issue, feedback and release-note destinations, and a signed PratiLekh update policy. Upstream automatic checks currently default on and use upstream release/signing policy. This milestone does not redirect or enable any updater. Decide whether to disable inherited checks in a separately authorized change pending PratiLekh releases.

Further screen rollout is paused for supervisor feedback through the product owner.
