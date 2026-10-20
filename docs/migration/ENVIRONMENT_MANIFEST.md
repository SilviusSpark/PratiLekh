# Environment Manifest (captured read-only, 2026-10-20, old Mac)
No secret values recorded.

## 1. Hardware / OS
MacBook Air M1, arm64, 8 GB RAM, 228 GB disk (67 GiB free), macOS 27.0.1.
Target: "Mac mini M6, 24 GB" — **M6 compatibility is unverified** (see VERIFICATION V-1).

## 2. Repositories
| Path | Branch / HEAD | Notes |
|---|---|---|
| `~/Projects/PratiLekh` | `main`, clean; source HEAD before this migration commit was `2f7f99d` | 11 commits (plus this migration-docs commit) ahead of `origin/main` (`32af8d3`); remotes `origin` (SilviusSpark/PratiLekh) and a legacy `upstream` (inherited FluidVoice; **never a migration source or push target**) |
| `~/Projects/PratiLekh-UI` (worktree) — **retired, does not migrate** | `codex/ui-ux-development` `8a5b134` | local-only branch; **333 status entries** (see UI_PRESERVATION below): 290 staged files (+5186/−46: 247 png, 15 md, 11 log, 6 json, 2 py, 1 swift), 50 unstaged (+2377/−2140; 49 swift, plus docs), 1 untracked (`Tests/ProviderProcessingDisclosureTests.swift`) |
Ignored/untracked of note: `DerivedData/` (1.5 GB, rebuildable), `default.profraw`, `.DS_Store`, `Evaluation/Intelligence/V1_30_S3_RESULTS/server_requests.log` — **correction of the earlier draft**: it *is* listed in that directory's `SHA256SUMS` (`79de85f6…a5c12`) and `scripts/verify_intelligence_v1_s3_evidence.sh` reads it (asserts 390 chat + 5 generate POSTs), but `.gitignore:126 *.log` keeps it out of Git. A fresh clone therefore **cannot pass V-5 without it**. A private copy was made at `~/pratilekh-private-preservation/v1_30/` (mode 700, hash identical). Content: 52 KB of Ollama request lines to 127.0.0.1, no judicial text; classification still pending (PO). It must not be added to Git or modified.
Sibling dirs `~/Projects/JurisCorpus*`, `NyayaLekha-mac`, `Judicial Knowledge Database`: **not PratiLekh**; out of scope unless PO says otherwise.
Commit identity: `Spandan <92712698+SilviusSpark@users.noreply.github.com>`.

## 3. Toolchain
Xcode 27.1 (27A9275), Swift 6.4 (project targets Swift 5.9 / macOS 15+), Homebrew 7.0.6, git 2.49.0, gh 2.93.0 (HTTPS, keyring auth), SwiftLint 0.65.1, SwiftFormat 0.63.0, Claude Code 2.1.285, Ollama client 0.34.4 (server not running). Git LFS: not installed.
Build/test commands: `./build.sh unsigned`; `xcodebuild test -project PratiLekh.xcodeproj -scheme PratiLekh -destination 'platform=macOS'`; `scripts/test_*.sh` (see CLAUDE.md). SPM deps resolved via `Package.resolved` (tracked).
Signing: `DEVELOPMENT_TEAM` is upstream's `V4J43B279J`; use `unsigned` builds. Do not change.
Environment variables: none required by repo docs (not exhaustively audited — see Risks).

## 4. Models (locations, sizes)
| Class | Location | Size | Source |
|---|---|---|---|
| **Pinned (5)** — `granite4:3b`, `granite4.1:3b`, `qwen3:4b-instruct-2507-q4_K_M`, `phi4-mini:latest`, `ministral-3:3b` | `~/.ollama/models` | most of 13 GB | Ollama registry; manifest/layer digests frozen in `Evaluation/References/intelligence-v1-comparison-s1/acquisition_identity.json`; verifiable with `scripts/intelligence_v1_comparison_s1_verify.sh --local` |
| **Unpinned (2)** — `granite4:350m`, `qwen2.5:1.5b` | same | small | Used only in V1.3B/V1.18 diagnostics; **not in the V1.27 registry, no frozen digest**. Not required for any current gate. Re-pull is optional [PO]; if wanted, record digests at pull time and label them unverified-against-history. |
| FluidAudio ASR (parakeet-tdt-0.6b-v2, parakeet-ctc-110m, silero-vad; CoreML) | `~/Library/Application Support/FluidAudio/Models` | 542 MB | Hugging Face, auto-download on first run |
| FluidIntelligence | `~/Library/Application Support/FluidIntelligence` | 3.5 GB | upstream FluidVoice artefact; **not a PratiLekh dependency** (CLAUDE.md) → do not migrate |
| HF cache | `~/.cache/huggingface` | 1.4 MB | trivial |
MLX / llama.cpp: no separate PratiLekh-owned runtime installed; Whisper GGUF via SPM `transcribe-cpp-swift`.

## 5. Non-Git assets
| Asset | Path | Class |
|---|---|---|
| Frozen evidence (V1.23, V1.30 results, corpora) | in repo | **GitHub** (hash-verify after clone) |
| Eval results 3E/3F/3G | `~/pratilekh-eval-results*` (~720 KB) | **private**; encrypted transfer [PO] or leave on old Mac |
| Real-dictation audio | `~/Music/Recordings` (28 files) | **private judicial-adjacent**; encrypted transfer [PO]; never GitHub |
| App state | `~/Library/Application Support/PratiLekh` (history sqlite, vocabulary) + defaults `in.pratilekh.app.debug` | **private**; do not migrate by default [PO] |
| Ollama / FluidAudio models | above | **re-download**, verify digests |
| Credentials | gh keyring token, Keychain items | **never copied**; re-auth |
| `DerivedData` | repo dir | rebuild |
| V1.30 `server_requests.log` | ignored, in `V1_30_S3_RESULTS/` | **needed for V-5**; private copy in `~/pratilekh-private-preservation/v1_30/`; restore into the same path on the mini via PO-approved transfer, never Git |
| Claude Code memory | `~/.claude/projects/<encoded-project-path>/memory` | optional copy [PO]; contains no secrets expected, review first |
| Unrelated `/Applications/FluidVoice.app` | | leave |

## 6. UI worktree — RETIRED (completed 2026-10-20, PO-authorized)
`PratiLekh-UI` was removed with `git worktree remove --force`. It does not migrate. HEAD `8a5b134` remains on `origin/codex/ink-paper-milestone`; the local branch pointer `codex/ui-ux-development` is retained (not pushed, not force-deleted). Design material was archived privately before removal: `~/pratilekh-private-preservation/ui-design-archive/` (67 files: 15 staged review md, 4 ignored design notes, 48 files of `option-b-stage-1/`; working-tree contents, relative paths preserved; `MANIFEST.sha256` hash `37070048…e7207`, all 67 verified against originals and re-verified after removal). The archive stays off GitHub; it is **not** part of the mini migration unless the PO later approves. Future UI work starts on a fresh branch from then-current `main`.
