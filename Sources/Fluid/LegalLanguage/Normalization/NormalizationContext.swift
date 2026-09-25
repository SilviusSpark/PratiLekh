import Foundation

/// The minimal context a normalizer may need. Table-driven normalizers
/// (`LookupTableNormalizer`) read `resolvedTable`; structured, pattern-based
/// normalizers (Phase 3) read `resolvedRecognitionVocabulary` when they need
/// to recognize an already-approved concept (e.g. a statute name) rather
/// than inventing a second vocabulary. Both fields are optional, and nil is
/// a valid, common state for a normalizer that doesn't need that input --
/// this is deliberately not a place for speculative future fields (locale,
/// court metadata, user preferences, ...); add a field only when a concrete
/// normalizer needs it.
struct NormalizationContext: Equatable {
    let resolvedTable: ResolvedNormalizationTable?
    let resolvedRecognitionVocabulary: ResolvedRecognitionVocabulary?
}
