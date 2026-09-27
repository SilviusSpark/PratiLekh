import Foundation

// EXPERIMENTAL -- Intelligence V1.3A architecture investigation only. See
// `DeterministicAddressingResolver.swift`'s header. Run via
// `scripts/test_v1_3a_experimental_resolver.sh`; not part of the normal
// `test_intelligence_safety.sh` acceptance gate, since this validates an
// unadopted experimental prototype, not committed V1.0/V1.1/V1.2 code.

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
enum ResolverPrototypeTests {
    static func main() {
        testB1RejectsShortAmbiguousFragments()
        testB1ZeroOccurrences()
        testB2OrdinalDisambiguation()
        testB3ContextAnchorDisambiguation()
        testB3FallsBackToAmbiguousWithoutContext()
        testInsertionAddressing()
        testInsertionRejectsAmbiguousAnchor()
        testInsertionRejectsEmptyAnchor()
        testIndianNameExactBinding()
        testOdiaIndicExactBinding()
        testNonBMPEmojiSurrogatePairCorrectness()
        testDeletionTarget()
        print("All V1.3A resolver-prototype checks passed.")
    }

    // B1 must reject the common case where a target is a single letter or a
    // short common word: real V1 edits are frequently this short, and such
    // fragments are almost always non-unique in realistic dictation-length
    // text. This is why B1 is measured here as insufficient ALONE.
    static func testB1RejectsShortAmbiguousFragments() {
        let source: NSString = "the witness confirmed the statement."
        expectFailure(resolveB1(source: source, sourceText: "t"), .ambiguousOccurrences(6))
        expectFailure(resolveB1(source: source, sourceText: "the"), .ambiguousOccurrences(2))
    }

    static func testB1ZeroOccurrences() {
        let source: NSString = "the witness confirmed the statement."
        expectFailure(resolveB1(source: source, sourceText: "nonexistent phrase"), .zeroOccurrences)
    }

    static func testB2OrdinalDisambiguation() {
        let source: NSString = "the accused said the accused left"
        expectSuccess(resolveB2(source: source, sourceText: "the accused", occurrence: 1), location: 0, length: 11)
        expectSuccess(resolveB2(source: source, sourceText: "the accused", occurrence: 2), location: 17, length: 11)
        expectFailure(resolveB2(source: source, sourceText: "the accused", occurrence: 3), .invalidOrdinal)
    }

    static func testB3ContextAnchorDisambiguation() {
        let source: NSString = "the accused said the accused left"
        expectSuccess(
            resolveB3(source: source, sourceText: "the accused", leftContext: nil, rightContext: " said"),
            location: 0,
            length: 11
        )
        expectSuccess(
            resolveB3(source: source, sourceText: "the accused", leftContext: "said ", rightContext: " left"),
            location: 17,
            length: 11
        )
    }

    static func testB3FallsBackToAmbiguousWithoutContext() {
        let source: NSString = "the accused said the accused left"
        expectFailure(
            resolveB3(source: source, sourceText: "the accused", leftContext: nil, rightContext: nil),
            .ambiguousOccurrences(2)
        )
    }

    static func testInsertionAddressing() {
        let endOfSentence: NSString = "The witness said he was present"
        expectSuccess(resolveInsertion(source: endOfSentence, anchorText: "present", side: .after), location: 31, length: 0)

        let midSentence: NSString = "However the accused denied the allegation"
        expectSuccess(resolveInsertion(source: midSentence, anchorText: "However", side: .after), location: 7, length: 0)
    }

    static func testInsertionRejectsAmbiguousAnchor() {
        let source: NSString = "the witness said the witness left"
        expectFailure(resolveInsertion(source: source, anchorText: "witness", side: .after), .ambiguousOccurrences(2))
    }

    static func testInsertionRejectsEmptyAnchor() {
        let source: NSString = "the witness confirmed the statement."
        expectFailure(resolveInsertion(source: source, anchorText: "", side: .after), .emptyAnchorForInsertion)
    }

    // Exact-substring resolution binds a multi-word Indian proper name
    // precisely, with no fuzzy/partial matching risk -- resolution alone;
    // this does not imply any name is ever eligible for autonomous editing.
    static func testIndianNameExactBinding() {
        let source: NSString = "the witness Rajesh Kumar Yadav confirmed the statement"
        expectSuccess(resolveB1(source: source, sourceText: "Rajesh Kumar Yadav"), location: 12, length: 18)
    }

    static func testOdiaIndicExactBinding() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}" // ଓଡ଼ିଶା
        let source = "The complainant resides in \(odia)  state" as NSString
        expectSuccess(resolveB1(source: source, sourceText: odia), location: 27, length: 6)
        // A downstream whitespace-fix target composes correctly from the
        // resolved anchor's own UTF-16 length -- no separate model-side
        // counting through the Indic text is required.
        guard case .success(let anchorRange) = resolveB1(source: source, sourceText: odia) else {
            preconditionFailure("expected odia anchor to resolve")
        }
        let doubleSpaceStart = anchorRange.location + anchorRange.length
        precondition(doubleSpaceStart == 33, "unexpected offset \(doubleSpaceStart)")
    }

    // The astral-plane emoji is a genuine UTF-16 surrogate pair (2 code
    // units for 1 Unicode scalar) -- exactly the case naive
    // character-counting gets wrong and NSString-based exact resolution
    // gets right for free.
    static func testNonBMPEmojiSurrogatePairCorrectness() {
        let emoji = "\u{1F60A}" // 😊
        precondition((emoji as NSString).length == 2, "expected astral-plane emoji to be a 2-unit UTF-16 surrogate pair")
        let source = "The accused smiled \(emoji)  during the hearing" as NSString
        expectSuccess(resolveB1(source: source, sourceText: emoji), location: 19, length: 2)
    }

    static func testDeletionTarget() {
        let source: NSString = "The witness  really said it"
        expectSuccess(resolveB1(source: source, sourceText: "really "), location: 13, length: 7)
    }
}
