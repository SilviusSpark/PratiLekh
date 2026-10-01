import Foundation

/// Focused unit coverage for `AutonomousPermissionGate` itself -- called
/// directly, not through `IntelligenceSafetyAuthority`, so each of the five
/// validated rules (P-A, P-B, W-A1, C-A2, C-C) can be tested in isolation
/// with an exact expected `AutonomousPermissionBlock` reason. Integration
/// with the Authority is covered separately in
/// `IntelligenceSafetyAuthorityTests`/`IntelligenceEditCompositionTests`, and
/// exact reproduction of the V1.14/V1.15 findings is covered separately in
/// `AutonomousPermissionGateProductionParityTests`.
@main
enum AutonomousPermissionGateTests {
    static func main() {
        testPunctuationAllowlistBlocksNonRoutineMarks()
        testPunctuationAllowlistAllowsRoutineMarks()
        testIntraTokenPunctuationBlocked()
        testPunctuationBetweenNonWordFormingNeighborsAllowed()
        testPunctuationRunStraddlingTheEditBoundaryIsConsidered()

        testMergeOnlyWhitespaceBlocksWordMerge()
        testSplittingWhitespaceIsNeverBlocked()
        testCollapsingRepeatedWhitespaceIsNeverBlocked()
        testWhitespaceWithNonWordFormingNeighborIsNeverBlocked()
        testNewlineAdjacentWhitespaceIsNeverTreatedAsMergeable()

        testAcronymCapitalizationLoweringBlocked()
        testSingleCapitalRaisingNeverBlocked()
        testSingleCapitalLoweringOutsideAnAcronymNeverBlocked()
        testIdentifierCapitalizationChangeBlocked()
        testAcronymTokenExtendsOutsideTheEditedSpan()
        testDesignatorSingleUppercaseLetterIsNotBlocked()

        testGateNeverConsultedForOtherClassification()
        testBoundedScanFailsClosedOnPathologicalInput()
        testUnicodeOdiaAndDevanagariAreWordForming()

        print("PASS: AutonomousPermissionGate rule-by-rule adversarial and positive-control suite")
    }

    // MARK: - Helpers

    private static func swiftRange(_ substring: String, in source: String, occurrence: Int = 1) -> Range<String.Index> {
        var searchStart = source.startIndex
        var found = 0
        while let range = source.range(of: substring, range: searchStart..<source.endIndex) {
            found += 1
            if found == occurrence { return range }
            searchStart = range.upperBound
        }
        preconditionFailure("'\(substring)' occurrence \(occurrence) not found in \(source.debugDescription)")
    }

    private static func block(
        _ classification: IntelligenceEditClassification,
        _ source: String,
        target: String,
        to replacement: String,
        occurrence: Int = 1
    ) -> AutonomousPermissionBlock? {
        AutonomousPermissionGate.block(
            classification: classification,
            source: source,
            range: self.swiftRange(target, in: source, occurrence: occurrence),
            expectedSourceText: target,
            replacementText: replacement
        )
    }

    // MARK: - P-A: routine-punctuation allowlist

    private static func testPunctuationAllowlistBlocksNonRoutineMarks() {
        for (source, target, replacement) in [
            ("Hon'ble Court", "'", ""),
            ("filed u/s the Act", "/", ""),
            ("paid Rs.5,000/-", "/-", ""),
            ("the email a@b.com", "@", ""),
            ("the firm S&P", "&", ""),
        ] {
            precondition(self.block(.punctuationOnly, source, target: target, to: replacement) == .nonRoutinePunctuationChanged, "\(source.debugDescription)")
        }
    }

    private static func testPunctuationAllowlistAllowsRoutineMarks() {
        for (source, target, replacement) in [
            ("the witness stated the following.", "stated", "stated,"),
            ("the accused was present,", ",", "."),
            ("wait the argument continued", "wait", "wait;"),
            ("आरोपी उपस्थित था", "था", "था।"),
        ] {
            precondition(self.block(.punctuationOnly, source, target: target, to: replacement) == nil, "\(source.debugDescription)")
        }
    }

    // MARK: - P-B: no intra-token punctuation change

    private static func testIntraTokenPunctuationBlocked() {
        for (source, target, replacement) in [
            ("Hon'ble Court reserved orders", "'", ""),
            ("filed u/s the Act", "/", ""),
            ("the witness S.K. Das deposed", ".", ""), // between S and K, both letters
            ("co-operate fully", "-", ""),
        ] {
            let result = self.block(.punctuationOnly, source, target: target, to: replacement)
            precondition(result == .intraTokenPunctuationChanged || result == .nonRoutinePunctuationChanged, "\(source.debugDescription): \(String(describing: result))")
        }
    }

    private static func testPunctuationBetweenNonWordFormingNeighborsAllowed() {
        // A sentence-terminal insertion: the right neighbour is the end of
        // the document (no word-forming scalar there at all).
        precondition(self.block(.punctuationOnly, "the accused was present", target: "present", to: "present.") == nil)
        // A space (not word-forming) sits on the right: inserting a comma
        // right after a word but before a space is not intra-token.
        precondition(self.block(.punctuationOnly, "the witness stated the truth", target: "stated", to: "stated,") == nil)
    }

