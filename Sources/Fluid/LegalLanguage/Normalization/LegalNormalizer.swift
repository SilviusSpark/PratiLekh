import Foundation

/// `range` is nil for Phase 1/2's trigger-based table lookups (a trigger
/// string has no meaningful single "location" beyond its own text) and
/// populated for Phase 3's span-aware structured rules. When present it is
/// an NSRange into the *input text of the pass that produced the change*
/// (not the post-replacement text, and not the original recognizer output
/// if an earlier normalizer in the pipeline already rewrote it). `sourcePackID` is
/// reused loosely by Phase 3 to mean "which rule family produced this,"
/// not literally a pack id -- both systems answer the same question
/// ("where did this change come from"), so no additional field was added.
struct AppliedNormalizationChange: Equatable {
    let trigger: String
    let replacement: String
    let sourcePackID: String
    let range: NSRange?

    init(trigger: String, replacement: String, sourcePackID: String, range: NSRange? = nil) {
        self.trigger = trigger
        self.replacement = replacement
        self.sourcePackID = sourcePackID
        self.range = range
    }
}

struct DeclinedNormalization: Equatable {
    let trigger: String
    let candidates: [NormalizationCandidate]
    let reason: String
    /// The candidate source span that was examined and preserved, in the
    /// input text of the producing pass; nil when no reliable span exists.
    let range: NSRange?

    init(trigger: String, candidates: [NormalizationCandidate], reason: String, range: NSRange? = nil) {
        self.trigger = trigger
        self.candidates = candidates
        self.reason = reason
        self.range = range
    }
}

/// A minimal, typed decline-reason vocabulary for Phase 3's structured
/// rules. Deliberately small: no elaborate diagnostics framework, just
/// enough to distinguish the three genuinely different situations a
/// structured rule can report.
enum DeclineReason: String, Equatable {
    /// A required value (a number, a witness index, ...) could not be
    /// parsed at all -- malformed or incomplete dictation.
    case unclearValue
    /// A value was present but expressed with uncertainty or as one of
    /// several competing candidates (a hedge, a self-correction) directly
    /// attached to the candidate itself.
    case unresolvedUncertainty
    /// The text matches a recognized legal-reference *shape* that Phase 3C
    /// does not (yet) support -- e.g. "read with", sub-sections, a section
    /// range, or an ambiguous compound reference. Distinct from "no
    /// candidate detected": the rule recognized *something*, just not a
    /// supported structure.
    case unsupportedStructure
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

/// The pure, testable normalization boundary. Phase 1 provides one
/// table-driven conformance (`LookupTableNormalizer`); Phase 3 adds
/// structured, pattern-based conformances (`StatutoryProvisionNormalizer`,
/// `WitnessReferenceNormalizer`) composed in the same sequence by
/// `LegalNormalizationPipeline`. The `NormalizationContext` parameter is the
/// Phase 3A-approved generalization away from requiring a
/// `ResolvedNormalizationTable` directly -- a pattern-based rule simply
/// ignores the fields it doesn't need.
protocol LegalNormalizer {
    func normalize(_ text: String, using context: NormalizationContext) -> NormalizationPassResult
}
