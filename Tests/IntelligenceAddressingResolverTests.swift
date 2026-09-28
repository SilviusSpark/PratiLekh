import Foundation

/// Coverage for `IntelligenceAddressingResolver`, the deterministic textual
/// source resolver promoted from the experimental V1.4/V1.4C work. Ports the
/// full V1.4C adversarial matrix (A1-A20) and adds the V1.6 cases:
/// overlapping literal occurrences, and the zero-match / one-match /
/// multi-match context distinction. Deterministic only -- no model, no
/// network.
///
/// The resolver answers only "where does this apply?". Whether a resolved
/// edit is *safe* is `IntelligenceSafetyAuthority`'s question and is covered
/// in `IntelligenceAddressingBridgeTests`.
@main
enum IntelligenceAddressingResolverTests {
    private typealias Basis = IntelligenceAddressingBasis
    private typealias Rejection = IntelligenceAddressingRejection

    static func main() {
        // V1.4C adversarial matrix, ported (A1-A20).
        self.testA1_uniqueSourceNoDiscriminator()
        self.testA2_uniqueSourceCorrectOccurrence()
        self.testA3_uniqueSourceIncorrectOccurrence()
        self.testA4_uniqueSourceIncorrectContext()
        self.testA5_repeatedCorrectOccurrenceOnly()
        self.testA6_repeatedInvalidOccurrenceOnly()
        self.testA7_repeatedCorrectContextOnly()
        self.testA8_repeatedAmbiguousContextOnly()
        self.testA9_repeatedOccurrenceAndAgreeingContext()
        self.testA10_repeatedOccurrenceWithNonMatchingContextNowRejects()
        self.testA11_repeatedInvalidOccurrenceUniquelyCorrectContext()
        self.testA12_repeatedContradiction()
        self.testA13_mutuallyConsistentWrongLocationIsUndetectable()
        self.testA14_offByOneOccurrenceVariants()
        self.testA15_adjacentIdenticalRepetition()
        self.testA16_substringContainment()
        self.testA17_contextContainingTargetItself()
        self.testA18_emptyVsAbsentContext()
        self.testA19_veryLongContext()
        self.testA20_unicodeContradictionAndFallback()

        // Remaining decision-table rows and structural guards.
        self.testEmptySourceTextRejected()
        self.testNoLiteralMatchRejected()
        self.testMatchingIsExactNoCaseFoldingOrNormalization()
        self.testBothContextsMustMatchTogether()
        self.testNegativeOccurrenceIsInvalid()
        self.testInvalidOccurrenceOnUniqueSourceNeverRescuedByContext()

        // V1.6: overlapping literal matches.
        self.testOverlappingOccurrencesAreAllEnumerated()
        self.testOverlappingCandidatesAreNotTreatedAsUnique()
        self.testOverlappingCandidatesAddressableByOccurrence()
        self.testOverlappingCandidatesAddressableByContext()

        // V1.6: context zero-match vs one-match vs multi-match.
        self.testContextZeroMatchRejectsOnUniqueSource()
        self.testContextZeroMatchRejectsEvenWithValidOccurrence()
        self.testContextZeroMatchRejectsWithInvalidOccurrence()
        self.testContextOneMatchIsInformative()
        self.testContextMultiMatchIncludingOccurrenceStillResolves()
        self.testContextMultiMatchExcludingOccurrenceRejects()
        self.testContextMultiMatchWithInvalidOccurrenceIsAmbiguous()
        self.testContextMultiMatchAloneIsAmbiguous()

        // Determinism / purity.
        self.testResolutionIsPureAndRepeatable()
        self.testRejectionsCarryNoTranscriptText()

        print("PASS: IntelligenceAddressingResolver V1.4C matrix and V1.6 clarification suite")
    }

    // MARK: - Helpers

    private static func resolve(_ edit: ModelFacingEdit, _ source: String) -> Result<IntelligenceAddressingResolver.Resolution, Rejection> {
        IntelligenceAddressingResolver.resolve(edit, in: source)
    }

