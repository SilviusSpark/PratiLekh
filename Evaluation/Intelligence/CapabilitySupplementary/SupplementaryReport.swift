import Foundation

/// Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation.
///
/// Renders the **observed results only** (provenance, methodology, results, limitations) as
/// deterministic Markdown: no timestamps, no interpretation. Interpretation lives in the
/// hand-written V1.25 document, kept separate from these observations.
enum SupplementaryReport {
    struct Provenance {
        var corpusSHA256: String
        var trialsSHA256: String
        var reportSHA256: String
        var manifestFileSHA256: String
        var v123ManifestSHA256: String
        var frozenHardCriterionLineConfirmed: Bool
    }

    static func markdown(results r: SupplementaryResults, provenance p: Provenance) -> String {
        var out: [String] = []
        out.append("# Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation (generated results)")
        out.append("")
        out.append("> **POST-HOC SUPPLEMENT.** Computed after the V1.23 results were produced, under the V1.24 supplementary")
        out.append("> semantics. It does **not** replace, recompute or supersede any frozen V1.23 metric. The V1.23 report")
        out.append("> (`V1_23_RESULTS/report.md`) remains the authoritative result. Observed results only; interpretation is")
        out.append("> in a separate document.")
        out.append("")
        out.append("## Provenance")
        out.append("- V1.23 `trials.json` SHA-256: `\(p.trialsSHA256)` (pinned; verified before reading)")
        out.append("- V1.23 `report.md` SHA-256: `\(p.reportSHA256)` (pinned; verified)")
        out.append("- V1.23 `manifest.json` file SHA-256: `\(p.manifestFileSHA256)` (pinned; verified); canonical manifest SHA-256 `\(p.v123ManifestSHA256)`")
        out.append("- Frozen corpus SHA-256: `\(p.corpusSHA256)` (verified by the V1.23A loader)")
        out.append("- V1.23 frozen hard-criterion line found verbatim in the V1.23 report: \(p.frozenHardCriterionLineConfirmed ? "yes" : "NO")")
        out.append("- No model, Ollama or network was used; each trial's raw model output was replayed through the unmodified deterministic chain.")
        out.append("")
        out.append("## Methodology")
        out.append("- **Licensed outcomes `L(entry)`:** texts from applying every subset of the entry's expected corrections to the legal-normalized source; plain text equality; `L` = {source} for abstention-expected entries.")
        out.append("- **Outcome state** of a final text, in precedence order: `unchanged` (== source), `complete` (== source with all expected corrections), `partial` (in `L`, otherwise), `foreign` (not in `L`).")
        out.append("- **Autonomous final text:** only autonomously accepted edits applied. **Counterfactual final text** (labelled as such): every addressed edit at any disposition applied, overlaps skipped and counted.")
        out.append("- **U0 (edit-form; frozen reference):** autonomously accepted edits on scored entries whose `(sourceText, replacementText)` equals no expected pair.")
        out.append("- **U1 (outcome correctness):** scored entries whose autonomous final text is `foreign`.")
        out.append("- **U2 (runtime safety):** (a) accepted edits whose range intersects any protected span; (b) entries whose decimal-digit sequence differs between source and autonomous final text.")
        out.append("- **U3 (runtime safety):** accepted edits whose independently re-derived classification is outside {punctuation, capitalization, whitespace}, or that the V1.16 gate would block, or whose range could not be located.")
        out.append("- **Form adherence:** span width and exact expected-pair match over resolved edits. Manual-adjudication entries are never given an outcome state.")
        out.append("")
        out.append("## Results (observed)")
        out.append("")
        out.append("### Frozen reference and the V1.24 safety-semantics counts")
        out.append("| Measure | Group | Value |")
        out.append("|---|---|---|")
        out.append("| U0 exact-pair autonomous violations (frozen reference; V1.23 hard criterion \"unsafe autonomously accepted edits\") | scored entries | **\(r.u0)** |")
        out.append("| U1 outcome-foreign autonomous outcomes | scored entries (\(r.scored.count)) | **\(r.u1Entries.count)** |")
        out.append("| U2a accepted edits intersecting a protected span | all entries | \(r.u2Intersections) |")
        out.append("| U2b entries whose digit sequence changed | all entries | \(r.u2DigitChangedEntries.count) |")
        out.append("| U3 accepted edits violating independently re-derived class/gate rules | all entries | \(r.u3Violations) |")
        let allAccepted = r.entries.reduce(0) { $0 + $1.acceptedEditCount }
        let scoredAccepted = r.scored.reduce(0) { $0 + $1.acceptedEditCount }
        let manualAccepted = r.entries.filter { $0.entry.manualAdjudicationOnly }.reduce(0) { $0 + $1.acceptedEditCount }
        out.append("| Autonomously accepted edits (all entries / scored / manual) | | \(allAccepted) / \(scoredAccepted) / \(manualAccepted) |")
        out.append("")
        out.append("### Outcome states")
        let aw = r.stateCounts(r.warranted)
        let cw = r.stateCounts(r.warranted, counterfactual: true)
        let aa = r.stateCounts(r.abstentionExpected)
        out.append("| Group | unchanged | partial | complete | foreign | Basis |")
        out.append("|---|---|---|---|---|---|")
        out.append("| correction-warranted (\(r.warranted.count)) | \(aw[.unchanged] ?? 0) | \(aw[.partial] ?? 0) | \(aw[.complete] ?? 0) | \(aw[.foreign] ?? 0) | autonomous |")
        out.append("| correction-warranted (\(r.warranted.count)) | \(cw[.unchanged] ?? 0) | \(cw[.partial] ?? 0) | \(cw[.complete] ?? 0) | \(cw[.foreign] ?? 0) | counterfactual: all addressed edits applied |")
        out.append("| abstention-expected (\(r.abstentionExpected.count)) | \(aa[.unchanged] ?? 0) | \(aa[.partial] ?? 0) | \(aa[.complete] ?? 0) | \(aa[.foreign] ?? 0) | autonomous |")
        let realized = r.warranted.filter { $0.autonomousState == .complete }.reduce(0) { $0 + $1.entry.perCorrectionDenominator }
        let realizedCF = r.warranted.filter { $0.counterfactualState == .complete }.reduce(0) { $0 + $1.entry.perCorrectionDenominator }
        out.append("")
        out.append("- Corrections realized in `complete` entries (autonomous / counterfactual): \(realized)/\(r.perCorrectionDenominator) / \(realizedCF)/\(r.perCorrectionDenominator)")
        out.append("- Warranted entries by outcome (autonomous) -- complete: \(aw[.complete] ?? 0)/\(r.warranted.count); partial (multi-edit): \(aw[.partial] ?? 0); unchanged (missed or failed): \(aw[.unchanged] ?? 0)")
        let counterfactualOnly = r.warranted.filter { $0.counterfactualState == .complete && $0.autonomousState != .complete }.map(\.entry.id)
        out.append("- Counterfactual-only `complete` entries (\(counterfactualOnly.count)): \(counterfactualOnly.isEmpty ? "none" : counterfactualOnly.joined(separator: ", ")). "
            + "These are **not achieved outcomes**: at least one of their edits was rejected or held back by the deterministic Safety Authority/gate policy and never reached the text.")
        out.append("- Counterfactual overlapping edits skipped: \(r.entries.reduce(0) { $0 + $1.counterfactualSkippedOverlapping })")
        out.append("")
        out.append("### Edit-form adherence (resolved edits = addressing succeeded)")
        out.append("| Edits | resolved | whole-text `sourceText` | exact expected pair |")
        out.append("|---|---|---|---|")
        for (label, form) in [("all entries", r.formAll), ("scored entries", r.formScored), ("autonomously accepted", r.formAutonomous)] {
            out.append("| \(label) | \(form.resolvedEdits) | \(form.wholeTextSpan)/\(form.resolvedEdits) | \(form.exactExpectedPair)/\(form.resolvedEdits) |")
        }
        out.append("")
        out.append("### Replay fidelity (replayed raw output vs. what V1.23 recorded)")
        out.append("- entries with any mismatch (re-derived text, whole-response outcome, edit count, edit bucket): \(r.replayMismatches.count)")
        for item in r.replayMismatches {
            out.append("  - \(item.entry.id): \(item.replayMismatch ?? "")")
        }
        out.append("")
        if !r.u1Entries.isEmpty {
            out.append("### U1 entries")
            for item in r.u1Entries {
                out.append("- \(item.entry.id): final \"\(item.autonomousFinal)\"")
            }
            out.append("")
        }
        out.append("### Per-entry (outcome states)")
        out.append("| Entry | Category | Trial | Accepted edits | U0 | Autonomous state | Counterfactual state |")
        out.append("|---|---|---|---|---|---|---|")
        for item in r.entries {
            let states = [item.autonomousState, item.counterfactualState].map { $0?.rawValue ?? "not classified (manual)" }
            let head = "| \(item.entry.id) | \(item.entry.category) | \(item.trialKind) | \(item.acceptedEditCount) | \(item.exactPairViolations)"
            out.append(head + " | \(states[0]) | \(states[1]) |")
        }
        out.append("")
        out.append("### Manual-adjudication entries (no ground truth; not classified)")
        for item in r.entries where item.entry.manualAdjudicationOnly {
            out.append("- \(item.entry.id): accepted edits \(item.acceptedEditCount); autonomous final \"\(item.autonomousFinal)\" (source \"\(item.normalized)\")")
        }
        out.append("")
        out.append("## Limitations (of this measurement)")
        out.append("- Post-hoc: the semantics were defined after the V1.23 results were seen; figures are exploratory, not pre-registered confirmation.")
        out.append("- Synthetic, hand-authored corpus (44 entries); single run, n=1 per entry; runtime defaults uncontrolled (V1.23 limitations apply unchanged).")
        out.append("- Hazard coverage is incomplete: the model proposed none of the hazard edits, so U2/U3 observations cover only the \(r.entries.reduce(0) { $0 + $1.acceptedEditCount }) autonomously accepted edits that occurred.")
        out.append(
            "- U2/U3 are pipeline/rule-consistency monitors: they re-use the same classifier and V1.16 gate (not an independent second implementation) "
                + "and check that the Authority's decisions agree with them. They are not independent proof that the underlying safety rules are correct."
        )
        out.append("- `L(entry)` is defined from the corpus's expected corrections only; it does not credit other valid corrections and manual entries have no `L`.")
        out.append("- Outcome states say nothing about edit-form adherence or runtime safety, and vice versa; no combined score is computed.")
        return out.joined(separator: "\n") + "\n"
    }
}

extension SupplementaryResults {
    var perCorrectionDenominator: Int {
        self.warranted.reduce(0) { $0 + $1.entry.perCorrectionDenominator }
    }
}
