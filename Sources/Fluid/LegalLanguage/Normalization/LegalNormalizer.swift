import Foundation

/// Which normalizer produced a provenance record. A typed identity, never
/// inferred from `sourcePackID` (a free-form string, "reused loosely" as a
/// rule-family label) or from a decline's reason text. Each normalizer
/// stamps every record it emits with its own `passID`.
enum NormalizationPassID: String, Equatable {
    case lookupTable
    case statutoryProvision
    case witnessReference
}

// MARK: - Provenance coordinate contract
//
// Both record types below share one coordinate contract (established by the
// V1.9 investigation, made explicit and complete in V1.10):
//
//   * `range` is always an explicit UTF-16 `NSRange` (NSString offsets).
//   * A record's coordinate space is identified by `(pass, step)`: `range`
//     indexes the exact text that was the INPUT of that step -- the text
//     immediately BEFORE the step's changes -- never the step's output, and
//     never any other pass's or the final text.
//   * `trigger` is exactly the text at `range` in that input space.
//   * A *pass* is one normalizer's run over the text left by the previous
//     pass. Passes run in `NormalizationOutcome.passes` order.
//   * A pass consists of one or more sequential *steps*, numbered by `step`
//     (ascending). All of a step's records index that step's own input, and
//     the step's changes do not overlap. `StatutoryProvisionNormalizer` and
//     `WitnessReferenceNormalizer` are single-step passes (`step == 0`).
//     `LookupTableNormalizer` runs one step per resolved-table entry, in table
//     order, each against the text left by the previous entry (so `step` is
//     the entry's index in the table).
//   * A step transforms its input into its output by replacing each applied
//     record's `range` with its `replacement`; declined records mark spans
//     that were examined and preserved (they do not change the text).
//
// Together with `NormalizationOutcome.recognized` and `.passes`, this makes
// every intermediate text -- and the final `normalized` text --
// deterministically reconstructable from provenance alone (see
// `NormalizationReplay`), so no intermediate text needs to be stored.

/// A deterministic transformation that was performed.
///
/// `sourcePackID` keeps its historical meaning ("where did this change come
/// from": a pack id for lookup replacements, a rule-family label for Phase 3
/// rules) and is NOT used to identify the producing pass -- see `pass`.
struct AppliedNormalizationChange: Equatable {
    /// Exactly the text at `range` in this step's input space.
    let trigger: String
    let replacement: String
    let sourcePackID: String
    let pass: NormalizationPassID
    /// Index of the sequential step within `pass` (0 for single-step passes).
    let step: Int
    /// UTF-16 range of `trigger` in this step's input space (pre-change).
    let range: NSRange

    init(trigger: String, replacement: String, sourcePackID: String, pass: NormalizationPassID, step: Int = 0, range: NSRange) {
        self.trigger = trigger
        self.replacement = replacement
        self.sourcePackID = sourcePackID
        self.pass = pass
        self.step = step
        self.range = range
    }
}

/// A potentially applicable transformation that was found but deliberately
/// not performed; the examined text is preserved unchanged.
struct DeclinedNormalization: Equatable {
    /// Exactly the text at `range` in this step's input space.
    let trigger: String
    let candidates: [NormalizationCandidate]
    let reason: String
    let pass: NormalizationPassID
    /// Index of the sequential step within `pass` (0 for single-step passes).
    let step: Int
    /// UTF-16 range of the examined and preserved span in this step's input
    /// space (pre-change).
    let range: NSRange

    init(trigger: String, candidates: [NormalizationCandidate], reason: String, pass: NormalizationPassID, step: Int = 0, range: NSRange) {
        self.trigger = trigger
        self.candidates = candidates
        self.reason = reason
        self.pass = pass
        self.step = step
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
    /// The typed identity stamped on every record this normalizer emits, and
    /// recorded (in run order) in `NormalizationOutcome.passes`. Must be
    /// unique among the normalizers of one pipeline run.
    var passID: NormalizationPassID { get }
    func normalize(_ text: String, using context: NormalizationContext) -> NormalizationPassResult
}
