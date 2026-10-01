import Foundation

/// Adversarial and positive-control coverage for `IntelligenceSafetyAuthority`.
/// The governing question every test here answers: can an untrusted,
/// possibly incorrect, malformed, misleading, stale, conflicting, or
/// adversarial proposal ever cause an unsafe edit to reach `resultingText`?
/// The required answer, everywhere, is no.
@main
enum IntelligenceSafetyAuthorityTests {
    static func main() {
        testInvalidRangeNegativeLocation()
        testInvalidRangeOutOfBounds()
        testInvalidRangeOverflowAttemptDoesNotCrash()
        testRangeSplittingSurrogatePairFailsSafely()
        testSourceTextMismatchStaleProposal()
        testShiftedProposalIsNotRelocated()
        testNoOpProposalRejected()

        testMislabeledPunctuationHidingStatuteChangeRejected()
        testMislabeledCapitalizationHidingStatuteChangeRejected()
        testMislabeledWhitespaceHidingWordDeletionRejected()

        testEditEntirelyOutsideProtectedSpanIsUnaffected()
        testEditEntirelyInsideProtectedSpanIsBlocked()
        testEditExactlyMatchingProtectedSpanIsBlocked()
        testEditBeginningOutsideEndingInsideIsBlocked()
        testEditBeginningInsideEndingOutsideIsBlocked()
        testZeroLengthInsertionImmediatelyBeforeProtectedSpanIsAllowed()
        testZeroLengthInsertionImmediatelyAfterProtectedSpanIsAllowed()
        testZeroLengthInsertionStrictlyInsideProtectedSpanIsBlocked()
        testMultipleProtectedSpansEachBlockTheirOwnRegion()
        testOverlappingProtectedSpansMostRestrictiveWins()

        testChangeStatutoryNumberInsideResolvedSpanRejected()
        testChangeDateInsideIndependentlyProtectedSpanIsReviewOnlyNotApplied()
        testChangeAmountInsideIndependentlyProtectedSpanIsReviewOnlyNotApplied()
        testChangeNameInsideIndependentlyProtectedSpanIsReviewOnlyNotApplied()
        testDeleteProtectedContentRejected()
        testInsertionInsideProtectedContentRejected()
        testRewriteAroundProtectionRejected()
        testClassificationSafeEditOverlappingResolvedSpanIsStillBlocked()

        testUnresolvedSpanNeverAutonomouslyCorrected()
        testResolvedAndUnresolvedProduceDistinctDispositions()

        testOverlappingProposalsBothRejected()
        testInputOrderDoesNotGrantOverlapAuthority()
        testIdenticalRangeIdenticalReplacementBothRejected()
        testIdenticalRangeConflictingReplacementsBothRejected()
        testNestedProposalsBothRejected()
        testAdjacentProposalsAreIndependentNotOverlapping()
        testDuplicateProposalIDsDoNotGrantSpecialTreatment()
        testValidProposalSurvivesUnsafeSiblingInSameBatch()

        testResultingTextIsOrderIndependentForDisjointSafeProposals()

        testSafeCommaInsertionOutsideProtectedSpanIsApplied()
        testSafeFullStopReplacementIsApplied()
        testSafeCapitalizationCorrectionIsApplied()
        testSafeWhitespaceCleanupIsApplied()
        testMultipleSafeEditsAppliedTogetherProduceCorrectFinalText()

        testAutonomousPermissionGateDowngradesWordMergeToReviewOnly()
        testAutonomousPermissionGateNeverConsultedForUnsupportedCategory()
        testAutonomousPermissionGateAndProtectedSpansAreIndependentLayers()

        print("PASS: IntelligenceSafetyAuthority adversarial and positive-control suite")
    }

    // MARK: - Test fixture helpers (test-only; not part of the production API)

    private static func range(of substring: String, in text: String) -> NSRange {
        let range = (text as NSString).range(of: substring)
        precondition(range.location != NSNotFound, "test fixture error: '\(substring)' not found in '\(text)'")
        return range
    }

    private static func proposal(
        id: String = "p",
        range: NSRange,
        expected: String,
        replacement: String,
        claimed: IntelligenceEditCategory = .other
    ) -> IntelligenceProposal {
        IntelligenceProposal(id: id, range: range, expectedSourceText: expected, replacementText: replacement, claimedCategory: claimed)
    }

