import Foundation

/// Tests for the V1.10 normalization provenance foundation: typed pass
/// identity on every record, individually located lookup replacements,
/// preserved normalization behavior, and exact reconstruction
/// (`NormalizationReplay`) of `R -> L -> S -> N` from provenance alone.
/// Nothing here derives protected spans.
@main
enum NormalizationProvenanceFoundationTests {
    static func main() {
        let pack = self.realPack()

        self.testTypedPassIdentityOnEveryRecordAndPassOrder(pack)
        self.testPassIdentityIsNotDerivedFromSourcePackID(pack)
        self.testLookupEveryOccurrenceIsLocated()
        self.testLookupLengthChangingSequentialStepsAndOriginalInputGate()
        self.testLookupEntryConsumedByAnEarlierEntryRecordsNothing()
        self.testLookupDeclinedOccurrencesAreLocated()
        self.testAdjacentAndOverlappingCandidates(pack)
        self.testCanonicalEquivalenceMatchesLikeReplacingOccurrences()
        self.testLookupDifferentialAgainstLegacySemantics()

        self.testReplayReconstructsRToLToSToN(pack)
        self.testReplayEmptyAndNoOpPasses(pack)
        self.testReplayDeclineOnlyPassIsAnIdentityStep(pack)
        self.testReplayUnicode(pack)
        self.testReplayExhaustiveCorpus(pack)
        self.testReplayFailsClosedOnInconsistentProvenance(pack)

        print("PASS: normalization provenance foundation (typed pass identity, located lookup, exact R->L->S->N replay)")
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

    private static func resolved(_ trigger: String, _ replacement: String, packID: String = "fixture") -> ResolvedNormalizationEntry {
        ResolvedNormalizationEntry(trigger: trigger, resolution: .resolved(replacement: replacement, sourcePackID: packID))
    }

    private static func conflicted(_ trigger: String) -> ResolvedNormalizationEntry {
        ResolvedNormalizationEntry(
            trigger: trigger,
            resolution: .conflicted(candidates: [NormalizationCandidate(sourcePackID: "a", replacement: "A"), NormalizationCandidate(sourcePackID: "b", replacement: "B")])
        )
    }

    private static func lookup(_ entries: [ResolvedNormalizationEntry], _ text: String) -> NormalizationPassResult {
        LookupTableNormalizer().normalize(text, using: NormalizationContext(resolvedTable: ResolvedNormalizationTable(entries: entries), resolvedRecognitionVocabulary: nil))
    }

    private static func pipeline(_ entries: [ResolvedNormalizationEntry], _ text: String) -> NormalizationOutcome {
        LegalNormalizationPipeline.run(
            recognizedText: text,
            context: NormalizationContext(resolvedTable: ResolvedNormalizationTable(entries: entries), resolvedRecognitionVocabulary: nil),
            normalizers: [LookupTableNormalizer()]
        )
    }

    private static func replay(_ outcome: NormalizationOutcome, file: StaticString = #file, line: UInt = #line) -> [NormalizationReplay.Step] {
        switch NormalizationReplay.steps(of: outcome) {
        case let .success(steps): return steps
        case let .failure(failure): preconditionFailure("replay failed: \(failure) for \(outcome.recognized.debugDescription)", file: file, line: line)
        }
    }

    private static func ns(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    // MARK: - Typed identity

    private static func testTypedPassIdentityOnEveryRecordAndPassOrder(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District")]))
        let input = "distt. section three zero two I P C then P W one or was it P W two and D W two and section three zero two read with"
        let outcome = processor.process(input)
        precondition(outcome.passes == [.lookupTable, .statutoryProvision, .witnessReference], "passes are recorded in run order")
        let applied = Dictionary(grouping: outcome.appliedChanges, by: \.pass)
        let declined = Dictionary(grouping: outcome.declinedChanges, by: \.pass)
        precondition(applied[.lookupTable]?.count == 1 && applied[.statutoryProvision]?.count == 1 && applied[.witnessReference]?.count == 1, "\(applied.mapValues(\.count))")
        precondition(declined[.statutoryProvision]?.count == 1 && declined[.witnessReference]?.count == 1 && declined[.lookupTable] == nil)
        precondition(outcome.appliedChanges.allSatisfy { $0.step == 0 } && outcome.declinedChanges.allSatisfy { $0.step == 0 })
        // Flat order is pass order.
        precondition(outcome.appliedChanges.map(\.pass) == [.lookupTable, .statutoryProvision, .witnessReference])
        // The normalizers advertise the same identity they stamp.
        precondition(LookupTableNormalizer().passID == .lookupTable && StatutoryProvisionNormalizer().passID == .statutoryProvision && WitnessReferenceNormalizer().passID == .witnessReference)
    }

    private static func testPassIdentityIsNotDerivedFromSourcePackID(_ base: LanguagePack) {
        // A lookup entry whose pack id collides with a Phase 3 family label
        // must not be mistaken for that pass.
        let outcome = self.pipeline([self.resolved("distt.", "District", packID: "phase3.statutoryProvision")], "the distt. court")
        precondition(outcome.appliedChanges.count == 1)
        precondition(outcome.appliedChanges[0].sourcePackID == "phase3.statutoryProvision")
        precondition(outcome.appliedChanges[0].pass == .lookupTable, "identity is typed, never read from sourcePackID")
        _ = self.replay(outcome)
        _ = base
    }

    // MARK: - Lookup provenance

    private static func testLookupEveryOccurrenceIsLocated() {
        let input = "sec. one and sec. two"
        let result = self.lookup([self.resolved("sec.", "Section")], input)
        precondition(result.text == "Section one and Section two")
        precondition(result.appliedChanges.map(\.range) == [NSRange(location: 0, length: 4), NSRange(location: 13, length: 4)], "one record per occurrence, each located")
        precondition(result.appliedChanges.allSatisfy { $0.trigger == "sec." && $0.step == 0 && $0.pass == .lookupTable })
        for change in result.appliedChanges { precondition(self.ns(input, change.range) == change.trigger) }
    }

    private static func testLookupLengthChangingSequentialStepsAndOriginalInputGate() {
        // step 0 lengthens; step 1 then acts on the LENGTHENED text (and so
        // also on the "b"s step 0 created); step 2's trigger is absent from
        // the ORIGINAL input, so it is never considered, exactly as before.
        let entries = [self.resolved("a", "bbb"), self.resolved("b", "c"), self.resolved("c", "Z")]
        let outcome = self.pipeline(entries, "a b")
        precondition(outcome.normalized == "ccc c", outcome.normalized)
        precondition(outcome.appliedChanges.filter { $0.step == 0 }.map(\.range) == [NSRange(location: 0, length: 1)])
        precondition(outcome.appliedChanges.filter { $0.step == 1 }.map(\.range) == [0, 1, 2, 4].map { NSRange(location: $0, length: 1) }, "step 1 ranges index step 0's OUTPUT")
        precondition(outcome.appliedChanges.allSatisfy { $0.step != 2 })
        let steps = self.replay(outcome)
        precondition(steps.map(\.input) == ["a b", "bbb b"] && steps.map(\.output) == ["bbb b", "ccc c"])
    }

    private static func testLookupEntryConsumedByAnEarlierEntryRecordsNothing() {
        // Step 1's trigger "y" passes the original-input check but step 0
        // consumed it. Text is unchanged either way; provenance no longer
        // carries a phantom, unlocatable change.
        let result = self.lookup([self.resolved("x y", "z"), self.resolved("y", "w")], "x y")
        precondition(result.text == "z")
        precondition(result.appliedChanges.count == 1 && result.declinedChanges.isEmpty)
    }

    private static func testLookupDeclinedOccurrencesAreLocated() {
        let input = "distt. and distt. again"
        let result = self.lookup([self.conflicted("distt.")], input)
        precondition(result.text == input, "declined text is preserved")
        precondition(result.declinedChanges.map(\.range) == [NSRange(location: 0, length: 6), NSRange(location: 11, length: 6)])
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.allSatisfy { $0.pass == .lookupTable && $0.trigger == "distt." && $0.candidates.count == 2 })
    }

    private static func testAdjacentAndOverlappingCandidates(_ base: LanguagePack) {
        // Adjacent occurrences.
        let adjacent = self.lookup([self.resolved("aa", "X")], "aaaa")
        precondition(adjacent.text == "XX" && adjacent.appliedChanges.map(\.range) == [NSRange(location: 0, length: 2), NSRange(location: 2, length: 2)])
        // Overlapping candidate: "aa" also matches at 1 in "aaa", but the
        // scan is non-overlapping left-to-right, as replacingOccurrences is.
        let overlapping = self.lookup([self.resolved("aa", "X")], "aaa")
        precondition(overlapping.text == "Xa" && overlapping.appliedChanges.map(\.range) == [NSRange(location: 0, length: 2)])
        precondition(overlapping.text == "aaa".replacingOccurrences(of: "aa", with: "X"))
        // Structured rules: adjacent statutory candidates never overlap.
        let processor = LegalDictationProcessor(builtinPack: base)
        let outcome = processor.process("section three zero two I P C section three zero four I P C")
        let ranges = outcome.appliedChanges.map(\.range).sorted { $0.location < $1.location }
        precondition(ranges.count == 2 && ranges[0].location + ranges[0].length <= ranges[1].location)
        _ = self.replay(outcome)
    }

    private static func testCanonicalEquivalenceMatchesLikeReplacingOccurrences() {
        let precomposed = "caf\u{00E9}"
        let decomposed = "cafe\u{0301}"
        let text = "the \(decomposed) opened"
        let oracle = text.replacingOccurrences(of: precomposed, with: "coffee")
        let result = self.lookup([self.resolved(precomposed, "coffee")], text)
        precondition(result.text == oracle, "output identical to String.replacingOccurrences, whatever it does with equivalent forms")
        if oracle != text {
            precondition(result.appliedChanges.count == 1 && result.appliedChanges[0].trigger == decomposed, "trigger is the exact matched form")
            precondition(result.appliedChanges[0].range.length == decomposed.utf16.count)
        } else {
            precondition(result.appliedChanges.isEmpty)
        }
    }

    /// The pre-V1.10 algorithm, kept as an oracle for output equivalence.
    private static func legacyLookupText(entries: [(trigger: String, replacement: String?)], _ text: String) -> String {
        var updated = text
        for entry in entries where text.contains(entry.trigger) {
            if let replacement = entry.replacement {
                updated = updated.replacingOccurrences(of: entry.trigger, with: replacement)
            }
        }
        return updated
    }

    private static func testLookupDifferentialAgainstLegacySemantics() {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let triggers = ["a", "b", "ab", "aa", "b c", "c", "e\u{0301}", "\u{00E9}", "\u{1F60A}", odia, "x y", "y"]
        let replacements = ["", "a", "bbb", "Z", "\u{1F60A}\u{1F60A}", "Odisha", "ab ab"]
        let alphabet = ["a", "b", "c", " ", "x", "y", "e\u{0301}", "\u{00E9}", "\u{1F60A}", odia, "ab", "aa"]
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }
        var checked = 0
        for _ in 0..<600 {
            let entryCount = 1 + next(4)
            let entries = (0..<entryCount).map { _ in (trigger: triggers[next(triggers.count)], replacement: next(5) == 0 ? String?.none : replacements[next(replacements.count)]) }
            let text = (0..<(1 + next(10))).map { _ in alphabet[next(alphabet.count)] }.joined()
            let table = entries.map { entry -> ResolvedNormalizationEntry in
                entry.replacement.map { self.resolved(entry.trigger, $0) } ?? self.conflicted(entry.trigger)
            }
            let outcome = self.pipeline(table, text)
            precondition(outcome.normalized == self.legacyLookupText(entries: entries, text), "output must equal the legacy algorithm: \(entries) on \(text.debugDescription)")
            _ = self.replay(outcome)
            checked += 1
        }
        precondition(checked == 600)
    }

