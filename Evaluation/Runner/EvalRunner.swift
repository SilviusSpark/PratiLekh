import Foundation

/// Standalone evaluation runner. Build and run via scripts/eval_run.sh.
///
/// For each reference it obtains the post-ASR deterministic text either from
/// the Local API (`/v1/transcribe`, fixed audio) or from a directory of text
/// files, replays it through the real `LegalDictationProcessor`, scores every
/// observable stage, and writes per-sample JSON plus a text summary.
@main
enum EvalRunner {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch let error as RunnerError {
            FileHandle.standardError.write(Data("error: \(error.message)\n".utf8))
            exit(error.code)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    struct RunnerError: Error {
        let message: String
        let code: Int32
        init(_ message: String, code: Int32 = 2) {
            self.message = message
            self.code = code
        }
    }

    private struct Options {
        var references = "Evaluation/References/synthetic"
        var audio: String?
        var textDir: String?
        var out: String?
        var apiBase = "http://127.0.0.1:47733"
    }

    private static let usage = """
    usage: eval_run.sh --out DIR (--audio DIR | --text-dir DIR) [--references DIR] [--api-base URL]
      --audio DIR      fixed audio named <sampleID>.<wav|m4a|mp3|flac|caf|aiff>, transcribed via the Local API
      --text-dir DIR   <sampleID>.txt post-ASR text (offline; no app needed)
      --out DIR        results directory (must be outside the Git repository)
    The Local API must be enabled in the running app (it is off by default); this tool never changes it.
    """

    private static func run(arguments: [String]) throws {
        var options = Options()
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw RunnerError("missing value for \(arguments[index])\n\(usage)") }
            let value = arguments[index + 1]
            switch arguments[index] {
            case "--references": options.references = value
            case "--audio": options.audio = value
            case "--text-dir": options.textDir = value
            case "--out": options.out = value
            case "--api-base": options.apiBase = value
            default: throw RunnerError("unknown option \(arguments[index])\n\(usage)")
            }
            index += 2
        }
        guard let out = options.out, (options.audio == nil) != (options.textDir == nil) else { throw RunnerError(usage) }

        let repoRoot = gitOutput(["rev-parse", "--show-toplevel"])
        try enforcePrivacy(paths: [("--out", out), ("--audio", options.audio), ("--text-dir", options.textDir)], repoRoot: repoRoot)

        let references = try loadReferences(directory: options.references, repoRoot: repoRoot)
        let pack = try loadPack(repoRoot: repoRoot)
        let processor = LegalDictationProcessor(builtinPack: pack)

        let runID = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let metadata = RunMetadata(
            runID: runID,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            toolVersion: "3E.1",
            gitCommit: gitOutput(["rev-parse", "--short", "HEAD"]),
            source: options.audio != nil ? "localAPI" : "textDir",
            apiBase: options.audio != nil ? options.apiBase : nil,
            referenceCount: references.count,
            legalPackID: pack.id,
            legalPackVersion: pack.version,
            settingsCaptured: false,
            limitations: [
                "postASRDeterministic includes filler removal, custom dictionary and spoken punctuation; raw provider text is not observable",
                "app settings (dictionary entries, boosting, model options) are not exposed by the Local API and are not recorded",
                "post-legal formatting, AI and final-output stages are not evaluated in 3E.1",
                "critical tokens are presence-based per sample",
            ]
        )

        var records: [SampleRunRecord] = []
        for reference in references {
            records.append(evaluate(reference, options: options, processor: processor))
        }

