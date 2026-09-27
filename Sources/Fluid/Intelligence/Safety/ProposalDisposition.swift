import Foundation

/// `IntelligenceSafetyAuthority`'s final, deterministic decision for one
/// proposal. Every rejection and every review-only disposition carries a
/// machine-readable reason -- tests assert the reason, never merely that a
/// proposal was or was not applied.
enum ProposalDisposition: Equatable {
    /// Safe to apply without human review: an independently-derived
    /// punctuation-only/capitalization-only/whitespace-only edit, entirely
    /// outside any protected span, and not in conflict with any other
    /// proposal in the same batch.
    case autonomouslyAccepted(IntelligenceEditClassification)
    /// Structurally and semantically valid, but not safe to apply
    /// autonomously -- it intersects a `.deterministicallyUnresolved` or
    /// `.independentlyProtected` span. A future milestone may surface this
    /// to a human reviewer; this milestone only represents the disposition,
    /// since no reviewer UI exists yet, and never applies it.
    case reviewOnly(ReviewReason)
    /// Rejected outright -- never applied, never surfaced for review.
    case rejected(ProposalRejectionReason)
}

enum ReviewReason: Equatable {
    case intersectsUnresolvedSpan
    case intersectsIndependentlyProtectedSpan
}

/// Every reason a proposal can be rejected outright, in roughly the order
/// `IntelligenceSafetyAuthority` evaluates them (see its own documentation
/// for the exact, explicit pipeline order -- this enum does not itself
/// encode ordering).
enum ProposalRejectionReason: Equatable {
    /// `range` is negative, or extends beyond the immutable source's UTF-16
    /// length. Detected before any range/string conversion is attempted, so
    /// an adversarial huge or negative value can never reach arithmetic
    /// that could overflow.
    case invalidRange
    /// `range` could not be converted to a `String.Index` range in the
    /// source at all. Kept as a defensive rejection path -- empirically,
    /// Foundation's `Range(_:in:)` tends to round a range that splits a
    /// UTF-16 surrogate pair to the nearest valid boundary rather than
    /// failing outright, so that adversarial case is more commonly caught
    /// as `.sourceTextMismatch` once the rounded text is compared against
    /// `expectedSourceText` (see `IntelligenceSafetyAuthorityTests`). Either
    /// way, no proposal ever reaches an unsafe String subscript.
    case rangeConversionFailed
    /// The text actually at `range` in the immutable source does not equal
    /// `expectedSourceText` -- a stale or shifted proposal. Never relocated
    /// by searching the source for a better match.
    case sourceTextMismatch
    /// `expectedSourceText == replacementText` -- a proposal asserting an
    /// edit that changes nothing.
    case noOpProposal
    /// This proposal's range intersects another proposal's range in the
    /// same batch (including an identical range, a nested range, a range
    /// with a conflicting replacement, or two insertions at the exact same
    /// point). Adjacent, merely-touching ranges are not this reason -- see
    /// `IntelligenceSafetyAuthority`'s intersection predicate.
    case overlapsAnotherProposal
    /// The edit's range intersects a `.deterministicallyResolved` protected
    /// span -- forbidden outright, not even review-only, regardless of
    /// what the edit would otherwise classify as.
    case intersectsResolvedSpan
    /// The independently-derived edit classification is `.other` -- not one
    /// of V1's autonomous categories -- regardless of what the proposal
    /// claimed and regardless of whether it intersects any protected span.
    case unsupportedEditCategory
}
