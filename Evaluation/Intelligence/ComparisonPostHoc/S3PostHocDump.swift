import Foundation

/// Intelligence V1.30 -- S3 post-hoc detail dump (NON-PREREGISTERED, NON-SCORING).
///
/// Re-derives, for every S3 record, the per-edit journey (model proposal -> addressing -> disposition -> outcome) with the
/// committed, unmodified scoring chain (`ComparisonAnalysis.assemble`), and prints it as JSON so post-hoc questions can be
/// answered from evidence. It computes no gate, ranking or classification of its own and changes nothing: every value is read
/// from `ComparisonEntryScore`. No model, no network, no benchmark (same execution source set as the analyzer).
///
///   scripts/intelligence_v1_s3_posthoc.sh --records PATH [--write PATH]
@main
enum S3PostHocDump {
    static func main() {
        var records: String?
        var write: String?
        var arguments = Array(CommandLine.arguments.dropFirst())[...]
        while let argument = arguments.popFirst() {
            switch argument {
            case "--records": records = arguments.popFirst()
            case "--write": write = arguments.popFirst()
            default:
                FileHandle.standardError.write(Data("unknown option \(argument)\n".utf8))
                exit(2)
            }
        }
        guard let records else {
            FileHandle.standardError.write(Data("--records PATH is required\n".utf8))
            exit(2)
        }
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        do {
            let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
            let plan = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: corpus)
            let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
            let results = try ComparisonAnalysis.assemble(
                records: ComparisonRecordCoding.decode(jsonLines: String(contentsOfFile: records, encoding: .utf8)),
                plan: plan,
                corpus: corpus,
                processor: processor
            )
            var rows: [[String: Any]] = []
            for result in results {
                for score in result.screening + result.audit {
                    rows.append(self.row(score))
                }
            }
            let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
            if let write {
                try data.write(to: URL(fileURLWithPath: write))
            } else {
                print(String(bytes: data, encoding: .utf8) ?? "")
            }
        } catch {
            FileHandle.standardError.write(Data("refused/failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func row(_ score: ComparisonEntryScore) -> [String: Any] {
        let edits = score.adjudication.edits.map { edit -> [String: Any] in
            [
                "position": edit.position, "sourceText": edit.sourceText, "replacementText": edit.replacementText,
                "addressing": edit.addressingSummary, "disposition": edit.dispositionSummary, "bucket": edit.bucket.rawValue,
                "literalMatchesExpected": edit.literalMatchesExpected,
            ]
        }
        return [
            "candidate": score.record.candidateID, "phase": score.record.phase, "entry": score.entry.id, "category": score.entry.category,
            "expectation": score.entry.expectation, "manual": score.entry.manualAdjudicationOnly,
            "expectedCorrections": score.entry.expectedCorrections.map { ["source": $0.source, "replacement": $0.replacement] },
            "normalized": score.normalized ?? "", "trial": score.trialKind.rawValue, "failureDetail": score.adjudication.failureDetail ?? "",
            "toolCallNames": score.record.toolCallNames, "rawArguments": score.record.rawToolCallArguments,
            "freeText": score.record.modelTextContent ?? "", "providerFailure": score.record.providerFailure ?? "",
            "latencyMs": score.record.latencyMilliseconds ?? -1, "edits": edits,
            "autonomousFinal": score.autonomousFinal ?? "", "outcomeState": score.autonomousState?.rawValue ?? "n/a",
            "counterfactualState": score.counterfactualState?.rawValue ?? "n/a", "u0": score.exactPairViolations,
            "spanWidths": score.spanWidths.map(\.rawValue), "digitChanged": score.digitSequenceChanged,
        ]
    }
}
