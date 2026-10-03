import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling.
///
/// The pre-registered S3 execution plan, derived deterministically from the frozen V1.27 artifacts and
/// the S1 identity artifact; nothing here calls a model or the network. The plan fixes, before any
/// inference: candidate order, per-candidate call sequence (one full screening pass in corpus order, then
/// the fixed 12-entry audit in protocol order), the contract arm, the request parameters, every frozen
/// artifact hash, and the hash of the tooling that will measure. Its canonical SHA-256 is what the live
/// runner must be given (`--execute-plan`); a drift in any pinned input changes that hash.
///
/// Corpus isolation: this file (like every execution-path file) reads only the development corpus, through
/// `ComparisonCorpus.load`. It has no reference to the V1.23 benchmark, its loader, pin, or artifacts.
enum ComparisonExecutionSources {
    /// Execution-path source files, in compile order for `scripts/intelligence_v1_comparison_s3_run.sh`.
    /// Everything that determines what a model is shown and how its output is scored is hashed in the plan.
    static let chainSources = [
        "Sources/Fluid/LegalLanguage/Packs/LanguagePack.swift",
        "Sources/Fluid/LegalLanguage/Packs/PackLoader.swift",
        "Sources/Fluid/LegalLanguage/Packs/PackRepository.swift",
        "Sources/Fluid/LegalLanguage/Resolution/ResolvedLanguageResources.swift",
        "Sources/Fluid/LegalLanguage/Resolution/PrecedenceResolver.swift",
        "Sources/Fluid/LegalLanguage/Recognition/ProviderRecognitionCapability.swift",
        "Sources/Fluid/LegalLanguage/Recognition/ProviderCapabilityResolver.swift",
        "Sources/Fluid/LegalLanguage/Recognition/RecognitionVocabularyAdapter.swift",
        "Sources/Fluid/LegalLanguage/Normalization/NormalizationContext.swift",
        "Sources/Fluid/LegalLanguage/Normalization/LegalNormalizer.swift",
        "Sources/Fluid/LegalLanguage/Normalization/LookupTableNormalizer.swift",
        "Sources/Fluid/LegalLanguage/Normalization/NormalizationOutcome.swift",
        "Sources/Fluid/LegalLanguage/Normalization/NormalizationReplay.swift",
        "Sources/Fluid/LegalLanguage/Normalization/WordTokenizer.swift",
        "Sources/Fluid/LegalLanguage/Normalization/SpokenNumberParser.swift",
        "Sources/Fluid/LegalLanguage/Normalization/StatuteRecognizer.swift",
        "Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionReference.swift",
        "Sources/Fluid/LegalLanguage/Normalization/StatutoryProvisionNormalizer.swift",
        "Sources/Fluid/LegalLanguage/Normalization/WitnessReferenceNormalizer.swift",
        "Sources/Fluid/LegalLanguage/LegalLanguageCoordinator.swift",
        "Sources/Fluid/LegalLanguage/Packs/BuiltInPacks.swift",
        "Sources/Fluid/LegalLanguage/LegalDictationProcessor.swift",
        "Sources/Fluid/Intelligence/Safety/IntelligenceProposal.swift",
        "Sources/Fluid/Intelligence/Safety/AutonomousPermissionGate.swift",
        "Sources/Fluid/Intelligence/Safety/ProtectedSpan.swift",
        "Sources/Fluid/Intelligence/Safety/IntelligenceEditClassifier.swift",
        "Sources/Fluid/Intelligence/Safety/ProposalDisposition.swift",
        "Sources/Fluid/Intelligence/Safety/IntelligenceSafetyAuthority.swift",
        "Sources/Fluid/Intelligence/Transport/RawJSONObjectKeyScanner.swift",
        "Sources/Fluid/Intelligence/Transport/IntelligenceProposalTransportParser.swift",
        "Sources/Fluid/Intelligence/Transport/ModelFacingEditTransportParser.swift",
        "Sources/Fluid/Intelligence/Generation/IntelligenceGenerationContract.swift",
        "Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponse.swift",
        "Sources/Fluid/Intelligence/Generation/IntelligenceProviderResponseAdapter.swift",
        "Sources/Fluid/Intelligence/Generation/ModelFacingGenerationContract.swift",
        "Sources/Fluid/Intelligence/Generation/ModelFacingResponseAdapter.swift",
        "Sources/Fluid/Intelligence/Addressing/ModelFacingEdit.swift",
        "Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingResolver.swift",
        "Sources/Fluid/Intelligence/Addressing/IntelligenceAddressingBridge.swift",
        "Sources/Fluid/Intelligence/Composition/IntelligenceEditComposition.swift",
        "Sources/Fluid/Intelligence/Provenance/ProtectedSpanDerivation.swift",
        "Sources/Fluid/Intelligence/Protection/NumericStructuralProtection.swift",
        "Evaluation/Intelligence/Harness/IntelligenceHarnessTypes.swift",
        "Evaluation/Intelligence/Harness/IntelligenceHarnessPipeline.swift",
        "Evaluation/Intelligence/Harness/IntelligenceHarnessLegalPack.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityAdjudication.swift",
        "Evaluation/Intelligence/CapabilityEvaluation/CapabilityMetrics.swift",
        "Evaluation/Intelligence/CapabilitySupplementary/SupplementaryOutcome.swift",
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonCorpus.swift",
        "Evaluation/Intelligence/ComparisonProtocol/ComparisonFixtures.swift",
    ]

