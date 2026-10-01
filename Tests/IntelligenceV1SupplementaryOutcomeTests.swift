import Foundation

/// Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation.
///
/// Offline, deterministic verification of the supplementary outcome machinery
/// (`Evaluation/Intelligence/CapabilitySupplementary/`). No model, no Ollama, no network. Synthetic
/// cases drive the **real, unmodified** deterministic chain by replaying hand-written raw tool-call
/// arguments (never a model). Run via `scripts/test_intelligence_v1_supplementary_outcome.sh`.
@main
enum IntelligenceV1SupplementaryOutcomeTests {
    static func main() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        self.testLicensedOutcomes()
        self.testStateClassificationAndApplication()
        self.testRuntimeSafetyMonitors()
        try self.testEvaluatorOnSyntheticTrials(repoRoot)
        try self.testRealV123Reproduction(repoRoot)
        self.testArtifactPins(repoRoot)
        try self.testReportIsDeterministicAndLabelled(repoRoot)
        self.testNoProviderPath(repoRoot)
        print("PASS: Intelligence V1.25 supplementary outcome machinery -- all offline checks passed (no model, no network)")
    }

    // MARK: - Helpers

    private static func jsonString(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text), let encoded = String(bytes: data, encoding: .utf8) else { preconditionFailure("encode") }
        return encoded
    }

    private static func entry(
        id: String, category: String = "capitalization-correction-warranted", text: String, expectation: String = "correctionWarranted",
        corrections: [(String, String)] = [], requiresAll: Bool = false, manual: Bool = false
    ) -> CapabilityCorpus.Entry {
        let list = corrections.map { "{\"source\":\(self.jsonString($0.0)),\"replacement\":\(self.jsonString($0.1))}" }.joined(separator: ",")
        let raw = """
        {"id":\(self.jsonString(id)),"category":\(self.jsonString(category)),"tier":"synthetic","text":\(self.jsonString(text)),"expectation":\(self.jsonString(expectation)),
        "expectedCorrections":[\(list)],"recallRequiresAll":\(requiresAll),"manualAdjudicationOnly":\(manual),"hazardNote":null,"knownRiskReference":null,"note":null}
        """
        guard let decoded = try? JSONDecoder().decode(CapabilityCorpus.Entry.self, from: Data(raw.utf8)) else { preconditionFailure("bad entry") }
        return decoded
    }

    private static func toolArguments(_ edits: [[String: String]]) -> String {
        let payload: [String: Any] = ["schemaVersion": 1, "edits": edits]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), let text = String(bytes: data, encoding: .utf8) else { preconditionFailure("encode") }
        return text
    }

    private static func trial(
        _ entry: CapabilityCorpus.Entry, kind: String = "evaluated", raw: [String], buckets: [String], normalized: String? = nil
    ) -> SupplementaryTrialRecord {
        let edits = buckets.enumerated().map { offset, bucket in
            "{\"position\":\(offset + 1),\"sourceText\":\"\",\"replacementText\":\"\",\"bucket\":\"\(bucket)\",\"correctness\":\"unlabelled\",\"literalMatchesExpected\":false}"
        }.joined(separator: ",")
        let rawList = raw.map { self.jsonString($0) }.joined(separator: ",")
        let json = """
        {"id":\(self.jsonString(entry.id)),"category":\(self.jsonString(entry.category)),"manualAdjudicationOnly":\(entry.manualAdjudicationOnly),
        "rawInput":\(self.jsonString(entry.text)),"legalNormalized":\(self.jsonString(normalized ?? entry.text)),"modelFreeText":null,
        "modelRawToolCallArguments":[\(rawList)],"trial":"\(kind)","edits":[\(edits)]}
        """
        guard let decoded = try? JSONDecoder().decode(SupplementaryTrialRecord.self, from: Data(json.utf8)) else { preconditionFailure("bad trial") }
        return decoded
    }

    private static func evaluate(_ items: [(CapabilityCorpus.Entry, SupplementaryTrialRecord)], _ repoRoot: URL) throws -> SupplementaryResults {
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        return try SupplementaryEvaluator.evaluate(
            corpus: CapabilityCorpus(entries: items.map(\.0), sha256: "synthetic"), trials: items.map(\.1), processor: processor
        )
    }

    // MARK: - Licensed outcomes (plain text equality over subsets)

    private static func testLicensedOutcomes() {
        let source = "ram das appeared as a witness and gave his statement"
        let two = [CapabilityCorpus.Correction(source: "ram das", replacement: "Ram Das"), .init(source: "statement", replacement: "statement.")]
        guard case let .success(licensed) = LicensedOutcomes.compute(source: source, corrections: two) else { preconditionFailure("two corrections") }
        precondition(licensed.texts == [
            source, "Ram Das appeared as a witness and gave his statement", "ram das appeared as a witness and gave his statement.",
            "Ram Das appeared as a witness and gave his statement.",
        ], "4 licensed texts from 2 independent corrections")
        precondition(licensed.full == "Ram Das appeared as a witness and gave his statement.")
        guard case let .success(reversed) = LicensedOutcomes.compute(source: source, corrections: two.reversed()) else { preconditionFailure("reversed") }
        precondition(reversed == licensed, "the order the corrections are listed in never changes L")

        guard case let .success(none) = LicensedOutcomes.compute(source: source, corrections: []) else { preconditionFailure("none") }
        precondition(none.texts == [source] && none.full == source, "abstention-expected entries license only the source")

        precondition(LicensedOutcomes.compute(source: source, corrections: [.init(source: "missing", replacement: "x")]) == .failure(.correctionNotUniquelyLocatable(source: "missing", occurrences: 0)))
        precondition(LicensedOutcomes.compute(source: "a a", corrections: [.init(source: "a", replacement: "A")]) == .failure(.correctionNotUniquelyLocatable(source: "a", occurrences: 2)))
        precondition(LicensedOutcomes.compute(source: "ram das", corrections: [.init(source: "ram das", replacement: "Ram Das"), .init(source: "das", replacement: "Das")]) == .failure(.overlappingCorrections))
    }

    // MARK: - States and application

    private static func testStateClassificationAndApplication() {
        let source = "ram das appeared as a witness and gave his statement"
        guard case let .success(licensed) = LicensedOutcomes.compute(source: source, corrections: [.init(source: "ram das", replacement: "Ram Das"), .init(source: "statement", replacement: "statement.")]) else { preconditionFailure("L") }
        func state(_ final: String) -> SupplementaryOutcomeState {
            SupplementaryOutcomeState.classify(final: final, source: source, licensed: licensed)
        }
        precondition(state(source) == .unchanged)
        precondition(state("Ram Das appeared as a witness and gave his statement.") == .complete)
        precondition(state("Ram Das appeared as a witness and gave his statement") == .partial, "multi-edit partial: one of two corrections applied")
        precondition(state("ram das appeared as a witness and gave his statement.") == .partial)
        precondition(state("ram das Appeared as a witness and gave his statement") == .foreign, "injected foreign: capitalization of an unlisted word")
        precondition(state("Ram Das appeared as a witness and gave her statement.") == .foreign, "a lexical change is foreign even when licensed edits are also present")
        // Precedence: a state is never ambiguous when `full == source` is impossible to reach for warranted entries.
        guard case let .success(abstain) = LicensedOutcomes.compute(source: "the accused was present.", corrections: []) else { preconditionFailure("abstain") }
        precondition(SupplementaryOutcomeState.classify(final: "the accused was present.", source: "the accused was present.", licensed: abstain) == .unchanged)
        precondition(SupplementaryOutcomeState.classify(final: "The accused was present.", source: "the accused was present.", licensed: abstain) == .foreign, "any change to an abstention-expected entry is foreign")

        // Right-to-left application; overlaps are skipped and counted, never merged.
        let applied = SupplementaryApplication.apply([(NSRange(location: 0, length: 1), "R"), (NSRange(location: 4, length: 1), "D")], to: "ram das")
        precondition(applied.text == "Ram Das" && applied.skippedOverlapping == 0)
        let overlapped = SupplementaryApplication.apply([(NSRange(location: 0, length: 3), "RAM"), (NSRange(location: 2, length: 2), "XX")], to: "ram das")
        precondition(overlapped.skippedOverlapping == 1)
    }

    // MARK: - Runtime-safety monitors (U2, U3)

    private static func testRuntimeSafetyMonitors() {
        let source = "ram das appeared"
        let clean = SupplementaryRuntimeSafetyMonitor.observe(source: source, range: NSRange(location: 0, length: 7), expectedSourceText: "ram das", replacementText: "Ram Das", protectedSpans: [])
        precondition(!clean.intersectsProtectedSpan && !clean.u3Violation, "a clean capitalization edit raises nothing")

        let span = ProtectedSpan(range: NSRange(location: 4, length: 3), kind: .independentlyProtected)
        let hit = SupplementaryRuntimeSafetyMonitor.observe(source: source, range: NSRange(location: 0, length: 7), expectedSourceText: "ram das", replacementText: "Ram Das", protectedSpans: [span])
        precondition(hit.intersectsProtectedSpan, "U2: an accepted edit overlapping a protected span is observed")
        precondition(!SupplementaryRuntimeSafetyMonitor.observe(source: source, range: NSRange(location: 8, length: 8), expectedSourceText: "appeared", replacementText: "Appeared", protectedSpans: [span]).intersectsProtectedSpan)
        precondition(SupplementaryRuntimeSafetyMonitor.intersects(NSRange(location: 5, length: 0), span.range), "a zero-length insertion strictly inside a span intersects it")
        precondition(!SupplementaryRuntimeSafetyMonitor.intersects(NSRange(location: 4, length: 0), span.range), "an insertion at a span edge does not")

        let lexical = SupplementaryRuntimeSafetyMonitor.observe(source: source, range: NSRange(location: 8, length: 8), expectedSourceText: "appeared", replacementText: "arrived", protectedSpans: [])
        precondition(lexical.classificationOutsideAutonomousSet && lexical.u3Violation, "U3: a lexical change is outside the autonomous set")

        let acronym = SupplementaryRuntimeSafetyMonitor.observe(source: "the IPC applies", range: NSRange(location: 4, length: 3), expectedSourceText: "IPC", replacementText: "ipc", protectedSpans: [])
        precondition(acronym.gateBlock == .acronymCapitalizationLowered && acronym.u3Violation, "U3: the V1.16 gate rule is re-derived independently")

        let unlocatable = SupplementaryRuntimeSafetyMonitor.observe(source: source, range: NSRange(location: 90, length: 3), expectedSourceText: "ram", replacementText: "Ram", protectedSpans: [])
        precondition(unlocatable.rangeUnconvertible && unlocatable.u3Violation, "an unlocatable range fails closed")

        precondition(SupplementaryRuntimeSafetyMonitor.digitSequenceChanged(source: "Rs. 5,000", output: "Rs. 5.000") == false, "punctuation inside an amount keeps the digit sequence")
        precondition(SupplementaryRuntimeSafetyMonitor.digitSequenceChanged(source: "Rs. 5,000", output: "Rs. 5,00") == true)
        precondition(SupplementaryRuntimeSafetyMonitor.digitSequenceChanged(source: "12 34", output: "1234") == false, "merging digit runs keeps the sequence (V1.13 protects that separately)")
    }

    // MARK: - Evaluator on synthetic trials through the real chain

    private static func testEvaluatorOnSyntheticTrials(_ repoRoot: URL) throws {
        let text = "ram das appeared as a witness and gave his statement"
        let corrections = [("ram das", "Ram Das"), ("statement", "statement.")]
        let multi = self.entry(id: "S-MULTI", category: "multi-edit-correction-warranted", text: text, corrections: corrections, requiresAll: true)

        // Both corrections as separate minimal edits: complete, no violation of any kind.
        let both = self.toolArguments([["sourceText": "ram das", "replacementText": "Ram Das"], ["sourceText": "statement", "replacementText": "statement."]])
        // One correction only: multi-edit partial outcome.
        let one = self.toolArguments([["sourceText": "ram das", "replacementText": "Ram Das"]])
        // One wide edit combining capitalization AND punctuation: not a single surface class, so the real
        // Authority rejects it (the V1.23 MULTI-002 situation) -- nothing reaches the text.
        let combined = self.toolArguments([["sourceText": text, "replacementText": "Ram Das appeared as a witness and gave his statement."]])
        // One wide capitalization-only edit realizing both of its entry's corrections: accepted; outcome
        // complete, but not the expected pairs (the V1.23 situation: U0 counts it, U1 does not).
        let namesText = "ram das and sita devi appeared as witnesses"
        let wide = self.toolArguments([["sourceText": namesText, "replacementText": "Ram Das and Sita Devi appeared as witnesses"]])
        // Injected foreign outcome: a capitalization edit the ground truth does not license.
        let foreign = self.toolArguments([["sourceText": "witness", "replacementText": "Witness"]])

        let results = try self.evaluate([
            (multi, self.trial(multi, raw: [both], buckets: ["autonomouslyAccepted", "autonomouslyAccepted"])),
            (
                self.entry(id: "S-PARTIAL", category: "multi-edit-correction-warranted", text: text, corrections: corrections, requiresAll: true),
                self.trial(self.entry(id: "S-PARTIAL", text: text), raw: [one], buckets: ["autonomouslyAccepted"])
            ),
            (
                self.entry(id: "S-WIDE", category: "multi-edit-correction-warranted", text: namesText, corrections: [("ram das", "Ram Das"), ("sita devi", "Sita Devi")], requiresAll: true),
                self.trial(self.entry(id: "S-WIDE", text: namesText), raw: [wide], buckets: ["autonomouslyAccepted"])
            ),
            (
                self.entry(id: "S-COMBINED", category: "multi-edit-correction-warranted", text: text, corrections: corrections, requiresAll: true),
                self.trial(self.entry(id: "S-COMBINED", text: text), raw: [combined], buckets: ["rejectedBySafetyAuthority"])
            ),
            (
                self.entry(id: "S-FOREIGN", text: text, corrections: corrections, requiresAll: true),
                self.trial(self.entry(id: "S-FOREIGN", text: text), raw: [foreign], buckets: ["autonomouslyAccepted"])
            ),
            (
                self.entry(id: "S-ABSTAIN-CHANGED", category: "clean-control", text: "the accused was present.", expectation: "abstentionExpected"),
                self.trial(self.entry(id: "S-ABSTAIN-CHANGED", text: "the accused was present."), raw: [self.toolArguments([["sourceText": "the", "replacementText": "The"]])], buckets: ["autonomouslyAccepted"])
            ),
            (
                self.entry(id: "S-ABSTAIN-EMPTY", category: "clean-control", text: "the accused was present.", expectation: "abstentionExpected"),
                self.trial(self.entry(id: "S-ABSTAIN-EMPTY", text: "the accused was present."), raw: [self.toolArguments([])], buckets: [])
            ),
            (
                self.entry(id: "S-MANUAL", category: "ambiguous", text: "ipc and crpc were invoked", manual: true),
                self.trial(self.entry(id: "S-MANUAL", text: "ipc and crpc were invoked", manual: true), raw: [self.toolArguments([["sourceText": "ipc", "replacementText": "Ipc"]])], buckets: ["autonomouslyAccepted"])
            ),
            (
                self.entry(id: "S-PROVIDER", text: text, corrections: corrections, requiresAll: true),
                self.trial(self.entry(id: "S-PROVIDER", text: text), kind: "providerFailure", raw: [], buckets: [])
            ),
            (
                self.entry(id: "S-PROTOCOL", text: text, corrections: corrections, requiresAll: true),
                self.trial(self.entry(id: "S-PROTOCOL", text: text), kind: "protocolFailure", raw: [#"{"schemaVersion":1,"edits":[{"sourceText":"x"}]}"#], buckets: [])
            ),
        ], repoRoot)
        func result(_ id: String) -> SupplementaryEntryResult {
            guard let found = results.entries.first(where: { $0.entry.id == id }) else { preconditionFailure("missing \(id)") }
            return found
        }
        precondition(result("S-MULTI").autonomousState == .complete && result("S-MULTI").exactPairViolations == 0, "complete outcome built from two real autonomous edits")
        precondition(result("S-PARTIAL").autonomousState == .partial && result("S-PARTIAL").exactPairViolations == 0, "multi-edit partial outcome")
        precondition(result("S-WIDE").autonomousState == .complete && result("S-WIDE").exactPairViolations == 1, "wide edit: outcome complete, exact-pair violation counted (the V1.23 situation)")
        precondition(
            result("S-COMBINED").autonomousState == .unchanged && result("S-COMBINED").counterfactualState == .complete && result("S-COMBINED").acceptedEditCount == 0,
            "a combined wide edit is contained by the Authority: autonomous unchanged, counterfactual complete (MULTI-002)"
        )
        precondition(result("S-FOREIGN").autonomousState == .foreign && result("S-FOREIGN").exactPairViolations == 1, "injected foreign outcome is detected by U1 and U0")
        precondition(result("S-ABSTAIN-CHANGED").autonomousState == .foreign && result("S-ABSTAIN-EMPTY").autonomousState == .unchanged)
        precondition(result("S-MANUAL").autonomousState == nil && result("S-MANUAL").acceptedEditCount == 1 && result("S-MANUAL").exactPairViolations == 0, "manual entries are never classified or counted in U0")
        precondition(result("S-PROVIDER").autonomousState == .unchanged && result("S-PROVIDER").trialKind == "providerFailure", "a provider failure leaves the text unchanged")
        precondition(result("S-PROTOCOL").autonomousState == .unchanged && result("S-PROTOCOL").replayMismatch == nil, "a recorded protocol failure replays as a whole-response rejection")
        precondition(results.u0 == 3 && results.u1Entries.map(\.entry.id).sorted() == ["S-ABSTAIN-CHANGED", "S-FOREIGN"], "U0 and U1 are separate counts")
        precondition(results.u2Intersections == 0 && results.u3Violations == 0 && results.replayMismatches.isEmpty, "the real Authority output is clean under the independent monitors")
        precondition(results.formAutonomous == SupplementaryFormAdherence(resolvedEdits: 7, wholeTextSpan: 1, exactExpectedPair: 3), "form adherence is reported separately from outcome correctness")

        // Replay-fidelity detection: a recorded bucket that the real chain does not reproduce is reported.
        let tampered = try self.evaluate([(multi, self.trial(multi, raw: [both], buckets: ["autonomouslyAccepted", "reviewOnly"]))], repoRoot)
        precondition(tampered.replayMismatches.count == 1 && tampered.replayMismatches[0].replayMismatch?.contains("bucket") == true)
        let wrongKind = try self.evaluate([(multi, self.trial(multi, kind: "protocolFailure", raw: [both], buckets: []))], repoRoot)
        precondition(wrongKind.replayMismatches.count == 1, "a recorded outcome kind that the replay does not reproduce is reported")
        let wrongText = try self.evaluate([(multi, self.trial(multi, raw: [both], buckets: ["autonomouslyAccepted", "autonomouslyAccepted"], normalized: "different"))], repoRoot)
        precondition(wrongText.replayMismatches.count == 1)
    }

    // MARK: - Real V1.23 reproduction

    private static func testRealV123Reproduction(_ repoRoot: URL) throws {
        let corpus = try CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
        let trials = try SupplementaryArtifacts.loadTrials(repoRoot: repoRoot)
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        let r = try SupplementaryEvaluator.evaluate(corpus: corpus, trials: trials, processor: processor)

        precondition(r.entries.count == 44 && r.scored.count == 41 && r.warranted.count == 18 && r.abstentionExpected.count == 23)
        precondition(r.u0 == 4, "frozen V1.23 hard-criterion reference reproduced: U0 = 4")
        precondition(r.u1Entries.isEmpty, "U1 = 0")
        let autonomous = r.stateCounts(r.warranted)
        precondition(autonomous[.complete] == 4 && autonomous[.unchanged] == 14 && autonomous[.partial] == nil && autonomous[.foreign] == nil, "4/18 complete autonomous")
        precondition(r.warranted.filter { $0.autonomousState == .complete }.map(\.entry.id) == ["CAP-001", "CAP-002", "CAP-004", "MULTI-004"])
        let counterfactual = r.stateCounts(r.warranted, counterfactual: true)
        precondition(counterfactual[.complete] == 5, "5/18 under the counterfactual 'all addressed edits applied' (adds MULTI-002)")
        precondition(r.warranted.filter { $0.autonomousState == .complete }.reduce(0) { $0 + $1.entry.perCorrectionDenominator } == 5)
        precondition(r.warranted.filter { $0.counterfactualState == .complete }.reduce(0) { $0 + $1.entry.perCorrectionDenominator } == 7)
        precondition(r.perCorrectionDenominator == 22)
        precondition(r.stateCounts(r.abstentionExpected)[.unchanged] == 23, "no abstention-expected entry had its text changed")
        precondition(r.entries.filter(\.entry.manualAdjudicationOnly).allSatisfy { $0.autonomousState == nil && $0.acceptedEditCount == 0 })
        precondition(r.formAll == SupplementaryFormAdherence(resolvedEdits: 9, wholeTextSpan: 7, exactExpectedPair: 0))
        precondition(r.formScored == SupplementaryFormAdherence(resolvedEdits: 6, wholeTextSpan: 6, exactExpectedPair: 0))
        precondition(r.formAutonomous == SupplementaryFormAdherence(resolvedEdits: 4, wholeTextSpan: 4, exactExpectedPair: 0))
        precondition(r.u2Intersections == 0 && r.u2DigitChangedEntries.isEmpty && r.u3Violations == 0, "no runtime-safety invariant observation")
        precondition(r.replayMismatches.isEmpty, "the replay reproduces every recorded V1.23 disposition")
        precondition(r.entries.reduce(0) { $0 + $1.acceptedEditCount } == 4)
        // Frozen reference cross-check: recorded correctness labels agree with the recomputed U0.
        let recordedIncorrectAccepted = trials.filter { !$0.manualAdjudicationOnly }.flatMap(\.edits).filter { $0.bucket == "autonomouslyAccepted" && $0.correctness == "incorrect" }.count
        precondition(recordedIncorrectAccepted == r.u0, "U0 recomputed from pairs equals the V1.23 recorded labels")
    }

    // MARK: - Pins and report

    private static func testArtifactPins(_ repoRoot: URL) {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("v125-pin-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let directory = scratch.appendingPathComponent(SupplementaryArtifacts.directory)
        precondition((try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil)
        guard var data = try? Data(contentsOf: repoRoot.appendingPathComponent(SupplementaryArtifacts.directory).appendingPathComponent("trials.json")) else { preconditionFailure("read trials") }
        data.append(0x20)
        precondition((try? data.write(to: directory.appendingPathComponent("trials.json"))) != nil)
        do {
            _ = try SupplementaryArtifacts.loadTrials(repoRoot: scratch)
            preconditionFailure("a modified V1.23 raw artifact must be refused")
        } catch SupplementaryArtifacts.LoadError.hashMismatch {} catch { preconditionFailure("wrong error \(error)") }
        do {
            _ = try SupplementaryArtifacts.loadTrials(repoRoot: scratch.appendingPathComponent("absent"))
            preconditionFailure("missing artifacts must be refused")
        } catch SupplementaryArtifacts.LoadError.unreadable {} catch { preconditionFailure("wrong error \(error)") }
    }

    private static func testReportIsDeterministicAndLabelled(_ repoRoot: URL) throws {
        let corpus = try CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath))
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        let results = try SupplementaryEvaluator.evaluate(corpus: corpus, trials: SupplementaryArtifacts.loadTrials(repoRoot: repoRoot), processor: processor)
        let provenance = SupplementaryReport.Provenance(
            corpusSHA256: corpus.sha256,
            trialsSHA256: SupplementaryArtifacts.trialsSHA256,
            reportSHA256: SupplementaryArtifacts.reportSHA256,
            manifestFileSHA256: SupplementaryArtifacts.manifestFileSHA256,
            v123ManifestSHA256: SupplementaryArtifacts.v123ManifestSHA256,
            frozenHardCriterionLineConfirmed: true
        )
        let first = SupplementaryReport.markdown(results: results, provenance: provenance)
        precondition(first == SupplementaryReport.markdown(results: results, provenance: provenance), "the report is deterministic (no timestamps)")
        let committed = try String(contentsOf: repoRoot.appendingPathComponent("Evaluation/Intelligence/V1_25_RESULTS/supplementary_results.md"), encoding: .utf8)
        precondition(committed == first, "the committed results report must equal what the code regenerates -- regenerate deliberately, never edit by hand")
        for needle in [
            "POST-HOC SUPPLEMENT", "does **not** replace, recompute or supersede any frozen V1.23 metric", "| **4** |", "U1 outcome-foreign autonomous outcomes | scored entries (41) | **0**",
            "| correction-warranted (18) | 14 | 0 | 4 | 0 | autonomous |", "| all entries | 9 | 7/9 | 0/9 |", "entries with any mismatch (re-derived text, whole-response outcome, edit count, edit bucket): 0",
            "not classified (manual)", "## Limitations (of this measurement)",
        ] {
            precondition(first.contains(needle), "report is missing: \(needle)")
        }
        precondition(!first.lowercased().contains("interpretation") || first.lowercased().contains("interpretation is"), "observed results only; no interpretation section")
        precondition(!first.lowercased().contains("overall score") && !first.lowercased().contains("weighted"), "no blended score")
    }

    // MARK: - Static guard

    private static func testNoProviderPath(_ repoRoot: URL) {
        let directory = repoRoot.appendingPathComponent("Evaluation/Intelligence/CapabilitySupplementary")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path).filter({ $0.hasSuffix(".swift") }), files.count == 4 else { preconditionFailure("expected 4 supplementary sources") }
        for name in files {
            guard let full = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else { preconditionFailure("read \(name)") }
            let code = full.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for forbidden in ["URLSession", "URLRequest", "URLProtocol", "LLMClient", "IntelligenceHarnessProvider", "Process()", ".propose("] {
                precondition(!code.contains(forbidden), "\(name) must have no provider/network path (found \(forbidden))")
            }
        }
    }
}
