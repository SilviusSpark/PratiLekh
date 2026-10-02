import Foundation

/// Intelligence V1.28 -- offline S1 identity verifier runner. Reads the committed S1 artifact and the
/// frozen V1.27 registry; with `--local` it also re-hashes the blobs under `~/.ollama/models`.
/// No Ollama contact, no model load, no corpus access.
///
///   scripts/intelligence_v1_comparison_s1_verify.sh [--local]
@main
enum AcquisitionVerifierRunner {
    static func main() {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var checks = AcquisitionVerifier.checks(repoRoot: repoRoot)
        if CommandLine.arguments.dropFirst().contains("--local") {
            let models = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ollama/models")
            checks.append(contentsOf: AcquisitionVerifier.localBlobChecks(repoRoot: repoRoot, modelsDirectory: models))
        }
        for check in checks {
            print("[\(check.passed ? "PASS" : "FAIL")] \(check.name): \(check.detail)")
        }
        print("\n\(checks.filter(\.passed).count)/\(checks.count) checks passed. No model was loaded; no corpus was read.")
        exit(checks.allSatisfy(\.passed) ? 0 : 1)
    }
}