    /// S2 execution/scoring tooling (the files this milestone adds). `ComparisonProvider.swift` and
    /// `ComparisonLiveRunner.swift` link `LLMClient` and are compiled only by the live runner script.
    static let coreTooling = [
        "Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionEntryTypes.swift",
        "Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionPlan.swift",
        "Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionRecords.swift",
        "Evaluation/Intelligence/ComparisonExecution/ComparisonExecutor.swift",
        "Evaluation/Intelligence/ComparisonExecution/ComparisonScoring.swift",
        "Evaluation/Intelligence/ComparisonExecution/ComparisonAnalysis.swift",
    ]

    static let providerTooling = [
        "Evaluation/Intelligence/ComparisonExecution/ComparisonProvider.swift",
    ]

    static let liveRunner = "Evaluation/Intelligence/ComparisonExecution/ComparisonLiveRunner.swift"
    static let analysisRunner = "Evaluation/Intelligence/ComparisonExecution/ComparisonAnalysisRunner.swift"

    /// Scripts that define the build/invocation of the above.
    static let scripts = [
        "scripts/intelligence_v1_comparison_s3_run.sh",
        "scripts/intelligence_v1_comparison_s3_analyze.sh",
        "scripts/test_intelligence_v1_comparison_s2.sh",
    ]

    /// S2 tests and their synthetic fixtures; hashed into the plan so the isolation guards are part of FB2.
    static let tests = [
        "Tests/IntelligenceV1ComparisonS2Tests.swift",
        "Tests/IntelligenceV1ComparisonS2ParityTests.swift",
        "Tests/IntelligenceV1ComparisonS2Fixtures.swift",
    ]

    /// Paths that must never appear in an execution build (the benchmark loader and every artifact that
    /// carries benchmark text or results). Enforced by tests on the source lists, file contents and a
    /// negative-compile check.
    static let forbiddenSourceFiles = [
        "CapabilityCorpus.swift", "CapabilityManifest.swift", "CapabilityLiveRunner.swift",
        "CapabilityPreflightRunner.swift", "CapabilityEvaluationDriver.swift", "CapabilityReport.swift",
        "SupplementaryEvaluator.swift", "SupplementaryRunner.swift", "SupplementaryReport.swift",
        "ComparisonFreeze.swift", "ComparisonFreezeRunner.swift", "ComparisonOverlap.swift",
    ]

    /// Substrings that may not occur in any execution-path source file.
    /// Written as concatenations so that this file, which is itself scanned, never contains the literal tokens.
    static let forbiddenTokens = [
        "intelligence-v1-" + "capability", "V1_23" + "_RESULTS", "V1_22" + "_", "Capability" + "Corpus.load", "Capability" + "Corpus.relativePath",
        "Capability" + "Corpus.frozen", "0edd" + "60bb", "Supplementary" + "Artifacts", "Capability" + "RunManifest", "Capability" + "FrozenRun",
    ]
}

