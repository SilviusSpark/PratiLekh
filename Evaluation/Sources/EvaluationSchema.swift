import Foundation

// Reference definitions for the judicial dictation evaluation.
//
// Governing principle: the reference is what the judge DICTATED, not what an
// evaluator or model thinks the judge intended. Nothing here rewards a
// "legally better" provision, statute, fact, date, amount or identifier.
// (Complements the normalization principle: format what was dictated; never
// complete what was not dictated.)

enum CriticalTokenType: String, Codable, CaseIterable {
    case statute, provision, witness, negation, date, amount, caseIdentifier
}

/// A legally significant token that must be exactly right. `expected` is the
/// canonical written form; `spokenForms` are the dictated (non-canonical)
/// spellings that show the right words were recognized but not yet normalized.
struct CriticalToken: Codable, Equatable {
    let type: CriticalTokenType
    let expected: String
    let spokenForms: [String]

    init(type: CriticalTokenType, expected: String, spokenForms: [String] = []) {
        self.type = type
        self.expected = expected
        self.spokenForms = spokenForms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(CriticalTokenType.self, forKey: .type)
        self.expected = try container.decode(String.self, forKey: .expected)
        self.spokenForms = try container.decodeIfPresent([String].self, forKey: .spokenForms) ?? []
    }
}

/// What deterministic legal normalization is expected to do with one span of
/// the post-ASR text.
struct LegalExpectation: Codable, Equatable {
    enum Kind: String, Codable {
        /// The span must be rewritten to exactly `replacement`.
        case apply
        /// The span is a recognized-but-unsupported or ambiguous structure and must be preserved.
        case decline
        /// Nothing in the sample is a normalization candidate; text must be untouched.
        case noCandidate
    }

    let kind: Kind
    let source: String?
    let replacement: String?
}

struct EvaluationReference: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: String
    /// "synthetic" (invented, may live in Git) or "private" (never in Git).
    let tier: String
    let category: String
    let tags: [String]
    /// The words as dictated. WER/CER of the post-ASR stage is measured against this.
    let reference: String
    /// Text expected after approved deterministic formatting, when it differs from
    /// `reference` only for that reason. Later stages are measured against it.
    let intendedFinal: String?
    let criticalTokens: [CriticalToken]
    let legalExpectations: [LegalExpectation]
    let notes: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.id = try container.decode(String.self, forKey: .id)
        self.tier = try container.decode(String.self, forKey: .tier)
        self.category = try container.decode(String.self, forKey: .category)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.reference = try container.decode(String.self, forKey: .reference)
        self.intendedFinal = try container.decodeIfPresent(String.self, forKey: .intendedFinal)
        self.criticalTokens = try container.decodeIfPresent([CriticalToken].self, forKey: .criticalTokens) ?? []
        self.legalExpectations = try container.decode([LegalExpectation].self, forKey: .legalExpectations)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    init(
        id: String, tier: String = "synthetic", category: String, tags: [String] = [], reference: String,
        intendedFinal: String? = nil, criticalTokens: [CriticalToken] = [], legalExpectations: [LegalExpectation],
        notes: String? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.tier = tier
        self.category = category
        self.tags = tags
        self.reference = reference
        self.intendedFinal = intendedFinal
        self.criticalTokens = criticalTokens
        self.legalExpectations = legalExpectations
        self.notes = notes
    }

    /// Structural validation. Returns human-readable problems; empty means valid.
    func validate() -> [String] {
        var problems: [String] = []
        if self.schemaVersion != Self.currentSchemaVersion {
            problems.append("unsupported schemaVersion \(self.schemaVersion)")
        }
        if self.id.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) == nil {
            problems.append("id must match [A-Za-z0-9._-]+")
        }
        if !["synthetic", "private"].contains(self.tier) { problems.append("tier must be 'synthetic' or 'private'") }
        if self.category.isEmpty { problems.append("category is required") }
        if self.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("reference is empty") }
        if self.legalExpectations.isEmpty {
            problems.append("legalExpectations must be explicit (use a single noCandidate entry for ordinary text)")
        }
        for token in self.criticalTokens where token.expected.isEmpty {
            problems.append("critical token of type \(token.type.rawValue) has an empty expected value")
        }
        let hasNoCandidate = self.legalExpectations.contains { $0.kind == .noCandidate }
        if hasNoCandidate && self.legalExpectations.count > 1 {
            problems.append("noCandidate cannot be combined with other expectations")
        }
        for (index, expectation) in self.legalExpectations.enumerated() {
            switch expectation.kind {
            case .apply:
                if expectation.source?.isEmpty ?? true || expectation.replacement?.isEmpty ?? true {
                    problems.append("legalExpectations[\(index)] apply needs source and replacement")
                }
            case .decline:
                if expectation.source?.isEmpty ?? true { problems.append("legalExpectations[\(index)] decline needs source") }
                if expectation.replacement != nil { problems.append("legalExpectations[\(index)] decline must not carry a replacement") }
            case .noCandidate:
                if expectation.source != nil || expectation.replacement != nil {
                    problems.append("legalExpectations[\(index)] noCandidate must not carry source or replacement")
                }
            }
            if let source = expectation.source, !source.isEmpty,
               self.reference.range(of: source, options: .caseInsensitive) == nil
            {
                problems.append("legalExpectations[\(index)] source '\(source)' does not occur in the dictated reference")
            }
        }
        return problems
    }

    static func load(from url: URL) throws -> EvaluationReference {
        try JSONDecoder().decode(EvaluationReference.self, from: Data(contentsOf: url))
    }
}