    private static func edit(
        _ sourceText: String,
        occurrence: Int? = nil,
        left: String? = nil,
        right: String? = nil
    ) -> ModelFacingEdit {
        ModelFacingEdit(sourceText: sourceText, replacementText: "X", occurrence: occurrence, leftContext: left, rightContext: right)
    }

    private static func expectResolved(
        _ label: String,
        _ edit: ModelFacingEdit,
        _ source: String,
        at location: Int,
        basis: Basis,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        switch self.resolve(edit, source) {
        case let .success(resolution):
            precondition(resolution.range.location == location, "\(label): expected location \(location), got \(resolution.range.location)", file: file, line: line)
            precondition(resolution.range.length == edit.sourceText.utf16.count, "\(label): range length must equal sourceText length", file: file, line: line)
            precondition(resolution.basis == basis, "\(label): expected basis \(basis), got \(resolution.basis)", file: file, line: line)
        case let .failure(reason):
            preconditionFailure("\(label): expected resolution, got rejection \(reason)", file: file, line: line)
        }
    }

    private static func expectRejected(
        _ label: String,
        _ edit: ModelFacingEdit,
        _ source: String,
        _ expected: Rejection,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        switch self.resolve(edit, source) {
        case let .success(resolution):
            preconditionFailure("\(label): expected rejection \(expected), got resolution at \(resolution.range)", file: file, line: line)
        case let .failure(reason):
            precondition(reason == expected, "\(label): expected \(expected), got \(reason)", file: file, line: line)
        }
    }

    private static let unique = "The witness confirmed the statement."
    private static let twice = "the accused said the accused left" // occurrences at 0 and 17

    // MARK: - V1.4C matrix (A1-A20)

    private static func testA1_uniqueSourceNoDiscriminator() {
        self.expectResolved("A1", self.edit("confirmed"), self.unique, at: 12, basis: .uniqueSource)
    }

    private static func testA2_uniqueSourceCorrectOccurrence() {
        self.expectResolved("A2", self.edit("confirmed", occurrence: 1), self.unique, at: 12, basis: .uniqueSourceCorroborated)
    }

    private static func testA3_uniqueSourceIncorrectOccurrence() {
        self.expectRejected("A3", self.edit("confirmed", occurrence: 2), self.unique, .occurrenceOutOfRange(occurrence: 2, candidateCount: 1))
    }

    private static func testA4_uniqueSourceIncorrectContext() {
        // V1.6: rejects as contextMatchesNoCandidate (V1.5 named it "context
        // contradicts unique"); same outcome, unified reason.
        self.expectRejected("A4", self.edit("confirmed", left: "wrong prefix "), self.unique, .contextMatchesNoCandidate)
    }

    private static func testA5_repeatedCorrectOccurrenceOnly() {
        self.expectResolved("A5", self.edit("the accused", occurrence: 2), self.twice, at: 17, basis: .occurrence)
    }

    private static func testA6_repeatedInvalidOccurrenceOnly() {
        self.expectRejected("A6", self.edit("the accused", occurrence: 5), self.twice, .occurrenceOutOfRange(occurrence: 5, candidateCount: 2))
    }

    private static func testA7_repeatedCorrectContextOnly() {
        self.expectResolved("A7", self.edit("the accused", right: " left"), self.twice, at: 17, basis: .contextOnly)
    }

    private static func testA8_repeatedAmbiguousContextOnly() {
        let source = "the accused left, the accused left again."
        self.expectRejected("A8", self.edit("the accused", right: " left"), source, .ambiguousCandidates(count: 2))
    }

    private static func testA9_repeatedOccurrenceAndAgreeingContext() {
        self.expectResolved("A9", self.edit("the accused", occurrence: 2, right: " left"), self.twice, at: 17, basis: .occurrenceCorroboratedByContext)
    }

