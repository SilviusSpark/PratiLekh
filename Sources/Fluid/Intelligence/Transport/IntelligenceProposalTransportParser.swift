import Foundation

/// Every way an untrusted, model-shaped serialized payload can fail to
/// become native `IntelligenceProposal` values. Structural/transport
/// failures only -- this type never expresses a semantic-safety verdict
/// (overlap, protected-span intersection, category truthfulness, ...); that
/// remains `IntelligenceSafetyAuthority`'s job alone, downstream of this
/// parser. Associated values are field/key *names* only, never field
/// *content* -- transcript text must never appear in a parse failure.
enum IntelligenceProposalParseFailure: Error, Equatable {
    case payloadTooLarge
    case invalidEncoding
    case invalidRootStructure
    case missingField(String)
    case unknownField(String)
    case duplicateKey(String)
    case unsupportedSchemaVersion
    case proposalCountExceeded
    case invalidFieldType(String)
    case invalidRange
    case fieldLengthExceeded(String)
    case emptyID
    case duplicateProposalID
    case unsupportedCategory
    case aggregateTextLimitExceeded
}

/// Conservative *engineering* bounds on untrusted transport input --
/// distinct from, and independent of, `IntelligenceSafetyAuthority`'s
/// semantic edit-safety policy, which deliberately has no numeric bounds
/// yet (an intentionally deferred empirical/configuration decision -- see
/// CLAUDE.md). These exist only so pathological model/provider output
/// cannot cause excessive memory/CPU use; they say nothing about what edit
/// size is legally safe.
enum IntelligenceProposalTransportLimits {
    /// Real dictation utterances and their proposal batches are expected to
    /// be at most a few kilobytes; 1 MB leaves enormous headroom while still
    /// bounding truly pathological input, checked before any decoding.
    static let maxPayloadBytes = 1_000_000
    static let maxProposalCount = 500
    static let maxIDLength = 200
    static let maxExpectedSourceTextLength = 10_000
    static let maxReplacementTextLength = 10_000
    /// Sum of every id + expectedSourceText + replacementText length across
    /// the whole batch -- an outer bound independent of the per-field
    /// limits above, so many proposals each just under a per-field limit
    /// still cannot add up to unbounded decoded text.
    static let maxAggregateDecodedTextLength = 200_000
    /// Bounds `rangeStart`/`rangeLength` individually, far below `Int.max`,
    /// checked before they are ever added together -- so that later
    /// arithmetic (here or in `IntelligenceSafetyAuthority`) can never
    /// overflow.
    static let maxRangeValue = 10_000_000
}

/// The result of successfully parsing a transport payload: a schema version
/// and zero or more native, still entirely untrusted, proposals. Successful
/// parsing establishes only that the payload conforms to the V1.1 wire
/// contract structurally -- it grants the resulting proposals no semantic
/// authority whatsoever. Every one of them must still pass through
/// `IntelligenceSafetyAuthority` before it can affect any transcript text.
struct ParsedIntelligenceProposalBatch: Equatable {
    let schemaVersion: Int
    let proposals: [IntelligenceProposal]
}

/// Converts an untrusted, provider-independent JSON payload into native
/// `IntelligenceProposal` values, or a deterministic typed failure. Never
/// binds to any specific provider's response envelope (OpenAI tool calls,
/// Ollama, LM Studio, ...) -- provider-specific extraction of this JSON
/// payload from a real response is later, separate work; this type only
/// ever sees the raw proposal-batch JSON itself.
///
/// Whole-response failure semantics: structural parsing is all-or-nothing.
/// One structurally malformed proposal invalidates the entire payload --
/// this is intentionally different from `IntelligenceSafetyAuthority`,
/// where a structurally valid proposal's *semantic* disposition is decided
/// independently of its siblings. "Structurally valid" and "semantically
/// safe" are different questions answered by different, non-overlapping
/// authorities; this parser answers only the first one.
enum IntelligenceProposalTransportParser {
    private static let supportedSchemaVersions: Set<Int> = [1]
    private static let knownRootKeys: Set<String> = ["schemaVersion", "proposals"]
    private static let knownProposalKeys: Set<String> = [
        "id", "rangeStart", "rangeLength", "expectedSourceText", "replacementText", "claimedCategory",
    ]
    private static let requiredProposalKeys = ["id", "rangeStart", "rangeLength", "expectedSourceText", "replacementText", "claimedCategory"]

