import Foundation

struct RunMetadata: Codable, Equatable {
    let runID: String
    let startedAt: String
    let toolVersion: String
    let gitCommit: String?
    /// "localAPI" (audio transcribed via /v1/transcribe) or "textDir" (post-ASR text supplied).
    let source: String
    let apiBase: String?
    let referenceCount: Int
    let legalPackID: String
    let legalPackVersion: String
    /// The Local API does not expose app settings; nothing about them is claimed as captured.
    let settingsCaptured: Bool
    let limitations: [String]
}

struct ProvenanceRecord: Codable, Equatable {
    let kind: String
    let source: String
    let replacement: String?
    let rule: String?
    /// Indexes the input of the normalizer pass that produced it, not the final text.
    let rangeLocation: Int?
    let rangeLength: Int?
}

struct SampleRunRecord: Codable, Equatable {
    let id: String
    let category: String
    let tags: [String]
    let audioFile: String?
    /// As reported by the API (model display name), when the source was the Local API.
    let provider: String?
    let confidence: Float?
    let sampleCount: Int?
    let stages: [StageText]
    let observedNormalization: ObservedNormalization?
    let provenance: [ProvenanceRecord]
    let score: SampleScore?
    let error: String?
}

enum RunSummary {
    static func render(metadata: RunMetadata, records: [SampleRunRecord]) -> String {
        var lines: [String] = []
        let scored = records.compactMap(\.score)
        lines.append("PratiLekh judicial dictation evaluation \(metadata.toolVersion) - run \(metadata.runID)")
        lines.append("source: \(metadata.source)   samples: \(records.count) (scored: \(scored.count))   commit: \(metadata.gitCommit ?? "unknown")")
        lines.append("legal pack: \(metadata.legalPackID) \(metadata.legalPackVersion)   settings captured: \(metadata.settingsCaptured ? "yes" : "NO")")
        let providers = Set(records.compactMap(\.provider)).sorted()
        if !providers.isEmpty { lines.append("provider(s) reported by API: \(providers.joined(separator: ", "))") }
        lines.append("Stage 'postASRDeterministic' = provider text after filler removal, custom dictionary, spoken punctuation (not raw ASR).")
        lines.append("")

        lines.append("== Transcription error rates (micro-averaged; separate from legal accuracy) ==")
        for stage in orderedStages(scored) {
            let entries = scored.flatMap { $0.stageErrors }.filter { $0.stage == stage }
            let against = Set(entries.map(\.against)).sorted().joined(separator: "/")
            lines.append("\(stage) vs \(against): WER \(pct(entries.map(\.wer))), CER \(pct(entries.map(\.cer)))")
        }

        lines.append("")
        lines.append("== Legal-critical tokens (exact) ==")
        let tokenRecords = scored.flatMap { score in score.criticalTokens.map { (score.id, $0) } }
        lines.append("tokens scored: \(tokenRecords.count)")
        var transitionCounts: [String: [TokenTransition: Int]] = [:]
        for (_, token) in tokenRecords {
            for transition in token.transitions {
                transitionCounts["\(transition.fromStage) -> \(transition.toStage)", default: [:]][transition.transition, default: 0] += 1
            }
        }
        for key in transitionCounts.keys.sorted() {
            let counts = transitionCounts[key] ?? [:]
            let parts = ["preserved", "recovered", "unrecovered", "corrupted"].map { name in
                "\(name) \(counts[TokenTransition(rawValue: name) ?? .preserved] ?? 0)"
            }
            lines.append("\(key): \(parts.joined(separator: ", "))")
        }
        var corrupted: [String] = []
        for (id, token) in tokenRecords {
            for transition in token.transitions where transition.transition == .corrupted {
                corrupted.append(
                    "CORRUPTED [\(id)] \(token.type.rawValue) '\(token.expected)': \(transition.fromStage)(\(transition.fromState.rawValue)) -> \(transition.toStage)(\(transition.toState.rawValue))"
                )
            }
        }
        lines.append(corrupted.isEmpty ? "corrupted tokens: none" : "corrupted tokens (each listed):")
        lines.append(contentsOf: corrupted.map { "  " + $0 })

        lines.append("")
        lines.append("== Legal normalization outcomes ==")
        let findings = scored.flatMap { score in score.normalization.map { (score.id, $0) } }
        var kindCounts: [NormalizationOutcomeKind: Int] = [:]
        for (_, finding) in findings { kindCounts[finding.kind, default: 0] += 1 }
        let order: [NormalizationOutcomeKind] = [
            .correctApplication, .correctDecline, .correctNoCandidate, .missedOpportunity,
            .falsePositive, .incorrectTransformation, .notEvaluable,
        ]
        lines.append(order.map { "\($0.rawValue) \(kindCounts[$0] ?? 0)" }.joined(separator: ", "))
        let severe = findings.filter { $0.1.kind.isSevere }
        lines.append(severe.isEmpty ? "severe failures: none" : "SEVERE failures (each listed):")
        for (id, finding) in severe {
            lines.append("  \(finding.kind.rawValue.uppercased()) [\(id)] source '\(finding.source ?? "-")' expected '\(finding.expectedReplacement ?? "-")' observed '\(finding.observedReplacement ?? "-")': \(finding.detail)")
        }

        lines.append("")
        lines.append("== Formatting (punctuation/capitalization; separate from WER) ==")
        let formats = scored.compactMap(\.formatting)
        let comparable = formats.filter(\.comparable)
        lines.append("compared: \(comparable.count) of \(formats.count); case differences \(comparable.map(\.caseDifferences).reduce(0, +)), punctuation differences \(comparable.map(\.punctuationDifferences).reduce(0, +))")

        let failed = records.filter { $0.error != nil }
        if !failed.isEmpty {
            lines.append("")
            lines.append("== Samples that could not be run ==")
            lines.append(contentsOf: failed.map { "  [\($0.id)] \($0.error ?? "")" })
        }
        lines.append("")
        lines.append("Limitations: " + metadata.limitations.joined(separator: " | "))
        return lines.joined(separator: "\n") + "\n"
    }

    private static func orderedStages(_ scores: [SampleScore]) -> [String] {
        var seen: [String] = []
        for stage in scores.flatMap({ $0.stageErrors.map(\.stage) }) where !seen.contains(stage) { seen.append(stage) }
        return seen
    }

    private static func pct(_ rates: [ErrorRate]) -> String {
        let edits = rates.map(\.edits).reduce(0, +)
        let length = rates.map(\.referenceLength).reduce(0, +)
        guard length > 0 else { return "n/a" }
        return String(format: "%.1f%% (%d/%d)", Double(edits) / Double(length) * 100, edits, length)
    }
}
