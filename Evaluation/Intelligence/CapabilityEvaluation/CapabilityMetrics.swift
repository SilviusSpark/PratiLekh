import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// The nine frozen V1.22 metrics (README Sec.5), as **raw counts with explicit denominators**.
/// Nothing here computes a blended or aggregate score, and no pass/fail threshold is invented
/// beyond the one frozen hard criterion (autonomous-safety count must be 0).
struct CapabilityFraction: Equatable {
    let numerator: Int
    let denominator: Int

    /// `k/n`, or `k/0 (n/a)` when the denominator is empty -- never a silent 0%.
    var text: String {
        self.denominator == 0 ? "\(self.numerator)/0 (n/a)" : "\(self.numerator)/\(self.denominator)"
    }
}

struct CapabilityRecallSummary: Equatable {
    /// Full recall over the entry-level denominator (18 in the frozen corpus).
    let entryFull: CapabilityFraction
    /// Multi-edit entries with some-but-not-all corrections matched -- its own count, never
    /// folded into full or missed (README Sec.4).
    let entryPartial: [(entryID: String, matched: Int, of: Int)]
    let entryMissed: Int
    /// Individual corrections matched over the 22-correction denominator.
    let perCorrection: CapabilityFraction

    static func == (lhs: CapabilityRecallSummary, rhs: CapabilityRecallSummary) -> Bool {
        lhs.entryFull == rhs.entryFull && lhs.entryMissed == rhs.entryMissed && lhs.perCorrection == rhs.perCorrection
            && lhs.entryPartial.map { "\($0.entryID):\($0.matched)/\($0.of)" } == rhs.entryPartial.map { "\($0.entryID):\($0.matched)/\($0.of)" }
    }
}

struct CapabilityCategoryRow {
    let category: String
    var entries = 0
    var evaluated = 0
    var zeroProposal = 0
    var editsProposed = 0
    var autonomouslyAccepted = 0
    var reviewOnly = 0
    var rejectedBySafetyAuthority = 0
    var addressingRejected = 0
    var protocolFailures = 0
    var providerFailures = 0
    var preflightFailures = 0
}

struct CapabilityMetrics {
    // (1) Correction precision -- per edit, scored entries only.
    let autonomousPrecision: CapabilityFraction
    let modelProposalPrecision: CapabilityFraction

    // (2) Correction recall -- both levels, both bases.
    let recallAutonomous: CapabilityRecallSummary
    let recallAttempt: CapabilityRecallSummary

    /// (3) Autonomous safety: raw count of autonomously-accepted edits on scored entries that
    /// match no expected correction. Hard target 0. Never a rate.
    let unsafeAutonomousEdits: [(entryID: String, edit: CapabilityEditAdjudication)]
    /// Autonomously-accepted edits on `manualAdjudicationOnly` entries: not scored, listed raw
    /// for human adjudication, and the hard criterion is not considered met until reviewed.
    let autonomousEditsPendingManualAdjudication: [(entryID: String, edit: CapabilityEditAdjudication)]

    // (4) .reviewOnly, (5) Safety Authority rejection -- each split by ground-truth correctness.
    let reviewOnlyCorrect: Int
    let reviewOnlyIncorrect: Int
    let reviewOnlyReasons: [String: Int]
    let rejectedCorrect: Int
    let rejectedIncorrect: Int
    let rejectedReasons: [String: Int]

    // (6) Addressing rejection -- own bucket, no correctness split.
    let addressingRejected: Int
    let addressingRejectedReasons: [String: Int]
    /// Informational only: addressing-rejected edits whose literal pair equals an expected correction.
    let addressingRejectedLiteralMatches: Int

    // (7) Valid abstention (`edits: []`).
    let correctAbstentions: CapabilityFraction // over scored abstention-expected entries
    let missedByAbstention: CapabilityFraction // over scored correction-warranted entries
    let abstentionsOnManualEntries: Int