    static func parse(_ data: Data) throws -> ParsedIntelligenceProposalBatch {
        guard data.count <= IntelligenceProposalTransportLimits.maxPayloadBytes else {
            throw IntelligenceProposalParseFailure.payloadTooLarge
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw IntelligenceProposalParseFailure.invalidEncoding
        }
        guard let rootStart = text.firstIndex(where: { !$0.isWhitespace }) else {
            throw IntelligenceProposalParseFailure.invalidRootStructure
        }

        let (rootEntries, rootEnd) = try self.scanObjectMappingErrors(text, start: rootStart, onMalformed: .invalidRootStructure)
        guard text[rootEnd...].allSatisfy(\.isWhitespace) else {
            throw IntelligenceProposalParseFailure.invalidRootStructure
        }

        var rootByKey: [String: Substring] = [:]
        for entry in rootEntries {
            guard self.knownRootKeys.contains(entry.key) else {
                throw IntelligenceProposalParseFailure.unknownField(entry.key)
            }
            rootByKey[entry.key] = entry.value
        }

        guard let schemaVersionValue = rootByKey["schemaVersion"] else {
            throw IntelligenceProposalParseFailure.missingField("schemaVersion")
        }
        guard let schemaVersion = self.strictIntegerLiteral(schemaVersionValue) else {
            throw IntelligenceProposalParseFailure.invalidFieldType("schemaVersion")
        }
        guard self.supportedSchemaVersions.contains(schemaVersion) else {
            throw IntelligenceProposalParseFailure.unsupportedSchemaVersion
        }

        guard let proposalsValue = rootByKey["proposals"] else {
            throw IntelligenceProposalParseFailure.missingField("proposals")
        }
        guard !proposalsValue.isEmpty else {
            throw IntelligenceProposalParseFailure.invalidFieldType("proposals")
        }
        let (elements, _) = try self.scanArrayMappingErrors(text, start: proposalsValue.startIndex)

        guard elements.count <= IntelligenceProposalTransportLimits.maxProposalCount else {
            throw IntelligenceProposalParseFailure.proposalCountExceeded
        }

        var proposals: [IntelligenceProposal] = []
        var seenIDs = Set<String>()
        var aggregateTextLength = 0

        for element in elements {
            guard !element.isEmpty else {
                throw IntelligenceProposalParseFailure.invalidFieldType("proposals")
            }
            let (proposalEntries, _) = try self.scanObjectMappingErrors(text, start: element.startIndex, onMalformed: .invalidFieldType("proposals"))

            var byKey: [String: Substring] = [:]
            for entry in proposalEntries {
                guard self.knownProposalKeys.contains(entry.key) else {
                    throw IntelligenceProposalParseFailure.unknownField(entry.key)
                }
                byKey[entry.key] = entry.value
            }
            for required in self.requiredProposalKeys where byKey[required] == nil {
                throw IntelligenceProposalParseFailure.missingField(required)
            }

            guard let rangeStart = self.strictIntegerLiteral(byKey["rangeStart"] ?? ""),
                  let rangeLength = self.strictIntegerLiteral(byKey["rangeLength"] ?? "")
            else {
                throw IntelligenceProposalParseFailure.invalidRange
            }
            guard
                rangeStart >= 0, rangeLength >= 0,
                rangeStart <= IntelligenceProposalTransportLimits.maxRangeValue,
                rangeLength <= IntelligenceProposalTransportLimits.maxRangeValue
            else {
                throw IntelligenceProposalParseFailure.invalidRange
            }

            let strings = try self.decodeStrings(String(element))

            guard !strings.id.isEmpty else {
                throw IntelligenceProposalParseFailure.emptyID
            }
            guard strings.id.utf16.count <= IntelligenceProposalTransportLimits.maxIDLength else {
                throw IntelligenceProposalParseFailure.fieldLengthExceeded("id")
            }
            guard strings.expectedSourceText.utf16.count <= IntelligenceProposalTransportLimits.maxExpectedSourceTextLength else {
                throw IntelligenceProposalParseFailure.fieldLengthExceeded("expectedSourceText")
            }
            guard strings.replacementText.utf16.count <= IntelligenceProposalTransportLimits.maxReplacementTextLength else {
                throw IntelligenceProposalParseFailure.fieldLengthExceeded("replacementText")
            }
            guard let category = IntelligenceEditCategory(rawValue: strings.claimedCategory) else {
                throw IntelligenceProposalParseFailure.unsupportedCategory
            }
            guard seenIDs.insert(strings.id).inserted else {
                throw IntelligenceProposalParseFailure.duplicateProposalID
            }

            aggregateTextLength += strings.id.utf16.count + strings.expectedSourceText.utf16.count + strings.replacementText.utf16.count
            guard aggregateTextLength <= IntelligenceProposalTransportLimits.maxAggregateDecodedTextLength else {
                throw IntelligenceProposalParseFailure.aggregateTextLimitExceeded
            }

            // Preserved exactly: no trimming, Unicode normalization,
            // punctuation/casing correction, or inference of missing
            // values. This parser is a transport boundary, not a
            // transcript processor.
            proposals.append(
                IntelligenceProposal(
                    id: strings.id,
                    range: NSRange(location: rangeStart, length: rangeLength),
                    expectedSourceText: strings.expectedSourceText,
                    replacementText: strings.replacementText,
                    claimedCategory: category
                )
            )
        }

        return ParsedIntelligenceProposalBatch(schemaVersion: schemaVersion, proposals: proposals)
    }

