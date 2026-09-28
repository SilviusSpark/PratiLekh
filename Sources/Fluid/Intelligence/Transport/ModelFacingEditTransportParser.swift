import Foundation

/// Every way an untrusted, model-shaped serialized payload can fail to
/// become `ModelFacingEdit` values. Structural/lexical failures only: this
/// type never expresses whether an edit *addresses* anything (that is
/// `IntelligenceAddressingResolver`'s job) or whether it is *safe* (that is
/// `IntelligenceSafetyAuthority`'s). Associated values are field/key names
/// only, never field content -- transcript text must never appear in a
/// parse failure.
enum ModelFacingEditParseFailure: Error, Equatable {
    case payloadTooLarge
    case invalidEncoding
    case invalidRootStructure
    case missingField(String)
    case unknownField(String)
    case duplicateKey(String)
    case unsupportedSchemaVersion
    case editCountExceeded
    /// A field is present but is the wrong JSON type or lexical form: a
    /// non-string where a string is required (including `null`), or an
    /// `occurrence`/`schemaVersion` that is not a plain JSON integer
    /// literal (fractional, exponent, quoted, `1.0`, leading zeros, or too
    /// large to represent as an `Int`).
    case invalidFieldType(String)
    case fieldLengthExceeded(String)
    case aggregateTextLimitExceeded
}

/// Conservative *engineering* bounds on untrusted model-facing transport
/// input. Independent of, and deliberately not shared with,
/// `IntelligenceProposalTransportLimits` (the V1.1 internal contract's
/// bounds), so changing one contract's limits can never silently change the
/// other's -- even though the numbers currently coincide. They exist only so
/// pathological output cannot cause excessive memory/CPU use; they say
/// nothing about what edit size is legally safe.
enum ModelFacingEditTransportLimits {
    static let maxPayloadBytes = 1_000_000
    static let maxEditCount = 500
    /// UTF-16 length bound applied to each of `sourceText`, `replacementText`,
    /// `leftContext` and `rightContext`.
    static let maxTextFieldLength = 10_000
    /// Sum of every text field's length across the whole batch, independent
    /// of the per-field bound.
    static let maxAggregateDecodedTextLength = 200_000
}

/// The result of successfully parsing a model-facing payload: a schema
/// version and zero or more still-untrusted edits. Success establishes only
/// that the payload is structurally and lexically well-formed; it grants the
/// edits no authority and does not establish that any of them addresses
/// anything in a source.
struct ParsedModelFacingEditBatch: Equatable {
    let schemaVersion: Int
    let edits: [ModelFacingEdit]
}

/// Strict parser for the V1.7 model-facing wire contract:
///
///     { "schemaVersion": 1,
///       "edits": [ { "sourceText": "...", "replacementText": "...",
///                    "occurrence": 2,            // optional integer
///                    "leftContext": "...",       // optional string
///                    "rightContext": "..." } ] } // optional string
///
/// This is a *different wire contract* from the V1.1 internal one
/// (`IntelligenceProposalTransportParser`: `proposals`, offsets, ids,
/// categories) and never accepts it: a V1.1-shaped payload fails here with
/// `unknownField`. The V1.1 parser is unmodified and remains the
/// internal-contract parser.
///
/// Discipline inherited from V1.1 (and using the same
/// `RawJSONObjectKeyScanner`, for the same reason: `JSONDecoder` silently
/// collapses duplicate keys and coerces `1.0` to an integer before any code
/// can observe it):
///   - whole-response, all-or-nothing structural parsing;
///   - duplicate-key and unknown-field rejection at the root and per edit;
///   - no type coercion: string fields must be JSON strings (never `null`,
///     numbers, booleans, arrays or objects); `occurrence` and
///     `schemaVersion` must be plain integer literals;
///   - bounded payload, count, per-field and aggregate sizes;
///   - text preserved exactly -- no trimming, Unicode normalization, or
///     repair.
///
/// **Ownership boundary for `occurrence` (deliberate, single-owner):** the
/// parser owns only that the value is a JSON integer literal representable
/// as an `Int`. It does *not* judge the value: `0`, negatives and
/// out-of-range ordinals parse successfully and are rejected -- or, per the
/// frozen V1.5/V1.6 decision table, sometimes rescued by independently
/// unique context -- by `IntelligenceAddressingResolver`
/// (`occurrenceOutOfRange`). Rejecting `0` structurally here would
/// duplicate that validation, would abort the whole batch for one item's bad
/// ordinal, and would make the frozen "invalid occurrence + uniquely
/// matching context resolves" rule unreachable. Likewise an empty
/// `sourceText` parses and is rejected per-item by the resolver
/// (`emptySourceText`), and an empty-string context parses and is treated by
/// the resolver as "not supplied".
enum ModelFacingEditTransportParser {
    private static let supportedSchemaVersions: Set<Int> = [1]
    private static let knownRootKeys: Set<String> = ["schemaVersion", "edits"]
    private static let requiredEditKeys = ["sourceText", "replacementText"]
    private static let optionalStringKeys = ["leftContext", "rightContext"]
    private static let knownEditKeys: Set<String> = ["sourceText", "replacementText", "occurrence", "leftContext", "rightContext"]