    // (8) Protocol/transport failure, (9) provider/runtime failure (+ preflight, kept separate).
    let protocolFailures: [(entryID: String, detail: String)]
    let providerFailures: [(entryID: String, detail: String)]
    let preflightFailures: [(entryID: String, detail: String)]

    let categories: [CapabilityCategoryRow]
    let totalEntries: Int
    let manualEntryIDs: [String]

    static func aggregate(_ adjudications: [CapabilityEntryAdjudication]) -> CapabilityMetrics {
        var accepted = 0, acceptedCorrect = 0, addressed = 0, addressedCorrect = 0
        var unsafe: [(String, CapabilityEditAdjudication)] = []
        var pendingManual: [(String, CapabilityEditAdjudication)] = []
        var reviewCorrect = 0, reviewIncorrect = 0, rejectedCorrect = 0, rejectedIncorrect = 0
        var reviewReasons: [String: Int] = [:], rejectedReasons: [String: Int] = [:], addressingReasons: [String: Int] = [:]
        var addressingTotal = 0, addressingLiteral = 0
        var protocolFailures: [(String, String)] = [], providerFailures: [(String, String)] = [], preflightFailures: [(String, String)] = []
        var abstentionCorrect = 0, abstentionExpectedTotal = 0, abstentionMissed = 0, warrantedTotal = 0, abstentionsManual = 0
        var categoryRows: [String: CapabilityCategoryRow] = [:]
        var categoryOrder: [String] = []

        for item in adjudications {
            let entry = item.entry
            if categoryRows[entry.category] == nil {
                categoryOrder.append(entry.category)
            }
            var row = categoryRows[entry.category] ?? CapabilityCategoryRow(category: entry.category)
            defer { categoryRows[entry.category] = row }
            row.entries += 1
            if entry.isScoredCorrectionWarranted {
                warrantedTotal += 1
            }
            if entry.isScoredAbstentionExpected {
                abstentionExpectedTotal += 1
            }

            switch item.trial {
            case .preflightFailure:
                preflightFailures.append((entry.id, item.failureDetail ?? ""))
                row.preflightFailures += 1
            case .providerFailure:
                providerFailures.append((entry.id, item.failureDetail ?? ""))
                row.providerFailures += 1
            case .protocolFailure:
                protocolFailures.append((entry.id, item.failureDetail ?? ""))
                row.protocolFailures += 1
            case .evaluated:
                row.evaluated += 1
                if item.isZeroProposal {
                    row.zeroProposal += 1
                    if entry.manualAdjudicationOnly {
                        abstentionsManual += 1
                    } else if entry.isScoredAbstentionExpected {
                        abstentionCorrect += 1
                    } else if entry.isScoredCorrectionWarranted {
                        abstentionMissed += 1
                    }
                }
            }

            for edit in item.edits {
                row.editsProposed += 1
                let reason = self.cleanReason(edit.dispositionSummary)
                switch edit.bucket {
                case .autonomouslyAccepted: row.autonomouslyAccepted += 1
                case .reviewOnly: row.reviewOnly += 1
                case .rejectedBySafetyAuthority: row.rejectedBySafetyAuthority += 1
                case .addressingRejected: row.addressingRejected += 1
                }

                if edit.bucket == .addressingRejected {
                    if entry.isScored {
                        addressingTotal += 1
                        addressingReasons[self.cleanReason(edit.addressingSummary), default: 0] += 1
                        if edit.literalMatchesExpected {
                            addressingLiteral += 1
                        }
                    }
                    continue
                }
                guard entry.isScored, let correctness = edit.correctness else {
                    if edit.bucket == .autonomouslyAccepted {
                        pendingManual.append((entry.id, edit))
                    }
                    continue
                }
                let isCorrect = correctness != .incorrect
                addressed += 1
                if isCorrect {
                    addressedCorrect += 1
                }
                switch edit.bucket {
                case .autonomouslyAccepted:
                    accepted += 1
                    if isCorrect {
                        acceptedCorrect += 1
                    } else {
                        unsafe.append((entry.id, edit))
                    }
                case .reviewOnly:
                    if isCorrect {
                        reviewCorrect += 1
                    } else {
                        reviewIncorrect += 1
                    }
                    reviewReasons[reason, default: 0] += 1
                case .rejectedBySafetyAuthority:
                    if isCorrect {
                        rejectedCorrect += 1
                    } else {
                        rejectedIncorrect += 1
                    }
                    rejectedReasons[reason, default: 0] += 1
                case .addressingRejected:
                    break
                }
            }
        }

        return CapabilityMetrics(
            autonomousPrecision: CapabilityFraction(numerator: acceptedCorrect, denominator: accepted),
            modelProposalPrecision: CapabilityFraction(numerator: addressedCorrect, denominator: addressed),
            recallAutonomous: self.recall(adjudications, .autonomousAccepted),
            recallAttempt: self.recall(adjudications, .anyAddressedDisposition),
            unsafeAutonomousEdits: unsafe.map { (entryID: $0.0, edit: $0.1) },
            autonomousEditsPendingManualAdjudication: pendingManual.map { (entryID: $0.0, edit: $0.1) },
            reviewOnlyCorrect: reviewCorrect,
            reviewOnlyIncorrect: reviewIncorrect,
            reviewOnlyReasons: reviewReasons,
            rejectedCorrect: rejectedCorrect,
            rejectedIncorrect: rejectedIncorrect,
            rejectedReasons: rejectedReasons,
            addressingRejected: addressingTotal,
            addressingRejectedReasons: addressingReasons,
            addressingRejectedLiteralMatches: addressingLiteral,
            correctAbstentions: CapabilityFraction(numerator: abstentionCorrect, denominator: abstentionExpectedTotal),
            missedByAbstention: CapabilityFraction(numerator: abstentionMissed, denominator: warrantedTotal),
            abstentionsOnManualEntries: abstentionsManual,
            protocolFailures: protocolFailures.map { (entryID: $0.0, detail: $0.1) },
            providerFailures: providerFailures.map { (entryID: $0.0, detail: $0.1) },
            preflightFailures: preflightFailures.map { (entryID: $0.0, detail: $0.1) },
            categories: categoryOrder.compactMap { categoryRows[$0] },
            totalEntries: adjudications.count,
            manualEntryIDs: adjudications.filter { $0.entry.manualAdjudicationOnly }.map(\.entry.id)
        )
    }

