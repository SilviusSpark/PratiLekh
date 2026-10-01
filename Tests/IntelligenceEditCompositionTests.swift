import Foundation

/// Coverage for `IntelligenceEditComposition`, the single deterministic entry
/// point composing response parsing (V1.7), addressing (V1.6) and the
/// unmodified Safety Authority. Governing questions:
///   - are transport failure, addressing rejection and Safety Authority
///     disposition kept distinct, never flattened?
///   - are original order and ids preserved through every stage?
///   - does the composition layer apply nothing and return no text?
///   - does it add no policy of its own (parity with calling the components
///     directly)?
/// Deterministic only -- no model, no network.
@main
enum IntelligenceEditCompositionTests {
    static func main() {
        self.testFullChainWithMixedSafetyOutcomes()
        self.testWirePayloadFailuresStopBeforeAddressing()
        self.testResponseShapeFailuresStopBeforeAddressing()
        self.testMixedAddressingSuccessAndFailure()
        self.testEverySafetyAuthorityDispositionIsRepresented()
        self.testAuthorityRunsOverTheWholeBatchSoOverlapIsDetected()
        self.testAddressingRejectedEditsDoNotParticipateInSafetyEvaluation()
        self.testProtectedSpansAreCallerSuppliedAndChangeOnlyDispositions()
        self.testImmutableSourceSemantics()
        self.testOrderingAndIdentity()
        self.testUnicodePreservation()
        self.testZeroEditResponse()
        self.testCompositionAppliesNothingAndReturnsNoText()
        self.testParityWithDirectComponentComposition()
        self.testOutcomePartitionIsExhaustiveAndDisjoint()
        self.testDeterminism()
        self.testAutonomousPermissionGateBlockFlowsThroughToReviewOnly()

        print("PASS: IntelligenceEditComposition deterministic composition suite")
    }

    // MARK: - Helpers

