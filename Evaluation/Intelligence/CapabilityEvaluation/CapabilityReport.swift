import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// Durable report for one V1.23 run: a Markdown report (all nine metrics as raw counts with
/// explicit denominators, never blended; per-category breakdown; per-entry record;
/// manual-adjudication section with raw model output) and a machine-readable JSON trial log
/// carrying every raw model response. Reports describe; they never compute a verdict.
struct CapabilityRunInfo {
    var runLabel: String
    var manifestSHA256: String
    var startedAt: String
    var finishedAt: String
    /// Free-form observations captured at run time (git HEAD / tree state, server version,
    /// loaded context length, serving-process environment, ...). Reported verbatim.
    var observations: [(key: String, value: String)]
}

enum CapabilityReport {
    static func markdown(info: CapabilityRunInfo, preflight: [CapabilityPreflightCheck], trials: [CapabilityTrial], metrics m: CapabilityMetrics) -> String {
        var out: [String] = []
        out.append("# Intelligence V1.23 -- Frozen Capability Evaluation Report")
        out.append("")
        out.append("- run: \(info.runLabel)")
        out.append("- manifest SHA-256: `\(info.manifestSHA256)`")
        out.append("- started: \(info.startedAt) / finished: \(info.finishedAt)")
        for (key, value) in info.observations {
            out.append("- \(key): \(value)")
        }
        out.append("")
        out.append("## Preflight (before the first inference)")
        for check in preflight {
            out.append("- [\(check.passed ? "PASS" : "FAIL")] \(check.name) -- `\(check.detail)`")
        }
        out.append("")
        out.append("Every figure below is a raw count with its denominator. No blended score is computed. Provider, protocol and preflight failures stay inside the denominators (an entry that failed is a miss, not an exclusion).")
        out.append("")

        out.append("## Hard safety criterion")
        out.append("**Unsafe autonomously-accepted edits (scored entries): \(m.unsafeAutonomousEdits.count)** (target 0)")
        for item in m.unsafeAutonomousEdits {
            out.append("- \(item.entryID): \(self.editLine(item.edit))")
        }
        out.append("Autonomously-accepted edits on manual-adjudication entries (unscored; need human review before the criterion is considered met): \(m.autonomousEditsPendingManualAdjudication.count)")
        for item in m.autonomousEditsPendingManualAdjudication {
            out.append("- \(item.entryID): \(self.editLine(item.edit))")
        }
        out.append("")

        out.append("## 1. Correction precision (scored entries, per edit)")
        out.append("- autonomous-facing (autonomously accepted & correct / autonomously accepted): \(m.autonomousPrecision.text)")
        out.append("- broader model-proposal (correct / all addressed edits, any disposition): \(m.modelProposalPrecision.text)")
        out.append("")
        out.append("## 2. Correction recall")
        out.append(contentsOf: self.recallLines(title: "production-facing (matched by an autonomously-accepted edit)", m.recallAutonomous))
        out.append(contentsOf: self.recallLines(title: "broader model-attempt (matched by an addressed edit at any disposition)", m.recallAttempt))
        out.append("")
        out.append("## 3. Autonomous safety")
        out.append("- raw count of autonomously-accepted edits matching no expected correction (scored entries): \(m.unsafeAutonomousEdits.count)")
        out.append("")
        out.append("## 4. `.reviewOnly` proposals (scored entries)")
        out.append("- ground-truth-correct (capability cost: good proposal held back): \(m.reviewOnlyCorrect)")
        out.append("- ground-truth-incorrect (safety catch): \(m.reviewOnlyIncorrect)")
        out.append(contentsOf: self.reasonLines(m.reviewOnlyReasons))
        out.append("")
        out.append("## 5. Deterministic Safety Authority rejection (scored entries)")
        out.append("- ground-truth-correct (safeguard precision cost): \(m.rejectedCorrect)")
        out.append("- ground-truth-incorrect (safeguard safety win): \(m.rejectedIncorrect)")
        out.append(contentsOf: self.reasonLines(m.rejectedReasons))
        out.append("")
        out.append("## 6. Addressing rejection (scored entries; no correctness split)")
        out.append("- count: \(m.addressingRejected)")
        out.append(contentsOf: self.reasonLines(m.addressingRejectedReasons))
        out.append("- informational: addressing-rejected edits whose literal text pair equals an expected correction: \(m.addressingRejectedLiteralMatches) (not counted toward any recall or precision figure)")
        out.append("")
        out.append("## 7. Valid abstention (`edits: []`)")
        out.append("- correct abstention (scored abstention-expected entries): \(m.correctAbstentions.text)")
        out.append("- missed correction by abstention (scored correction-warranted entries): \(m.missedByAbstention.text)")
        out.append("- abstentions on manual-adjudication entries (unscored): \(m.abstentionsOnManualEntries)")
        out.append("")
        out.append("## 8. Protocol/transport failure (whole-response rejection)")
        out.append("- count: \(m.protocolFailures.count)")
        for item in m.protocolFailures {
            out.append("  - \(item.entryID): \(BreakdownText.clean(item.detail))")
        }
        out.append("")
        out.append("## 9. Provider/runtime failure (not retried; Intelligence never invoked)")
        out.append("- count: \(m.providerFailures.count)")
        for item in m.providerFailures {
            out.append("  - \(item.entryID): \(BreakdownText.clean(item.detail))")
        }
        out.append("- preflight failures (model never called): \(m.preflightFailures.count)")
        for item in m.preflightFailures {
            out.append("  - \(item.entryID): \(BreakdownText.clean(item.detail))")
        }
        out.append("")

        out.append("## Per-category breakdown (raw counts)")
        out.append("| category | entries | evaluated | zero-proposal | edits | auto-accepted | reviewOnly | SA-rejected | addr-rejected | protocol-fail | provider-fail | preflight-fail |")
        out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for row in m.categories {
            let cells: [Int] = [
                row.entries, row.evaluated, row.zeroProposal, row.editsProposed, row.autonomouslyAccepted, row.reviewOnly,
                row.rejectedBySafetyAuthority, row.addressingRejected, row.protocolFailures, row.providerFailures, row.preflightFailures,
            ]
            out.append("| \(row.category) | " + cells.map(String.init).joined(separator: " | ") + " |")
        }
        out.append("")

        out.append("## Manual adjudication (never auto-scored): \(m.manualEntryIDs.joined(separator: ", "))")
        for trial in trials where trial.adjudication.entry.manualAdjudicationOnly {
            out.append("")
            out.append(self.entryRecord(trial))
        }
        out.append("")
        out.append("## Per-entry record (scored entries)")
        for trial in trials where !trial.adjudication.entry.manualAdjudicationOnly {
            out.append("")
            out.append(self.entryRecord(trial))
        }
        return out.joined(separator: "\n")
    }

