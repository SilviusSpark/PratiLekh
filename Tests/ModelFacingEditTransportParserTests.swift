import Foundation

/// Adversarial coverage for `ModelFacingEditTransportParser`, the strict
/// wire parser for the V1.7 model-facing contract. The governing question:
/// can a malformed, coerced, duplicated, oversized or extra-field payload
/// ever become a `ModelFacingEdit`? Required answer: no -- and whatever does
/// parse is preserved byte-for-byte, with addressing/safety judgments left
/// entirely to downstream components. No model, no network.
@main
enum ModelFacingEditTransportParserTests {
    private typealias Failure = ModelFacingEditParseFailure

    static func main() {
        // Valid payloads.
        self.testMinimalEdit()
        self.testFullEdit()
        self.testMultipleEditsPreserveOrder()
        self.testEmptyEditsArrayIsValid()
        self.testKeyOrderAndWhitespaceAreIrrelevant()
        self.testJSONEscapesDecodeExactly()
        self.testStructuralCharactersInsideStringsAreInert()

        // Text preservation.
        self.testOdiaEmojiAndMixedScriptPreservedExactly()
        self.testNoUnicodeNormalization()
        self.testWhitespaceAndEmptyStringsPreservedExactly()

        // occurrence: lexical ownership only.
        self.testOccurrenceValuesAcceptedStructurally()
        self.testOccurrenceNonIntegerFormsRejected()
        self.testOccurrenceOversizedRejected()
        self.testOccurrenceZeroOwnershipBoundaryEndToEnd()

        // Structure.
        self.testDuplicateKeysRejected()
        self.testUnknownFieldsRejected()
        self.testInternalContractShapeIsRejected()
        self.testMissingFieldsRejected()
        self.testWrongTypesRejected()
        self.testSchemaVersionStrictness()
        self.testMalformedJSONRejected()
        self.testInvalidUTF8Rejected()
        self.testAllOrNothing()

        // Limits.
        self.testPayloadSizeLimit()
        self.testEditCountLimit()
        self.testPerFieldLimitCountsUTF16()
        self.testAggregateLimit()

        // Failures never carry transcript text.
        self.testFailuresCarryNoTranscriptText()

        print("PASS: ModelFacingEditTransportParser strict wire-contract suite")
    }

    // MARK: - Helpers

    private static func parse(_ json: String) -> Result<ParsedModelFacingEditBatch, Failure> {
        self.parse(Data(json.utf8))
    }

    private static func parse(_ data: Data) -> Result<ParsedModelFacingEditBatch, Failure> {
        do {
            return .success(try ModelFacingEditTransportParser.parse(data))
        } catch let failure as Failure {
            return .failure(failure)
        } catch {
            preconditionFailure("parser threw a non-typed error: \(error)")
        }
    }

    private static func edits(_ json: String, file: StaticString = #file, line: UInt = #line) -> [ModelFacingEdit] {
        switch self.parse(json) {
        case let .success(batch): return batch.edits
        case let .failure(failure): preconditionFailure("expected success, got \(failure) for \(json.prefix(200))", file: file, line: line)
        }
    }

    private static func expectFailure(_ label: String, _ json: String, _ expected: Failure, file: StaticString = #file, line: UInt = #line) {
        switch self.parse(json) {
        case let .success(batch): preconditionFailure("\(label): expected \(expected), but parsed \(batch)", file: file, line: line)
        case let .failure(failure): precondition(failure == expected, "\(label): expected \(expected), got \(failure)", file: file, line: line)
        }
    }

    /// Wraps a single edit object body in a valid root.
    private static func root(_ editBody: String) -> String {
        #"{"schemaVersion":1,"edits":[{\#(editBody)}]}"#
    }

    // MARK: - Valid payloads

