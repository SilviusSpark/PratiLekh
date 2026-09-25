import Foundation

/// Executable form of the Phase 3B-approved, Phase 3C-refined golden corpus
/// for statutory provision references. Uses a fixture pack mirroring the
/// real Indian Legal Core's statute entries (not the bundled JSON -- this
/// standalone binary has no app bundle; see IndianLegalCorePackTests.swift
/// for the production-pack-loading test).
@main
enum StatutoryProvisionNormalizerTests {
    static func main() {
        testBareSectionWithoutStatute()
        testSectionWithStatute()
        testLetterSuffix()
        testBoundedTwoSectionPlural()
        testTwoIndependentSingularReferencesSameStatuteFamily()
        testTwoIndependentSingularReferencesDifferentStatutes()
        testAlreadyNormalizedBareIsIdempotent()
        testAlreadyNormalizedWithStatuteIsIdempotent()
        testMalformedNumberDeclines()
        testNumberUncertaintyDeclines()
        testStatuteUncertaintyDeclinesWholeCandidateNotBareFallback()
        testUnrelatedHedgeElsewhereDoesNotBlockCitation()
        testReadWithIsUnsupported()
        testSubSectionIsUnsupported()
        testSectionRangeIsUnsupported()
        testAmbiguousBareContinuationDeclinesWholeStructure()
        testNearMissGenericSectionWord()
        testMultipleSafeTransformationsInOneDictation()
        testMixedAppliedAndDeclinedInOneDictation()
        testExactSpanPunctuationPreservation()
        testPunctuationOutsideMatchedSpanIsUntouched()

        testMultiProvisionListSpokenNumbers()
        testAlreadyCompactSlashFormIsNotTouched()
        testMultiProvisionListWithLetterSuffix()
        testTwoAndThreePlusItemListsRenderViaTheSameMechanism()
        testUncertainMemberDeclinesEntireList()
        testMalformedMemberDeclinesEntireList()
        testBareMultiProvisionListWithoutStatuteDeclines()
        testCrossStatuteNeverSlashMerged()
        testSpanProvenance()

        print("PASS: StatutoryProvisionNormalizer golden corpus (singular, bounded plural, multi-provision list)")
    }

    // MARK: - Fixture vocabulary (mirrors the real Indian Legal Core's statute entries)

    private static func statuteVocabulary() -> ResolvedRecognitionVocabulary {
        let pack = LanguagePack(
            id: "fixture.statutes",
            version: "1.0.0",
            kind: .builtin,
            displayName: "Fixture Statutes",
            recognitionEntries: [
                RecognitionEntry(canonical: "Bharatiya Nyaya Sanhita, 2023", aliases: ["BNS"]),
                RecognitionEntry(canonical: "Bharatiya Nagarik Suraksha Sanhita, 2023", aliases: ["BNSS"]),
                RecognitionEntry(canonical: "Bharatiya Sakshya Adhiniyam, 2023", aliases: ["BSA"]),
                RecognitionEntry(canonical: "Indian Penal Code, 1860", aliases: ["IPC"]),
                RecognitionEntry(canonical: "Code of Criminal Procedure, 1973", aliases: ["CrPC"]),
                RecognitionEntry(canonical: "Indian Evidence Act, 1872", aliases: []),
                RecognitionEntry(canonical: "Code of Civil Procedure, 1908", aliases: ["CPC"]),
            ],
            normalizationEntries: []
        )
        return PrecedenceResolver.resolveRecognitionVocabulary(from: [pack])
    }

    private static func context() -> NormalizationContext {
        NormalizationContext(resolvedTable: ResolvedNormalizationTable(entries: []), resolvedRecognitionVocabulary: statuteVocabulary())
    }

    private static func normalize(_ text: String) -> NormalizationPassResult {
        StatutoryProvisionNormalizer().normalize(text, using: context())
    }

    // MARK: - Section without statute (shape 1)

