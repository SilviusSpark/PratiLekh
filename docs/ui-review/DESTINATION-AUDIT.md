# PratiLekh: destination and compatibility audit (updated through milestone 2)

Source inspection on 1 October 2026. No external feedback was submitted, update installed, or destination redirected. Links are traced from current code; availability and suitability of remote services have not been verified.

| Surface | Current destination / behavior | Review consequence |
|---|---|---|
| Shell Help | `https://docs.altic.dev/` | Upstream documentation. Help accessibility hint explicitly identifies it as upstream. A supported PratiLekh help destination needs a product decision. |
| Shell and Settings issue button | `https://github.com/altic-dev/Fluid-oss/issues/new/choose` | Opens upstream issue reporting. Needs a PratiLekh support policy before redirection. |
| What's New | GitHub release API and releases page for `altic-dev/Fluid-oss` | Renamed shell entry still leads to inherited release notes, not PratiLekh release history. This is a remaining defect outside milestone 1. |
| Feedback | `https://altic.dev/api/fluid/feedback` | Sends entered email and feedback; optionally app/system details and recent logs. Not equivalent to disabled analytics. Needs a supported feedback destination and privacy review. No submissions made in verification. |
| History Report issue | `https://altic.dev/api/fluid/examples` | POSTs reviewed raw text, processed text, model identifier and comments. The sheet now explicitly names the upstream destination and asks for review/removal of sensitive information. No anonymity guarantee or claim that this improves a PratiLekh model. Endpoint, transport and submission behavior unchanged; no example sent. |
| Feedback support links | Upstream repository and `github.com/sponsors/altic-dev` | Upstream sponsorship/repository promotion remains. |
| Automatic and manual updates | `altic-dev/Fluid-oss` releases in AppDelegate and MenuBarManager | `AutoUpdateCheckEnabled` defaults to true. Checks run at launch and hourly. Installer uses upstream approved signing teams; do not substitute a feed or signing policy casually. A PratiLekh release policy is required before distribution. No update behavior changed. |
| Settings releases / rollback | Upstream releases page; backup restore/relaunch | Inherited UI strings remain. Restore is consequential and was not exercised. |
| Accessibility drag target | Current `Bundle.main.bundleURL` first, then `/Applications/FluidVoice.app` only when current bundle is not an existing `.app` | Normal packaged PratiLekh launches use their own bundle. The legacy fallback may select an unrelated upstream installation in unusual launch contexts. Left unchanged pending a focused path fix. |
| Analytics | Info.plist PostHog key is empty; AnalyticsConfig consumes that key | Inherited Settings telemetry explanation is obsolete. Feedback and optional cloud processing remain separate outbound routes. No blanket “nothing leaves your Mac” copy added. |

## Remaining branding inventory

`remaining-branding.json` records every case-insensitive source match for FluidVoice, Fluid Voice, Fluid-oss, and Fluid Intelligence in Swift, JSON, and plist files under Sources/Fluid. It is a location inventory, not evidence that every match is reachable product UI.

- **Remaining product defects:** Settings, Feedback, Changelog, update/rollback alerts, service error/recovery messages, dictionary export/error messages, pronunciation overlay, provider badges, login-item messages, Local AI management surfaces. Their screen rollout is deferred.
- **Compatibility retained:** UserDefaults keys, Keychain service `com.fluidvoice.provider-api-keys`, migrations, internal Swift/type names, import format recognition and legacy metadata. Do not mechanically replace these.
- **Third-party identity retained:** dependencies and private upstream runtime identifiers. Existing Local AI onboarding copy names the functional surface “Local AI”; the external runtime itself is not PratiLekh Intelligence.
- **Attribution retained:** README, GPL license and source attribution. No transcript, imported content, genuine source-app metadata, evaluation corpus, normalization or Intelligence contract was edited.
- **Assets:** new app/menu bar icons and editable document/pen SVG are supplied. Unused inherited BrandWordmark and legacy FluidIcon variants remain inventoried for later cleanup; provider artwork is third-party identity.

## Product decisions

1. Supported help, issues, feedback and release-notes destinations.
2. Whether upstream update checks should be disabled pending a signed PratiLekh release policy, and the supported signing/release channels.
3. Retention or removal of upstream sponsorship and optional log attachment flows.

## Milestone 2 branding audit

The recording workspace and floating bottom overlay use the shared palette and document/pen identity. History's product-owned success alert now names PratiLekh. The optional-AI footer has Back and Skip for now; provider setup stays in its card. “On-device” was removed from the floating overlay's formatting menu heading because menu choice alone cannot establish the active processing route. No processing-location badge was added without a session-specific verified route.

The raw inventory is refreshed to current source lines. Remaining product-owned branding, service errors, Settings, update/rollback UI, Feedback and inherited promotion are still outside this rollout. Protected persistence/Keychain identifiers, migrations, formats, attribution, transcript contents and genuine historical source-app names remain intact. The legacy installation fallback and all upstream feeds/destinations are unchanged.