struct ComparisonExecutionPlan {
    static let milestone = "V1.29"
    static let stage = "S3"
    static let directory = "Evaluation/References/intelligence-v1-comparison-dev"
    static let s1Path = "Evaluation/References/intelligence-v1-comparison-s1/acquisition_identity.json"
    static let proposedPlanPath = "Evaluation/References/intelligence-v1-comparison-s2/S3_PROPOSED_RUN_PLAN.json"

    /// Pinned at S2 from the committed V1.27 freeze manifest and the V1.28 S1 artifact. A mismatch means a
    /// frozen artifact changed; never update a pin to make a run proceed.
    static let artifactSHA256: [String: String] = [
        "candidates.json": "ef68ff0994e0e4c9be03d80fa3eb2b0ae68adaf04b48e646ee4515901d3c9d41",
        "contract_variant.json": "68b19453707e96251e71961d5aa1383f47a33faae812168a8c0fe72f89b2baec",
        "corpus.json": "e164297ec472e7f750d8e3e18f52f939e22a89bd7578ecc42df18d5b7941e364",
        "hazard_fixture.json": "a5353e38c1ac1340a00f9a72904672be0ac9cfb677993b29db11537c1f356202",
        "protocol.json": "9215c7623ddac8d935bd6c1074af57c918011b987b92d695bb2877fb2c6fefb2",
    ]
    static let freezeManifestRawSHA256 = "e5426006dc85b068c653ee86fb4633fd0255d119a45084abd7691a1ea059f8bd"
    static let s1ArtifactSHA256 = "6e40337605cdf3b3dea4e0b96ecd351434ec1d7f76011d3a642cc9df256042ad"

    /// V1.21 baseline contract identity (also independently pinned by the V1.21 tests).
    static let baselineInstructionsSHA256 = "249ebb6ae1d7d6df9387d5d82ce818a0ccf5bef0b5104a05211f592caf54ad88"
    static let baselineToolDefinitionSHA256 = "d7a7cc2347d9f9f2b21561e0073f5fef183125edca916f658f9e62130265cc98"
    static let variantInstructionsSHA256 = "b6a8575fcef2d2c995be20100c15531ff71cf0c49de6de91984eea8c6ddd497a"

    /// Request parameters, frozen by `candidates.json` and V1.23 parity. A test asserts the registry agrees.
    static let temperature = 0.0
    static let timeoutSeconds = 60.0
    static let maxRetries = 1
    static let baseURL = "http://localhost:11434/v1"
    static let ollamaVersion = "0.34.4"

    /// The contract arm of a stage. S3 uses the unchanged V1.21 production contract only; the variant is
    /// reachable only for the conditional S4 probe and is a different case, never a flag on S3.
    enum ContractArm: String {
        case baselineV121 = "V1.21-production"
        case variantBalancedAbstention = "V-balanced-abstention"
    }

    struct Candidate: Equatable {
        let id: String
        let ollamaTag: String
        let manifestSHA256: String
        let modelLayerDigest: String
        let onDiskBytes: Int
        /// Params-layer sampling defaults recorded at S1 (empty when the candidate ships none).
        let paramsLayerContent: [String: String]
    }

    struct Step: Equatable {
        enum Phase: String { case screening, audit }
        let sequence: Int
        let candidateID: String
        let phase: Phase
        let entryID: String
        let entryOrdinal: Int
    }

    enum PlanError: Error, CustomStringConvertible {
        case unreadable(String)
        case hashMismatch(file: String, actual: String, expected: String)
        case structural(String)
        var description: String {
            switch self {
            case let .unreadable(path): "cannot read \(path)"
            case let .hashMismatch(file, actual, expected): "\(file) SHA-256 \(actual) != pinned \(expected): a frozen artifact changed"
            case let .structural(detail): "plan structural check failed: \(detail)"
            }
        }
    }