    private static func testBareSectionWithoutStatute() {
        let result = normalize("under section three zero two")
        precondition(result.text == "under Section 302", result.text)
        precondition(result.appliedChanges.count == 1)
        precondition(result.declinedChanges.isEmpty)
    }

    // MARK: - Section with statute (shape 2)

    private static func testSectionWithStatute() {
        let result = normalize("under section three zero two of the I P C")
        precondition(result.text == "under Section 302 IPC", result.text)
        precondition(result.appliedChanges.count == 1)
    }

    private static func testLetterSuffix() {
        let result = normalize("framed under section three seven six A of the Indian Penal Code")
        precondition(result.text == "framed under Section 376A IPC", result.text)
    }

    // MARK: - Bounded two-section plural (shape 3)

    private static func testBoundedTwoSectionPlural() {
        let result = normalize("charged under sections three zero two and three zero four of the I P C")
        precondition(result.text == "charged under Sections 302 and 304 IPC", result.text)
        precondition(result.appliedChanges.count == 1)
    }

    // MARK: - Two independently bounded singular references

    private static func testTwoIndependentSingularReferencesSameStatuteFamily() {
        let result = normalize("section three zero two I P C and section one twenty B I P C")
        precondition(result.text == "Section 302 IPC and Section 120B IPC", result.text)
        precondition(result.appliedChanges.count == 2)
    }

    private static func testTwoIndependentSingularReferencesDifferentStatutes() {
        let result = normalize("section three zero two I P C and section one zero one B N S")
        precondition(result.text == "Section 302 IPC and Section 101 BNS", result.text)
        precondition(result.appliedChanges.count == 2)
    }

    // MARK: - Idempotence

    private static func testAlreadyNormalizedBareIsIdempotent() {
        let result = normalize("under Section 302")
        precondition(result.isUnchanged, "Already-canonical bare form must not be re-touched")
    }

    private static func testAlreadyNormalizedWithStatuteIsIdempotent() {
        let result = normalize("under Section 302 IPC")
        precondition(result.isUnchanged, "Already-canonical form must not be re-touched")
    }

    // MARK: - Malformed / unclear numbers

    private static func testMalformedNumberDeclines() {
        // "section" with no recognizable number at all following it is not a
        // candidate -- near-miss, not a decline.
        let result = normalize("this section of the argument deals with bail")
        precondition(result.isUnchanged)
        precondition(result.appliedChanges.isEmpty && result.declinedChanges.isEmpty)
    }

    // MARK: - Uncertainty directly attached

    private static func testNumberUncertaintyDeclines() {
        let input = "section three zero two, or possibly three zero four"
        let result = normalize(input)
        precondition(result.text == input, "Uncertainty about the number itself must fully decline and preserve the original text")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
        precondition(result.declinedChanges[0].reason.hasPrefix("unresolvedUncertainty"))
    }

    private static func testStatuteUncertaintyDeclinesWholeCandidateNotBareFallback() {
        let input = "section three zero two of the Indian Penal Code, or possibly the Bharatiya Nyaya Sanhita"
        let result = normalize(input)
        precondition(result.text == input, "Statute uncertainty must decline the whole candidate, never fall back to bare 'Section 302'")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
    }

    private static func testUnrelatedHedgeElsewhereDoesNotBlockCitation() {
        let result = normalize("I think the prosecution failed to prove the charge under section three zero two IPC")
        precondition(result.text == "I think the prosecution failed to prove the charge under Section 302 IPC", result.text)
        precondition(result.appliedChanges.count == 1, "A hedge governing the outer clause must not block the citation")
    }

    // MARK: - Unsupported structures

    private static func testReadWithIsUnsupported() {
        let input = "section three zero two read with section three four of the IPC"
        let result = normalize(input)
        precondition(result.text == input, "'read with' must remain fully unchanged, not partially formatted")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
        precondition(result.declinedChanges[0].reason.hasPrefix("unsupportedStructure"))
    }

