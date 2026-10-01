import CryptoKit
import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// The immutable run manifest: everything needed to reproduce and interpret one V1.23
/// evaluation, content-addressed so it cannot drift silently. The manifest deliberately holds
/// *no git commit* (a commit that includes this file would change the manifest -- circular);
/// instead it pins the SHA-256 of every source file that determines the measurement, and the
/// run report separately records HEAD and working-tree state at execution time.
enum CapabilityFrozenRun {
    static let manifestSchemaVersion = 1
    static let milestone = "V1.23"

    // MARK: - Contract identity (V1.21 production contract; independently pinned by its own tests)

    /// V1.19 Arm B / V1.21 production instructions.
    static let instructionsSHA256 = "249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88"
    /// `JSONSerialization` (`.sortedKeys`) of `ModelFacingGenerationContract.toolDefinition`;
    /// identical to the V1.18/V1.19/V1.20 recorded value (reproduced at V1.23A).
    static let toolDefinitionSHA256 = "d7a7cc2347d9f9f2b21561e0073f5fef183125edca916f658f9e62130265cc98"
    /// The README is the adjudication/metric source of truth (Sec.4/Sec.5); any edit to it after
    /// freeze must be a deliberate, reviewed re-pin -- never a quiet one.
    static let scoringREADMESHA256 = "8a7e06c4123872b928420038274bf0a74fff244a90288ac90ad9260efe8fd39d"
    static let scoringREADMEPath = "Evaluation/References/intelligence-v1-capability/README.md"

    // MARK: - Model identity (as installed locally at V1.23A inspection; no server was running)

    static let modelName = "granite4:3b"
    /// SHA-256 of the Ollama manifest file for `granite4:3b` (the value `ollama list` shows as ID, truncated).
    static let ollamaManifestSHA256 = "89962fcc75239ac434cdebceb6b7e0669397f92eaef9c487774b718bc36a3e5f"
    static let ggufBlobSHA256 = "6c02683809a8dc4eb05c78d44bc63bcd707703b078998fa58829c858ab337bb0"
    static let ggufBlobSizeBytes = 2_099_502_528
    static let configBlobSHA256 = "ba32b08db168051148743c54d446b8b0d82d112ced661edc21b070d3038f6ff1"
    static let templateBlobSHA256 = "0f6ec9740c765c3fb0dc38fe25f4d283c3bc1ede32b76f81c3a971daef20f76c"
    static let licenseBlobSHA256 = "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
    static let ollamaManifestRelativePath = "registry.ollama.ai/library/granite4/3b"

    // MARK: - Runtime / request (frozen)

    static let ollamaVersion = "0.34.4"
    static let baseURL = "http://localhost:11434/v1"
    static let temperature = 0.0
    /// Effective hard ceiling: `LLMClient.shared`'s URLSession caps the whole resource at 60 s
    /// regardless of `Config.timeoutSeconds`, so 60 is the largest value that can be honored.
    static let timeoutSeconds = 60.0
    static let maxRetries = 1
    static let attemptsPerEntry = 1

    /// Source files whose content determines the measurement. Hashed into the manifest.
    static let measurementSourcePaths = [
        "Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift",
        "Sources/Fluid/Intelligence/Transport/ModelFacingEditTransportParser.swift",
        "Sources/Fluid/Intelligence/Generation/ModelFacingResponseAdapter.swift",
        "Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift",
        "Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingBridge.swift",
        "Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift",
        "Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift",
        "Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift",
        "Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift",
        "Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift",
        "Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift",
        "Sources/Fluid/Services/LLMClient.swift",
        "Sources/Fluid/Resources/indian_legal_core.default.json",
        "Evaluation/Intelligence/Harness/IntelligenceHarnessPipeline.swift",
        "Evaluation/Intelligence/Harness/IntelligenceHarnessProvider.swift",
        "Evaluation/Intelligence/Harness/IntelligenceHarnessTypes.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityCorpus.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityAdjudication.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityMetrics.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityEvaluationDriver.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityManifest.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityReport.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityLiveRunner.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityPreflightRunner.swift",
    ]
}

struct CapabilityRunManifest {
    /// Canonical, JSON-compatible content. Built only by `proposed(repoRoot:corpus:)`.
    let content: [String: Any]

