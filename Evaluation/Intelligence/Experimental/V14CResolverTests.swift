import Foundation

// EXPERIMENTAL -- Intelligence V1.4C architecture investigation only.
// Deterministic, Ollama-free adversarial matrix (A1-A20) for the precise
// P3 decision procedure in `V1_4C_P3Adversarial.swift`. Run via
// `scripts/test_v1_4c_experimental_policies.sh`.

private func expect(
    _ actual: P3PreciseOutcome,
    _ expected: P3PreciseOutcome,
    file: StaticString = #file,
    line: UInt = #line
) {
    precondition(actual == expected, "expected \(expected), got \(actual)", file: file, line: line)
}

@main
enum V14CResolverTests {
    static func main() {
        testA1_uniqueSourceNoDiscriminator()
        testA2_uniqueSourceCorrectOccurrence()
        testA3_uniqueSourceIncorrectOccurrence()
        testA4_uniqueSourceIncorrectContext()
        testA5_repeatedCorrectOccurrenceOnly()
        testA6_repeatedInvalidOccurrenceOnly()
        testA7_repeatedCorrectContextOnly()
        testA8_repeatedAmbiguousContextOnly()
        testA9_repeatedOccurrenceAndAgreeingContext()
        testA10_repeatedOccurrenceWithUninformativeContext()
        testA11_repeatedInvalidOccurrenceUniquelyCorrectContext()
        testA12_repeatedContradiction()
        testA13_mutuallyConsistentWrongLocationIsUndetectable()
        testA14_offByOneOccurrenceVariants()
        testA15_adjacentIdenticalRepetition()
        testA16_substringContainment()
        testA17_contextContainingTargetItself()
        testA18_emptyVsAbsentContext()
        testA19_veryLongContext()
        testA20_unicodeContradictionAndFallback()
        print("All V1.4C adversarial checks passed.")
    }

    // A1 -- unique source, no discriminator.
    static func testA1_uniqueSourceNoDiscriminator() {
        let source = "The witness confirmed the statement." as NSString
        let (outcome, range) = resolveP3Precise(.replace("confirmed"), in: source)
        expect(outcome, .resolvedUnambiguousSource)
        precondition(range == (source.range(of: "confirmed")))
    }

    // A2 -- unique source + correct occurrence.
    static func testA2_uniqueSourceCorrectOccurrence() {
        let source = "The witness confirmed the statement." as NSString
        let (outcome, _) = resolveP3Precise(.replace("confirmed", occurrence: 1), in: source)
        expect(outcome, .resolvedOccurrenceAgreesWithUniqueSource)
    }

    // A3 -- unique source + incorrect occurrence: explicit false evidence
    // is significant, not silently ignored.
    static func testA3_uniqueSourceIncorrectOccurrence() {
        let source = "The witness confirmed the statement." as NSString
        let (outcome, range) = resolveP3Precise(.replace("confirmed", occurrence: 2), in: source)
        expect(outcome, .rejectedOccurrenceContradictsUnique)
        precondition(range == nil)
    }

    // A4 -- unique source + incorrect context: same principle.
    static func testA4_uniqueSourceIncorrectContext() {
        let source = "The witness confirmed the statement." as NSString
        let (outcome, range) = resolveP3Precise(.replace("confirmed", leftContext: "wrong prefix "), in: source)
        expect(outcome, .rejectedContextContradictsUnique)
        precondition(range == nil)
    }

    // A5 -- repeated source + correct occurrence only.
    static func testA5_repeatedCorrectOccurrenceOnly() {
        let source = "the accused said the accused left" as NSString
        let (outcome, range) = resolveP3Precise(.replace("the accused", occurrence: 2), in: source)
        expect(outcome, .resolvedOccurrenceOnly)
        precondition(range?.location == 17)
    }

    // A6 -- repeated source + invalid occurrence only.
    static func testA6_repeatedInvalidOccurrenceOnly() {
        let source = "the accused said the accused left" as NSString
        let (outcome, _) = resolveP3Precise(.replace("the accused", occurrence: 5), in: source)
        expect(outcome, .rejectedInvalidOccurrenceNoContext)
    }

    // A7 -- repeated source + correct context only (context-alone fallback).
    static func testA7_repeatedCorrectContextOnly() {
        let source = "the accused said the accused left" as NSString
        let (outcome, range) = resolveP3Precise(.replace("the accused", rightContext: " left"), in: source)
        expect(outcome, .resolvedContextOnlyFallback)
        precondition(range?.location == 17)
    }

