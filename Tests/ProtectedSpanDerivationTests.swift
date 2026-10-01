import Foundation

/// Coverage for `ProtectedSpanDerivation`: protected spans in the exact
/// coordinates of `NormalizationOutcome.normalized`, derived from verified V1.10
/// provenance. Includes the end-to-end path
/// `NormalizationOutcome -> derived ProtectedSpan[] -> V1.8 composition ->
/// unmodified Safety Authority`. Deterministic only -- no model, no network.
@main
enum ProtectedSpanDerivationTests {
    static func main() {
        let pack = self.realPack()

        self.testAppliedIsResolvedAndDeclinedIsUnresolved(pack)
        self.testLengthChangingReplacementsProjectToFinalCoordinates(pack)
        self.testAdjacentAndTouchingSpans(pack)
        self.testLaterNestedReplacementResizesTheSpan()
        self.testLaterReplacementExactlyEqualToTheSpan()
        self.testBoundariesBeforeAndAfterLengthChangingReplacements()
        self.testPartialIntersectionWithALaterReplacementIsUnprojectable()
        self.testSpanStrictlyInsideALaterReplacementIsUnprojectable()
        self.testEveryUnprojectableSpanIsReportedNeverDropped()
        self.testMultipleSequentialLookupSteps()
        self.testEmptyReplacementYieldsAZeroLengthSpan()
        self.testUnicodeUsesUTF16Coordinates(pack)
        self.testCrossPassProjectionThroughStatutoryAndWitness(pack)
        self.testOverlappingResultingSpansAreKeptNotMerged()
        self.testOrderingIsDeterministic(pack)
        self.testFailureOwnership(pack)
        self.testExhaustiveCorpusNeverFailsVerificationOrProvenance(pack)

        self.testEndToEndThroughCompositionAndSafetyAuthority(pack)
        self.testEndToEndDerivationFailureNeverBecomesOmittedProtection()

        print("PASS: ProtectedSpanDerivation projection, failure semantics and end-to-end Safety Authority suite")
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

    private static func pack(_ base: LanguagePack, lookup: [(String, String)]) -> LanguagePack {
        LanguagePack(
            id: base.id,
            version: base.version,
            kind: base.kind,
            displayName: base.displayName,
            recognitionEntries: base.recognitionEntries,
            normalizationEntries: lookup.map { NormalizationEntry(trigger: $0.0, canonicalReplacement: $0.1) }
        )
    }

    private static func resolvedEntry(_ trigger: String, _ replacement: String) -> ResolvedNormalizationEntry {
        ResolvedNormalizationEntry(trigger: trigger, resolution: .resolved(replacement: replacement, sourcePackID: "fixture"))
    }

    /// Lookup-only pipeline run: one sequential step per table entry.
    private static func lookupOutcome(_ entries: [(String, String)], _ text: String) -> NormalizationOutcome {
        LegalNormalizationPipeline.run(
            recognizedText: text,
            context: NormalizationContext(
                resolvedTable: ResolvedNormalizationTable(entries: entries.map { self.resolvedEntry($0.0, $0.1) }),
                resolvedRecognitionVocabulary: nil
            ),
            normalizers: [LookupTableNormalizer()]
        )
    }

    private static func derived(_ outcome: NormalizationOutcome, file: StaticString = #file, line: UInt = #line) -> NormalizationProtectedSpans {
        switch ProtectedSpanDerivation.derive(from: outcome) {
        case let .success(spans): return spans
        case let .failure(failure): preconditionFailure("derivation failed: \(failure) for \(outcome.recognized.debugDescription)", file: file, line: line)
        }
    }

    private static func text(_ result: NormalizationProtectedSpans, _ entry: NormalizationProtectedSpans.Entry) -> String {
        (result.normalizedText as NSString).substring(with: entry.span.range)
    }

    private static func texts(_ result: NormalizationProtectedSpans) -> [String] {
        result.entries.map { self.text(result, $0) }
    }

    // MARK: - Kind mapping

    private static func testAppliedIsResolvedAndDeclinedIsUnresolved(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)

        let applied = self.derived(processor.process("the accused is charged under section three zero two of the I P C"))
        precondition(applied.normalizedText == "the accused is charged under Section 302 IPC")
        precondition(applied.entries.count == 1)
        precondition(applied.entries[0].span == ProtectedSpan(range: NSRange(location: 29, length: 15), kind: .deterministicallyResolved))
        precondition(self.texts(applied) == ["Section 302 IPC"])

        let declined = self.derived(processor.process("section three hundred twenty three I P C stands"))
        precondition(declined.entries.count == 1)
        precondition(declined.entries[0].span.kind == .deterministicallyUnresolved, "a decline is never collapsed into the resolved kind")
        precondition(self.texts(declined) == ["section three hundred twenty three I"], "the preserved, examined text")

        let unchanged = self.derived(processor.process("ordinary text with nothing to normalize."))
        precondition(unchanged.entries.isEmpty && unchanged.normalizedText == "ordinary text with nothing to normalize.")
    }

