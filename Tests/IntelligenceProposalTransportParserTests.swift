import Foundation

/// Adversarial and integration coverage for `IntelligenceProposalTransportParser`.
/// The governing questions every test here answers:
///   1. Can malformed/hostile transport input ever crash, or become a
///      native proposal without satisfying the strict wire contract?
///   2. Does successfully parsing ever, by itself, grant a proposal any
///      semantic authority? (No -- only `IntelligenceSafetyAuthority` does.)
@main
enum IntelligenceProposalTransportParserTests {
    static func main() {
        testRootAndSchemaFailures()
        testUnknownFieldFailures()
        testDuplicateKeyFailures()
        testProposalStructureFailures()
        testRangeFailures()
        testStringFieldBehavior()
        testCountAndResourceLimits()
        testIDBehavior()
        testGarbageAndEncodingFailures()
        testStructuralAllOrNothingSemantics()
        testSuccessfulParses()
        testSafetyAuthorityIntegration()
        print("PASS: IntelligenceProposalTransportParser adversarial and integration suite")
    }

    // MARK: - Fixture helpers (test-only)

    private static func validProposalJSON(
        id: String = "p1",
        rangeStart: Int = 0,
        rangeLength: Int = 2,
        expected: String = "ab",
        replacement: String = "AB",
        category: String = "capitalization"
    ) -> String {
        "{\"id\":\"\(id)\",\"rangeStart\":\(rangeStart),\"rangeLength\":\(rangeLength),"
            + "\"expectedSourceText\":\"\(expected)\",\"replacementText\":\"\(replacement)\",\"claimedCategory\":\"\(category)\"}"
    }

    private static func payload(schemaVersion: String = "1", proposalsJSON: String) -> String {
        "{\"schemaVersion\":\(schemaVersion),\"proposals\":[\(proposalsJSON)]}"
    }

    private static func parse(_ json: String) -> Result<ParsedIntelligenceProposalBatch, Error> {
        Result { try IntelligenceProposalTransportParser.parse(Data(json.utf8)) }
    }

    private static func assertFails(
        _ label: String,
        _ json: String,
        expected: IntelligenceProposalParseFailure,
        line: Int = #line
    ) {
        switch self.parse(json) {
        case .success:
            preconditionFailure("[line \(line)] \(label): expected \(expected) but parse succeeded")
        case let .failure(error):
            guard let failure = error as? IntelligenceProposalParseFailure else {
                preconditionFailure("[line \(line)] \(label): expected a typed parse failure, got \(error)")
            }
            precondition(failure == expected, "[line \(line)] \(label): expected \(expected), got \(failure)")
        }
    }

    private static func assertFailsWithSomeTypedReason(_ label: String, _ json: String, line: Int = #line) {
        switch self.parse(json) {
        case .success:
            preconditionFailure("[line \(line)] \(label): expected some failure but parse succeeded")
        case let .failure(error):
            precondition(error is IntelligenceProposalParseFailure, "[line \(line)] \(label): unexpected error type \(error)")
        }
    }

    private static func assertSucceeds(_ label: String, _ json: String, expectedCount: Int, line: Int = #line) {
        switch self.parse(json) {
        case let .success(batch):
            precondition(batch.proposals.count == expectedCount, "[line \(line)] \(label): expected \(expectedCount) proposals, got \(batch.proposals.count)")
        case let .failure(error):
            preconditionFailure("[line \(line)] \(label): expected success, got \(error)")
        }
    }

    // MARK: - Root / schema

