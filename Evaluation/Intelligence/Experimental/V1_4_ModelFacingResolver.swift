import Foundation

// EXPERIMENTAL -- Intelligence V1.4 architecture investigation only. Not
// production code; not referenced by `Sources/Fluid/Intelligence/` or any
// application/dictation path. This file explores several CANDIDATE
// model-facing proposal representations at once (a superset of optional
// discriminator fields) so the same resolver can be exercised under
// different "which fields are actually populated" disciplines -- that is
// how this investigation measures the *minimum* information a model must
// supply, rather than assuming a schema up front.
//
// This is explicitly NOT presented as the final resolver design (V1.3A's
// resolver, reused conceptually here, was not treated as final either).
// A future milestone that adopts anything resembling this must
// re-implement/promote it inside `Sources/Fluid/Intelligence/` under its
// own review, and must still route every result through the unmodified
// `IntelligenceProposalTransportParser` / `IntelligenceSafetyAuthority`
// boundary. Resolution here never grants transcript-mutation authority by
// itself.

/// Which side of an anchor an insertion targets. Only meaningful when
/// `ModelFacingReference.anchorText` is non-nil.
enum AnchorSide: Equatable {
    case before
    case after
}

/// A superset reference representation covering every candidate (A-D) from
/// the V1.4 investigation. A real model-facing contract would only ever
/// populate the fields its own candidate representation defines; this type
/// exists so the SAME resolver logic can be exercised under each
/// candidate's field-usage discipline and compared directly.
struct ModelFacingReference: Equatable {
    /// Candidate A/B/C: the exact text being targeted for replacement or
    /// deletion. Empty/nil for a pure insertion (paired with an anchor or a
    /// boundary flag instead).
    var sourceText: String?
    /// Candidate B: an explicit 1-based occurrence ordinal, disambiguating
    /// among source-ordered exact occurrences of `sourceText`.
    var occurrence: Int?
    /// Candidate C: exact literal context immediately adjacent to
    /// `sourceText` in the source, used only to disambiguate among
    /// repeated occurrences -- never fuzzy, never optional-but-approximate.
    var leftContext: String?
    var rightContext: String?
    /// Candidate D: insertion addressing. `anchorText` + `anchorSide`
    /// locates a zero-length insertion point immediately before/after an
    /// exact (optionally occurrence/context-disambiguated) anchor.
    var anchorText: String?
    var anchorSide: AnchorSide?
    /// Candidate D: absolute source boundaries, for insertion at the very
    /// start or end of the immutable source (no anchor needed).
    var atStart: Bool = false
    var atEnd: Bool = false

    static func replace(_ text: String, occurrence: Int? = nil, leftContext: String? = nil, rightContext: String? = nil) -> ModelFacingReference {
        ModelFacingReference(sourceText: text, occurrence: occurrence, leftContext: leftContext, rightContext: rightContext)
    }

    static func insert(anchor: String, side: AnchorSide, occurrence: Int? = nil, leftContext: String? = nil, rightContext: String? = nil) -> ModelFacingReference {
        ModelFacingReference(occurrence: occurrence, leftContext: leftContext, rightContext: rightContext, anchorText: anchor, anchorSide: side)
    }

    static func insertAtStart() -> ModelFacingReference { ModelFacingReference(atStart: true) }
    static func insertAtEnd() -> ModelFacingReference { ModelFacingReference(atEnd: true) }
}

/// One model-facing proposal: a reference into the immutable source, plus
/// the replacement text. Candidate E (zero-edit representation) is
/// evaluated at the caller level -- an empty proposal array/no tool call is
/// a distinct experimental condition, not a field on this type.
struct ModelFacingProposal: Equatable {
    let id: String
    let reference: ModelFacingReference
    let replacementText: String
}

enum ResolverFailure: Error, Equatable, CustomStringConvertible {
    case zeroOccurrences
    case ambiguousOccurrences(Int)
    case invalidOrdinal
    case contextMismatch
    case emptyReference
    case anchorZeroOccurrences
    case anchorAmbiguousOccurrences(Int)

    var description: String {
        switch self {
        case .zeroOccurrences: return "zeroOccurrences"
        case .ambiguousOccurrences(let n): return "ambiguousOccurrences(\(n))"
        case .invalidOrdinal: return "invalidOrdinal"
        case .contextMismatch: return "contextMismatch"
        case .emptyReference: return "emptyReference"
        case .anchorZeroOccurrences: return "anchorZeroOccurrences"
        case .anchorAmbiguousOccurrences(let n): return "anchorAmbiguousOccurrences(\(n))"
        }
    }
}

/// Finds all exact, non-overlapping occurrences of `needle` in `haystack`,
/// in source order, as UTF-16 `NSRange`s. Exact only -- no case-folding, no
/// Unicode normalization, no fuzzy matching, ever.
func findExactOccurrences(of needle: String, in haystack: NSString) -> [NSRange] {
    guard needle.isEmpty == false else { return [] }
    var results: [NSRange] = []
    var searchRange = NSRange(location: 0, length: haystack.length)
    while true {
        let found = haystack.range(of: needle, options: [.literal], range: searchRange)
        if found.location == NSNotFound { break }
        results.append(found)
        let nextStart = found.location + found.length
        if nextStart >= haystack.length { break }
        searchRange = NSRange(location: nextStart, length: haystack.length - nextStart)
    }
    return results
}

