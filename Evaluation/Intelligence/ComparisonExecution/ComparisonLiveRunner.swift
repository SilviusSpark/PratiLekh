import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: the guarded S3 live runner.
///
/// **Built in S2; deliberately NOT run in S2.** It is the only entry point that can send the development corpus
/// to a model, and it refuses unless, in order:
///   1. `--execute-plan <sha256>` equals the plan hash recomputed from the repository now (the approved,
///      pre-registered plan -- no default, no override) and the committed `S3_PROPOSED_RUN_PLAN.json` equals it;
///   2. the working tree is clean (so the recorded HEAD fully identifies the measured code);
///   3. `--out` is outside the Git repository (records contain corpus text and model output);
///   4. the running Ollama reports the frozen version, no model is loaded, and `/api/tags` serves every
///      candidate with exactly the S1-verified manifest digest;
///   5. the stage is S3 with the unchanged V1.21 contract: there is no flag that selects the variant arm.
/// It cannot read the V1.23 benchmark: that loader is not compiled into this binary (see
/// `ComparisonExecutionEntryTypes.swift`). One attempt per step; nothing is retried, repeated, skipped or
/// adjusted in response to any output. `--preflight-only` performs checks 1-4 (read-only GETs) and stops.
///
///   scripts/intelligence_v1_comparison_s3_run.sh --execute-plan SHA256 --out DIR [--run-label TEXT] [--preflight-only]
@main
enum ComparisonLiveRunner {
    struct Refusal: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) {
            self.description = description
        }
    }

    static func main() async {
        do {
            try await self.run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("refused/failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(arguments: [String]) async throws {
        var planHash: String?
        var out: String?
        var label = "V1.29 S3 development-corpus screening"
        var preflightOnly = false
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--preflight-only":
                preflightOnly = true
                index += 1
            case "--execute-plan", "--out", "--run-label":
                guard index + 1 < arguments.count else { throw Refusal("missing value for \(arguments[index])") }
                switch arguments[index] {
                case "--execute-plan": planHash = arguments[index + 1]
                case "--out": out = arguments[index + 1]
                default: label = arguments[index + 1]
                }
                index += 2
            default: throw Refusal("unknown option \(arguments[index])")
            }
        }
        guard let planHash, let out else { throw Refusal("both --execute-plan <sha256> and --out <dir> are required") }

        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        guard let toplevel = git(["rev-parse", "--show-toplevel"]),
              URL(fileURLWithPath: toplevel).resolvingSymlinksInPath().path == repoRoot.resolvingSymlinksInPath().path
        else {
            throw Refusal("run from the repository root")
        }
        let resolvedOut = URL(fileURLWithPath: out).resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedRoot = repoRoot.resolvingSymlinksInPath().standardizedFileURL.path
        if resolvedOut == resolvedRoot || resolvedOut.hasPrefix(resolvedRoot + "/") {
            throw Refusal("--out must be outside the Git repository")
        }
        guard self.git(["status", "--porcelain"])?.isEmpty ?? false else { throw Refusal("working tree is not clean; commit before the frozen run") }
        let head = self.git(["rev-parse", "HEAD"]) ?? "unknown"

        // 1. Plan and its approval.
        let corpus = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
        let plan = try ComparisonExecutionPlan.build(repoRoot: repoRoot, corpus: corpus)
        let computed = try plan.sha256()
        guard computed == planHash else { throw Refusal("plan hash \(computed) != approved \(planHash)") }
        let committed = try String(contentsOf: repoRoot.appendingPathComponent(ComparisonExecutionPlan.proposedPlanPath), encoding: .utf8)
        guard try committed == (plan.prettyJSON()) else { throw Refusal("committed S3_PROPOSED_RUN_PLAN.json differs from the recomputed plan") }

        // 4. Runtime identity (read-only GETs; no inference).
        let serverRoot = ComparisonExecutionPlan.baseURL.replacingOccurrences(of: "/v1", with: "")
        let version = await (try? JSONSerialization.jsonObject(with: self.get(serverRoot + "/api/version")) as? [String: Any])?["version"] as? String
        guard version == ComparisonExecutionPlan.ollamaVersion
        else { throw Refusal("running Ollama version \(version ?? "unparsed") != \(ComparisonExecutionPlan.ollamaVersion)") }
        guard try await self.loadedModels(serverRoot).isEmpty
        else { throw Refusal("a model is already loaded; one model must be resident at a time") }
        let tags = await (try? JSONSerialization
            .jsonObject(with: self.get(serverRoot + "/api/tags")) as? [String: Any])?["models"] as? [[String: Any]] ?? []
        for candidate in plan.candidates {
            let digest = tags
                .first { ($0["name"] as? String) == candidate.ollamaTag || ($0["model"] as? String) == candidate.ollamaTag }?["digest"] as? String
            guard digest == candidate.manifestSHA256
            else { throw Refusal("\(candidate.ollamaTag): served digest \(digest ?? "not listed") != S1-verified \(candidate.manifestSHA256)") }
        }
        print("preflight passed: plan \(computed), HEAD \(head), \(plan.candidates.count) candidates, \(plan.steps.count) steps")
        if preflightOnly {
            return
        }

        // Execute.
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        let instructions = try ComparisonExecutionPlan.instructions(
            for: .baselineV121,
            baseline: ModelFacingGenerationContract.instructions,
            repoRoot: nil
        )
        let stamp = ComparisonExecutor.iso(Date()).replacingOccurrences(of: ":", with: "")
        let directory = URL(fileURLWithPath: out).appendingPathComponent("v1.29-S3-\(stamp)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recordsURL = directory.appendingPathComponent("records.jsonl")
        FileManager.default.createFile(atPath: recordsURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: recordsURL)
        try plan.prettyJSON().write(to: directory.appendingPathComponent("plan.json"), atomically: true, encoding: .utf8)
        let runInfo: [String: Any] = [
            "runLabel": label,
            "planSHA256": computed,
            "gitHEAD": head,
            "workingTree": "clean",
            "ollamaVersion": version ?? "",
            "startedAt": ComparisonExecutor.iso(Date()),
        ]
        try JSONSerialization.data(withJSONObject: runInfo, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appendingPathComponent("run_info.json"))

        // Lifecycle evidence (identity probes, resident checks, the keep_alive-0 unload and its verification) goes to its own
        // file and never into a proposer record, step sequence, count, latency or metric (see `ComparisonLifecycleAudit`).
        let runID = "v1.29-S3-\(stamp)"
        let lifecycleURL = directory.appendingPathComponent("lifecycle.jsonl")
        FileManager.default.createFile(atPath: lifecycleURL.path, contents: nil)
        let lifecycleHandle = try FileHandle(forWritingTo: lifecycleURL)
        var lifecycleSequence = 0
        // swiftlint:disable:next function_parameter_count
        func lifecycle(
            _ kind: ComparisonLifecycleEvent.Kind,
            candidate: ComparisonExecutionPlan.Candidate?,
            endpoint: String,
            body: String?,
            started: Date,
            status: Int?,
            resident: [String],
            observed: Bool,
            note: String? = nil
        ) {
            lifecycleSequence += 1
            let event = ComparisonLifecycleEvent(
                runID: runID,
                sequence: lifecycleSequence,
                kind: kind,
                candidateID: candidate?.id,
                ollamaTag: candidate?.ollamaTag,
                endpoint: endpoint,
                requestBody: body,
                startedAt: ComparisonExecutor.iso(started),
                finishedAt: ComparisonExecutor.iso(Date()),
                httpStatus: status,
                residentModelsAfter: resident,
                residentObserved: observed,
                countsAsInference: false,
                note: note
            )
            lifecycleHandle.write(Data((ComparisonLifecycleCoding.line(event) + "\n").utf8))
        }
        for path in ["/api/version", "/api/tags", "/api/ps"] {
            let began = Date()
            var resident: [String] = []
            if path == "/api/ps" {
                resident = try await self.loadedModels(serverRoot)
            } else {
                _ = try await self.get(serverRoot + path)
            }
            lifecycle(
                .identityProbe,
                candidate: nil,
                endpoint: "GET \(path)",
                body: nil,
                started: began,
                status: 200,
                resident: resident,
                observed: path == "/api/ps"
            )
        }

        var hooks = ComparisonExecutionHooks()
        hooks.candidateWillStart = { candidate in
            let began = Date()
            let resident = try await self.loadedModels(serverRoot)
            lifecycle(
                .residentCheck,
                candidate: candidate,
                endpoint: "GET /api/ps",
                body: nil,
                started: began,
                status: 200,
                resident: resident,
                observed: true
            )
            guard resident.isEmpty else { throw Refusal("a model is resident before the next candidate starts") }
        }
        hooks.runtimeObservation = { _ in
            await (try? self.get(serverRoot + "/api/ps")).flatMap { String(bytes: $0, encoding: .utf8) }
        }
        hooks.candidateDidFinish = { candidate in
            // Unload: `POST /api/generate` with `keep_alive` 0 and NO prompt. It is lifecycle, not inference: it is logged only
            // in lifecycle.jsonl (countsAsInference false), has no proposer record or step number, and is verified by an
            // empty /api/ps afterwards.
            guard let generateURL = URL(string: serverRoot + "/api/generate") else { throw Refusal("bad generate URL") }
            var request = URLRequest(url: generateURL)
            request.httpMethod = "POST"
            let body = ComparisonLifecycleCoding.unloadBody(tag: candidate.ollamaTag)
            request.httpBody = Data(body.utf8)
            request.timeoutInterval = 30
            let began = Date()
            let status = try await (URLSession.shared.data(for: request).1 as? HTTPURLResponse)?.statusCode
            lifecycle(
                .unloadRequest,
                candidate: candidate,
                endpoint: "POST /api/generate",
                body: body,
                started: began,
                status: status,
                resident: [],
                observed: false
            )
            let verifyBegan = Date()
            for _ in 0..<20 where try await !(self.loadedModels(serverRoot).isEmpty) {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            let resident = try await self.loadedModels(serverRoot)
            lifecycle(
                .unloadVerification,
                candidate: candidate,
                endpoint: "GET /api/ps",
                body: nil,
                started: verifyBegan,
                status: 200,
                resident: resident,
                observed: true
            )
            guard resident.isEmpty else { throw Refusal("\(candidate.ollamaTag) did not unload") }
        }
        try await ComparisonExecutor.execute(
            plan: plan,
            corpus: corpus,
            evidence: .developmentCorpus,
            processor: processor,
            runID: runID,
            instructions: instructions,
            proposer: ComparisonProvider.proposer(),
            hooks: hooks
        ) { record in
            handle.write(Data((ComparisonRecordCoding.line(record) + "\n").utf8))
        }
        try handle.close()
        try lifecycleHandle.close()
        print(
            "wrote \(directory.path)/records.jsonl; analyze offline with scripts/intelligence_v1_comparison_s3_analyze.sh --records \(directory.path)/records.jsonl --lifecycle \(directory.path)/lifecycle.jsonl"
        )
    }

    private static func loadedModels(_ serverRoot: String) async throws -> [String] {
        let object = try await JSONSerialization.jsonObject(with: self.get(serverRoot + "/api/ps")) as? [String: Any]
        return (object?["models"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
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
