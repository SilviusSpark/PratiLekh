import Foundation

// EXPERIMENTAL -- Intelligence V1.4C architecture investigation only.
// Refines V1.4B's broad Policy P3 ("discriminator fallback") into a
// precise, exhaustive decision table. Does not modify
// `V1_4B_PolicyExperiments.swift` -- that file's P1/P2/P3 remain intact as
// the V1.4B record. This file supersedes P3 for V1.4C's adversarial
// validation, addressing two ambiguities V1.4B's P3 left implicit:
//
// 1. V1.4B's P3, when occurrence is explicitly supplied and WRONG on an
//    otherwise-unique source, silently resolved via the (absent) context
//    path -- because "context absent" and "context resolves via bare
//    sourceText" were not distinguished. V1.4C treats an explicitly wrong
//    occurrence as significant negative evidence: it is never silently
//    ignored merely because sourceText happens to be unique.
// 2. V1.4B's P3 did not distinguish "context independently fails to
//    narrow to any single location" (uninformative, not contradictory)
//    from "context independently narrows to a DIFFERENT single location
//    than occurrence" (a genuine contradiction). Both were folded into
//    "context = .failure" or "context = .success(different)". V1.4C makes
//    this distinction explicit, per the milestone's requirement not to
//    hide it.

/// Every distinct outcome the precise P3 decision table can produce,
/// named so a reader can understand the policy without reading the
/// implementation.
enum P3PreciseOutcome: Equatable, CustomStringConvertible {
    case resolvedUnambiguousSource                    // A1
    case resolvedOccurrenceAgreesWithUniqueSource      // A2
    case rejectedOccurrenceContradictsUnique          // A3
    case rejectedContextContradictsUnique             // A4
    case resolvedOccurrenceOnly                        // A5
    case rejectedInvalidOccurrenceNoContext             // A6
    case resolvedContextOnlyFallback                    // A7
    case rejectedAmbiguousContextOnly                    // A8
    case resolvedOccurrenceAndContextAgree               // A9
    case resolvedOccurrenceContextUninformative          // A10 (corroboration absent/insufficient, not contradictory)
    case resolvedContextFallback                          // A11
    case rejectedGenuineContradiction                    // A12 / A13 (consistent-but-wrong is NOT detectable here)
    case rejectedBothInvalid

    var description: String {
        switch self {
        case .resolvedUnambiguousSource: return "resolvedUnambiguousSource"
        case .resolvedOccurrenceAgreesWithUniqueSource: return "resolvedOccurrenceAgreesWithUniqueSource"
        case .rejectedOccurrenceContradictsUnique: return "rejectedOccurrenceContradictsUnique"
        case .rejectedContextContradictsUnique: return "rejectedContextContradictsUnique"
        case .resolvedOccurrenceOnly: return "resolvedOccurrenceOnly"
        case .rejectedInvalidOccurrenceNoContext: return "rejectedInvalidOccurrenceNoContext"
        case .resolvedContextOnlyFallback: return "resolvedContextOnlyFallback"
        case .rejectedAmbiguousContextOnly: return "rejectedAmbiguousContextOnly"
        case .resolvedOccurrenceAndContextAgree: return "resolvedOccurrenceAndContextAgree"
        case .resolvedOccurrenceContextUninformative: return "resolvedOccurrenceContextUninformative"
        case .resolvedContextFallback: return "resolvedContextFallback"
        case .rejectedGenuineContradiction: return "rejectedGenuineContradiction"
        case .rejectedBothInvalid: return "rejectedBothInvalid"
        }
    }
}

private func hasContext(_ reference: ModelFacingReference) -> Bool {
    if let l = reference.leftContext, !l.isEmpty { return true }
    if let r = reference.rightContext, !r.isEmpty { return true }
    return false
}

private func occurrenceOnlyRef(_ reference: ModelFacingReference) -> ModelFacingReference {
    var r = reference
    r.leftContext = nil
    r.rightContext = nil
    return r
}

private func contextOnlyRef(_ reference: ModelFacingReference) -> ModelFacingReference {
    var r = reference
    r.occurrence = nil
    return r
}

/// The precise, exhaustive P3 decision procedure. Returns both the named
/// outcome (for the decision table / test assertions) and the resolved
/// range when applicable.
func resolveP3Precise(_ reference: ModelFacingReference, in source: NSString) -> (outcome: P3PreciseOutcome, range: NSRange?) {
    guard let sourceText = reference.sourceText, !sourceText.isEmpty else {
        return (.rejectedBothInvalid, nil)
    }
    let allOccurrences = findExactOccurrences(of: sourceText, in: source)
    let isUnique = allOccurrences.count == 1
    let hasOcc = reference.occurrence != nil
    let hasCtx = hasContext(reference)

    // Bare sourceText resolution (no discriminators at all).
    if !hasOcc && !hasCtx {
        if isUnique { return (.resolvedUnambiguousSource, allOccurrences[0]) }
        return (.rejectedBothInvalid, nil) // repeated, nothing to disambiguate with
    }

    // Non-optional by construction: when a discriminator isn't supplied,
    // `occurrenceOnlyRef`/`contextOnlyRef` leave that field nil, and
    // `resolveReference` reports `.emptyReference`-adjacent failure --
    // callers below only interpret these results when `hasOcc`/`hasCtx`
    // is true, so an "unsupplied" result is never mistaken for a
    // meaningful failure.
    let occurrenceOutcome = resolveReference(occurrenceOnlyRef(reference), in: source)
    let contextOutcome = resolveReference(contextOnlyRef(reference), in: source)
    let occurrenceRange: NSRange? = { if case .success(let r) = occurrenceOutcome { return r }; return nil }()
    let contextRange: NSRange? = { if case .success(let r) = contextOutcome { return r }; return nil }()

    if isUnique {
        // Explicitly supplied evidence is checked for contradiction even
        // though sourceText alone would already resolve -- an explicitly
        // wrong occurrence or context is significant, never silently
        // ignored (this is the refinement over V1.4B's broad P3).
        if hasOcc, occurrenceRange == nil {
            return (.rejectedOccurrenceContradictsUnique, nil)
        }
        if hasCtx, contextRange == nil {
            return (.rejectedContextContradictsUnique, nil)
        }
        return (.resolvedOccurrenceAgreesWithUniqueSource, allOccurrences[0])
    }

    // Repeated source from here on.
    switch (hasOcc, hasCtx) {
    case (true, false):
        if let range = occurrenceRange { return (.resolvedOccurrenceOnly, range) }
        return (.rejectedInvalidOccurrenceNoContext, nil)

    case (false, true):
        if let range = contextRange { return (.resolvedContextOnlyFallback, range) }
        return (.rejectedAmbiguousContextOnly, nil)

    case (true, true):
        switch (occurrenceRange, contextRange) {
        case let (.some(a), .some(b)) where a == b:
            return (.resolvedOccurrenceAndContextAgree, a)
        case (.some, .some):
            // Both independently resolve, but to different locations --
            // a genuine contradiction. No precedence; reject.
            return (.rejectedGenuineContradiction, nil)
        case let (.some(a), .none):
            // Occurrence valid; context independently failed to narrow
            // to any single location -- uninformative, not contradictory.
            return (.resolvedOccurrenceContextUninformative, a)
        case let (.none, .some(b)):
            // Occurrence invalid; context independently resolves --
            // the principal P3 fallback case.
            return (.resolvedContextFallback, b)
        case (.none, .none):
            return (.rejectedBothInvalid, nil)
        }

    case (false, false):
        return (.rejectedBothInvalid, nil) // unreachable given the early guard, kept for exhaustiveness
    }
}
