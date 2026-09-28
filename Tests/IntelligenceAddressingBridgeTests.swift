import Foundation

/// Coverage for `IntelligenceAddressingBridge` and its integration with the
/// unmodified `IntelligenceSafetyAuthority`. Governing questions:
///   - is bridge metadata deterministic and never model-derived?
///   - does every edit resolve against the same immutable source, with one
///     item's failure never affecting another's outcome?
///   - does a correctly *resolved* edit still get judged -- and, when
///     unsafe, rejected -- by the Safety Authority alone?
/// Deterministic only -- no model, no network.
@main
enum IntelligenceAddressingBridgeTests {
    static func main() {
        self.testMetadataIsDeterministicAndNeverModelDerived()
        self.testExpectedSourceTextComesFromTheRealSource()
        self.testOrderIsPreservedAndIDsFollowOriginalPosition()
        self.testRejectedItemsKeepTheirPositionalID()
        self.testPartialFailureIsolation()
        self.testReversingTheBatchYieldsIdenticalPerItemResolutions()
        self.testEveryEditResolvesAgainstTheOriginalImmutableSource()
        self.testReplacementTextNeverAffectsResolution()
        self.testBridgeDoesNotDetectOverlapOrJudgeSafety()
        self.testEmptyBatch()
        self.testUnicodeRangesAreUTF16DerivedBySwift()

        self.testEndToEndSafeCapitalizationIsAccepted()
        self.testEndToEndRepeatedOccurrenceThroughAuthority()
        self.testEndToEndSafeWhitespaceAfterNonBMPText()
        self.testEndToEndResolvedButLexicalEditRejectedByAuthority()
        self.testEndToEndResolvedButOverBroadSpanRejectedByAuthority()
        self.testEndToEndResolvedStatuteNumberChangeRejectedByAuthority()
        self.testEndToEndNoOpResolvesButAuthorityRejects()
        self.testEndToEndResolvedEditIntersectingProtectedSpans()
        self.testEndToEndOverlapIsTheAuthoritysJobNotTheBridges()
        self.testEndToEndMixedBatchAddressingFailureDoesNotDisturbSiblings()
        self.testEndToEndAddressingFailureNeverReachesTheAuthority()
        self.testEndToEndSubGraphemeTargetsAreJudgedByTheAuthority()

        print("PASS: IntelligenceAddressingBridge deterministic bridge and Safety Authority integration suite")
    }

    // MARK: - Helpers

    private static func edit(
        _ sourceText: String,
        to replacement: String,
        occurrence: Int? = nil,
        left: String? = nil,
        right: String? = nil
    ) -> ModelFacingEdit {
        ModelFacingEdit(sourceText: sourceText, replacementText: replacement, occurrence: occurrence, leftContext: left, rightContext: right)
    }