    private static func response(_ raw: String) -> IntelligenceProviderResponse {
        IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: raw)])
    }

    private static func payload(_ editObjects: [String]) -> String {
        #"{"schemaVersion":1,"edits":[\#(editObjects.joined(separator: ","))]}"#
    }

    private static func edit(_ source: String, _ replacement: String, occurrence: Int? = nil, left: String? = nil, right: String? = nil) -> String {
        func quote(_ value: String) -> String {
            let data = (try? JSONEncoder().encode(value)) ?? Data()
            return String(data: data, encoding: .utf8) ?? "\"\""
        }
        var fields = ["\"sourceText\":\(quote(source))", "\"replacementText\":\(quote(replacement))"]
        if let occurrence { fields.append("\"occurrence\":\(occurrence)") }
        if let left { fields.append("\"leftContext\":\(quote(left))") }
        if let right { fields.append("\"rightContext\":\(quote(right))") }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private static func evaluate(
        _ editObjects: [String],
        source: String,
        protectedSpans: [ProtectedSpan] = [],
        file: StaticString = #file,
        line: UInt = #line
    ) -> IntelligenceCompositionResult {
        switch IntelligenceEditComposition.evaluate(response: self.response(self.payload(editObjects)), source: source, protectedSpans: protectedSpans) {
        case let .success(result): return result
        case let .failure(failure): preconditionFailure("expected the response to compose, got \(failure)", file: file, line: line)
        }
    }

    private static func disposition(_ composed: IntelligenceComposedEdit, file: StaticString = #file, line: UInt = #line) -> ProposalDisposition {
        guard let disposition = composed.disposition else { preconditionFailure("edit \(composed.id) was not evaluated: \(composed.stage)", file: file, line: line) }
        return disposition
    }

    private static func addressingReason(_ composed: IntelligenceComposedEdit, file: StaticString = #file, line: UInt = #line) -> IntelligenceAddressingRejection {
        guard case let .addressingRejected(reason) = composed.stage else { preconditionFailure("edit \(composed.id) unexpectedly resolved", file: file, line: line) }
        return reason
    }

    private static func expectTransportFailure(_ label: String, _ response: IntelligenceProviderResponse, _ expected: ModelFacingAdapterFailure, file: StaticString = #file, line: UInt = #line) {
        switch IntelligenceEditComposition.evaluate(response: response, source: "the accused left", protectedSpans: []) {
        case .success: preconditionFailure("\(label): expected \(expected), but composed", file: file, line: line)
        case let .failure(failure): precondition(failure == expected, "\(label): expected \(expected), got \(failure)", file: file, line: line)
        }
    }

    // MARK: - Full chain

    private static func testFullChainWithMixedSafetyOutcomes() {
        let source = "the accused left. the witness spoke  now under Section 302 IPC."
        let result = self.evaluate([
            self.edit(". the", ". The"),
            self.edit("  ", " "),
            self.edit("302", "304"),
        ], source: source)

        precondition(result.schemaVersion == 1)
        precondition(result.edits.map(\.index) == [0, 1, 2])
        precondition(result.edits.map(\.id) == ["p1", "p2", "p3"])
        guard case .autonomouslyAccepted(.capitalizationOnly) = self.disposition(result.edits[0]) else { preconditionFailure("\(result.edits[0].stage)") }
        guard case .autonomouslyAccepted(.whitespaceOnly) = self.disposition(result.edits[1]) else { preconditionFailure("\(result.edits[1].stage)") }
        precondition(self.disposition(result.edits[2]) == .rejected(.unsupportedEditCategory), "a resolved lexical statute-number change is the Authority's to reject")
        precondition(result.accepted.map(\.id) == ["p1", "p2"])
        precondition(result.rejectedBySafetyAuthority.map(\.id) == ["p3"])
        precondition(result.reviewOnly.isEmpty && result.addressingRejected.isEmpty)
    }

    // MARK: - Transport / batch failures stop before addressing

    private static func testWirePayloadFailuresStopBeforeAddressing() {
        // One structurally invalid edit fails the whole response, even though
        // its sibling is perfectly addressable and safe: no partial result.
        let good = self.edit(". the", ". The")
        let cases: [(String, String, ModelFacingAdapterFailure)] = [
            ("truncated JSON", #"{"schemaVersion":1,"edits":[{"sourceText":"a""#, .wireParseFailure(.invalidRootStructure)),
            ("empty arguments", "", .wireParseFailure(.invalidRootStructure)),
            ("fenced JSON", "```json\n" + self.payload([good]) + "\n```", .wireParseFailure(.invalidRootStructure)),
            ("duplicate key", self.payload([#"{"sourceText":"a","replacementText":"b","occurrence":1,"occurrence":2}"#, good]), .wireParseFailure(.duplicateKey("occurrence"))),
            ("unknown field", self.payload([good, #"{"sourceText":"a","replacementText":"b","claimedCategory":"other"}"#]), .wireParseFailure(.unknownField("claimedCategory"))),
            ("fractional occurrence", self.payload([good, #"{"sourceText":"a","replacementText":"b","occurrence":1.0}"#]), .wireParseFailure(.invalidFieldType("occurrence"))),
            ("null optional", self.payload([good, #"{"sourceText":"a","replacementText":"b","leftContext":null}"#]), .wireParseFailure(.invalidFieldType("leftContext"))),
            ("internal-contract shape", #"{"schemaVersion":1,"proposals":[]}"#, .wireParseFailure(.unknownField("proposals"))),
            ("wrong schemaVersion", #"{"schemaVersion":2,"edits":[]}"#, .wireParseFailure(.unsupportedSchemaVersion)),
        ]
        for (label, raw, expected) in cases {
            self.expectTransportFailure(label, self.response(raw), expected)
        }
    }

    private static func testResponseShapeFailuresStopBeforeAddressing() {
        let valid = IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: self.payload([]))
        self.expectTransportFailure("no call", IntelligenceProviderResponse(), .noToolCall)
        self.expectTransportFailure("wrong tool", IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: "x", rawArguments: "{}")]), .unexpectedToolName("x"))
        self.expectTransportFailure(
            "legacy contract's tool",
            IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: IntelligenceGenerationContract.toolName, rawArguments: #"{"schemaVersion":1,"proposals":[]}"#)]),
            .unexpectedToolName(IntelligenceGenerationContract.toolName)
        )
        self.expectTransportFailure("two calls", IntelligenceProviderResponse(toolCalls: [valid, valid]), .multipleToolCalls(count: 2))
        self.expectTransportFailure("prose alongside call", IntelligenceProviderResponse(textContent: "edits:", toolCalls: [valid]), .unexpectedTextContent)
    }

    // MARK: - Addressing isolation

    private static func testMixedAddressingSuccessAndFailure() {
        let source = "the accused said the accused left. the court rose."
        let edits = [
            self.edit("the defendant", "The defendant"), // p1: hallucinated
            self.edit("the accused", "The accused", occurrence: 2), // p2: fine
            self.edit("the accused", "The accused"), // p3: ambiguous
            self.edit(". the", ". The"), // p4: fine
            self.edit("", "x"), // p5: empty
            self.edit("the accused", "The accused", occurrence: 0), // p6: unrescued invalid ordinal
        ]
        let result = self.evaluate(edits, source: source)
        precondition(result.edits.map(\.id) == ["p1", "p2", "p3", "p4", "p5", "p6"], "rejected edits keep their positions; ids never shift")
        precondition(self.addressingReason(result.edits[0]) == .noLiteralMatch)
        precondition(self.addressingReason(result.edits[2]) == .ambiguousCandidates(count: 2))
        precondition(self.addressingReason(result.edits[4]) == .emptySourceText)
        precondition(self.addressingReason(result.edits[5]) == .occurrenceOutOfRange(occurrence: 0, candidateCount: 2))
        precondition(result.addressingRejected.map(\.id) == ["p1", "p3", "p5", "p6"])
        precondition(result.accepted.map(\.id) == ["p2", "p4"])
        for rejected in result.addressingRejected {
            precondition(rejected.proposal == nil && rejected.disposition == nil, "an addressing-rejected edit never becomes a proposal or reaches the Authority")
        }

        // Each surviving sibling's disposition equals its disposition alone.
        let alone2 = self.evaluate([edits[1]], source: source).edits[0].disposition
        let alone4 = self.evaluate([edits[3]], source: source).edits[0].disposition
        precondition(result.edits[1].disposition == alone2 && result.edits[3].disposition == alone4, "failing siblings must not change another edit's outcome")
    }

    // MARK: - Safety Authority dispositions

    private static func testEverySafetyAuthorityDispositionIsRepresented() {
        // autonomouslyAccepted: capitalization, whitespace, punctuation.
        let capitalization = self.evaluate([self.edit("the", "The")], source: "the accused")
        guard case .autonomouslyAccepted(.capitalizationOnly) = self.disposition(capitalization.edits[0]) else { preconditionFailure("\(capitalization.edits[0].stage)") }
        let whitespace = self.evaluate([self.edit("a  b", "a b")], source: "x a  b y")
        guard case .autonomouslyAccepted(.whitespaceOnly) = self.disposition(whitespace.edits[0]) else { preconditionFailure("\(whitespace.edits[0].stage)") }
        let punctuation = self.evaluate([self.edit("left the", "left, the")], source: "he left the court")
        guard case .autonomouslyAccepted(.punctuationOnly) = self.disposition(punctuation.edits[0]) else { preconditionFailure("\(punctuation.edits[0].stage)") }

        // rejected: unsupported category, no-op.
        let lexical = self.evaluate([self.edit("the accused", "the complainant")], source: "the accused left")
        precondition(self.disposition(lexical.edits[0]) == .rejected(.unsupportedEditCategory))
        let noOp = self.evaluate([self.edit("accused", "accused")], source: "the accused left")
        precondition(self.disposition(noOp.edits[0]) == .rejected(.noOpProposal))

        // review-only and rejected-by-resolved-span, via caller-supplied spans.
        let source = "Ordered: section 302 ipc applies."
        let target = (source as NSString).range(of: "section 302 ipc")
        let resolved = self.evaluate([self.edit("section", "Section")], source: source, protectedSpans: [ProtectedSpan(range: target, kind: .deterministicallyResolved)])
        precondition(self.disposition(resolved.edits[0]) == .rejected(.intersectsResolvedSpan))
        let unresolved = self.evaluate([self.edit("section", "Section")], source: source, protectedSpans: [ProtectedSpan(range: target, kind: .deterministicallyUnresolved)])
        precondition(self.disposition(unresolved.edits[0]) == .reviewOnly(.intersectsUnresolvedSpan))
        let independent = self.evaluate([self.edit("section", "Section")], source: source, protectedSpans: [ProtectedSpan(range: target, kind: .independentlyProtected)])
        precondition(self.disposition(independent.edits[0]) == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(independent.reviewOnly.count == 1 && independent.accepted.isEmpty, "review-only is never reported as accepted")

        // overlap: see the dedicated batch test. (`invalidRange`,
        // `rangeConversionFailed`, `sourceTextMismatch` are unreachable through
        // the bridge, which derives every range and expected text from the
        // real source; the Authority's own suite covers them.)
    }

    private static func testAuthorityRunsOverTheWholeBatchSoOverlapIsDetected() {
        let source = "the accused said. the witness spoke"
        let a = self.edit(". the", ". The")
        let b = self.edit(" the witness", " The witness")
        // Each alone is a safe, accepted capitalization...
        guard case .autonomouslyAccepted = self.disposition(self.evaluate([a], source: source).edits[0]),
              case .autonomouslyAccepted = self.disposition(self.evaluate([b], source: source).edits[0])
        else { preconditionFailure("premise: each edit is individually safe") }
        // ...but together they overlap, and BOTH are rejected. Per-proposal
        // Authority invocation could never have detected this.
        let together = self.evaluate([a, b], source: source)
        precondition(together.edits.map(\.disposition) == [.rejected(.overlapsAnotherProposal), .rejected(.overlapsAnotherProposal)])
        precondition(together.accepted.isEmpty)
        // Order does not grant authority.
        let reversed = self.evaluate([b, a], source: source)
        precondition(reversed.edits.map(\.disposition) == [.rejected(.overlapsAnotherProposal), .rejected(.overlapsAnotherProposal)])
    }

    private static func testAddressingRejectedEditsDoNotParticipateInSafetyEvaluation() {
        // An addressing-rejected edit has no range, so it cannot overlap or
        // conflict with a resolved one; the resolved edit is judged on its own.
        let source = "the accused said. the witness spoke"
        let result = self.evaluate([self.edit(". the", ". The"), self.edit("the witness spoke!!", "x")], source: source)
        precondition(self.addressingReason(result.edits[1]) == .noLiteralMatch)
        guard case .autonomouslyAccepted = self.disposition(result.edits[0]) else { preconditionFailure("\(result.edits[0].stage)") }
    }

    private static func testProtectedSpansAreCallerSuppliedAndChangeOnlyDispositions() {
        let source = "Ordered: section 302 ipc applies. the end."
        let edits = [self.edit("section", "Section"), self.edit(". the", ". The")]
        let target = (source as NSString).range(of: "section 302 ipc")
        let open = self.evaluate(edits, source: source)
        let guarded = self.evaluate(edits, source: source, protectedSpans: [ProtectedSpan(range: target, kind: .deterministicallyResolved)])
        precondition(open.edits.map(\.proposal) == guarded.edits.map(\.proposal), "spans never change addressing or the proposals")
        precondition(open.accepted.map(\.id) == ["p1", "p2"])
        precondition(guarded.edits[0].disposition == .rejected(.intersectsResolvedSpan))
        guard case .autonomouslyAccepted = self.disposition(guarded.edits[1]) else { preconditionFailure("an edit outside the span is unaffected") }
    }

    // MARK: - Immutable source, ordering, identity

    private static func testImmutableSourceSemantics() {
        let source = "the accused said the accused left"
        let result = self.evaluate([
            self.edit("the accused", "X", occurrence: 1),
            self.edit("the accused", "Y", occurrence: 2),
            self.edit("the accused", "Z", right: " left"),
            self.edit("said", "said said said"),
        ], source: source)
        // Every edit is located in ORIGINAL coordinates, regardless of what
        // any other edit's replacement would do to length or content.
        precondition(result.edits[0].proposal?.range == NSRange(location: 0, length: 11))
        precondition(result.edits[1].proposal?.range == NSRange(location: 17, length: 11))
        precondition(result.edits[2].proposal?.range == NSRange(location: 17, length: 11))
        precondition(result.edits[3].proposal?.range == NSRange(location: 12, length: 4))
        for composed in result.edits {
            guard let proposal = composed.proposal else { preconditionFailure("all four resolve") }
            precondition(proposal.expectedSourceText == (source as NSString).substring(with: proposal.range), "expected text is read from the real source")
        }
        // Reordering the model's array changes no per-edit outcome.
        let forward = self.evaluate([self.edit("the", "The", occurrence: 1), self.edit("said", "SAID"), self.edit("nope", "x")], source: source)
        let reversed = self.evaluate([self.edit("nope", "x"), self.edit("said", "SAID"), self.edit("the", "The", occurrence: 1)], source: source)
        precondition(forward.edits[0].proposal?.range == reversed.edits[2].proposal?.range)
        precondition(forward.edits[0].disposition == reversed.edits[2].disposition)
        precondition(forward.edits[1].disposition == reversed.edits[1].disposition)
        precondition(forward.edits[2].stage == reversed.edits[0].stage)
    }

    private static func testOrderingAndIdentity() {
        // Deliberately not in source order and with failures interleaved.
        let source = "alpha beta gamma delta"
        let result = self.evaluate([
            self.edit("delta", "Delta"),
            self.edit("missing", "x"),
            self.edit("alpha", "Alpha"),
            self.edit("gamma", "Gamma"),
        ], source: source)
        precondition(result.edits.map(\.index) == [0, 1, 2, 3])
        precondition(result.edits.map(\.id) == ["p1", "p2", "p3", "p4"])
        precondition(result.edits.map(\.edit.sourceText) == ["delta", "missing", "alpha", "gamma"], "the parsed model edit rides along unchanged")
        precondition(result.edits.map { $0.proposal?.id } == ["p1", nil, "p3", "p4"], "proposal identity matches edit identity")
        precondition(result.accepted.map(\.id) == ["p1", "p3", "p4"], "accepted preserves original order, not source order")
    }

    // MARK: - Unicode

    private static func testUnicodePreservation() {
        let emoji = "\u{1F60A}"
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let source = "\(emoji)\(emoji) \(odia)  done \(odia)"
        let result = self.evaluate([
            self.edit("  ", " "),
            self.edit(odia, odia, occurrence: 2), // resolves; no-op is the Authority's call
            self.edit("\u{0B13}\u{0B21}\u{0B3F}\u{0B36}\u{0B3E}", "x"), // corrupted Odia
        ], source: source)
        guard let space = result.edits[0].proposal else { preconditionFailure("\(result.edits[0].stage)") }
        precondition(space.range.location == (emoji + emoji + " " + odia).utf16.count, "UTF-16 derived by Swift past surrogate pairs and Odia")
        guard case .autonomouslyAccepted(.whitespaceOnly) = self.disposition(result.edits[0]) else { preconditionFailure("\(result.edits[0].stage)") }
        guard let second = result.edits[1].proposal else { preconditionFailure("\(result.edits[1].stage)") }
        precondition(Array(second.expectedSourceText.unicodeScalars) == Array(odia.unicodeScalars), "scalar-for-scalar identical")
        precondition(second.range.location == (source as NSString).length - odia.utf16.count)
        precondition(self.disposition(result.edits[1]) == .rejected(.noOpProposal))
        precondition(self.addressingReason(result.edits[2]) == .noLiteralMatch, "corrupted model Unicode fails closed; never repaired")
        // Unicode inside a protected span is protected like any other text.
        let odiaRange = (source as NSString).range(of: odia)
        let protected = self.evaluate([self.edit("  ", " ")], source: source, protectedSpans: [ProtectedSpan(range: NSRange(location: odiaRange.location, length: odiaRange.length + 2), kind: .independentlyProtected)])
        precondition(protected.edits[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
    }

    // MARK: - Zero edits, no application, parity

    private static func testZeroEditResponse() {
        let result = self.evaluate([], source: "already correct.")
        precondition(result.schemaVersion == 1 && result.edits.isEmpty)
        precondition(result.accepted.isEmpty && result.reviewOnly.isEmpty && result.rejectedBySafetyAuthority.isEmpty && result.addressingRejected.isEmpty)
    }

    private static func testCompositionAppliesNothingAndReturnsNoText() {
        let source = "the accused left. the witness spoke"
        let edits = [self.edit("the", "The", occurrence: 1), self.edit(". the", ". The")]
        // Premise: the Authority alone WOULD produce different text here.
        guard case let .success(parsed) = ModelFacingResponseAdapter.extractEdits(from: self.response(self.payload(edits))) else { preconditionFailure("premise") }
        let direct = IntelligenceSafetyAuthority.validate(proposals: IntelligenceAddressingBridge.bridge(parsed.edits, source: source).proposals, source: source, protectedSpans: [])
        precondition(direct.resultingText != source, "premise: accepted edits change text when applied")

        let result = self.evaluate(edits, source: source)
        precondition(result.accepted.count == 2, "edits are accepted...")
        // ...but the composition result is structurally incapable of carrying
        // applied text: its only stored properties are the version and the
        // per-edit outcomes.
        precondition(Mirror(reflecting: result).children.compactMap(\.label).sorted() == ["edits", "schemaVersion"])
        precondition(!String(describing: result).contains(direct.resultingText), "no applied transcript may appear anywhere in the result")
        // Review-only and rejected outcomes likewise yield nothing.
        let blocked = self.evaluate([self.edit("the accused", "the complainant")], source: source)
        precondition(blocked.accepted.isEmpty && blocked.edits[0].disposition == .rejected(.unsupportedEditCategory))
    }

    private static func testParityWithDirectComponentComposition() {
        // The composition adds no policy: its dispositions are exactly what
        // the existing components produce when called by hand.
        let source = "the accused said. the witness spoke  now under Section 302 IPC. the end."
        let spans = [ProtectedSpan(range: (source as NSString).range(of: "Section 302 IPC"), kind: .deterministicallyUnresolved)]
        let edits = [
            self.edit(". the", ". The", occurrence: 1), self.edit("missing", "x"), self.edit("  ", " "),
            self.edit("302", "304"), self.edit("Section", "SECTION"), self.edit(". the", ". The", occurrence: 2),
        ]
        let composed = self.evaluate(edits, source: source, protectedSpans: spans)

        guard case let .success(parsed) = ModelFacingResponseAdapter.extractEdits(from: self.response(self.payload(edits))) else { preconditionFailure("premise") }
        let batch = IntelligenceAddressingBridge.bridge(parsed.edits, source: source)
        let direct = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: spans)
        precondition(direct.outcomes.count == batch.proposals.count)
        precondition(composed.edits.compactMap(\.proposal) == batch.proposals)
        precondition(composed.edits.compactMap(\.disposition) == direct.outcomes.map(\.disposition))
        precondition(composed.edits.compactMap(\.proposal) == direct.outcomes.map(\.proposal))
    }

    // MARK: - Structure

    private static func testOutcomePartitionIsExhaustiveAndDisjoint() {
        let source = "the accused said the accused left. Ordered: section 302 ipc applies."
        let target = (source as NSString).range(of: "section 302 ipc")
        let edits = [
            self.edit("the", "The", occurrence: 1), // accepted
            self.edit("section", "Section"), // review-only (span)
            self.edit("accused left", "accused departed"), // rejected by Authority
            self.edit("nonexistent", "x"), // addressing rejected
            self.edit("the accused", "The"), // addressing rejected (ambiguous)
        ]
        let spans = [ProtectedSpan(range: target, kind: .deterministicallyUnresolved)]
        let result = self.evaluate(edits, source: source, protectedSpans: spans)
        let buckets = [result.accepted, result.reviewOnly, result.rejectedBySafetyAuthority, result.addressingRejected].map { $0.map(\.id) }
        precondition(buckets[0] == ["p1"] && buckets[1] == ["p2"] && buckets[2] == ["p3"] && buckets[3] == ["p4", "p5"], "\(buckets)")
        let all = buckets.flatMap { $0 }
        precondition(Set(all).count == all.count, "no edit may appear in two buckets")
        precondition(all.count == result.edits.count, "every edit must appear in exactly one bucket")
    }

    // MARK: - AutonomousPermissionGate (V1.16) integration through composition

    private static func testAutonomousPermissionGateBlockFlowsThroughToReviewOnly() {
        // Composition adds no policy of its own (a governing invariant of
        // this type); a gate-blocked edit must flow through exactly the way
        // a protected-span-blocked one does: review-only, not applied, and
        // no code change was needed in this type to make that true.
        let source = "the accused Ram Das denied it"
        let result = self.evaluate([self.edit("Ram Das", "RamDas")], source: source)
        precondition(result.edits[0].disposition == .reviewOnly(.wordBoundaryMerged), "\(String(describing: result.edits[0].disposition))")
        precondition(result.accepted.isEmpty && result.reviewOnly.map(\.id) == ["p1"])
    }

    private static func testDeterminism() {
        let source = "the accused said the accused left. the court rose."
        let edits = [self.edit("the accused", "The accused", occurrence: 2), self.edit("nope", "x"), self.edit(". the", ". The")]
        let first = IntelligenceEditComposition.evaluate(response: self.response(self.payload(edits)), source: source)
        for _ in 0..<25 {
            precondition(IntelligenceEditComposition.evaluate(response: self.response(self.payload(edits)), source: source) == first, "composition must be a pure function of its inputs")
        }
    }
}
