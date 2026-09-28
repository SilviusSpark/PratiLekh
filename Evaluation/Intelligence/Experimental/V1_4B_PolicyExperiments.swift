import Foundation

// EXPERIMENTAL -- Intelligence V1.4B architecture investigation only.
// Extends `V1_4_ModelFacingResolver.swift` (unmodified) with explicit,
// separately-testable Candidate B+C contradiction policies. Not production
// code. Each policy is its own function so the investigation can compare
// them directly rather than hiding a single choice behind one code path.

/// How a combined B+C reference resolves when both an occurrence ordinal
/// and exact context are supplied together.
enum BCPolicyOutcome: Equatable {
    case resolved(NSRange)
    case rejectedBothInvalid
    case rejectedOccurrenceInvalidOnly
    case rejectedContextInvalidOnly
    case rejectedContradiction   // both individually valid, but disagree
    case rejectedOther(ResolverFailure)
}

private func occurrenceOnly(_ reference: ModelFacingReference) -> ModelFacingReference {
    var r = reference
    r.leftContext = nil
    r.rightContext = nil
    return r
}

private func contextOnly(_ reference: ModelFacingReference) -> ModelFacingReference {
    var r = reference
    r.occurrence = nil
    return r
}

/// Policy P1 -- strict agreement. Both occurrence and context (whichever of
/// left/right are supplied) must independently resolve, AND to the SAME
/// location. Any disagreement, or either one alone failing, rejects. This
/// is the safety-first hypothesis: contradiction is treated as a reason to
/// distrust the whole proposal, not as extra information to adjudicate.
func resolveBCPolicyP1StrictAgreement(_ reference: ModelFacingReference, in source: NSString) -> BCPolicyOutcome {
    let occurrenceResult = resolveReference(occurrenceOnly(reference), in: source)
    let contextResult = resolveReference(contextOnly(reference), in: source)
    switch (occurrenceResult, contextResult) {
    case let (.success(a), .success(b)):
        if a == b { return .resolved(a) }
        return .rejectedContradiction
    case (.failure, .failure):
        return .rejectedBothInvalid
    case (.failure, .success):
        return .rejectedOccurrenceInvalidOnly
    case (.success, .failure):
        return .rejectedContextInvalidOnly
    }
}

/// Policy P2 -- optional corroboration, with `occurrence` as primary. The
/// context fields, if present, are checked only as a non-binding sanity
/// signal; disagreement is recorded but does not itself cause rejection --
/// only occurrence's own success/failure decides the outcome. Evaluated
/// here as an experimental hypothesis, not adopted.
func resolveBCPolicyP2OccurrencePrimary(_ reference: ModelFacingReference, in source: NSString) -> BCPolicyOutcome {
    let occurrenceResult = resolveReference(occurrenceOnly(reference), in: source)
    guard case .success(let occurrenceRange) = occurrenceResult else {
        return .rejectedOccurrenceInvalidOnly
    }
    let contextResult = resolveReference(contextOnly(reference), in: source)
    if case .success(let contextRange) = contextResult, contextRange != occurrenceRange {
        // Corroboration disagrees, but occurrence still wins under this
        // policy -- this is exactly the risk this policy exists to expose.
        return .resolved(occurrenceRange)
    }
    return .resolved(occurrenceRange)
}

/// Policy P3 -- discriminator fallback. If one supplied discriminator
/// fails but the other resolves uniquely, accept the successful one. This
/// is the most permissive policy and the one most likely to convert
/// genuinely contradictory model output into an applied edit -- evaluated
/// explicitly as a risk, not recommended by construction.
func resolveBCPolicyP3Fallback(_ reference: ModelFacingReference, in source: NSString) -> BCPolicyOutcome {
    let occurrenceResult = resolveReference(occurrenceOnly(reference), in: source)
    let contextResult = resolveReference(contextOnly(reference), in: source)
    switch (occurrenceResult, contextResult) {
    case let (.success(a), .success(b)):
        if a == b { return .resolved(a) }
        // Both independently valid but disagree -- P3 must still pick one
        // or reject; picking either would be an unjustified guess, so even
        // the most permissive policy tested here rejects a true
        // contradiction rather than silently choosing.
        return .rejectedContradiction
    case (.success(let a), .failure):
        return .resolved(a)
    case (.failure, .success(let b)):
        return .resolved(b)
    case (.failure, .failure):
        return .rejectedBothInvalid
    }
}