        let runDirectory = URL(fileURLWithPath: out).appendingPathComponent(runID)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: runDirectory.appendingPathComponent("run.json"))
        for record in records {
            try encoder.encode(record).write(to: runDirectory.appendingPathComponent("\(record.id).result.json"))
        }
        let summary = RunSummary.render(metadata: metadata, records: records)
        try summary.write(to: runDirectory.appendingPathComponent("summary.txt"), atomically: true, encoding: .utf8)
        print(summary)
        print("results: \(runDirectory.path)")
        if records.contains(where: { $0.error != nil }) { exit(3) }
    }

    // MARK: - Per sample

    private static func evaluate(_ reference: EvaluationReference, options: Options, processor: LegalDictationProcessor) -> SampleRunRecord {
        func failure(_ message: String, audio: String? = nil) -> SampleRunRecord {
            SampleRunRecord(
                id: reference.id,
                category: reference.category,
                tags: reference.tags,
                audioFile: audio,
                provider: nil,
                confidence: nil,
                sampleCount: nil,
                stages: [],
                observedNormalization: nil,
                provenance: [],
                score: nil,
                error: message
            )
        }

        var postASR: String
        var provider: String?
        var confidence: Float?
        var sampleCount: Int?
        var audioName: String?
        if let audioDirectory = options.audio {
            guard let audioURL = findAudio(id: reference.id, in: audioDirectory) else { return failure("no audio file for this sample") }
            audioName = audioURL.lastPathComponent
            do {
                let response = try transcribe(fileURL: audioURL, apiBase: options.apiBase)
                postASR = response.text
                provider = response.provider
                confidence = response.confidence
                sampleCount = response.sampleCount
            } catch {
                return failure("transcription failed: \(error)", audio: audioName)
            }
        } else if let textDirectory = options.textDir {
            let url = URL(fileURLWithPath: textDirectory).appendingPathComponent("\(reference.id).txt")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return failure("no text file for this sample") }
            postASR = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return failure("no input source")
        }

        let outcome = processor.process(postASR)
        let observed = ObservedNormalization(
            input: postASR,
            output: outcome.normalized,
            applied: outcome.appliedChanges.map { .init(source: $0.trigger, replacement: $0.replacement) },
            declinedSources: outcome.declinedChanges.map(\.trigger)
        )
        var provenance: [ProvenanceRecord] = outcome.appliedChanges.map {
            ProvenanceRecord(
                kind: "applied",
                source: $0.trigger,
                replacement: $0.replacement,
                rule: $0.sourcePackID,
                rangeLocation: $0.range?.location,
                rangeLength: $0.range?.length
            )
        }
        provenance += outcome.declinedChanges.map {
            ProvenanceRecord(
                kind: "declined",
                source: $0.trigger,
                replacement: nil,
                rule: $0.reason,
                rangeLocation: $0.range?.location,
                rangeLength: $0.range?.length
            )
        }
        let stages = [
            StageText(stage: EvaluationStage.postASRDeterministic, text: postASR),
            StageText(stage: EvaluationStage.legalNormalized, text: outcome.normalized),
        ]
        return SampleRunRecord(
            id: reference.id,
            category: reference.category,
            tags: reference.tags,
            audioFile: audioName,
            provider: provider,
            confidence: confidence,
            sampleCount: sampleCount,
            stages: stages,
            observedNormalization: observed,
            provenance: provenance,
            score: SampleScoring.score(reference: reference, stages: stages, observed: observed),
            error: nil
        )
    }

    // MARK: - Inputs

    private static func loadReferences(directory: String, repoRoot: String?) throws -> [EvaluationReference] {
        let url = URL(fileURLWithPath: directory)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            throw RunnerError("cannot read references directory \(directory)")
        }
        var references: [EvaluationReference] = []
        var problems: [String] = []
        let insideRepo = isInside(url.path, repoRoot: repoRoot)
        for name in names.sorted() where name.hasSuffix(".json") {
            do {
                let reference = try EvaluationReference.load(from: url.appendingPathComponent(name))
                var found = reference.validate().map { "\(name): \($0)" }
                if insideRepo && reference.tier != "synthetic" { found.append("\(name): non-synthetic reference inside the Git repository") }
                if name != "\(reference.id).json" { found.append("\(name): file name must be <id>.json") }
                problems += found
                references.append(reference)
            } catch {
                problems.append("\(name): \(error)")
            }
        }
        if !problems.isEmpty { throw RunnerError("invalid references:\n  " + problems.joined(separator: "\n  ")) }
        if references.isEmpty { throw RunnerError("no reference .json files in \(directory)") }
        let duplicates = Dictionary(grouping: references, by: \.id).filter { $1.count > 1 }.keys
        if !duplicates.isEmpty { throw RunnerError("duplicate sample ids: \(duplicates.sorted().joined(separator: ", "))") }
        return references
    }

    private static func loadPack(repoRoot: String?) throws -> LanguagePack {
        let root = repoRoot ?? FileManager.default.currentDirectoryPath
        let resources = URL(fileURLWithPath: root).appendingPathComponent("Sources/Fluid/Resources").path
        guard let bundle = Bundle(path: resources), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            throw RunnerError("could not load the Indian Legal Core pack from \(resources) (run from the repository root)")
        }
        return pack
    }

    private static func findAudio(id: String, in directory: String) -> URL? {
        for ext in ["wav", "m4a", "mp3", "flac", "caf", "aiff"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(id).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // MARK: - Local API

    private struct TranscribeResponse: Decodable {
        let text: String
        let confidence: Float
        let sampleCount: Int
        let provider: String
    }

    private static func transcribe(fileURL: URL, apiBase: String) throws -> TranscribeResponse {
        guard let url = URL(string: apiBase + "/v1/transcribe") else { throw RunnerError("bad --api-base") }
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": fileURL.standardizedFileURL.path])

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error> = .failure(RunnerError("no response"))
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failure(RunnerError("HTTP \(http.statusCode): \(String(data: data ?? Data(), encoding: .utf8) ?? "")"))
            } else {
                result = .success(data ?? Data())
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return try JSONDecoder().decode(TranscribeResponse.self, from: result.get())
    }

    // MARK: - Privacy / git helpers

    /// Private audio, text and results must live outside the repository.
    private static func enforcePrivacy(paths: [(String, String?)], repoRoot: String?) throws {
        for (flag, path) in paths {
            guard let path, isInside(path, repoRoot: repoRoot) else { continue }
            throw RunnerError("\(flag) \(path) is inside the Git repository; private audio and results must stay outside it")
        }
    }

    private static func isInside(_ path: String, repoRoot: String?) -> Bool {
        guard let repoRoot else { return false }
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        let root = URL(fileURLWithPath: repoRoot).resolvingSymlinksInPath().standardizedFileURL.path
        return resolved == root || resolved.hasPrefix(root + "/")
    }

    private static func gitOutput(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }
}
