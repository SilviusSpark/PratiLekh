import Foundation

// EXPERIMENTAL -- Intelligence V1.4 architecture investigation only. See
// `V1_4_ModelFacingResolver.swift`'s header. These tests are deterministic
// and require NO Ollama/model -- they exercise the resolver and, for the
// protected-span/lexical-mutation cases, the real committed
// `IntelligenceSafetyAuthority` directly with hand-constructed proposals.
// Run via `scripts/test_v1_4_experimental_resolver.sh`.

func expectSuccess(
    _ result: Result<NSRange, ResolverFailure>,
    location: Int,
    length: Int,
    file: StaticString = #file,
    line: UInt = #line
) {
    switch result {
    case .success(let range):
        precondition(range.location == location && range.length == length, "unexpected range \(range)", file: file, line: line)
    case .failure(let failure):
        preconditionFailure("expected success, got \(failure)", file: file, line: line)
    }
}

func expectFailure(
    _ result: Result<NSRange, ResolverFailure>,
    _ expected: ResolverFailure,
    file: StaticString = #file,
    line: UInt = #line
) {
    switch result {
    case .success(let range):
        preconditionFailure("expected failure \(expected), got success \(range)", file: file, line: line)
    case .failure(let failure):
        precondition(failure == expected, "expected \(expected), got \(failure)", file: file, line: line)
    }
}

@main
enum V14ResolverTests {
    static func main() {
        testUniqueReplacement()
        testUniqueDeletion()
        testInsertionBeforeAfterAnchor()
        testBoundaryInsertionStartEnd()
        testRepeatedSourceCandidateAFailsClosed()
        testRepeatedSourceCandidateBOrdinalResolves()
        testRepeatedSourceCandidateCContextResolves()
        testRepeatedSourceContextStillAmbiguous()
        testMissingHallucinatedSource()
        testContextMismatch()
        testUnicodeOdia()
        testUnicodeEmojiSurrogatePair()
        testUnicodeMixed()
        testMultipleIndependentEdits()
        testOverlapDetectedExplicitly()
        testConflictSameTargetDifferentReplacements()
        testImmutableSourceSemanticsMultiEdit()
        testAnchorRepeatsFailsClosed()
        testAnchorMissingFailsClosed()
        testProtectedSpanInteractionWithRealSafetyAuthority()
        testLexicalMutationResolvedButRejectedByRealSafetyAuthority()
        testInvalidOrdinalFailsClosed()
        testEmptyReferenceFailsClosed()
        print("All V1.4 model-facing resolver checks passed.")
    }

    // MARK: - 1-4: replacement, deletion, insertion, boundaries

    static func testUniqueReplacement() {
        let source = "The witness confirmed the statement." as NSString
        let ref = ModelFacingReference.replace("confirmed")
        expectSuccess(resolveReference(ref, in: source), location: 12, length: 9)
    }

    static func testUniqueDeletion() {
        // Deletion is a replacement whose replacementText is empty -- the
        // resolver's job (locating sourceText) is identical either way.
        let source = "The witness said,, it was true" as NSString
        let ref = ModelFacingReference.replace(",")
        // "," is not unique here (appears twice); use occurrence to select
        // the second one for deletion, proving deletion needs the same
        // disambiguation machinery as any other edit.
        let ambiguous = ModelFacingReference.replace(",", occurrence: 2)
        expectFailure(resolveReference(ref, in: source), .ambiguousOccurrences(2))
        expectSuccess(resolveReference(ambiguous, in: source), location: 17, length: 1)
    }

    static func testInsertionBeforeAfterAnchor() {
        let source = "However the accused denied the allegation" as NSString
        let after = ModelFacingReference.insert(anchor: "However", side: .after)
        expectSuccess(resolveReference(after, in: source), location: 7, length: 0)

        let before = ModelFacingReference.insert(anchor: "the accused", side: .before)
        expectSuccess(resolveReference(before, in: source), location: 8, length: 0)
    }

    static func testBoundaryInsertionStartEnd() {
        let source = "The witness said he was present" as NSString
        expectSuccess(resolveReference(.insertAtEnd(), in: source), location: 31, length: 0)
        expectSuccess(resolveReference(.insertAtStart(), in: source), location: 0, length: 0)
    }

