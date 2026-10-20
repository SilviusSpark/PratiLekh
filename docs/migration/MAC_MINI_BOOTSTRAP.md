# Mac mini Bootstrap (executed 2026-10-20/21; see "Execution record" at the end)
Every step [M] unless marked [A]. Each install step needs PO authorization first.
1. Record `sw_vers`, `uname -m`, `sysctl hw.memsize`; install macOS updates [M].
2. Xcode (App Store/developer.apple.com) matching or newer than 27.1; `sudo xcodebuild -license accept`; `xcode-select -s /Applications/Xcode.app` [M]. Confirm macOS 15+ SDK builds the target.
3. Homebrew (official installer) [M]; `brew install git gh swiftlint swiftformat ollama` [A after approval]. Pin to the manifest versions where the formula allows; otherwise record resulting versions.
4. `gh auth login` (HTTPS, browser flow) [M]; set `git config --global user.name Spandan` and user.email to the noreply address [M].
5. `git clone https://github.com/SilviusSpark/PratiLekh.git ~/Projects/PratiLekh` [A]; `git fetch origin` (do not add or fetch `upstream`); `codex/ink-paper-milestone` remains available as a remote branch for history; do not check it out as a working branch unless needed [A]. Clone `main` only as the authoritative dev branch; **no UI worktree** is recreated. Future UI work starts on a fresh branch from then-current `main`.
6. Read `CLAUDE.md`; install Claude Code [M]; (optional PO) restore memory dir.
7. `./build.sh unsigned` [A]; resolves SPM from `Package.resolved`.
8. ASR models: launch built app / local API once to trigger Hugging Face download of parakeet-tdt-0.6b-v2 + silero-vad (+ctc-110m only if boosting enabled; CLAUDE.md says boosting stays off) [M]. Check `~/Library/Application Support/FluidAudio/Models`.
9. Ollama: start server [M]; run `scripts/intelligence_v1_comparison_s1_verify.sh` **without `--local`** to see what is missing; `ollama pull <tag>` only the models the PO selects [PO]. Pulling is a download, not an experiment. Pull only the 5 **pinned** models (see manifest §4); the 2 unpinned ones are optional. Then `--local` compares manifests/layers to the frozen S1 artifact (no inference).
10. Restore `V1_30_S3_RESULTS/server_requests.log` (hash `79de85f6…a5c12`) to its original path — required by V-5 — then other permitted private assets via encrypted transfer [PO] (never GitHub/cloud sync).
11. Grant macOS permissions (microphone, accessibility, input monitoring) [M]; these are per-machine and cannot be copied.
12. Do not enable Local API unless needed (setting read at launch).

## Execution record (2026-10-20/21)
| Step | Result on the Mac mini |
|---|---|
| 1 hardware | recorded (ENVIRONMENT_MANIFEST §7) |
| 2 Xcode | 27.1 (27A9275) installed by the PO; license accepted, `xcode-select` -> `/Applications/Xcode.app` |
| 3 Homebrew + packages | Homebrew 7.0.10; `gh`, `swiftlint`, `swiftformat`, `ollama` installed (versions in §7; unpinned) |
| 4 GitHub/identity | git identity set; `gh auth login` completed by the PO (keyring) |
| 5 clone | **deviation:** fresh clone to `/Volumes/Projects/Pratilekh` on an APFS external SSD (the first clone on ExFAT was discarded); `main` = `c1f645b`, `origin` only, `git fsck --full` clean, tree clean |
| 6 CLAUDE.md / Claude Code | read; Claude Code memory not copied |
| 7 build | `./build.sh unsigned` BUILD SUCCEEDED (same single `transcribe-cpp-swift` symlink warning as the old Mac) |
| 8 ASR models | downloaded on first XCTest run (not by launching the app); Parakeet TDT v2 loads and transcribes on M6 |
| 9 Ollama | server started manually; five pinned tags pulled sequentially; S1 `--local` verifier 41/46 (qualified, see VERIFICATION) |
| 10 private log | `server_requests.log` AirDropped, SHA-256 `79de85f6…a5c12` verified at source copy and destination, restored at the original gitignored path, mode 600 |
| 11 permissions | microphone and global-hotkey/Accessibility granted by the PO; no Input Monitoring prompt was reported (not independently verifiable from logs) |
| 12 Local API | disabled; enabled once, per process only (`-LocalAPIEnabled YES`), for the isolated V-8 run, then closed |