    /// V1.6 CORRECTION to V1.4C's A10. The experimental resolver treated
    /// context that matches no candidate at all as "uninformative" and
    /// resolved by occurrence. V1.6 treats zero-match context as
    /// contradictory evidence and rejects (uniformly with A4).
    private static func testA10_repeatedOccurrenceWithNonMatchingContextNowRejects() {
        self.expectRejected("A10", self.edit("the accused", occurrence: 2, right: " nonexistent-neighbor"), self.twice, .contextMatchesNoCandidate)
    }

    private static func testA11_repeatedInvalidOccurrenceUniquelyCorrectContext() {
        self.expectResolved("A11", self.edit("the accused", occurrence: 9, right: " left"), self.twice, at: 17, basis: .contextFallbackForInvalidOccurrence)
    }

    private static func testA12_repeatedContradiction() {
        let source = "the accused said, the accused left"
        // occurrence 2 names the second; " said" matches only the first.
        self.expectRejected("A12", self.edit("the accused", occurrence: 2, right: " said"), source, .occurrenceContradictsContext)
    }

    private static func testA13_mutuallyConsistentWrongLocationIsUndetectable() {
        // Documents a known, undetectable-by-construction limit: agreeing
        // discriminators resolve, even if both misidentify the human's
        // intent. Not a resolver defect; a model/evaluation-layer risk.
        self.expectResolved("A13", self.edit("the accused", occurrence: 1, right: " said"), self.twice, at: 0, basis: .occurrenceCorroboratedByContext)
    }

    private static func testA14_offByOneOccurrenceVariants() {
        self.expectRejected("A14 occ 0", self.edit("the accused", occurrence: 0), self.twice, .occurrenceOutOfRange(occurrence: 0, candidateCount: 2))
        self.expectRejected("A14 occ N+1", self.edit("the accused", occurrence: 3), self.twice, .occurrenceOutOfRange(occurrence: 3, candidateCount: 2))
        self.expectResolved("A14 occ 1", self.edit("the accused", occurrence: 1), self.twice, at: 0, basis: .occurrence)
        self.expectResolved("A14 occ 2", self.edit("the accused", occurrence: 2), self.twice, at: 17, basis: .occurrence)
    }

    private static func testA15_adjacentIdenticalRepetition() {
        let source = "the the the"
        self.expectResolved("A15 occ 1", self.edit("the", occurrence: 1), source, at: 0, basis: .occurrence)
        self.expectResolved("A15 occ 2", self.edit("the", occurrence: 2), source, at: 4, basis: .occurrence)
        self.expectResolved("A15 occ 3", self.edit("the", occurrence: 3), source, at: 8, basis: .occurrence)
        self.expectRejected("A15 occ 4", self.edit("the", occurrence: 4), source, .occurrenceOutOfRange(occurrence: 4, candidateCount: 3))
    }

    private static func testA16_substringContainment() {
        // "Act" is a literal substring of "Action": three candidates, exactly.
        let source = "Act one preceded Action two, then Act three."
        self.expectResolved("A16 occ 2", self.edit("Act", occurrence: 2), source, at: 17, basis: .occurrence)
        self.expectResolved("A16 occ 3", self.edit("Act", occurrence: 3), source, at: 34, basis: .occurrence)
    }

    private static func testA17_contextContainingTargetItself() {
        let source = "the witness said the witness said the witness left"
        self.expectResolved("A17", self.edit("the witness", right: " said the witness said"), source, at: 0, basis: .contextOnly)
    }

    private static func testA18_emptyVsAbsentContext() {
        // Empty context is "not supplied", never a universal match, so this
        // resolves via occurrence alone (basis .occurrence, not a
        // context-corroborated one).
        self.expectResolved("A18", self.edit("the accused", occurrence: 1, left: "", right: ""), self.twice, at: 0, basis: .occurrence)
        // ...and with no occurrence it is simply ambiguous, never "first".
        self.expectRejected("A18 bare", self.edit("the accused", left: "", right: ""), self.twice, .ambiguousCandidates(count: 2))
    }

