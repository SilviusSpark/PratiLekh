import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: the sequential executor.
///
/// Runs a `ComparisonExecutionPlan` step by step and captures one raw `ComparisonCallRecord` per step.
/// The model call is an injected `ComparisonProposer`, so this file has no `LLMClient`, network or process
/// dependency and is exercised in tests with deterministic stand-ins (never a model).
///
/// Methodology enforced structurally, not by convention:
///   - strictly sequential, in plan order; exactly one proposer call per step, never more -- there is no
///     retry, repeat or re-ask loop anywhere in this file (a provider failure is recorded and the run moves on);
///   - a preflight failure (legal normalization / protected-span derivation) means the proposer is never called;
///   - nothing about a result influences what is run next: the plan is fixed before the first call, and
///     no observed output can add, skip, repeat or reorder a step (audit steps follow each candidate's single
///     full pass exactly as pre-registered; disagreement never triggers extra passes);
///   - raw outputs are captured verbatim; no scoring happens here, so no metric can be decided during the run.
struct ComparisonProposerRequest {
    let candidate: ComparisonExecutionPlan.Candidate
    let contractArm: ComparisonExecutionPlan.ContractArm
    /// System instructions for the arm (baseline V1.21 text, or the pre-registered variant in S4 only).
    let instructions: String
    /// The user message: the step's `legalNormalized` text.
    let userText: String
}

struct ComparisonProposerOutcome {
    let response: IntelligenceProviderResponse?
    let thinking: String?
    let failure: String?

    static func success(_ response: IntelligenceProviderResponse, thinking: String? = nil) -> ComparisonProposerOutcome {
        ComparisonProposerOutcome(response: response, thinking: thinking, failure: nil)
    }

    static func failure(_ reason: String) -> ComparisonProposerOutcome {
        ComparisonProposerOutcome(response: nil, thinking: nil, failure: reason)
    }
}

typealias ComparisonProposer = (ComparisonProposerRequest) async -> ComparisonProposerOutcome

/// Side-effect hooks around candidates (model unload/preload, `/api/ps` observation). Defaults do nothing.
struct ComparisonExecutionHooks {
    /// May throw to refuse to start a candidate (e.g. a model is already resident); nothing is run for it then.
    var candidateWillStart: (ComparisonExecutionPlan.Candidate) async throws -> Void = { _ in }
    var runtimeObservation: (ComparisonExecutionPlan.Candidate) async -> String? = { _ in nil }
    var candidateDidFinish: (ComparisonExecutionPlan.Candidate) async throws -> Void = { _ in }
}

enum ComparisonExecutor {
    enum Evidence: String {
        /// The pinned 66-entry development corpus: the only evidence an S3 run may produce.
        case developmentCorpus
        /// Synthetic mechanics fixtures: records are stamped so they can never be mistaken for evidence.
        case toolingFixture
    }

    enum ExecutionError: Error, CustomStringConvertible {
        case refused(String)
        var description: String {
            switch self {
            case let .refused(reason): "execution refused: \(reason)"
            }
        }
    }

