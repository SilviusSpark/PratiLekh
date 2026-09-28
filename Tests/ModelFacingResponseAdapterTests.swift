import Foundation

/// Coverage for `ModelFacingResponseAdapter` and the full, separated chain:
///   `IntelligenceProviderResponse` (raw arguments, synthetic)
///   -> `ModelFacingResponseAdapter` (tool-call policy only)
///   -> `ModelFacingEditTransportParser` (strict wire parse)
///   -> `IntelligenceAddressingBridge` (V1.6 resolution, isolated per edit)
///   -> `IntelligenceSafetyAuthority` (unmodified, sole semantic authority)
/// No model, no network: every response is a Swift value.
@main
enum ModelFacingResponseAdapterTests {
    static func main() {
        // Tool-call policy (parity with the V1.2 adapter's cases).
        self.testNoToolCall()
        self.testWrongToolNameIncludingTheInternalContractsName()
        self.testTwoExpectedToolCalls()
        self.testExpectedPlusUnexpectedToolCall()
        self.testTextualAnswerInsteadOfToolCall()
        self.testTextualAnswerAlongsideExpectedToolCall()
        self.testWhitespaceOnlyTextAlongsideToolCallIsFine()

        // Raw arguments reach the strict parser verbatim; never repaired.
        self.testEmptyArgumentsFailAtTheParser()
        self.testMalformedJSONFailsAtTheParserWithoutRepair()
        self.testMarkdownFencedPayloadIsNotRepaired()
        self.testDuplicateKeyInRawArgumentsIsDetected()
        self.testWholeNumberFloatOccurrenceInRawArgumentsIsDetected()
        self.testInternalContractPayloadUnderTheNewToolNameIsRejected()
        self.testUnusualRawSpacingAndUnicodeSurviveToTheEdits()

        // Full chain, through the unmodified Safety Authority.
        self.testEndToEndSafeEditAccepted()
        self.testEndToEndRepeatedTextResolvedByOccurrence()
        self.testEndToEndZeroEditsIsValid()
        self.testEndToEndOccurrenceZeroRescuedByContextButUnrescuedIsIsolated()
        self.testEndToEndEmptySourceTextAndHallucinationAreIsolatedPerEdit()
        self.testEndToEndLexicalEditResolvesButAuthorityRejects()
        self.testEndToEndWholePassageSpanResolvesButAuthorityRejects()
        self.testEndToEndProtectedSpanStillBlocksAResolvedEdit()
        self.testEndToEndWireFailureNeverReachesTheBridge()
        self.testEndToEndOdiaAndEmojiSourcesUseSwiftDerivedUTF16()

        print("PASS: ModelFacingResponseAdapter policy and end-to-end (parser -> V1.6 bridge -> Safety Authority) suite")
    }

    // MARK: - Helpers

    private static func call(_ raw: String, name: String = ModelFacingGenerationContract.toolName) -> IntelligenceProviderToolCall {
        IntelligenceProviderToolCall(name: name, rawArguments: raw)
    }

    private static func response(_ raw: String) -> IntelligenceProviderResponse {
        IntelligenceProviderResponse(toolCalls: [self.call(raw)])
    }

    private static func edits(_ body: String) -> String {
        #"{"schemaVersion":1,"edits":[\#(body)]}"#
    }

    private static func expectExtractFailure(_ label: String, _ response: IntelligenceProviderResponse, _ expected: ModelFacingAdapterFailure, file: StaticString = #file, line: UInt = #line) {
        switch ModelFacingResponseAdapter.extractEdits(from: response) {
        case .success: preconditionFailure("\(label): expected \(expected)", file: file, line: line)
        case let .failure(failure): precondition(failure == expected, "\(label): expected \(expected), got \(failure)", file: file, line: line)
        }
    }

    private static func resolved(_ raw: String, source: String, file: StaticString = #file, line: UInt = #line) -> IntelligenceAddressingBatchResult {
        switch ModelFacingResponseAdapter.resolveEdits(from: self.response(raw), source: source) {
        case let .success(batch): return batch
        case let .failure(failure): preconditionFailure("expected the response to reach the bridge, got \(failure)", file: file, line: line)
        }
    }

