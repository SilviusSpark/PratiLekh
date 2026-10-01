import Foundation

// Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation.
//
// Reads the committed, hash-pinned V1.23 raw trials and applies the V1.24 supplementary
// semantics. **Does not re-score V1.23**: the frozen metrics are not recomputed here; the frozen
// exact-pair hard-criterion value is only *reproduced as a reference* (U0) so the supplement can
// be read beside it. To make the supplement independent of the recorded dispositions, each trial's
// raw model tool-call arguments are replayed through the real, unmodified deterministic chain
// (`IntelligenceEditComposition`), and the replay is checked against what V1.23 recorded.
// No model, no network.

struct SupplementaryTrialRecord: Decodable {
    struct Edit: Decodable {
        let position: Int
        let sourceText: String
        let replacementText: String
        let bucket: String
        let correctness: String
        let literalMatchesExpected: Bool
    }

    let id: String
    let category: String
    let manualAdjudicationOnly: Bool
    let rawInput: String
    let legalNormalized: String?
    let modelFreeText: String?
    let modelRawToolCallArguments: [String]
    let trial: String
    let edits: [Edit]
}

enum SupplementaryArtifacts {
    static let directory = "Evaluation/Intelligence/V1_23_RESULTS"
    /// SHA-256 of the committed V1.23 raw artifacts. A mismatch means a frozen artifact changed.
    static let trialsSHA256 = "37ed4f4b97c8be867413764adc139d7ee465ada97a4da302788e05911850c883"
    static let reportSHA256 = "725917e72370dc725c2720fde63fbf2328f251e7f7d77729779ab9d56dbbc726"
    static let manifestFileSHA256 = "5326c971393299285ef2ad535c2b35f3923f95716b41d33d22182ab7d508f9cc"
    /// The V1.23 run manifest's canonical SHA-256 as recorded in the V1.23 report.
    static let v123ManifestSHA256 = "a1b7b13eff2f4b324f3385e69afc79194b989c2889a19dcc0c759c5e12e7d840"
    /// The frozen V1.23 hard-criterion value as printed in the V1.23 report.
    static let frozenHardCriterionLine = "**Unsafe autonomously-accepted edits (scored entries): 4** (target 0)"

    enum LoadError: Error, CustomStringConvertible {
        case unreadable(String)
        case hashMismatch(file: String, actual: String, expected: String)
        case undecodable
        var description: String {
            switch self {
            case let .unreadable(path): return "cannot read \(path)"
            case let .hashMismatch(file, actual, expected): return "\(file) SHA-256 \(actual) != pinned \(expected): a frozen V1.23 artifact changed"
            case .undecodable: return "trials.json could not be decoded"
            }
        }
    }

    static func verifiedData(_ name: String, expected: String, repoRoot: URL) throws -> Data {
        let url = repoRoot.appendingPathComponent(self.directory).appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { throw LoadError.unreadable(url.path) }
        let actual = CapabilitySHA256.hex(data)
        guard actual == expected else { throw LoadError.hashMismatch(file: name, actual: actual, expected: expected) }
        return data
    }

    static func loadTrials(repoRoot: URL) throws -> [SupplementaryTrialRecord] {
        let data = try self.verifiedData("trials.json", expected: self.trialsSHA256, repoRoot: repoRoot)
        guard let records = try? JSONDecoder().decode([SupplementaryTrialRecord].self, from: data) else { throw LoadError.undecodable }
        return records
    }
}

// MARK: - Results

struct SupplementaryEntryResult {
    let entry: CapabilityCorpus.Entry
    let trialKind: String
    let normalized: String
    let licensed: LicensedOutcomes? // nil for manual entries (no ground truth)
    /// Final text after applying only autonomously accepted edits.
    let autonomousFinal: String
    let autonomousState: SupplementaryOutcomeState? // nil for manual entries
    /// Counterfactual: final text if every addressed edit, at any disposition, were applied.
    let counterfactualFinal: String
    let counterfactualState: SupplementaryOutcomeState?
    let counterfactualSkippedOverlapping: Int
    let acceptedEditCount: Int
    /// U0 reference: autonomously accepted edits on this entry whose pair equals no expected pair
    /// (always 0 for manual entries, which are not scored).
    let exactPairViolations: Int
    let runtime: [SupplementaryRuntimeObservation]
    let digitSequenceChanged: Bool
    /// Replay disagreed with what V1.23 recorded for this entry (a fidelity defect, expected none).
    let replayMismatch: String?
}