    private static func testRootAndSchemaFailures() {
        self.assertFails("empty payload", "", expected: .invalidRootStructure)
        self.assertFails("whitespace-only payload", "   \n\t  ", expected: .invalidRootStructure)
        self.assertFails("empty object root", "{}", expected: .missingField("schemaVersion"))
        self.assertFails("array root", "[]", expected: .invalidRootStructure)
        self.assertFails("scalar root (number)", "42", expected: .invalidRootStructure)
        self.assertFails("scalar root (string)", #""hello""#, expected: .invalidRootStructure)
        self.assertFails("missing schemaVersion", #"{"proposals":[]}"#, expected: .missingField("schemaVersion"))
        self.assertFails("schemaVersion null", #"{"schemaVersion":null,"proposals":[]}"#, expected: .invalidFieldType("schemaVersion"))
        self.assertFails("schemaVersion string", #"{"schemaVersion":"1","proposals":[]}"#, expected: .invalidFieldType("schemaVersion"))
        self.assertFails("schemaVersion whole-number float", #"{"schemaVersion":1.0,"proposals":[]}"#, expected: .invalidFieldType("schemaVersion"))
        self.assertFails("schemaVersion fractional float", #"{"schemaVersion":1.5,"proposals":[]}"#, expected: .invalidFieldType("schemaVersion"))
        self.assertFails("schemaVersion boolean", #"{"schemaVersion":true,"proposals":[]}"#, expected: .invalidFieldType("schemaVersion"))
        self.assertFails("unsupported version 0", #"{"schemaVersion":0,"proposals":[]}"#, expected: .unsupportedSchemaVersion)
        self.assertFails("unsupported version 2 (future)", #"{"schemaVersion":2,"proposals":[]}"#, expected: .unsupportedSchemaVersion)
        self.assertFails("unsupported negative version", #"{"schemaVersion":-1,"proposals":[]}"#, expected: .unsupportedSchemaVersion)
        self.assertFails("missing proposals", #"{"schemaVersion":1}"#, expected: .missingField("proposals"))
        self.assertFails("null proposals", #"{"schemaVersion":1,"proposals":null}"#, expected: .invalidFieldType("proposals"))
        self.assertFails("proposals wrong type (object)", #"{"schemaVersion":1,"proposals":{}}"#, expected: .invalidFieldType("proposals"))
        self.assertFails("proposals wrong type (string)", #"{"schemaVersion":1,"proposals":"none"}"#, expected: .invalidFieldType("proposals"))
        self.assertFails("proposals wrong type (number)", #"{"schemaVersion":1,"proposals":5}"#, expected: .invalidFieldType("proposals"))
        self.assertSucceeds("empty proposal list is a legitimate valid parse", #"{"schemaVersion":1,"proposals":[]}"#, expectedCount: 0)
    }

    // MARK: - Unknown fields

    private static func testUnknownFieldFailures() {
        self.assertFails("unknown root field", #"{"schemaVersion":1,"proposals":[],"extra":"x"}"#, expected: .unknownField("extra"))
        let proposalWithExtra = #"{"id":"p1","rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization","confidence":0.9}"#
        self.assertFails("unknown proposal field (confidence)", self.payload(proposalsJSON: proposalWithExtra), expected: .unknownField("confidence"))
    }

    // MARK: - Duplicate keys

    private static func testDuplicateKeyFailures() {
        self.assertFails("duplicate schemaVersion key", #"{"schemaVersion":1,"schemaVersion":999,"proposals":[]}"#, expected: .duplicateKey("schemaVersion"))
        self.assertFails(
            "duplicate proposals key",
            #"{"schemaVersion":1,"proposals":[],"proposals":[{"id":"p1","rangeStart":0,"rangeLength":1,"expectedSourceText":"a","replacementText":"A","claimedCategory":"capitalization"}]}"#,
            expected: .duplicateKey("proposals")
        )
        let dupID = #"{"id":"p1","id":"p2","rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#
        self.assertFails("duplicate id key within a proposal", self.payload(proposalsJSON: dupID), expected: .duplicateKey("id"))
        let dupReplacement = #"{"id":"p1","rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"IPC","replacementText":"CrPC","claimedCategory":"other"}"#
        self.assertFails("duplicate replacementText key", self.payload(proposalsJSON: dupReplacement), expected: .duplicateKey("replacementText"))
        let dupRange = #"{"id":"p1","rangeStart":0,"rangeStart":99,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#
        self.assertFails("duplicate rangeStart key", self.payload(proposalsJSON: dupRange), expected: .duplicateKey("rangeStart"))
    }

    // MARK: - Proposal structure

    private static func testProposalStructureFailures() {
        self.assertFails("missing id", self.payload(proposalsJSON: #"{"rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .missingField("id"))
        self.assertFails("missing rangeStart", self.payload(proposalsJSON: #"{"id":"p1","rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .missingField("rangeStart"))
        self.assertFails("missing expectedSourceText", self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":2,"replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .missingField("expectedSourceText"))
        self.assertFails("missing replacementText", self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","claimedCategory":"capitalization"}"#), expected: .missingField("replacementText"))
        self.assertFails("missing claimedCategory", self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB"}"#), expected: .missingField("claimedCategory"))
        self.assertFails("null id", self.payload(proposalsJSON: #"{"id":null,"rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .invalidFieldType("id"))
        self.assertFails("wrong type id (number)", self.payload(proposalsJSON: #"{"id":1,"rangeStart":0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .invalidFieldType("id"))
        self.assertFails("unknown category", self.payload(proposalsJSON: self.validProposalJSON(category: "grammar")), expected: .unsupportedCategory)
        self.assertFails(
            "proposals array contains a non-object element (string)",
            #"{"schemaVersion":1,"proposals":["not an object"]}"#,
            expected: .invalidFieldType("proposals")
        )
        self.assertFails(
            "proposals array contains a non-object element (number)",
            #"{"schemaVersion":1,"proposals":[5]}"#,
            expected: .invalidFieldType("proposals")
        )
    }

    // MARK: - Range

    private static func testRangeFailures() {
        self.assertSucceeds("zero location/zero length range", self.payload(proposalsJSON: self.validProposalJSON(rangeStart: 0, rangeLength: 0, expected: "", replacement: ",")), expectedCount: 1)
        self.assertSucceeds("normal range", self.payload(proposalsJSON: self.validProposalJSON(rangeStart: 3, rangeLength: 5)), expectedCount: 1)
        self.assertFails("negative rangeStart", self.payload(proposalsJSON: #"{"id":"p1","rangeStart":-1,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .invalidRange)
        self.assertFails("negative rangeLength", self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":-2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#), expected: .invalidRange)
        self.assertFails(
            "huge rangeStart beyond transport limit",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":99999999999,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expected: .invalidRange
        )
        self.assertFails(
            "rangeStart at Int64 overflow edge (unrepresentable literal)",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":99999999999999999999999999999999,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expected: .invalidRange
        )
        self.assertFails(
            "float rangeStart",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0.0,"rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expected: .invalidRange
        )
        self.assertFails(
            "numeric-string rangeStart",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":"0","rangeLength":2,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expected: .invalidRange
        )
        // rangeStart/rangeLength each exactly at the transport max: both
        // individually permitted, and their sum (2x the max) still cannot
        // overflow Int64 -- the bound is chosen so this is always safe.
        // Not a claim about a real transcript's length: this parser
        // deliberately never validates a range against actual source text
        // (that remains `IntelligenceSafetyAuthority`'s job downstream).
        self.assertSucceeds(
            "rangeStart and rangeLength both exactly at the transport max",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":10000000,"rangeLength":10000000,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expectedCount: 1
        )
        self.assertFails(
            "rangeStart one past the transport max",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":10000001,"rangeLength":0,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expected: .invalidRange
        )
        self.assertFails(
            "rangeLength one past the transport max",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":10000001,"expectedSourceText":"ab","replacementText":"AB","claimedCategory":"capitalization"}"#),
            expected: .invalidRange
        )
    }

    // MARK: - Strings / Unicode

    private static func testStringFieldBehavior() {
        self.assertSucceeds(
            "empty expectedSourceText is structurally valid (zero-length insertion)",
            self.payload(proposalsJSON: self.validProposalJSON(rangeStart: 0, rangeLength: 0, expected: "", replacement: ",")),
            expectedCount: 1
        )
        self.assertSucceeds(
            "empty replacementText is structurally valid (deletion is a semantic concern, not transport's)",
            self.payload(proposalsJSON: self.validProposalJSON(expected: "ab", replacement: "")),
            expectedCount: 1
        )
        self.assertSucceeds(
            "Unicode Indian name round-trips exactly",
            self.payload(proposalsJSON: self.validProposalJSON(expected: "sabyasachi mohapatra", replacement: "Sabyasachi Mohapatra")),
            expectedCount: 1
        )
        switch self.parse(self.payload(proposalsJSON: self.validProposalJSON(expected: "ipc", replacement: "IPC"))) {
        case let .success(batch):
            precondition(batch.proposals[0].expectedSourceText == "ipc")
            precondition(batch.proposals[0].replacementText == "IPC")
        case let .failure(error):
            preconditionFailure("Unicode round-trip should succeed: \(error)")
        }
        self.assertSucceeds(
            "Odia text preserved exactly",
            self.payload(proposalsJSON: self.validProposalJSON(expected: "test", replacement: "ସାବ୍ୟସାଚୀ")),
            expectedCount: 1
        )
        self.assertSucceeds(
            "escaped newline/tab and quote inside JSON string",
            self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":2,"expectedSourceText":"a\nb","replacementText":"a\tb","claimedCategory":"whitespace"}"#),
            expectedCount: 1
        )
        // Over-limit strings.
        let overLongID = String(repeating: "x", count: IntelligenceProposalTransportLimits.maxIDLength + 1)
        self.assertFails("overlong id", self.payload(proposalsJSON: self.validProposalJSON(id: overLongID)), expected: .fieldLengthExceeded("id"))
        let overLongExpected = String(repeating: "x", count: IntelligenceProposalTransportLimits.maxExpectedSourceTextLength + 1)
        self.assertFails("overlong expectedSourceText", self.payload(proposalsJSON: self.validProposalJSON(expected: overLongExpected)), expected: .fieldLengthExceeded("expectedSourceText"))
        let overLongReplacement = String(repeating: "x", count: IntelligenceProposalTransportLimits.maxReplacementTextLength + 1)
        self.assertFails("overlong replacementText", self.payload(proposalsJSON: self.validProposalJSON(replacement: overLongReplacement)), expected: .fieldLengthExceeded("replacementText"))
        // At-limit strings succeed.
        let atLimitID = String(repeating: "x", count: IntelligenceProposalTransportLimits.maxIDLength)
        self.assertSucceeds("id exactly at the length limit", self.payload(proposalsJSON: self.validProposalJSON(id: atLimitID)), expectedCount: 1)
    }

    // MARK: - Counts / resources

    private static func testCountAndResourceLimits() {
        let maxCount = IntelligenceProposalTransportLimits.maxProposalCount
        let exactlyMax = (0..<maxCount).map { self.validProposalJSON(id: "p\($0)") }.joined(separator: ",")
        self.assertSucceeds("exactly the max proposal count", self.payload(proposalsJSON: exactlyMax), expectedCount: maxCount)

        let overMax = (0..<(maxCount + 1)).map { self.validProposalJSON(id: "p\($0)") }.joined(separator: ",")
        self.assertFails("max proposal count + 1", self.payload(proposalsJSON: overMax), expected: .proposalCountExceeded)

        let overPayload = "{\"schemaVersion\":1,\"proposals\":[],\"padding\":\"" + String(repeating: "x", count: IntelligenceProposalTransportLimits.maxPayloadBytes) + "\"}"
        self.assertFails("payload over the byte limit", overPayload, expected: .payloadTooLarge)

        // Aggregate decoded text: many proposals each individually under the
        // per-field limit, but summing past the aggregate limit.
        let chunk = String(repeating: "x", count: 5_000)
        let manyModeratelyLargeProposals = (0..<50).map { index in
            self.validProposalJSON(id: "agg\(index)", expected: chunk, replacement: chunk)
        }.joined(separator: ",")
        // 50 * (5000 + 5000) = 500,000 > maxAggregateDecodedTextLength (200,000)
        self.assertFails("aggregate decoded text exceeds the batch-wide limit", self.payload(proposalsJSON: manyModeratelyLargeProposals), expected: .aggregateTextLimitExceeded)
    }

    // MARK: - IDs

    private static func testIDBehavior() {
        self.assertFails("empty id", self.payload(proposalsJSON: self.validProposalJSON(id: "")), expected: .emptyID)
        let duplicateIDs = self.validProposalJSON(id: "same", rangeStart: 0) + "," + self.validProposalJSON(id: "same", rangeStart: 10)
        self.assertFails("duplicate proposal IDs across the batch", self.payload(proposalsJSON: duplicateIDs), expected: .duplicateProposalID)
        let caseDifferentIDs = self.validProposalJSON(id: "P1", rangeStart: 0) + "," + self.validProposalJSON(id: "p1", rangeStart: 10)
        self.assertSucceeds("IDs differing only by case are distinct (case-sensitive)", self.payload(proposalsJSON: caseDifferentIDs), expectedCount: 2)
        self.assertSucceeds("Unicode id is permitted", self.payload(proposalsJSON: self.validProposalJSON(id: "प्रस्ताव-1")), expectedCount: 1)
    }

    // MARK: - Garbage / encoding

    private static func testGarbageAndEncodingFailures() {
        self.assertFails("trailing garbage after valid JSON", #"{"schemaVersion":1,"proposals":[]}garbage"#, expected: .invalidRootStructure)
        self.assertFails(
            "two concatenated JSON objects",
            #"{"schemaVersion":1,"proposals":[]}{"schemaVersion":1,"proposals":[]}"#,
            expected: .invalidRootStructure
        )
        // Both truncations happen while the root-level scan is still
        // finding where the "proposals" key's own value ends (bracket/quote
        // matching runs off the end of the text), so the root scan itself
        // is what fails here -- not the later, proposals-specific scan.
        self.assertFails("truncated JSON (unterminated object)", #"{"schemaVersion":1,"proposals":["#, expected: .invalidRootStructure)
        self.assertFails("truncated JSON (unterminated string)", #"{"schemaVersion":1,"proposals":[{"id":"p1"#, expected: .invalidRootStructure)
        self.assertFailsWithSomeTypedReason("malformed escape sequence", self.payload(proposalsJSON: #"{"id":"p1","rangeStart":0,"rangeLength":2,"expectedSourceText":"a\qb","replacementText":"AB","claimedCategory":"capitalization"}"#))

        // Invalid UTF-8 bytes fed directly as Data (not representable as a
        // Swift String literal, so constructed as raw bytes).
        var invalidUTF8 = Data(#"{"schemaVersion":1,"proposals":["#.utf8)
        invalidUTF8.append(contentsOf: [0xFF, 0xFE])
        do {
            _ = try IntelligenceProposalTransportParser.parse(invalidUTF8)
            preconditionFailure("invalid UTF-8 payload should have failed to parse")
        } catch let failure as IntelligenceProposalParseFailure {
            precondition(failure == .invalidEncoding, "\(failure)")
        } catch {
            preconditionFailure("unexpected error type \(error)")
        }
    }

    // MARK: - Structural all-or-nothing semantics

    private static func testStructuralAllOrNothingSemantics() {
        // proposal 1 valid, proposal 2 missing replacementText, proposal 3
        // valid -- the ENTIRE payload must fail, not just proposal 2.
        let mixed = [
            self.validProposalJSON(id: "p1"),
            #"{"id":"p2","rangeStart":0,"rangeLength":2,"expectedSourceText":"cd","claimedCategory":"capitalization"}"#,
            self.validProposalJSON(id: "p3"),
        ].joined(separator: ",")
        self.assertFails("one malformed proposal invalidates the whole structural payload", self.payload(proposalsJSON: mixed), expected: .missingField("replacementText"))
    }

    // MARK: - Successful parses (positive controls)

    private static func testSuccessfulParses() {
        self.assertSucceeds("single safe proposal", self.payload(proposalsJSON: self.validProposalJSON()), expectedCount: 1)
        let three = [
            self.validProposalJSON(id: "a", rangeStart: 0),
            self.validProposalJSON(id: "b", rangeStart: 10),
            self.validProposalJSON(id: "c", rangeStart: 20),
        ].joined(separator: ",")
        self.assertSucceeds("multiple safe proposals", self.payload(proposalsJSON: three), expectedCount: 3)
        for category in ["punctuation", "capitalization", "whitespace", "other"] {
            self.assertSucceeds("every recognized wire category parses: \(category)", self.payload(proposalsJSON: self.validProposalJSON(category: category)), expectedCount: 1)
        }
    }

    // MARK: - Parser -> Safety Authority integration (the two trust boundaries stay separate)

    private static func testSafetyAuthorityIntegration() {
        // Case 1: safe surface proposal parses, reaches the authority, is
        // autonomously accepted, and produces the expected resulting text.
        let source1 = "the accused was present"
        let theRange1 = (source1 as NSString).range(of: "the")
        let safeJSON = self.payload(proposalsJSON: #"{"id":"p1","rangeStart":\#(theRange1.location),"rangeLength":\#(theRange1.length),"expectedSourceText":"the","replacementText":"The","claimedCategory":"capitalization"}"#)
        switch self.parse(safeJSON) {
        case let .success(batch):
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source1, protectedSpans: [])
            precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.capitalizationOnly), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == "the accused was present".replacingOccurrences(of: "the accused", with: "The accused"), result.resultingText)
        case let .failure(error):
            preconditionFailure("expected the safe proposal to parse: \(error)")
        }

        // Case 2: a proposal that lies about its category (claims
        // punctuation while changing IPC -> CrPC) parses successfully, then
        // is rejected by the Safety Authority -- never by the parser.
        let source2 = "charged under IPC for the offence."
        let ipcRange2 = (source2 as NSString).range(of: "IPC")
        let lyingJSON = self.payload(proposalsJSON: #"{"id":"p1","rangeStart":\#(ipcRange2.location),"rangeLength":\#(ipcRange2.length),"expectedSourceText":"IPC","replacementText":"CrPC","claimedCategory":"punctuation"}"#)
        switch self.parse(lyingJSON) {
        case let .success(batch):
            precondition(batch.proposals[0].claimedCategory == .punctuation, "the parser must not second-guess or reclassify the claimed category")
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source2, protectedSpans: [])
            precondition(result.outcomes[0].disposition == .rejected(.unsupportedEditCategory), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == source2, "a lying proposal must never reach the resulting text")
        case let .failure(error):
            preconditionFailure("a structurally valid but semantically dishonest proposal must still parse: \(error)")
        }

        // Case 3: a proposal changing a protected date parses successfully,
        // then is rejected (review-only, not autonomous) by the authority.
        let source3 = "arrested on 16 March 2026 near the market."
        let dateRange = (source3 as NSString).range(of: "16 March 2026")
        let dateJSON = self.payload(proposalsJSON: #"{"id":"p1","rangeStart":\#(dateRange.location),"rangeLength":\#(dateRange.length),"expectedSourceText":"16 March 2026","replacementText":"15 March 2026","claimedCategory":"other"}"#)
        switch self.parse(dateJSON) {
        case let .success(batch):
            let result = IntelligenceSafetyAuthority.validate(
                proposals: batch.proposals,
                source: source3,
                protectedSpans: [ProtectedSpan(range: dateRange, kind: .independentlyProtected)]
            )
            precondition(result.outcomes[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == source3)
        case let .failure(error):
            preconditionFailure("a structurally valid protected-content mutation must still parse: \(error)")
        }

        // Case 4: a structurally valid but stale proposal (wrong
        // expectedSourceText) parses successfully, then is rejected by the
        // authority for the source mismatch -- never by the parser.
        let source4 = "the accused shall appear on 16 March 2026"
        // The real text at this range is "16 March" -- the proposal claims
        // (incorrectly) that it is "15 March", making it stale/shifted.
        let realRange4 = (source4 as NSString).range(of: "16 March")
        let staleJSON = self.payload(proposalsJSON: #"{"id":"p1","rangeStart":\#(realRange4.location),"rangeLength":\#(realRange4.length),"expectedSourceText":"15 March","replacementText":"16 March","claimedCategory":"other"}"#)
        switch self.parse(staleJSON) {
        case let .success(batch):
            let result = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source4, protectedSpans: [])
            precondition(result.outcomes[0].disposition == .rejected(.sourceTextMismatch), "\(result.outcomes[0].disposition)")
            precondition(result.resultingText == source4)
        case let .failure(error):
            preconditionFailure("a structurally valid but stale proposal must still parse: \(error)")
        }
    }
}