    let arm: ContractArm
    let candidates: [Candidate]
    let auditEntryIDs: [String]
    let corpusEntryIDs: [String]
    let steps: [Step]
    let repoRoot: URL

    /// Canonical dictionary of everything that determines the run (no git state: the live runner records
    /// HEAD and tree state separately, exactly like V1.23A).
    func manifest() throws -> [String: Any] {
        var artifacts: [String: String] = [:]
        for name in Self.artifactSHA256.keys.sorted() {
            artifacts["\(Self.directory)/\(name)"] = Self.artifactSHA256[name]
        }
        func hashes(_ paths: [String]) throws -> [String: String] {
            var result: [String: String] = [:]
            for path in paths {
                guard let data = try? Data(contentsOf: self.repoRoot.appendingPathComponent(path)) else { throw PlanError.unreadable(path) }
                result[path] = CapabilitySHA256.hex(data)
            }
            return result
        }
        let candidateRecords: [[String: Any]] = self.candidates.map { candidate in
            var record: [String: Any] = [
                "id": candidate.id, "ollamaTag": candidate.ollamaTag, "ollamaManifestSHA256": candidate.manifestSHA256,
                "modelLayerDigest": candidate.modelLayerDigest, "onDiskBytes": candidate.onDiskBytes,
            ]
            if !candidate.paramsLayerContent.isEmpty {
                record["paramsLayerOptions"] = candidate.paramsLayerContent
            }
            return record
        }
        let stepRecords = self.steps.map { "\($0.sequence)|\($0.candidateID)|\($0.phase.rawValue)|\($0.entryID)|\($0.entryOrdinal)" }
        return try [
            "manifestSchemaVersion": 1,
            "milestone": Self.milestone,
            "stage": Self.stage,
            "status": "proposed-not-executed; S2 tooling only, no model run",
            "frozenArtifactSHA256": artifacts,
            "freezeManifestRawSHA256": Self.freezeManifestRawSHA256,
            "s1ArtifactSHA256": Self.s1ArtifactSHA256,
            "developmentCorpusEntries": self.corpusEntryIDs.count,
            "contract": [
                "arm": self.arm.rawValue,
                "instructionsSHA256": self.arm == .baselineV121 ? Self.baselineInstructionsSHA256 : Self.variantInstructionsSHA256,
                "toolDefinitionSHA256": Self.baselineToolDefinitionSHA256,
            ] as [String: Any],
            "request": [
                "stream": false, "temperature": Self.temperature, "toolChoice": "auto", "timeoutSeconds": Self.timeoutSeconds,
                "llmClientMaxRetries": Self.maxRetries, "attemptsPerStep": 1, "retriesOnFailure": false,
                "baseURL": Self.baseURL, "ollamaVersion": Self.ollamaVersion,
            ] as [String: Any],
            "candidates": candidateRecords,
            "auditEntryIDs": self.auditEntryIDs,
            "stepCount": self.steps.count,
            "stepsSHA256": CapabilitySHA256.hex(of: stepRecords.joined(separator: "\n")),
            "chainSourceSHA256": hashes(ComparisonExecutionSources.chainSources),
            "toolingSourceSHA256": hashes(ComparisonExecutionSources.coreTooling + ComparisonExecutionSources.providerTooling + [
                ComparisonExecutionSources.liveRunner,
                ComparisonExecutionSources.analysisRunner,
            ]),
            "scriptSHA256": hashes(ComparisonExecutionSources.scripts),
            "testSourceSHA256": hashes(ComparisonExecutionSources.tests),
        ]
    }

    func canonicalJSON() throws -> Data {
        try JSONSerialization.data(withJSONObject: self.manifest(), options: [.sortedKeys, .withoutEscapingSlashes])
    }

    func prettyJSON() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: self.manifest(), options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    func sha256() throws -> String {
        try CapabilitySHA256.hex(self.canonicalJSON())
    }

    // MARK: - Construction

