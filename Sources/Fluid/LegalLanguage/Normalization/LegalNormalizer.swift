import Foundation

struct AppliedNormalizationChange: Equatable {
    let trigger: String
    let replacement: String
    let sourcePackID: String
}

struct DeclinedNormalization: Equatable {
    let trigger: String
    let candidates: [NormalizationCandidate]
    let reason: String
}

/// The result of one normalizer's pass over the current text.
///
/// Together, this type's possible states are exactly the three concepts a
/// normalization result must distinguish:
///   - unchanged: `appliedChanges` and `declinedChanges` are both empty --
///     this normalizer found nothing in its domain applicable to the text.
///   - applied: one or more entries in `appliedChanges` -- a deterministic
///     transformation was performed.
///   - declined: one or more entries in `declinedChanges` -- a potentially
///     applicable transformation was found but not performed, because it
///     could not be done safely/deterministically (see
///     `NormalizationResolution.conflicted`).
///
/// A single pass may legitimately contain both applied and declined entries:
/// an unrelated conflict must never block an otherwise-safe transformation
/// elsewhere in the same text. (A separate `NormalizerVerdict`-style enum
/// duplicating `.resolved`/`.conflicted` at the same per-entry granularity
/// was deliberately not added here -- `NormalizationResolution` already is
/// that distinction; see the Phase 1 hardening report.)
struct NormalizationPassResult: Equatable {
    let text: String
    let appliedChanges: [AppliedNormalizationChange]
    let declinedChanges: [DeclinedNormalization]

    var isUnchanged: Bool {
        appliedChanges.isEmpty && declinedChanges.isEmpty
    }
}

/// The pure, testable normalization boundary. Phase 1 provides exactly one
/// conformance (`LookupTableNormalizer`). Phase 3's statute/date/case-number
/// rules are additional conformances composed in sequence by
/// `LegalNormalizationPipeline` -- this protocol does not need to change for
/// that to work.
protocol LegalNormalizer {
    func normalize(_ text: String, using table: ResolvedNormalizationTable) -> NormalizationPassResult
}
