import Foundation

/// How a `ModelFacingEdit` was located. Diagnostic only -- it grants
/// nothing. Each case names the row of the V1.5 decision table (as clarified
/// by V1.6; see `IntelligenceAddressingResolver`) that produced the
/// resolution, so tests assert *why* something resolved, not merely that it
/// did.
enum IntelligenceAddressingBasis: Equatable {
    /// `sourceText` occurs exactly once; no occurrence or context supplied.
    case uniqueSource
    /// `sourceText` occurs exactly once, and every explicitly supplied
    /// occurrence/context agreed with that single location.
    case uniqueSourceCorroborated
    /// Repeated source; a valid occurrence alone identified the location.
    case occurrence
    /// Repeated source; no occurrence supplied and the supplied context
    /// matched exactly one candidate.
    case contextOnly
    /// Repeated source; a valid occurrence, and the supplied context matched
    /// exactly that same single candidate.
    case occurrenceCorroboratedByContext
    /// Repeated source; a valid occurrence, and the supplied context matched
    /// several candidates *including* the occurrence's -- context did not
    /// narrow further but did not contradict.
    case occurrenceWithNonNarrowingContext
    /// Repeated source; the occurrence was invalid but the supplied context
    /// independently matched exactly one candidate (the constrained
    /// fallback).
    case contextFallbackForInvalidOccurrence
}

/// Every way a `ModelFacingEdit` can fail to resolve to exactly one
/// location. Associated values are counts/ordinals only -- never transcript
/// text -- so a failure can be logged without leaking dictation content.
enum IntelligenceAddressingRejection: Error, Equatable {
    /// `sourceText` is empty. (Insertion is out of scope; an empty target
    /// is never a wildcard.)
    case emptySourceText
    /// `sourceText` occurs nowhere in the immutable source -- a
    /// hallucinated, stale or corrupted reference.
    case noLiteralMatch
    /// The supplied `occurrence` is not a valid 1-based ordinal for the
    /// number of literal candidates (zero, negative or too large) and no
    /// independently usable context rescued it. On a unique source this
    /// covers any ordinal other than 1: an explicit contradiction is never
    /// silently ignored merely because the bare text is unambiguous.
    case occurrenceOutOfRange(occurrence: Int, candidateCount: Int)
    /// Supplied context matches none of the candidate occurrences. This is
    /// contradictory evidence and rejects regardless of any occurrence
    /// (V1.6 clarification), on unique and repeated sources alike.
    case contextMatchesNoCandidate
    /// More than one candidate remains after every supplied discriminator
    /// was applied, and nothing selects among them.
    case ambiguousCandidates(count: Int)
    /// A valid occurrence names a candidate that the supplied context
    /// excludes. Neither discriminator silently wins.
    case occurrenceContradictsContext
}

/// Deterministic textual source resolver: "where does this model-facing edit
/// apply, if anywhere?" -- and nothing more. It never asks whether the edit
/// is *safe* (that is `IntelligenceSafetyAuthority`'s job alone), never
/// shrinks or reinterprets a model-selected span, never relocates by
/// fuzzy/semantic search, never falls back to "first match", and never
/// computes anything from the model's own idea of an offset.
///
/// Promoted and refactored from the experimental V1.4/V1.4C resolver
/// (`Evaluation/Intelligence/Experimental/`), implementing the V1.5
/// decision table with the V1.6 clarifications below.
///
/// Definitions, for one edit against one immutable source:
///   - *candidates*: every UTF-16 start position at which `sourceText`
///     literally occurs, **including overlapping ones** (`"aa"` in `"aaa"`
///     has candidates at 0 and 1), in source order;
///   - *occurrence is valid* iff it is in `1...candidates.count`;
///   - *context is supplied* iff `leftContext` or `rightContext` is
///     non-empty; a candidate *matches* the context iff every supplied side
///     literally matches the source immediately around it; the *context set*
///     `C` is the candidates that match.
///
/// Decision procedure (V1.5 table, rows in brackets, with V1.6 changes
/// marked *):
///   1. no candidates -> reject `noLiteralMatch` [14]
///   2. context supplied and `C` empty -> reject `contextMatchesNoCandidate`
///      * -- this applies to unique and repeated sources alike, and even
///      when the occurrence is valid (V1.5 row 10 treated "context matches
///      nowhere" as uninformative; V1.6 treats it as contradiction, making
///      it consistent with row 4).
///   3. unique source:
///        - occurrence supplied and != 1 -> reject `occurrenceOutOfRange` [3]
///        - otherwise resolve [1, 2] (context, if supplied, necessarily
///          matched the sole candidate by step 2)
///   4. repeated source, occurrence supplied and valid (position `o`):
///        - context not supplied -> resolve `o` [5]
///        - `o` not in `C` -> reject `occurrenceContradictsContext` [12]
///          * (extends row 12 to the case where context matches several
///          other candidates but excludes `o`; V1.5 row 10 would have
///          resolved `o` there)
///        - `|C| == 1` -> resolve `o` [9]; `|C| > 1` -> resolve `o`,
///          context non-narrowing but non-contradictory [10]
///   5. repeated source, occurrence supplied but invalid:
///        - context not supplied -> reject `occurrenceOutOfRange` [6]
///        - `|C| == 1` -> resolve that candidate [11]
///        - `|C| > 1` -> reject `ambiguousCandidates` [13]
///   6. repeated source, no occurrence:
///        - context not supplied -> reject `ambiguousCandidates` [the bare
///          repeated-text case, never "first match"]
///        - `|C| == 1` -> resolve [7]; `|C| > 1` -> reject
///          `ambiguousCandidates` [8]
enum IntelligenceAddressingResolver {
    struct Resolution: Equatable {
        /// UTF-16 range in the immutable source, matching this repository's
        /// existing `NSRange` convention.
        let range: NSRange
        let basis: IntelligenceAddressingBasis
    }

