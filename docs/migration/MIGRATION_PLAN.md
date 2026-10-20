# PratiLekh Migration Plan — MacBook Air M1 (8 GB) → Mac mini (24 GB)

**Status: COMPLETED 2026-10-21 — the Mac mini was approved as the primary development workstation by the Product Owner (see "Closure record" at the end).** The text below is the original plan, kept as written. Authoritative project state stays in `CLAUDE.md` and `Evaluation/Intelligence/*`; this plan does not restate it.
Legend — **[A]** automatic (scriptable), **[M]** manual action, **[PO]** Product Owner approval required.

## Phase 0 — Freeze the source (old Mac)
1. [M] Confirm no running Xcode/app/Ollama processes touching the repo.
2. [A] Record `git rev-parse HEAD`, `git branch -vv`, `git status --porcelain --ignored` for `PratiLekh` and `PratiLekh-UI` (see ENVIRONMENT_MANIFEST §2).
3. [PO] Decide the push set (below). Nothing is pushed by this plan.

## Phase 1 — GitHub transfer (old Mac)
Required refs (all from one GitHub remote, `origin` = `SilviusSpark/PratiLekh`):
| Ref | Local | origin | Action |
|---|---|---|---|
| `main` | `2f7f99d` | `32af8d3` | **11 commits unpushed** → fast-forward push `main` |
| `codex/ink-paper-milestone` | `8a5b134` | `8a5b134` | already on GitHub |
| `codex/ui-ux-development` | `8a5b134` | not pushed | **Retired by PO; does not migrate.** Its HEAD equals `origin/codex/ink-paper-milestone`, so nothing is lost by not pushing. |
| `claude/funny-dijkstra-v1oxc1` | — | exists on origin | clone gets it; no action |
Range verified: `origin/main..HEAD` = exactly 11 commits (`1c1f8dd` … `2f7f99d`), all authored `Spandan <…@users.noreply.github.com>`; `origin/main` (`32af8d3`) is an ancestor of HEAD, so the push is a pure fast-forward. 55 files, +24,645/−78: Evaluation docs/results/references, scripts, Tests, `.gitignore` (adds script allowlist entries), `CLAUDE.md`, `PRATILEKH_PLAN.md`. `V1_30_S3_RESULTS/*` is deliberate frozen evidence from the synthetic development corpus (no real dictation, no audio, no model files, no credentials found; `apiKey: ""` literals are empty harness config). Not exposed: `server_requests.log` (ignored).
Commands for later approval (all use `origin`; `upstream` is never used):
```
git -C ~/Projects/PratiLekh fetch origin
git -C ~/Projects/PratiLekh merge-base --is-ancestor origin/main main && echo FF-OK
git -C ~/Projects/PratiLekh push origin main
git -C ~/Projects/PratiLekh ls-remote origin refs/heads/main   # expect the HEAD SHA at push time
```
The migration docs and the CLAUDE.md correction must be committed **before** the push if they are meant to travel (proposed 1 commit: `docs/migration/*` + `CLAUDE.md`), which makes the pushed tip a new SHA — re-record it as the V-2 expected value.
Git LFS: **not needed** (not installed, no `.gitattributes` LFS rules, no tracked model/audio >1 MB beyond bundled UI sounds and one test wav). Models/audio/results stay out of Git.

## Phase 2 — Non-Git assets (secure transfer or re-download)
See ENVIRONMENT_MANIFEST §5 for the class of each asset. Summary: models are **re-downloaded and hash-verified**, not copied; private evaluation results and real-dictation audio need **encrypted direct transfer** [PO]; credentials are **never transferred**, re-authenticated on the mini.

## Phase 3 — Bootstrap (Mac mini) — see MAC_MINI_BOOTSTRAP.md
## Phase 4 — Verify — see MIGRATION_VERIFICATION.md (all must pass)
## Phase 5 — Cutover [PO]
Mini becomes primary only after Phase 4 passes **and** the PO signs off. The old Mac is untouched until a PO-chosen retention period ends (MIGRATION_ROLLBACK.md).

## Out of scope
No feature work, no Intelligence/normalization/Authority change, no model runs, no benchmark runs, no frozen-evidence edits. Verification ≠ authorization of a new experiment.

## Closure record (2026-10-21)
- **Outcome:** all verification gates V-1…V-11 passed or are explicitly qualified (MIGRATION_VERIFICATION.md, "Final verification results"); PO approved the Mac mini as the primary workstation. Cutover itself is a status change: the old Mac stays intact as fallback per MIGRATION_ROLLBACK.md until the PO retires it.
- **Deviations from this plan:** (1) the migration checkpoint `c1f645b` (already on `origin/main`) was cloned fresh; no push was needed from the old Mac. (2) The repository lives on a dedicated external APFS SSD (`/Volumes/Projects/Pratilekh`), not `~/Projects/PratiLekh`; system tools stay on the internal SSD. An earlier ExFAT checkout on that drive was discarded (AppleDouble `._*` files corrupt Git/status on ExFAT). (3) Models were re-pulled from the Ollama registry and the private V1.30 log was transferred by AirDrop (hash-verified), as Phase 2 required. No private recordings, evaluation results, app state or credentials were transferred.
- **Non-blocking items carried forward:** SEC-1 (Local API binds all interfaces; API disabled), the S1 verifier's 41/46 qualification, and one XCTest run with two unexplained failures — all described in MIGRATION_VERIFICATION.md.
