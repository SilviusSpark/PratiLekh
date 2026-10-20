# Rollback & Cutover
- Old Mac stays fully intact: no deletion, reset, `git clean`, model removal or Ollama prune until PO explicitly retires it.
- Until cutover, **the old Mac is authoritative**. Do no new commits on the mini before cutover, or record them and reconcile by fetch/rebase-free fast-forward only.
- Before pushing, tag nothing; no force-push or history rewrite at any time. If `git push` is rejected, stop and report.
- Failure on the mini at any phase → discard the mini clone (`rm -rf ~/Projects/PratiLekh` on the **mini only**) and restart Phase 3; GitHub content is unaffected.
- Cutover [PO]: all MIGRATION_VERIFICATION checks recorded as passed → PO signs off → mini becomes primary. Keep old Mac read-only-by-convention for a PO-set period, then PO decides retirement. Old Mac `~/pratilekh-eval-results*`, recordings and Application Support remain until securely handled.
- If a verification check fails after cutover, resume work on the old Mac from its last HEAD; reconcile any mini commits via GitHub.

## UI retirement — COMPLETED
Worktree removed after identity checks (path, branch, HEAD `8a5b134`, reachable from `origin/codex/ink-paper-milestone`, 333 entries unchanged). Archive: `~/pratilekh-private-preservation/ui-design-archive/` (manifest verified before and after). Local branch `codex/ui-ux-development` kept at `8a5b134`; to drop it later use `git branch -d` only (reachable from the remote branch). Not restorable except from `origin/codex/ink-paper-milestone` (committed state) and the archive (design docs); discarded uncommitted UI code and screenshots are gone by PO decision.

## Cutover record (2026-10-21)
PO approved the Mac mini as the primary workstation after all verification checks were recorded (MIGRATION_VERIFICATION.md). Rollback posture is unchanged: the old Mac was not modified and remains the fallback; retention and retirement are PO decisions. No commits had been made on the mini before cutover other than this closure documentation.
