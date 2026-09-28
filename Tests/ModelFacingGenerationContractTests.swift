import Foundation

/// Guards the V1.7 model-facing generation contract against drifting out of
/// sync with what `ModelFacingEditTransportParser` actually enforces -- by
/// *deriving* payloads from the advertised schema and feeding them to the
/// real parser, rather than only comparing field-name lists. No model is
/// invoked: this proves the contract is self-consistent, not that any model
/// complies with it (that is what the adversarial parser suite is for).
@main
enum ModelFacingGenerationContractTests {
    static func main() {
        self.testToolNameStableAndDistinctFromInternalContract()
        self.testSchemaStructure()
        self.testSchemaDoesNotAdvertiseInternalOrUnsupportedFields()
        self.testSchemaReusesAuthoritativeEditCountLimit()
        self.testSchemaDoesNotDeclareOccurrenceMinimum()
        self.testParserAcceptsPayloadBuiltFromSchema()
        self.testParserRejectsEachSchemaRequiredFieldWhenMissing()
        self.testParserAcceptsEachOptionalFieldWhenOmitted()
        self.testParserEnforcesSchemaDeclaredTypes()
        self.testParserRejectsFieldOutsideSchema()
        self.testParserEnforcesSchemaEditCountBound()
        self.testInstructionsStateTheLiteralSourceRule()
        self.testInstructionsStateSmallestCorrectionBearingSpan()
        self.testInstructionsStateOneBasedOccurrence()
        self.testInstructionsStateContextIsOptionalEvidence()
        self.testInstructionsForbidOffsetsIDsAndCategories()
        self.testInstructionsRetainV1SurfaceScopeAndZeroEditPreference()
        self.testInstructionsDoNotLeakInternalContractVocabulary()
        self.testInternalContractIsUntouched()
        print("PASS: ModelFacingGenerationContract schema/parser/instruction consistency suite")
    }

    // MARK: - Schema accessors

    private static func function() -> [String: Any] {
        guard let function = ModelFacingGenerationContract.toolDefinition["function"] as? [String: Any] else {
            preconditionFailure("tool definition must have a \"function\" object")
        }
        return function
    }

    private static func parameters() -> [String: Any] {
        guard let parameters = self.function()["parameters"] as? [String: Any] else { preconditionFailure("missing parameters") }
        return parameters
    }

    private static func editsSchema() -> [String: Any] {
        guard let properties = self.parameters()["properties"] as? [String: Any],
              let edits = properties["edits"] as? [String: Any]
        else { preconditionFailure("parameters.properties.edits must exist") }
        return edits
    }

    private static func itemSchema() -> [String: Any] {
        guard let items = self.editsSchema()["items"] as? [String: Any] else { preconditionFailure("edits.items must exist") }
        return items
    }

    private static func itemProperties() -> [String: [String: Any]] {
        guard let properties = self.itemSchema()["properties"] as? [String: [String: Any]] else { preconditionFailure("items.properties must exist") }
        return properties
    }

    private static func itemRequired() -> [String] {
        self.itemSchema()["required"] as? [String] ?? []
    }

    /// A syntactically valid JSON literal for a schema-declared type.
    private static func sample(for type: String, key: String) -> String {
        switch type {
        case "string": return "\"sample-\(key)\""
        case "integer": return "1"
        default: preconditionFailure("schema uses a type this test does not know how to sample: \(type)")
        }
    }

