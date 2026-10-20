# Migration Verification — all must pass before cutover

## 0. Source-machine baseline procedure (run on the old Mac first; results below)
B1 `git status --porcelain` and `git rev-parse HEAD` before and after (must be identical → proves no mutation of tracked/untracked evidence). B2 Run every `scripts/test_*.sh`, `scripts/check_*.sh`, `scripts/verify_*.sh`, `Tests/run_*.sh` (none start a model; the `*_run.sh` live runners and `eval_run.sh` are excluded). B3 `./build.sh unsigned`. B4 Record exit code per script. Known/expected failures: the two superseded V1.12/V1.14 investigation scripts fail their own pinned preconditions (documented in CLAUDE.md V1.16); `testDictationEndToEnd_whisperTiny…` is an 8 GB memory failure (XCTest target, not run in B2). Mini results are compared to this table, not to 'all green'.

Environment verification only; passing authorizes **no** new Intelligence experiment.
| ID | Check | Pass criterion |
|---|---|---|
| V-1 | Hardware | `uname -m`=arm64; macOS/Xcode versions recorded; any M6-specific failure documented, not assumed |
| V-2 | Refs | `git rev-parse main` == the full SHA recorded on the old Mac at push time (the migration-docs commit on top of `2f7f99d`); `git ls-remote origin` agrees; same for each transferred branch |
| V-3 | History | `git log --format=%H%n%an%n%ae main` identical to old Mac's output (diff = empty); `git fsck` clean |
| V-4 | Tree | `git status --porcelain` empty after clone and after build |
| V-5 | Frozen evidence | `scripts/verify_intelligence_v1_s3_evidence.sh`; V1.27 `scripts/intelligence_v1_comparison_freeze.sh` (no `--write`) prints canonical hash `fa5c3110…7325940`; `scripts/intelligence_v1_comparison_freeze` corpus tests; V1.23 results unchanged (`git diff` empty) |
| V-6 | Build | `./build.sh unsigned` succeeds |
| V-7 | Tests | `scripts/test_*.sh` (legal language, intelligence safety, protected-span, permission gate, harness, evaluation, comparison S1/S2, spec-consistency checks V1.32–V1.37) and `Tests/run_paste_key_cache_tests.sh` pass with counts equal to old Mac's; XCTest target run; known pre-existing failure `testDictationEndToEnd_whisperTiny…` (memory) should now be re-assessed, not assumed |
| V-8 | ASR | transcribe an **authorized** short test audio (e.g. bundled `dictation_fixture.wav`) via the app/Local API; non-empty plausible transcript |
| V-9 | Ollama | `ollama list` shows PO-selected tags; S1 `--local` verifier passes (digests match); *load* check only via `ollama show`, no judicial text, no corpus input |
| V-10 | Privacy | `git status`/`git log` contain no audio, results, models, tokens; `gh auth status` shows credentials only in keyring; secret scan of the repo diff since `32af8d3` |
| V-11 | Invariants | `git diff 2f7f99d -- Sources/Fluid/Intelligence Sources/Fluid/LegalLanguage` empty vs old Mac HEAD; CLAUDE.md invariants unchanged |

## Source-machine baseline (old Mac, 2026-10-20, HEAD `2f7f99d`, tracked tree unchanged except the pending CLAUDE.md edit)
- **33 scripts run, 31 exit 0, 2 exit 133 (expected):** `test_autonomous_edit_policy_investigation.sh` and `test_independent_protection_investigation.sh` fail their own pinned preconditions (superseded by V1.16; documented in CLAUDE.md). No other failures.
- Passing included: `test_legal_language`, `test_intelligence_safety`, `test_protected_span_derivation`, `test_autonomous_permission_gate`, `test_intelligence_harness`, `test_evaluation`, capability/comparison S1/S2/protocol/supplementary tests, `check_intelligence_v1_32…37_*`, `Tests/run_paste_key_cache_tests.sh`, and `verify_intelligence_v1_s3_evidence.sh` (which consumed the ignored `server_requests.log`).
- `./build.sh unsigned`: **BUILD SUCCEEDED** (one framework-symlink warning for `transcribe-cpp-swift`).
- Post-run `git status`/HEAD: unchanged; no model run, no network pulls.
- **Not run:** the `FluidDictationIntegrationTests` XCTest target (heavy; known Whisper-memory failure on 8 GB); `*_run.sh` live runners (model inference); `eval_run.sh`.
- Mini pass criterion: same 31 pass, same 2 expected failures, build succeeds.

## Final verification results — Mac mini (2026-10-20/21)
Environment verification only; passing authorizes no new Intelligence experiment. Baseline for comparison: the old-Mac table above.
| ID | Result | Evidence |
|---|---|---|
| V-1 Hardware | PASS | arm64, M6/24 GB, macOS 27.0.1, Xcode 27.1 (27A9275, same as old Mac), Swift 6.4; no M6-specific failure observed |
| V-2 Refs | PASS | `main` = `c1f645b5b46967bd435a16d2c0d35fd16413be98`, fresh clone from `origin` |
| V-3 History | PARTIAL | `git fsck --full` clean; 1130 commits, authors as expected. The line-by-line diff against the old Mac's `git log` output was not performed (old-Mac output unavailable on the mini) |
| V-4 Tree | PASS | `git status` empty after clone, build, tests and baseline |
| V-5 Frozen evidence | PASS | `verify_intelligence_v1_s3_evidence.sh` PASS with the restored log (hash-verified); V1.27 freeze check prints `fa5c3110…7325940`; no diff in `Evaluation/` |
| V-6 Build | PASS | `./build.sh unsigned` BUILD SUCCEEDED |
| V-7 Tests | PASS | 33-script baseline: **31 pass + 2 documented historical failures** (exit 133: `test_autonomous_edit_policy_investigation.sh`, `test_independent_protection_investigation.sh`) == old Mac; XCTest see below |
| V-8 ASR | PASS | isolated Local API run, see below |
| V-9 Ollama | PASS, QUALIFIED | five tags present; S1 `--local` verifier **41/46** (see S1 qualification); `ollama show` load check not run |
| V-10 Privacy | PASS | no audio/results/models/tokens in `git status`/`log`; `gh` credentials in keyring; secret-pattern scan of added lines `32af8d3..HEAD`: 0 hits; tracked audio = documented bundled UI sounds only |
| V-11 Invariants | PASS | `git diff 2f7f99d HEAD -- Sources/Fluid/Intelligence Sources/Fluid/LegalLanguage` empty |