    // MARK: - 5-7: repeated text, ambiguity, disambiguation

    static func testRepeatedSourceCandidateAFailsClosed() {
        // Candidate A (sourceText only) cannot express "which occurrence".
        let source = "the accused said the accused left" as NSString
        expectFailure(resolveReference(.replace("the accused"), in: source), .ambiguousOccurrences(2))
    }

    static func testRepeatedSourceCandidateBOrdinalResolves() {
        let source = "the accused said the accused left" as NSString
        expectSuccess(resolveReference(.replace("the accused", occurrence: 1), in: source), location: 0, length: 11)
        expectSuccess(resolveReference(.replace("the accused", occurrence: 2), in: source), location: 17, length: 11)
    }

    static func testRepeatedSourceCandidateCContextResolves() {
        let source = "the accused said the accused left" as NSString
        expectSuccess(
            resolveReference(.replace("the accused", rightContext: " said"), in: source),
            location: 0,
            length: 11
        )
        expectSuccess(
            resolveReference(.replace("the accused", leftContext: "said "), in: source),
            location: 17,
            length: 11
        )
    }

    static func testRepeatedSourceContextStillAmbiguous() {
        // A context that does not distinguish the two occurrences must
        // still fail closed -- context is a discriminator, not a promotion
        // to "resolve somehow".
        let source = "the accused left, the accused left again." as NSString
        // Both occurrences of "the accused" are followed by " left" -- this
        // context does not disambiguate them.
        expectFailure(
            resolveReference(.replace("the accused", rightContext: " left"), in: source),
            .ambiguousOccurrences(2)
        )
    }

    // MARK: - 8-9: hallucinated source, context mismatch

    static func testMissingHallucinatedSource() {
        let source = "The witness confirmed the statement." as NSString
        expectFailure(resolveReference(.replace("nonexistent phrase"), in: source), .zeroOccurrences)
    }

    static func testContextMismatch() {
        // "accused" exists uniquely, but the claimed left context is wrong.
        let source = "The accused was present." as NSString
        expectFailure(
            resolveReference(.replace("accused", leftContext: "some wrong prefix "), in: source),
            .contextMismatch
        )
    }

    // MARK: - 10: Unicode

