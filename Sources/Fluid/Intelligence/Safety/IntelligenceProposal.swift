import Foundation

/// One untrusted, model-proposed edit to `legalNormalized`. Every field is
/// taken at face value from an untrusted source -- a local model in a future
/// milestone, or (in this model-free milestone) a test constructing one
/// directly -- and nothing here is trusted until `IntelligenceSafetyAuthority`
/// independently re-derives what the edit actually does. In particular
/// `claimedCategory` grants no permission by itself; see
/// `IntelligenceEditClassifier`.
///
/// Deliberately excludes speculative audio-model evidence fields (an audio
/// time range, acoustic confidence, alignment evidence, candidate
/// alternatives, ...) and model confidence/rationale, per the committed
/// Text-Only Intelligence Baseline: those belong to a future milestone, only
/// after an actual audio/recognition evidence source or model-output parser
/// exists to consume them -- see CLAUDE.md's "PratiLekh Intelligence
/// architecture" section.
struct IntelligenceProposal: Equatable {
    /// Model-supplied, for correlation/logging only -- never assumed unique
    /// and never used to grant or deny permission. Two proposals may share
    /// an `id`; the authority treats each purely by its own content.
    let id: String
    /// UTF-16 offset into the immutable source, matching this repository's
    /// existing `NSRange` convention (see `AppliedNormalizationChange.range`,
    /// `WordToken.range`). A zero-length range represents a pure insertion.
    let range: NSRange
    /// The text the proposal claims exists at `range` in the source. Matched
    /// exactly against the real source -- never fuzzily realigned. A
    /// mismatch (a stale or shifted proposal) is always a rejection.
    let expectedSourceText: String
    /// The text that would replace `expectedSourceText` if this proposal is
    /// autonomously accepted.
    let replacementText: String
    /// The model's own claim about what kind of edit this is. Diagnostic
    /// metadata only -- the authority always independently re-derives the
    /// actual edit category from `expectedSourceText`/`replacementText` and
    /// never trusts this value.
    let claimedCategory: IntelligenceEditCategory
}

/// The model's own claim about its proposal's edit category. Never trusted
/// for permission -- see `IntelligenceProposal.claimedCategory`. `.other`
/// covers any claim outside the V1 surface taxonomy; it is never
/// autonomously eligible regardless of what is claimed.
enum IntelligenceEditCategory: String, Equatable {
    case punctuation
    case capitalization
    case whitespace
    case other
}
