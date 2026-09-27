import Foundation

// EXPERIMENTAL -- Intelligence V1.3A architecture investigation only.
//
// This file is NOT production code. It is not referenced by
// `Sources/Fluid/Intelligence/` or any application/dictation path, and must
// never be imported from one. It exists solely as reproducible evidence for
// the V1.3A investigation into whether a model-facing addressing
// representation that omits UTF-16 arithmetic can be converted
// deterministically and safely into exact internal UTF-16 coordinates.
//
// If a future milestone adopts a representation resembling this prototype,
// it must be re-implemented (or explicitly promoted) inside
// `Sources/Fluid/Intelligence/`, reviewed under that milestone's own scope,
// and wired so that its output still passes through the unmodified
// `IntelligenceProposalTransportParser` / `IntelligenceSafetyAuthority`
// boundary -- resolution here never grants any transcript-mutation
// authority by itself.

enum InsertionSide {
    case before
    case after
}

enum ResolverFailure: Error, Equatable, CustomStringConvertible {
    case zeroOccurrences
    case ambiguousOccurrences(Int)
    case invalidOrdinal
    case emptyAnchorForInsertion

    var description: String {
        switch self {
        case .zeroOccurrences: return "zeroOccurrences"
        case .ambiguousOccurrences(let n): return "ambiguousOccurrences(\(n))"
        case .invalidOrdinal: return "invalidOrdinal"
        case .emptyAnchorForInsertion: return "emptyAnchorForInsertion"
        }
    }
}

/// Finds all exact, non-overlapping occurrences of `needle` in `haystack`, in
/// source order, as UTF-16 `NSRange`s. Exact only -- no case-folding, no
/// Unicode normalization, no fuzzy matching. This is the entire "search"
/// primitive every candidate below is built from.
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

/// Candidate B1: unique exact source. Zero occurrences -> reject. Exactly one
/// -> resolve. More than one -> reject as ambiguous. No guessing, ever.
func resolveB1(source: NSString, sourceText: String) -> Result<NSRange, ResolverFailure> {
    let occurrences = findExactOccurrences(of: sourceText, in: source)
    if occurrences.isEmpty { return .failure(.zeroOccurrences) }
    if occurrences.count > 1 { return .failure(.ambiguousOccurrences(occurrences.count)) }
    return .success(occurrences[0])
}

/// Candidate B2: exact source + an explicit 1-based occurrence ordinal,
/// selecting deterministically among source-ordered exact occurrences.
func resolveB2(source: NSString, sourceText: String, occurrence: Int) -> Result<NSRange, ResolverFailure> {
    let occurrences = findExactOccurrences(of: sourceText, in: source)
    if occurrences.isEmpty { return .failure(.zeroOccurrences) }
    guard occurrence >= 1, occurrence <= occurrences.count else { return .failure(.invalidOrdinal) }
    return .success(occurrences[occurrence - 1])
}

/// Candidate B3: exact source + exact left/right context anchors. Among all
/// occurrences of `sourceText`, selects the one(s) whose immediately
/// adjacent text exactly matches `leftContext`/`rightContext`. Zero or more
/// than one qualifying occurrence is rejected -- this never falls back to
/// "first match".
func resolveB3(
    source: NSString,
    sourceText: String,
    leftContext: String?,
    rightContext: String?
) -> Result<NSRange, ResolverFailure> {
    let occurrences = findExactOccurrences(of: sourceText, in: source)
    if occurrences.isEmpty { return .failure(.zeroOccurrences) }
    let matching = occurrences.filter { range in
        if let left = leftContext, !left.isEmpty {
            let leftLength = (left as NSString).length
            guard range.location >= leftLength else { return false }
            let leftRange = NSRange(location: range.location - leftLength, length: leftLength)
            if source.substring(with: leftRange) != left { return false }
        }
        if let right = rightContext, !right.isEmpty {
            let rightLength = (right as NSString).length
            let rightStart = range.location + range.length
            guard rightStart + rightLength <= source.length else { return false }
            let rightRange = NSRange(location: rightStart, length: rightLength)
            if source.substring(with: rightRange) != right { return false }
        }
        return true
    }
    if matching.isEmpty { return .failure(.zeroOccurrences) }
    if matching.count > 1 { return .failure(.ambiguousOccurrences(matching.count)) }
    return .success(matching[0])
}

/// Insertion addressing: resolve a non-empty anchor via the same
/// unique-exact-match rule as B1 (inheriting its ambiguity/zero-occurrence
/// rejection), then place a zero-length insertion point immediately before
/// or after it. An empty anchor is refused outright -- it would otherwise
/// match "everywhere" and silently select an arbitrary insertion point.
func resolveInsertion(source: NSString, anchorText: String, side: InsertionSide) -> Result<NSRange, ResolverFailure> {
    if anchorText.isEmpty { return .failure(.emptyAnchorForInsertion) }
    switch resolveB1(source: source, sourceText: anchorText) {
    case .failure(let failure):
        return .failure(failure)
    case .success(let anchorRange):
        switch side {
        case .after:
            return .success(NSRange(location: anchorRange.location + anchorRange.length, length: 0))
        case .before:
            return .success(NSRange(location: anchorRange.location, length: 0))
        }
    }
}