    // A8 -- repeated source + ambiguous context only.
    static func testA8_repeatedAmbiguousContextOnly() {
        let source = "the accused left, the accused left again." as NSString
        let (outcome, _) = resolveP3Precise(.replace("the accused", rightContext: " left"), in: source)
        expect(outcome, .rejectedAmbiguousContextOnly)
    }

    // A9 -- repeated source + correct occurrence + agreeing context.
    static func testA9_repeatedOccurrenceAndAgreeingContext() {
        let source = "the accused said the accused left" as NSString
        let (outcome, range) = resolveP3Precise(.replace("the accused", occurrence: 2, rightContext: " left"), in: source)
        expect(outcome, .resolvedOccurrenceAndContextAgree)
        precondition(range?.location == 17)
    }

    // A10 -- repeated source + correct occurrence + context that is merely
    // insufficient to narrow anything on its own (NOT contradictory --
    // this is the "corroboration absent vs. contradictory" distinction
    // the milestone requires to be explicit).
    static func testA10_repeatedOccurrenceWithUninformativeContext() {
        let source = "the accused said the accused left" as NSString
        // rightContext "" would be treated as absent; use a context value
        // that independently matches NEITHER occurrence (not "the wrong
        // one" -- genuinely uninformative, e.g. text that never appears).
        let ref = ModelFacingReference.replace("the accused", occurrence: 2, rightContext: " nonexistent-neighbor")
        let (outcome, range) = resolveP3Precise(ref, in: source)
        expect(outcome, .resolvedOccurrenceContextUninformative)
        precondition(range?.location == 17)
    }

    // A11 -- the principal P3 fallback case: invalid occurrence, uniquely
    // correct context recovers the proposal.
    static func testA11_repeatedInvalidOccurrenceUniquelyCorrectContext() {
        let source = "the accused said the accused left" as NSString
        let ref = ModelFacingReference.replace("the accused", occurrence: 9, rightContext: " left")
        let (outcome, range) = resolveP3Precise(ref, in: source)
        expect(outcome, .resolvedContextFallback)
        precondition(range?.location == 17)
    }

    // A12 -- genuine contradiction: valid occurrence, context uniquely
    // identifies a DIFFERENT occurrence. No precedence; reject.
    static func testA12_repeatedContradiction() {
        let source = "the accused said, the accused left" as NSString
        // occurrence=2 -> second "the accused"; rightContext " said" only
        // matches the FIRST occurrence.
        let ref = ModelFacingReference.replace("the accused", occurrence: 2, rightContext: " said")
        let (outcome, range) = resolveP3Precise(ref, in: source)
        expect(outcome, .rejectedGenuineContradiction)
        precondition(range == nil)
    }

    // A13 -- both discriminators agree with each other but (per external
    // ground truth the resolver cannot see) identify the WRONG occurrence.
    // The resolver necessarily resolves consistently -- this is not a
    // resolver defect; it is a model semantic-addressing risk that
    // deterministic code cannot detect from supplied evidence alone. This
    // test documents that fact rather than "fixing" it.
    static func testA13_mutuallyConsistentWrongLocationIsUndetectable() {
        let source = "the accused said the accused left" as NSString
        // Suppose external ground truth intended occurrence 2, but the
        // model consistently (and wrongly, by that external truth)
        // supplies occurrence=1 with agreeing context " said".
        let ref = ModelFacingReference.replace("the accused", occurrence: 1, rightContext: " said")
        let (outcome, range) = resolveP3Precise(ref, in: source)
        expect(outcome, .resolvedOccurrenceAndContextAgree)
        // The resolver did exactly what internally-consistent evidence
        // demands -- resolving to occurrence 1, not 2. No deterministic
        // check can catch this; it must be measured at the model layer.
        precondition(range?.location == 0)
    }

    // A14 -- off-by-one variants: 0, N+1, one below, one above.
    static func testA14_offByOneOccurrenceVariants() {
        let source = "the accused said the accused left" as NSString // 2 occurrences
        expect(resolveP3Precise(.replace("the accused", occurrence: 0), in: source).outcome, .rejectedInvalidOccurrenceNoContext)
        expect(resolveP3Precise(.replace("the accused", occurrence: 3), in: source).outcome, .rejectedInvalidOccurrenceNoContext)
        expect(resolveP3Precise(.replace("the accused", occurrence: 1), in: source).outcome, .resolvedOccurrenceOnly)
        expect(resolveP3Precise(.replace("the accused", occurrence: 2), in: source).outcome, .resolvedOccurrenceOnly)
    }