    private static func validate(
        _ proposals: [IntelligenceProposal],
        source: String,
        protectedSpans: [ProtectedSpan] = []
    ) -> IntelligenceSafetyAuthority.Result {
        IntelligenceSafetyAuthority.validate(proposals: proposals, source: source, protectedSpans: protectedSpans)
    }

    // MARK: - Structural / range safety

    private static func testInvalidRangeNegativeLocation() {
        let source = "the accused appeared"
        let bad = IntelligenceProposal(
            id: "p1",
            range: NSRange(location: -1, length: 3),
            expectedSourceText: "the",
            replacementText: "The",
            claimedCategory: .capitalization
        )
        let result = self.validate([bad], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.invalidRange))
        precondition(result.resultingText == source)
    }

    private static func testInvalidRangeOutOfBounds() {
        let source = "short"
        let bad = self.proposal(range: NSRange(location: 3, length: 10), expected: "ort??????", replacement: "ORT??????")
        let result = self.validate([bad], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.invalidRange))
        precondition(result.resultingText == source)
    }

    private static func testInvalidRangeOverflowAttemptDoesNotCrash() {
        let source = "short"
        let bad = self.proposal(range: NSRange(location: Int.max - 1, length: Int.max - 1), expected: "x", replacement: "y")
        let result = self.validate([bad], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.invalidRange))
        precondition(result.resultingText == source)
    }

    private static func testRangeSplittingSurrogatePairFailsSafely() {
        // Foundation's `Range(_:in:)` does not return nil for a range that
        // splits a surrogate pair -- empirically, it rounds to the nearest
        // valid `String.Index` boundary (verified directly against this
        // Swift/Foundation revision) rather than failing the conversion.
        // The safety net that actually catches this adversarial case is the
        // exact `expectedSourceText` comparison: whatever text the rounded
        // range resolves to will not equal what the proposal claimed, so it
        // is rejected as a source-text mismatch -- deterministically, and
        // without ever indexing the string unsafely or crashing. This test
        // exists to pin that verified behavior, not an assumption about it.
        let source = "Sworn \u{1F64F} before the court"
        let emojiRange = self.range(of: "\u{1F64F}", in: source)
        precondition(emojiRange.length == 2, "the emoji must be a surrogate pair for this test to be meaningful")
        // Deliberately points at only the first UTF-16 code unit of the pair.
        let malformed = self.proposal(range: NSRange(location: emojiRange.location, length: 1), expected: "\u{1F64F}", replacement: "!")
        let result = self.validate([malformed], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.sourceTextMismatch), "\(result.outcomes[0].disposition)")
        precondition(result.resultingText == source, "no crash, and the source is never mutated by a rejected proposal")
    }

    private static func testSourceTextMismatchStaleProposal() {
        let source = "the accused shall appear on 16 March 2026"
        let stale = self.proposal(range: self.range(of: "16 March", in: source), expected: "15 March", replacement: "16 March")
        let result = self.validate([stale], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.sourceTextMismatch))
        precondition(result.resultingText == source)
    }

    private static func testShiftedProposalIsNotRelocated() {
        // "IPC" genuinely exists in the source, but not at the range this
        // proposal names -- the authority must reject, never search the
        // source for a location where "IPC" would match.
        let source = "Filed under IPC, tried under CrPC."
        let shifted = self.proposal(range: self.range(of: "CrPC", in: source), expected: "IPC", replacement: "IPC-amended")
        let result = self.validate([shifted], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.sourceTextMismatch))
        precondition(result.resultingText == source)
    }

    private static func testNoOpProposalRejected() {
        let source = "unchanged text"
        let noOp = self.proposal(range: self.range(of: "unchanged", in: source), expected: "unchanged", replacement: "unchanged")
        let result = self.validate([noOp], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.noOpProposal))
        precondition(result.resultingText == source)
    }

    // MARK: - Never trust the claimed category

    private static func testMislabeledPunctuationHidingStatuteChangeRejected() {
        let source = "charged under IPC for the offence."
        let mislabeled = self.proposal(range: self.range(of: "IPC", in: source), expected: "IPC", replacement: "CrPC", claimed: .punctuation)
        let result = self.validate([mislabeled], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    private static func testMislabeledCapitalizationHidingStatuteChangeRejected() {
        let source = "tried under the BNS for the offence."
        let mislabeled = self.proposal(range: self.range(of: "BNS", in: source), expected: "BNS", replacement: "BNSS", claimed: .capitalization)
        let result = self.validate([mislabeled], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    private static func testMislabeledWhitespaceHidingWordDeletionRejected() {
        let source = "the accused shall pay the fine amount."
        let mislabeled = self.proposal(range: self.range(of: "pay the fine", in: source), expected: "pay the fine", replacement: "pay fine", claimed: .whitespace)
        let result = self.validate([mislabeled], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    // MARK: - Protected-span boundary semantics (exhaustive)

    private static func syntheticSource() -> String { "ABCDEFGHIJ" }

    private static func testEditEntirelyOutsideProtectedSpanIsUnaffected() {
        let source = self.syntheticSource()
        let protected = [ProtectedSpan(range: self.range(of: "DEFGH", in: source), kind: .deterministicallyResolved)]
        // "J," at the very end of the document, not "B," mid-run: inserting
        // punctuation directly between two letters with nothing else nearby
        // is exactly the intra-token shape `AutonomousPermissionGate` (V1.16)
        // now blocks (P-B); at the document's end there is no letter on the
        // right to complete that shape, so this stays a genuinely safe edit.
        let safe = self.proposal(range: self.range(of: "J", in: source), expected: "J", replacement: "J,", claimed: .punctuation)
        let result = self.validate([safe], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.punctuationOnly))
        precondition(result.resultingText == "ABCDEFGHIJ,", result.resultingText)
    }

    private static func testEditEntirelyInsideProtectedSpanIsBlocked() {
        let source = self.syntheticSource()
        let protected = [ProtectedSpan(range: self.range(of: "DEFGH", in: source), kind: .deterministicallyResolved)]
        let inside = self.proposal(range: self.range(of: "EF", in: source), expected: "EF", replacement: "ef", claimed: .capitalization)
        let result = self.validate([inside], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testEditExactlyMatchingProtectedSpanIsBlocked() {
        let source = self.syntheticSource()
        let spanRange = self.range(of: "DEFGH", in: source)
        let protected = [ProtectedSpan(range: spanRange, kind: .deterministicallyResolved)]
        let exact = self.proposal(range: spanRange, expected: "DEFGH", replacement: "defgh", claimed: .capitalization)
        let result = self.validate([exact], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testEditBeginningOutsideEndingInsideIsBlocked() {
        let source = self.syntheticSource()
        let protected = [ProtectedSpan(range: self.range(of: "DEFGH", in: source), kind: .deterministicallyResolved)]
        let straddling = self.proposal(range: self.range(of: "BCD", in: source), expected: "BCD", replacement: "bcd", claimed: .capitalization)
        let result = self.validate([straddling], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testEditBeginningInsideEndingOutsideIsBlocked() {
        let source = self.syntheticSource()
        let protected = [ProtectedSpan(range: self.range(of: "DEFGH", in: source), kind: .deterministicallyResolved)]
        let straddling = self.proposal(range: self.range(of: "GHI", in: source), expected: "GHI", replacement: "ghi", claimed: .capitalization)
        let result = self.validate([straddling], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testZeroLengthInsertionImmediatelyBeforeProtectedSpanIsAllowed() {
        let source = self.syntheticSource()
        let spanRange = self.range(of: "DEFGH", in: source)
        let protected = [ProtectedSpan(range: spanRange, kind: .deterministicallyResolved)]
        // A whitespace SPLIT (empty -> non-empty), not a punctuation insertion
        // between two letters: the latter is exactly the intra-token shape
        // `AutonomousPermissionGate` (V1.16) now blocks (P-B), and splitting a
        // token is deliberately never blocked (merge-only, W-A1) -- this keeps
        // the edit itself genuinely safe so the test still isolates the span-
        // boundary question ("touching" a span from outside is not
        // intersecting it) from gate policy.
        let insertion = self.proposal(
            range: NSRange(location: spanRange.location, length: 0),
            expected: "",
            replacement: " ",
            claimed: .whitespace
        )
        let result = self.validate([insertion], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.whitespaceOnly))
        precondition(result.resultingText == "ABC DEFGHIJ", result.resultingText)
    }

    private static func testZeroLengthInsertionImmediatelyAfterProtectedSpanIsAllowed() {
        let source = self.syntheticSource()
        let spanRange = self.range(of: "DEFGH", in: source)
        let protected = [ProtectedSpan(range: spanRange, kind: .deterministicallyResolved)]
        let insertion = self.proposal(
            range: NSRange(location: spanRange.location + spanRange.length, length: 0),
            expected: "",
            replacement: " ",
            claimed: .whitespace
        )
        let result = self.validate([insertion], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.whitespaceOnly))
        precondition(result.resultingText == "ABCDEFGH IJ", result.resultingText)
    }

    private static func testZeroLengthInsertionStrictlyInsideProtectedSpanIsBlocked() {
        let source = self.syntheticSource()
        let spanRange = self.range(of: "DEFGH", in: source)
        let protected = [ProtectedSpan(range: spanRange, kind: .deterministicallyResolved)]
        let insertion = self.proposal(
            range: NSRange(location: spanRange.location + 2, length: 0),
            expected: "",
            replacement: ",",
            claimed: .punctuation
        )
        let result = self.validate([insertion], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testMultipleProtectedSpansEachBlockTheirOwnRegion() {
        let source = self.syntheticSource()
        let protected = [
            ProtectedSpan(range: self.range(of: "AB", in: source), kind: .deterministicallyResolved),
            ProtectedSpan(range: self.range(of: "IJ", in: source), kind: .deterministicallyResolved),
        ]
        let hitsFirst = self.proposal(range: self.range(of: "A", in: source), expected: "A", replacement: "a", claimed: .capitalization)
        let hitsSecond = self.proposal(range: self.range(of: "J", in: source), expected: "J", replacement: "j", claimed: .capitalization)
        // A whitespace split, not a capitalization edit: `syntheticSource()`
        // is one continuous run of letters, so ANY lowering edit within it is
        // (correctly) an acronym-shaped, `AutonomousPermissionGate`-blocked
        // token (V1.16, C-A2) -- irrelevant to what this test isolates (that a
        // protected span never affects a region outside itself), so the
        // "hits neither" probe uses an edit shape the gate never touches.
        let hitsNeither = self.proposal(range: self.range(of: "F", in: source), expected: "F", replacement: "F ", claimed: .whitespace)
        let result = self.validate([hitsFirst, hitsSecond, hitsNeither], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.outcomes[1].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.outcomes[2].disposition == .autonomouslyAccepted(.whitespaceOnly))
        precondition(result.resultingText == "ABCDEF GHIJ", result.resultingText)
    }

    private static func testOverlappingProtectedSpansMostRestrictiveWins() {
        let source = self.syntheticSource()
        // "DEFG" is independently-protected; the narrower "FG" nested inside
        // it is separately, more restrictively, deterministically resolved.
        let protected = [
            ProtectedSpan(range: self.range(of: "DEFG", in: source), kind: .independentlyProtected),
            ProtectedSpan(range: self.range(of: "FG", in: source), kind: .deterministicallyResolved),
        ]
        let touchesBoth = self.proposal(range: self.range(of: "F", in: source), expected: "F", replacement: "f", claimed: .capitalization)
        let result = self.validate([touchesBoth], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    // MARK: - Realistic legal-content hostile suite

    private static func testChangeStatutoryNumberInsideResolvedSpanRejected() {
        let source = "Convicted under Section 302 IPC as charged."
        let citation = self.range(of: "Section 302 IPC", in: source)
        let protected = [ProtectedSpan(range: citation, kind: .deterministicallyResolved)]
        let attack = self.proposal(range: self.range(of: "302", in: source), expected: "302", replacement: "304", claimed: .other)
        let result = self.validate([attack], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testChangeDateInsideIndependentlyProtectedSpanIsReviewOnlyNotApplied() {
        let source = "The accused was arrested on 16 March 2026 near the market."
        let dateRange = self.range(of: "16 March 2026", in: source)
        let protected = [ProtectedSpan(range: dateRange, kind: .independentlyProtected)]
        let attack = self.proposal(range: dateRange, expected: "16 March 2026", replacement: "15 March 2026", claimed: .other)
        let result = self.validate([attack], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(result.resultingText == source, "a review-only disposition must never be applied")
    }

    private static func testChangeAmountInsideIndependentlyProtectedSpanIsReviewOnlyNotApplied() {
        let source = "The fine imposed was \u{20B9}5,000 payable within thirty days."
        let amountRange = self.range(of: "\u{20B9}5,000", in: source)
        let protected = [ProtectedSpan(range: amountRange, kind: .independentlyProtected)]
        let attack = self.proposal(range: amountRange, expected: "\u{20B9}5,000", replacement: "\u{20B9}50,000", claimed: .other)
        let result = self.validate([attack], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(result.resultingText == source)
    }

    private static func testChangeNameInsideIndependentlyProtectedSpanIsReviewOnlyNotApplied() {
        let source = "The complainant Sabyasachi Mohapatra deposed that the incident occurred at night."
        let nameRange = self.range(of: "Sabyasachi Mohapatra", in: source)
        let protected = [ProtectedSpan(range: nameRange, kind: .independentlyProtected)]
        let attack = self.proposal(range: nameRange, expected: "Sabyasachi Mohapatra", replacement: "Sabyasachi Mahapatra", claimed: .other)
        let result = self.validate([attack], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(result.resultingText == source)
    }

    private static func testDeleteProtectedContentRejected() {
        let source = "Section 302 IPC applies."
        let citation = self.range(of: "Section 302 IPC", in: source)
        let protected = [ProtectedSpan(range: citation, kind: .deterministicallyResolved)]
        let deletion = self.proposal(range: citation, expected: "Section 302 IPC", replacement: "", claimed: .other)
        let result = self.validate([deletion], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testInsertionInsideProtectedContentRejected() {
        let source = "Section 302 IPC applies."
        let numberRange = self.range(of: "302", in: source)
        let protected = [ProtectedSpan(range: numberRange, kind: .deterministicallyResolved)]
        let insertion = self.proposal(
            range: NSRange(location: numberRange.location + 1, length: 0),
            expected: "",
            replacement: ",",
            claimed: .punctuation
        )
        let result = self.validate([insertion], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testRewriteAroundProtectionRejected() {
        let source = "The accused violated Section 302 IPC and fled the scene."
        let citation = self.range(of: "Section 302 IPC", in: source)
        let protected = [ProtectedSpan(range: citation, kind: .deterministicallyResolved)]
        let surrounding = self.range(of: "violated Section 302 IPC and fled", in: source)
        let rewrite = self.proposal(
            range: surrounding,
            expected: "violated Section 302 IPC and fled",
            replacement: "broke the law and fled",
            claimed: .other
        )
        let result = self.validate([rewrite], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testClassificationSafeEditOverlappingResolvedSpanIsStillBlocked() {
        // "IPC " -> "IPC" is, in isolation, a whitespace-only edit -- but its
        // range overlaps into the resolved "302 IPC" citation, so the
        // protected-span gate must still block it. Proves the two defenses
        // are independent layers, not a single check.
        let source = "Convicted under Section 302 IPC as charged."
        let citation = self.range(of: "302 IPC", in: source)
        let protected = [ProtectedSpan(range: citation, kind: .deterministicallyResolved)]
        let sneaky = self.proposal(range: self.range(of: "IPC ", in: source), expected: "IPC ", replacement: "IPC", claimed: .whitespace)
        precondition(
            IntelligenceEditClassifier.classify(from: "IPC ", to: "IPC") == .whitespaceOnly,
            "this edit must be classification-safe in isolation for the test to prove anything"
        )
        let result = self.validate([sneaky], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(result.resultingText == source)
    }

    // MARK: - Deterministically unresolved spans (declines are not resolutions)

    private static func testUnresolvedSpanNeverAutonomouslyCorrected() {
        let source = "under section three hundred and two of it c the accused was charged."
        let ambiguous = self.range(of: "it c", in: source)
        let protected = [ProtectedSpan(range: ambiguous, kind: .deterministicallyUnresolved)]
        // Even a surface-safe-looking (whitespace-only) edit inside an
        // unresolved span must not be autonomously applied.
        let sneaky = self.proposal(range: self.range(of: "it c", in: source), expected: "it c", replacement: "itc", claimed: .whitespace)
        precondition(IntelligenceEditClassifier.classify(from: "it c", to: "itc") == .whitespaceOnly)
        let result = self.validate([sneaky], source: source, protectedSpans: protected)
        precondition(result.outcomes[0].disposition == .reviewOnly(.intersectsUnresolvedSpan))
        precondition(result.resultingText == source)
    }

    private static func testResolvedAndUnresolvedProduceDistinctDispositions() {
        precondition(ProtectedSpanKind.deterministicallyUnresolved != .independentlyProtected)
        precondition(ProtectedSpanKind.deterministicallyResolved != .deterministicallyUnresolved)

        let source = "reference marker here"
        let markerRange = self.range(of: "marker", in: source)
        let edit = self.proposal(range: markerRange, expected: "marker", replacement: "Marker", claimed: .capitalization)

        let resolvedResult = self.validate(
            [edit],
            source: source,
            protectedSpans: [ProtectedSpan(range: markerRange, kind: .deterministicallyResolved)]
        )
        let unresolvedResult = self.validate(
            [edit],
            source: source,
            protectedSpans: [ProtectedSpan(range: markerRange, kind: .deterministicallyUnresolved)]
        )
        precondition(resolvedResult.outcomes[0].disposition == .rejected(.intersectsResolvedSpan))
        precondition(unresolvedResult.outcomes[0].disposition == .reviewOnly(.intersectsUnresolvedSpan))
        precondition(resolvedResult.outcomes[0].disposition != unresolvedResult.outcomes[0].disposition)
    }

    // MARK: - Conflict / overlap semantics

    private static func testOverlappingProposalsBothRejected() {
        let source = "The accused shall pay the fine amount owed."
        let a = self.proposal(id: "a", range: self.range(of: "pay the fine", in: source), expected: "pay the fine", replacement: "pay the fine,", claimed: .punctuation)
        let b = self.proposal(id: "b", range: self.range(of: "the fine amount", in: source), expected: "the fine amount", replacement: "the fine amount,", claimed: .punctuation)
        let result = self.validate([a, b], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.outcomes[1].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.resultingText == source)
    }

    private static func testInputOrderDoesNotGrantOverlapAuthority() {
        let source = "The accused shall pay the fine amount owed."
        let a = self.proposal(id: "a", range: self.range(of: "pay the fine", in: source), expected: "pay the fine", replacement: "pay the fine,", claimed: .punctuation)
        let b = self.proposal(id: "b", range: self.range(of: "the fine amount", in: source), expected: "the fine amount", replacement: "the fine amount,", claimed: .punctuation)
        let forward = self.validate([a, b], source: source)
        let reversed = self.validate([b, a], source: source)
        precondition(forward.resultingText == source)
        precondition(reversed.resultingText == source)
        precondition(forward.accepted.isEmpty && reversed.accepted.isEmpty)
    }

    private static func testIdenticalRangeIdenticalReplacementBothRejected() {
        let source = "the witness stated that"
        let sharedRange = self.range(of: "stated", in: source)
        let a = self.proposal(id: "a", range: sharedRange, expected: "stated", replacement: "Stated", claimed: .capitalization)
        let b = self.proposal(id: "b", range: sharedRange, expected: "stated", replacement: "Stated", claimed: .capitalization)
        let result = self.validate([a, b], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.outcomes[1].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.resultingText == source)
    }

    private static func testIdenticalRangeConflictingReplacementsBothRejected() {
        let source = "the witness stated that"
        let sharedRange = self.range(of: "stated", in: source)
        let a = self.proposal(id: "a", range: sharedRange, expected: "stated", replacement: "Stated", claimed: .capitalization)
        let b = self.proposal(id: "b", range: sharedRange, expected: "stated", replacement: "STATED", claimed: .capitalization)
        let result = self.validate([a, b], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.outcomes[1].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.resultingText == source)
    }

    private static func testNestedProposalsBothRejected() {
        let source = self.syntheticSource()
        let outer = self.proposal(id: "outer", range: self.range(of: "CDEFG", in: source), expected: "CDEFG", replacement: "cdefg", claimed: .capitalization)
        let inner = self.proposal(id: "inner", range: self.range(of: "DEF", in: source), expected: "DEF", replacement: "def", claimed: .capitalization)
        let result = self.validate([outer, inner], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.outcomes[1].disposition == .rejected(.overlapsAnotherProposal))
        precondition(result.resultingText == source)
    }

    private static func testAdjacentProposalsAreIndependentNotOverlapping() {
        // Two spaces, not one: `removeSpace` below deletes only ONE of them,
        // leaving the other -- a genuine collapse-of-repeated-whitespace, not
        // a merge of "ab" and "cd" into one word. Deleting the ONLY space
        // between two words is exactly what `AutonomousPermissionGate`
        // (V1.16, W-A1) now blocks; that is not what this test isolates (that
        // non-overlapping proposals are judged independently), so the fixture
        // avoids it rather than repurposing the test to prove a rejection.
        let source = "ab  cd"
        let capitalize = self.proposal(id: "a", range: self.range(of: "ab", in: source), expected: "ab", replacement: "AB", claimed: .capitalization)
        let removeSpace = self.proposal(id: "b", range: NSRange(location: 2, length: 1), expected: " ", replacement: "", claimed: .whitespace)
        let result = self.validate([capitalize, removeSpace], source: source)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.capitalizationOnly))
        precondition(result.outcomes[1].disposition == .autonomouslyAccepted(.whitespaceOnly))
        precondition(result.resultingText == "AB cd", result.resultingText)
    }

    private static func testDuplicateProposalIDsDoNotGrantSpecialTreatment() {
        let source = "ab cd"
        let a = self.proposal(id: "same-id", range: self.range(of: "ab", in: source), expected: "ab", replacement: "AB", claimed: .capitalization)
        let b = self.proposal(id: "same-id", range: self.range(of: "cd", in: source), expected: "cd", replacement: "CD", claimed: .capitalization)
        let result = self.validate([a, b], source: source)
        precondition(result.outcomes.count == 2, "each input proposal produces its own outcome regardless of id collisions")
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.capitalizationOnly))
        precondition(result.outcomes[1].disposition == .autonomouslyAccepted(.capitalizationOnly))
        precondition(result.resultingText == "AB CD", result.resultingText)
    }

    private static func testValidProposalSurvivesUnsafeSiblingInSameBatch() {
        let source = "ab cd"
        let safe = self.proposal(id: "safe", range: self.range(of: "ab", in: source), expected: "ab", replacement: "AB", claimed: .capitalization)
        let stale = self.proposal(id: "stale", range: self.range(of: "cd", in: source), expected: "WRONG", replacement: "CD", claimed: .capitalization)
        let result = self.validate([safe, stale], source: source)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.capitalizationOnly))
        precondition(result.outcomes[1].disposition == .rejected(.sourceTextMismatch))
        precondition(result.resultingText == "AB cd", result.resultingText)
    }

    // MARK: - Order independence of the final text

    private static func testResultingTextIsOrderIndependentForDisjointSafeProposals() {
        let source = "alpha beta gamma"
        let a = self.proposal(id: "a", range: self.range(of: "alpha", in: source), expected: "alpha", replacement: "Alpha", claimed: .capitalization)
        let b = self.proposal(id: "b", range: self.range(of: "gamma", in: source), expected: "gamma", replacement: "Gamma", claimed: .capitalization)
        let forward = self.validate([a, b], source: source)
        let reversed = self.validate([b, a], source: source)
        precondition(forward.resultingText == reversed.resultingText, "\(forward.resultingText) vs \(reversed.resultingText)")
        precondition(forward.resultingText == "Alpha beta Gamma", forward.resultingText)
    }

    // MARK: - Safe positive controls

    private static func testSafeCommaInsertionOutsideProtectedSpanIsApplied() {
        let source = "The witness stated the following before the court."
        let edit = self.proposal(range: self.range(of: "stated", in: source), expected: "stated", replacement: "stated,", claimed: .punctuation)
        let result = self.validate([edit], source: source)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.punctuationOnly))
        precondition(result.resultingText == "The witness stated, the following before the court.", result.resultingText)
    }

    private static func testSafeFullStopReplacementIsApplied() {
        let source = "the accused was present,"
        let edit = self.proposal(range: self.range(of: ",", in: source), expected: ",", replacement: ".", claimed: .punctuation)
        let result = self.validate([edit], source: source)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.punctuationOnly))
        precondition(result.resultingText == "the accused was present.", result.resultingText)
    }

    private static func testSafeCapitalizationCorrectionIsApplied() {
        let source = "the accused was present."
        let edit = self.proposal(range: self.range(of: "the", in: source), expected: "the", replacement: "The", claimed: .capitalization)
        let result = self.validate([edit], source: source)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.capitalizationOnly))
        precondition(result.resultingText == "The accused was present.", result.resultingText)
    }

    private static func testSafeWhitespaceCleanupIsApplied() {
        let source = "the accused  shall appear"
        let edit = self.proposal(range: self.range(of: "  ", in: source), expected: "  ", replacement: " ", claimed: .whitespace)
        let result = self.validate([edit], source: source)
        precondition(result.outcomes[0].disposition == .autonomouslyAccepted(.whitespaceOnly))
        precondition(result.resultingText == "the accused shall appear", result.resultingText)
    }

    // MARK: - AutonomousPermissionGate integration (V1.16)

    private static func testAutonomousPermissionGateDowngradesWordMergeToReviewOnly() {
        // A well-formed, plausibly-correct-looking edit -- not malformed,
        // not overlapping, not touching any protected span -- is still never
        // applied: end to end through validate(), with no spans at all, a
        // structural invariant alone downgrades it.
        let source = "the accused Ram Das denied it"
        // The space between "Ram" and "Das" specifically.
        let ramDasSpace = self.proposal(range: NSRange(location: (source as NSString).range(of: "Ram Das").location + 3, length: 1), expected: " ", replacement: "", claimed: .whitespace)
        let result = self.validate([ramDasSpace], source: source)
        precondition(result.outcomes[0].disposition == .reviewOnly(.wordBoundaryMerged), "\(result.outcomes[0].disposition)")
        precondition(result.resultingText == source, "a gate-blocked edit is never applied")
    }

    private static func testAutonomousPermissionGateNeverConsultedForUnsupportedCategory() {
        // A lexical change is rejected on its own terms (.other), never
        // reaching -- and therefore never needing -- the gate at all.
        let source = "charged under IPC for the offence."
        let edit = self.proposal(range: self.range(of: "IPC", in: source), expected: "IPC", replacement: "CrPC", claimed: .other)
        let result = self.validate([edit], source: source)
        precondition(result.outcomes[0].disposition == .rejected(.unsupportedEditCategory))
    }

    private static func testAutonomousPermissionGateAndProtectedSpansAreIndependentLayers() {
        // A protected-span rejection takes precedence regardless of what the
        // gate would have said; conversely, with no protected span at all
        // the gate alone still withholds autonomous acceptance -- proving
        // the two layers are independent, neither redundant.
        let source = "charged under IPC for the offence."
        let ipcRange = self.range(of: "IPC", in: source)
        let lowering = self.proposal(range: ipcRange, expected: "IPC", replacement: "ipc", claimed: .capitalization)

        let withResolvedSpan = self.validate([lowering], source: source, protectedSpans: [ProtectedSpan(range: ipcRange, kind: .deterministicallyResolved)])
        precondition(withResolvedSpan.outcomes[0].disposition == .rejected(.intersectsResolvedSpan), "the span check runs first and is unaffected by the gate")

        let withNoSpans = self.validate([lowering], source: source)
        precondition(withNoSpans.outcomes[0].disposition == .reviewOnly(.acronymCapitalizationLowered), "\(withNoSpans.outcomes[0].disposition)")
        precondition(withNoSpans.resultingText == source)
    }

    private static func testMultipleSafeEditsAppliedTogetherProduceCorrectFinalText() {
        let source = "the accused  was present"
        let capitalize = self.proposal(id: "cap", range: self.range(of: "the", in: source), expected: "the", replacement: "The", claimed: .capitalization)
        let whitespace = self.proposal(id: "ws", range: self.range(of: "  ", in: source), expected: "  ", replacement: " ", claimed: .whitespace)
        let punctuation = self.proposal(id: "punc", range: self.range(of: "present", in: source), expected: "present", replacement: "present.", claimed: .punctuation)
        let result = self.validate([capitalize, whitespace, punctuation], source: source)
        precondition(result.accepted.count == 3, "\(result.outcomes)")
        precondition(result.resultingText == "The accused was present.", result.resultingText)
    }
}
