import Foundation

/// Exercises `LegalDictationProcessor` with the real bundled Indian Legal Core.
/// The inputs model finalized dictation at the live seam: text that has already
/// been through the custom dictionary, spoken-punctuation and spoken-send
/// stages, immediately before optional AI. The seam itself lives in
/// `ContentView`; `scripts/test_legal_language.sh` also checks its ordering
/// structurally.
@main
enum LegalDictationProcessorTests {
    static func main() {
        let processor = makeProcessor()
        testStatutoryReference(processor)
        testWitnessReferences(processor)
        testMultiProvisionList(processor)
        testSpokenPunctuationNearLists(processor)
        testCustomDictionaryOutputReachesNormalizer(processor)
        testOrdinaryTextUnchanged(processor)
        testCanonicalReferencesStable(processor)
        testAmbiguousAndUnsupportedUnchanged(processor)
        testMultipleReferencesInOneDictation(processor)
        testProvenanceIndexesInput(processor)
        testMissingPackStillSafe()
        print("PASS: LegalDictationProcessor loads the bundled pack and normalizes finalized dictation")
    }

    // MARK: - Production pack loading

    private static func makeProcessor() -> LegalDictationProcessor {
        // Resolve through the production loader (`BuiltInPacks`) against the
        // real Resources directory, treated as a bundle.
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Fluid/Resources")
        guard let bundle = Bundle(path: resources.path),
              let pack = BuiltInPacks.indianLegalCore(bundle: bundle)
        else {
            preconditionFailure("BuiltInPacks must load the bundled Indian Legal Core from \(resources.path)")
        }
        precondition(pack.kind == .builtin && !pack.recognitionEntries.isEmpty)
        return LegalDictationProcessor(builtinPack: pack)
    }

    // MARK: - Cases

    private static func check(_ processor: LegalDictationProcessor, _ input: String, _ expected: String, line: UInt = #line) {
        let out = processor.process(input)
        precondition(out.normalized == expected, "line \(line): '\(input)' -> '\(out.normalized)', expected '\(expected)'")
        precondition(out.recognized == input)
    }

    private static func testStatutoryReference(_ p: LegalDictationProcessor) {
        check(p, "the accused is charged under section three zero two of the I P C", "the accused is charged under Section 302 IPC")
        check(p, "framed under section three seven six A of the Indian Penal Code", "framed under Section 376A IPC")
    }

    private static func testWitnessReferences(_ p: LegalDictationProcessor) {
        check(p, "P W one stated that", "PW-1 stated that")
        check(p, "defence witness number two denied it", "DW-2 denied it")
    }

    private static func testMultiProvisionList(_ p: LegalDictationProcessor) {
        check(
            p,
            "sections two nine four, three two three, three four one and five zero six of the I P C",
            "Sections 294, 323, 341 and 506 IPC"
        )
    }

    private static func testSpokenPunctuationNearLists(_ p: LegalDictationProcessor) {
        // Spoken punctuation has already produced commas/periods by this point.
        check(
            p,
            "Offences under sections two nine four, three two three and five zero six of the I P C.",
            "Offences under Sections 294, 323 and 506 IPC."
        )
        check(p, "He said, section three zero two of the I P C, applies.", "He said, Section 302 IPC, applies.")
    }

    private static func testCustomDictionaryOutputReachesNormalizer(_ p: LegalDictationProcessor) {
        // A user dictionary entry (e.g. "eye pee see" -> "I P C" / "IPC") has
        // already been applied by ASRService.stop before the seam.
        check(p, "under section three zero two IPC", "under Section 302 IPC")
        // If the dictionary rewrote the *trigger* word instead, the legal
        // rule simply no longer matches and the text is preserved.
        check(p, "under clause three zero two of the I P C", "under clause three zero two of the I P C")
    }

    private static func testOrdinaryTextUnchanged(_ p: LegalDictationProcessor) {
        for text in [
            "The court adjourned the matter to the next date.",
            "We must witness the following developments.",
            "This section of the road is closed.",
            "",
        ] {
            let out = p.process(text)
            precondition(out.normalized == text && out.isUnchanged, "ordinary text changed: '\(text)' -> '\(out.normalized)'")
        }
    }

    private static func testCanonicalReferencesStable(_ p: LegalDictationProcessor) {
        for text in ["Section 302 IPC", "Sections 294, 323, 341 and 506 IPC", "PW-1 stated", "DW-2 denied"] {
            let once = p.process(text).normalized
            precondition(once == text, "canonical form changed: '\(text)' -> '\(once)'")
            precondition(p.process(once).normalized == once)
        }
        // Idempotence of produced output.
        let produced = p.process("section three zero two of the I P C and P W one").normalized
        precondition(p.process(produced).normalized == produced)
    }

    private static func testAmbiguousAndUnsupportedUnchanged(_ p: LegalDictationProcessor) {
        for text in [
            "section three zero two I P C and one zero one B N S",
            "section three zero two read with section thirty four of the I P C",
            "section three zero two, or possibly three zero four of the I P C",
            "P W one, or was it P W two",
        ] {
            let out = p.process(text)
            precondition(out.normalized == text, "ambiguous text was altered: '\(text)' -> '\(out.normalized)'")
            precondition(!out.declinedChanges.isEmpty, "expected an explicit decline for '\(text)'")
        }
    }

    private static func testMultipleReferencesInOneDictation(_ p: LegalDictationProcessor) {
        check(
            p,
            "P W one proved section three zero two of the I P C while D W two disputed section one zero one of the B N S",
            "PW-1 proved Section 302 IPC while DW-2 disputed Section 101 BNS"
        )
    }

    private static func testProvenanceIndexesInput(_ p: LegalDictationProcessor) {
        let input = "as P W one said under section three zero two of the I P C"
        let out = p.process(input)
        precondition(out.appliedChanges.count == 2)
        // The statutory pass runs first, so its span indexes `input`.
        let statutory = out.appliedChanges.first { $0.sourcePackID == "phase3.statutoryProvision" }
        precondition(statutory?.range.map { (input as NSString).substring(with: $0) } == "section three zero two of the I P C")
        precondition(out.appliedChanges.allSatisfy { $0.range != nil })
    }

    private static func testMissingPackStillSafe() {
        let p = LegalDictationProcessor(builtinPack: nil)
        precondition(p.process("nothing legal here").isUnchanged)
        precondition(p.process("P W one stated").normalized == "PW-1 stated", "witness rules do not need the pack")
    }
}