    static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    /// SHA-256 of the tool definition exactly as the V1.23 freeze computed it (`sortedKeys`).
    static func toolDefinitionSHA256() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: ModelFacingGenerationContract.toolDefinition, options: [.sortedKeys])
        else { return "unserializable" }
        return CapabilitySHA256.hex(data)
    }

    /// Canonical fingerprint of the logical request a step sends (independent of `LLMClient`'s wire format; the
    /// provider file separately proves its configuration carries exactly these fields).
    static func requestFingerprint(model: String, instructionsSHA256: String, userText: String, toolDefinitionSHA256: String) -> String {
        let object: [String: Any] = [
            "model": model, "instructionsSHA256": instructionsSHA256, "userText": userText, "toolDefinitionSHA256": toolDefinitionSHA256,
            "stream": false, "temperature": ComparisonExecutionPlan.temperature, "toolChoice": "auto",
            "timeoutSeconds": ComparisonExecutionPlan.timeoutSeconds, "maxRetries": ComparisonExecutionPlan.maxRetries,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return CapabilitySHA256.hex(data)
    }

    // swiftlint:disable function_parameter_count
    /// Executes every step of `plan` in order. `sink` receives each record as soon as its step ends.
    static func execute(
        plan: ComparisonExecutionPlan,
        corpus: ComparisonCorpus,
        evidence: Evidence,
        processor: LegalDictationProcessor,
        runID: String,
        instructions: String,
        proposer: ComparisonProposer,
        hooks: ComparisonExecutionHooks = ComparisonExecutionHooks(),
        clock: () -> Date = { Date() },
        sink: (ComparisonCallRecord) -> Void
    ) async throws {
        let toolHash = self.toolDefinitionSHA256()
        guard toolHash == ComparisonExecutionPlan.baselineToolDefinitionSHA256
        else { throw ExecutionError.refused("tool definition differs from the pinned V1.21 definition") }
        let instructionsHash = CapabilitySHA256.hex(of: instructions)
        let expectedHash = plan.arm == .baselineV121 ? ComparisonExecutionPlan.baselineInstructionsSHA256 : ComparisonExecutionPlan
            .variantInstructionsSHA256
        guard instructionsHash == expectedHash else { throw ExecutionError.refused("instructions do not match the plan's contract arm") }
        if evidence == .developmentCorpus {
            guard corpus.sha256 == ComparisonCorpus.frozenSHA256, corpus.entries.count == 66, plan.steps.count == plan.candidates.count * 78 else {
                throw ExecutionError.refused("a development-corpus run needs the pinned corpus and the full pre-registered plan")
            }
        }
        let entries = Dictionary(uniqueKeysWithValues: corpus.entries.map { ($0.id, $0) })
        guard plan.steps.allSatisfy({ entries[$0.entryID] != nil })
        else { throw ExecutionError.refused("a plan step names an entry that is not in the corpus") }
        let candidates = Dictionary(uniqueKeysWithValues: plan.candidates.map { ($0.id, $0) })

        var current: String?
        var lastStepOfCandidate: [String: Int] = [:]
        for step in plan.steps {
            lastStepOfCandidate[step.candidateID] = step.sequence
        }
        var observedFirst = Set<String>()
        for step in plan.steps {
            guard let candidate = candidates[step.candidateID],
                  let entry = entries[step.entryID] else { throw ExecutionError.refused("unknown step reference") }
            if current != candidate.id {
                if let previous = current, let finished = candidates[previous] {
                    try await hooks.candidateDidFinish(finished)
                }
                try await hooks.candidateWillStart(candidate)
                current = candidate.id
            }
            var record = ComparisonCallRecord(
                runID: runID,
                sequence: step.sequence,
                stage: ComparisonExecutionPlan.stage,
                evidenceKind: evidence.rawValue,
                corpusSHA256: corpus.sha256,
                candidateID: candidate.id,
                ollamaTag: candidate.ollamaTag,
                contractArm: plan.arm.rawValue,
                contractInstructionsSHA256: instructionsHash,
                toolDefinitionSHA256: toolHash,
                phase: step.phase.rawValue,
                entryID: entry.id,
                entryOrdinal: step.entryOrdinal,
                rawInputText: entry.text,
                legalNormalizedText: nil,
                requestFingerprintSHA256: nil,
                preflightFailure: nil,
                startedAt: self.iso(clock()),
                finishedAt: "",
                latencyMilliseconds: nil,
                providerFailure: nil,
                modelTextContent: nil,
                modelThinking: nil,
                toolCallNames: [],
                rawToolCallArguments: [],
                runtimeObservation: nil
            )
            switch IntelligenceHarnessPipeline.preflight(rawInputText: entry.text, processor: processor) {
            case let .failure(reason):
                record.preflightFailure = reason.description
            case let .success(pre):
                record.legalNormalizedText = pre.normalizedText
                record.requestFingerprintSHA256 = self.requestFingerprint(
                    model: candidate.ollamaTag,
                    instructionsSHA256: instructionsHash,
                    userText: pre.normalizedText,
                    toolDefinitionSHA256: toolHash
                )
                let began = clock()
                // The one and only attempt for this step.
                let outcome = await proposer(ComparisonProposerRequest(
                    candidate: candidate,
                    contractArm: plan.arm,
                    instructions: instructions,
                    userText: pre.normalizedText
                ))
                let ended = clock()
                record.latencyMilliseconds = max(0, Int((ended.timeIntervalSince(began) * 1000).rounded()))
                if let failure = outcome.failure {
                    record.providerFailure = failure
                } else if let response = outcome.response {
                    record.modelTextContent = response.textContent
                    record.toolCallNames = response.toolCalls.map(\.name)
                    record.rawToolCallArguments = response.toolCalls.map(\.rawArguments)
                } else {
                    record.providerFailure = "proposer returned neither a response nor a failure"
                }
                record.modelThinking = outcome.thinking
            }
            record.finishedAt = self.iso(clock())
            // Runtime observation: after the candidate's first call and after its last, recorded not gated.
            if record.latencyMilliseconds != nil, !observedFirst.contains(candidate.id) {
                observedFirst.insert(candidate.id)
                record.runtimeObservation = await hooks.runtimeObservation(candidate)
            } else if lastStepOfCandidate[candidate.id] == step.sequence {
                record.runtimeObservation = await hooks.runtimeObservation(candidate)
            }
            sink(record)
        }
        if let last = current, let finished = candidates[last] {
            try await hooks.candidateDidFinish(finished)
        }
    }
}

// swiftlint:enable function_parameter_count