    /// Compact, key-sorted JSON -- the exact bytes that are hashed.
    var canonicalJSON: Data {
        (try? JSONSerialization.data(withJSONObject: self.content, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
    }

    var sha256: String {
        CapabilitySHA256.hex(self.canonicalJSON)
    }

    var prettyJSON: String {
        let data = (try? JSONSerialization.data(withJSONObject: self.content, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    enum BuildError: Error, CustomStringConvertible {
        case unreadableSource(String)
        var description: String {
            switch self {
            case let .unreadableSource(path): return "cannot read measurement source \(path)"
            }
        }
    }

    static func proposed(repoRoot: URL, corpus: CapabilityCorpus) throws -> CapabilityRunManifest {
        var sourceHashes: [String: String] = [:]
        for path in CapabilityFrozenRun.measurementSourcePaths {
            guard let data = try? Data(contentsOf: repoRoot.appendingPathComponent(path)) else { throw BuildError.unreadableSource(path) }
            sourceHashes[path] = CapabilitySHA256.hex(data)
        }
        let nullValue: Any = NSNull()
        let content: [String: Any] = [
            "manifestSchemaVersion": CapabilityFrozenRun.manifestSchemaVersion,
            "milestone": CapabilityFrozenRun.milestone,
            "status": "proposed-not-executed",
            "purpose": "Evaluation only: run granite4:3b under the committed V1.21 contract against the frozen 44-entry corpus, unmodified. No tuning, no retries.",
            "corpus": [
                "path": CapabilityCorpus.relativePath,
                "sha256": corpus.sha256,
                "entryCount": corpus.entries.count,
                "scoredEntries": corpus.scoredEntries.count,
                "manualAdjudicationOnlyEntries": corpus.manualEntries.map(\.id),
                "scoredCorrectionWarrantedEntries": corpus.scoredCorrectionWarrantedEntries.count,
                "perCorrectionDenominator": corpus.perCorrectionDenominator,
                "scoredAbstentionExpectedEntries": corpus.scoredAbstentionExpectedEntries.count,
                "tier": "synthetic",
            ] as [String: Any],
            "scoring": [
                "adjudicationAndMetricsSource": CapabilityFrozenRun.scoringREADMEPath,
                "adjudicationAndMetricsSourceSHA256": CapabilityFrozenRun.scoringREADMESHA256,
                "correctnessRule": "exact case-sensitive (sourceText, replacementText) pair equality against expectedCorrections; no fuzzy matching",
                "manualEntriesAutoScored": false,
                "addressingRejectedEditsGivenCorrectnessLabel": false,
                "autonomousEditsOnManualEntries": "listed raw for human adjudication; not scored; hard criterion not considered met until reviewed",
                "providerAndProtocolFailuresInDenominators": true,
                "blendedScore": false,
                "hardCriterion": "unsafe autonomously-accepted edits on scored entries == 0 (raw count)",
            ] as [String: Any],
            "measurementSourceSHA256": sourceHashes,
            "contract": [
                "instructionsSHA256": CapabilityFrozenRun.instructionsSHA256,
                "toolDefinitionSHA256": CapabilityFrozenRun.toolDefinitionSHA256,
                "toolDefinitionHashMethod": "JSONSerialization.data(withJSONObject: ModelFacingGenerationContract.toolDefinition, options: [.sortedKeys])",
                "toolName": ModelFacingGenerationContract.toolName,
            ] as [String: Any],
            "model": [
                "name": CapabilityFrozenRun.modelName,
                "ollamaManifestSHA256": CapabilityFrozenRun.ollamaManifestSHA256,
                "ggufBlobSHA256": CapabilityFrozenRun.ggufBlobSHA256,
                "ggufBlobSizeBytes": CapabilityFrozenRun.ggufBlobSizeBytes,
                "configBlobSHA256": CapabilityFrozenRun.configBlobSHA256,
                "templateBlobSHA256": CapabilityFrozenRun.templateBlobSHA256,
                "licenseBlobSHA256": CapabilityFrozenRun.licenseBlobSHA256,
                "family": "granite", "ggufGeneralName": "Granite 4.0 Micro", "parameterSize": "3.4B",
                "quantization": "Q4_K_M", "ggufFileType": 15, "ggufContextLengthTrained": 131_072,
                "modelfileParameterOverrides": "none (manifest has no params layer)",
            ] as [String: Any],
            "runtime": [
                "ollamaVersion": CapabilityFrozenRun.ollamaVersion,
                "baseURL": CapabilityFrozenRun.baseURL,
                "endpoint": "POST /v1/chat/completions",
                "observedServerDefaults": [
                    "source": "`ollama serve` 0.34.4 startup config log, metadata inspection at V1.23A (no model loaded, no generation)",
                    "defaultNumCtx": 4096,
                    "defaultNumCtxNote": "vram-based default (Apple M1, Metal, 5.3 GiB); not sent by the harness; /api/ps after the run records the loaded value",
                    "keepAlive": "5m0s", "numParallel": 1, "maxLoadedModels": 0, "flashAttention": false, "contextLengthEnv": 0,
                    "ollamaEnvironmentOverrides": "none (all OLLAMA_* values at defaults)",
                ] as [String: Any],
                "modelIdentityVerifiedViaAPI": "GET /api/tags digest for granite4:3b == ollamaManifestSHA256; POST /api/show template sha256 == templateBlobSHA256, no parameters",
            ] as [String: Any],
            "request": [
                "client": "LLMClient.shared via IntelligenceHarnessProvider.makeLLMConfig (V1.17 harness, unmodified request shape)",
                "stream": false, "temperature": CapabilityFrozenRun.temperature, "toolChoice": "auto",
                "maxTokens": nullValue, "extraParameters": [String: String](), "apiKeySent": false,
                "messages": "[system: ModelFacingGenerationContract.instructions, user: <entry legalNormalized text>]",
                "tools": "[ModelFacingGenerationContract.toolDefinition]",
                "timeoutSeconds": CapabilityFrozenRun.timeoutSeconds,
                "timeoutNote": "LLMClient.shared's transport session also hard-caps total resource time at 60 s (timeoutIntervalForResource = 2 x default 30 s); 60 is the maximum honorable value",
                "notSentSoRuntimeDefaultsApply": ["seed", "top_p", "top_k", "num_ctx", "num_predict", "repeat_penalty", "keep_alive", "min_p"],
            ] as [String: Any],
            "methodology": [
                "attemptsPerEntry": CapabilityFrozenRun.attemptsPerEntry,
                "retries": 0,
                "llmClientMaxRetries": CapabilityFrozenRun.maxRetries,
                "llmClientMaxRetriesNote": "LLMClient.Config defaults to 3 attempts on transient URLErrors (timeout, connection lost/refused, DNS). "
                    + "The V1.17 harness never overrode it. V1.23 sets 1 so a timeout is a recorded failure, not a silent re-submission.",
                "order": "corpus order (as committed)",
                "concurrency": 1,
                "providerFailure": "counted as failure; entry not retried; run continues",
                "selectiveRetries": false, "promptOrSchemaOrPolicyChangesAfterResults": false, "benchmarkRepair": false,
                "benchmarkDefectsDiscovered": "disclosed and qualified in the run report, never repaired",
                "inferencesPerRun": corpus.entries.count,
            ] as [String: Any],
        ]
        return CapabilityRunManifest(content: content)
    }
}

// MARK: - Preflight checks (no model, no network)

struct CapabilityPreflightCheck {
    let name: String
    let passed: Bool
    let detail: String
}

enum CapabilityPreflight {
    static func contractChecks() -> [CapabilityPreflightCheck] {
        let instructions = CapabilitySHA256.hex(of: ModelFacingGenerationContract.instructions)
        let toolData = (try? JSONSerialization.data(withJSONObject: ModelFacingGenerationContract.toolDefinition, options: [.sortedKeys])) ?? Data()
        let tool = CapabilitySHA256.hex(toolData)
        return [
            CapabilityPreflightCheck(name: "V1.21 production instructions SHA-256", passed: instructions == CapabilityFrozenRun.instructionsSHA256, detail: instructions),
            CapabilityPreflightCheck(name: "V1.21 tool definition SHA-256 (sortedKeys)", passed: tool == CapabilityFrozenRun.toolDefinitionSHA256, detail: tool),
        ]
    }

    static func corpusCheck(url: URL) -> (check: CapabilityPreflightCheck, corpus: CapabilityCorpus?) {
        do {
            let corpus = try CapabilityCorpus.load(from: url)
            return (CapabilityPreflightCheck(name: "frozen corpus SHA-256 + structure", passed: true, detail: "\(corpus.sha256) (\(corpus.entries.count) entries)"), corpus)
        } catch {
            return (CapabilityPreflightCheck(name: "frozen corpus SHA-256 + structure", passed: false, detail: "\(error)"), nil)
        }
    }

    static func scoringSourceCheck(repoRoot: URL) -> CapabilityPreflightCheck {
        guard let data = try? Data(contentsOf: repoRoot.appendingPathComponent(CapabilityFrozenRun.scoringREADMEPath)) else {
            return CapabilityPreflightCheck(name: "scoring/adjudication source (README) SHA-256", passed: false, detail: "unreadable")
        }
        let actual = CapabilitySHA256.hex(data)
        return CapabilityPreflightCheck(name: "scoring/adjudication source (README) SHA-256", passed: actual == CapabilityFrozenRun.scoringREADMESHA256, detail: actual)
    }

    /// Verifies the locally installed `granite4:3b` files against the frozen identity. Reads files
    /// only -- never contacts Ollama. `modelsDirectory` is normally `~/.ollama/models`.
    static func installedModelChecks(modelsDirectory: URL, hashBlob: Bool = true) -> [CapabilityPreflightCheck] {
        let manifestURL = modelsDirectory.appendingPathComponent("manifests/\(CapabilityFrozenRun.ollamaManifestRelativePath)")
        var checks: [CapabilityPreflightCheck] = []
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            return [CapabilityPreflightCheck(name: "installed granite4:3b manifest", passed: false, detail: "missing: \(manifestURL.path)")]
        }
        let manifestHash = CapabilitySHA256.hex(manifestData)
        checks.append(CapabilityPreflightCheck(name: "installed granite4:3b Ollama manifest SHA-256", passed: manifestHash == CapabilityFrozenRun.ollamaManifestSHA256, detail: manifestHash))
        let layers = ((try? JSONSerialization.jsonObject(with: manifestData)) as? [String: Any])?["layers"] as? [[String: Any]] ?? []
        let layerDigests = Set(layers.compactMap { ($0["digest"] as? String)?.replacingOccurrences(of: "sha256:", with: "") })
        let expected = [CapabilityFrozenRun.ggufBlobSHA256, CapabilityFrozenRun.templateBlobSHA256, CapabilityFrozenRun.licenseBlobSHA256]
        checks.append(CapabilityPreflightCheck(
            name: "manifest layers are exactly {model, template, license} (no params/system/adapter layer)",
            passed: layerDigests == Set(expected) && layers.count == 3,
            detail: "\(layers.count) layers"
        ))
        let blobURL = modelsDirectory.appendingPathComponent("blobs/sha256-\(CapabilityFrozenRun.ggufBlobSHA256)")
        let size = (try? FileManager.default.attributesOfItem(atPath: blobURL.path)[.size] as? Int) ?? nil
        checks.append(CapabilityPreflightCheck(name: "GGUF blob present, frozen size", passed: size == CapabilityFrozenRun.ggufBlobSizeBytes, detail: "\(size.map(String.init) ?? "missing") bytes"))
        if hashBlob, size == CapabilityFrozenRun.ggufBlobSizeBytes {
            let streamed = self.streamingSHA256(of: blobURL)
            checks.append(CapabilityPreflightCheck(name: "GGUF blob content SHA-256 == frozen", passed: streamed == CapabilityFrozenRun.ggufBlobSHA256, detail: streamed ?? "unreadable"))
        }
        return checks
    }

    static func streamingSHA256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Runtime probe parsing (pure; the HTTP GETs live in the live runner)

    /// `GET /api/version` -> `{"version":"0.34.4"}`.
    static func parseOllamaVersion(_ data: Data) -> String? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["version"] as? String
    }

    /// `GET /api/tags` -> the Ollama manifest digest for `model`, if it is installed.
    static func parseInstalledDigest(tags data: Data, model: String) -> String? {
        let models = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["models"] as? [[String: Any]] ?? []
        let match = models.first { ($0["name"] as? String) == model || ($0["model"] as? String) == model }
        return (match?["digest"] as? String)?.replacingOccurrences(of: "sha256:", with: "")
    }
}