struct SupplementaryResults {
    let entries: [SupplementaryEntryResult]
    let formAll: SupplementaryFormAdherence
    let formScored: SupplementaryFormAdherence
    let formAutonomous: SupplementaryFormAdherence

    var scored: [SupplementaryEntryResult] {
        self.entries.filter { $0.entry.isScored }
    }

    var warranted: [SupplementaryEntryResult] {
        self.entries.filter { $0.entry.isScoredCorrectionWarranted }
    }

    var abstentionExpected: [SupplementaryEntryResult] {
        self.entries.filter { $0.entry.isScoredAbstentionExpected }
    }

    /// U0 reference: exact-pair autonomous violations across scored entries.
    var u0: Int {
        self.scored.reduce(0) { $0 + $1.exactPairViolations }
    }

    /// U1: scored entries whose autonomous final text is outside `L(entry)`.
    var u1Entries: [SupplementaryEntryResult] {
        self.scored.filter { $0.autonomousState == .foreign }
    }

    /// U2a: accepted edits intersecting a protected span (all entries). U2b: entries whose digit sequence changed.
    var u2Intersections: Int {
        self.entries.reduce(0) { $0 + $1.runtime.filter(\.intersectsProtectedSpan).count }
    }

    var u2DigitChangedEntries: [SupplementaryEntryResult] {
        self.entries.filter(\.digitSequenceChanged)
    }

    var u3Violations: Int {
        self.entries.reduce(0) { $0 + $1.runtime.filter(\.u3Violation).count }
    }

    var replayMismatches: [SupplementaryEntryResult] {
        self.entries.filter { $0.replayMismatch != nil }
    }

    func stateCounts(_ group: [SupplementaryEntryResult], counterfactual: Bool = false) -> [SupplementaryOutcomeState: Int] {
        var counts: [SupplementaryOutcomeState: Int] = [:]
        for item in group {
            if let state = counterfactual ? item.counterfactualState : item.autonomousState {
                counts[state, default: 0] += 1
            }
        }
        return counts
    }
}

enum SupplementaryEvaluator {
    enum EvaluationError: Error, CustomStringConvertible {
        case missingTrial(String)
        case licensedOutcomes(entry: String, LicensedOutcomes.Failure)
        case preflight(entry: String, String)
        var description: String {
            switch self {
            case let .missingTrial(id): return "no V1.23 trial recorded for \(id)"
            case let .licensedOutcomes(entry, failure): return "\(entry): \(failure)"
            case let .preflight(entry, detail): return "\(entry): preflight failed: \(detail)"
            }
        }
    }

