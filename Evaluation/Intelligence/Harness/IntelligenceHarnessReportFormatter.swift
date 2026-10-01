import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// Plain-text, human-readable rendering of `IntelligenceHarnessSampleReport`
/// values, designed for manual adjudication: every line traces
/// `input -> model proposal -> addressing result -> deterministic
/// disposition/reason -> would-be output` for one sample, and the summary
/// separates every bucket the V1.17 instructions asked to keep distinct.
/// Never computes a verdict itself -- counts and reasons only; "fewer
/// rejections" is explicitly never treated as "better."
enum IntelligenceHarnessReportFormatter {
    /// Strips a leading `<ModuleName>.` component from a `String(describing:)`
    /// rendering of a nested enum value (e.g.
    /// `IntelligenceHarnessPipelineTests.ProposalRejectionReason.intersectsResolvedSpan`
    /// -> `ProposalRejectionReason.intersectsResolvedSpan`). This is purely
    /// cosmetic -- a side effect of this repo's standalone-binary compile
    /// convention naming the module after the compiled `@main` type -- and
    /// never changes which reason is reported, only how it reads for a human
    /// adjudicator.
    private static func clean(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9_]+\\.(?=[A-Z][A-Za-z0-9_]*\\.)") else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    static func render(_ report: IntelligenceHarnessSampleReport) -> String {
        var lines: [String] = []
        lines.append("=== SAMPLE \(report.sampleID) [tier=\(report.tier)] ===")
        lines.append("input:            \(self.quote(report.rawInputText))")
        if let normalized = report.legalNormalizedText {
            lines.append("legalNormalized:  \(self.quote(normalized))")
        }
        if let text = report.modelTextContent, !text.isEmpty {
            lines.append("model free text:  \(self.quote(text))")
        }
        for (index, raw) in report.modelRawToolCallArguments.enumerated() {
            lines.append("model raw args[\(index)]: \(raw)")
        }

