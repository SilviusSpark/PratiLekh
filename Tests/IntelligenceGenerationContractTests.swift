import Foundation

/// Tests the invariants of the model-facing generation contract itself --
/// not model compliance (no model is invoked anywhere in this suite), only
/// that the tool schema and instructions are internally consistent with the
/// committed V1.1 wire contract and V1 product scope. A model choosing to
/// ignore every word of this contract is exactly what the adversarial
/// suites in `IntelligenceProviderResponseAdapterTests` and
/// `IntelligenceProposalTransportParserTests` already prove is safe; this
/// file only guards against the *contract itself* silently drifting out of
/// sync with what those layers actually enforce.
@main
enum IntelligenceGenerationContractTests {
    static func main() {
        testToolNameIsStable()
        testSchemaStructureMatchesV1TransportContract()
        testSchemaDoesNotAdvertiseUnsupportedFields()
        testSchemaReusesAuthoritativeProposalCountLimit()
        testInstructionsProhibitWholesaleReplacement()
        testInstructionsPermitZeroProposals()
        testInstructionsRestrictToSurfaceEdits()
        testInstructionsProhibitProtectedContentChanges()
        print("PASS: IntelligenceGenerationContract invariants")
    }

    private static func testToolNameIsStable() {
        precondition(IntelligenceGenerationContract.toolName == "propose_transcript_edits", IntelligenceGenerationContract.toolName)
    }

    private static func function() -> [String: Any] {
        guard let function = IntelligenceGenerationContract.toolDefinition["function"] as? [String: Any] else {
            preconditionFailure("tool definition must have a \"function\" object")
        }
        return function
    }

    private static func parameters() -> [String: Any] {
        guard let parameters = self.function()["parameters"] as? [String: Any] else {
            preconditionFailure("function must have a \"parameters\" object")
        }
        return parameters
    }

    private static func proposalItemSchema() -> [String: Any] {
        guard
            let proposalsSchema = self.parameters()["properties"] as? [String: Any],
            let proposals = proposalsSchema["proposals"] as? [String: Any],
            let items = proposals["items"] as? [String: Any]
        else {
            preconditionFailure("parameters.properties.proposals.items must exist")
        }
        return items
    }

    private static func testSchemaStructureMatchesV1TransportContract() {
        precondition(IntelligenceGenerationContract.toolDefinition["type"] as? String == "function")
        precondition(self.function()["name"] as? String == IntelligenceGenerationContract.toolName)

        let params = self.parameters()
        let topLevelRequired = Set(params["required"] as? [String] ?? [])
        precondition(topLevelRequired == ["schemaVersion", "proposals"], "\(topLevelRequired)")

        let item = self.proposalItemSchema()
        let itemRequired = Set(item["required"] as? [String] ?? [])
        precondition(itemRequired == ["id", "rangeStart", "rangeLength", "expectedSourceText", "replacementText", "claimedCategory"], "\(itemRequired)")

        let properties = item["properties"] as? [String: Any] ?? [:]
        precondition(Set(properties.keys) == itemRequired, "schema must declare exactly the fields it requires, no more, no fewer")

        guard let categorySchema = properties["claimedCategory"] as? [String: Any],
              let enumValues = categorySchema["enum"] as? [String]
        else {
            preconditionFailure("claimedCategory must declare an enum")
        }
        // Exhaustive switch: if IntelligenceEditCategory ever gains or loses
        // a case, this fails to COMPILE, forcing the schema to be updated
        // in the same change rather than silently drifting out of sync.
        func expectedWireValue(_ category: IntelligenceEditCategory) -> String {
            switch category {
            case .punctuation: return "punctuation"
            case .capitalization: return "capitalization"
            case .whitespace: return "whitespace"
            case .other: return "other"
            }
        }
        let expected: Set<String> = [
            expectedWireValue(.punctuation), expectedWireValue(.capitalization), expectedWireValue(.whitespace), expectedWireValue(.other),
        ]
        precondition(Set(enumValues) == expected, "schema category enum \(enumValues) must exactly match IntelligenceEditCategory's cases")
    }

    private static func testSchemaDoesNotAdvertiseUnsupportedFields() {
        let item = self.proposalItemSchema()
        let properties = item["properties"] as? [String: Any] ?? [:]
        for forbidden in ["confidence", "rationale", "audioTimeRange", "acousticConfidence", "alignmentEvidence", "candidateAlternatives"] {
            precondition(properties[forbidden] == nil, "schema must not advertise the unsupported field \"\(forbidden)\"")
        }
        precondition(item["additionalProperties"] as? Bool == false, "schema should not silently permit undeclared proposal fields")
    }

    private static func testSchemaReusesAuthoritativeProposalCountLimit() {
        let proposalsSchema = (self.parameters()["properties"] as? [String: Any])?["proposals"] as? [String: Any] ?? [:]
        let maxItems = proposalsSchema["maxItems"] as? Int
        precondition(maxItems == IntelligenceProposalTransportLimits.maxProposalCount, "the schema's advertised max must be the same constant V1.1 actually enforces, not a copied number")
    }

    private static func testInstructionsProhibitWholesaleReplacement() {
        let text = IntelligenceGenerationContract.instructions.lowercased()
        precondition(text.contains("do not return a corrected transcript"), "instructions must explicitly forbid returning a replacement transcript")
        precondition(!text.contains("rewrite the transcript"), "instructions must never invite a rewritten transcript")
    }

    private static func testInstructionsPermitZeroProposals() {
        let text = IntelligenceGenerationContract.instructions.lowercased()
        precondition(text.contains("zero edits"), "instructions must explicitly say zero proposals is acceptable and preferred")
    }

    private static func testInstructionsRestrictToSurfaceEdits() {
        let text = IntelligenceGenerationContract.instructions.lowercased()
        for allowed in ["punctuation", "capitalization", "whitespace"] {
            precondition(text.contains(allowed), "instructions must name the allowed V1 surface category \"\(allowed)\"")
        }
    }

    private static func testInstructionsProhibitProtectedContentChanges() {
        let text = IntelligenceGenerationContract.instructions.lowercased()
        for protectedTopic in ["name", "date", "amount", "statute", "case identifier", "witness"] {
            precondition(text.contains(protectedTopic), "instructions must explicitly warn against changing \"\(protectedTopic)\"")
        }
    }
}