    static func testUnicodeOdia() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}" // ଓଡ଼ିଶା
        let source = "The complainant resides in \(odia) state" as NSString
        expectSuccess(resolveReference(.replace(odia), in: source), location: 27, length: 6)
    }

    static func testUnicodeEmojiSurrogatePair() {
        let emoji = "\u{1F60A}" // 😊, astral-plane, 2 UTF-16 units
        precondition((emoji as NSString).length == 2, "expected a genuine UTF-16 surrogate pair")
        let source = "The accused smiled \(emoji) during the hearing" as NSString
        expectSuccess(resolveReference(.replace(emoji), in: source), location: 19, length: 2)
        // Insertion immediately after the emoji must land past both
        // surrogate units, not after only one.
        let after = ModelFacingReference.insert(anchor: emoji, side: .after)
        expectSuccess(resolveReference(after, in: source), location: 21, length: 0)
    }

    static func testUnicodeMixed() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let emoji = "\u{1F60A}"
        let source = "The witness \(odia) smiled \(emoji) today" as NSString
        // Insert a comma right after the Odia word, verifying the resolver
        // correctly counts through a preceding non-Latin, non-astral
        // Unicode span before locating a subsequent anchor.
        let ref = ModelFacingReference.insert(anchor: odia, side: .after)
        expectSuccess(resolveReference(ref, in: source), location: 12 + 6, length: 0)
    }

    // MARK: - 11-13: multi-edit, overlap, conflict

    static func testMultipleIndependentEdits() {
        let source = "the witness confirmed the statement and the accused denied it" as NSString
        let proposals = [
            ModelFacingProposal(id: "p1", reference: .replace("the witness"), replacementText: "The witness"),
            ModelFacingProposal(id: "p2", reference: .replace("the accused"), replacementText: "the Accused"),
        ]
        let resolved = resolveBatch(proposals, against: source)
        precondition(resolved.count == 2)
        for (proposal, result) in resolved {
            guard case .success = result else { preconditionFailure("expected \(proposal.id) to resolve") }
        }
        let ranges = resolved.compactMap { pair -> (id: String, range: NSRange)? in
            guard case .success(let r) = pair.result else { return nil }
            return (id: pair.proposal.id, range: r)
        }
        precondition(detectOverlaps(ranges).isEmpty, "non-overlapping edits must not be flagged as overlapping")
    }

    static func testOverlapDetectedExplicitly() {
        let source = "the accused was present" as NSString
        let proposals = [
            ModelFacingProposal(id: "p1", reference: .replace("the accused"), replacementText: "The accused"),
            ModelFacingProposal(id: "p2", reference: .replace("accused was"), replacementText: "Accused was"),
        ]
        let resolved = resolveBatch(proposals, against: source)
        let ranges = resolved.compactMap { pair -> (id: String, range: NSRange)? in
            guard case .success(let r) = pair.result else { return nil }
            return (id: pair.proposal.id, range: r)
        }
        let overlaps = detectOverlaps(ranges)
        precondition(!overlaps.isEmpty, "expected p1/p2 to be flagged as overlapping -- must not be silently merged")
    }

    static func testConflictSameTargetDifferentReplacements() {
        // Two proposals resolving to the EXACT same range with different
        // replacements -- an overlap by definition (identical ranges always
        // intersect), and must be surfaced the same explicit way.
        let source = "the accused was present" as NSString
        let proposals = [
            ModelFacingProposal(id: "p1", reference: .replace("accused"), replacementText: "defendant"),
            ModelFacingProposal(id: "p2", reference: .replace("accused"), replacementText: "respondent"),
        ]
        let resolved = resolveBatch(proposals, against: source)
        let ranges = resolved.compactMap { pair -> (id: String, range: NSRange)? in
            guard case .success(let r) = pair.result else { return nil }
            return (id: pair.proposal.id, range: r)
        }
        precondition(ranges.count == 2, "both must resolve individually -- conflict is a downstream concern, not a resolver failure")
        precondition(!detectOverlaps(ranges).isEmpty, "identical-range conflicting proposals must be flagged")
    }

    // MARK: - 14 (immutable-source semantics)

    static func testImmutableSourceSemanticsMultiEdit() {
        // Two proposals target text that would only coexist in the
        // ORIGINAL source -- if resolution of p2 accidentally happened
        // against a hypothetically-already-edited copy (with p1 applied),
        // its target text would have shifted or vanished. Resolving both
        // against the same immutable `source` value proves this can't
        // happen structurally: both resolve correctly regardless of which
        // is "applied first" conceptually.
        let source = "the witness said the accused left" as NSString
        let proposals = [
            ModelFacingProposal(id: "p1", reference: .replace("the witness"), replacementText: "The witness"),
            ModelFacingProposal(id: "p2", reference: .replace("the accused"), replacementText: "the Accused"),
        ]
        // Resolve in both orders -- immutable-source semantics guarantee
        // the result is identical regardless of array order.
        let forward = resolveBatch(proposals, against: source)
        let reversed = resolveBatch(proposals.reversed(), against: source)
        func range(_ results: [(proposal: ModelFacingProposal, result: Result<NSRange, ResolverFailure>)], _ id: String) -> NSRange? {
            guard let match = results.first(where: { $0.proposal.id == id }), case .success(let r) = match.result else { return nil }
            return r
        }
        precondition(range(forward, "p1") == range(reversed, "p1"))
        precondition(range(forward, "p2") == range(reversed, "p2"))
    }

    // MARK: - anchor-specific ambiguity/failure

    static func testAnchorRepeatsFailsClosed() {
        let source = "the witness said the witness left" as NSString
        let ref = ModelFacingReference.insert(anchor: "witness", side: .after)
        expectFailure(resolveReference(ref, in: source), .anchorAmbiguousOccurrences(2))
    }

    static func testAnchorMissingFailsClosed() {
        let source = "the witness said the accused left" as NSString
        let ref = ModelFacingReference.insert(anchor: "nonexistent", side: .after)
        expectFailure(resolveReference(ref, in: source), .anchorZeroOccurrences)
    }

    static func testInvalidOrdinalFailsClosed() {
        let source = "the accused said the accused left" as NSString
        expectFailure(resolveReference(.replace("the accused", occurrence: 3), in: source), .invalidOrdinal)
    }

    static func testEmptyReferenceFailsClosed() {
        let source = "the accused said the accused left" as NSString
        expectFailure(resolveReference(ModelFacingReference(), in: source), .emptyReference)
    }

    // MARK: - 13/15: protected-span and lexical-mutation, through the REAL
    // committed V1.0 Safety Authority (unmodified) -- proving resolution
    // does not bypass existing safety semantics.

    static func testProtectedSpanInteractionWithRealSafetyAuthority() {
        let source = "Section 302 IPC was invoked he said"
        let sourceNS = source as NSString
        let statuteRange = sourceNS.range(of: "Section 302 IPC")
        let ref = ModelFacingReference.insert(anchor: "invoked", side: .after)
        guard case .success(let insertionRange) = resolveReference(ref, in: sourceNS) else {
            preconditionFailure("expected anchor to resolve")
        }
        // This proposal's own resolved range does NOT itself overlap the
        // statute span (it's a pure insertion after "invoked") -- this is
        // deliberately the "minimal-diff" case V1.3C's whole-segment
        // approach could not express. Verify the real Safety Authority
        // accepts it as a safe punctuation-only insertion, and separately
        // verify a proposal that DOES intersect the resolved protected
        // span is forbidden outright regardless of content.
        let safeProposal = IntelligenceProposal(
            id: "insert-comma",
            range: insertionRange,
            expectedSourceText: "",
            replacementText: ",",
            claimedCategory: .punctuation
        )
        let protectedSpans = [ProtectedSpan(range: statuteRange, kind: .deterministicallyResolved)]
        let safeResult = IntelligenceSafetyAuthority.validate(proposals: [safeProposal], source: source, protectedSpans: protectedSpans)
        guard case .autonomouslyAccepted = safeResult.outcomes[0].disposition else {
            preconditionFailure("expected minimal-diff insertion outside the protected span to be autonomously accepted, got \(safeResult.outcomes[0].disposition)")
        }

        // Now a proposal whose resolved range DOES intersect the protected
        // span (replacing "302" with "303") must be forbidden outright.
        let numberRange = sourceNS.range(of: "302")
        let unsafeProposal = IntelligenceProposal(
            id: "change-number",
            range: numberRange,
            expectedSourceText: "302",
            replacementText: "303",
            claimedCategory: .other
        )
        let unsafeResult = IntelligenceSafetyAuthority.validate(proposals: [unsafeProposal], source: source, protectedSpans: protectedSpans)
        guard case .rejected(.intersectsResolvedSpan) = unsafeResult.outcomes[0].disposition else {
            preconditionFailure("expected protected-span intersection to be rejected outright, got \(unsafeResult.outcomes[0].disposition)")
        }
    }

    static func testLexicalMutationResolvedButRejectedByRealSafetyAuthority() {
        // The resolver's job is addressing, not permission: a proposal can
        // resolve perfectly (exact, unique, unambiguous) and still be a
        // substantive lexical edit the real Safety Authority must reject.
        let source = "he done the act as alleged"
        let sourceNS = source as NSString
        let ref = ModelFacingReference.replace("done")
        guard case .success(let range) = resolveReference(ref, in: sourceNS) else {
            preconditionFailure("expected 'done' to resolve uniquely")
        }
        let proposal = IntelligenceProposal(
            id: "lexical",
            range: range,
            expectedSourceText: "done",
            replacementText: "did",
            claimedCategory: .other
        )
        let result = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: source, protectedSpans: [])
        guard case .rejected(.unsupportedEditCategory) = result.outcomes[0].disposition else {
            preconditionFailure("expected lexical substitution to be rejected as unsupported category, got \(result.outcomes[0].disposition)")
        }
    }
}
