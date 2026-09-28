import Foundation

/// Characterization tests recording WHICH TEXT each normalization provenance
/// range refers to today, as observed in the V1.9 investigation (see
/// `Evaluation/Intelligence/V1_9_PROTECTED_SPAN_COORDINATE_FINDINGS.md`). They
/// describe current behavior only -- they do not prescribe how provenance
/// should change. If normalization provenance is changed for any reason, these
/// assertions are expected to be revisited deliberately rather than silently
/// invalidated.
///
/// Nothing here derives protected spans; it only asserts what the existing
/// provenance does and does not record.
@main
enum NormalizationProvenanceCoordinateTests {
    static func main() {
        let pack = self.realPack()
        let processor = LegalDictationProcessor(builtinPack: pack)

        self.testRangesAreUTF16(processor)
        self.testStatutoryRangesIndexTheRecognizedInputPreChange(processor)
        self.testAppliedChangesWithinAPassAreDescendingAndAllPreChange(processor)
        self.testWitnessRangesIndexTheStatutoryOutputNotRecognizedNorFinalText(processor, pack: pack)
        self.testAppliedProvenanceReconstructsTheFinalTextWhenPassIsKnown(processor)
        self.testDeclinedRangesIndexTheirPassInputAndTextIsPreserved(processor)
        self.testLookupProvenanceHasNoRangesAndShiftsLaterCoordinates(pack: pack)
        self.testProvenanceRecordsCarryNoTypedPassIdentity()
        print("PASS: normalization provenance coordinate model as currently observed (UTF-16, per-pass input coordinates, no typed pass identity)")
    }

    // MARK: - Fixtures

    private static func realPack() -> LanguagePack {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Fluid/Resources")
        guard let bundle = Bundle(path: resources.path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            preconditionFailure("BuiltInPacks must load the bundled Indian Legal Core from \(resources.path)")
        }
        return pack
    }

    private static func substring(_ text: String, _ range: NSRange) -> String? {
        let ns = text as NSString
        guard range.location >= 0, range.length >= 0, range.location + range.length <= ns.length else { return nil }
        return ns.substring(with: range)
    }

    private static func range(_ change: AppliedNormalizationChange, file: StaticString = #file, line: UInt = #line) -> NSRange {
        guard let range = change.range else { preconditionFailure("expected a range on \(change.sourcePackID)", file: file, line: line) }
        return range
    }

    private static let statutory = "phase3.statutoryProvision"
    private static let witness = "phase3.witnessReference"

    // MARK: - Tests

    private static func testRangesAreUTF16(_ processor: LegalDictationProcessor) {
        // Two non-BMP glyphs (2 UTF-16 units each) precede the reference:
        // location 5 = 2 + 2 + 1, not the 3 Swift Characters before it.
        let input = "\u{1F60A}\u{1F60A} section three zero two I P C"
        let outcome = processor.process(input)
        guard let change = outcome.appliedChanges.first(where: { $0.sourcePackID == self.statutory }) else { preconditionFailure("expected a statutory change") }
        precondition(self.range(change).location == 5, "ranges are UTF-16 offsets: \(self.range(change))")
        precondition(self.substring(input, self.range(change)) == change.trigger)
    }

    private static func testStatutoryRangesIndexTheRecognizedInputPreChange(_ processor: LegalDictationProcessor) {
        let input = "the accused is charged under section three zero two of the I P C"
        let outcome = processor.process(input)
        precondition(outcome.normalized == "the accused is charged under Section 302 IPC")
        let change = outcome.appliedChanges[0]
        precondition(self.substring(input, self.range(change)) == change.trigger, "range indexes the pre-change input")
        precondition(self.substring(outcome.normalized, self.range(change)) == nil, "the same range is out of bounds in the final text (shorter)")
    }

    private static func testAppliedChangesWithinAPassAreDescendingAndAllPreChange(_ processor: LegalDictationProcessor) {
        let input = "section two nine four and section three two three I P C then section three zero two B N S"
        let outcome = processor.process(input)
        let statutory = outcome.appliedChanges.filter { $0.sourcePackID == self.statutory }
        precondition(statutory.count == 3)
        precondition(statutory.map { self.range($0).location } == statutory.map { self.range($0).location }.sorted(by: >), "a pass reports changes from the end backward")
        for change in statutory {
            precondition(self.substring(input, self.range(change)) == change.trigger, "every change in a pass indexes that pass's ORIGINAL input, not a progressively edited copy")
        }
    }

    private static func testWitnessRangesIndexTheStatutoryOutputNotRecognizedNorFinalText(_ processor: LegalDictationProcessor, pack: LanguagePack) {
        let input = "section two nine four and section three two three I P C then P W one then section three zero two B N S"
        let outcome = processor.process(input)
        guard let witnessChange = outcome.appliedChanges.first(where: { $0.sourcePackID == self.witness }) else { preconditionFailure("expected a witness change") }
        let witnessRange = self.range(witnessChange)

        // The intermediate text after the statutory pass only -- never
        // retained by NormalizationOutcome, so rebuilt here with the same
        // production pipeline minus the witness normalizer.
        let context = NormalizationContext(
            resolvedTable: PrecedenceResolver.resolveNormalizationTable(from: [pack]),
            resolvedRecognitionVocabulary: PrecedenceResolver.resolveRecognitionVocabulary(from: [pack])
        )
        let afterStatutory = LegalNormalizationPipeline.run(
            recognizedText: input,
            context: context,
            normalizers: [LookupTableNormalizer(), StatutoryProvisionNormalizer()]
        ).normalized

        precondition(self.substring(afterStatutory, witnessRange) == witnessChange.trigger, "a witness range indexes the statutory pass's OUTPUT")
        precondition(self.substring(input, witnessRange) != witnessChange.trigger, "...not the recognized text")
        precondition(self.substring(outcome.normalized, witnessRange) != witnessChange.replacement, "...and not the final normalized text")
        precondition(afterStatutory != input && afterStatutory != outcome.normalized, "three distinct coordinate spaces exist for this dictation")
    }