### XCTest result summaries (full `FluidDictationIntegrationTests` suite, unsigned, unchanged, run via `xcodebuild test`)
- **Run 1:** 535 tests, 533 passed, **2 failed** (`AudioRouteRecoveryIntegrationTests`): `testCancelDuringCleanupWaitNeverStartsReplacement` (start count 1, expected 0, in a tight timing check) and `testTwentyOrdinaryStartsAndStopsKeepRecoveryIdle` (speech model `parakeet-tdt-v2` vs expected `parakeet-tdt`). 215 s wall, peak RSS 851 MB, footprint 215 MB. The run overlapped the first-ever download of the FluidAudio models. Both tests passed in two isolated reruns each.
- **Run 2:** 535 tests, **535 passed**, 65 s, peak RSS 374 MB, footprint 213 MB.
- **Status:** the cause of the run-1 failures is **not established** (cold-download timing and shared `SettingsStore` state are hypotheses only); they are not classified as flaky or as defects. No test was changed. The historical 8 GB failure `testDictationEndToEnd_whisperTiny_transcribesFixture` passed on 24 GB (3.7 s). Both result bundles are preserved privately outside Git (`~/pratilekh-private-preservation/xctest-results/`, mode 700; per-file SHA-256 `MANIFEST.sha256`, SHA-256 `ecaf69c29045365b0cf4c38b9efde857a78d9a3487997adb587f4d291ebb115d`); they are not part of the repository.

### S1 compatibility qualification (accepted by architectural ruling)
The unmodified `scripts/intelligence_v1_comparison_s1_verify.sh --local` reports **41/46**. The five failures are the same check, "on-disk blobs and manifest still hash to the recorded identity". Ollama 0.40.6 appends one self-referential layer entry (`application/vnd.docker.distribution.manifest.v2+json`, digest and size = the frozen manifest's own SHA-256 and size) to each local manifest (+163 B): granite4:3b `sha256:89962fcc…` 829 B; granite4.1:3b `6fd34935…` 829 B; qwen3:4b-instruct-2507-q4_K_M `0edcdef3…` 859 B; phi4-mini:latest `78fad5d1…` 711 B; ministral-3:3b `f04aa1c7…` 858 B. Removing only that entry and compact-serializing reproduces the frozen manifest bytes and SHA-256 exactly for all five; config digests, every frozen layer digest/size and all blobs are unchanged. The models' contents are migration-compatible; the verifier, manifests and frozen records were not modified, and the 41/46 result stands unchanged as a client-version qualification (frozen runtime: Ollama 0.34.4).

### V-8 (2026-10-21)
Run in an isolated session: Wi-Fi radio off, no non-loopback IPv4 or live non-tunnel IPv6, internet and gateway unreachable (checked before and after). The debug app was launched with a per-process `-LocalAPIEnabled YES` (nothing persisted); one `POST /v1/transcribe` for the synthetic upstream fixture `dictation_fixture.wav` returned HTTP 200: text `Hello Fluid Voice`, provider `Parakeet TDT v2 (English Only)`, confidence 0.952, `sampleCount` 18524 (= the WAV's frame count). The app was then quit cleanly, port 47733 was confirmed closed and the setting was confirmed not persisted. (Interpretation recorded: link-local IPv6 on the Wi-Fi radio's virtual interfaces was treated as down while the radio was off.)

### Live dictation smoke test (PO at the keyboard, disposable text file, non-sensitive speech)
Microphone granted via the macOS prompt; global hotkey (toggle) started and stopped dictation; the streaming preview updated about every 0.7 s; Parakeet TDT v2 produced the final text (confidence 0.94-0.99); text was inserted into the focused editor exactly; a second session started and finished normally (stop-to-insert about 0.1 s). The PO changed the primary hotkey in the app settings during the test. No automatic space is added between consecutive dictations: expected, as Continuous Dictation Mode is an opt-in setting (default off; not migrated from the old Mac).

## Open non-blocking items
- **SEC-1 (security hardening, separate from the migration): the Local API listener binds all interfaces.** `Sources/Fluid/Services/LocalAPI/LocalAPIServer.swift` `start()` creates `NWListener(using: .tcp, on: port)` with no loopback restriction; loopback is enforced only afterwards by cancelling non-loopback connections post-accept (observed during V-8 as `TCP *:47733 (LISTEN)`). When enabled, the port is therefore reachable at TCP level from the local network. Inherited upstream behaviour, identical on the old Mac; **not fixed** (production change out of scope). **The API stays disabled** (default off, `LocalAPIEnabled` unset) **pending remediation**; do not enable it without isolating the network. Suggested fix for a separately approved change: set `requiredLocalEndpoint` to `127.0.0.1` (and consider `::1`).
- XCTest run-1 failures: cause not established (above).
- S1 verifier 41/46: qualified (above).
- Operational: no built-in microphone on the Mac mini; unsigned rebuilds may require re-granting macOS permissions; app settings were not migrated.
