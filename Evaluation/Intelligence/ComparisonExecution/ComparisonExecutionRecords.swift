import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: the raw per-call record.
///
/// One record per plan step, written as one JSON line the moment the step finishes. It holds only what was
/// *observed or sent* -- never a derived judgement -- so every S3 metric is recomputed afterwards from these
/// records by `ComparisonScoring`/`ComparisonAnalysis`, with the committed deterministic chain, and cannot
/// be reinterpreted after seeing results. Records contain development-corpus text and model output: they are
/// written outside the Git repository (the live runner refuses an in-repo output directory).
struct ComparisonCallRecord: Codable, Equatable {
    var runID: String
    var sequence: Int
    var stage: String
    /// `developmentCorpus` for a live run; `toolingFixture` for mechanics tests (never scored as evidence).
    var evidenceKind: String
    var corpusSHA256: String
    var candidateID: String
    var ollamaTag: String
    var contractArm: String
    var contractInstructionsSHA256: String
    var toolDefinitionSHA256: String
    /// `screening` or `audit`.
    var phase: String
    var entryID: String
    var entryOrdinal: Int
    var rawInputText: String
    /// The exact user message sent (`NormalizationOutcome.normalized`); nil only if preflight failed.
    var legalNormalizedText: String?
    /// SHA-256 of the canonical request (model, system instructions, user text, tool definition hash, parameters).
    var requestFingerprintSHA256: String?
    var preflightFailure: String?
    var startedAt: String
    var finishedAt: String
    /// Wall-clock milliseconds around the single provider call; nil when no call was made.
    var latencyMilliseconds: Int?
    /// Set when the provider call failed (timeout, transport error, ...). Never retried.
    var providerFailure: String?
    var modelTextContent: String?
    var modelThinking: String?
    var toolCallNames: [String]
    /// Each tool call's raw, undecoded argument text exactly as returned.
    var rawToolCallArguments: [String]
    /// Optional runtime observation (e.g. a `/api/ps` snapshot) taken after this call; recorded, never gated.
    var runtimeObservation: String?
}

enum ComparisonRecordCoding {
    static func line(_ record: ComparisonCallRecord) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(record), let text = String(bytes: data, encoding: .utf8) else { preconditionFailure("record encoding") }
        return text
    }

    static func jsonLines(_ records: [ComparisonCallRecord]) -> String {
        records.map(self.line).joined(separator: "\n") + "\n"
    }

    static func decode(jsonLines text: String) throws -> [ComparisonCallRecord] {
        try text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { try JSONDecoder().decode(ComparisonCallRecord.self, from: Data($0.utf8)) }
    }
}

/// Runtime lifecycle evidence: every request the live runner makes that is NOT a proposer inference call (identity
/// probes, resident-model checks, the `keep_alive: 0` unload and its verification). Written to `lifecycle.jsonl`, a file
/// separate from `records.jsonl`. These events never enter a `ComparisonCallRecord`, a step sequence number, a count,
/// a latency statistic or any metric; `ComparisonLifecycleAudit` proves that accounting from the two files.
struct ComparisonLifecycleEvent: Codable, Equatable {
    enum Kind: String, Codable {
        case identityProbe, residentCheck, unloadRequest, unloadVerification
    }

    var runID: String
    /// Own 1-based sequence; unrelated to the proposer step sequence.
    var sequence: Int
    var kind: Kind
    /// Candidate the event concerns (nil for run-level probes).
    var candidateID: String?
    var ollamaTag: String?
    /// e.g. `GET /api/ps`, `POST /api/generate`.
    var endpoint: String
    /// Canonical request body for a POST (sorted keys), nil for GETs. An unload body carries `keep_alive` 0 and no `prompt`.
    var requestBody: String?
    var startedAt: String
    var finishedAt: String
    var httpStatus: Int?
    /// Model names resident after the request, meaningful only when `residentObserved` (from `/api/ps`).
    var residentModelsAfter: [String]
    var residentObserved: Bool
    /// Always false: lifecycle requests are never inference.
    var countsAsInference: Bool
    var note: String?
}