    // A15 -- adjacent identical repetition; occurrence enumeration must
    // remain deterministic and non-overlapping.
    static func testA15_adjacentIdenticalRepetition() {
        let source = "the the the" as NSString
        let occs = findExactOccurrences(of: "the", in: source)
        precondition(occs.count == 3, "expected 3 non-overlapping occurrences, got \(occs.count)")
        precondition(occs[0].location == 0 && occs[1].location == 4 && occs[2].location == 8)
        expect(resolveP3Precise(.replace("the", occurrence: 2), in: source).outcome, .resolvedOccurrenceOnly)
    }

    // A16 -- substring containment ("Act" inside "Action") must not
    // corrupt occurrence enumeration of the shorter literal target.
    static func testA16_substringContainment() {
        let source = "Act one preceded Action two, then Act three." as NSString
        let occs = findExactOccurrences(of: "Act", in: source)
        // "Act" occurs at the literal start of "Act one", inside "Action"
        // (as its own literal prefix), and at "Act three" -- exact
        // substring search finds all three, since "Action" DOES contain
        // the literal substring "Act".
        precondition(occs.count == 3, "expected 3 occurrences of the literal substring 'Act', got \(occs.count)")
        expect(resolveP3Precise(.replace("Act", occurrence: 2), in: source).outcome, .resolvedOccurrenceOnly)
    }

    // A17 -- context containing the target text itself must not
    // recursively change occurrence cardinality or match a different
    // structure than intended.
    static func testA17_contextContainingTargetItself() {
        let source = "the witness said the witness said the witness left" as NSString
        // rightContext itself contains "the witness" again -- this must
        // not be treated as re-matching; it is compared as an exact
        // literal adjacent string, independent of its own content.
        let ref = ModelFacingReference.replace("the witness", rightContext: " said the witness said")
        let (outcome, range) = resolveP3Precise(ref, in: source)
        expect(outcome, .resolvedContextOnlyFallback)
        precondition(range?.location == 0)
    }

    // A18 -- empty string context must NOT act as a universal match;
    // it must be treated identically to context being absent.
    static func testA18_emptyVsAbsentContext() {
        let source = "the accused said the accused left" as NSString
        var ref = ModelFacingReference.replace("the accused", occurrence: 1)
        ref.leftContext = ""   // explicitly empty, not nil
        ref.rightContext = ""  // explicitly empty, not nil
        let (outcome, _) = resolveP3Precise(ref, in: source)
        // Empty strings must be treated as "no context supplied" -- this
        // resolves via occurrence alone, not as agreeing/uninformative
        // context (which would imply context was meaningfully evaluated).
        expect(outcome, .resolvedOccurrenceOnly)
    }

    // A19 -- very long context is accepted literally, with no production
    // length limit imposed here, and does not itself introduce ambiguity
    // when it is exact and immediately adjacent.
    static func testA19_veryLongContext() {
        let filler = String(repeating: "padding ", count: 200)
        let source = "\(filler)the accused said the accused left" as NSString
        var ref = ModelFacingReference.replace("the accused", occurrence: nil)
        ref.leftContext = filler + "the accused said " // exact, immediately adjacent to the 2nd occurrence
        let (outcome, range) = resolveP3Precise(ref, in: source)
        expect(outcome, .resolvedContextOnlyFallback)
        precondition(range?.location == (source.length - "the accused left".utf16.count))
    }

    // A20 -- Unicode: repeat selected contradiction/fallback cases with
    // Odia and non-BMP emoji content.
    static func testA20_unicodeContradictionAndFallback() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}" // ଓଡ଼ିଶା
        let source = "The complainant resides in \(odia). The witness also resides in \(odia)." as NSString
        // Fallback: invalid occurrence, uniquely correct context.
        let fallbackRef = ModelFacingReference.replace(odia, occurrence: 9, rightContext: ". The witness")
        expect(resolveP3Precise(fallbackRef, in: source).outcome, .resolvedContextFallback)

        let emoji = "\u{1F60A}"
        let emojiSource = "The accused smiled \(emoji) once. The witness smiled \(emoji) twice." as NSString
        // Contradiction: valid occurrence (2nd), context uniquely
        // identifies the FIRST occurrence instead.
        let contradictionRef = ModelFacingReference.replace(emoji, occurrence: 2, rightContext: " once")
        expect(resolveP3Precise(contradictionRef, in: emojiSource).outcome, .rejectedGenuineContradiction)
    }
}
