import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// Deterministic verification of the evaluation machinery. **No model, no Ollama, no network
/// socket.** The frozen corpus is run only through deterministic stand-in proposers (an empty
/// responder, an "oracle" that returns each entry's own expected corrections, and failure
/// injectors) -- never a model -- through the real, unmodified V1.17 chain. The one place
/// `LLMClient` appears is to (a) inspect the request configuration the frozen run will send and
/// (b) count attempts against an in-process `URLProtocol` stub (no socket is opened).
/// Run via `scripts/test_intelligence_v1_capability_evaluation.sh`.
@main
enum IntelligenceV1CapabilityEvaluationTests {
    static func main() async {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        self.testCorpusLoaderAndFrozenDenominators(repoRoot)
        self.testAdjudicationRules()
        self.testMetricsAggregationOnHandBuiltScenario()
        await self.testDriverWithStandInProposers(repoRoot)
        self.testManifestAndPreflight(repoRoot)
        self.testRequestFreeze()
        await self.testRetryPolicyAgainstInProcessStub()
        self.testNoProviderPathInDeterministicMachinery(repoRoot)
        print("PASS: Intelligence V1.23A capability-evaluation machinery -- all deterministic checks passed (no model, no network)")
    }

    // MARK: - Helpers

    private static func entry(
        id: String = "T-001", category: String = "punctuation-correction-warranted", text: String = "t",
        expectation: String = "correctionWarranted", corrections: [(String, String)] = [], requiresAll: Bool = false, manual: Bool = false
    ) -> CapabilityCorpus.Entry {
        let list = corrections.map { "{\"source\":\(self.json($0.0)),\"replacement\":\(self.json($0.1))}" }.joined(separator: ",")
        let raw = """
        {"id":\(json(id)),"category":\(json(category)),"tier":"synthetic","text":\(json(text)),"expectation":\(json(expectation)),
        "expectedCorrections":[\(list)],"recallRequiresAll":\(requiresAll),"manualAdjudicationOnly":\(manual),
        "hazardNote":null,"knownRiskReference":null,"note":null}
        """
        guard let decoded = try? JSONDecoder().decode(CapabilityCorpus.Entry.self, from: Data(raw.utf8)) else { preconditionFailure("bad test entry") }
        return decoded
    }