    private static func testMinimalEdit() {
        let parsed = self.edits(self.root(#""sourceText":"the","replacementText":"The""#))
        precondition(parsed == [ModelFacingEdit(sourceText: "the", replacementText: "The")])
        precondition(parsed[0].occurrence == nil && parsed[0].leftContext == nil && parsed[0].rightContext == nil, "absent optionals stay nil")
    }

    private static func testFullEdit() {
        let parsed = self.edits(self.root(#""sourceText":"the","replacementText":"The","occurrence":2,"leftContext":"said ","rightContext":" accused""#))
        precondition(parsed == [ModelFacingEdit(sourceText: "the", replacementText: "The", occurrence: 2, leftContext: "said ", rightContext: " accused")])
    }

    private static func testMultipleEditsPreserveOrder() {
        let json = #"{"schemaVersion":1,"edits":[{"sourceText":"c","replacementText":"C"},{"sourceText":"a","replacementText":"A","occurrence":3},{"sourceText":"b","replacementText":"B"}]}"#
        let parsed = self.edits(json)
        precondition(parsed.map(\.sourceText) == ["c", "a", "b"], "order must be preserved exactly")
        precondition(parsed[1].occurrence == 3 && parsed[0].occurrence == nil)
    }

    private static func testEmptyEditsArrayIsValid() {
        switch self.parse(#"{"schemaVersion":1,"edits":[]}"#) {
        case let .success(batch): precondition(batch.edits.isEmpty && batch.schemaVersion == 1)
        case let .failure(failure): preconditionFailure("zero edits is the preferred response: \(failure)")
        }
    }

    private static func testKeyOrderAndWhitespaceAreIrrelevant() {
        let json = """

          { "edits" : [
              { "replacementText" : "The" ,
                "occurrence" : 1 ,
                "sourceText" : "the" } ] ,
            "schemaVersion" : 1 }

        """
        precondition(self.edits(json) == [ModelFacingEdit(sourceText: "the", replacementText: "The", occurrence: 1)])
    }

    private static func testJSONEscapesDecodeExactly() {
        let parsed = self.edits(self.root(#""sourceText":"line\nbreak \"quoted\" back\\slash \u00e9 \ud83d\ude0a","replacementText":"tab\there""#))
        precondition(parsed[0].sourceText == "line\nbreak \"quoted\" back\\slash \u{00E9} \u{1F60A}", parsed[0].sourceText)
        precondition(parsed[0].replacementText == "tab\there")
    }

    private static func testStructuralCharactersInsideStringsAreInert() {
        let nasty = #"}]{[,:\"occurrence\":9"#
        let parsed = self.edits(self.root(#""sourceText":"\#(nasty)","replacementText":"x""#))
        precondition(parsed.count == 1 && parsed[0].occurrence == nil, "text that looks like JSON structure must stay text")
        precondition(parsed[0].sourceText == #"}]{[,:"occurrence":9"#)
    }

    // MARK: - Text preservation

    private static func testOdiaEmojiAndMixedScriptPreservedExactly() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let emoji = "\u{1F60A}"
        let mixed = "\(odia) \(emoji) \u{0928}\u{092E}\u{0938}\u{094D}\u{0924}\u{0947} abc"
        let parsed = self.edits(self.root(#""sourceText":"\#(odia)","replacementText":"\#(mixed)","leftContext":"\#(emoji)","rightContext":"\#(emoji)\#(emoji)""#))
        precondition(parsed[0].sourceText == odia)
        precondition(parsed[0].replacementText == mixed)
        precondition(parsed[0].leftContext == emoji && parsed[0].rightContext == emoji + emoji)
        precondition(Array(parsed[0].sourceText.unicodeScalars) == Array(odia.unicodeScalars), "scalar-for-scalar identical")
        precondition(parsed[0].leftContext?.utf16.count == 2, "non-BMP glyph is a surrogate pair")
    }

    private static func testNoUnicodeNormalization() {
        let nfc = "caf\u{00E9}"
        let nfd = "cafe\u{0301}"
        let parsed = self.edits(self.root(#""sourceText":"\#(nfd)","replacementText":"\#(nfc)""#))
        precondition(Array(parsed[0].sourceText.unicodeScalars) == Array(nfd.unicodeScalars), "decomposed form must not be recomposed")
        precondition(Array(parsed[0].replacementText.unicodeScalars) == Array(nfc.unicodeScalars), "precomposed form must not be decomposed")
    }

    private static func testWhitespaceAndEmptyStringsPreservedExactly() {
        let parsed = self.edits(self.root(#""sourceText":"  the  ","replacementText":"","leftContext":"","rightContext":" ""#))
        precondition(parsed[0].sourceText == "  the  ", "no trimming")
        precondition(parsed[0].replacementText == "", "empty replacement (a deletion) is structurally valid")
        precondition(parsed[0].leftContext == "", "empty context parses as empty; the resolver treats it as not supplied")
        precondition(parsed[0].rightContext == " ")
        // Empty sourceText is an addressing failure, not a wire failure.
        precondition(self.edits(self.root(#""sourceText":"","replacementText":"x""#)).count == 1)
    }

    // MARK: - occurrence

    private static func testOccurrenceValuesAcceptedStructurally() {
        // Wire parser owns lexical integer-ness only. The VALUE (1-based,
        // in range) belongs to IntelligenceAddressingResolver, which owns
        // occurrenceOutOfRange and the frozen fallback semantics.
        for (literal, expected) in [("1", 1), ("0", 0), ("-1", -1), ("-0", 0), ("2", 2), ("1000000", 1_000_000), ("9223372036854775807", Int.max), ("-9223372036854775808", Int.min)] {
            let parsed = self.edits(self.root(#""sourceText":"a","replacementText":"b","occurrence":\#(literal)"#))
            precondition(parsed[0].occurrence == expected, "occurrence \(literal) must parse structurally as \(expected)")
        }
    }

    private static func testOccurrenceNonIntegerFormsRejected() {
        for (label, literal) in [
            ("whole-number float", "1.0"), ("fractional", "1.5"), ("negative fractional", "-0.5"),
            ("exponent", "2e0"), ("upper exponent", "1E2"), ("quoted", #""2""#), ("quoted empty", #""""#),
            ("leading zero", "01"), ("plus sign", "+1"), ("null", "null"), ("true", "true"), ("false", "false"),
            ("array", "[1]"), ("object", "{}"), ("bare minus", "-"), ("hex", "0x1"), ("trailing dot", "1."),
            ("arabic-indic digit", "\u{0663}"), ("fullwidth digit", "\u{FF11}"), ("superscript", "\u{00B2}"), ("vulgar fraction", "\u{00BD}"),
            ("NaN", "NaN"), ("Infinity", "Infinity"),
        ] {
            self.expectFailure("occurrence \(label)", self.root(#""sourceText":"a","replacementText":"b","occurrence":\#(literal)"#), .invalidFieldType("occurrence"))
        }
    }

    private static func testOccurrenceOversizedRejected() {
        for literal in ["9223372036854775808", "-9223372036854775809", "99999999999999999999", String(repeating: "9", count: 400)] {
            self.expectFailure("occurrence \(literal.prefix(25))", self.root(#""sourceText":"a","replacementText":"b","occurrence":\#(literal)"#), .invalidFieldType("occurrence"))
        }
    }

    /// The documented ownership decision, demonstrated end to end: the wire
    /// parser accepts `occurrence: 0` and addressing owns the verdict -- which
    /// is what keeps the frozen "invalid occurrence rescued by uniquely
    /// matching context" rule reachable, and keeps one item's bad ordinal
    /// from aborting the whole batch.
    private static func testOccurrenceZeroOwnershipBoundaryEndToEnd() {
        let source = "the accused said the accused left"
        let json = #"{"schemaVersion":1,"edits":[{"sourceText":"the accused","replacementText":"X","occurrence":0},{"sourceText":"the accused","replacementText":"Y","occurrence":0,"rightContext":" left"}]}"#
        let batch = self.edits(json)
        precondition(batch.map(\.occurrence) == [0, 0], "parser passes 0 through untouched")
        let bridged = IntelligenceAddressingBridge.bridge(batch, source: source)
        guard case .rejected(.occurrenceOutOfRange(occurrence: 0, candidateCount: 2)) = bridged.items[0].result else {
            preconditionFailure("addressing must reject an unrescued 0: \(bridged.items[0].result)")
        }
        guard case let .resolved(proposal, .contextFallbackForInvalidOccurrence) = bridged.items[1].result else {
            preconditionFailure("addressing must apply the frozen fallback rule: \(bridged.items[1].result)")
        }
        precondition(proposal.range.location == 17)
    }

    // MARK: - Structure

    private static func testDuplicateKeysRejected() {
        self.expectFailure("root schemaVersion", #"{"schemaVersion":1,"schemaVersion":1,"edits":[]}"#, .duplicateKey("schemaVersion"))
        self.expectFailure("root edits", #"{"schemaVersion":1,"edits":[],"edits":[]}"#, .duplicateKey("edits"))
        for key in ["sourceText", "replacementText", "leftContext", "rightContext"] {
            var parts = [#""sourceText":"a""#, #""replacementText":"b""#]
            parts.removeAll { $0.hasPrefix("\"\(key)\"") }
            parts.append(contentsOf: ["\"\(key)\":\"c\"", "\"\(key)\":\"d\""])
            self.expectFailure("edit \(key)", self.root(parts.joined(separator: ",")), .duplicateKey(key))
        }
        self.expectFailure("edit occurrence (differing values)", self.root(#""sourceText":"a","replacementText":"b","occurrence":1,"occurrence":2"#), .duplicateKey("occurrence"))
        self.expectFailure("edit occurrence (identical values)", self.root(#""sourceText":"a","replacementText":"b","occurrence":1,"occurrence":1"#), .duplicateKey("occurrence"))
    }

    private static func testUnknownFieldsRejected() {
        self.expectFailure("root", #"{"schemaVersion":1,"edits":[],"note":"hi"}"#, .unknownField("note"))
        self.expectFailure("edit", self.root(#""sourceText":"a","replacementText":"b","confidence":0.9"#), .unknownField("confidence"))
        self.expectFailure("edit rationale", self.root(#""sourceText":"a","replacementText":"b","rationale":"because""#), .unknownField("rationale"))
        self.expectFailure("case-variant key", self.root(#""SourceText":"a","replacementText":"b""#), .unknownField("SourceText"))
        // Escaped spelling of a known key is not silently unescaped into a
        // match: it is an unknown key, and fails closed.
        self.expectFailure("escaped key spelling", self.root(#""sourc\u0065Text":"a","replacementText":"b""#), .unknownField(#"sourc\u0065Text"#))
    }

    private static func testInternalContractShapeIsRejected() {
        // A V1.1 internal-contract payload must never be accepted here.
        self.expectFailure("V1.1 root", #"{"schemaVersion":1,"proposals":[]}"#, .unknownField("proposals"))
        for extra in [#""id":"p1""#, #""rangeStart":0"#, #""rangeLength":3"#, #""expectedSourceText":"the""#, #""claimedCategory":"capitalization""#] {
            let key = String(extra.dropFirst().prefix { $0 != "\"" })
            self.expectFailure("model supplied \(key)", self.root(#""sourceText":"a","replacementText":"b",\#(extra)"#), .unknownField(key))
        }
    }

    private static func testMissingFieldsRejected() {
        self.expectFailure("no schemaVersion", #"{"edits":[]}"#, .missingField("schemaVersion"))
        self.expectFailure("no edits", #"{"schemaVersion":1}"#, .missingField("edits"))
        self.expectFailure("empty root", "{}", .missingField("schemaVersion"))
        self.expectFailure("no sourceText", self.root(#""replacementText":"b""#), .missingField("sourceText"))
        self.expectFailure("no replacementText", self.root(#""sourceText":"a""#), .missingField("replacementText"))
        self.expectFailure("empty edit object", self.root(""), .missingField("sourceText"))
    }

    private static func testWrongTypesRejected() {
        for (label, literal) in [("number", "1"), ("null", "null"), ("true", "true"), ("array", #"["a"]"#), ("object", #"{"a":1}"#), ("float", "1.5")] {
            self.expectFailure("sourceText \(label)", self.root(#""sourceText":\#(literal),"replacementText":"b""#), .invalidFieldType("sourceText"))
            self.expectFailure("replacementText \(label)", self.root(#""sourceText":"a","replacementText":\#(literal)"#), .invalidFieldType("replacementText"))
            self.expectFailure("leftContext \(label)", self.root(#""sourceText":"a","replacementText":"b","leftContext":\#(literal)"#), .invalidFieldType("leftContext"))
            self.expectFailure("rightContext \(label)", self.root(#""sourceText":"a","replacementText":"b","rightContext":\#(literal)"#), .invalidFieldType("rightContext"))
        }
        for (label, literal) in [("object", "{}"), ("string", #""[]""#), ("null", "null"), ("number", "5")] {
            self.expectFailure("edits \(label)", #"{"schemaVersion":1,"edits":\#(literal)}"#, .invalidFieldType("edits"))
        }
        for (label, element) in [("string", #""x""#), ("number", "1"), ("null", "null"), ("array", "[]"), ("true", "true")] {
            self.expectFailure("edit element \(label)", #"{"schemaVersion":1,"edits":[\#(element)]}"#, .invalidFieldType("edits"))
        }
    }

    private static func testSchemaVersionStrictness() {
        for (label, literal) in [("string", #""1""#), ("float", "1.0"), ("null", "null"), ("exponent", "1e0"), ("leading zero", "01"), ("array", "[1]")] {
            self.expectFailure("schemaVersion \(label)", #"{"schemaVersion":\#(literal),"edits":[]}"#, .invalidFieldType("schemaVersion"))
        }
        for literal in ["0", "2", "-1", "100"] {
            self.expectFailure("schemaVersion \(literal)", #"{"schemaVersion":\#(literal),"edits":[]}"#, .unsupportedSchemaVersion)
        }
    }

    private static func testMalformedJSONRejected() {
        let cases: [(String, String, Failure)] = [
            ("empty", "", .invalidRootStructure),
            ("whitespace only", "  \n ", .invalidRootStructure),
            ("bare text", "not json", .invalidRootStructure),
            ("top-level array", "[]", .invalidRootStructure),
            ("top-level string", #""x""#, .invalidRootStructure),
            ("unclosed root", #"{"schemaVersion":1,"edits":[]"#, .invalidRootStructure),
            ("trailing garbage", #"{"schemaVersion":1,"edits":[]} extra"#, .invalidRootStructure),
            ("two roots", #"{"schemaVersion":1,"edits":[]}{"schemaVersion":1,"edits":[]}"#, .invalidRootStructure),
            ("markdown fence", "```json\n{\"schemaVersion\":1,\"edits\":[]}\n```", .invalidRootStructure),
            ("single quotes", "{'schemaVersion':1,'edits':[]}", .invalidRootStructure),
            ("trailing comma in root", #"{"schemaVersion":1,"edits":[],}"#, .invalidRootStructure),
            ("missing colon", #"{"schemaVersion" 1,"edits":[]}"#, .invalidRootStructure),
            ("trailing comma in edits", #"{"schemaVersion":1,"edits":[{"sourceText":"a","replacementText":"b"},]}"#, .invalidFieldType("edits")),
            ("unclosed edits array", #"{"schemaVersion":1,"edits":[{"sourceText":"a","replacementText":"b"}"#, .invalidRootStructure),
            ("unterminated string", #"{"schemaVersion":1,"edits":[{"sourceText":"a,"replacementText":"b"}]}"#, .invalidRootStructure),
            ("unclosed edit object", #"{"schemaVersion":1,"edits":[{"sourceText":"a","replacementText":"b"]}"#, .invalidFieldType("edits")),
        ]
        for (label, json, expected) in cases {
            switch self.parse(json) {
            case .success: preconditionFailure("\(label): malformed JSON must never parse")
            case let .failure(failure):
                if failure != expected {
                    // The exact category for a few malformed shapes depends on
                    // where the scanner gives up; what is contractual is that
                    // it fails, typed and without repair. Still pin it so a
                    // change is noticed and reviewed rather than silent.
                    preconditionFailure("\(label): expected \(expected), got \(failure)")
                }
            }
        }
        // String-level malformations reach the string decoder and fail closed.
        for (label, body) in [
            ("invalid escape", #""sourceText":"a\qb","replacementText":"x""#),
            ("lone high surrogate escape", #""sourceText":"\ud800","replacementText":"x""#),
            ("lone low surrogate escape", #""sourceText":"\ude0a","replacementText":"x""#),
            ("short unicode escape", #""sourceText":"\u12","replacementText":"x""#),
        ] {
            self.expectFailure(label, self.root(body), .invalidFieldType("sourceText"))
        }
        self.expectFailure("raw newline inside string", self.root("\"sourceText\":\"a\nb\",\"replacementText\":\"x\""), .invalidFieldType("sourceText"))
        self.expectFailure("raw tab inside string", self.root("\"sourceText\":\"a\tb\",\"replacementText\":\"x\""), .invalidFieldType("sourceText"))
    }

    private static func testInvalidUTF8Rejected() {
        var data = Data(#"{"schemaVersion":1,"edits":[{"sourceText":"a"#.utf8)
        data.append(contentsOf: [0xFF, 0xFE])
        data.append(contentsOf: Data(#"","replacementText":"b"}]}"#.utf8))
        switch self.parse(data) {
        case .success: preconditionFailure("invalid UTF-8 must not parse")
        case let .failure(failure): precondition(failure == .invalidEncoding, "\(failure)")
        }
    }

    private static func testAllOrNothing() {
        let json = #"{"schemaVersion":1,"edits":[{"sourceText":"a","replacementText":"A"},{"sourceText":"b","replacementText":"B","occurrence":1.5},{"sourceText":"c","replacementText":"C"}]}"#
        self.expectFailure("one bad edit invalidates the batch", json, .invalidFieldType("occurrence"))
        let unknown = #"{"schemaVersion":1,"edits":[{"sourceText":"a","replacementText":"A"},{"sourceText":"b","replacementText":"B","id":"x"}]}"#
        self.expectFailure("one unknown field invalidates the batch", unknown, .unknownField("id"))
    }

    // MARK: - Limits

    private static func testPayloadSizeLimit() {
        let big = String(repeating: " ", count: ModelFacingEditTransportLimits.maxPayloadBytes + 1)
        switch self.parse(#"{"schemaVersion":1,"edits":[]}"# + big) {
        case .success: preconditionFailure("over-limit payload must be rejected")
        case let .failure(failure): precondition(failure == .payloadTooLarge, "\(failure)")
        }
        // Exactly at the limit is checked by size before anything else and
        // passes that gate (trailing whitespace is legal JSON).
        let atLimitBody = #"{"schemaVersion":1,"edits":[]}"#
        let padded = atLimitBody + String(repeating: " ", count: ModelFacingEditTransportLimits.maxPayloadBytes - atLimitBody.utf8.count)
        precondition(padded.utf8.count == ModelFacingEditTransportLimits.maxPayloadBytes)
        if case let .failure(failure) = self.parse(padded) { preconditionFailure("payload exactly at the limit must parse: \(failure)") }
    }

    private static func testEditCountLimit() {
        func payload(count: Int) -> String {
            let item = #"{"sourceText":"a","replacementText":"b"}"#
            return #"{"schemaVersion":1,"edits":[\#(Array(repeating: item, count: count).joined(separator: ","))]}"#
        }
        precondition(self.edits(payload(count: ModelFacingEditTransportLimits.maxEditCount)).count == ModelFacingEditTransportLimits.maxEditCount)
        self.expectFailure("one over", payload(count: ModelFacingEditTransportLimits.maxEditCount + 1), .editCountExceeded)
    }

    private static func testPerFieldLimitCountsUTF16() {
        let limit = ModelFacingEditTransportLimits.maxTextFieldLength
        for field in ["sourceText", "replacementText", "leftContext", "rightContext"] {
            func body(_ value: String) -> String {
                var parts = [#""sourceText":"a""#, #""replacementText":"b""#]
                parts.removeAll { $0.hasPrefix("\"\(field)\"") }
                parts.append("\"\(field)\":\"\(value)\"")
                return self.root(parts.joined(separator: ","))
            }
            precondition(self.edits(body(String(repeating: "x", count: limit))).count == 1, "\(field) at the limit must parse")
            self.expectFailure("\(field) one over", body(String(repeating: "x", count: limit + 1)), .fieldLengthExceeded(field))
        }
        // The bound is UTF-16 units, matching the resolver's coordinate
        // system: 5001 emoji = 10,002 units.
        let emoji = String(repeating: "\u{1F60A}", count: limit / 2 + 1)
        self.expectFailure("emoji counted as UTF-16", self.root(#""sourceText":"\#(emoji)","replacementText":"b""#), .fieldLengthExceeded("sourceText"))
        precondition(self.edits(self.root(#""sourceText":"\#(String(repeating: "\u{1F60A}", count: limit / 2))","replacementText":"b""#)).count == 1)
    }

    private static func testAggregateLimit() {
        let limit = ModelFacingEditTransportLimits.maxAggregateDecodedTextLength
        let perField = ModelFacingEditTransportLimits.maxTextFieldLength
        func payload(editCount: Int) -> String {
            let item = #"{"sourceText":"\#(String(repeating: "x", count: perField))","replacementText":""}"#
            return #"{"schemaVersion":1,"edits":[\#(Array(repeating: item, count: editCount).joined(separator: ","))]}"#
        }
        precondition(limit % perField == 0, "test premise")
        precondition(self.edits(payload(editCount: limit / perField)).count == limit / perField, "exactly at the aggregate limit must parse")
        self.expectFailure("aggregate over", payload(editCount: limit / perField + 1), .aggregateTextLimitExceeded)
    }

    // MARK: - No transcript text in failures

    private static func testFailuresCarryNoTranscriptText() {
        let secret = "CONFIDENTIAL-STATEMENT"
        let payloads = [
            self.root(#""sourceText":"\#(secret)","replacementText":"x","occurrence":1.5"#),
            self.root(#""sourceText":"\#(secret)","replacementText":"x","note":"y""#),
            self.root(#""sourceText":"\#(secret)","replacementText":null"#),
            self.root(#""sourceText":"\#(secret)","replacementText":"x","sourceText":"\#(secret)""#),
            self.root(#""sourceText":"\#(String(repeating: secret, count: 1000))","replacementText":"x""#),
        ]
        for payload in payloads {
            guard case let .failure(failure) = self.parse(payload) else { preconditionFailure("expected failure") }
            precondition(!String(describing: failure).contains(secret), "failure must name fields, never echo transcript text: \(failure)")
        }
    }
}
