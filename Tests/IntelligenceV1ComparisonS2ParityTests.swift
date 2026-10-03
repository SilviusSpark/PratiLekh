import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: parity build tests (part B).
///
/// Compiled with the **real frozen** scoring code (`CapabilityCorpus.swift`, the V1.25 `SupplementaryEvaluator`),
/// the V1.17 harness provider and `LLMClient`. This binary is never part of the execution path; it exists to prove
/// that the execution build's stand-ins are equivalent to the frozen originals:
///   1. the corpus-isolation shadow's entry schema is text-identical to the frozen declaration;
///   2. S2 scoring reproduces `SupplementaryEvaluator` (V1.25 semantics) on the same raw outputs;
///   3. the S2 request configuration equals the V1.17/V1.23 harness configuration (baseline arm), and differs
///      from it only in the system instructions for the variant arm;
///   4. the synthetic tooling fixtures are disjoint (rules P1-P7) from BOTH the development corpus and the
///      V1.23 benchmark. No model, no network. Run via `scripts/test_intelligence_v1_comparison_s2.sh`.
@main
enum IntelligenceV1ComparisonS2ParityTests {
    static func main() async throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        try self.testShadowTypeIsTextIdentical(repoRoot)
        try await self.testScoringParityWithV125(repoRoot)
        try self.testRequestParity(repoRoot)
        try self.testFixturesAreDisjointFromBothCorpora(repoRoot)
        print(
            "PASS: Intelligence V1.29 S2 parity tests -- shadow schema, V1.25 scoring, request configuration and fixture disjointness all verified (no model, no network)"
        )
    }

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func slice(_ text: String, from: String, to: String) -> String {
        guard let start = text.range(of: from),
              let end = text.range(of: to, range: start.upperBound..<text.endIndex) else { preconditionFailure("slice \(from)") }
        return self.normalized(String(text[start.lowerBound..<end.lowerBound]))
    }

    // MARK: - 1. Shadow type

    private static func testShadowTypeIsTextIdentical(_ repoRoot: URL) throws {
        let real = try String(
            contentsOf: repoRoot.appendingPathComponent("Evaluation/Intelligence/CapabilityEvaluation/CapabilityCorpus.swift"),
            encoding: .utf8
        )
        let shadow = try String(
            contentsOf: repoRoot.appendingPathComponent("Evaluation/Intelligence/ComparisonExecution/ComparisonExecutionEntryTypes.swift"),
            encoding: .utf8
        )
        let realSchema = self.slice(real, from: "    struct Correction: Decodable, Equatable {", to: "    private struct File: Decodable {")
        let shadowSchema = self.slice(shadow, from: "    struct Correction: Decodable, Equatable {", to: "    let entries: [Entry]")
        precondition(realSchema == shadowSchema, "the isolation shadow's Correction/Entry declarations must be text-identical to the frozen ones")
        precondition(
            self.slice(real, from: "enum CapabilitySHA256 {", to: "struct CapabilityCorpus {") == self.slice(
                shadow,
                from: "enum CapabilitySHA256 {",
                to: "struct CapabilityCorpus {"
            ),
            "the SHA-256 helper is identical"
        )
    }

    // MARK: - 2. Scoring parity with SupplementaryEvaluator

    private static func testScoringParityWithV125(_ repoRoot: URL) async throws {
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        let entries = S2ToolingFixtures.entries()
        let foreign = S2ToolingFixtures.rawArguments([("the peon", "The peon")])
        let wide = S2ToolingFixtures.rawArguments([("the surveyor measured the boundary wall", "the surveyor measured the boundary wall.")])
        let merge = S2ToolingFixtures.rawArguments([("The drawer answered the NI Act", "The drawer answered the ni Act")])
        func arguments(for entry: CapabilityCorpus.Entry, variant: Int) -> [String] {
            switch variant {
            case 0: [S2ToolingFixtures.oracleArguments(for: entry)]
            case 1: [S2ToolingFixtures.emptyArguments]
            case 2: [entry.id == "TF-K1" ? foreign : (entry.id == "TF-P1" ? wide : (entry.id == "TF-H1" ? merge : S2ToolingFixtures.emptyArguments))]
            case 3: ["{\"edits\":[]}"] // strict-parser failure
            default: []
            }
        }
        let corpus = ComparisonCorpus(entries: entries, sha256: S2ToolingFixtures.corpusSHA256)
        for variant in 0...4 {
            var records: [ComparisonCallRecord] = []
            let plan = ComparisonExecutionPlan.fixturePlan(
                candidates: [ComparisonExecutionPlan.Candidate(
                    id: "C",
                    ollamaTag: "t",
                    manifestSHA256: "",
                    modelLayerDigest: "",
                    onDiskBytes: 1,
                    paramsLayerContent: [:]
                )],
                corpusEntryIDs: entries.map(\.id),
                auditEntryIDs: []
            )
            let byNormalized = Dictionary(uniqueKeysWithValues: entries.map { (processor.process($0.text).normalized, $0) })
            try await ComparisonExecutor.execute(
                plan: plan,
                corpus: corpus,
                evidence: .toolingFixture,
                processor: processor,
                runID: "parity",
                instructions: ModelFacingGenerationContract.instructions,
                proposer: { request in
                    guard let entry = byNormalized[request.userText] else { preconditionFailure("text") }
                    let calls = arguments(for: entry, variant: variant)
                    return .success(IntelligenceProviderResponse(toolCalls: calls.map { IntelligenceProviderToolCall(
                        name: ModelFacingGenerationContract.toolName,
                        rawArguments: $0
                    ) }))
                },
                sink: { records.append($0) }
            )
            // S2 scoring.
            let scores = try zip(entries, records).map { try ComparisonScoring.score(entry: $0, record: $1, processor: processor) }
            // Frozen V1.25 evaluator over the same raw outputs (as V1.23-style trial records).
            let trials: [SupplementaryTrialRecord] = try records.map { record in
                let kind = record.toolCallNames.isEmpty ? "protocolFailure" : "evaluated"
                let raw = try JSONSerialization.data(withJSONObject: [
                    "id": record.entryID, "category": "c", "manualAdjudicationOnly": false, "rawInput": record.rawInputText,
                    "legalNormalized": record.legalNormalizedText as Any,
                    "modelFreeText": NSNull(), "modelRawToolCallArguments": record.rawToolCallArguments, "trial": kind, "edits": [] as [Any],
                ] as [String: Any])
                return try JSONDecoder().decode(SupplementaryTrialRecord.self, from: raw)
            }
            let reference = try SupplementaryEvaluator.evaluate(
                corpus: CapabilityCorpus(entries: entries, sha256: "x"),
                trials: trials,
                processor: processor
            )
            for (mine, theirs) in zip(scores, reference.entries) {
                let id = mine.entry.id
                precondition(mine.autonomousFinal == theirs.autonomousFinal, "\(id)/v\(variant): autonomous final text")
                precondition(mine.autonomousState == theirs.autonomousState, "\(id)/v\(variant): V1.25 outcome state")
                precondition(mine.counterfactualState == theirs.counterfactualState, "\(id)/v\(variant): counterfactual state")
                precondition(
                    mine.acceptedEditCount == theirs.acceptedEditCount && mine.exactPairViolations == theirs.exactPairViolations,
                    "\(id)/v\(variant): accepted edits and U0"
                )
                precondition(
                    mine.runtime == theirs.runtime && mine.digitSequenceChanged == theirs.digitSequenceChanged,
                    "\(id)/v\(variant): U2/U3 observations"
                )
                precondition(mine.licensed == theirs.licensed, "\(id)/v\(variant): licensed outcome set")
            }
            precondition(scores.reduce(0) { $0 + $1.exactPairViolations } == reference.u0, "v\(variant): U0 total")
            precondition(
                scores.filter { $0.entry.isScored && $0.autonomousState == .foreign }.count == reference.u1Entries.count,
                "v\(variant): U1 total"
            )
            let formAll = scores.reduce(SupplementaryFormAdherence()) { acc, score in
                var next = acc
                next.resolvedEdits += score.formAll.resolvedEdits
                next.exactExpectedPair += score.formAll.exactExpectedPair
                next.wholeTextSpan += score.formAll.wholeTextSpan
                return next
            }
            precondition(formAll == reference.formAll, "v\(variant): edit-form adherence tallies")
            precondition(
                scores.reduce(0) { $0 + $1.spanWidths.filter { $0 == .wholeText }.count } == reference.formAll.wholeTextSpan,
                "v\(variant): S2 whole-text span count agrees with V1.25's"
            )
        }
    }

    // MARK: - 3. Request parity

    private static func testRequestParity(_ repoRoot: URL) throws {
        let candidate = ComparisonExecutionPlan.Candidate(
            id: "CAND-X",
            ollamaTag: "x:3b",
            manifestSHA256: "",
            modelLayerDigest: "",
            onDiskBytes: 1,
            paramsLayerContent: [:]
        )
        let text = "the registrar noted the order"
        let mine = ComparisonProvider.makeLLMConfig(request: ComparisonProposerRequest(
            candidate: candidate,
            contractArm: .baselineV121,
            instructions: ModelFacingGenerationContract.instructions,
            userText: text
        ))
        let harness = IntelligenceHarnessProvider.makeLLMConfig(
            normalizedText: text,
            config: IntelligenceHarnessProvider.LocalProviderConfig(
                baseURL: IntelligenceHarnessProvider.LocalProviderConfig.defaultBaseURL,
                model: "x:3b",
                apiKey: "",
                timeoutSeconds: 60,
                maxRetries: 1
            )
        )
        func canon(_ object: Any) -> String {
            String(
                bytes: (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data(),
                encoding: .utf8
            ) ?? ""
        }
        precondition(
            canon(mine.messages) == canon(harness.messages) && canon(mine.tools) == canon(harness.tools),
            "baseline arm: messages and tools equal the V1.23 harness request"
        )
        precondition(mine.model == harness.model && mine.baseURL == harness.baseURL && mine.apiKey == harness.apiKey)
        precondition(mine.streaming == false && harness.streaming == false && mine.temperature == harness.temperature && mine.temperature == 0)
        precondition(
            mine.timeoutSeconds == harness.timeoutSeconds && mine.timeoutSeconds == 60 && mine.maxRetries == 1 && harness.maxRetries == 1,
            "60 s limit and exactly one attempt (LLMClient's own default of 3 is overridden)"
        )
        precondition(
            mine.maxTokens == harness.maxTokens && mine.maxTokens == nil && canon(mine.extraParameters) == canon(harness.extraParameters) && mine
                .extraParameters.isEmpty,
            "no sampling or per-model option is added"
        )
        precondition(mine.baseURL == ComparisonExecutionPlan.baseURL && mine.model == "x:3b")
        // The variant arm changes only the system instructions.
        let variantText = try ComparisonExecutionPlan.instructions(
            for: .variantBalancedAbstention,
            baseline: ModelFacingGenerationContract.instructions,
            repoRoot: repoRoot
        )
        let variant = ComparisonProvider.makeLLMConfig(request: ComparisonProposerRequest(
            candidate: candidate,
            contractArm: .variantBalancedAbstention,
            instructions: variantText,
            userText: text
        ))
        precondition(canon(variant.tools) == canon(mine.tools) && canon(variant.messages) != canon(mine.messages))
        let userBase = (mine.messages[1]["content"] as? String), userVariant = (variant.messages[1]["content"] as? String)
        precondition(userBase == userVariant && userBase == text && (variant.messages[0]["content"] as? String) == variantText)
        precondition(variant.temperature == mine.temperature && variant.timeoutSeconds == mine.timeoutSeconds && variant.maxRetries == mine
            .maxRetries)
        // The executor's logical fingerprint depends on exactly these inputs.
        let a = ComparisonExecutor.requestFingerprint(
            model: "x:3b",
            instructionsSHA256: CapabilitySHA256.hex(of: ModelFacingGenerationContract.instructions),
            userText: text,
            toolDefinitionSHA256: ComparisonExecutor.toolDefinitionSHA256()
        )
        let b = ComparisonExecutor.requestFingerprint(
            model: "x:3b",
            instructionsSHA256: CapabilitySHA256.hex(of: variantText),
            userText: text,
            toolDefinitionSHA256: ComparisonExecutor.toolDefinitionSHA256()
        )
        precondition(a != b)
    }

    // MARK: - 4. Fixture disjointness

    private static func testFixturesAreDisjointFromBothCorpora(_ repoRoot: URL) throws {
        let benchmark = try CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
        let development = try ComparisonCorpus.load(from: repoRoot.appendingPathComponent(ComparisonCorpus.relativePath))
        let subjects = S2ToolingFixtures.specs.map {
            ComparisonOverlap.Subject(
                id: $0.id,
                text: $0.text,
                corrections: $0.corrections.map { CapabilityCorpus.Correction(source: $0.0, replacement: $0.1) }
            )
        }
        let againstBenchmark = ComparisonOverlap.check(subjects: subjects, frozen: benchmark.entries)
        precondition(
            againstBenchmark.isEmpty,
            "fixtures overlap the V1.23 benchmark: \(againstBenchmark.map { "\($0.rule.rawValue) \($0.subjectID)~\($0.against)" })"
        )
        let againstDevelopment = ComparisonOverlap.check(subjects: subjects, frozen: development.entries)
        precondition(
            againstDevelopment.isEmpty,
            "fixtures overlap the development corpus: \(againstDevelopment.map { "\($0.rule.rawValue) \($0.subjectID)~\($0.against)" })"
        )
        precondition(ComparisonOverlap.internalDuplicates(subjects).isEmpty)
        // Sensitivity: the same check does flag a copied entry from either corpus.
        let leakBenchmark = ComparisonOverlap.Subject(id: "leak", text: benchmark.entries[0].text, corrections: [])
        let leakDevelopment = ComparisonOverlap.Subject(id: "leak", text: development.entries[0].text, corrections: [])
        precondition(!ComparisonOverlap.check(subjects: [leakBenchmark], frozen: benchmark.entries).isEmpty && !ComparisonOverlap.check(
            subjects: [leakDevelopment],
            frozen: development.entries
        ).isEmpty)
    }
}
