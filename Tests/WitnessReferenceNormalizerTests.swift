import Foundation

@main
enum WitnessReferenceNormalizerTests {
    static func main() {
        testProsecutionWitnessSpelledOut()
        testPWSpokenAsLetters()
        testDefenceWitnessSpelledOut()
        testDWSpokenAsLetters()
        testAlreadyCanonicalIsIdempotent()
        testMissingRoleIsNotACandidate()
        testSelfCorrectionDeclines()
        testUnrelatedHedgeDoesNotBlock()
        testNearMissWitnessAsVerb()
        testMultipleWitnessesInOneDictation()
        testSpanProvenance()
        print("PASS: WitnessReferenceNormalizer PW/DW forms, self-correction, and near-misses")
    }

    private static func context() -> NormalizationContext {
        NormalizationContext(resolvedTable: ResolvedNormalizationTable(entries: []), resolvedRecognitionVocabulary: nil)
    }

    private static func normalize(_ text: String) -> NormalizationPassResult {
        WitnessReferenceNormalizer().normalize(text, using: context())
    }

    private static func testProsecutionWitnessSpelledOut() {
        let result = normalize("as deposed by prosecution witness number one")
        precondition(result.text == "as deposed by PW-1", result.text)
        precondition(result.appliedChanges.count == 1)
    }

    private static func testPWSpokenAsLetters() {
        let result = normalize("P W two confirmed the recovery")
        precondition(result.text == "PW-2 confirmed the recovery", result.text)
    }

    private static func testDefenceWitnessSpelledOut() {
        let result = normalize("defence witness number one stated that")
        precondition(result.text == "DW-1 stated that", result.text)
    }

    private static func testDWSpokenAsLetters() {
        let result = normalize("D W two confirmed the alibi")
        precondition(result.text == "DW-2 confirmed the alibi", result.text)
    }

    private static func testAlreadyCanonicalIsIdempotent() {
        let result = normalize("PW-1 further stated")
        precondition(result.isUnchanged)
    }

    private static func testMissingRoleIsNotACandidate() {
        let result = normalize("witness number one")
        precondition(result.isUnchanged)
        precondition(result.appliedChanges.isEmpty && result.declinedChanges.isEmpty)
    }

    private static func testSelfCorrectionDeclines() {
        let input = "P W one, or was it P W two"
        let result = normalize(input)
        precondition(result.text == input, "Self-correction directly attached to the reference must decline and preserve the text")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
    }

    private static func testUnrelatedHedgeDoesNotBlock() {
        let result = normalize("I think P W one gave clear and consistent testimony")
        precondition(result.text == "I think PW-1 gave clear and consistent testimony", result.text)
        precondition(result.appliedChanges.count == 1)
    }

    private static func testNearMissWitnessAsVerb() {
        let result = normalize("witness the following developments in the case")
        precondition(result.isUnchanged)
    }

    private static func testMultipleWitnessesInOneDictation() {
        let result = normalize("as stated by P W one and D W two")
        precondition(result.text == "as stated by PW-1 and DW-2", result.text)
        precondition(result.appliedChanges.count == 2)
    }

    // MARK: - Span provenance (ranges index the pass's original input)

    private static func testSpanProvenance() {
        let applied = "as stated by P W one and defence witness number two today"
        let r1 = normalize(applied)
        precondition(r1.appliedChanges.count == 2)
        let spans = r1.appliedChanges.compactMap { change in change.range.map { (applied as NSString).substring(with: $0) } }
        precondition(spans == ["P W one", "defence witness number two"] || spans == ["defence witness number two", "P W one"], "\(spans)")

        let declined = "P W one, or was it P W two"
        let r2 = normalize(declined)
        precondition(r2.declinedChanges.count == 1)
        guard let range = r2.declinedChanges[0].range else { preconditionFailure("declined witness candidate must carry its span") }
        precondition((declined as NSString).substring(with: range) == r2.declinedChanges[0].trigger)
        precondition(range.location == 0)
    }
}