    // MARK: - Replay

    private static func testReplayReconstructsRToLToSToN(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District")]))
        let input = "the distt. court section three zero two I P C and P W one"
        let outcome = processor.process(input)
        precondition(outcome.normalized == "the District court Section 302 IPC and PW-1")
        let steps = self.replay(outcome)
        precondition(steps.map(\.pass) == [.lookupTable, .statutoryProvision, .witnessReference])
        precondition(steps[0].input == input, "R")
        precondition(steps[0].output == "the District court section three zero two I P C and P W one", "L")
        precondition(steps[1].input == steps[0].output && steps[1].output == "the District court Section 302 IPC and P W one", "S")
        precondition(steps[2].input == steps[1].output && steps[2].output == outcome.normalized, "N")
    }

    private static func testReplayEmptyAndNoOpPasses(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)
        for input in ["", "   ", "ordinary text with no legal references.", "\u{1F60A}"] {
            let outcome = processor.process(input)
            precondition(outcome.isUnchanged && outcome.normalized == input)
            precondition(outcome.passes == [.lookupTable, .statutoryProvision, .witnessReference], "passes that changed nothing are still recorded")
            precondition(self.replay(outcome).isEmpty, "no records -> identity transition, no steps")
        }
    }

    private static func testReplayDeclineOnlyPassIsAnIdentityStep(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: base)
        let input = "section three hundred twenty three I P C stands"
        let outcome = processor.process(input)
        precondition(outcome.appliedChanges.isEmpty && outcome.declinedChanges.count == 1)
        let steps = self.replay(outcome)
        precondition(steps.count == 1 && steps[0].pass == .statutoryProvision && steps[0].input == input && steps[0].output == input)
    }

    private static func testReplayUnicode(_ base: LanguagePack) {
        let odia = "\u{0B13}\u{0B21}\u{0B3C}\u{0B3F}\u{0B36}\u{0B3E}"
        let emoji = "\u{1F60A}"
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [(odia, "Odisha"), (emoji, "")]))
        let input = "\(emoji)\(emoji) \(odia) section three zero two I P C \(emoji) P W two \(odia)"
        let outcome = processor.process(input)
        precondition(outcome.normalized == " Odisha Section 302 IPC  PW-2 Odisha", outcome.normalized.debugDescription)
        let steps = self.replay(outcome)
        precondition(steps.count == 4 && steps[0].input == input, "two lookup steps (one per table entry), then statutory, then witness")
        precondition(steps.map(\.pass) == [.lookupTable, .lookupTable, .statutoryProvision, .witnessReference] && steps.prefix(2).map(\.step) == [0, 1])
        // Ranges are UTF-16: the first Odia occurrence follows two surrogate pairs and a space.
        let odiaRanges = outcome.appliedChanges.filter { $0.pass == .lookupTable && $0.trigger == odia }.map(\.range)
        precondition(odiaRanges.first?.location == 5 && odiaRanges.count == 2)
        precondition(outcome.appliedChanges.filter { $0.trigger == emoji }.count == 3, "each emoji occurrence is located individually")
    }

    private static func testReplayExhaustiveCorpus(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District"), ("hon'ble", "Hon'ble")]))
        let fragments = [
            "section three zero two I P C", "section three zero two read with", "P W one", "P W one or was it P W two",
            "section three hundred twenty three I P C", "the accused", "D W two", "section four B N S", "distt.", "hon'ble", "\u{1F60A}",
        ]
        func sequences(_ length: Int) -> [[String]] {
            length == 0 ? [[]] : fragments.flatMap { fragment in sequences(length - 1).map { [fragment] + $0 } }
        }
        var count = 0
        for length in 1...3 {
            for sequence in sequences(length) {
                let outcome = processor.process(sequence.joined(separator: " "))
                _ = self.replay(outcome)
                count += 1
            }
        }
        precondition(count == 11 + 121 + 1331, "\(count)")
    }

    private static func testReplayFailsClosedOnInconsistentProvenance(_ base: LanguagePack) {
        let processor = LegalDictationProcessor(builtinPack: self.pack(base, lookup: [("distt.", "District")]))
        let good = processor.process("distt. section three zero two I P C then P W one")
        _ = self.replay(good)

        func outcome(
            passes: [NormalizationPassID] = good.passes,
            normalized: String = good.normalized,
            applied: [AppliedNormalizationChange] = good.appliedChanges,
            declined: [DeclinedNormalization] = good.declinedChanges
        ) -> NormalizationOutcome {
            NormalizationOutcome(
                recognized: good.recognized,
                normalized: normalized,
                passes: passes,
                appliedChanges: applied,
                declinedChanges: declined
            )
        }
        func expect(_ label: String, _ candidate: NormalizationOutcome, _ expected: NormalizationReplay.Failure) {
            switch NormalizationReplay.steps(of: candidate) {
            case .success: preconditionFailure("\(label): inconsistent provenance must not replay")
            case let .failure(failure): precondition(failure == expected, "\(label): expected \(expected), got \(failure)")
            }
        }
        func changing(_ change: AppliedNormalizationChange, range: NSRange? = nil, trigger: String? = nil) -> AppliedNormalizationChange {
            AppliedNormalizationChange(
                trigger: trigger ?? change.trigger,
                replacement: change.replacement,
                sourcePackID: change.sourcePackID,
                pass: change.pass,
                step: change.step,
                range: range ?? change.range
            )
        }
        guard let statutoryIndex = good.appliedChanges.firstIndex(where: { $0.pass == .statutoryProvision }) else { preconditionFailure("premise") }
        let statutory = good.appliedChanges[statutoryIndex]
        func replacing(_ change: AppliedNormalizationChange) -> [AppliedNormalizationChange] {
            var all = good.appliedChanges
            all[statutoryIndex] = change
            return all
        }

        expect("range out of bounds", outcome(applied: replacing(changing(statutory, range: NSRange(location: 900, length: 5)))), .rangeOutOfBounds(pass: .statutoryProvision, step: 0))
        expect("negative range", outcome(applied: replacing(changing(statutory, range: NSRange(location: -1, length: 5)))), .rangeOutOfBounds(pass: .statutoryProvision, step: 0))
        expect("trigger mismatch", outcome(applied: replacing(changing(statutory, trigger: "not the text"))), .triggerMismatch(pass: .statutoryProvision, step: 0))
        expect("shifted range", outcome(applied: replacing(changing(statutory, range: NSRange(location: statutory.range.location + 1, length: statutory.range.length)))), .triggerMismatch(pass: .statutoryProvision, step: 0))
        var overlapping = good.appliedChanges
        overlapping.append(changing(statutory))
        expect("overlapping records", outcome(applied: overlapping), .overlappingRecords(pass: .statutoryProvision, step: 0))
        expect("unknown pass", outcome(passes: [.lookupTable, .witnessReference]), .unknownPass(.statutoryProvision))
        expect("final text mismatch", outcome(normalized: good.normalized + "!"), .finalTextMismatch)
        expect("missing record", outcome(applied: good.appliedChanges.filter { $0.pass != .witnessReference }), .finalTextMismatch)
    }
}