    private static func testSubSectionIsUnsupported() {
        let input = "section three zero two sub section two of the IPC"
        let result = normalize(input)
        precondition(result.text == input)
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
    }

    private static func testSectionRangeIsUnsupported() {
        let input = "sections three zero two to three zero four of the IPC"
        let result = normalize(input)
        precondition(result.text == input, "Section ranges must never be converted")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
    }

    private static func testAmbiguousBareContinuationDeclinesWholeStructure() {
        let input = "section three zero two IPC and one zero one BNS"
        let result = normalize(input)
        precondition(result.text == input, "Omitted second 'section' keyword must never be inferred")
        precondition(result.declinedChanges.count == 1)
        precondition(result.appliedChanges.isEmpty)
    }

    private static func testNearMissGenericSectionWord() {
        let result = normalize("this section of the argument deals with bail")
        precondition(result.isUnchanged)
    }

    // MARK: - Multiple / mixed outcomes

    private static func testMultipleSafeTransformationsInOneDictation() {
        let result = normalize("charged under section three zero two I P C and section one twenty B I P C")
        precondition(result.appliedChanges.count == 2)
        precondition(result.text == "charged under Section 302 IPC and Section 120B IPC", result.text)
    }

    private static func testMixedAppliedAndDeclinedInOneDictation() {
        let result = normalize(
            "section three zero two IPC. section three zero two read with section three four of the IPC."
        )
        precondition(result.appliedChanges.count == 1, "The clean citation must still apply")
        precondition(result.declinedChanges.count == 1, "The unsupported structure must be recorded, not silently dropped")
    }

    // MARK: - Punctuation: exact-span replacement only
    //
    // Punctuation ownership *within* a matched span (e.g. a comma sitting
    // between the number and the statute, both of which are part of what's
    // being replaced) was left an explicit open design question in Phase
    // 3B -- this test only asserts what Phase 3C actually commits to:
    // text strictly outside the matched span (the sentence's lead-in and
    // trailing period) is preserved byte-for-byte, and nothing is fabricated.

    private static func testExactSpanPunctuationPreservation() {
        let result = normalize("he was charged under section three zero two, I P C.")
        precondition(result.text.hasPrefix("he was charged under Section 302"), result.text)
        precondition(result.text.hasSuffix("IPC."), result.text)
        precondition(result.appliedChanges.count == 1)
    }

    private static func testPunctuationOutsideMatchedSpanIsUntouched() {
        let result = normalize("(see section three zero two of the IPC)")
        precondition(result.text == "(see Section 302 IPC)", result.text)
    }

    // MARK: - Multi-provision lists (neutral expanded rendering)
    //
    // Phase 3C.1: comma presence in the dictated input no longer selects a
    // different output format. A comma-and-"and" enumerated list and a
    // plain two-item "and" list are the same kind of parsed structure
    // (`StatutoryProvisionReference`), rendered identically by
    // `StatutoryProvisionRenderer`. The compact "u/s N1/N2/.../of <statute>"
    // style is a recorded future rendering preference (Phase 4+), not
    // built here -- see `StatutoryProvisionReference.swift`.

    private static func testMultiProvisionListSpokenNumbers() {
        let result = normalize("under sections two nine four, three two three, three four one and five zero six of IPC")
        precondition(result.text == "under Sections 294, 323, 341 and 506 IPC", result.text)
        precondition(result.appliedChanges.count == 1)
    }

    private static func testAlreadyCompactSlashFormIsNotTouched() {
        // "u/s 294/323/341/506 of IPC" is a valid compact written form, but
        // Phase 3C's parser never recognizes it as a candidate at all (it
        // only triggers on the words "section"/"sections") -- leaving it
        // unchanged is correct, per the "do not destructively expand an
        // already-valid compact form" requirement. No new compact-notation
        // parser was added to make this assertion true; it already held.
        let result = normalize("under u/s 294/323/341/506 of IPC")
        precondition(result.isUnchanged, "Compact written notation must not be touched or re-expanded")
    }

