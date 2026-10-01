import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// The live V1.23 runner: the ONLY file in this evaluation that links `LLMClient` and so the
/// only place the corpus can reach a model. **Built in V1.23A; deliberately not run.** It
/// refuses to make any inference unless, in order:
///   1. `--execute-manifest <sha256>` equals the manifest hash recomputed from the repository now
///      (the architect-approved, frozen manifest) -- there is no default and no override;
///   2. the working tree is clean (so the recorded HEAD fully identifies the measured code);
///   3. every preflight check passes (corpus hash, V1.21 hashes, scoring source, installed model);
///   4. the *running* Ollama reports the frozen version and serves a `granite4:3b` whose manifest
///      digest equals the frozen one (read-only GETs on /api/version and /api/tags; not inference);
///   5. `--out` is outside the Git repository.
/// One attempt per entry; `maxRetries` is forced to 1; nothing is retried or adjusted afterwards.
///
///   scripts/intelligence_v1_capability_run.sh --execute-manifest SHA256 --out DIR [--run-label TEXT]
@main
enum CapabilityLiveRunner {
    static func main() async {
        do {
            try await self.run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("refused/failed: \(error)\n".utf8))
            exit(1)
        }
    }

    struct Refusal: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) {
            self.description = description
        }
    }

    private static func run(arguments: [String]) async throws {
        var manifestHash: String?
        var out: String?
        var label = "V1.23 granite4:3b frozen capability evaluation"
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw Refusal("missing value for \(arguments[index])") }
            switch arguments[index] {
            case "--execute-manifest": manifestHash = arguments[index + 1]
            case "--out": out = arguments[index + 1]
            case "--run-label": label = arguments[index + 1]
            default: throw Refusal("unknown option \(arguments[index])")
            }
            index += 2
        }
        guard let manifestHash, let out else { throw Refusal("both --execute-manifest <sha256> and --out <dir> are required") }

        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        guard let toplevel = git(["rev-parse", "--show-toplevel"]), URL(fileURLWithPath: toplevel).resolvingSymlinksInPath().path == repoRoot.resolvingSymlinksInPath().path else {
            throw Refusal("run from the repository root")
        }
        let resolvedOut = URL(fileURLWithPath: out).resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedRoot = repoRoot.resolvingSymlinksInPath().standardizedFileURL.path
        if resolvedOut == resolvedRoot || resolvedOut.hasPrefix(resolvedRoot + "/") {
            throw Refusal("--out must be outside the Git repository")
        }
        guard self.git(["status", "--porcelain"])?.isEmpty ?? false else { throw Refusal("working tree is not clean; commit before the frozen run") }
        let head = self.git(["rev-parse", "HEAD"]) ?? "unknown"

        // Preflight (no network).
        var checks = CapabilityPreflight.contractChecks()
        checks.append(CapabilityPreflight.scoringSourceCheck(repoRoot: repoRoot))
        let corpusResult = CapabilityPreflight.corpusCheck(url: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
        checks.append(corpusResult.check)
        checks.append(contentsOf: CapabilityPreflight.installedModelChecks(modelsDirectory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ollama/models")))
        guard let corpus = corpusResult.corpus else { throw Refusal("corpus check failed: \(corpusResult.check.detail)") }
        let manifest = try CapabilityRunManifest.proposed(repoRoot: repoRoot, corpus: corpus)
        guard manifest.sha256 == manifestHash else { throw Refusal("manifest hash \(manifest.sha256) != approved \(manifestHash)") }

        // Read-only runtime identity probe (still no inference).
        let serverRoot = CapabilityFrozenRun.baseURL.replacingOccurrences(of: "/v1", with: "")
        let versionData = try await get(serverRoot + "/api/version")
        let tagsData = try await get(serverRoot + "/api/tags")
        let serverVersion = CapabilityPreflight.parseOllamaVersion(versionData)
        let servedDigest = CapabilityPreflight.parseInstalledDigest(tags: tagsData, model: CapabilityFrozenRun.modelName)
        checks.append(CapabilityPreflightCheck(name: "running Ollama version == frozen", passed: serverVersion == CapabilityFrozenRun.ollamaVersion, detail: serverVersion ?? "unparsed"))
        checks.append(CapabilityPreflightCheck(name: "served granite4:3b manifest digest == frozen", passed: servedDigest == CapabilityFrozenRun.ollamaManifestSHA256, detail: servedDigest ?? "not listed"))
        if let failing = checks.first(where: { !$0.passed }) {
            throw Refusal("preflight failed: \(failing.name) -- \(failing.detail)")
        }

        guard let processor = try? IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path) else { throw Refusal("legal pack unavailable") }
        let providerConfig = IntelligenceHarnessProvider.LocalProviderConfig(
            baseURL: CapabilityFrozenRun.baseURL,
            model: CapabilityFrozenRun.modelName,
            apiKey: "",
            timeoutSeconds: CapabilityFrozenRun.timeoutSeconds,
            maxRetries: CapabilityFrozenRun.maxRetries
        )
        let formatter = ISO8601DateFormatter()
        let started = formatter.string(from: Date())
        let trials = await CapabilityEvaluationDriver.run(corpus: corpus, processor: processor) { normalized in
            switch await IntelligenceHarnessProvider.propose(normalizedText: normalized, config: providerConfig) {
            case let .failure(reason): return .failure(reason)
            case let .success(response): return .success(IntelligenceProviderResponse(bridgingFrom: response))
            }
        }
        let finished = formatter.string(from: Date())

        var observations: [(key: String, value: String)] = [("git HEAD", head), ("working tree", "clean"), ("ollama version (served)", serverVersion ?? "")]
        if let psData = try? await get(serverRoot + "/api/ps") {
            observations.append(("ollama /api/ps after run", String(bytes: psData, encoding: .utf8) ?? ""))
        }
        let info = CapabilityRunInfo(runLabel: label, manifestSHA256: manifest.sha256, startedAt: started, finishedAt: finished, observations: observations)
        let metrics = CapabilityMetrics.aggregate(trials.map(\.adjudication))

        let stamp = finished.replacingOccurrences(of: ":", with: "")
        let directory = URL(fileURLWithPath: out).appendingPathComponent("v1.23-\(stamp)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try CapabilityReport.markdown(info: info, preflight: checks, trials: trials, metrics: metrics).write(to: directory.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
        try CapabilityReport.trialLogJSON(trials: trials).write(to: directory.appendingPathComponent("trials.json"))
        try manifest.prettyJSON.write(to: directory.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        print("wrote \(directory.path)")
        print("unsafe autonomously-accepted edits (scored entries): \(metrics.unsafeAutonomousEdits.count)")
    }

    private static func get(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw Refusal("bad URL \(urlString)") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        return try await URLSession.shared.data(for: request).0
    }

    private static func git(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
