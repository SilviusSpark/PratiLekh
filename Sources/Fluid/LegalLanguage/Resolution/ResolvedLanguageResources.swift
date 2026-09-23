import Foundation

// MARK: - Recognition (merge, no conflict concept)
//
// Recognition entries are hints, not value-producing mappings: two packs
// contributing aliases for the same canonical term is never ambiguous, only
// additive. So recognition resolution is a pure union/merge -- there is no
// recognition equivalent of `NormalizationResolution.conflicted` below.

struct ResolvedRecognitionEntry: Equatable {
    let canonical: String
    let aliases: [String]
    let sourcePackIDs: [String]
}

struct ResolvedRecognitionVocabulary: Equatable {
    /// Ordered by precedence: entries first contributed by higher-precedence
    /// packs appear first. Consumers that must truncate (see `Recognition/`)
    /// should do so from the end of this list, not by inventing their own
    /// priority scheme.
    let entries: [ResolvedRecognitionEntry]
}

// MARK: - Normalization (precedence + conflict detection)
//
// Unlike recognition, a normalization entry produces a specific replacement
// value. Two packs at the same precedence rank disagreeing about that value
// is a genuine ambiguity and must not be silently resolved.

struct NormalizationCandidate: Equatable {
    let sourcePackID: String
    let replacement: String
}

enum NormalizationResolution: Equatable {
    case resolved(replacement: String, sourcePackID: String)
    case conflicted(candidates: [NormalizationCandidate])
}

struct ResolvedNormalizationEntry: Equatable {
    let trigger: String
    let resolution: NormalizationResolution
}

struct ResolvedNormalizationTable: Equatable {
    let entries: [ResolvedNormalizationEntry]

    func resolution(forTrigger trigger: String) -> NormalizationResolution? {
        entries.first { $0.trigger == trigger }?.resolution
    }
}

/// A same-rank, different-value collision surfaced for diagnostics. Phase 1
/// builds no UI or logging consumer for this -- it exists so the resolver's
/// "do not silently choose a winner" behavior is inspectable and testable.
struct PackConflict: Equatable {
    let key: String
    let candidates: [NormalizationCandidate]
}

extension ResolvedNormalizationTable {
    var conflicts: [PackConflict] {
        entries.compactMap { entry in
            guard case let .conflicted(candidates) = entry.resolution else { return nil }
            return PackConflict(key: entry.trigger, candidates: candidates)
        }
    }
}