    private static func testPunctuationRunStraddlingTheEditBoundaryIsConsidered() {
        // The proposal targets only the SECOND comma of "word,,rest"; the
        // untouched first comma is adjacent and still part of the same
        // affected run once the second is removed -- P-A/P-B must see it.
        let source = "word,,rest"
        let secondComma = self.swiftRange(",", in: source, occurrence: 2)
        let result = AutonomousPermissionGate.block(classification: .punctuationOnly, source: source, range: secondComma, expectedSourceText: ",", replacementText: "")
        precondition(result == .intraTokenPunctuationChanged, "\(String(describing: result))")
    }

    // MARK: - W-A1: merge-only whitespace blocking

    private static func testMergeOnlyWhitespaceBlocksWordMerge() {
        for (source, target, replacement) in [
            ("the accused Ram Das denied it", " ", ""),
            ("the OD 02 vehicle", " ", ""),
        ] {
            let range = self.swiftRange(target, in: source, occurrence: source == "the accused Ram Das denied it" ? 3 : 2)
            let result = AutonomousPermissionGate.block(classification: .whitespaceOnly, source: source, range: range, expectedSourceText: target, replacementText: replacement)
            precondition(result == .wordBoundaryMerged, "\(source.debugDescription): \(String(describing: result))")
        }
    }

    private static func testSplittingWhitespaceIsNeverBlocked() {
        // Inserting whitespace (a split) is deliberately out of scope, even
        // though it superficially resembles the merge case reversed.
        let source = "Theinformant lodged a complaint"
        let range = source.startIndex..<source.index(source.startIndex, offsetBy: 0)
        precondition(AutonomousPermissionGate.block(classification: .whitespaceOnly, source: source, range: range, expectedSourceText: "", replacementText: " ") == nil)
    }

    private static func testCollapsingRepeatedWhitespaceIsNeverBlocked() {
        // Deleting ONE space of the double space between "accused" and "was",
        // leaving one behind, is not a merge: the gap never fully closes.
        let source = "the accused  was present"
        let doubleSpace = self.swiftRange("  ", in: source)
        let firstOfTheTwoSpaces = doubleSpace.lowerBound..<source.index(after: doubleSpace.lowerBound)
        precondition(AutonomousPermissionGate.block(classification: .whitespaceOnly, source: source, range: firstOfTheTwoSpaces, expectedSourceText: " ", replacementText: "") == nil)
    }

    private static func testWhitespaceWithNonWordFormingNeighborIsNeverBlocked() {
        // "stated, the" -> deleting the space after the comma: the left
        // neighbour is punctuation, not word-forming.
        let source = "the witness stated, the truth"
        let range = self.swiftRange(" ", in: source, occurrence: 3)
        precondition(AutonomousPermissionGate.block(classification: .whitespaceOnly, source: source, range: range, expectedSourceText: " ", replacementText: "") == nil)
    }

    private static func testNewlineAdjacentWhitespaceIsNeverTreatedAsMergeable() {
        // A newline immediately adjacent to the edit is a hard boundary --
        // it is never mergeable content, so no merge can be established here
        // regardless of the rest of the gap.
        // The SECOND space -- immediately after the newline, before "word" --
        // is the one under test: scanning left from it hits the newline
        // first, which is not mergeable whitespace, so no word-forming left
        // anchor is ever found and this can never be classified as a merge.
        let source = "line one\n word"
        let range = self.swiftRange(" ", in: source, occurrence: 2)
        precondition(AutonomousPermissionGate.block(classification: .whitespaceOnly, source: source, range: range, expectedSourceText: " ", replacementText: "") == nil)
    }

    // MARK: - C-A2: acronym capitalization guard

    private static func testAcronymCapitalizationLoweringBlocked() {
        for (source, target, replacement) in [
            ("charged under IPC", "IPC", "ipc"),
            ("tried under CrPC", "CrPC", "crpc"),
            ("the report of the FSL", "FSL", "fsl"),
            ("under BNSS as stated", "BNSS", "Bnss"),
        ] {
            precondition(self.block(.capitalizationOnly, source, target: target, to: replacement) == .acronymCapitalizationLowered, "\(source.debugDescription)")
        }
    }

    private static func testSingleCapitalRaisingNeverBlocked() {
        precondition(self.block(.capitalizationOnly, "the accused was present.", target: "the", to: "The") == nil)
        precondition(self.block(.capitalizationOnly, "ram das denied it", target: "ram das", to: "Ram Das") == nil)
    }

    private static func testSingleCapitalLoweringOutsideAnAcronymNeverBlocked() {
        // A single uppercase letter has no "acronym" to speak of (<2
        // uppercase letters in its token) -- this is the documented,
        // deliberately out-of-scope designator/single-letter residual.
        precondition(self.block(.capitalizationOnly, "the document Ext. P applies", target: "P", to: "p") == nil)
    }