    static func evaluate(corpus: CapabilityCorpus, trials: [SupplementaryTrialRecord], processor: LegalDictationProcessor) throws -> SupplementaryResults {
        let byID = Dictionary(uniqueKeysWithValues: trials.map { ($0.id, $0) })
        var results: [SupplementaryEntryResult] = []
        var formAll = SupplementaryFormAdherence()
        var formScored = SupplementaryFormAdherence()
        var formAutonomous = SupplementaryFormAdherence()

        for entry in corpus.entries {
            guard let trial = byID[entry.id] else { throw EvaluationError.missingTrial(entry.id) }
            let pre: IntelligenceHarnessPipeline.Preflight
            switch IntelligenceHarnessPipeline.preflight(rawInputText: entry.text, processor: processor) {
            case let .failure(reason): throw EvaluationError.preflight(entry: entry.id, reason.description)
            case let .success(value): pre = value
            }
            var mismatch: String?
            if trial.legalNormalized != pre.normalizedText {
                mismatch = "recorded legalNormalized differs from re-derived"
            }

            // Replay the recorded raw model output through the real chain (no model).
            var autonomous: [(range: NSRange, replacement: String)] = []
            var addressed: [(range: NSRange, replacement: String)] = []
            var observations: [SupplementaryRuntimeObservation] = []
            var violations = 0
            let hasResponse = trial.trial == "evaluated" || trial.trial == "protocolFailure"
            if hasResponse {
                let response = IntelligenceProviderResponse(
                    textContent: trial.modelFreeText,
                    toolCalls: trial.modelRawToolCallArguments.map { IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: $0) }
                )
                switch IntelligenceEditComposition.evaluate(response: response, source: pre.normalizedText, protectedSpans: pre.protectedSpans) {
                case .failure:
                    if trial.trial != "protocolFailure" {
                        mismatch = (mismatch.map { $0 + "; " } ?? "") + "replay whole-response rejected but V1.23 recorded \(trial.trial)"
                    }
                case let .success(composition):
                    if trial.trial != "evaluated" {
                        mismatch = (mismatch.map { $0 + "; " } ?? "") + "replay evaluated but V1.23 recorded \(trial.trial)"
                    }
                    if composition.edits.count != trial.edits.count {
                        mismatch = (mismatch.map { $0 + "; " } ?? "") + "edit count differs"
                    }
                    for (offset, composed) in composition.edits.enumerated() {
                        let bucket: String
                        switch composed.stage {
                        case .addressingRejected: bucket = "addressingRejected"
                        case let .evaluated(proposal, _, disposition):
                            addressed.append((proposal.range, proposal.replacementText))
                            switch disposition {
                            case .autonomouslyAccepted:
                                bucket = "autonomouslyAccepted"
                                autonomous.append((proposal.range, proposal.replacementText))
                                observations.append(SupplementaryRuntimeSafetyMonitor.observe(
                                    source: pre.normalizedText,
                                    range: proposal.range,
                                    expectedSourceText: proposal.expectedSourceText,
                                    replacementText: proposal.replacementText,
                                    protectedSpans: pre.protectedSpans
                                ))
                                let matches = entry.expectedCorrections.contains { $0.source == composed.edit.sourceText && $0.replacement == composed.edit.replacementText }
                                if entry.isScored, !matches {
                                    violations += 1
                                }
                                formAutonomous.add(sourceText: composed.edit.sourceText, replacementText: composed.edit.replacementText, normalized: pre.normalizedText, matchesExpectedPair: matches)
                            case .reviewOnly: bucket = "reviewOnly"
                            case .rejected: bucket = "rejectedBySafetyAuthority"
                            }
                            let matches = entry.expectedCorrections.contains { $0.source == composed.edit.sourceText && $0.replacement == composed.edit.replacementText }
                            formAll.add(sourceText: composed.edit.sourceText, replacementText: composed.edit.replacementText, normalized: pre.normalizedText, matchesExpectedPair: matches)
                            if entry.isScored {
                                formScored.add(sourceText: composed.edit.sourceText, replacementText: composed.edit.replacementText, normalized: pre.normalizedText, matchesExpectedPair: matches)
                            }
                        }
                        if offset < trial.edits.count, trial.edits[offset].bucket != bucket {
                            mismatch = (mismatch.map { $0 + "; " } ?? "") + "edit \(offset + 1) bucket \(bucket) != recorded \(trial.edits[offset].bucket)"
                        }
                    }
                }
            }

            let final = SupplementaryApplication.apply(autonomous, to: pre.normalizedText).text
            let counterfactual = SupplementaryApplication.apply(addressed, to: pre.normalizedText)
            var licensed: LicensedOutcomes?
            var state: SupplementaryOutcomeState?
            var counterfactualState: SupplementaryOutcomeState?
            if entry.isScored {
                switch LicensedOutcomes.compute(source: pre.normalizedText, corrections: entry.expectedCorrections) {
                case let .failure(failure): throw EvaluationError.licensedOutcomes(entry: entry.id, failure)
                case let .success(value):
                    licensed = value
                    state = SupplementaryOutcomeState.classify(final: final, source: pre.normalizedText, licensed: value)
                    counterfactualState = SupplementaryOutcomeState.classify(final: counterfactual.text, source: pre.normalizedText, licensed: value)
                }
            }
            results.append(SupplementaryEntryResult(
                entry: entry,
                trialKind: trial.trial,
                normalized: pre.normalizedText,
                licensed: licensed,
                autonomousFinal: final,
                autonomousState: state,
                counterfactualFinal: counterfactual.text,
                counterfactualState: counterfactualState,
                counterfactualSkippedOverlapping: counterfactual.skippedOverlapping,
                acceptedEditCount: autonomous.count,
                exactPairViolations: violations,
                runtime: observations,
                digitSequenceChanged: SupplementaryRuntimeSafetyMonitor.digitSequenceChanged(source: pre.normalizedText, output: final),
                replayMismatch: mismatch
            ))
        }
        return SupplementaryResults(entries: results, formAll: formAll, formScored: formScored, formAutonomous: formAutonomous)
    }
}