    private static func verified(_ name: String, in directory: String, expected: String, repoRoot: URL) throws -> Data {
        let url = repoRoot.appendingPathComponent(directory).appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { throw PlanError.unreadable(url.path) }
        let actual = CapabilitySHA256.hex(data)
        guard actual == expected else { throw PlanError.hashMismatch(file: name, actual: actual, expected: expected) }
        return data
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw PlanError.structural("not a JSON object") }
        return value
    }

    /// Builds the S3 plan. `corpus` must be the verified development corpus (the loader enforces its pin).
    static func build(repoRoot: URL, corpus: ComparisonCorpus, arm: ContractArm = .baselineV121) throws -> ComparisonExecutionPlan {
        guard corpus.sha256 == self.artifactSHA256["corpus.json"] else { throw PlanError.structural("corpus is not the pinned development corpus") }
        var parsed: [String: [String: Any]] = [:]
        for (name, hash) in self.artifactSHA256 {
            parsed[name] = try self.object(self.verified(name, in: self.directory, expected: hash, repoRoot: repoRoot))
        }
        let s1 = try self.object(self.verified(
            "acquisition_identity.json",
            in: "Evaluation/References/intelligence-v1-comparison-s1",
            expected: self.s1ArtifactSHA256,
            repoRoot: repoRoot
        ))
        guard let protocolJSON = parsed["protocol.json"], let registry = parsed["candidates.json"],
              let s1Candidates = s1["candidates"] as? [[String: Any]]
        else {
            throw PlanError.structural("missing artifact section")
        }
        // Request parameters: the registry must agree with the constants the runner uses.
        guard let request = registry["requestParameters"] as? [String: Any],
              request["stream"] as? Bool == false, request["temperature"] as? Double == self.temperature,
              request["toolChoice"] as? String == "auto", request["timeoutSeconds"] as? Double == self.timeoutSeconds,
              request["maxRetries"] as? Int == self.maxRetries,
              (registry["runtime"] as? [String: Any])?["baseURL"] as? String == self.baseURL,
              (registry["runtime"] as? [String: Any])?["ollamaVersion"] as? String == self.ollamaVersion
        else { throw PlanError.structural("registry request parameters differ from the execution constants") }

        // Candidate order and identity: the S1-verified set, in S1 order, which must equal the registry's primary order.
        let registryIDs = ((registry["candidates"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }
        let s1IDs = s1Candidates.compactMap { $0["id"] as? String }
        guard s1IDs == registryIDs.filter({ $0 != "CAND-OPT-001" }), s1IDs.first == "CAND-BASE", s1IDs.count == 5 else {
            throw PlanError.structural("S1 candidate set/order differs from the registry's primary candidates: \(s1IDs) vs \(registryIDs)")
        }
        guard (s1["summary"] as? [String: Any])?["allVerified"] as? Bool == true
        else { throw PlanError.structural("S1 artifact is not fully verified") }
        var candidates: [Candidate] = []
        for item in s1Candidates {
            guard let id = item["id"] as? String, let tag = item["ollamaTag"] as? String,
                  let manifest = (item["localManifest"] as? [String: Any])?["sha256"] as? String,
                  let layers = (item["localManifest"] as? [String: Any])?["layers"] as? [[String: Any]],
                  let model = layers.first(where: { ($0["mediaType"] as? String)?.hasSuffix("image.model") == true })?["digest"] as? String,
                  let bytes = (item["storage"] as? [String: Any])?["totalLayerBytes"] as? Int,
                  (item["verification"] as? [String: Any])?["status"] as? String == "verified"
            else { throw PlanError.structural("S1 candidate record incomplete or unverified") }
            var params: [String: String] = [:]
            if let content = (item["paramsLayer"] as? [String: Any])?["content"] as? [String: Any] {
                params = content.mapValues { value in
                    (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])).flatMap { String(
                        bytes: $0,
                        encoding: .utf8
                    ) } ?? ""
                }
            }
            candidates.append(Candidate(
                id: id,
                ollamaTag: tag,
                manifestSHA256: manifest,
                modelLayerDigest: model,
                onDiskBytes: bytes,
                paramsLayerContent: params
            ))
        }

        // Audit entries: fixed by the protocol, in its order, each present exactly once.
        guard let audit = (protocolJSON["runCountDecision"] as? [String: Any])?["determinismAudit"] as? [String: Any],
              let auditIDs = audit["entryIds"] as? [String], auditIDs.count == 12, Set(auditIDs).count == 12
        else { throw PlanError.structural("protocol audit list is not 12 distinct ids") }
        let corpusIDs = corpus.entries.map(\.id)
        guard auditIDs.allSatisfy(corpusIDs.contains),
              corpusIDs.count == 66 else { throw PlanError.structural("audit ids must all be development-corpus entries") }

        var steps: [Step] = []
        var sequence = 0
        for candidate in candidates {
            for (ordinal, id) in corpusIDs.enumerated() {
                sequence += 1
                steps.append(Step(sequence: sequence, candidateID: candidate.id, phase: .screening, entryID: id, entryOrdinal: ordinal + 1))
            }
            for id in auditIDs {
                sequence += 1
                steps.append(Step(
                    sequence: sequence,
                    candidateID: candidate.id,
                    phase: .audit,
                    entryID: id,
                    entryOrdinal: (corpusIDs.firstIndex(of: id) ?? -1) + 1
                ))
            }
        }
        return ComparisonExecutionPlan(
            arm: arm,
            candidates: candidates,
            auditEntryIDs: auditIDs,
            corpusEntryIDs: corpusIDs,
            steps: steps,
            repoRoot: repoRoot
        )
    }

    /// A smaller plan over an arbitrary (tooling-fixture) corpus for mechanics tests only. Never used by the
    /// live runner, and carries no pin: the executor stamps its records `toolingFixture`.
    static func fixturePlan(candidates: [Candidate], corpusEntryIDs: [String], auditEntryIDs: [String]) -> ComparisonExecutionPlan {
        var steps: [Step] = []
        var sequence = 0
        for candidate in candidates {
            for (ordinal, id) in corpusEntryIDs.enumerated() {
                sequence += 1
                steps.append(Step(sequence: sequence, candidateID: candidate.id, phase: .screening, entryID: id, entryOrdinal: ordinal + 1))
            }
            for id in auditEntryIDs {
                sequence += 1
                steps.append(Step(
                    sequence: sequence,
                    candidateID: candidate.id,
                    phase: .audit,
                    entryID: id,
                    entryOrdinal: (corpusEntryIDs.firstIndex(of: id) ?? -1) + 1
                ))
            }
        }
        return ComparisonExecutionPlan(
            arm: .baselineV121,
            candidates: candidates,
            auditEntryIDs: auditEntryIDs,
            corpusEntryIDs: corpusEntryIDs,
            steps: steps,
            repoRoot: URL(fileURLWithPath: "/")
        )
    }

    // MARK: - Contract text per arm

    /// Instructions for an arm. The variant is reconstructed from `contract_variant.json` and refused unless its
    /// hash equals the pre-registered value; it is never produced for the S3 arm.
    static func instructions(for arm: ContractArm, baseline: String, repoRoot: URL?) throws -> String {
        switch arm {
        case .baselineV121:
            guard CapabilitySHA256.hex(of: baseline) == self.baselineInstructionsSHA256
            else { throw PlanError.structural("baseline instructions differ from the pinned V1.21 text") }
            return baseline
        case .variantBalancedAbstention:
            guard let repoRoot else { throw PlanError.structural("variant needs the repository root") }
            let spec = try self.object(self.verified(
                "contract_variant.json",
                in: self.directory,
                expected: self.artifactSHA256["contract_variant.json"] ?? "",
                repoRoot: repoRoot
            ))
            guard let construction = (spec["variant"] as? [String: Any])?["construction"] as? [String: Any],
                  let find = construction["find"] as? String, let replacement = construction["replaceWith"] as? String,
                  baseline.components(separatedBy: find).count == 2
            else { throw PlanError.structural("variant construction does not apply exactly once") }
            let rebuilt = baseline.replacingOccurrences(of: find, with: replacement)
            guard CapabilitySHA256.hex(of: rebuilt) == self.variantInstructionsSHA256
            else { throw PlanError.structural("variant instructions differ from the pre-registered hash") }
            return rebuilt
        }
    }
}