    private static func json(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text), let encoded = String(bytes: data, encoding: .utf8) else { preconditionFailure("encode") }
        return encoded
    }

    private static func record(_ position: Int, _ source: String, _ replacement: String, _ bucket: IntelligenceHarnessBucket, disposition: String? = nil) -> IntelligenceHarnessEditRecord {
        IntelligenceHarnessEditRecord(
            position: position,
            id: "p\(position)",
            modelEdit: ModelFacingEdit(sourceText: source, replacementText: replacement),
            addressingSummary: bucket == .addressingRejected ? "rejected: noLiteralMatch" : "resolved (basis: only)",
            dispositionSummary: disposition ?? bucket.rawValue,
            bucket: bucket
        )
    }

    private static func evaluated(_ records: [IntelligenceHarnessEditRecord]) -> IntelligenceHarnessSampleOutcome {
        .evaluated(IntelligenceHarnessEvaluatedSample(schemaVersion: 1, edits: records, wouldBeOutput: "x"))
    }

    // MARK: - Corpus loader

    private static func testCorpusLoaderAndFrozenDenominators(_ repoRoot: URL) {
        let url = repoRoot.appendingPathComponent(CapabilityCorpus.relativePath)
        guard let corpus = try? CapabilityCorpus.load(from: url) else { preconditionFailure("the frozen corpus must load") }
        precondition(corpus.entries.count == 44 && corpus.scoredEntries.count == 41)
        precondition(corpus.manualEntries.map(\.id) == ["AMBIG-001", "AMBIG-002", "AMBIG-003"], "exactly the 3 ambiguous entries are manual")
        precondition(corpus.scoredCorrectionWarrantedEntries.count == 18, "README Sec.5.2 entry-level denominator")
        precondition(corpus.perCorrectionDenominator == 22, "README Sec.5.2 per-correction denominator")
        precondition(corpus.scoredAbstentionExpectedEntries.count == 23, "6 clean-control + 17 hazard")
        precondition(corpus.manualEntries.allSatisfy { $0.expectedCorrections.isEmpty }, "manual entries are never given automatic ground truth")

        // A wrong pin must refuse to load (the loader never repins).
        do {
            _ = try CapabilityCorpus.load(from: url, expectedSHA256: String(repeating: "0", count: 64))
            preconditionFailure("a mismatching hash must be refused")
        } catch let CapabilityCorpus.LoadError.hashMismatch(actual, _) {
            precondition(actual == CapabilityCorpus.frozenSHA256)
        } catch { preconditionFailure("wrong error: \(error)") }

        // A one-character edit must be refused against the real pin, before decoding.
        guard var data = try? Data(contentsOf: url) else { preconditionFailure("read corpus") }
        data.append(0x20)
        let tampered = FileManager.default.temporaryDirectory.appendingPathComponent("v123-tampered-corpus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tampered) }
        precondition((try? data.write(to: tampered)) != nil)
        do {
            _ = try CapabilityCorpus.load(from: tampered)
            preconditionFailure("a tampered corpus must be refused")
        } catch CapabilityCorpus.LoadError.hashMismatch {} catch { preconditionFailure("wrong error: \(error)") }
    }

    // MARK: - Adjudication (README Sec.4)

    private static func testAdjudicationRules() {
        let single = self.entry(corrections: [("court", "court.")])

        // Exact match, autonomously accepted: correct; full recall on both bases.
        var a = CapabilityAdjudicator.adjudicate(entry: single, outcome: self.evaluated([self.record(1, "court", "court.", .autonomouslyAccepted)]))
        precondition(a.edits[0].correctness == .correct(expectedIndex: 0))
        precondition(a.recall(.autonomousAccepted) == .full && a.recall(.anyAddressedDisposition) == .full)
        precondition(a.correctionCredit(.autonomousAccepted) == (1, 1))

        // Different replacement / different span / different case = incorrect (no fuzzy matching, a partial fix is not credit).
        for (source, replacement) in [("court", "court!"), ("in court", "in court."), ("Court", "Court."), ("court", "Court.")] {
            a = CapabilityAdjudicator.adjudicate(entry: single, outcome: self.evaluated([self.record(1, source, replacement, .autonomouslyAccepted)]))
            precondition(a.edits[0].correctness == .incorrect, "\(source)->\(replacement) must not match")
            precondition(a.recall(.autonomousAccepted) == .missed && a.recall(.anyAddressedDisposition) == .missed)
        }

        // Correct content held back as reviewOnly: attempt recall yes, autonomous recall no.
        a = CapabilityAdjudicator.adjudicate(entry: single, outcome: self.evaluated([self.record(1, "court", "court.", .reviewOnly)]))
        precondition(a.recall(.autonomousAccepted) == .missed && a.recall(.anyAddressedDisposition) == .full)

        // Addressing-rejected edit: never labelled, never earns recall; literal match kept as information only.
        a = CapabilityAdjudicator.adjudicate(entry: single, outcome: self.evaluated([self.record(1, "court", "court.", .addressingRejected)]))
        precondition(a.edits[0].correctness == nil && a.edits[0].literalMatchesExpected)
        precondition(a.recall(.autonomousAccepted) == .missed && a.recall(.anyAddressedDisposition) == .missed)

        // recallRequiresAll: full / partial (with exact counts) / missed, on each basis separately.
        let multi = self.entry(category: "multi-edit-correction-warranted", corrections: [("ram das", "Ram Das"), ("statement", "statement.")], requiresAll: true)
        a = CapabilityAdjudicator.adjudicate(entry: multi, outcome: self.evaluated([
            self.record(1, "ram das", "Ram Das", .autonomouslyAccepted), self.record(2, "statement", "statement.", .reviewOnly),
        ]))
        precondition(a.recall(.autonomousAccepted) == .partial(matched: 1, of: 2), "partial recall is its own outcome")
        precondition(a.recall(.anyAddressedDisposition) == .full)
        precondition(a.correctionCredit(.autonomousAccepted) == (1, 2) && a.correctionCredit(.anyAddressedDisposition) == (2, 2))
        a = CapabilityAdjudicator.adjudicate(entry: multi, outcome: self.evaluated([]))
        precondition(a.recall(.autonomousAccepted) == .missed && a.isZeroProposal && a.correctionCredit(.autonomousAccepted) == (0, 2))

        // Equivalent phrasings (recallRequiresAll=false, two listed pairs): any one is full credit, denominator 1.
        let equivalent = self.entry(corrections: [("court", "court."), ("court", "court;")])
        a = CapabilityAdjudicator.adjudicate(entry: equivalent, outcome: self.evaluated([self.record(1, "court", "court;", .autonomouslyAccepted)]))
        precondition(a.recall(.autonomousAccepted) == .full && a.correctionCredit(.autonomousAccepted) == (1, 1))

        // Mixed response: one correct + one unnecessary edit are adjudicated independently.
        a = CapabilityAdjudicator.adjudicate(entry: single, outcome: self.evaluated([
            self.record(1, "court", "court.", .autonomouslyAccepted), self.record(2, "the", "The", .autonomouslyAccepted),
        ]))
        precondition(a.edits[0].correctness == .correct(expectedIndex: 0) && a.edits[1].correctness == .incorrect)

        // Manual-adjudication entries: nothing is auto-labelled, recall not applicable.
        let manual = self.entry(id: "AMBIG-X", category: "ambiguous", manual: true)
        a = CapabilityAdjudicator.adjudicate(entry: manual, outcome: self.evaluated([self.record(1, "x", "y", .autonomouslyAccepted)]))
        precondition(a.edits[0].correctness == nil && a.recall(.autonomousAccepted) == .notApplicable)

        // Failures keep the entry in the denominators (recall .missed) and carry their kind.
        for (outcome, kind) in [
            (IntelligenceHarnessSampleOutcome.providerFailure("timed out"), CapabilityTrialKind.providerFailure),
            (.wholeResponseRejected("missingField"), .protocolFailure), (.preflightFailure("derivation"), .preflightFailure),
        ] {
            a = CapabilityAdjudicator.adjudicate(entry: single, outcome: outcome)
            precondition(a.trial == kind && a.recall(.autonomousAccepted) == .missed && !a.isZeroProposal && a.failureDetail != nil)
        }
    }

    // MARK: - Metrics on a hand-built scenario with known answers

    private static func testMetricsAggregationOnHandBuiltScenario() {
        let punct = self.entry(id: "P1", corrections: [("court", "court.")])
        let punct2 = self.entry(id: "P2", corrections: [("hall", "hall.")])
        let multi = self.entry(id: "M1", category: "multi-edit-correction-warranted", corrections: [("a b", "A b"), ("end", "end.")], requiresAll: true)
        let control = self.entry(id: "C1", category: "clean-control", expectation: "abstentionExpected")
        let hazard = self.entry(id: "H1", category: "hazard-word-merge", expectation: "abstentionExpected")
        let manual = self.entry(id: "A1", category: "ambiguous", manual: true)
        let outcomes: [(CapabilityCorpus.Entry, IntelligenceHarnessSampleOutcome)] = [
            (punct, self.evaluated([self.record(1, "court", "court.", .autonomouslyAccepted)])), // correct accepted
            (punct2, .providerFailure("timed out")), // failure stays in the denominator
            (multi, self.evaluated([
                self.record(1, "a b", "A b", .autonomouslyAccepted), self.record(2, "end", "end.", .reviewOnly, disposition: "reviewOnly(Mod.ReviewReason.wordBoundaryMerged)"),
                self.record(3, "zzz", "yyy", .rejectedBySafetyAuthority, disposition: "rejected(Mod.ProposalRejectionReason.unsupportedEditCategory)"),
                self.record(4, "q", "r", .addressingRejected),
            ])),
            (control, self.evaluated([])), // correct abstention
            (hazard, self.evaluated([self.record(1, "x y", "xy", .autonomouslyAccepted)])), // UNSAFE accepted
            (manual, self.evaluated([self.record(1, "m", "n", .autonomouslyAccepted)])), // pending manual, not unsafe
        ]
        let m = CapabilityMetrics.aggregate(outcomes.map { CapabilityAdjudicator.adjudicate(entry: $0.0, outcome: $0.1) })

        precondition(m.autonomousPrecision == CapabilityFraction(numerator: 2, denominator: 3), "2 correct of 3 accepted (manual excluded)")
        precondition(m.modelProposalPrecision == CapabilityFraction(numerator: 3, denominator: 5), "correct 3 of 5 addressed on scored entries")
        precondition(m.unsafeAutonomousEdits.count == 1 && m.unsafeAutonomousEdits[0].entryID == "H1")
        precondition(m.autonomousEditsPendingManualAdjudication.count == 1 && m.autonomousEditsPendingManualAdjudication[0].entryID == "A1")
        precondition(m.recallAutonomous.entryFull == CapabilityFraction(numerator: 1, denominator: 3), "P1 full; P2 failed; M1 partial")
        precondition(m.recallAutonomous.entryPartial.count == 1 && m.recallAutonomous.entryPartial[0].matched == 1 && m.recallAutonomous.entryMissed == 1)
        precondition(m.recallAutonomous.perCorrection == CapabilityFraction(numerator: 2, denominator: 4), "denominator 1+1+2")
        precondition(m.recallAttempt.entryFull == CapabilityFraction(numerator: 2, denominator: 3) && m.recallAttempt.perCorrection == CapabilityFraction(numerator: 3, denominator: 4))
        precondition(m.reviewOnlyCorrect == 1 && m.reviewOnlyIncorrect == 0 && m.reviewOnlyReasons["reviewOnly(ReviewReason.wordBoundaryMerged)"] == 1)
        precondition(m.rejectedCorrect == 0 && m.rejectedIncorrect == 1)
        precondition(m.addressingRejected == 1 && m.addressingRejectedLiteralMatches == 0)
        precondition(m.correctAbstentions == CapabilityFraction(numerator: 1, denominator: 2), "control abstained; hazard did not")
        precondition(m.missedByAbstention == CapabilityFraction(numerator: 0, denominator: 3))
        precondition(m.providerFailures.count == 1 && m.protocolFailures.isEmpty && m.preflightFailures.isEmpty)
        precondition(m.totalEntries == 6 && m.manualEntryIDs == ["A1"])
        precondition(CapabilityFraction(numerator: 0, denominator: 0).text == "0/0 (n/a)", "an empty denominator is never a silent 0%")
    }

    // MARK: - Driver, real pipeline, stand-in proposers

    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int {
            self.lock.lock(); defer { self.lock.unlock() }; self.value += 1; return self.value
        }

        var count: Int {
            self.lock.lock(); defer { self.lock.unlock() }; return self.value
        }
    }

    private static func toolResponse(_ edits: [[String: Any]]) -> IntelligenceProviderResponse {
        let payload: [String: Any] = ["schemaVersion": 1, "edits": edits]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        return IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: String(bytes: data, encoding: .utf8) ?? "")])
    }

    private static func testDriverWithStandInProposers(_ repoRoot: URL) async {
        guard let corpus = try? CapabilityCorpus.load(from: repoRoot.appendingPathComponent(CapabilityCorpus.relativePath)),
              let processor = try? IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        else { preconditionFailure("corpus/pack") }

        // (a) Empty responder: exactly one proposer call per entry, none retried.
        var counter = CallCounter()
        var trials = await CapabilityEvaluationDriver.run(corpus: corpus, processor: processor) { _ in
            _ = counter.next()
            return .success(self.toolResponse([]))
        }
        precondition(counter.count == 44 && trials.count == 44, "one attempt per entry, corpus order")
        precondition(trials.map(\.adjudication.entry.id) == corpus.entries.map(\.id))
        var m = CapabilityMetrics.aggregate(trials.map(\.adjudication))
        precondition(m.recallAutonomous.entryFull == CapabilityFraction(numerator: 0, denominator: 18) && m.recallAutonomous.entryMissed == 18)
        precondition(m.recallAutonomous.perCorrection == CapabilityFraction(numerator: 0, denominator: 22))
        precondition(m.correctAbstentions == CapabilityFraction(numerator: 23, denominator: 23))
        precondition(m.missedByAbstention == CapabilityFraction(numerator: 18, denominator: 18) && m.abstentionsOnManualEntries == 3)
        precondition(m.unsafeAutonomousEdits.isEmpty && m.protocolFailures.isEmpty && m.providerFailures.isEmpty && m.preflightFailures.isEmpty)
        precondition(m.autonomousPrecision.denominator == 0 && m.autonomousPrecision.text == "0/0 (n/a)")

        // (b) Oracle stand-in: returns each entry's own expected corrections. This is NOT a model.
        // It measures the benchmark's deterministic ceiling through the real unmodified chain:
        // can the real addressing/Safety Authority/V1.16 gate autonomously accept every expected
        // correction? Any shortfall is a benchmark/pipeline-premise finding to disclose, not to repair.
        counter = CallCounter()
        let ordered = corpus.entries
        trials = await CapabilityEvaluationDriver.run(corpus: corpus, processor: processor) { _ in
            let entry = ordered[counter.next() - 1]
            return .success(self.toolResponse(entry.expectedCorrections.map { ["sourceText": $0.source, "replacementText": $0.replacement] }))
        }
        m = CapabilityMetrics.aggregate(trials.map(\.adjudication))
        print(
            "INFO oracle ceiling: autonomous entry recall \(m.recallAutonomous.entryFull.text), per-correction \(m.recallAutonomous.perCorrection.text), "
                + "unsafe \(m.unsafeAutonomousEdits.count), precision \(m.autonomousPrecision.text), "
                + "SA-rejected \(m.rejectedCorrect)/\(m.rejectedIncorrect), reviewOnly \(m.reviewOnlyCorrect)/\(m.reviewOnlyIncorrect), addressing-rejected \(m.addressingRejected)"
        )
        precondition(m.unsafeAutonomousEdits.isEmpty, "feeding ground truth back through the real chain can never produce an unsafe autonomous edit")
        precondition(m.protocolFailures.isEmpty && m.providerFailures.isEmpty && m.preflightFailures.isEmpty)
        precondition(
            m.recallAutonomous.entryFull == CapabilityFraction(numerator: 18, denominator: 18) && m.recallAutonomous.perCorrection == CapabilityFraction(numerator: 22, denominator: 22),
            "the frozen benchmark is deterministically attainable: every expected correction is autonomously accepted by the real chain"
        )
        precondition(m.autonomousPrecision == CapabilityFraction(numerator: 22, denominator: 22))

        // (c) Provider failures: recorded, never retried, run continues, Intelligence never invoked.
        counter = CallCounter()
        trials = await CapabilityEvaluationDriver.run(corpus: corpus, processor: processor) { _ in
            let n = counter.next()
            return n % 4 == 0 ? .failure(IntelligenceHarnessFailure("LLMClient error: timed out")) : .success(self.toolResponse([]))
        }
        m = CapabilityMetrics.aggregate(trials.map(\.adjudication))
        precondition(counter.count == 44, "a failed entry is not re-attempted")
        precondition(m.providerFailures.count == 11 && trials.filter { $0.adjudication.trial == .providerFailure }.allSatisfy { $0.report.modelRawToolCallArguments.isEmpty })

        // (d) Whole-response failures (prose instead of a tool call; missing schemaVersion) are protocol failures.
        counter = CallCounter()
        trials = await CapabilityEvaluationDriver.run(corpus: corpus, processor: processor) { _ in
            counter.next() % 2 == 0
                ? .success(IntelligenceProviderResponse(textContent: "Here is the corrected text.", toolCalls: []))
                : .success(IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: #"{"edits":[]}"#)]))
        }
        m = CapabilityMetrics.aggregate(trials.map(\.adjudication))
        precondition(m.protocolFailures.count == 44 && m.recallAutonomous.entryMissed == 18, "failures stay in the recall denominator as misses")

        // (e) Report rendering over the oracle run: complete, raw, and never blended.
        counter = CallCounter()
        trials = await CapabilityEvaluationDriver.run(corpus: corpus, processor: processor) { _ in
            let entry = ordered[counter.next() - 1]
            return .success(self.toolResponse(entry.expectedCorrections.map { ["sourceText": $0.source, "replacementText": $0.replacement] }))
        }
        m = CapabilityMetrics.aggregate(trials.map(\.adjudication))
        let info = CapabilityRunInfo(runLabel: "STAND-IN SELF-TEST (not a model run)", manifestSHA256: "n/a", startedAt: "t0", finishedAt: "t1", observations: [("note", "oracle stand-in")])
        let report = CapabilityReport.markdown(info: info, preflight: CapabilityPreflight.contractChecks(), trials: trials, metrics: m)
        for needle in [
            "Unsafe autonomously-accepted edits (scored entries): 0", "entry-level full recall: 18/18", "per-correction recall: 22/22",
            "Manual adjudication (never auto-scored): AMBIG-001, AMBIG-002, AMBIG-003", "### AMBIG-001", "### MULTI-001", "model raw args[0]:",
            "## 8. Protocol/transport failure", "## 9. Provider/runtime failure", "| category | entries |",
        ] {
            precondition(report.contains(needle), "report is missing: \(needle)")
        }
        precondition(!report.lowercased().contains("overall score") && !report.lowercased().contains("f1 score") && !report.lowercased().contains("weighted"), "metrics are never blended")
        guard let log = try? JSONSerialization.jsonObject(with: CapabilityReport.trialLogJSON(trials: trials)) as? [[String: Any]] else { preconditionFailure("trial log is not valid JSON") }
        precondition(log.count == 44 && log.allSatisfy { ($0["modelRawToolCallArguments"] as? [String]) != nil })
    }

    // MARK: - Manifest and preflight

    private static func testManifestAndPreflight(_ repoRoot: URL) {
        let url = repoRoot.appendingPathComponent(CapabilityCorpus.relativePath)
        guard let corpus = try? CapabilityCorpus.load(from: url),
              let first = try? CapabilityRunManifest.proposed(repoRoot: repoRoot, corpus: corpus),
              let second = try? CapabilityRunManifest.proposed(repoRoot: repoRoot, corpus: corpus)
        else { preconditionFailure("manifest") }
        precondition(first.canonicalJSON == second.canonicalJSON && first.sha256 == second.sha256, "the manifest is deterministic")
        precondition(first.sha256 == CapabilitySHA256.hex(first.canonicalJSON) && first.sha256.count == 64)
        var mutated = first.content
        mutated["status"] = "executed"
        precondition(CapabilityRunManifest(content: mutated).sha256 != first.sha256, "any manifest change changes its hash")
        let text = first.prettyJSON
        let needles = [
            CapabilityFrozenRun.instructionsSHA256,
            CapabilityFrozenRun.toolDefinitionSHA256,
            CapabilityFrozenRun.ollamaManifestSHA256,
            CapabilityFrozenRun.ggufBlobSHA256,
            corpus.sha256,
            "llmClientMaxRetries",
            "granite4:3b",
        ]
        for needle in needles {
            precondition(text.contains(needle), "manifest missing \(needle)")
        }
        // The committed proposal must equal what the code regenerates now: any change to a hashed
        // measurement source after the proposal was written fails here until it is deliberately
        // re-proposed (and, once approved, re-approved) -- never silently.
        let proposalURL = repoRoot.appendingPathComponent("Evaluation/Intelligence/V1_23A_PROPOSED_RUN_MANIFEST.json")
        guard let proposalData = try? Data(contentsOf: proposalURL),
              let proposalObject = try? JSONSerialization.jsonObject(with: proposalData),
              let proposalCanonical = try? JSONSerialization.data(withJSONObject: proposalObject, options: [.sortedKeys, .withoutEscapingSlashes])
        else { preconditionFailure("the proposed manifest file must exist and parse") }
        precondition(proposalCanonical == first.canonicalJSON, "the committed proposed manifest no longer matches the measurement sources -- re-propose deliberately")
        precondition(first.content["gitCommit"] == nil, "no commit hash inside a hashed manifest (circular); HEAD is recorded in the run report")

        precondition(CapabilityPreflight.contractChecks().allSatisfy(\.passed), "V1.21 instructions and tool definition match the frozen hashes")
        precondition(CapabilityPreflight.scoringSourceCheck(repoRoot: repoRoot).passed)
        precondition(CapabilityPreflight.corpusCheck(url: url).check.passed)

        // Installed-model verification fails closed on a missing or different model directory.
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("v123-fake-ollama-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        precondition(CapabilityPreflight.installedModelChecks(modelsDirectory: scratch, hashBlob: false).allSatisfy { !$0.passed })
        let manifestDirectory = scratch.appendingPathComponent("manifests/\(CapabilityFrozenRun.ollamaManifestRelativePath)").deletingLastPathComponent()
        precondition((try? FileManager.default.createDirectory(at: manifestDirectory, withIntermediateDirectories: true)) != nil)
        precondition((try? Data(#"{"layers":[]}"#.utf8).write(to: scratch.appendingPathComponent("manifests/\(CapabilityFrozenRun.ollamaManifestRelativePath)"))) != nil)
        precondition(CapabilityPreflight.installedModelChecks(modelsDirectory: scratch, hashBlob: false).contains { !$0.passed }, "a different manifest is refused")

        // Runtime-probe parsing (the HTTP GETs themselves live only in the live runner).
        precondition(CapabilityPreflight.parseOllamaVersion(Data(#"{"version":"0.34.4"}"#.utf8)) == "0.34.4")
        precondition(CapabilityPreflight.parseOllamaVersion(Data("nonsense".utf8)) == nil)
        let tags = Data(#"{"models":[{"name":"qwen2.5:1.5b","digest":"aaa"},{"name":"granite4:3b","model":"granite4:3b","digest":"89962fcc75239ac434cdebceb6b7e0669397f92eaef9c487774b718bc36a3e5f"}]}"#.utf8)
        precondition(CapabilityPreflight.parseInstalledDigest(tags: tags, model: "granite4:3b") == CapabilityFrozenRun.ollamaManifestSHA256)
        precondition(CapabilityPreflight.parseInstalledDigest(tags: tags, model: "granite4:350m") == nil)

        // Real /api/tags shape (captured from Ollama 0.34.4 at V1.23A): `digest` is the bare manifest SHA-256.
        let realShape = Data("""
        {"models":[{"name":"granite4:3b","model":"granite4:3b","modified_at":"2026-09-28T07:18:18.141791023+05:30","size":2099521385,
        "digest":"89962fcc75239ac434cdebceb6b7e0669397f92eaef9c487774b718bc36a3e5f","details":{"format":"gguf","family":"granite","parameter_size":"3.4B","quantization_level":"Q4_K_M"}},
        {"name":"granite4:350m","model":"granite4:350m","digest":"5eee845b49c4b72ef9e385463a1e2ea9f6f937e08b019f3bbecec12bc1927221"}]}
        """.utf8)
        precondition(CapabilityPreflight.parseInstalledDigest(tags: realShape, model: "granite4:3b") == CapabilityFrozenRun.ollamaManifestSHA256)
        // Fail closed: a different digest, a sibling model, or an unparseable payload never equals the pin.
        let swapped = Data(#"{"models":[{"name":"granite4:3b","digest":"5eee845b49c4b72ef9e385463a1e2ea9f6f937e08b019f3bbecec12bc1927221"}]}"#.utf8)
        precondition(CapabilityPreflight.parseInstalledDigest(tags: swapped, model: "granite4:3b") != CapabilityFrozenRun.ollamaManifestSHA256)
        precondition(CapabilityPreflight.parseInstalledDigest(tags: Data("<html>".utf8), model: "granite4:3b") != CapabilityFrozenRun.ollamaManifestSHA256)
    }

    // MARK: - Request freeze (inspection only)

    private static func testRequestFreeze() {
        let text = "the accused was present in court"
        let frozen = IntelligenceHarnessProvider.LocalProviderConfig(
            baseURL: CapabilityFrozenRun.baseURL,
            model: CapabilityFrozenRun.modelName,
            apiKey: "",
            timeoutSeconds: CapabilityFrozenRun.timeoutSeconds,
            maxRetries: CapabilityFrozenRun.maxRetries
        )
        let config = IntelligenceHarnessProvider.makeLLMConfig(normalizedText: text, config: frozen)
        precondition(config.model == "granite4:3b" && config.baseURL == "http://localhost:11434/v1" && config.apiKey.isEmpty)
        precondition(!config.streaming && config.temperature == 0 && config.maxTokens == nil && config.extraParameters.isEmpty)
        precondition(config.timeoutSeconds == 60 && config.maxRetries == 1, "frozen: one attempt, explicit timeout")
        precondition(config.tools.count == 1)
        let messages = config.messages
        precondition(messages.count == 2 && messages[0]["role"] as? String == "system" && messages[1]["role"] as? String == "user")
        precondition(CapabilitySHA256.hex(of: messages[0]["content"] as? String ?? "") == CapabilityFrozenRun.instructionsSHA256)
        precondition(messages[1]["content"] as? String == text, "the user message is exactly the entry's legalNormalized text")
        let tool = (try? JSONSerialization.data(withJSONObject: config.tools[0], options: [.sortedKeys])) ?? Data()
        precondition(CapabilitySHA256.hex(tool) == CapabilityFrozenRun.toolDefinitionSHA256)

        // The exact request body keys for the frozen model: nothing implicit is injected.
        let body = LLMClient.shared.buildChatCompletionsBody(config)
        precondition(Set(body.keys) == ["model", "messages", "temperature", "tools", "tool_choice", "stream"], "unexpected request keys: \(body.keys.sorted())")
        precondition(body["tool_choice"] as? String == "auto" && body["stream"] as? Bool == false && body["temperature"] as? Double == 0)

        // Documented finding: without the explicit override the V1.17 harness inherits LLMClient's 3-attempt default.
        let v117 = IntelligenceHarnessProvider.LocalProviderConfig(baseURL: CapabilityFrozenRun.baseURL, model: "granite4:3b", apiKey: "", timeoutSeconds: nil)
        precondition(IntelligenceHarnessProvider.makeLLMConfig(normalizedText: text, config: v117).maxRetries == 3, "V1.17 default behavior is unchanged (3 attempts)")
    }

    // MARK: - Retry policy against an in-process stub (no socket)

    private final class CountingFailProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var attempts = 0
        private static let lock = NSLock()
        static func reset() {
            self.lock.lock(); self.attempts = 0; self.lock.unlock()
        }

        static var count: Int {
            self.lock.lock(); defer { self.lock.unlock() }; return self.attempts
        }

        override static func canInit(with request: URLRequest) -> Bool {
            true
        }

        override static func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.lock.lock(); Self.attempts += 1; Self.lock.unlock()
            self.client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
        }

        override func stopLoading() {}
    }

    private static func testRetryPolicyAgainstInProcessStub() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CountingFailProtocol.self]
        let client = LLMClient(session: URLSession(configuration: configuration))
        let text = "the accused was present in court"

        CountingFailProtocol.reset()
        let frozen = IntelligenceHarnessProvider.LocalProviderConfig(baseURL: CapabilityFrozenRun.baseURL, model: "granite4:3b", apiKey: "", timeoutSeconds: 60, maxRetries: 1)
        do {
            _ = try await client.call(IntelligenceHarnessProvider.makeLLMConfig(normalizedText: text, config: frozen))
            preconditionFailure("the stub always times out")
        } catch {}
        precondition(CountingFailProtocol.count == 1, "frozen policy: a timeout is ONE attempt (got \(CountingFailProtocol.count))")

        CountingFailProtocol.reset()
        let inherited = IntelligenceHarnessProvider.LocalProviderConfig(baseURL: CapabilityFrozenRun.baseURL, model: "granite4:3b", apiKey: "", timeoutSeconds: 60)
        do {
            _ = try await client.call(IntelligenceHarnessProvider.makeLLMConfig(normalizedText: text, config: inherited))
            preconditionFailure("the stub always times out")
        } catch {}
        precondition(CountingFailProtocol.count == 3, "documents the hazard V1.23 closes: LLMClient's default re-submits a timeout 3 times (got \(CountingFailProtocol.count))")
    }

    // MARK: - Static guard: the deterministic machinery has no provider path

    private static func testNoProviderPathInDeterministicMachinery(_ repoRoot: URL) {
        let directory = repoRoot.appendingPathComponent("Evaluation/Intelligence/CapabilityEvaluation")
        let deterministic = [
            "CapabilityCorpus", "CapabilityAdjudication", "CapabilityMetrics", "CapabilityEvaluationDriver",
            "CapabilityManifest", "CapabilityReport", "CapabilityPreflightRunner",
        ]
        for name in deterministic {
            guard let full = try? String(contentsOf: directory.appendingPathComponent("\(name).swift"), encoding: .utf8) else { preconditionFailure("read \(name)") }
            // Code lines only: doc comments legitimately say "no LLMClient dependency".
            let source = full.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            // Call-capable symbols only: the manifest legitimately *describes* the client in string literals.
            for forbidden in ["URLSession", "URLRequest", "URLProtocol", ".propose(", "LLMClient.shared.call", "LLMClient(", "Process()"] {
                precondition(!source.contains(forbidden), "\(name).swift must have no provider/network path (found \(forbidden))")
            }
        }
        guard let live = try? String(contentsOf: directory.appendingPathComponent("CapabilityLiveRunner.swift"), encoding: .utf8) else { preconditionFailure("read live runner") }
        precondition(live.contains("--execute-manifest") && live.contains("working tree is not clean") && live.contains("maxRetries: CapabilityFrozenRun.maxRetries"), "the live runner keeps its guards")
    }
}
