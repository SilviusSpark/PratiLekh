import Foundation

/// Intelligence V1.27 -- Model Comparison Development Corpus & Protocol: offline freeze runner.
/// Verifies and content-addresses the pre-registered comparison artifacts. Makes no model call,
/// no network call and downloads nothing; it reads the frozen benchmark only for the text-level
/// overlap check.
///
///   scripts/intelligence_v1_comparison_freeze.sh [--write]   (writes FREEZE_MANIFEST.json next to the artifacts)
@main
enum ComparisonFreezeRunner {
    static func main() {
        let write = CommandLine.arguments.dropFirst().contains("--write")
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let directory = repoRoot.appendingPathComponent(ComparisonFreeze.directory)
        var checks: [CapabilityPreflightCheck] = []
        do {
            let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
            let fixtures = try ComparisonFixtureReplay.load(from: directory.appendingPathComponent("hazard_fixture.json"))
            let frozen = try CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
            let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
            checks.append(CapabilityPreflightCheck(name: "development corpus SHA-256 + composition", passed: true, detail: "\(corpus.sha256) (\(corpus.entries.count) entries)"))
            checks.append(CapabilityPreflightCheck(name: "frozen benchmark SHA-256 (read for overlap check only)", passed: true, detail: frozen.sha256))
            let summary = ComparisonFreeze.overlap(corpus: corpus, fixtures: fixtures, frozen: frozen.entries)
            checks.append(CapabilityPreflightCheck(name: "overlap check vs frozen benchmark (P1-P7)", passed: summary.violations.isEmpty, detail: "\(summary.subjectsChecked) subjects, \(summary.violations.count) violation(s)"))
            checks.append(CapabilityPreflightCheck(name: "development-internal duplicates", passed: summary.internalDuplicates.isEmpty, detail: "\(summary.internalDuplicates.count)"))
            let results = ComparisonFixtureReplay.replay(fixtures, processor: processor)
            let contained = results.allSatisfy(\.matchesExpectation) && !results.contains(where: \.hazardAutonomouslyAccepted)
            checks.append(CapabilityPreflightCheck(name: "stored hazard fixtures replayed through the real chain (no model)", passed: contained, detail: "\(results.filter(\.matchesExpectation).count)/\(results.count) as expected"))
            checks.append(contentsOf: ComparisonFreeze.contractChecks(repoRoot: repoRoot))
            checks.append(contentsOf: ComparisonFreeze.candidateChecks(repoRoot: repoRoot))
            checks.append(contentsOf: ComparisonFreeze.protocolChecks(repoRoot: repoRoot, corpus: corpus))
            for check in checks {
                print("[\(check.passed ? "PASS" : "FAIL")] \(check.name): \(check.detail)")
            }
            for result in results where !result.matchesExpectation || result.hazardAutonomouslyAccepted {
                print("  FIXTURE \(result.fixture.id) (\(result.fixture.kind)): expected \(result.fixture.expect.map { "\($0.bucket)/\($0.reasonAnyOf)" }) observed \(result.observed) \(result.failure ?? "")")
            }
            for violation in summary.violations {
                print("  VIOLATION \(violation.rule.rawValue) \(violation.subjectID) vs \(violation.against): \(violation.detail)")
            }
            let manifest = ComparisonFreeze.manifest(repoRoot: repoRoot, corpus: corpus, summary: summary, fixtureCount: results.count, allFixturesContained: contained)
            let canonical = ComparisonFreeze.canonical(manifest)
            print("\nfreeze manifest SHA-256: \(CapabilitySHA256.hex(canonical))")
            if write {
                let pretty = (try? JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])) ?? Data()
                try pretty.write(to: directory.appendingPathComponent(ComparisonFreeze.manifestName))
                print("wrote \(ComparisonFreeze.directory)/\(ComparisonFreeze.manifestName)")
            }
            print("No model was called, nothing was downloaded, no network call was made.")
            exit(checks.allSatisfy(\.passed) ? 0 : 1)
        } catch {
            FileHandle.standardError.write(Data("failed: \(error)\n".utf8))
            exit(1)
        }
    }
}