    private static func testA19_veryLongContext() {
        let filler = String(repeating: "padding ", count: 200)
        let source = "\(filler)the accused said the accused left"
        let second = (source as NSString).length - "the accused left".utf16.count
        self.expectResolved("A19", self.edit("the accused", left: filler + "the accused said "), source, at: second, basis: .contextOnly)
    }

    private static func testA20_unicodeContradictionAndFallback() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let odiaSource = "The complainant resides in \(odia). The witness also resides in \(odia)."
        let second = (odiaSource as NSString).range(of: odia, options: [.backwards]).location
        self.expectResolved("A20 odia fallback", self.edit(odia, occurrence: 9, right: ". The witness"), odiaSource, at: 27, basis: .contextFallbackForInvalidOccurrence)
        self.expectResolved("A20 odia second by occurrence", self.edit(odia, occurrence: 2), odiaSource, at: second, basis: .occurrence)

        let emoji = "\u{1F60A}"
        let emojiSource = "The accused smiled \(emoji) once. The witness smiled \(emoji) twice."
        self.expectRejected("A20 emoji contradiction", self.edit(emoji, occurrence: 2, right: " once"), emojiSource, .occurrenceContradictsContext)
        // Surrogate-pair length is UTF-16 (2), derived by Swift, not the model.
        self.expectResolved("A20 emoji by context", self.edit(emoji, right: " twice"), emojiSource, at: (emojiSource as NSString).range(of: emoji, options: [.backwards]).location, basis: .contextOnly)
    }

    // MARK: - Other decision-table rows and guards

    private static func testEmptySourceTextRejected() {
        self.expectRejected("empty sourceText", self.edit(""), self.twice, .emptySourceText)
        self.expectRejected("empty sourceText with discriminators", self.edit("", occurrence: 1, left: "the"), self.twice, .emptySourceText)
    }

    private static func testNoLiteralMatchRejected() {
        self.expectRejected("hallucinated text", self.edit("the defendant"), self.twice, .noLiteralMatch)
        self.expectRejected("hallucinated text with occurrence", self.edit("the defendant", occurrence: 1), self.twice, .noLiteralMatch)
        self.expectRejected("sourceText longer than the source", self.edit(self.twice + " and more"), self.twice, .noLiteralMatch)
    }

    private static func testMatchingIsExactNoCaseFoldingOrNormalization() {
        self.expectRejected("case differs", self.edit("The Accused"), self.twice, .noLiteralMatch)
        // Precomposed vs decomposed e-acute: not equal, never normalized.
        let precomposed = "caf\u{00E9}"
        let decomposed = "cafe\u{0301}"
        self.expectRejected("NFC target against NFD source", self.edit(precomposed), "the \(decomposed) opened", .noLiteralMatch)
        self.expectRejected("NFD target against NFC source", self.edit(decomposed), "the \(precomposed) opened", .noLiteralMatch)
    }

    private static func testBothContextsMustMatchTogether() {
        // " said" follows the first occurrence; "said " precedes the second.
        // Supplying the right context of one and the left of the other
        // matches neither candidate: contradiction, not a partial match.
        self.expectRejected("left/right from different candidates", self.edit("the accused", left: "said ", right: " said"), self.twice, .contextMatchesNoCandidate)
        // Both sides matching the same candidate resolves.
        self.expectResolved("left and right agree", self.edit("the accused", left: "said ", right: " left"), self.twice, at: 17, basis: .contextOnly)
    }

    private static func testNegativeOccurrenceIsInvalid() {
        self.expectRejected("negative on repeated", self.edit("the accused", occurrence: -1), self.twice, .occurrenceOutOfRange(occurrence: -1, candidateCount: 2))
        self.expectRejected("negative on unique", self.edit("confirmed", occurrence: -1), self.unique, .occurrenceOutOfRange(occurrence: -1, candidateCount: 1))
        self.expectRejected("Int.min never crashes", self.edit("the accused", occurrence: Int.min), self.twice, .occurrenceOutOfRange(occurrence: Int.min, candidateCount: 2))
        self.expectRejected("Int.max never crashes", self.edit("the accused", occurrence: Int.max), self.twice, .occurrenceOutOfRange(occurrence: Int.max, candidateCount: 2))
    }

    private static func testInvalidOccurrenceOnUniqueSourceNeverRescuedByContext() {
        // The context is correct, but the explicit occurrence contradicts the
        // unique match. V1.5 row 3: reject -- never silently ignored.
        self.expectRejected("unique + bad occurrence + good context", self.edit("confirmed", occurrence: 2, left: "witness "), self.unique, .occurrenceOutOfRange(occurrence: 2, candidateCount: 1))
    }

    // MARK: - V1.6: overlapping literal occurrences

    private static func testOverlappingOccurrencesAreAllEnumerated() {
        let starts = { (needle: String, haystack: String) in
            IntelligenceAddressingResolver.literalOccurrences(of: Array(needle.utf16), in: Array(haystack.utf16)).map(\.location)
        }
        precondition(starts("aa", "aaa") == [0, 1], "overlapping matches must all be found")
        precondition(starts("aa", "aaaa") == [0, 1, 2])
        precondition(starts("aba", "ababa") == [0, 2])
        precondition(starts("the", "the the the") == [0, 4, 8])
        precondition(starts("x", "abc").isEmpty)
        precondition(starts("abc", "ab").isEmpty)
        precondition(starts("", "abc").isEmpty)
        precondition(starts("abc", "abc") == [0])
    }

    private static func testOverlappingCandidatesAreNotTreatedAsUnique() {
        // The experimental non-overlapping scan reported ONE occurrence of
        // "aa" in "aaa" and would have silently resolved it to 0. There are
        // two valid literal positions: bare reference must reject.
        self.expectRejected("aa in aaa, bare", self.edit("aa"), "aaa", .ambiguousCandidates(count: 2))
        // With the source correctly seen as repeated, occurrence 1 simply
        // selects the first candidate.
        self.expectResolved("aa in aaa, occurrence 1", self.edit("aa", occurrence: 1), "aaa", at: 0, basis: .occurrence)
        self.expectRejected("aa in aaa, occurrence 3", self.edit("aa", occurrence: 3), "aaa", .occurrenceOutOfRange(occurrence: 3, candidateCount: 2))
    }

    private static func testOverlappingCandidatesAddressableByOccurrence() {
        self.expectResolved("aa in aaa, occurrence 2", self.edit("aa", occurrence: 2), "aaa", at: 1, basis: .occurrence)
        self.expectResolved("aba in ababa, occurrence 2", self.edit("aba", occurrence: 2), "ababa", at: 2, basis: .occurrence)
    }

    private static func testOverlappingCandidatesAddressableByContext() {
        // Candidates of "aa" in "baaac": 1 and 2. Left context "b" only
        // matches the candidate at 1; right context "c" only matches 2.
        self.expectResolved("overlap by left context", self.edit("aa", left: "b"), "baaac", at: 1, basis: .contextOnly)
        self.expectResolved("overlap by right context", self.edit("aa", right: "c"), "baaac", at: 2, basis: .contextOnly)
    }

    // MARK: - V1.6: context zero / one / multi match

    private static func testContextZeroMatchRejectsOnUniqueSource() {
        self.expectRejected("zero-match on unique", self.edit("confirmed", right: " never appears"), self.unique, .contextMatchesNoCandidate)
    }

    private static func testContextZeroMatchRejectsEvenWithValidOccurrence() {
        self.expectRejected("zero-match on repeated, valid occurrence", self.edit("the accused", occurrence: 1, left: "nobody "), self.twice, .contextMatchesNoCandidate)
        // ...and with a valid occurrence on a unique source too.
        self.expectRejected("zero-match on unique, valid occurrence", self.edit("confirmed", occurrence: 1, right: " never appears"), self.unique, .contextMatchesNoCandidate)
    }

    private static func testContextZeroMatchRejectsWithInvalidOccurrence() {
        self.expectRejected("zero-match, invalid occurrence", self.edit("the accused", occurrence: 9, left: "nobody "), self.twice, .contextMatchesNoCandidate)
    }

    private static func testContextOneMatchIsInformative() {
        // Alone: selects the candidate. With an invalid occurrence: rescues.
        // With a disagreeing valid occurrence: contradiction.
        self.expectResolved("one-match alone", self.edit("the accused", left: "said "), self.twice, at: 17, basis: .contextOnly)
        self.expectResolved("one-match rescues invalid occurrence", self.edit("the accused", occurrence: 0, left: "said "), self.twice, at: 17, basis: .contextFallbackForInvalidOccurrence)
        self.expectRejected("one-match vs disagreeing occurrence", self.edit("the accused", occurrence: 1, left: "said "), self.twice, .occurrenceContradictsContext)
    }

    private static func testContextMultiMatchIncludingOccurrenceStillResolves() {
        // Both candidates are followed by " left"; context is uninformative
        // for narrowing but does not contradict a valid occurrence.
        let source = "the accused left, the accused left again."
        self.expectResolved("multi-match includes occurrence 1", self.edit("the accused", occurrence: 1, right: " left"), source, at: 0, basis: .occurrenceWithNonNarrowingContext)
        self.expectResolved("multi-match includes occurrence 2", self.edit("the accused", occurrence: 2, right: " left"), source, at: 18, basis: .occurrenceWithNonNarrowingContext)
    }

    private static func testContextMultiMatchExcludingOccurrenceRejects() {
        // Three "ab" candidates (1, 5, 9); left context "x" matches the
        // first two only; occurrence 3 names a candidate the context excludes.
        let source = "xab xab yab"
        self.expectResolved("baseline: occurrence 3 alone", self.edit("ab", occurrence: 3), source, at: 9, basis: .occurrence)
        self.expectRejected("multi-match excluding occurrence", self.edit("ab", occurrence: 3, left: "x"), source, .occurrenceContradictsContext)
    }

    private static func testContextMultiMatchWithInvalidOccurrenceIsAmbiguous() {
        let source = "xab xab yab"
        self.expectRejected("multi-match, invalid occurrence", self.edit("ab", occurrence: 9, left: "x"), source, .ambiguousCandidates(count: 2))
    }

    private static func testContextMultiMatchAloneIsAmbiguous() {
        let source = "xab xab yab"
        self.expectRejected("multi-match alone", self.edit("ab", left: "x"), source, .ambiguousCandidates(count: 2))
    }

    // MARK: - Determinism

    private static func testResolutionIsPureAndRepeatable() {
        let e = self.edit("the accused", occurrence: 2, right: " left")
        let first = self.resolve(e, self.twice)
        for _ in 0..<50 {
            precondition(self.resolve(e, self.twice) == first, "resolution must be a pure function of (edit, source)")
        }
        // A different edit resolved in between cannot affect it.
        _ = self.resolve(self.edit("said"), self.twice)
        precondition(self.resolve(e, self.twice) == first)
    }

    private static func testRejectionsCarryNoTranscriptText() {
        // Compile-time-ish guarantee documented as a runtime check: the
        // description of every rejection contains only counts/ordinals.
        let secret = "CONFIDENTIAL-STATEMENT"
        let source = "\(secret) and \(secret)"
        for edit in [
            self.edit(secret),
            self.edit(secret, occurrence: 7),
            self.edit(secret, occurrence: 1, left: "nope"),
            self.edit("absent-text"),
        ] {
            guard case let .failure(reason) = self.resolve(edit, source) else { preconditionFailure("expected rejection") }
            precondition(!String(describing: reason).contains(secret), "rejection must not echo transcript text")
        }
    }
}