enum ComparisonLifecycleCoding {
    static func line(_ event: ComparisonLifecycleEvent) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(event), let text = String(bytes: data, encoding: .utf8) else { preconditionFailure("event encoding") }
        return text
    }

    static func decode(jsonLines text: String) throws -> [ComparisonLifecycleEvent] {
        try text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { try JSONDecoder().decode(ComparisonLifecycleEvent.self, from: Data($0.utf8)) }
    }

    /// Canonical body of the unload request for a model.
    static func unloadBody(tag: String) -> String {
        let object: [String: Any] = ["model": tag, "keep_alive": 0]
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}

/// Verifies, from the two evidence files and the plan, that lifecycle requests are auditable as non-proposer requests and
/// excluded from inference accounting. Returns problems (empty = verified) and the summary lines for the report.
enum ComparisonLifecycleAudit {
    struct Result {
        let problems: [String]
        let lines: [String]
    }

    static func verify(events: [ComparisonLifecycleEvent], records: [ComparisonCallRecord], plan: ComparisonExecutionPlan) -> Result {
        var problems: [String] = []
        let ordered = events.sorted { $0.sequence < $1.sequence }
        if ordered.map(\.sequence) != Array(0..<ordered.count).map({ $0 + 1 }) {
            problems.append("lifecycle sequence is not contiguous from 1")
        }
        if Set(ordered.map(\.runID) + records.map(\.runID)).count > 1 {
            problems.append("lifecycle run id differs from the proposer records' run id")
        }
        if ordered.contains(where: \.countsAsInference) {
            problems.append("a lifecycle event is marked as inference")
        }
        // Proposer accounting is exactly the plan: lifecycle events add nothing to it.
        if records.count != plan.steps.count {
            problems.append("proposer records \(records.count) != plan steps \(plan.steps.count)")
        }
        if records.contains(where: { $0.runtimeObservation?.contains("keep_alive") == true }) {
            problems.append("a proposer record contains lifecycle data")
        }
        let unloads = ordered.filter { $0.kind == .unloadRequest }
        if unloads.map({ $0.candidateID ?? "" }) != plan.candidates.map(\.id) {
            problems
                .append("unload requests \(unloads.map { $0.candidateID ?? "?" }) != one per candidate in plan order \(plan.candidates.map(\.id))")
        }
        for unload in unloads {
            let tag = plan.candidates.first { $0.id == unload.candidateID }?.ollamaTag ?? ""
            if unload.endpoint != "POST /api/generate" || unload.requestBody != ComparisonLifecycleCoding.unloadBody(tag: tag) {
                problems.append("\(unload.candidateID ?? "?"): unload is not exactly a keep_alive-0 request for \(tag)")
            }
            if unload.requestBody?.contains("prompt") == true || unload.requestBody?.contains("messages") == true {
                problems.append("\(unload.candidateID ?? "?"): an unload carries prompt content")
            }
            let verified = ordered.first { $0.kind == .unloadVerification && $0.candidateID == unload.candidateID && $0.sequence > unload.sequence }
            if verified?.residentObserved != true || verified?.residentModelsAfter.isEmpty != true {
                problems.append("\(unload.candidateID ?? "?"): no verification of an empty resident-model list after the unload")
            }
            // The unload must come after that candidate's last proposer call (by time).
            let last = records.filter { $0.candidateID == unload.candidateID }.map(\.finishedAt).max() ?? ""
            if unload.startedAt < last {
                problems.append("\(unload.candidateID ?? "?"): unload started before the candidate's last proposer call finished")
            }
        }
        let kinds = Dictionary(grouping: ordered, by: \.kind).mapValues(\.count)
        let lines = [
            "- proposer records: \(records.count) (plan steps \(plan.steps.count)); only these feed counts, latency and metrics",
            "- lifecycle events: \(ordered.count) \(kinds.map { "\($0.key.rawValue)=\($0.value)" }.sorted()), all `countsAsInference` false",
            "- unload requests (`POST /api/generate`, `keep_alive` 0, no prompt): \(unloads.count), one per candidate",
            "- lifecycle verification: \(problems.isEmpty ? "passed" : "FAILED: " + problems.joined(separator: "; "))",
        ]
        return Result(problems: problems, lines: lines)
    }
}
