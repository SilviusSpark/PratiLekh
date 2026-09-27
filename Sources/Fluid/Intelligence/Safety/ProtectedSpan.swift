import Foundation

/// A source-text region carrying one of three *conceptually distinct*
/// protection levels, per the committed Text-Only Intelligence Baseline
/// (see CLAUDE.md's "PratiLekh Intelligence architecture" section,
/// "Protected spans"). The three are never collapsed into each other -- in
/// particular a `.deterministicallyUnresolved` span (e.g. what a
/// `DeclinedNormalization` would represent) is never treated as though it
/// were `.deterministicallyResolved` (what an `AppliedNormalizationChange`
/// would represent): a decline means "PratiLekh does not know," not
/// "PratiLekh has decided."
///
/// This milestone implements only the representation and the
/// `IntelligenceSafetyAuthority` semantics that consume it. Mapping real
/// `NormalizationOutcome` provenance -- or any future heuristic detector for
/// dates/amounts/case numbers/exhibits/names, none of which has an existing
/// recognizer -- into `ProtectedSpan` values is explicitly out of scope
/// here; tests construct spans directly.
struct ProtectedSpan: Equatable {
    /// UTF-16 offset into the immutable source, matching this repository's
    /// existing `NSRange` convention.
    let range: NSRange
    let kind: ProtectedSpanKind
}

/// The three protection tiers named by the committed Text-Only Intelligence
/// Baseline. `.deterministicallyUnresolved` and `.independentlyProtected`
/// currently produce the same `ProposalDisposition` restriction (autonomous
/// application forbidden; review-only permitted) -- see
/// `IntelligenceSafetyAuthority` -- but are kept as separate cases because
/// the committed design distinguishes them conceptually, and because a
/// future milestone may need to treat them differently once a real
/// `.independentlyProtected` detector exists.
enum ProtectedSpanKind: Equatable {
    /// A deterministic PratiLekh transformation positively established a
    /// result here. No proposal may target this span at all -- not
    /// autonomous, not review-only.
    case deterministicallyResolved
    /// PratiLekh recognized something potentially significant here but
    /// declined to transform it because evidence was insufficient. This is
    /// *not* a resolved fact: a review-only proposal may discuss this span,
    /// but autonomous application is always forbidden.
    case deterministicallyUnresolved
    /// Legally consequential material with no existing deterministic
    /// recognizer at all (dates, amounts, case numbers, exhibits, names,
    /// ...). Review-only proposals are permitted; autonomous application is
    /// always forbidden.
    case independentlyProtected
}