    /// Raw per-entry JSON log, including every raw model tool-call argument string verbatim.
    static func trialLogJSON(trials: [CapabilityTrial]) -> Data {
        let records: [[String: Any]] = trials.map { trial in
            let adjudication = trial.adjudication
            return [
                "id": adjudication.entry.id,
                "category": adjudication.entry.category,
                "manualAdjudicationOnly": adjudication.entry.manualAdjudicationOnly,
                "rawInput": trial.report.rawInputText,
                "legalNormalized": trial.report.legalNormalizedText ?? NSNull(),
                "modelFreeText": trial.report.modelTextContent ?? NSNull(),
                "modelRawToolCallArguments": trial.report.modelRawToolCallArguments,
                "trial": adjudication.trial.rawValue,
                "failureDetail": adjudication.failureDetail ?? NSNull(),
                "recallAutonomous": "\(adjudication.recall(.autonomousAccepted))",
                "recallAnyAddressed": "\(adjudication.recall(.anyAddressedDisposition))",
                "edits": adjudication.edits.map { edit -> [String: Any] in
                    [
                        "position": edit.position, "id": edit.id, "sourceText": edit.sourceText, "replacementText": edit.replacementText,
                        "bucket": edit.bucket.rawValue, "disposition": BreakdownText.clean(edit.dispositionSummary),
                        "addressing": BreakdownText.clean(edit.addressingSummary),
                        "correctness": edit.correctness.map { "\($0)" } ?? "unlabelled",
                        "literalMatchesExpected": edit.literalMatchesExpected,
                    ]
                },
            ]
        }
        return (try? JSONSerialization.data(withJSONObject: records, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])) ?? Data()
    }

    // MARK: - Helpers

    private static func recallLines(title: String, _ recall: CapabilityRecallSummary) -> [String] {
        var lines = ["- \(title):"]
        lines.append("  - entry-level full recall: \(recall.entryFull.text)")
        lines.append("  - entry-level partial (multi-edit): \(recall.entryPartial.count)" + (recall.entryPartial.isEmpty ? "" : " -- " + recall.entryPartial.map { "\($0.entryID) \($0.matched)/\($0.of)" }.joined(separator: ", ")))
        lines.append("  - entry-level missed: \(recall.entryMissed) of \(recall.entryFull.denominator)")
        lines.append("  - per-correction recall: \(recall.perCorrection.text)")
        return lines
    }

    private static func reasonLines(_ reasons: [String: Int]) -> [String] {
        reasons.sorted { $0.key < $1.key }.map { "  - \(BreakdownText.clean($0.key)): \($0.value)" }
    }

    private static func editLine(_ edit: CapabilityEditAdjudication) -> String {
        "\"\(edit.sourceText)\" -> \"\(edit.replacementText)\" (\(BreakdownText.clean(edit.dispositionSummary)))"
    }

    private static func entryRecord(_ trial: CapabilityTrial) -> String {
        let a = trial.adjudication
        var lines = ["### \(a.entry.id) [\(a.entry.category)] -- \(a.trial.rawValue)"]
        lines.append("- input: \"\(trial.report.rawInputText)\"")
        if let normalized = trial.report.legalNormalizedText {
            lines.append("- legalNormalized: \"\(normalized)\"")
        }
        if !a.entry.expectedCorrections.isEmpty {
            lines.append("- expected: " + a.entry.expectedCorrections.map { "\"\($0.source)\" -> \"\($0.replacement)\"" }.joined(separator: "; ") + (a.entry.recallRequiresAll ? " (all required)" : " (any one)"))
        } else {
            lines.append("- expectation: \(a.entry.expectation)\(a.entry.manualAdjudicationOnly ? " (manual adjudication only)" : "")")
        }
        if let text = trial.report.modelTextContent, !text.isEmpty {
            lines.append("- model free text: \"\(text)\"")
        }
        for (index, raw) in trial.report.modelRawToolCallArguments.enumerated() {
            lines.append("- model raw args[\(index)]: `\(raw)`")
        }
        if let detail = a.failureDetail {
            lines.append("- failure: \(BreakdownText.clean(detail))")
        }
        if a.trial == .evaluated {
            if a.isZeroProposal {
                lines.append("- zero proposals")
            }
            for edit in a.edits {
                let correctness = edit.correctness.map { "\($0)" } ?? "unlabelled"
                lines.append(
                    "- [\(edit.position)] \"\(edit.sourceText)\" -> \"\(edit.replacementText)\" | "
                        + "\(BreakdownText.clean(edit.addressingSummary)) | \(BreakdownText.clean(edit.dispositionSummary)) | correctness: \(correctness)"
                )
            }
            if a.entry.isScoredCorrectionWarranted {
                lines.append("- recall: autonomous \(a.recall(.autonomousAccepted)), any-addressed \(a.recall(.anyAddressedDisposition))")
            }
            if case let .evaluated(sample) = trial.report.outcome {
                lines.append("- would-be output: \"\(sample.wouldBeOutput)\"")
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// Cosmetic `String(describing:)` clean-up shared by the report (see `CapabilityMetrics.cleanReason`).
enum BreakdownText {
    static func clean(_ text: String) -> String {
        CapabilityMetrics.cleanReason(text)
    }
}
