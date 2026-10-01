import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// The live, model-capable runner. For each `<sampleID>.txt` file in
/// `--text-dir`: legal-normalize it, derive protected spans, call the
/// configured local provider through the existing, unmodified `LLMClient`,
/// and run the real response through the existing, unmodified
/// `IntelligenceEditComposition`/`IntelligenceSafetyAuthority` chain --
/// reporting every proposal's full journey for manual adjudication.
///
/// Applies nothing to any live transcript: this binary has no dictation
/// dependency at all (it does not import, reference, or compile against
/// `ContentView.swift` or any UI code) and writes only its own report.
///
/// Evidence-tier discipline: `--tier` is mandatory (`synthetic` or
/// `real-dictation`) and is stamped on every line of output and into the
/// `--out` filename, so a run's evidence tier is never ambiguous and two
/// tiers can never be silently combined in one invocation.
@main
enum IntelligenceHarnessRunner {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
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
        var tier: String?
        var textDir: String?
        var out: String?
        var baseURL = IntelligenceHarnessProvider.LocalProviderConfig.defaultBaseURL
        var model: String?
        var apiKey = ""
        var timeoutSeconds: TimeInterval?
    }

    private static let usage = """
    usage: intelligence_harness_run.sh --tier synthetic|real-dictation --text-dir DIR --model NAME \
    [--base-url URL] [--api-key KEY] [--timeout-seconds N] [--out DIR]
      --tier synthetic|real-dictation  the evidence tier this run's input text belongs to (mandatory;
                                        never mixed with the other tier in one run)
      --text-dir DIR     <sampleID>.txt raw dictation-like text, one sample per file; must be
                          outside the Git repository
      --model NAME        the provider's model name (e.g. granite4:3b)
      --base-url URL      OpenAI-compatible endpoint (default: \(IntelligenceHarnessProvider.LocalProviderConfig.defaultBaseURL), i.e. Ollama)
      --api-key KEY        optional; most local providers need none
      --timeout-seconds N  optional request timeout override
      --out DIR            optional; if given, the report is also written there (must be outside
                            the Git repository); the filename is stamped with --tier
    This harness never modifies live dictation: it has no ContentView/UI dependency at all.
    """

    private static func run(arguments: [String]) async throws {
        var options = Options()
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count else { throw RunnerError("missing value for \(arguments[index])\n\(usage)") }
            let value = arguments[index + 1]
            switch arguments[index] {
            case "--tier": options.tier = value
            case "--text-dir": options.textDir = value
            case "--out": options.out = value
            case "--base-url": options.baseURL = value
            case "--model": options.model = value
            case "--api-key": options.apiKey = value
            case "--timeout-seconds": options.timeoutSeconds = TimeInterval(value)
            default: throw RunnerError("unknown option \(arguments[index])\n\(usage)")
            }
            index += 2
        }
        guard let tier = options.tier, tier == "synthetic" || tier == "real-dictation" else {
            throw RunnerError("--tier must be exactly \"synthetic\" or \"real-dictation\"\n\(usage)")
        }
        guard let textDir = options.textDir else { throw RunnerError(usage) }
        guard let model = options.model else { throw RunnerError(usage) }

        let repoRoot = gitOutput(["rev-parse", "--show-toplevel"])
        try enforcePrivacy(paths: [("--text-dir", textDir), ("--out", options.out)], repoRoot: repoRoot)

        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot ?? FileManager.default.currentDirectoryPath)
        let providerConfig = IntelligenceHarnessProvider.LocalProviderConfig(
            baseURL: options.baseURL, model: model, apiKey: options.apiKey, timeoutSeconds: options.timeoutSeconds
        )

        let samples = try loadSamples(textDir: textDir)
        guard !samples.isEmpty else { throw RunnerError("no <sampleID>.txt files found in \(textDir)") }

        var reports: [IntelligenceHarnessSampleReport] = []
        var renderedSamples: [String] = []
        for (sampleID, rawText) in samples {
            let report = await evaluateOneSample(sampleID: sampleID, tier: tier, rawText: rawText, processor: processor, providerConfig: providerConfig)
            reports.append(report)
            let rendered = IntelligenceHarnessReportFormatter.render(report)
            renderedSamples.append(rendered)
            print(rendered)
            print("")
        }

        let summary = IntelligenceHarnessReportFormatter.render(IntelligenceHarnessReportFormatter.summarize(tier: tier, reports: reports))
        print(summary)

        if let out = options.out {
            try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
            let outPath = URL(fileURLWithPath: out).appendingPathComponent("intelligence-harness-\(tier)-\(stamp).txt").path
            let fullReport = (renderedSamples + [summary]).joined(separator: "\n\n")
            try fullReport.write(toFile: outPath, atomically: true, encoding: .utf8)
            print("\nwrote \(outPath)")
        }
    }

    private static func evaluateOneSample(
        sampleID: String,
        tier: String,
        rawText: String,
        processor: LegalDictationProcessor,
        providerConfig: IntelligenceHarnessProvider.LocalProviderConfig
    ) async -> IntelligenceHarnessSampleReport {
        switch IntelligenceHarnessPipeline.preflight(rawInputText: rawText, processor: processor) {
        case let .failure(reason):
            return IntelligenceHarnessSampleReport(
                sampleID: sampleID,
                tier: tier,
                rawInputText: rawText,
                legalNormalizedText: nil,
                modelTextContent: nil,
                modelRawToolCallArguments: [],
                outcome: .preflightFailure(reason.description)
            )
        case let .success(pre):
            switch await IntelligenceHarnessProvider.propose(normalizedText: pre.normalizedText, config: providerConfig) {
            case let .failure(reason):
                // Fail closed: no Intelligence/composition call happens on
                // this branch at all.
                return IntelligenceHarnessSampleReport(
                    sampleID: sampleID,
                    tier: tier,
                    rawInputText: rawText,
                    legalNormalizedText: pre.normalizedText,
                    modelTextContent: nil,
                    modelRawToolCallArguments: [],
                    outcome: .providerFailure(reason.description)
                )
            case let .success(llmResponse):
                let response = IntelligenceProviderResponse(bridgingFrom: llmResponse)
                let outcome: IntelligenceHarnessSampleOutcome
                switch IntelligenceHarnessPipeline.evaluate(response: response, normalizedText: pre.normalizedText, protectedSpans: pre.protectedSpans) {
                case let .failure(reason): outcome = .wholeResponseRejected(reason.description)
                case let .success(sample): outcome = .evaluated(sample)
                }
                return IntelligenceHarnessSampleReport(
                    sampleID: sampleID,
                    tier: tier,
                    rawInputText: rawText,
                    legalNormalizedText: pre.normalizedText,
                    modelTextContent: response.textContent,
                    modelRawToolCallArguments: response.toolCalls.map(\.rawArguments),
                    outcome: outcome
                )
            }
        }
    }

    private static func loadSamples(textDir: String) throws -> [(id: String, text: String)] {
        let url = URL(fileURLWithPath: textDir)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            throw RunnerError("could not read --text-dir \(textDir)")
        }
        return entries
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { file -> (id: String, text: String)? in
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
                return (file.deletingPathExtension().lastPathComponent, text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
    }

    private static func enforcePrivacy(paths: [(String, String?)], repoRoot: String?) throws {
        for (flag, path) in paths {
            guard let path, isInside(path, repoRoot: repoRoot) else { continue }
            throw RunnerError("\(flag) \(path) is inside the Git repository; private dictation text and results must stay outside it")
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
