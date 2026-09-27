import Foundation

/// Adversarial coverage for `IntelligenceProviderResponseAdapter`, plus
/// synthetic end-to-end tests proving the full, separated chain:
///   `IntelligenceProviderResponse` (synthetic, local)
///   -> `IntelligenceProviderResponseAdapter` (response-shape policy only)
///   -> `IntelligenceProposalTransportParser` (structural trust boundary)
///   -> `IntelligenceSafetyAuthority` (sole semantic authority)
/// No network call, model process, or live inference occurs anywhere in
/// this file -- every response is constructed directly as a Swift value.
@main
enum IntelligenceProviderResponseAdapterTests {
    static func main() {
        testNoToolCall()
        testWrongToolName()
        testTwoExpectedToolCalls()
        testExpectedPlusUnexpectedToolCall()
        testMultipleUnexpectedCalls()
        testTextualAnswerInsteadOfToolCall()
        testTextualAnswerAlongsideExpectedToolCall()
        testEmptyTextContentAlongsideToolCallIsFine()
        testEmptyArgumentStringPassesThroughToV11()
        testMalformedArgumentJSONPassesThroughToV11()
        testUnsupportedSchemaVersionPassesThroughToV11()
        testDuplicateJSONKeysPassThroughToV11()
        testUnknownFieldPassesThroughToV11()
        testOverProposalCountLimitPassesThroughToV11()
        testWholeNumberFloatIntegerFieldPassesThroughToV11()
        testAdapterNeverRepairsMalformedJSON()

        testEndToEndSafeProposalAccepted()
        testEndToEndZeroProposalsIsValid()
        testEndToEndMaliciousLexicalProposalRejectedBySafetyAuthority()
        testEndToEndProtectedMutationIsReviewOnlyNeverApplied()
        testEndToEndStaleSourceRejectedBySafetyAuthority()

        print("PASS: IntelligenceProviderResponseAdapter adversarial and end-to-end suite")
    }

    // MARK: - Fixture helpers

    private static let toolName = IntelligenceGenerationContract.toolName

    private static func call(_ rawArguments: String, name: String? = nil) -> IntelligenceProviderToolCall {
        IntelligenceProviderToolCall(name: name ?? self.toolName, rawArguments: rawArguments)
    }