    static func parse(_ data: Data) throws -> ParsedModelFacingEditBatch {
        guard data.count <= ModelFacingEditTransportLimits.maxPayloadBytes else {
            throw ModelFacingEditParseFailure.payloadTooLarge
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ModelFacingEditParseFailure.invalidEncoding
        }
        guard let rootStart = text.firstIndex(where: { !$0.isWhitespace }) else {
            throw ModelFacingEditParseFailure.invalidRootStructure
        }

        let (rootEntries, rootEnd) = try self.scanObject(text, start: rootStart, onMalformed: .invalidRootStructure)
        guard text[rootEnd...].allSatisfy(\.isWhitespace) else {
            throw ModelFacingEditParseFailure.invalidRootStructure
        }

        var rootByKey: [String: Substring] = [:]
        for entry in rootEntries {
            guard self.knownRootKeys.contains(entry.key) else {
                throw ModelFacingEditParseFailure.unknownField(entry.key)
            }
            rootByKey[entry.key] = entry.value
        }

        guard let schemaVersionValue = rootByKey["schemaVersion"] else {
            throw ModelFacingEditParseFailure.missingField("schemaVersion")
        }
        guard let schemaVersion = self.strictIntegerLiteral(schemaVersionValue) else {
            throw ModelFacingEditParseFailure.invalidFieldType("schemaVersion")
        }
        guard self.supportedSchemaVersions.contains(schemaVersion) else {
            throw ModelFacingEditParseFailure.unsupportedSchemaVersion
        }

        guard let editsValue = rootByKey["edits"] else {
            throw ModelFacingEditParseFailure.missingField("edits")
        }
        guard editsValue.first == "[" else {
            throw ModelFacingEditParseFailure.invalidFieldType("edits")
        }
        let elements = try self.scanElements(text, start: editsValue.startIndex)
        guard elements.count <= ModelFacingEditTransportLimits.maxEditCount else {
            throw ModelFacingEditParseFailure.editCountExceeded
        }

        var edits: [ModelFacingEdit] = []
        var aggregateTextLength = 0
        for element in elements {
            guard element.first == "{" else {
                throw ModelFacingEditParseFailure.invalidFieldType("edits")
            }
            let edit = try self.parseEdit(text, element: element)
            aggregateTextLength += edit.sourceText.utf16.count
                + edit.replacementText.utf16.count
                + (edit.leftContext?.utf16.count ?? 0)
                + (edit.rightContext?.utf16.count ?? 0)
            guard aggregateTextLength <= ModelFacingEditTransportLimits.maxAggregateDecodedTextLength else {
                throw ModelFacingEditParseFailure.aggregateTextLimitExceeded
            }
            edits.append(edit)
        }
        return ParsedModelFacingEditBatch(schemaVersion: schemaVersion, edits: edits)
    }