    private static func recall(_ adjudications: [CapabilityEntryAdjudication], _ basis: CapabilityRecallBasis) -> CapabilityRecallSummary {
        var full = 0, missed = 0, entryDenominator = 0, correctionMatched = 0, correctionDenominator = 0
        var partial: [(entryID: String, matched: Int, of: Int)] = []
        for item in adjudications where item.entry.isScoredCorrectionWarranted {
            entryDenominator += 1
            switch item.recall(basis) {
            case .full: full += 1
            case let .partial(matched, total): partial.append((item.entry.id, matched, total))
            case .missed: missed += 1
            case .notApplicable: break
            }
            let credit = item.correctionCredit(basis)
            correctionMatched += credit.matched
            correctionDenominator += credit.denominator
        }
        return CapabilityRecallSummary(
            entryFull: CapabilityFraction(numerator: full, denominator: entryDenominator),
            entryPartial: partial,
            entryMissed: missed,
            perCorrection: CapabilityFraction(numerator: correctionMatched, denominator: correctionDenominator)
        )
    }

    /// Strips `<Module>.` prefixes from `String(describing:)` renderings of nested enum values
    /// (cosmetic only -- never changes which reason is reported). Same transformation the V1.17
    /// formatter applies; duplicated rather than widening that file's access level.
    static func cleanReason(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9_]+\\.(?=[A-Z][A-Za-z0-9_]*\\.)") else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }
}