    // MARK: - Projection rules

    private static func testLengthChangingReplacementsProjectToFinalCoordinates(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)
        let input = "section two nine four and section three two three I P C then P W one then section three zero two B N S and D W two"
        let outcome = processor.process(input)
        let result = self.derived(outcome)
        precondition(outcome.normalized == "Section 294 and Section 323 IPC then PW-1 then Section 302 BNS and DW-2")
        precondition(self.texts(result) == ["Section 294", "Section 323 IPC", "PW-1", "Section 302 BNS", "DW-2"], "\(self.texts(result))")
        precondition(result.entries.map(\.span.kind).allSatisfy { $0 == .deterministicallyResolved })
        // Witness ranges live in the statutory OUTPUT; they land on the right
        // final text only because they were projected through later changes.
        let witness = result.entries.filter { $0.pass == .witnessReference }
        precondition(witness.map { self.text(result, $0) } == ["PW-1", "DW-2"])
    }

    private static func testAdjacentAndTouchingSpans(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)
        let statutory = self.derived(processor.process("section three zero two I P C section three zero four I P C"))
        precondition(self.texts(statutory) == ["Section 302 IPC", "Section 304 IPC"])
        let ranges = statutory.entries.map(\.span.range)
        precondition(ranges[0].location + ranges[0].length < ranges[1].location, "separated by the space between references")

        // Truly touching spans: adjacent lookup occurrences.
        let touching = self.derived(self.lookupOutcome([("aa", "X")], "aaaa"))
        precondition(touching.entries.map(\.span.range) == [NSRange(location: 0, length: 1), NSRange(location: 1, length: 1)])
        precondition(self.texts(touching) == ["X", "X"], "adjacent spans share a boundary without overlapping")
    }

    private static func testLaterNestedReplacementResizesTheSpan() {
        // step 0: "a" -> "bcd"; step 1 replaces the "c" nested inside that
        // output (and a second "c" elsewhere).
        let outcome = self.lookupOutcome([("a", "bcd"), ("c", "CCC")], "a c")
        precondition(outcome.normalized == "bCCCd CCC")
        let result = self.derived(outcome)
        let step0 = result.entries.first { $0.step == 0 }
        precondition(step0?.span.range == NSRange(location: 0, length: 5), "the span grew with the nested replacement: \(String(describing: step0))")
        precondition(step0.map { self.text(result, $0) } == "bCCCd")
        let step1 = result.entries.filter { $0.step == 1 }.map(\.span.range)
        precondition(step1 == [NSRange(location: 1, length: 3), NSRange(location: 6, length: 3)])
    }

    private static func testLaterReplacementExactlyEqualToTheSpan() {
        let outcome = self.lookupOutcome([("a", "b"), ("b", "Z")], "a b")
        precondition(outcome.normalized == "Z Z")
        let result = self.derived(outcome)
        let step0 = result.entries.first { $0.step == 0 }
        precondition(step0?.span.range == NSRange(location: 0, length: 1) && step0.map { self.text(result, $0) } == "Z", "exact-boundary coincidence maps the span onto the later replacement's output")
    }

    private static func testBoundariesBeforeAndAfterLengthChangingReplacements() {
        // A later replacement BEFORE the span shifts it; one AFTER does not.
        let before = self.lookupOutcome([("zz", "Z"), ("q", "QQ")], "q zz")
        precondition(before.normalized == "QQ Z")
        let beforeResult = self.derived(before)
        precondition(beforeResult.entries.first { $0.step == 0 }?.span.range == NSRange(location: 3, length: 1), "shifted right by the earlier, growing replacement")
        let after = self.lookupOutcome([("a", "bbb"), ("z", "Y")], "a z")
        let afterResult = self.derived(after)
        precondition(after.normalized == "bbb Y")
        precondition(afterResult.entries.first { $0.step == 0 }?.span.range == NSRange(location: 0, length: 3), "unaffected by a later replacement after it")
        precondition(self.texts(afterResult) == ["bbb", "Y"])
    }

    // MARK: - Unprojectable spans

    private static func testPartialIntersectionWithALaterReplacementIsUnprojectable() {
        // step 0: "a" -> "bb" (span [0,2)); step 1 matches "b b" at [1,4) of
        // "bb b b", straddling the span's end.
        let outcome = self.lookupOutcome([("a", "bb"), ("b b", "X")], "a b b")
        precondition(outcome.normalized == "bX b")
        switch ProtectedSpanDerivation.derive(from: outcome) {
        case .success: preconditionFailure("a boundary strictly inside a later replacement must not be given an invented coordinate")
        case let .failure(failure):
            guard case let .unprojectable(spans) = failure else { preconditionFailure("\(failure)") }
            precondition(spans.count == 1)
            precondition(spans[0].kind == .deterministicallyResolved && spans[0].pass == .lookupTable && spans[0].step == 0)
            precondition(spans[0].sourceRange == NSRange(location: 0, length: 1))
            precondition(spans[0].blockedByStep == 1 && spans[0].blockedByRange == NSRange(location: 1, length: 3))
        }
    }

    private static func testSpanStrictlyInsideALaterReplacementIsUnprojectable() {
        // step 0: "a" -> "b" (span [0,1)); step 1 replaces "b b" at [0,3):
        // the span's end lies strictly inside it.
        let outcome = self.lookupOutcome([("a", "b"), ("b b", "X")], "a b b")
        guard case let .failure(.unprojectable(spans)) = ProtectedSpanDerivation.derive(from: outcome) else { preconditionFailure("expected an unprojectable failure") }
        precondition(spans.map(\.step) == [0] && spans[0].blockedByRange == NSRange(location: 0, length: 3))
    }

    private static func testEveryUnprojectableSpanIsReportedNeverDropped() {
        // Two independent unprojectable spans: both appear in the failure.
        let outcome = self.lookupOutcome([("a", "bb"), ("b b", "X")], "a b b a b b")
        guard case let .failure(.unprojectable(spans)) = ProtectedSpanDerivation.derive(from: outcome) else { preconditionFailure("expected an unprojectable failure") }
        precondition(spans.count == 2, "\(spans)")
        precondition(spans.map(\.sourceRange.location) == spans.map(\.sourceRange.location).sorted(), "deterministic order")
    }

    private static func testMultipleSequentialLookupSteps() {
        let outcome = self.lookupOutcome([("a", "bbb"), ("b", "c"), ("c", "Z")], "a b")
        // Step 2 is never considered ("c" is absent from the original input);
        // steps 0 and 1 project into "ccc c".
        let result = self.derived(outcome)
        precondition(outcome.normalized == "ccc c")
        let step0 = result.entries.filter { $0.step == 0 }
        precondition(step0.map(\.span.range) == [NSRange(location: 0, length: 3)] && self.text(result, step0[0]) == "ccc")
        let step1 = result.entries.filter { $0.step == 1 }
        precondition(step1.map(\.span.range) == [NSRange(location: 0, length: 1), NSRange(location: 1, length: 1), NSRange(location: 2, length: 1), NSRange(location: 4, length: 1)])
    }

    private static func testEmptyReplacementYieldsAZeroLengthSpan() {
        // A deterministic deletion is still a resolved change at that point.
        let outcome = self.lookupOutcome([("x", "")], "ab x cd")
        precondition(outcome.normalized == "ab  cd")
        let result = self.derived(outcome)
        precondition(result.entries.map(\.span) == [ProtectedSpan(range: NSRange(location: 3, length: 0), kind: .deterministicallyResolved)])
    }

    // MARK: - Unicode, cross-pass, overlap, ordering

    private static func testUnicodeUsesUTF16Coordinates(_ base: LanguagePack) {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let emoji = "\u{1F60A}"
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [(odia, "Odisha"), (emoji, "!")]))
        let outcome = processor.process("\(emoji)\(emoji) \(odia) section three zero two I P C \(emoji) P W two \(odia)")
        precondition(outcome.normalized == "!! Odisha Section 302 IPC ! PW-2 Odisha", outcome.normalized.debugDescription)
        let result = self.derived(outcome)
        precondition(self.texts(result) == ["!", "!", "Odisha", "Section 302 IPC", "!", "PW-2", "Odisha"], "\(self.texts(result))")
        precondition(result.entries[0].span.range == NSRange(location: 0, length: 1) && result.entries[2].span.range == NSRange(location: 3, length: 6))

        // Non-BMP text stays in the final text: spans still land exactly.
        let keep = LegalDictationProcessor(builtinPack: base)
        let kept = self.derived(keep.process("\(emoji)\(emoji) \(odia) section three zero two I P C"))
        precondition(kept.entries[0].span.range.location == (emoji + emoji + " " + odia + " ").utf16.count, "UTF-16 offset past surrogate pairs and Odia")
        precondition(self.texts(kept) == ["Section 302 IPC"])
    }

    private static func testCrossPassProjectionThroughStatutoryAndWitness(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District")]))
        let outcome = processor.process("the distt. court section three zero two I P C then P W one or was it P W two and section three zero four read with")
        let result = self.derived(outcome)
        // lookup (resolved), statutory (resolved), witness decline (unresolved),
        // statutory decline (unresolved) -- each in final coordinates.
        let byPass = Dictionary(grouping: result.entries, by: \.pass)
        precondition(byPass[.lookupTable]?.map { self.text(result, $0) } == ["District"])
        precondition(byPass[.statutoryProvision]?.map { self.text(result, $0) }.sorted() == ["Section 302 IPC", "section three zero four read with"])
        precondition(byPass[.witnessReference]?.map { self.text(result, $0) } == ["P W one or was it P W two"])
        precondition(byPass[.witnessReference]?.first?.span.kind == .deterministicallyUnresolved)
    }

    private static func testOverlappingResultingSpansAreKeptNotMerged() {
        let outcome = self.lookupOutcome([("a", "bcd"), ("c", "CCC")], "a c")
        precondition(outcome.normalized == "bCCCd CCC")
        let result = self.derived(outcome)
        precondition(result.entries.map(\.span.range) == [NSRange(location: 0, length: 5), NSRange(location: 1, length: 3), NSRange(location: 6, length: 3)])
        precondition(result.entries[0].span.range.location + result.entries[0].span.range.length > result.entries[1].span.range.location, "nested spans overlap and both are kept (the Authority resolves overlap most-restrictive-wins)")
        // Identical spans from different steps are not deduplicated either.
        let identical = self.derived(self.lookupOutcome([("a", "b"), ("b", "Z")], "a b"))
        precondition(identical.entries.map(\.span.range) == [NSRange(location: 0, length: 1), NSRange(location: 0, length: 1), NSRange(location: 2, length: 1)])
    }

    private static func testOrderingIsDeterministic(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)
        let outcome = processor.process("P W one then section three zero two I P C and section three hundred twenty three I P C then D W two")
        let first = self.derived(outcome)
        for _ in 0..<20 { precondition(self.derived(outcome) == first) }
        let locations = first.entries.map(\.span.range.location)
        precondition(locations == locations.sorted(), "ordered by final location")
    }

    // MARK: - Failure ownership

    private static func testFailureOwnership(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)
        let good = processor.process("as P W one said under section three zero two of the I P C")
        _ = self.derived(good)

        guard let statutory = good.appliedChanges.first(where: { $0.pass == .statutoryProvision }) else { preconditionFailure("premise") }
        let tamperedChange = AppliedNormalizationChange(
            trigger: statutory.trigger,
            replacement: statutory.replacement,
            sourcePackID: statutory.sourcePackID,
            pass: statutory.pass,
            step: statutory.step,
            range: NSRange(location: statutory.range.location - 1, length: statutory.range.length)
        )
        let tampered = NormalizationOutcome(
            recognized: good.recognized,
            normalized: good.normalized,
            passes: good.passes,
            appliedChanges: good.appliedChanges.map { $0 == statutory ? tamperedChange : $0 },
            declinedChanges: good.declinedChanges
        )
        // 1. Invalid/tampered provenance -> invalidProvenance (no span trusted).
        guard case let .failure(.invalidProvenance(reason)) = ProtectedSpanDerivation.derive(from: tampered) else { preconditionFailure("tampered provenance must be rejected") }
        precondition(reason == .triggerMismatch(pass: .statutoryProvision, step: 0))
        let wrongFinal = NormalizationOutcome(recognized: good.recognized, normalized: good.normalized + "!", passes: good.passes, appliedChanges: good.appliedChanges, declinedChanges: good.declinedChanges)
        guard case .failure(.invalidProvenance(.finalTextMismatch)) = ProtectedSpanDerivation.derive(from: wrongFinal) else { preconditionFailure("expected finalTextMismatch") }

        // 2. Valid provenance, ambiguous projection -> unprojectable.
        guard case .failure(.unprojectable) = ProtectedSpanDerivation.derive(from: self.lookupOutcome([("a", "bb"), ("b b", "X")], "a b b")) else { preconditionFailure("expected unprojectable") }

        // 3. Success -> spans (tested throughout). The three cases are distinct enum cases.
    }

    private static func testExhaustiveCorpusNeverFailsVerificationOrProvenance(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District"), ("hon'ble", "Hon'ble")]))
        let fragments = [
            "section three zero two I P C", "section three zero two read with", "P W one", "P W one or was it P W two",
            "section three hundred twenty three I P C", "the accused", "D W two", "section four B N S", "distt.", "hon'ble", "\u{1F60A}",
        ]
        func sequences(_ length: Int) -> [[String]] {
            length == 0 ? [[]] : fragments.flatMap { fragment in sequences(length - 1).map { [fragment] + $0 } }
        }
        var succeeded = 0
        var unprojectable = 0
        for length in 1...3 {
            for sequence in sequences(length) {
                let outcome = processor.process(sequence.joined(separator: " "))
                switch ProtectedSpanDerivation.derive(from: outcome) {
                case let .success(result):
                    succeeded += 1
                    let total = outcome.appliedChanges.count + outcome.declinedChanges.count
                    precondition(result.entries.count == total, "every provenance record yields exactly one span")
                    let resolved = result.entries.filter { $0.span.kind == .deterministicallyResolved }.count
                    precondition(resolved == outcome.appliedChanges.count)
                case .failure(.unprojectable):
                    unprojectable += 1
                case let .failure(failure):
                    preconditionFailure("valid production provenance must never fail as \(failure)")
                }
            }
        }
        precondition(succeeded + unprojectable == 11 + 121 + 1331)
        precondition(unprojectable == 0, "no realistic production pipeline shape needs an invented coordinate (\(unprojectable))")
    }

    // MARK: - End to end: NormalizationOutcome -> spans -> V1.8 composition -> Safety Authority

    private static func response(_ edits: [(String, String)]) -> IntelligenceProviderResponse {
        func quote(_ value: String) -> String {
            String(data: (try? JSONEncoder().encode(value)) ?? Data(), encoding: .utf8) ?? "\"\""
        }
        let body = edits.map { #"{"sourceText":\#(quote($0.0)),"replacementText":\#(quote($0.1))}"# }.joined(separator: ",")
        return IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: #"{"schemaVersion":1,"edits":[\#(body)]}"#)])
    }

    private static func compose(_ edits: [(String, String)], _ outcome: NormalizationOutcome, spans: [ProtectedSpan]) -> IntelligenceCompositionResult {
        switch IntelligenceEditComposition.evaluate(response: self.response(edits), source: outcome.normalized, protectedSpans: spans) {
        case let .success(result): return result
        case let .failure(failure): preconditionFailure("composition failed: \(failure)")
        }
    }

    private static func testEndToEndThroughCompositionAndSafetyAuthority(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District")]))
        let outcome = processor.process("distt. section three zero two I P C then P W one and section three hundred twenty three I P C stands")
        precondition(outcome.normalized == "District Section 302 IPC then PW-1 and section three hundred twenty three I P C stands", outcome.normalized)
        let derivedSpans = self.derived(outcome)
        precondition(derivedSpans.normalizedText == outcome.normalized, "spans and source travel together")

        // Each edit is an individually safe capitalization.
        let edits = [
            ("District", "DISTRICT"), // inside a resolved lookup replacement
            ("Section", "SECTION"), // inside a resolved statutory citation
            ("PW-1", "pw-1"), // inside a resolved witness reference
            ("section three", "Section three"), // inside a declined statutory span
            ("stands", "Stands"), // outside every protected span
        ]

        // Without derived spans (the pre-V1.11 gap): most of these are still
        // accepted -- EXCEPT "PW-1"->"pw-1", which V1.16's
        // AutonomousPermissionGate independently blocks (an acronym-shaped
        // token, "PW", being lowered) with no protected span involved at
        // all. This is the gate and V1.11's spans acting as independent,
        // complementary layers: the gate alone already narrows the pre-V1.11
        // gap for this one shape, though not for the others (a raise, never
        // an acronym lowering, is never gate-blocked).
        let unprotected = self.compose(edits, outcome, spans: [])
        precondition(unprotected.accepted.count == 4, "with no spans, resolved normalization output other than an acronym-lowering identifier is still autonomously editable")
        precondition(unprotected.edits[2].disposition == .reviewOnly(.acronymCapitalizationLowered), "\(String(describing: unprotected.edits[2].disposition))")

        // With derived spans: the existing intended protections apply.
        let protected = self.compose(edits, outcome, spans: derivedSpans.spans)
        precondition(protected.edits[0].disposition == .rejected(.intersectsResolvedSpan), "\(String(describing: protected.edits[0].disposition))")
        precondition(protected.edits[1].disposition == .rejected(.intersectsResolvedSpan))
        precondition(protected.edits[2].disposition == .rejected(.intersectsResolvedSpan))
        precondition(protected.edits[3].disposition == .reviewOnly(.intersectsUnresolvedSpan), "a decline is review-only, never rejected as resolved and never autonomous")
        guard case .autonomouslyAccepted(.capitalizationOnly) = protected.edits[4].disposition ?? .rejected(.invalidRange) else { preconditionFailure("an edit outside every span must still be accepted") }
        precondition(protected.accepted.map(\.id) == ["p5"] && protected.reviewOnly.map(\.id) == ["p4"] && protected.rejectedBySafetyAuthority.map(\.id) == ["p1", "p2", "p3"])

        // Boundary behaviour: an edit that merely touches a span's edge is
        // outside it; one that crosses the edge intersects it.
        let touching = self.compose([("Section 302 IPC then", "Section 302 IPC Then")], outcome, spans: derivedSpans.spans)
        precondition(touching.edits[0].disposition == .rejected(.intersectsResolvedSpan), "crossing into the resolved span is blocked")
        let adjacentOnly = self.compose([("then", "Then")], outcome, spans: derivedSpans.spans)
        guard case .autonomouslyAccepted = adjacentOnly.edits[0].disposition ?? .rejected(.invalidRange) else { preconditionFailure("text adjacent to a span is not inside it") }
    }

    private static func testEndToEndDerivationFailureNeverBecomesOmittedProtection() {
        // Valid provenance whose spans cannot be projected: the caller receives
        // a typed failure -- there is no span list to (mis)use, and passing an
        // empty list would be an explicit caller decision, not a default.
        let outcome = self.lookupOutcome([("a", "bb"), ("b b", "X")], "a b b")
        switch ProtectedSpanDerivation.derive(from: outcome) {
        case .success: preconditionFailure("derivation must fail")
        case let .failure(failure):
            guard case let .unprojectable(spans) = failure else { preconditionFailure("\(failure)") }
            precondition(spans.count == 1 && spans[0].kind == .deterministicallyResolved)
        }
    }
}
