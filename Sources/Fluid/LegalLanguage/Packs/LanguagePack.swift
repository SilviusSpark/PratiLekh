import Foundation

/// Where a pack's authority comes from. Precedence between kinds is defined in
/// `PrecedenceResolver`, not here -- this type only labels provenance.
enum PackKind: String, Codable, Equatable {
    case builtin
    case jurisdiction
    case user
}

/// A single recognition hint: a canonical legal term plus the spoken variants an
/// ASR engine might mishear it as. Carries no provider-specific shape -- see
/// `Recognition/` for how this gets adapted to a given engine.
struct RecognitionEntry: Codable, Equatable {
    let canonical: String
    let aliases: [String]
}

/// A single deterministic normalization rule in its simplest form: an exact
/// trigger substring and the canonical replacement it should become. This is
/// the Phase 1 data shape; Phase 3's pattern-based rules (statutes, dates,
/// case numbers) are a separate, later extension of the normalization boundary,
/// not an extension of this entry type.
struct NormalizationEntry: Codable, Equatable {
    let trigger: String
    let canonicalReplacement: String
}

/// A versioned, independently loadable/replaceable bundle of legal-language
/// resources. A pack is a unit of trust and updateability: replacing the
/// built-in Indian Legal Core pack with a new version must never touch a
/// jurisdiction pack or the user's own pack.
struct LanguagePack: Codable, Equatable {
    let id: String
    let version: String
    let kind: PackKind
    let displayName: String
    let recognitionEntries: [RecognitionEntry]
    let normalizationEntries: [NormalizationEntry]
}