    private static func validate(_ batch: IntelligenceAddressingBatchResult, source: String, protectedSpans: [ProtectedSpan] = []) -> IntelligenceSafetyAuthority.Result {
        IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: protectedSpans)
    }

    private static func disposition(_ result: IntelligenceSafetyAuthority.Result, id: String) -> ProposalDisposition {
        guard let outcome = result.outcomes.first(where: { $0.proposal.id == id }) else { preconditionFailure("no Authority outcome for \(id)") }
        return outcome.disposition
    }

    // MARK: - Tool-call policy

    private static func testNoToolCall() {
        self.expectExtractFailure("no tool call", IntelligenceProviderResponse(), .noToolCall)
    }

    private static func testWrongToolNameIncludingTheInternalContractsName() {
        self.expectExtractFailure("unrelated name", IntelligenceProviderResponse(toolCalls: [self.call("{}", name: "something_else")]), .unexpectedToolName("something_else"))
        // The V1.2 internal contract's tool must not be accepted here, even
        // with an otherwise valid-looking payload.
        self.expectExtractFailure(
            "internal contract's tool name",
            IntelligenceProviderResponse(toolCalls: [self.call(#"{"schemaVersion":1,"edits":[]}"#, name: IntelligenceGenerationContract.toolName)]),
            .unexpectedToolName(IntelligenceGenerationContract.toolName)
        )
    }

    private static func testTwoExpectedToolCalls() {
        let valid = self.call(#"{"schemaVersion":1,"edits":[]}"#)
        self.expectExtractFailure("two calls", IntelligenceProviderResponse(toolCalls: [valid, valid]), .multipleToolCalls(count: 2))
    }

    private static func testExpectedPlusUnexpectedToolCall() {
        let valid = self.call(#"{"schemaVersion":1,"edits":[]}"#)
        self.expectExtractFailure("expected plus other", IntelligenceProviderResponse(toolCalls: [valid, self.call("{}", name: "other")]), .multipleToolCalls(count: 2))
    }

    private static func testTextualAnswerInsteadOfToolCall() {
        self.expectExtractFailure("prose only", IntelligenceProviderResponse(textContent: "The text looks fine."), .unexpectedTextContent)
    }

    private static func testTextualAnswerAlongsideExpectedToolCall() {
        self.expectExtractFailure(
            "prose alongside a valid call",
            IntelligenceProviderResponse(textContent: "Here are my edits:", toolCalls: [self.call(#"{"schemaVersion":1,"edits":[]}"#)]),
            .unexpectedTextContent
        )
    }

    private static func testWhitespaceOnlyTextAlongsideToolCallIsFine() {
        switch ModelFacingResponseAdapter.extractEdits(from: IntelligenceProviderResponse(textContent: "  \n", toolCalls: [self.call(#"{"schemaVersion":1,"edits":[]}"#)])) {
        case .success: break
        case let .failure(failure): preconditionFailure("whitespace-only text is harmless: \(failure)")
        }
    }

    // MARK: - Raw arguments -> strict parser

    private static func testEmptyArgumentsFailAtTheParser() {
        self.expectExtractFailure("empty arguments", self.response(""), .wireParseFailure(.invalidRootStructure))
    }

    private static func testMalformedJSONFailsAtTheParserWithoutRepair() {
        self.expectExtractFailure("truncated JSON", self.response(#"{"schemaVersion":1,"edits":[{"sourceText":"a""#), .wireParseFailure(.invalidRootStructure))
    }

    private static func testMarkdownFencedPayloadIsNotRepaired() {
        self.expectExtractFailure("fenced payload", self.response("```json\n{\"schemaVersion\":1,\"edits\":[]}\n```"), .wireParseFailure(.invalidRootStructure))
    }

    private static func testDuplicateKeyInRawArgumentsIsDetected() {
        // Unrecoverable from a decoded dictionary; only the preserved raw
        // text can reveal it.
        self.expectExtractFailure("duplicate occurrence key", self.response(self.edits(#"{"sourceText":"a","replacementText":"b","occurrence":1,"occurrence":2}"#)), .wireParseFailure(.duplicateKey("occurrence")))
    }

    private static func testWholeNumberFloatOccurrenceInRawArgumentsIsDetected() {
        self.expectExtractFailure("occurrence 1.0", self.response(self.edits(#"{"sourceText":"a","replacementText":"b","occurrence":1.0}"#)), .wireParseFailure(.invalidFieldType("occurrence")))
    }

    private static func testInternalContractPayloadUnderTheNewToolNameIsRejected() {
        let internalShape = #"{"schemaVersion":1,"proposals":[{"id":"p1","rangeStart":0,"rangeLength":3,"expectedSourceText":"the","replacementText":"The","claimedCategory":"capitalization"}]}"#
        self.expectExtractFailure("V1.1 shaped payload", self.response(internalShape), .wireParseFailure(.unknownField("proposals")))
    }

    private static func testUnusualRawSpacingAndUnicodeSurviveToTheEdits() {
        let raw = "  {\n\t\"schemaVersion\" :1 ,\n \"edits\":[ {\"sourceText\":\"\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}\" , \"replacementText\" : \"\u{1F60A}\" } ]\n}\n  "
        switch ModelFacingResponseAdapter.extractEdits(from: self.response(raw)) {
        case let .success(batch):
            precondition(batch.edits == [ModelFacingEdit(sourceText: "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}", replacementText: "\u{1F60A}")])
        case let .failure(failure): preconditionFailure("valid payload with unusual spacing must parse: \(failure)")
        }
    }

    // MARK: - End to end

    private static func testEndToEndSafeEditAccepted() {
        let source = "the accused left. the witness spoke"
        let batch = self.resolved(self.edits(#"{"sourceText":". the","replacementText":". The"}"#), source: source)
        let result = self.validate(batch, source: source)
        guard case .autonomouslyAccepted(.capitalizationOnly) = self.disposition(result, id: "p1") else {
            preconditionFailure("safe edit should traverse the whole chain: \(self.disposition(result, id: "p1"))")
        }
        precondition(result.resultingText == "the accused left. The witness spoke")
    }

    private static func testEndToEndRepeatedTextResolvedByOccurrence() {
        let source = "the accused said the accused left"
        let batch = self.resolved(self.edits(#"{"sourceText":"the","replacementText":"The","occurrence":2}"#), source: source)
        let result = self.validate(batch, source: source)
        guard case .autonomouslyAccepted = self.disposition(result, id: "p1") else { preconditionFailure("occurrence-addressed edit should be accepted") }
        precondition(result.resultingText == "the accused said The accused left")
    }

    private static func testEndToEndZeroEditsIsValid() {
        let source = "already correct."
        let batch = self.resolved(#"{"schemaVersion":1,"edits":[]}"#, source: source)
        precondition(batch.items.isEmpty)
        precondition(self.validate(batch, source: source).resultingText == source)
    }

    private static func testEndToEndOccurrenceZeroRescuedByContextButUnrescuedIsIsolated() {
        let source = "the accused said the accused left"
        let body = [
            #"{"sourceText":"the","replacementText":"The","occurrence":0}"#, // unrescued: addressing rejects, batch survives
            #"{"sourceText":"accused","replacementText":"Accused","occurrence":0,"rightContext":" left"}"#, // rescued by unique context
        ].joined(separator: ",")
        let batch = self.resolved(self.edits(body), source: source)
        precondition(batch.rejections.map(\.reason) == [.occurrenceOutOfRange(occurrence: 0, candidateCount: 2)])
        precondition(batch.rejections.map(\.id) == ["p1"])
        precondition(batch.proposals.map(\.id) == ["p2"])
        let result = self.validate(batch, source: source)
        precondition(result.resultingText == "the accused said the Accused left")
    }

    private static func testEndToEndEmptySourceTextAndHallucinationAreIsolatedPerEdit() {
        let source = "the accused left. the witness spoke"
        let body = [
            #"{"sourceText":"","replacementText":"x"}"#,
            #"{"sourceText":"the defendant","replacementText":"The defendant"}"#,
            #"{"sourceText":". the","replacementText":". The"}"#,
        ].joined(separator: ",")
        let batch = self.resolved(self.edits(body), source: source)
        precondition(batch.rejections.map(\.reason) == [.emptySourceText, .noLiteralMatch])
        precondition(batch.proposals.map(\.id) == ["p3"], "a valid sibling still resolves; ids keep original positions")
        precondition(self.validate(batch, source: source).resultingText == "the accused left. The witness spoke")
    }

    private static func testEndToEndLexicalEditResolvesButAuthorityRejects() {
        let source = "convicted under Section 302 IPC"
        let batch = self.resolved(self.edits(#"{"sourceText":"302","replacementText":"304"}"#), source: source)
        precondition(batch.rejections.isEmpty, "addressing succeeds")
        let result = self.validate(batch, source: source)
        precondition(self.disposition(result, id: "p1") == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    private static func testEndToEndWholePassageSpanResolvesButAuthorityRejects() {
        let source = "He left. she stayed."
        let batch = self.resolved(self.edits(#"{"sourceText":"He left. she stayed.","replacementText":"He left. She remained."}"#), source: source)
        precondition(batch.rejections.isEmpty, "the resolver resolves what the model actually proposed; it never shrinks a span")
        let result = self.validate(batch, source: source)
        precondition(self.disposition(result, id: "p1") == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    private static func testEndToEndProtectedSpanStillBlocksAResolvedEdit() {
        let source = "Ordered: section 302 ipc applies."
        let target = (source as NSString).range(of: "section 302 ipc")
        let batch = self.resolved(self.edits(#"{"sourceText":"section","replacementText":"Section"}"#), source: source)
        let blocked = self.validate(batch, source: source, protectedSpans: [ProtectedSpan(range: target, kind: .deterministicallyResolved)])
        precondition(self.disposition(blocked, id: "p1") == .rejected(.intersectsResolvedSpan))
        precondition(blocked.resultingText == source)
    }

    private static func testEndToEndWireFailureNeverReachesTheBridge() {
        switch ModelFacingResponseAdapter.resolveEdits(from: self.response(self.edits(#"{"sourceText":"a","replacementText":"b","id":"p1"}"#)), source: "a") {
        case .success: preconditionFailure("a wire failure must not produce any resolved batch")
        case let .failure(failure): precondition(failure == .wireParseFailure(.unknownField("id")), "\(failure)")
        }
    }

    private static func testEndToEndOdiaAndEmojiSourcesUseSwiftDerivedUTF16() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let emoji = "\u{1F60A}"
        // Non-BMP glyphs before the target: the model never counts UTF-16.
        let source = "\(emoji)\(emoji) \(odia)  done"
        let batch = self.resolved(self.edits(#"{"sourceText":"  ","replacementText":" "}"#), source: source)
        let proposal = batch.proposals[0]
        precondition(proposal.range.location == (emoji + emoji + " " + odia).utf16.count)
        let result = self.validate(batch, source: source)
        guard case .autonomouslyAccepted(.whitespaceOnly) = self.disposition(result, id: "p1") else {
            preconditionFailure("whitespace fix after Odia/emoji should be accepted: \(self.disposition(result, id: "p1"))")
        }
        precondition(result.resultingText == "\(emoji)\(emoji) \(odia) done")

        // A model that corrupts the Odia (hallucinated other-script text)
        // fails closed at addressing, never repaired.
        let corrupted = self.resolved(self.edits(#"{"sourceText":"\#("\u{0B13}\u{0B21}\u{0B3F}\u{0B36}\u{0B3E}")","replacementText":"x"}"#), source: source)
        precondition(corrupted.rejections.map(\.reason) == [.noLiteralMatch] && corrupted.proposals.isEmpty)
    }
}