    // MARK: - C-C: digit-bearing identifier guard

    private static func testIdentifierCapitalizationChangeBlocked() {
        for (source, target, replacement) in [
            ("the exhibit P9 was marked", "P9", "p9"),
            ("the flat is 4B in the block", "B", "b"),
            ("CRLMC No. 1234 of 2021", "CRLMC", "crlmc"), // also an acronym, but C-C applies regardless of digits elsewhere in the text
        ] {
            let result = self.block(.capitalizationOnly, source, target: target, to: replacement)
            precondition(result == .identifierCapitalizationChanged || result == .acronymCapitalizationLowered, "\(source.debugDescription): \(String(describing: result))")
        }
        // A raise in a digit-bearing token is blocked too (C-C is not
        // direction-specific, unlike C-A2).
        precondition(self.block(.capitalizationOnly, "the exhibit p9 was marked", target: "p9", to: "P9") == .identifierCapitalizationChanged)
    }

    private static func testAcronymTokenExtendsOutsideTheEditedSpan() {
        // The proposal targets only the middle letter of "CrPC"; the token's
        // remaining letters are OUTSIDE expectedSourceText, in the untouched
        // source, and must still be counted.
        let source = "tried under CrPC as stated"
        let range = self.swiftRange("P", in: source)
        let result = AutonomousPermissionGate.block(classification: .capitalizationOnly, source: source, range: range, expectedSourceText: "P", replacementText: "p")
        precondition(result == .acronymCapitalizationLowered, "\(String(describing: result))")
    }

    private static func testDesignatorSingleUppercaseLetterIsNotBlocked() {
        // Documented, deliberately unresolved residual (V1.14 §8 / V1.15
        // §8): a single-letter designator flanked by a non-word-forming
        // space on one side has no acronym or digit in its own token.
        let source = "the document Ext. P-9 was proved"
        let range = self.swiftRange("P", in: source)
        precondition(AutonomousPermissionGate.block(classification: .capitalizationOnly, source: source, range: range, expectedSourceText: "P", replacementText: "p") == nil)
    }

    // MARK: - Never consulted for .other; bounded scan fails closed; Unicode

    private static func testGateNeverConsultedForOtherClassification() {
        // Defensive only: the Authority never calls the gate for `.other`,
        // but the gate itself must not crash or misbehave if it were.
        let source = "charged under IPC for murder"
        let range = self.swiftRange("IPC", in: source)
        precondition(AutonomousPermissionGate.block(classification: .other, source: source, range: range, expectedSourceText: "IPC", replacementText: "CrPC") == nil)
    }

    private static func testBoundedScanFailsClosedOnPathologicalInput() {
        // A run of more than the scan bound's worth of word-forming scalars
        // with no natural boundary: the true token extent cannot be
        // established within the bound, so this fails closed to a block --
        // never to permission -- even though no acronym/identifier shape was
        // actually confirmed.
        let longRun = String(repeating: "a", count: 200)
        let source = longRun + "B" + longRun
        let range = self.swiftRange("B", in: source)
        let result = AutonomousPermissionGate.block(classification: .capitalizationOnly, source: source, range: range, expectedSourceText: "B", replacementText: "b")
        precondition(result != nil, "exceeding the boundary-scan bound must never imply permission")

        // Likewise for the merge rule: a whitespace gap longer than the
        // bound must fail closed to a block, not be treated as "not a merge".
        let longSpaces = String(repeating: " ", count: 200)
        let mergeSource = "word1" + longSpaces + "word2"
        let target = self.swiftRange(longSpaces, in: mergeSource)
        let mergeResult = AutonomousPermissionGate.block(classification: .whitespaceOnly, source: mergeSource, range: target, expectedSourceText: longSpaces, replacementText: "")
        precondition(mergeResult == .wordBoundaryMerged, "\(String(describing: mergeResult))")
    }

    private static func testUnicodeOdiaAndDevanagariAreWordForming() {
        let odiaSource = "\u{0B27}\u{0B3E}\u{0B30}\u{0B3E} \u{0B69}\u{0B70}\u{0B69}"
        precondition(AutonomousPermissionGate.block(
            classification: .whitespaceOnly,
            source: odiaSource,
            range: self.swiftRange(" ", in: odiaSource),
            expectedSourceText: " ",
            replacementText: ""
        ) == .wordBoundaryMerged, "Odia scalars must be recognized as word-forming for the merge rule")

        let devanagariSource = "\u{0927}\u{093E}\u{0930}\u{093E} \u{0967}\u{0968}\u{0969}"
        precondition(AutonomousPermissionGate.block(
            classification: .whitespaceOnly,
            source: devanagariSource,
            range: self.swiftRange(" ", in: devanagariSource),
            expectedSourceText: " ",
            replacementText: ""
        ) == .wordBoundaryMerged, "Devanagari scalars must be recognized as word-forming for the merge rule")
    }
}
