import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// Model-free, network-free preflight. Verifies the frozen corpus hash, the V1.21 contract
/// hashes, the scoring-source hash and the locally installed `granite4:3b` files; derives
/// legal-normalized text + protected spans for every corpus entry through the real pipeline;
/// and prints the proposed immutable run manifest and its SHA-256. It never constructs a
/// provider, never links `LLMClient`, never contacts Ollama, and never exposes the corpus to a model.
///
///   scripts/intelligence_v1_capability_preflight.sh [--models-dir DIR] [--skip-blob-hash] [--write-manifest PATH]
@main
enum CapabilityPreflightRunner {
    static func main() {
        var modelsDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ollama/models")
        var skipBlobHash = false
        var manifestPath: String?
        var arguments = Array(CommandLine.arguments.dropFirst())[...]
        while let argument = arguments.popFirst() {
            switch argument {
            case "--models-dir": if let value = arguments.popFirst() {
                    modelsDirectory = URL(fileURLWithPath: value)
                }
            case "--skip-blob-hash": skipBlobHash = true
            case "--write-manifest": manifestPath = arguments.popFirst()
            default:
                FileHandle.standardError.write(Data("unknown option \(argument)\n".utf8))
                exit(2)
            }
        }

        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var checks = CapabilityPreflight.contractChecks()
        checks.append(CapabilityPreflight.scoringSourceCheck(repoRoot: repoRoot))
        let corpusResult = CapabilityPreflight.corpusCheck(url: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
        checks.append(corpusResult.check)
        var modelChecks = CapabilityPreflight.installedModelChecks(modelsDirectory: modelsDirectory, hashBlob: !skipBlobHash)
        if skipBlobHash {
            modelChecks.append(CapabilityPreflightCheck(name: "GGUF blob content SHA-256 == frozen", passed: true, detail: "skipped (--skip-blob-hash); size check only"))
        }
        checks.append(contentsOf: modelChecks)

        guard let corpus = corpusResult.corpus else {
            self.print(checks)
            exit(1)
        }
        guard let processor = try? IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path) else {
            Swift.print("FAIL: could not load the Indian Legal Core pack")
            exit(1)
        }
        let preflights = CapabilityEvaluationDriver.preflightAll(corpus: corpus, processor: processor)
        let failed = preflights.filter {
            if case .failure = $0.result {
                return true
            } else {
                return false
            }
        }
        checks.append(CapabilityPreflightCheck(
            name: "per-entry legal normalization + protected-span derivation (no model)",
            passed: failed.isEmpty,
            detail: "\(preflights.count - failed.count)/\(preflights.count) entries derived"
        ))
        self.print(checks)

        do {
            let manifest = try CapabilityRunManifest.proposed(repoRoot: repoRoot, corpus: corpus)
            Swift.print("\n--- proposed run manifest (status: proposed-not-executed) ---")
            Swift.print(manifest.prettyJSON)
            Swift.print("\nmanifest SHA-256 (over compact key-sorted JSON): \(manifest.sha256)")
            if let manifestPath {
                try manifest.prettyJSON.write(toFile: manifestPath, atomically: true, encoding: .utf8)
                Swift.print("wrote \(manifestPath)")
            }
        } catch {
            Swift.print("FAIL: \(error)")
            exit(1)
        }
        Swift.print("\nNo provider was constructed; no model was called; no network call was made.")
        exit(checks.allSatisfy(\.passed) ? 0 : 1)
    }

    private static func print(_ checks: [CapabilityPreflightCheck]) {
        for check in checks {
            Swift.print("[\(check.passed ? "PASS" : "FAIL")] \(check.name): \(check.detail)")
        }
    }
}