    private static func validate(
        _ batch: IntelligenceAddressingBatchResult,
        source: String,
        protectedSpans: [ProtectedSpan] = []
    ) -> IntelligenceSafetyAuthority.Result {
        IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: protectedSpans)
    }

    private static func resolvedProposal(_ item: IntelligenceAddressingItemOutcome, file: StaticString = #file, line: UInt = #line) -> IntelligenceProposal {
        guard case let .resolved(proposal, _) = item.result else {
            preconditionFailure("expected item \(item.id) to resolve, got \(item.result)", file: file, line: line)
        }
        return proposal
    }

    private static func disposition(_ result: IntelligenceSafetyAuthority.Result, id: String) -> ProposalDisposition {
        guard let outcome = result.outcomes.first(where: { $0.proposal.id == id }) else {
            preconditionFailure("no Authority outcome for id \(id)")
        }
        return outcome.disposition
    }

    private static let twice = "the accused said the accused left"

    // MARK: - Bridge metadata and structure

    private static func testMetadataIsDeterministicAndNeverModelDerived() {
        let edits = [self.edit("said", to: "stated"), self.edit("left", to: "departed")]
        let first = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        let second = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        precondition(first == second, "bridging must be fully deterministic")
        for item in first.items {
            let proposal = self.resolvedProposal(item)
            precondition(proposal.claimedCategory == .other, "bridge must never claim a category")
        }
        precondition(first.proposals.map(\.id) == ["p1", "p2"], "IDs are batch-local, positional, 1-based p<n>")
    }

    private static func testExpectedSourceTextComesFromTheRealSource() {
        let source = "Section 302 IPC applies. Section 302 IPC applies."
        let batch = IntelligenceAddressingBridge.bridge([self.edit("302", to: "304", occurrence: 2)], source: source)
        let proposal = self.resolvedProposal(batch.items[0])
        precondition(proposal.expectedSourceText == (source as NSString).substring(with: proposal.range), "expectedSourceText must be read from the source at the resolved range")
        precondition(proposal.expectedSourceText == "302")
        precondition(proposal.range == NSRange(location: 33, length: 3))
        precondition(proposal.replacementText == "304")
    }

    private static func testOrderIsPreservedAndIDsFollowOriginalPosition() {
        // Deliberately not in source order.
        let edits = [self.edit("left", to: "L"), self.edit("said", to: "S"), self.edit("the accused", to: "T", occurrence: 1)]
        let batch = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        precondition(batch.items.map(\.index) == [0, 1, 2])
        precondition(batch.items.map(\.id) == ["p1", "p2", "p3"])
        precondition(batch.items.map(\.edit) == edits, "each outcome carries its own original edit")
        precondition(batch.proposals.map(\.replacementText) == ["L", "S", "T"], "proposals keep original order, not source order")
    }

    private static func testRejectedItemsKeepTheirPositionalID() {
        let edits = [self.edit("said", to: "S"), self.edit("nonexistent", to: "N"), self.edit("left", to: "L")]
        let batch = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        precondition(batch.items.map(\.id) == ["p1", "p2", "p3"], "a rejected item still occupies its position; later IDs never shift")
        precondition(batch.proposals.map(\.id) == ["p1", "p3"])
        precondition(batch.rejections.count == 1 && batch.rejections[0].id == "p2" && batch.rejections[0].index == 1)
        precondition(batch.rejections[0].reason == .noLiteralMatch)
    }

    private static func testPartialFailureIsolation() {
        let good1 = self.edit("said", to: "stated")
        let good2 = self.edit("the accused", to: "he", occurrence: 2)
        let bad1 = self.edit("absent", to: "x")
        let bad2 = self.edit("the accused", to: "he") // ambiguous, no discriminator
        let bad3 = self.edit("the accused", to: "he", occurrence: 7)

        let alone1 = IntelligenceAddressingBridge.bridge([good1], source: self.twice).items[0].result
        let alone2 = IntelligenceAddressingBridge.bridge([good2], source: self.twice).items[0].result

        let mixed = IntelligenceAddressingBridge.bridge([bad1, good1, bad2, good2, bad3], source: self.twice)
        precondition(mixed.items.count == 5)
        // Resolution results are identical to resolving each item alone
        // (IDs differ by position, so compare the resolved range/basis).
        for (item, alone) in [(mixed.items[1], alone1), (mixed.items[3], alone2)] {
            guard case let .resolved(mixedProposal, mixedBasis) = item.result, case let .resolved(aloneProposal, aloneBasis) = alone else {
                preconditionFailure("good edits must resolve regardless of failing siblings")
            }
            precondition(mixedProposal.range == aloneProposal.range && mixedProposal.expectedSourceText == aloneProposal.expectedSourceText)
            precondition(mixedProposal.replacementText == aloneProposal.replacementText && mixedBasis == aloneBasis)
        }
        precondition(mixed.rejections.map(\.reason) == [.noLiteralMatch, .ambiguousCandidates(count: 2), .occurrenceOutOfRange(occurrence: 7, candidateCount: 2)])
        precondition(mixed.rejections.map(\.index) == [0, 2, 4])
    }

    private static func testReversingTheBatchYieldsIdenticalPerItemResolutions() {
        let edits = [
            self.edit("said", to: "S"),
            self.edit("the accused", to: "T", occurrence: 2),
            self.edit("absent", to: "N"),
            self.edit("the accused", to: "U", right: " said"),
        ]
        let forward = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        let reversed = IntelligenceAddressingBridge.bridge(edits.reversed(), source: self.twice)
        for (index, item) in forward.items.enumerated() {
            let counterpart = reversed.items[edits.count - 1 - index]
            switch (item.result, counterpart.result) {
            case let (.resolved(a, basisA), .resolved(b, basisB)):
                precondition(a.range == b.range && a.expectedSourceText == b.expectedSourceText && basisA == basisB, "item \(index): order must not affect resolution")
            case let (.rejected(a), .rejected(b)):
                precondition(a == b, "item \(index): order must not affect rejection reason")
            default:
                preconditionFailure("item \(index): order changed whether an edit resolved")
            }
        }
    }

    private static func testEveryEditResolvesAgainstTheOriginalImmutableSource() {
        // Edit 1 would, if applied first, shift every later position AND
        // remove the first "the accused". Edit 2 (occurrence 2) and edit 3
        // (context) must still resolve against the ORIGINAL coordinates.
        let edits = [
            self.edit("the accused", to: "X", occurrence: 1),
            self.edit("the accused", to: "Y", occurrence: 2),
            self.edit("the accused", to: "Z", right: " left"),
        ]
        let batch = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        let ranges = batch.proposals.map(\.range)
        precondition(ranges[0] == NSRange(location: 0, length: 11))
        precondition(ranges[1] == NSRange(location: 17, length: 11), "occurrence 2 still names the original second occurrence")
        precondition(ranges[2] == NSRange(location: 17, length: 11))
    }

    private static func testReplacementTextNeverAffectsResolution() {
        // Replacement text that itself contains the target must not alter
        // cardinality or position for any sibling.
        let edits = [
            self.edit("said", to: "said said said"),
            self.edit("left", to: "the accused left"),
            self.edit("the accused", to: "the accused the accused", occurrence: 2),
        ]
        let batch = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        precondition(batch.proposals.map(\.range) == [NSRange(location: 12, length: 4), NSRange(location: 29, length: 4), NSRange(location: 17, length: 11)])
    }

    private static func testBridgeDoesNotDetectOverlapOrJudgeSafety() {
        // Two overlapping edits both resolve; the bridge neither merges,
        // orders, nor rejects them -- that is the Authority's job.
        let edits = [self.edit("the accused said", to: "A"), self.edit("said the", to: "B")]
        let batch = IntelligenceAddressingBridge.bridge(edits, source: self.twice)
        precondition(batch.proposals.count == 2 && batch.rejections.isEmpty)
        precondition(NSIntersectionRange(batch.proposals[0].range, batch.proposals[1].range).length > 0, "test premise: ranges genuinely overlap")
    }

    private static func testEmptyBatch() {
        let batch = IntelligenceAddressingBridge.bridge([], source: self.twice)
        precondition(batch.items.isEmpty && batch.proposals.isEmpty && batch.rejections.isEmpty)
        let result = self.validate(batch, source: self.twice)
        precondition(result.resultingText == self.twice && result.outcomes.isEmpty)
    }

    private static func testUnicodeRangesAreUTF16DerivedBySwift() {
        let emoji = "\u{1F60A}"
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let source = "\(emoji) said \(odia) then \(emoji) left"
        let batch = IntelligenceAddressingBridge.bridge([self.edit("left", to: "went"), self.edit(emoji, to: "", occurrence: 2)], source: source)
        let left = self.resolvedProposal(batch.items[0])
        precondition(left.range.location == (source as NSString).length - 4, "range must count the emoji as 2 UTF-16 units and Odia as its scalar count")
        let secondEmoji = self.resolvedProposal(batch.items[1])
        precondition(secondEmoji.range.length == 2, "non-BMP glyph is a surrogate pair: UTF-16 length 2")
        precondition(secondEmoji.expectedSourceText == emoji)
    }

    // MARK: - End to end through the unmodified Safety Authority

    private static func testEndToEndSafeCapitalizationIsAccepted() {
        let source = "the accused left. the witness spoke"
        let batch = IntelligenceAddressingBridge.bridge([self.edit(". the", to: ". The")], source: source)
        let result = self.validate(batch, source: source)
        guard case .autonomouslyAccepted(.capitalizationOnly) = self.disposition(result, id: "p1") else {
            preconditionFailure("safe capitalization should traverse bridge and Authority: \(self.disposition(result, id: "p1"))")
        }
        precondition(result.resultingText == "the accused left. The witness spoke")
    }

    private static func testEndToEndRepeatedOccurrenceThroughAuthority() {
        let batch = IntelligenceAddressingBridge.bridge([self.edit("the", to: "The", occurrence: 2)], source: self.twice)
        let result = self.validate(batch, source: self.twice)
        guard case .autonomouslyAccepted = self.disposition(result, id: "p1") else {
            preconditionFailure("occurrence-addressed capitalization should be accepted")
        }
        precondition(result.resultingText == "the accused said The accused left", "only the second occurrence changes")
    }

    private static func testEndToEndSafeWhitespaceAfterNonBMPText() {
        let source = "\u{1F60A}\u{1F60A}  done"
        let batch = IntelligenceAddressingBridge.bridge([self.edit("  ", to: " ")], source: source)
        let result = self.validate(batch, source: source)
        guard case .autonomouslyAccepted(.whitespaceOnly) = self.disposition(result, id: "p1") else {
            preconditionFailure("whitespace fix after surrogate pairs should be accepted: \(self.disposition(result, id: "p1"))")
        }
        precondition(result.resultingText == "\u{1F60A}\u{1F60A} done")
    }

    private static func testEndToEndResolvedButLexicalEditRejectedByAuthority() {
        // The occurrence-addressed reference is perfectly valid and resolves
        // exactly -- and is still not permitted: resolution is not permission.
        let batch = IntelligenceAddressingBridge.bridge([self.edit("the accused", to: "the complainant", occurrence: 2)], source: self.twice)
        precondition(batch.rejections.isEmpty, "addressing must succeed")
        let result = self.validate(batch, source: self.twice)
        precondition(self.disposition(result, id: "p1") == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == self.twice)
    }

    private static func testEndToEndResolvedButOverBroadSpanRejectedByAuthority() {
        // The V1.4C `E5` shape: a whole-passage span with a valid reference.
        // The resolver never shrinks it; the Authority contains it.
        let source = "He left. she stayed."
        let batch = IntelligenceAddressingBridge.bridge([self.edit(source, to: "He left. She stayed")], source: source)
        precondition(batch.rejections.isEmpty, "the resolver must resolve what the model actually proposed")
        precondition(batch.proposals[0].range == NSRange(location: 0, length: (source as NSString).length))
        let result = self.validate(batch, source: source)
        precondition(self.disposition(result, id: "p1") == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    private static func testEndToEndResolvedStatuteNumberChangeRejectedByAuthority() {
        let source = "Convicted under Section 302 IPC."
        let batch = IntelligenceAddressingBridge.bridge([self.edit("302", to: "304")], source: source)
        let result = self.validate(batch, source: source)
        precondition(self.disposition(result, id: "p1") == .rejected(.unsupportedEditCategory))
        precondition(result.resultingText == source)
    }

    private static func testEndToEndNoOpResolvesButAuthorityRejects() {
        let batch = IntelligenceAddressingBridge.bridge([self.edit("said", to: "said")], source: self.twice)
        precondition(batch.rejections.isEmpty, "the bridge does not judge no-ops")
        let result = self.validate(batch, source: self.twice)
        precondition(self.disposition(result, id: "p1") == .rejected(.noOpProposal))
    }

    private static func testEndToEndResolvedEditIntersectingProtectedSpans() {
        // "Section 302 IPC" occupies [10, 25). A resolved, otherwise-safe
        // capitalization edit inside it is blocked or downgraded by the
        // Authority according to the span's kind -- the bridge is unaware.
        let source = "Ordered: section 302 ipc applies."
        let target = (source as NSString).range(of: "section 302 ipc")
        let batch = IntelligenceAddressingBridge.bridge([self.edit("section", to: "Section")], source: source)
        precondition(batch.rejections.isEmpty)

        let resolvedSpan = self.validate(batch, source: source, protectedSpans: [ProtectedSpan(range: target, kind: .deterministicallyResolved)])
        precondition(self.disposition(resolvedSpan, id: "p1") == .rejected(.intersectsResolvedSpan))
        precondition(resolvedSpan.resultingText == source)

        let unresolvedSpan = self.validate(batch, source: source, protectedSpans: [ProtectedSpan(range: target, kind: .deterministicallyUnresolved)])
        precondition(self.disposition(unresolvedSpan, id: "p1") == .reviewOnly(.intersectsUnresolvedSpan))
        precondition(unresolvedSpan.resultingText == source)

        let independent = self.validate(batch, source: source, protectedSpans: [ProtectedSpan(range: target, kind: .independentlyProtected)])
        precondition(self.disposition(independent, id: "p1") == .reviewOnly(.intersectsIndependentlyProtectedSpan))
    }

    private static func testEndToEndOverlapIsTheAuthoritysJobNotTheBridges() {
        let source = "the accused said. the witness spoke"
        // Two individually-safe capitalization edits whose ranges overlap.
        let batch = IntelligenceAddressingBridge.bridge([self.edit(". the", to: ". The"), self.edit(" the witness", to: " The witness")], source: source)
        precondition(batch.rejections.isEmpty && batch.proposals.count == 2, "both resolve; the bridge never arbitrates")
        let result = self.validate(batch, source: source)
        precondition(self.disposition(result, id: "p1") == .rejected(.overlapsAnotherProposal))
        precondition(self.disposition(result, id: "p2") == .rejected(.overlapsAnotherProposal))
        precondition(result.resultingText == source)
    }

    private static func testEndToEndMixedBatchAddressingFailureDoesNotDisturbSiblings() {
        let source = "the accused left. the witness spoke. the court rose."
        let edits = [
            self.edit(". the", to: ". The", occurrence: 1),
            self.edit("nonexistent", to: "x"),
            self.edit(". the", to: ". The", occurrence: 2),
            self.edit(". the", to: ". The"), // ambiguous
        ]
        let batch = IntelligenceAddressingBridge.bridge(edits, source: source)
        precondition(batch.proposals.map(\.id) == ["p1", "p3"])
        precondition(batch.rejections.map(\.id) == ["p2", "p4"])
        let result = self.validate(batch, source: source)
        precondition(result.outcomes.count == 2, "only resolved proposals are handed to the Authority")
        precondition(result.accepted.count == 2)
        precondition(result.resultingText == "the accused left. The witness spoke. The court rose.")
    }

    private static func testEndToEndAddressingFailureNeverReachesTheAuthority() {
        // Overlapping-literal ambiguity is an addressing failure, so no
        // proposal exists at all: nothing to accept, nothing applied.
        let batch = IntelligenceAddressingBridge.bridge([self.edit("aa", to: "AA")], source: "aaa")
        precondition(batch.proposals.isEmpty)
        precondition(batch.rejections.map(\.reason) == [.ambiguousCandidates(count: 2)])
        let result = self.validate(batch, source: "aaa")
        precondition(result.outcomes.isEmpty && result.resultingText == "aaa")
    }

    private static func testEndToEndSubGraphemeTargetsAreJudgedByTheAuthority() {
        // "e" occurs as a literal UTF-16 code unit inside the decomposed
        // "e + combining acute". The resolver is exact-literal and does not
        // repair or enforce grapheme boundaries (neither does the unmodified
        // Authority, which classifies the edit on the scalar text). What
        // matters is that a sub-grapheme target can only ever be applied
        // when the Authority independently classifies it as a permitted
        // surface edit.
        let source = "the cafe\u{0301} opened"

        // Whole-grapheme target: a clean, accepted capitalization.
        let wholeBatch = IntelligenceAddressingBridge.bridge([self.edit("e\u{0301}", to: "E\u{0301}")], source: source)
        let whole = self.validate(wholeBatch, source: source)
        guard case .autonomouslyAccepted(.capitalizationOnly) = self.disposition(whole, id: "p1") else {
            preconditionFailure("a whole-grapheme target is legitimate: \(self.disposition(whole, id: "p1"))")
        }
        precondition(whole.resultingText == "the cafE\u{0301} opened")

        // Base-scalar-only target (context selects the "e" before the
        // accent): the code-unit match exists and resolves. A pure
        // capitalization of that scalar is what the Authority independently
        // says it is, and is accepted -- 'e' + acute becomes 'E' + acute.
        let capsBatch = IntelligenceAddressingBridge.bridge([self.edit("e", to: "E", right: "\u{0301}")], source: source)
        precondition(capsBatch.rejections.isEmpty, "the resolver is exact-literal: the code-unit match exists")
        let caps = self.validate(capsBatch, source: source)
        guard case .autonomouslyAccepted(.capitalizationOnly) = self.disposition(caps, id: "p1") else {
            preconditionFailure("scalar-level capitalization is a permitted surface edit: \(self.disposition(caps, id: "p1"))")
        }
        precondition(caps.resultingText == "the cafE\u{0301} opened")

        // A lexical change to the base scalar (e -> a, which would turn the
        // accented word into a different one) is never a surface edit: the
        // Authority rejects it regardless of the split.
        let lexicalBatch = IntelligenceAddressingBridge.bridge([self.edit("e", to: "a", right: "\u{0301}")], source: source)
        precondition(lexicalBatch.rejections.isEmpty)
        let lexical = self.validate(lexicalBatch, source: source)
        precondition(self.disposition(lexical, id: "p1") == .rejected(.unsupportedEditCategory))
        precondition(lexical.resultingText == source, "nothing may be applied")
    }
}