    private static func testMultiProvisionListWithLetterSuffix() {
        let result = normalize("under sections two nine four, three two three A and five zero six of IPC")
        precondition(result.text == "under Sections 294, 323A and 506 IPC", result.text)
    }

    private static func testTwoAndThreePlusItemListsRenderViaTheSameMechanism() {
        // Same shape (a "sections ... <statute>" reference with 2+ ordered
        // provisions), same renderer -- differing only in element count.
        let two = normalize("sections three zero two and three zero four of IPC")
        precondition(two.text == "Sections 302 and 304 IPC", two.text)
        let three = normalize("sections three zero two, three zero four and three four one of IPC")
        precondition(three.text == "Sections 302, 304 and 341 IPC", three.text)
    }

    private static func testUncertainMemberDeclinesEntireList() {
        let input = "sections two nine four, three two three and maybe five zero six IPC"
        let result = normalize(input)
        precondition(result.text == input, "One uncertain member must decline the entire list, not produce a partial one")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
    }

    private static func testMalformedMemberDeclinesEntireList() {
        // The final "member" position is immediately the statute, not a
        // number -- not a valid list at all. Must be an explicit decline
        // with the original text preserved, not silently ignored and not a
        // partial application of the first two members.
        let input = "sections two nine four, three two three and IPC"
        let result = normalize(input)
        precondition(result.text == input, "Malformed list member must decline, preserving the original text")
        precondition(result.appliedChanges.isEmpty, "Must never emit a partial list")
        precondition(result.declinedChanges.count == 1, "Must be an explicit decline, not silent")
    }

    private static func testBareMultiProvisionListWithoutStatuteDeclines() {
        let input = "sections two nine four, three two three and five zero six"
        let result = normalize(input)
        precondition(result.text == input, "No approved bare-list canonical form exists in Phase 3C -- must decline, not fabricate one")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1, "Must be an explicit decline, not silent")
    }

    private static func testCrossStatuteNeverSlashMerged() {
        let result = normalize("section three zero two IPC and section one zero one BNS")
        precondition(result.text == "Section 302 IPC and Section 101 BNS", result.text)
        precondition(!result.text.contains("u/s"), "Different statutes must never be slash-merged")
        precondition(result.appliedChanges.count == 2)
    }

    // MARK: - Span provenance (ranges index the pass's original input)

    private static func source(_ input: String, _ range: NSRange?) -> String? {
        range.map { (input as NSString).substring(with: $0) }
    }

    private static func testSpanProvenance() {
        let singular = "under section three zero two of the I P C, the accused"
        let r1 = normalize(singular)
        precondition(r1.appliedChanges.count == 1)
        precondition(source(singular, r1.appliedChanges[0].range) == "section three zero two of the I P C", "\(String(describing: r1.appliedChanges[0].range))")

        let plural = "charged under sections three zero two and three zero four of the I P C today"
        let r2 = normalize(plural)
        precondition(source(plural, r2.appliedChanges[0].range) == "sections three zero two and three zero four of the I P C")

        let declined = "held that section three zero two, or possibly three zero four, applies"
        let r3 = normalize(declined)
        precondition(r3.declinedChanges.count == 1)
        let span3 = source(declined, r3.declinedChanges[0].range)
        precondition(span3?.hasPrefix("section three zero two") == true, "\(String(describing: span3))")
        precondition(span3 == r3.declinedChanges[0].trigger, "Decline span must match the preserved trigger text")

        // Two applied candidates: both ranges index the original input, not the rewritten text.
        let two = "section three zero two of the I P C and section one zero one of the B N S"
        let r4 = normalize(two)
        let spans = r4.appliedChanges.compactMap { source(two, $0.range) }.sorted()
        precondition(spans.count == 2 && spans.contains("section three zero two of the I P C"), "\(spans)")
    }
}