    // MARK: - String-field decoding (delegated to JSONDecoder deliberately)

    /// Only the four string-valued fields are decoded via `JSONDecoder` --
    /// unlike numeric fields, ordinary `Decodable` `String` decoding has no
    /// analogous silent-coercion hazard (a JSON number/bool/null never
    /// satisfies a `String`-typed field), so leaning on `JSONDecoder` here
    /// correctly handles JSON string escaping without reimplementing it.
    /// Any additional keys present in the object (`rangeStart`, `rangeLength`,
    /// ...) are simply not requested by this struct and are ignored by
    /// `Decodable`, which is safe here because duplicate/unknown *keys* were
    /// already ruled out by `scanObjectMappingErrors` before this is called.
    private struct WireStrings: Decodable {
        let id: String
        let expectedSourceText: String
        let replacementText: String
        let claimedCategory: String
    }

    private static func decodeStrings(_ objectText: String) throws -> WireStrings {
        guard let data = objectText.data(using: .utf8) else {
            throw IntelligenceProposalParseFailure.invalidEncoding
        }
        do {
            return try JSONDecoder().decode(WireStrings.self, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw IntelligenceProposalParseFailure.missingField(key.stringValue)
        } catch let DecodingError.typeMismatch(_, context) {
            throw IntelligenceProposalParseFailure.invalidFieldType(context.codingPath.last?.stringValue ?? "proposal")
        } catch let DecodingError.valueNotFound(_, context) {
            throw IntelligenceProposalParseFailure.invalidFieldType(context.codingPath.last?.stringValue ?? "proposal")
        } catch {
            throw IntelligenceProposalParseFailure.invalidFieldType("proposal")
        }
    }

    // MARK: - Raw-scanner error mapping

    private static func scanObjectMappingErrors(
        _ text: String,
        start: String.Index,
        onMalformed: IntelligenceProposalParseFailure
    ) throws -> (entries: [RawJSONObjectKeyScanner.Entry], end: String.Index) {
        do {
            return try RawJSONObjectKeyScanner.scanObject(text, start: start)
        } catch let error as RawJSONObjectKeyScanner.ScanError {
            switch error.kind {
            case .malformedStructure:
                throw onMalformed
            case let .duplicateKey(key):
                throw IntelligenceProposalParseFailure.duplicateKey(key)
            }
        }
    }

    private static func scanArrayMappingErrors(
        _ text: String,
        start: String.Index
    ) throws -> (elements: [Substring], end: String.Index) {
        do {
            return try RawJSONObjectKeyScanner.scanArrayElements(text, start: start)
        } catch let error as RawJSONObjectKeyScanner.ScanError {
            switch error.kind {
            case .malformedStructure:
                throw IntelligenceProposalParseFailure.invalidFieldType("proposals")
            case let .duplicateKey(key):
                throw IntelligenceProposalParseFailure.duplicateKey(key)
            }
        }
    }

    // MARK: - Strict numeric parsing

    /// Parses a raw JSON numeric-value substring as a strict integer
    /// literal -- optional leading `-`, then one or more ASCII digits, and
    /// nothing else. Deliberately does not delegate to `JSONDecoder`/`Int`
    /// decoding: verified empirically that `JSONDecoder` silently accepts a
    /// whole-number float (e.g. `1.0`) into an `Int`-typed field, which this
    /// transport contract must not allow for schema-version/range fields --
    /// this check rejects it, along with quoted numeric strings and any
    /// other non-integer representation, before any value is trusted.
    private static func strictIntegerLiteral(_ substring: Substring) -> Int? {
        let trimmed = substring.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var digitsOnly = Substring(trimmed)
        if digitsOnly.first == "-" {
            digitsOnly = digitsOnly.dropFirst()
        }
        guard !digitsOnly.isEmpty, digitsOnly.allSatisfy(\.isNumber) else { return nil }
        return Int(trimmed)
    }
}
