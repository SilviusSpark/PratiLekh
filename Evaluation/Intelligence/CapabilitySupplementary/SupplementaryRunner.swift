import Foundation

/// Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation: offline runner.
/// Reads the hash-pinned V1.23 raw artifacts and the frozen corpus; makes no model call and no
/// network call; links no `LLMClient`. Prints (and optionally writes) the generated results report.
///
///   scripts/intelligence_v1_supplementary_outcome.sh [--write PATH]
@main
enum SupplementaryRunner {
    static func main() {
        var writePath: String?
        var arguments = Array(CommandLine.arguments.dropFirst())[...]
        while let argument = arguments.popFirst() {
            if argument == "--write" {
                writePath = arguments.popFirst()
            } else {
                FileHandle.standardError.write(Data("unknown option \(argument)\n".utf8))
                exit(2)
            }
        }
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        do {
            let corpus = try CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
            let trials = try SupplementaryArtifacts.loadTrials(repoRoot: repoRoot)
            let reportData = try SupplementaryArtifacts.verifiedData("report.md", expected: SupplementaryArtifacts.reportSHA256, repoRoot: repoRoot)
            _ = try SupplementaryArtifacts.verifiedData("manifest.json", expected: SupplementaryArtifacts.manifestFileSHA256, repoRoot: repoRoot)
            let reportText = String(bytes: reportData, encoding: .utf8) ?? ""
            let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
            let results = try SupplementaryEvaluator.evaluate(corpus: corpus, trials: trials, processor: processor)
            let markdown = SupplementaryReport.markdown(
                results: results,
                provenance: SupplementaryReport.Provenance(
                    corpusSHA256: corpus.sha256,
                    trialsSHA256: SupplementaryArtifacts.trialsSHA256,
                    reportSHA256: SupplementaryArtifacts.reportSHA256,
                    manifestFileSHA256: SupplementaryArtifacts.manifestFileSHA256,
                    v123ManifestSHA256: SupplementaryArtifacts.v123ManifestSHA256,
                    frozenHardCriterionLineConfirmed: reportText.contains(SupplementaryArtifacts.frozenHardCriterionLine)
                )
            )
            print(markdown)
            if let writePath {
                try markdown.write(toFile: writePath, atomically: true, encoding: .utf8)
                print("wrote \(writePath)")
            }
        } catch {
            FileHandle.standardError.write(Data("refused/failed: \(error)\n".utf8))
            exit(1)
        }
    }
}