/// Narrows a set of candidate occurrences using whatever discriminators are
/// actually populated on the reference: occurrence ordinal first (if
/// present), then exact left/right context (if present). Never falls back
/// to "first match" -- if more than one occurrence survives every supplied
/// discriminator, that is ambiguity, not a resolvable case.
private func disambiguate(
    _ occurrences: [NSRange],
    reference: ModelFacingReference,
    source: NSString
) -> Result<NSRange, ResolverFailure> {
    if occurrences.isEmpty { return .failure(.zeroOccurrences) }

    var candidates = occurrences

    if let ordinal = reference.occurrence {
        guard ordinal >= 1, ordinal <= candidates.count else { return .failure(.invalidOrdinal) }
        candidates = [candidates[ordinal - 1]]
    }

    if reference.leftContext != nil || reference.rightContext != nil {
        let contextFiltered = candidates.filter { range in
            if let left = reference.leftContext, !left.isEmpty {
                let leftLength = (left as NSString).length
                guard range.location >= leftLength else { return false }
                let leftRange = NSRange(location: range.location - leftLength, length: leftLength)
                if source.substring(with: leftRange) != left { return false }
            }
            if let right = reference.rightContext, !right.isEmpty {
                let rightLength = (right as NSString).length
                let rightStart = range.location + range.length
                guard rightStart + rightLength <= source.length else { return false }
                let rightRange = NSRange(location: rightStart, length: rightLength)
                if source.substring(with: rightRange) != right { return false }
            }
            return true
        }
        if contextFiltered.isEmpty {
            // Distinguish "context syntactically requested but didn't match
            // anywhere" from ordinary zero-occurrences of sourceText itself.
            return .failure(.contextMismatch)
        }
        candidates = contextFiltered
    }

    if candidates.count > 1 { return .failure(.ambiguousOccurrences(candidates.count)) }
    return .success(candidates[0])
}

/// Resolves one `ModelFacingReference` against the immutable `source`,
/// returning the exact UTF-16 `NSRange` it deterministically identifies, or
/// a specific, explicit failure. This is the single resolver function
/// exercised by every candidate (A-D) -- which discriminator fields a
/// candidate is allowed to populate is a property of the EXPERIMENT, not
/// of this function, which always honors whatever is actually present.
func resolveReference(_ reference: ModelFacingReference, in source: NSString) -> Result<NSRange, ResolverFailure> {
    if reference.atStart { return .success(NSRange(location: 0, length: 0)) }
    if reference.atEnd { return .success(NSRange(location: source.length, length: 0)) }

    if let anchor = reference.anchorText, let side = reference.anchorSide {
        guard !anchor.isEmpty else { return .failure(.emptyReference) }
        let occurrences = findExactOccurrences(of: anchor, in: source)
        switch disambiguate(occurrences, reference: reference, source: source) {
        case .failure(.zeroOccurrences):
            return .failure(.anchorZeroOccurrences)
        case .failure(.ambiguousOccurrences(let n)):
            return .failure(.anchorAmbiguousOccurrences(n))
        case .failure(let other):
            return .failure(other)
        case .success(let anchorRange):
            switch side {
            case .after:
                return .success(NSRange(location: anchorRange.location + anchorRange.length, length: 0))
            case .before:
                return .success(NSRange(location: anchorRange.location, length: 0))
            }
        }
    }

    guard let sourceText = reference.sourceText, !sourceText.isEmpty else {
        return .failure(.emptyReference)
    }
    let occurrences = findExactOccurrences(of: sourceText, in: source)
    return disambiguate(occurrences, reference: reference, source: source)
}

/// Resolves every proposal in `proposals` against the SAME immutable
/// `source` -- never against a partially-edited copy, and never in an
/// order that lets an earlier proposal's resolution affect a later one's
/// coordinate space. This is the immutable-source-semantics invariant the
/// investigation requires: resolution is a pure function of (reference,
/// original source) for every proposal in a batch, regardless of how many
/// other proposals exist alongside it.
func resolveBatch(
    _ proposals: [ModelFacingProposal],
    against source: NSString
) -> [(proposal: ModelFacingProposal, result: Result<NSRange, ResolverFailure>)] {
    proposals.map { proposal in
        (proposal: proposal, result: resolveReference(proposal.reference, in: source))
    }
}

/// Detects overlap among a set of resolved ranges, using the same
/// half-open-interval intersection semantics as the committed
/// `IntelligenceSafetyAuthority` (a zero-length insertion at a boundary is
/// not considered overlapping with an adjacent non-empty range that merely
/// touches it). This is a resolver-level check, run BEFORE handing
/// anything to `IntelligenceSafetyAuthority`, which independently performs
/// its own overlap detection too -- two independent confirmations that
/// resolution does not bypass existing overlap/conflict safety semantics.
func detectOverlaps(_ ranges: [(id: String, range: NSRange)]) -> [(String, String)] {
    var overlapping: [(String, String)] = []
    for i in 0..<ranges.count {
        for j in (i + 1)..<ranges.count where j < ranges.count {
            let a = ranges[i].range
            let b = ranges[j].range
            let aEnd = a.location + a.length
            let bEnd = b.location + b.length
            let intersects = a.location < bEnd && b.location < aEnd
            if intersects {
                overlapping.append((ranges[i].id, ranges[j].id))
            }
        }
    }
    return overlapping
}