    static func resolve(_ edit: ModelFacingEdit, in source: String) -> Result<Resolution, IntelligenceAddressingRejection> {
        let sourceUnits = Array(source.utf16)
        let needleUnits = Array(edit.sourceText.utf16)
        guard needleUnits.isEmpty == false else { return .failure(.emptySourceText) }

        let candidates = self.literalOccurrences(of: needleUnits, in: sourceUnits)
        guard candidates.isEmpty == false else { return .failure(.noLiteralMatch) }

        let left = Array((edit.leftContext ?? "").utf16)
        let right = Array((edit.rightContext ?? "").utf16)
        let contextSupplied = left.isEmpty == false || right.isEmpty == false
        let contextMatches: [NSRange] = contextSupplied
            ? candidates.filter { self.contextMatches($0, left: left, right: right, in: sourceUnits) }
            : []
        if contextSupplied, contextMatches.isEmpty {
            return .failure(.contextMatchesNoCandidate)
        }

        let occurrenceSupplied = edit.occurrence != nil
        // The candidate the occurrence names, if it is a valid 1-based
        // ordinal; nil when absent or invalid (`occurrenceSupplied`
        // distinguishes the two).
        let occurrenceRange: NSRange? = edit.occurrence.flatMap { ordinal in
            (1...candidates.count).contains(ordinal) ? candidates[ordinal - 1] : nil
        }

        if candidates.count == 1 {
            if let ordinal = edit.occurrence, ordinal != 1 {
                return .failure(.occurrenceOutOfRange(occurrence: ordinal, candidateCount: 1))
            }
            let corroborated = occurrenceSupplied || contextSupplied
            return .success(Resolution(range: candidates[0], basis: corroborated ? .uniqueSourceCorroborated : .uniqueSource))
        }

        // Repeated source from here on.
        if let occurrenceRange {
            guard contextSupplied else {
                return .success(Resolution(range: occurrenceRange, basis: .occurrence))
            }
            guard contextMatches.contains(occurrenceRange) else { return .failure(.occurrenceContradictsContext) }
            let basis: IntelligenceAddressingBasis = contextMatches.count == 1 ? .occurrenceCorroboratedByContext : .occurrenceWithNonNarrowingContext
            return .success(Resolution(range: occurrenceRange, basis: basis))
        }

        if let ordinal = edit.occurrence, contextSupplied == false {
            return .failure(.occurrenceOutOfRange(occurrence: ordinal, candidateCount: candidates.count))
        }
        guard contextSupplied else {
            return .failure(.ambiguousCandidates(count: candidates.count))
        }
        // Context supplied, and no valid occurrence to select among its matches.
        guard contextMatches.count == 1 else {
            return .failure(.ambiguousCandidates(count: contextMatches.count))
        }
        let basis: IntelligenceAddressingBasis = occurrenceSupplied ? .contextFallbackForInvalidOccurrence : .contextOnly
        return .success(Resolution(range: contextMatches[0], basis: basis))
    }

    /// Every UTF-16 start position at which `needle` literally occurs in
    /// `haystack`, overlapping matches included, in source order. Compares
    /// raw UTF-16 code units: exact only, no case-folding, no Unicode
    /// normalization, no fuzzy matching. Because `needle` comes from a valid
    /// Swift `String`, a code-unit match can never begin or end inside a
    /// surrogate pair. (For canonically-decomposed text it can begin or end
    /// inside a grapheme cluster, e.g. the base "e" of "e" + combining
    /// acute. The resolver deliberately does not repair or forbid that: it
    /// is exact-literal, and whether such an edit is permissible is decided
    /// by `IntelligenceSafetyAuthority` on the resulting scalar text.)
    static func literalOccurrences(of needle: [UInt16], in haystack: [UInt16]) -> [NSRange] {
        guard needle.isEmpty == false, needle.count <= haystack.count else { return [] }
        var results: [NSRange] = []
        for start in 0...(haystack.count - needle.count) where haystack[start] == needle[0] {
            if haystack[start..<(start + needle.count)].elementsEqual(needle) {
                results.append(NSRange(location: start, length: needle.count))
            }
        }
        return results
    }

    private static func contextMatches(_ range: NSRange, left: [UInt16], right: [UInt16], in source: [UInt16]) -> Bool {
        if left.isEmpty == false {
            guard range.location >= left.count,
                  source[(range.location - left.count)..<range.location].elementsEqual(left)
            else { return false }
        }
        if right.isEmpty == false {
            let rightStart = range.location + range.length
            guard rightStart + right.count <= source.count,
                  source[rightStart..<(rightStart + right.count)].elementsEqual(right)
            else { return false }
        }
        return true
    }
}