    private static func testAppliedProvenanceReconstructsTheFinalTextWhenPassIsKnown(_ processor: LegalDictationProcessor) {
        // If (and only if) each change's pass is known, applied provenance
        // is sufficient to reproduce the final text exactly: statutory
        // changes replace spans of the recognized input; witness changes
        // replace spans of that result. Pass identity here comes from the
        // loosely-typed `sourcePackID` family string.
        let input = "section two nine four and section three two three I P C then P W one then section three zero two B N S and D W two"
        let outcome = processor.process(input)
        func apply(_ changes: [AppliedNormalizationChange], to text: String) -> String {
            var result = text as NSString
            for change in changes.sorted(by: { self.range($0).location > self.range($1).location }) {
                result = result.replacingCharacters(in: self.range(change), with: change.replacement) as NSString
            }
            return result as String
        }
        let afterStatutory = apply(outcome.appliedChanges.filter { $0.sourcePackID == self.statutory }, to: input)
        let final = apply(outcome.appliedChanges.filter { $0.sourcePackID == self.witness }, to: afterStatutory)
        precondition(final == outcome.normalized, "\(final) vs \(outcome.normalized)")
    }

    private static func testDeclinedRangesIndexTheirPassInputAndTextIsPreserved(_ processor: LegalDictationProcessor) {
        // A statutory decline sits AFTER an applied statutory change: its
        // range indexes the recognized input, so in the final text the same
        // words have moved left.
        let input = "section three zero two I P C and section three zero two read with"
        let outcome = processor.process(input)
        guard let declined = outcome.declinedChanges.first, let range = declined.range else { preconditionFailure("expected a declined change") }
        precondition(self.substring(input, range) == declined.trigger)
        precondition(outcome.normalized.hasSuffix(declined.trigger), "declined text is preserved verbatim in the output")
        precondition(self.substring(outcome.normalized, range) != declined.trigger, "but its recorded range is not a final-text coordinate once an earlier change shortened the text")

        // A witness decline's range indexes the statutory OUTPUT.
        let mixed = "section three zero two I P C then P W one or was it P W two"
        let mixedOutcome = processor.process(mixed)
        guard let witnessDecline = mixedOutcome.declinedChanges.first, let witnessRange = witnessDecline.range else { preconditionFailure("expected a witness decline") }
        precondition(self.substring(mixed, witnessRange) != witnessDecline.trigger, "a witness decline range is NOT a recognized-text coordinate")
        precondition(self.substring(mixedOutcome.normalized, witnessRange) == witnessDecline.trigger, "here it happens to equal the final coordinate only because nothing after it changed length")
    }

    private static func testLookupProvenanceHasNoRangesAndShiftsLaterCoordinates(pack: LanguagePack) {
        // The bundled pack has no normalization entries, so lookup never
        // fires in production today; a pack that does exposes the gap.
        precondition(pack.normalizationEntries.isEmpty, "premise: the builtin pack ships 0 normalization entries")
        let withLookup = LanguagePack(
            id: pack.id,
            version: pack.version,
            kind: pack.kind,
            displayName: pack.displayName,
            recognitionEntries: pack.recognitionEntries,
            normalizationEntries: [NormalizationEntry(trigger: "distt.", canonicalReplacement: "District")]
        )
        let input = "the distt. court and distt. jail section three zero two I P C"
        let outcome = LegalDictationProcessor(builtinPack: withLookup).process(input)
        let lookup = outcome.appliedChanges.filter { $0.range == nil }
        precondition(lookup.count == 1, "ONE record covers every occurrence of the trigger (two here)")
        precondition(lookup[0].sourcePackID == pack.id && lookup[0].trigger == "distt.")
        guard let statutory = outcome.appliedChanges.first(where: { $0.sourcePackID == self.statutory }) else { preconditionFailure("expected a statutory change") }
        precondition(self.substring(input, self.range(statutory)) != statutory.trigger, "once lookup changes lengths, later ranges are NOT recognized-text coordinates")
    }

    /// Records the current shape of the two provenance types: neither carries
    /// a typed identity of the normalizer pass that produced it (the applied
    /// type has only the loosely-typed `sourcePackID`; the declined type has
    /// no equivalent). A pure observation of stored properties.
    private static func testProvenanceRecordsCarryNoTypedPassIdentity() {
        let applied = Mirror(reflecting: AppliedNormalizationChange(trigger: "t", replacement: "r", sourcePackID: "p", range: nil)).children.compactMap(\.label)
        let declined = Mirror(reflecting: DeclinedNormalization(trigger: "t", candidates: [], reason: "r", range: nil)).children.compactMap(\.label)
        precondition(applied == ["trigger", "replacement", "sourcePackID", "range"], "\(applied)")
        precondition(declined == ["trigger", "candidates", "reason", "range"], "\(declined)")
    }
}