    private static func assertAdapterFails(
        _ label: String,
        _ response: IntelligenceProviderResponse,
        expected: IntelligenceAdapterFailure,
        line: Int = #line
    ) {
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case .success:
            preconditionFailure("[line \(line)] \(label): expected \(expected) but extraction succeeded")
        case let .failure(failure):
            precondition(failure == expected, "[line \(line)] \(label): expected \(expected), got \(failure)")
        }
    }

    // MARK: - Expected tool-call semantics (adversarial)

    private static func testNoToolCall() {
        self.assertAdapterFails("no tool call, no text", IntelligenceProviderResponse(), expected: .noToolCall)
    }

    private static func testWrongToolName() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1,"proposals":[]}"#, name: "some_other_tool")])
        self.assertAdapterFails("wrong tool name", response, expected: .unexpectedToolName("some_other_tool"))
    }

    private static func testTwoExpectedToolCalls() {
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call(#"{"schemaVersion":1,"proposals":[]}"#),
            self.call(#"{"schemaVersion":1,"proposals":[]}"#),
        ])
        self.assertAdapterFails("two calls to the expected tool", response, expected: .multipleToolCalls(count: 2))
    }

    private static func testExpectedPlusUnexpectedToolCall() {
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call(#"{"schemaVersion":1,"proposals":[]}"#),
            self.call("{}", name: "unrelated_tool"),
        ])
        self.assertAdapterFails("expected tool plus an unrelated one", response, expected: .multipleToolCalls(count: 2))
    }

    private static func testMultipleUnexpectedCalls() {
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call("{}", name: "tool_a"),
            self.call("{}", name: "tool_b"),
        ])
        self.assertAdapterFails("multiple unrelated calls, none expected", response, expected: .multipleToolCalls(count: 2))
    }

    private static func testTextualAnswerInsteadOfToolCall() {
        let response = IntelligenceProviderResponse(textContent: "Here is my answer: the text looks fine.")
        self.assertAdapterFails("prose instead of a tool call", response, expected: .unexpectedTextContent)
    }

    private static func testTextualAnswerAlongsideExpectedToolCall() {
        // Strict policy (per architectural decision): the model should not
        // need prose for this contract, so text alongside an otherwise
        // perfectly valid call still fails closed rather than being
        // tolerated.
        let response = IntelligenceProviderResponse(
            textContent: "I propose the following edit:",
            toolCalls: [self.call(#"{"schemaVersion":1,"proposals":[]}"#)]
        )
        self.assertAdapterFails("prose alongside an otherwise-valid tool call", response, expected: .unexpectedTextContent)
    }

    private static func testEmptyTextContentAlongsideToolCallIsFine() {
        // An empty (or whitespace-only) content field is common,
        // harmless provider behavior alongside a tool call -- not
        // "textual content" for this policy's purposes.
        let response = IntelligenceProviderResponse(textContent: "   ", toolCalls: [self.call(#"{"schemaVersion":1,"proposals":[]}"#)])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case .success: break
        case let .failure(failure): preconditionFailure("empty/whitespace-only text alongside a valid call should not fail: \(failure)")
        }
    }

    // MARK: - The adapter never repairs -- everything below reaches V1.1 verbatim

    private static func testEmptyArgumentStringPassesThroughToV11() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call("")])
        self.assertAdapterFails("empty argument string", response, expected: .transportParseFailure(.invalidRootStructure))
    }

    private static func testMalformedArgumentJSONPassesThroughToV11() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call("{not valid json")])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case .success: preconditionFailure("malformed JSON must not parse")
        case let .failure(failure):
            guard case .transportParseFailure = failure else { preconditionFailure("expected a wrapped transport failure, got \(failure)") }
        }
    }

    private static func testUnsupportedSchemaVersionPassesThroughToV11() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":99,"proposals":[]}"#)])
        self.assertAdapterFails("unsupported schema version", response, expected: .transportParseFailure(.unsupportedSchemaVersion))
    }

    private static func testDuplicateJSONKeysPassThroughToV11() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1,"schemaVersion":2,"proposals":[]}"#)])
        self.assertAdapterFails("duplicate JSON keys", response, expected: .transportParseFailure(.duplicateKey("schemaVersion")))
    }

    private static func testUnknownFieldPassesThroughToV11() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1,"proposals":[],"confidence":0.9}"#)])
        self.assertAdapterFails("unknown top-level field", response, expected: .transportParseFailure(.unknownField("confidence")))
    }

    private static func testOverProposalCountLimitPassesThroughToV11() {
        let tooMany = (0...IntelligenceProposalTransportLimits.maxProposalCount).map { index in
            #"{"id":"p\#(index)","rangeStart":0,"rangeLength":1,"expectedSourceText":"a","replacementText":"A","claimedCategory":"capitalization"}"#
        }.joined(separator: ",")
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1,"proposals":[\#(tooMany)]}"#)])
        self.assertAdapterFails("proposal count over the V1.1 limit", response, expected: .transportParseFailure(.proposalCountExceeded))
    }

    private static func testWholeNumberFloatIntegerFieldPassesThroughToV11() {
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1.0,"proposals":[]}"#)])
        self.assertAdapterFails("whole-number float in an integer field", response, expected: .transportParseFailure(.invalidFieldType("schemaVersion")))
    }

    private static func testAdapterNeverRepairsMalformedJSON() {
        // A markdown-fenced response is a realistic way a model might
        // misbehave -- the adapter must NOT strip the fence or search for
        // embedded JSON; it must pass the raw text through and let it fail.
        let fenced = "```json\n{\"schemaVersion\":1,\"proposals\":[]}\n```"
        let response = IntelligenceProviderResponse(toolCalls: [self.call(fenced)])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case .success: preconditionFailure("a markdown-fenced payload must not be silently repaired into validity")
        case let .failure(failure):
            guard case .transportParseFailure = failure else { preconditionFailure("expected a wrapped transport failure, got \(failure)") }
        }
    }

    // MARK: - End-to-end synthetic chain: adapter -> V1.1 parser -> V1.0 Safety Authority

    private static func testEndToEndSafeProposalAccepted() {
        let source = "the accused was present"
        let theRange = (source as NSString).range(of: "the")
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call(#"{"schemaVersion":1,"proposals":[{"id":"p1","rangeStart":\#(theRange.location),"rangeLength":\#(theRange.length),"expectedSourceText":"the","replacementText":"The","claimedCategory":"capitalization"}]}"#),
        ])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case let .success(batch):
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: [])
            precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.capitalizationOnly), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == "The accused was present", result.resultingText)
        case let .failure(failure):
            preconditionFailure("expected the safe proposal to traverse the whole chain: \(failure)")
        }
    }

    private static func testEndToEndZeroProposalsIsValid() {
        let source = "the text is already correct."
        let response = IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1,"proposals":[]}"#)])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case let .success(batch):
            precondition(batch.proposals.isEmpty)
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: [])
            precondition(result.resultingText == source)
        case let .failure(failure):
            preconditionFailure("an empty proposals array is a legitimate, preferred response: \(failure)")
        }
    }

    private static func testEndToEndMaliciousLexicalProposalRejectedBySafetyAuthority() {
        let source = "charged under IPC for the offence."
        let ipcRange = (source as NSString).range(of: "IPC")
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call(#"{"schemaVersion":1,"proposals":[{"id":"p1","rangeStart":\#(ipcRange.location),"rangeLength":\#(ipcRange.length),"expectedSourceText":"IPC","replacementText":"CrPC","claimedCategory":"punctuation"}]}"#),
        ])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case let .success(batch):
            precondition(batch.proposals[0].claimedCategory == .punctuation, "the adapter/parser must preserve, never second-guess, the claimed category")
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: [])
            precondition(result.outcomes[0].disposition == .rejected(.unsupportedEditCategory), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == source, "a lying proposal must never reach the resulting text, even though it parsed successfully")
        case let .failure(failure):
            preconditionFailure("a structurally valid but semantically dishonest proposal must still traverse the adapter and parser: \(failure)")
        }
    }

    private static func testEndToEndProtectedMutationIsReviewOnlyNeverApplied() {
        let source = "arrested on 16 March 2026 near the market."
        let dateRange = (source as NSString).range(of: "16 March 2026")
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call(#"{"schemaVersion":1,"proposals":[{"id":"p1","rangeStart":\#(dateRange.location),"rangeLength":\#(dateRange.length),"expectedSourceText":"16 March 2026","replacementText":"15 March 2026","claimedCategory":"other"}]}"#),
        ])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case let .success(batch):
            let result = IntelligenceSafetyAuthority.validate(
                proposals: batch.proposals,
                source: source,
                protectedSpans: [ProtectedSpan(range: dateRange, kind: .independentlyProtected)]
            )
            precondition(result.outcomes[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == source, "review-only must never be applied")
        case let .failure(failure):
            preconditionFailure("a structurally valid protected-content mutation must still traverse the adapter and parser: \(failure)")
        }
    }

    private static func testEndToEndStaleSourceRejectedBySafetyAuthority() {
        let source = "the accused shall appear on 16 March 2026"
        let realRange = (source as NSString).range(of: "16 March")
        let response = IntelligenceProviderResponse(toolCalls: [
            self.call(#"{"schemaVersion":1,"proposals":[{"id":"p1","rangeStart":\#(realRange.location),"rangeLength":\#(realRange.length),"expectedSourceText":"15 March","replacementText":"16 March","claimedCategory":"other"}]}"#),
        ])
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: response) {
        case let .success(batch):
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: [])
            precondition(result.outcomes[0].disposition == .rejected(.sourceTextMismatch), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == source)
        case let .failure(failure):
            preconditionFailure("a structurally valid but stale proposal must still traverse the adapter and parser: \(failure)")
        }
    }
}
