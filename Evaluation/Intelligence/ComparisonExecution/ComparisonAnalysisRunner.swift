import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: offline analyzer.
///
/// Recomputes the full S3 report from a run's `records.jsonl` and the repository's frozen artifacts. No model,
/// no network, no `LLMClient`; reads only the pinned development corpus and hazard fixtures. Because scoring is
/// a pure function of the raw records, re-running this later can only reproduce the report, never reinterpret it.
///
///   scripts/intelligence_v1_comparison_s3_analyze.sh --records PATH --lifecycle PATH [--write PATH]
@main
enum ComparisonAnalysisRunner {
    static func main() {
        var records: String?
        var lifecyclePath: String?
        var write: String?
        var arguments = Array(CommandLine.arguments.dropFirst())[...]
        while let argument = arguments.popFirst() {
            switch argument {
            case "--records": records = arguments.popFirst()
            case "--lifecycle": lifecyclePath = arguments.popFirst()
            case "--write": write = arguments.popFirst()
            default:
                FileHandle.standardError.write(Data("unknown option \(argument)\n".utf8))
                exit(2)
            }
        }
        guard let records, let lifecyclePath else {
            FileHandle.standardError.write(Data("--records PATH and --lifecycle PATH are both required\n".utf8))
            exit(2)
        }
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        do {
            let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
            let plan = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: corpus)
            let text = try String(contentsOfFile: records, encoding: .utf8)
            let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
            let callRecords = try ComparisonRecordCoding.decode(jsonLines: text)
            let events = try ComparisonLifecycleCoding.decode(jsonLines: String(contentsOfFile: lifecyclePath, encoding: .utf8))
            let lifecycle = ComparisonLifecycleAudit.verify(events: events, records: callRecords, plan: plan)
            guard lifecycle.problems.isEmpty
            else { throw ComparisonAnalysis.AnalysisError.recordsDoNotMatchPlan("lifecycle verification failed: \(lifecycle.problems)") }
            let results = try ComparisonAnalysis.assemble(
                records: callRecords,
                plan: plan,
                corpus: corpus,
                processor: processor
            )
            let fixtures = try ComparisonFixtureReplay
                .load(from: repoRoot.appendingPathComponent(ComparisonExecutionPlan.directory).appendingPathComponent("hazard_fixture.json"))
            let replay = ComparisonFixtureReplay.replay(fixtures, processor: processor)
            let contained = replay.allSatisfy { $0.matchesExpectation && !$0.hazardAutonomouslyAccepted }
            guard let analysis = ComparisonAnalysis.screen(results: results, fixturesContained: contained)
            else { throw ComparisonAnalysis.AnalysisError.recordsDoNotMatchPlan("no baseline") }
            let markdown = ComparisonAnalysis.markdown(analysis, runLabel: "V1.29 S3 screening analysis", lifecycleLines: lifecycle.lines)
            print(markdown)
            if let write {
                try markdown.write(toFile: write, atomically: true, encoding: .utf8)
            }
        } catch {
            FileHandle.standardError.write(Data("refused/failed: \(error)\n".utf8))
            exit(1)
        }
    }
}
