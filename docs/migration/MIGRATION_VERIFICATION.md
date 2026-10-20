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
