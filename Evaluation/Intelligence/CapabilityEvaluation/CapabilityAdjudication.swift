import Foundation

// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
//
// Applies the **committed V1.22 adjudication rules** (README Sec.4) to one corpus entry's
// outcome from the real, unmodified V1.17 harness chain. Pure and deterministic; no model,
// no network, no policy of its own beyond exact string equality:
//   - an edit is *correct* iff its `(sourceText, replacementText)` pair equals a listed
//     `expectedCorrections` pair exactly (case-sensitive, no fuzzy/semantic matching);
//   - any other edit is *incorrect* (a partial/different-span correction included);
//   - correctness is recorded independently of the pipeline disposition, so a safeguard
//     containing a bad proposal is distinguishable from a safeguard blocking a good one;
//   - `manualAdjudicationOnly` entries are never scored (no correctness label at all);
//   - an addressing-rejected edit never resolved to a located span, so it is given no
//     correctness label (README Sec.5.6); whether its literal text pair equals an expected
//     correction is kept only as an informational flag and never enters recall/precision.

enum CapabilityTrialKind: String {
    /// Legal normalization / protected-span derivation failed; the model was never called.
    case preflightFailure
    /// The provider call failed; Intelligence code was never invoked. Not retried.
    case providerFailure
    /// Whole-response rejection (no/multiple tool calls, strict parser rejection, ...).
    case protocolFailure
    /// The response reached the deterministic chain (possibly with zero edits).
    case evaluated
}

enum CapabilityEditCorrectness: Equatable {
    case correct(expectedIndex: Int)
    case incorrect
}

struct CapabilityEditAdjudication {
    let position: Int
    let id: String
    let sourceText: String
    let replacementText: String
    let bucket: IntelligenceHarnessBucket
    let dispositionSummary: String
    let addressingSummary: String
    /// `nil` for edits on a `manualAdjudicationOnly` entry and for addressing-rejected edits.
    let correctness: CapabilityEditCorrectness?
    /// Informational only: literal pair equals one of the entry's expected corrections.
    let literalMatchesExpected: Bool
}

enum CapabilityRecallLevel: Equatable {
    case full
    case partial(matched: Int, of: Int)
    case missed
    case notApplicable
}

enum CapabilityRecallBasis {
    /// Matched by an edit that reached `.autonomouslyAccepted` (the production-facing number).
    case autonomousAccepted
    /// Matched by an edit that resolved addressing, at any Safety Authority disposition
    /// (separates "the model did not try" from "the model tried and a safeguard intervened").
    case anyAddressedDisposition
}

struct CapabilityEntryAdjudication {
    let entry: CapabilityCorpus.Entry
    let trial: CapabilityTrialKind
    let failureDetail: String?
    let edits: [CapabilityEditAdjudication]
    let matchedAutonomous: Set<Int>
    let matchedAnyAddressed: Set<Int>
    /// Evaluated, structurally valid, and zero edits proposed.
    let isZeroProposal: Bool

    func recall(_ basis: CapabilityRecallBasis) -> CapabilityRecallLevel {
        guard self.entry.isScoredCorrectionWarranted else { return .notApplicable }
        let matched = basis == .autonomousAccepted ? self.matchedAutonomous : self.matchedAnyAddressed
        if self.entry.recallRequiresAll {
            let total = self.entry.expectedCorrections.count
            if matched.count == total {
                return .full
            }
            return matched.isEmpty ? .missed : .partial(matched: matched.count, of: total)
        }
        return matched.isEmpty ? .missed : .full
    }

    /// Per-correction credit toward the 22-correction denominator (README Sec.5.2).
    func correctionCredit(_ basis: CapabilityRecallBasis) -> (matched: Int, denominator: Int) {
        let denominator = self.entry.perCorrectionDenominator
        guard denominator > 0 else { return (0, 0) }
        let matched = basis == .autonomousAccepted ? self.matchedAutonomous : self.matchedAnyAddressed
        return (self.entry.recallRequiresAll ? matched.count : (matched.isEmpty ? 0 : 1), denominator)
    }
}

enum CapabilityAdjudicator {
    static func adjudicate(entry: CapabilityCorpus.Entry, outcome: IntelligenceHarnessSampleOutcome) -> CapabilityEntryAdjudication {
        switch outcome {
        case let .preflightFailure(reason):
            return self.nonEvaluated(entry, .preflightFailure, reason)
        case let .providerFailure(reason):
            return self.nonEvaluated(entry, .providerFailure, reason)
        case let .wholeResponseRejected(reason):
            return self.nonEvaluated(entry, .protocolFailure, reason)
        case let .evaluated(sample):
            var matchedAutonomous = Set<Int>()
            var matchedAny = Set<Int>()
            let edits = sample.edits.map { record -> CapabilityEditAdjudication in
                let literalIndex = entry.expectedCorrections.firstIndex {
                    $0.source == record.modelEdit.sourceText && $0.replacement == record.modelEdit.replacementText
                }
                var correctness: CapabilityEditCorrectness?
                if entry.isScored, record.bucket != .addressingRejected {
                    if let literalIndex {
                        correctness = .correct(expectedIndex: literalIndex)
                        matchedAny.insert(literalIndex)
                        if record.bucket == .autonomouslyAccepted {
                            matchedAutonomous.insert(literalIndex)
                        }
                    } else {
                        correctness = .incorrect
                    }
                }
                return CapabilityEditAdjudication(
                    position: record.position,
                    id: record.id,
                    sourceText: record.modelEdit.sourceText,
                    replacementText: record.modelEdit.replacementText,
                    bucket: record.bucket,
                    dispositionSummary: record.dispositionSummary,
                    addressingSummary: record.addressingSummary,
                    correctness: correctness,
                    literalMatchesExpected: literalIndex != nil
                )
            }
            return CapabilityEntryAdjudication(
                entry: entry,
                trial: .evaluated,
                failureDetail: nil,
                edits: edits,
                matchedAutonomous: matchedAutonomous,
                matchedAnyAddressed: matchedAny,
                isZeroProposal: sample.isZeroProposal
            )
        }
    }

    private static func nonEvaluated(_ entry: CapabilityCorpus.Entry, _ kind: CapabilityTrialKind, _ detail: String) -> CapabilityEntryAdjudication {
        CapabilityEntryAdjudication(
            entry: entry,
            trial: kind,
            failureDetail: detail,
            edits: [],
            matchedAutonomous: [],
            matchedAnyAddressed: [],
            isZeroProposal: false
        )
    }
}