        switch report.outcome {
        case let .preflightFailure(reason):
            lines.append("outcome: PREFLIGHT FAILURE (model never called) -- \(self.clean(reason))")
        case let .providerFailure(reason):
            lines.append("outcome: PROVIDER/TRANSPORT FAILURE (Intelligence never invoked) -- \(self.clean(reason))")
        case let .wholeResponseRejected(reason):
            lines.append("outcome: WHOLE-RESPONSE REJECTED (no edit individually addressed) -- \(self.clean(reason))")
        case let .evaluated(sample):
            if sample.isZeroProposal {
                lines.append("outcome: evaluated, zero proposals")
            } else {
                lines.append("outcome: evaluated, \(sample.edits.count) edit(s)")
                for edit in sample.edits {
                    lines.append(self.render(edit))
                }
            }
            lines.append("would-be output:  \(self.quote(sample.wouldBeOutput))")
        }
        return lines.joined(separator: "\n")
    }

    private static func render(_ edit: IntelligenceHarnessEditRecord) -> String {
        var occurrenceNote = ""
        if let occurrence = edit.modelEdit.occurrence {
            occurrenceNote = " occurrence=\(occurrence)"
        }
        return """
          [\(edit.position)] \(edit.id)  sourceText=\(self.quote(edit.modelEdit.sourceText)) replacementText=\(self.quote(edit.modelEdit.replacementText))\(occurrenceNote)
              addressing:   \(self.clean(edit.addressingSummary))
              disposition:  \(self.clean(edit.dispositionSummary))  [\(edit.bucket.rawValue)]
        """
    }

    private static func quote(_ text: String) -> String {
        "\"\(text)\""
    }

    // MARK: - Summary

    struct Summary {
        let tier: String
        let sampleCount: Int
        let zeroProposalSamples: [String]
        let preflightFailures: [(id: String, reason: String)]
        let providerFailures: [(id: String, reason: String)]
        let wholeResponseRejections: [(id: String, reason: String)]
        let bucketCounts: [IntelligenceHarnessBucket: Int]
        let bucketReasonCounts: [IntelligenceHarnessBucket: [String: Int]]
        let autonomouslyAcceptedDetail: [(sampleID: String, edit: IntelligenceHarnessEditRecord)]
    }

    static func summarize(tier: String, reports: [IntelligenceHarnessSampleReport]) -> Summary {
        var zeroProposalSamples: [String] = []
        var preflightFailures: [(id: String, reason: String)] = []
        var providerFailures: [(id: String, reason: String)] = []
        var wholeResponseRejections: [(id: String, reason: String)] = []
        var bucketCounts: [IntelligenceHarnessBucket: Int] = [:]
        var bucketReasonCounts: [IntelligenceHarnessBucket: [String: Int]] = [:]
        var autonomouslyAcceptedDetail: [(sampleID: String, edit: IntelligenceHarnessEditRecord)] = []

        for report in reports {
            switch report.outcome {
            case let .preflightFailure(reason):
                preflightFailures.append((report.sampleID, reason))
            case let .providerFailure(reason):
                providerFailures.append((report.sampleID, reason))
            case let .wholeResponseRejected(reason):
                wholeResponseRejections.append((report.sampleID, reason))
            case let .evaluated(sample):
                if sample.isZeroProposal {
                    zeroProposalSamples.append(report.sampleID)
                }
                for edit in sample.edits {
                    bucketCounts[edit.bucket, default: 0] += 1
                    bucketReasonCounts[edit.bucket, default: [:]][edit.dispositionSummary, default: 0] += 1
                    if edit.bucket == .autonomouslyAccepted {
                        autonomouslyAcceptedDetail.append((report.sampleID, edit))
                    }
                }
            }
        }

        return Summary(
            tier: tier,
            sampleCount: reports.count,
            zeroProposalSamples: zeroProposalSamples,
            preflightFailures: preflightFailures,
            providerFailures: providerFailures,
            wholeResponseRejections: wholeResponseRejections,
            bucketCounts: bucketCounts,
            bucketReasonCounts: bucketReasonCounts,
            autonomouslyAcceptedDetail: autonomouslyAcceptedDetail
        )
    }

    static func render(_ summary: Summary) -> String {
        var lines: [String] = []
        lines.append("=== SUMMARY (tier=\(summary.tier), n=\(summary.sampleCount) samples) ===")
        lines.append("samples with zero proposals: \(summary.zeroProposalSamples.count) \(summary.zeroProposalSamples)")
        lines.append("pre-flight (span derivation) failures: \(summary.preflightFailures.count)")
        for failure in summary.preflightFailures {
            lines.append("  - \(failure.id): \(self.clean(failure.reason))")
        }
        lines.append("provider/transport failures (Intelligence never invoked): \(summary.providerFailures.count)")
        for failure in summary.providerFailures {
            lines.append("  - \(failure.id): \(self.clean(failure.reason))")
        }
        lines.append("whole-response rejections (malformed/unexpected shape): \(summary.wholeResponseRejections.count)")
        for failure in summary.wholeResponseRejections {
            lines.append("  - \(failure.id): \(self.clean(failure.reason))")
        }
        lines.append("")
        lines.append("edit-level outcomes across all evaluated samples:")
        for bucket in [IntelligenceHarnessBucket.autonomouslyAccepted, .reviewOnly, .rejectedBySafetyAuthority, .addressingRejected] {
            let count = summary.bucketCounts[bucket] ?? 0
            lines.append("  \(bucket.rawValue): \(count)")
            for (reason, reasonCount) in (summary.bucketReasonCounts[bucket] ?? [:]).sorted(by: { $0.key < $1.key }) {
                lines.append("    - \(self.clean(reason)): \(reasonCount)")
            }
        }
        lines.append("")
        lines.append("SAFETY HEADLINE: \(summary.bucketCounts[.autonomouslyAccepted] ?? 0) edit(s) reached autonomous acceptance across \(summary.sampleCount) sample(s).")
        lines.append("Every one is listed below for manual adjudication. Rejection/review-only rate is NOT a quality metric --")
        lines.append("only manual adjudication of each accepted edit (and of review-only edits, separately) determines correctness.")
        for detail in summary.autonomouslyAcceptedDetail {
            lines.append("  - [\(detail.sampleID)] \(detail.edit.id) \"\(detail.edit.modelEdit.sourceText)\" -> \"\(detail.edit.modelEdit.replacementText)\" (\(self.clean(detail.edit.dispositionSummary)))")
        }
        return lines.joined(separator: "\n")
    }
}