    private static func editJSON(including keys: [String]) -> String {
        let properties = self.itemProperties()
        let fields = keys.sorted().map { key -> String in
            guard let type = properties[key]?["type"] as? String else { preconditionFailure("schema has no type for \(key)") }
            return "\"\(key)\":\(self.sample(for: type, key: key))"
        }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private static func root(_ editObject: String) -> String {
        #"{"schemaVersion":1,"edits":[\#(editObject)]}"#
    }

    private static func parses(_ json: String) -> Bool {
        (try? ModelFacingEditTransportParser.parse(Data(json.utf8))) != nil
    }

    // MARK: - Tool identity and schema shape

    private static func testToolNameStableAndDistinctFromInternalContract() {
        precondition(ModelFacingGenerationContract.toolName == "propose_literal_transcript_edits")
        precondition(ModelFacingGenerationContract.toolName != IntelligenceGenerationContract.toolName, "the two contracts must never share a tool name")
        precondition(ModelFacingGenerationContract.toolDefinition["type"] as? String == "function")
        precondition(self.function()["name"] as? String == ModelFacingGenerationContract.toolName)
    }

    private static func testSchemaStructure() {
        precondition(Set(self.parameters()["required"] as? [String] ?? []) == ["schemaVersion", "edits"])
        precondition(self.parameters()["additionalProperties"] as? Bool == false)
        precondition(Set(self.itemRequired()) == ["sourceText", "replacementText"])
        precondition(Set(self.itemProperties().keys) == ["sourceText", "replacementText", "occurrence", "leftContext", "rightContext"])
        precondition(self.itemSchema()["additionalProperties"] as? Bool == false)
        precondition(self.itemProperties()["sourceText"]?["type"] as? String == "string")
        precondition(self.itemProperties()["replacementText"]?["type"] as? String == "string")
        precondition(self.itemProperties()["occurrence"]?["type"] as? String == "integer")
        precondition(self.itemProperties()["leftContext"]?["type"] as? String == "string")
        precondition(self.itemProperties()["rightContext"]?["type"] as? String == "string")
    }

    private static func testSchemaDoesNotAdvertiseInternalOrUnsupportedFields() {
        let properties = self.itemProperties()
        for forbidden in ["id", "rangeStart", "rangeLength", "expectedSourceText", "claimedCategory", "confidence", "rationale", "anchorText", "anchorSide", "atStart", "atEnd", "audioTimeRange"] {
            precondition(properties[forbidden] == nil, "schema must not advertise \"\(forbidden)\"")
        }
        precondition((self.parameters()["properties"] as? [String: Any])?["proposals"] == nil, "the model-facing root key is edits, never proposals")
    }

    private static func testSchemaReusesAuthoritativeEditCountLimit() {
        precondition(self.editsSchema()["maxItems"] as? Int == ModelFacingEditTransportLimits.maxEditCount, "advertised max must be the constant the parser enforces")
    }

    private static func testSchemaDoesNotDeclareOccurrenceMinimum() {
        // The 1-based rule is stated in the instructions and enforced by
        // addressing; the wire parser deliberately accepts 0 structurally
        // (see ModelFacingEditTransportParser), so the schema must not
        // claim a wire-level bound the parser does not enforce.
        precondition(self.itemProperties()["occurrence"]?["minimum"] == nil)
        precondition(self.parses(self.root(#"{"sourceText":"a","replacementText":"b","occurrence":0}"#)), "parser accepts 0 structurally; addressing owns the verdict")
    }

    // MARK: - Schema-derived parser consistency

    private static func testParserAcceptsPayloadBuiltFromSchema() {
        let everyKey = Array(self.itemProperties().keys)
        precondition(self.parses(self.root(self.editJSON(including: everyKey))), "a payload containing every schema-declared field must parse")
        precondition(self.parses(self.root(self.editJSON(including: self.itemRequired()))), "a payload containing only schema-required fields must parse")
    }

    private static func testParserRejectsEachSchemaRequiredFieldWhenMissing() {
        let everyKey = Array(self.itemProperties().keys)
        for required in self.itemRequired() {
            let json = self.root(self.editJSON(including: everyKey.filter { $0 != required }))
            switch Result(catching: { try ModelFacingEditTransportParser.parse(Data(json.utf8)) }) {
            case .success: preconditionFailure("schema-required \"\(required)\" must be required by the parser")
            case let .failure(error): precondition(error as? ModelFacingEditParseFailure == .missingField(required), "\(error)")
            }
        }
        for rootRequired in (self.parameters()["required"] as? [String] ?? []) {
            var fields = ["\"schemaVersion\":1", "\"edits\":[]"]
            fields.removeAll { $0.hasPrefix("\"\(rootRequired)\"") }
            let json = "{" + fields.joined(separator: ",") + "}"
            precondition(!self.parses(json), "root-required \"\(rootRequired)\" must be required by the parser")
        }
    }

    private static func testParserAcceptsEachOptionalFieldWhenOmitted() {
        let optional = Set(self.itemProperties().keys).subtracting(self.itemRequired())
        precondition(optional == ["occurrence", "leftContext", "rightContext"])
        for key in optional {
            let keys = self.itemRequired() + [key]
            precondition(self.parses(self.root(self.editJSON(including: keys))), "optional \"\(key)\" must parse when present")
            precondition(self.parses(self.root(self.editJSON(including: self.itemRequired()))), "optional \"\(key)\" must parse when omitted")
        }
    }

    private static func testParserEnforcesSchemaDeclaredTypes() {
        for (key, schema) in self.itemProperties() {
            guard let type = schema["type"] as? String else { preconditionFailure("no type for \(key)") }
            let wrongLiteral = (type == "string") ? "1" : #""1""#
            var fields = self.itemRequired().filter { $0 != key }.map { "\"\($0)\":\"x\"" }
            fields.append("\"\(key)\":\(wrongLiteral)")
            precondition(!self.parses(self.root("{" + fields.joined(separator: ",") + "}")), "\"\(key)\" is declared \(type); the parser must reject the other type")
        }
    }

    private static func testParserRejectsFieldOutsideSchema() {
        precondition(!self.parses(self.root(#"{"sourceText":"a","replacementText":"b","claimedCategory":"other"}"#)))
        precondition(!self.parses(#"{"schemaVersion":1,"edits":[],"extra":1}"#))
    }

    private static func testParserEnforcesSchemaEditCountBound() {
        guard let maxItems = self.editsSchema()["maxItems"] as? Int else { preconditionFailure("maxItems missing") }
        let item = self.editJSON(including: self.itemRequired())
        func payload(_ count: Int) -> String { #"{"schemaVersion":1,"edits":[\#(Array(repeating: item, count: count).joined(separator: ","))]}"# }
        precondition(self.parses(payload(maxItems)), "exactly maxItems must parse")
        precondition(!self.parses(payload(maxItems + 1)), "maxItems + 1 must be rejected")
    }

    // MARK: - Instructions

    private static let text = ModelFacingGenerationContract.instructions.lowercased()

    private static func expectPhrase(_ phrase: String, _ why: String) {
        precondition(self.text.contains(phrase.lowercased()), "instructions must \(why) (expected phrase: \"\(phrase)\")")
    }

    private static func testInstructionsStateTheLiteralSourceRule() {
        self.expectPhrase("copied exactly", "require literal, exact source text")
        self.expectPhrase("character for character", "require literal, exact source text")
        self.expectPhrase("never paraphrase", "forbid paraphrase")
        self.expectPhrase("normalize", "forbid normalization")
    }

    private static func testInstructionsStateSmallestCorrectionBearingSpan() {
        self.expectPhrase("smallest span", "state the smallest-span rule")
        self.expectPhrase("not a whole sentence", "discourage whole-sentence spans")
        precondition(ModelFacingGenerationContract.instructions.contains("propose_literal_transcript_edits"), "instructions must name the tool")
    }

    private static func testInstructionsStateOneBasedOccurrence() {
        self.expectPhrase("appears more than once", "say occurrence is for repeated source text")
        self.expectPhrase("counting from 1", "state 1-based counting")
        self.expectPhrase("first appearance is 1", "state first = 1")
        self.expectPhrase("second is 2", "give the second example")
        self.expectPhrase("third is 3", "give the third example")
        self.expectPhrase("never use 0", "forbid 0")
        self.expectPhrase("appears exactly once, omit occurrence", "say to omit occurrence for unique text")
        let occurrenceDescription = self.itemProperties()["occurrence"]?["description"] as? String ?? ""
        precondition(occurrenceDescription.contains("first = 1") && occurrenceDescription.contains("Never 0"), "the schema's own occurrence description must state the convention too")
    }

    private static func testInstructionsStateContextIsOptionalEvidence() {
        self.expectPhrase("leftcontext and rightcontext are optional", "state context is optional")
        self.expectPhrase("extra evidence", "call context supplementary evidence")
        self.expectPhrase("also be copied exactly", "require literal context")
        self.expectPhrase("omit any optional field", "tell the model to omit unneeded optional fields")
        self.expectPhrase("null", "warn against null/empty optionals")
    }

    private static func testInstructionsForbidOffsetsIDsAndCategories() {
        self.expectPhrase("do not provide utf-16 offsets", "forbid offsets")
        self.expectPhrase("ids", "forbid ids")
        self.expectPhrase("edit categories", "forbid claimed categories")
        self.expectPhrase("rejected entirely", "warn that extra fields reject the whole response")
    }

    private static func testInstructionsRetainV1SurfaceScopeAndZeroEditPreference() {
        for topic in ["punctuation", "capitalization", "whitespace", "name", "date", "amount", "statute", "case identifier", "witness"] {
            self.expectPhrase(topic, "retain the V1 surface scope / protected-content warning")
        }
        self.expectPhrase("do not return a corrected transcript", "forbid a replacement transcript")
        self.expectPhrase("zero edits", "prefer zero edits when nothing needs changing")
    }

    private static func testInstructionsDoNotLeakInternalContractVocabulary() {
        for internalTerm in ["rangestart", "rangelength", "claimedcategory", "expectedsourcetext", "\"proposals\"", "propose_transcript_edits"] {
            precondition(!self.text.contains(internalTerm), "model-facing instructions must not mention the internal contract's \"\(internalTerm)\"")
        }
    }

    // MARK: - No accidental migration

    private static func testInternalContractIsUntouched() {
        precondition(IntelligenceGenerationContract.toolName == "propose_transcript_edits")
        precondition(IntelligenceGenerationContract.instructions.contains("UTF-16 offsets"), "the V1.2 internal contract keeps asking for UTF-16 offsets; V1.7 does not migrate it")
    }
}