    private static func parseEdit(_ text: String, element: Substring) throws -> ModelFacingEdit {
        let (entries, _) = try self.scanObject(text, start: element.startIndex, onMalformed: .invalidFieldType("edits"))
        var byKey: [String: Substring] = [:]
        for entry in entries {
            guard self.knownEditKeys.contains(entry.key) else {
                throw ModelFacingEditParseFailure.unknownField(entry.key)
            }
            byKey[entry.key] = entry.value
        }
        for required in self.requiredEditKeys where byKey[required] == nil {
            throw ModelFacingEditParseFailure.missingField(required)
        }

        // Always non-nil: presence was checked just above.
        let sourceText = try self.decodeString(byKey["sourceText"] ?? "", field: "sourceText")
        let replacementText = try self.decodeString(byKey["replacementText"] ?? "", field: "replacementText")
        var contexts: [String: String] = [:]
        for key in self.optionalStringKeys {
            if let raw = byKey[key] {
                contexts[key] = try self.decodeString(raw, field: key)
            }
        }

        var occurrence: Int?
        if let raw = byKey["occurrence"] {
            guard let value = self.strictIntegerLiteral(raw) else {
                throw ModelFacingEditParseFailure.invalidFieldType("occurrence")
            }
            occurrence = value
        }

        return ModelFacingEdit(
            sourceText: sourceText,
            replacementText: replacementText,
            occurrence: occurrence,
            leftContext: contexts["leftContext"],
            rightContext: contexts["rightContext"]
        )
    }

    // MARK: - String decoding

    /// Requires the raw value to be a JSON string literal (rejecting `null`,
    /// numbers, booleans, arrays and objects up front -- `JSONDecoder`'s
    /// optional handling would otherwise treat `null` as absent), then
    /// decodes just that literal, so JSON escaping is handled by Foundation
    /// without reimplementing it.
    private static func decodeString(_ raw: Substring, field: String) throws -> String {
        guard raw.first == "\"", raw.count >= 2, raw.last == "\"" else {
            throw ModelFacingEditParseFailure.invalidFieldType(field)
        }
        guard let data = String(raw).data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data)
        else {
            throw ModelFacingEditParseFailure.invalidFieldType(field)
        }
        guard decoded.utf16.count <= ModelFacingEditTransportLimits.maxTextFieldLength else {
            throw ModelFacingEditParseFailure.fieldLengthExceeded(field)
        }
        return decoded
    }

    // MARK: - Strict integer literal

    /// Accepts exactly the JSON integer grammar `-?(0|[1-9][0-9]*)` in ASCII
    /// digits, and only when the value fits an `Int`. Rejects fractional and
    /// exponent forms (`1.0`, `2e0`), quoted numbers, `+` signs, leading
    /// zeros (`01`), non-ASCII digits, and values too large for `Int`.
    /// Deliberately does not delegate to `JSONDecoder`, which silently
    /// accepts a whole-number float into an `Int` field.
    private static func strictIntegerLiteral(_ raw: Substring) -> Int? {
        var digits = raw
        if digits.first == "-" { digits = digits.dropFirst() }
        guard let first = digits.first, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        if first == "0", digits.count > 1 { return nil }
        return Int(raw)
    }

    // MARK: - Raw-scanner error mapping

    private static func scanObject(
        _ text: String,
        start: String.Index,
        onMalformed: ModelFacingEditParseFailure
    ) throws -> (entries: [RawJSONObjectKeyScanner.Entry], end: String.Index) {
        do {
            return try RawJSONObjectKeyScanner.scanObject(text, start: start)
        } catch let error as RawJSONObjectKeyScanner.ScanError {
            switch error.kind {
            case .malformedStructure: throw onMalformed
            case let .duplicateKey(key): throw ModelFacingEditParseFailure.duplicateKey(key)
            }
        }
    }

    private static func scanElements(_ text: String, start: String.Index) throws -> [Substring] {
        do {
            return try RawJSONObjectKeyScanner.scanArrayElements(text, start: start).elements
        } catch let error as RawJSONObjectKeyScanner.ScanError {
            switch error.kind {
            case .malformedStructure: throw ModelFacingEditParseFailure.invalidFieldType("edits")
            case let .duplicateKey(key): throw ModelFacingEditParseFailure.duplicateKey(key)
            }
        }
    }
}
