import Foundation

/// Intelligence V1.27 -- Model Comparison Development Corpus & Protocol.
///
/// Stored hazard-edit fixtures: known dangerous (and a few known safe) proposals replayed through
/// the **real, unmodified deterministic chain** (legal normalization, protected spans, addressing,
/// composition, Safety Authority, V1.16 gate) with **no model**. This exercises the safeguards
/// independently of what any candidate proposes (V1.23 limitation: the model proposed none of the
/// hazard edits). Expected dispositions come from the documented rules, never from observation.
struct ComparisonFixtureFile: Decodable {
    struct Edit: Decodable {
        let sourceText: String
        let replacementText: String
        let occurrence: Int?
        let leftContext: String?
        let rightContext: String?
    }

    struct Expectation: Decodable {
        let bucket: String
        let reasonAnyOf: [String]
    }

    struct Fixture: Decodable {
        let id: String
        let entryRef: String?
        let kind: String
        let text: String
        let proposedEdits: [Edit]
        let expect: [Expectation]
        let rationale: String
    }

    let schemaVersion: Int
    let description: String
    let fixtures: [Fixture]
}

struct ComparisonFixtureResult {
    let fixture: ComparisonFixtureFile.Fixture
    /// One `(bucket, addressing + disposition summary)` per proposed edit; empty when the chain rejected the whole response (see `failure`).
    let observed: [(bucket: String, summary: String)]
    let failure: String?
    let matchesExpectation: Bool
    /// A hazard or negative fixture whose edit was autonomously accepted (must never happen).
    let hazardAutonomouslyAccepted: Bool
}

enum ComparisonFixtureReplay {
    static func load(from url: URL) throws -> ComparisonFixtureFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ComparisonFixtureFile.self, from: data)
    }

    static func rawArguments(_ edits: [ComparisonFixtureFile.Edit]) -> String {
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "edits": edits.map { edit -> [String: Any] in
                var item: [String: Any] = ["sourceText": edit.sourceText, "replacementText": edit.replacementText]
                if let occurrence = edit.occurrence {
                    item["occurrence"] = occurrence
                }
                if let left = edit.leftContext {
                    item["leftContext"] = left
                }
                if let right = edit.rightContext {
                    item["rightContext"] = right
                }
                return item
            },
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }

    /// Strips `<Module>.` prefixes from `String(describing:)` renderings of nested enum values (cosmetic only).
    static func cleanReason(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9_]+\\.(?=[A-Z][A-Za-z0-9_]*\\.)") else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    static func replay(_ file: ComparisonFixtureFile, processor: LegalDictationProcessor) -> [ComparisonFixtureResult] {
        file.fixtures.map { fixture in
            guard case let .success(pre) = IntelligenceHarnessPipeline.preflight(rawInputText: fixture.text, processor: processor) else {
                return ComparisonFixtureResult(fixture: fixture, observed: [], failure: "preflight failed", matchesExpectation: false, hazardAutonomouslyAccepted: false)
            }
            let response = IntelligenceProviderResponse(toolCalls: [
                IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: self.rawArguments(fixture.proposedEdits)),
            ])
            switch IntelligenceHarnessPipeline.evaluate(response: response, normalizedText: pre.normalizedText, protectedSpans: pre.protectedSpans) {
            case let .failure(reason):
                return ComparisonFixtureResult(fixture: fixture, observed: [], failure: reason.description, matchesExpectation: false, hazardAutonomouslyAccepted: false)
            case let .success(sample):
                let observed = sample.edits.map { (bucket: $0.bucket.rawValue, summary: self.cleanReason($0.addressingSummary + " " + $0.dispositionSummary)) }
                var matches = observed.count == fixture.expect.count
                if matches {
                    for (item, expectation) in zip(observed, fixture.expect) {
                        if item.bucket != expectation.bucket || !expectation.reasonAnyOf.contains(where: { item.summary.contains($0) }) {
                            matches = false
                        }
                    }
                }
                let accepted = fixture.kind != "positive-control" && observed.contains { $0.bucket == "autonomouslyAccepted" }
                return ComparisonFixtureResult(fixture: fixture, observed: observed, failure: nil, matchesExpectation: matches, hazardAutonomouslyAccepted: accepted)
            }
        }
    }
}
