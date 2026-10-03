import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: S3 analysis and report, from raw records only.
///
/// Computes, as raw counts with explicit denominators, the four pre-registered metric groups, the hard gates
/// G1-G3, the advancement rule A1 (complete-outcome margin + exact McNemar), the lexicographic ranking, the
/// contract-probe trigger and the determinism-audit flag -- exactly as `protocol.json` states them. No
/// blended score exists. Nothing here may be changed after a stage's first inference (amendment rule).
///
/// Operationalizations fixed here, before any inference, and **ruled on by the architect before S2's freeze**
/// (none changes a frozen protocol rule; each fills a detail the protocol leaves implicit):
///   - G1 "responses" are calls that returned a response (no provider failure, no preflight failure). Tool engagement
///     = responses containing the expected tool name / responses. Strict-parser compliance = responses with exactly
///     one correctly-named tool call that the strict parser accepted / responses with exactly one correctly-named
///     tool call (the ones that reached the parser). Pass = numerator*100 >= denominator*95; an empty denominator fails;
///   - G2: provider/runtime failures over the screening pass; preflight failures are model-independent and are
///     reported separately (any is a tooling defect to disclose, not a model failure);
///   - the determinism-audit comparator is semantic (see `ComparisonAudit`); raw-text-only differences are reported
///     separately as `rawOutputDiffers` and are not disagreements;
///   - span width (`ComparisonSpanWidth`) is report-only and feeds no gate, stop, ranking or selection; its sentence
///     splitter ends a sentence after `.`/`?`/`!` followed by whitespace, so an abbreviation such as "Rs. 5" can split a
///     sentence -- a known, accepted limitation of a report-only metric;
///   - latency statistics and "calls above 30 s" are over the model's screening-pass calls and INCLUDE any cold-start
///     model load in the first call (no warm-up exists, by ruling);
///   - ranking has only the four V1.27 keys; registry order is presentation only, never a tie-breaker. An exact tie for
///     first place leaves no finalist and stops for review; the S4 "top two" are screened non-baseline candidates whether
///     or not they passed G1-G3/A1 (S4 cannot rehabilitate an S3-ineligible candidate), and an exact tie across the
///     cutoff stops for review instead of being broken;
///   - on-disk size for ranking is the S1 artifact's total layer bytes.
struct ComparisonModelResult {
    let candidate: ComparisonExecutionPlan.Candidate
    let screening: [ComparisonEntryScore]
    let audit: [ComparisonEntryScore]
    let auditComparisons: [ComparisonAuditComparison]
}

struct ComparisonGateResults {
    let g1ToolEngagementPass: Bool
    let g1ParserCompliancePass: Bool
    let g2Pass: Bool
    let g3U1: Int
    let g3U2: Int
    let g3U3: Int
    let g3FixturesContained: Bool
    let g3ControlHazardForeign: Int

    var g1Pass: Bool {
        self.g1ToolEngagementPass && self.g1ParserCompliancePass
    }

    var g3Pass: Bool {
        self.g3U1 == 0 && self.g3U2 == 0 && self.g3U3 == 0 && self.g3FixturesContained && self.g3ControlHazardForeign == 0
    }
}

struct ComparisonModelSummary {
    let result: ComparisonModelResult
    let responses: Int
    let providerFailures: [(entryID: String, detail: String)]
    let preflightFailures: [(entryID: String, detail: String)]
    let toolEngagement: CapabilityFraction
    let parserCompliance: CapabilityFraction
    let protocolFailureReasons: [String: Int]
    let latencyMedianMs: Int?
    let latencyMaxMs: Int?
    let callsAbove30s: Int
    // Edit-form group.
    let exactPairMatchedResolvedEdits: Int
    let resolvedEdits: Int
    let spanWidths: [ComparisonSpanWidth: Int]
    let editsWithOccurrence: Int
    let editsWithContext: Int
    let addressingRejectionReasons: [String: Int]
    // Outcome group.
    let warranted: Int
    let completeEntries: Set<String>
    let partialEntries: Int
    let perCorrection: CapabilityFraction
    let nonEmptyWarranted: Int
    let punctuationEntries: Int
    let punctuationNonEmpty: Int
    let nonEmptyByCategory: [String: (nonEmpty: Int, total: Int)]
    let stateByCategory: [String: [SupplementaryOutcomeState: Int]]
    let abstentionExpected: Int
    let correctAbstentionOnControlsAndHazards: Int
    let u0: Int
    let u1Entries: [String]
    let u2Intersections: Int
    let u2DigitChangedEntries: [String]
    let u3Violations: Int
    let controlHazardForeign: Int
    // Containment group.
    let dispositions: [String: Int]
    let dispositionsLicensed: [String: Int]
    let manualEntryOutputs: [(entryID: String, raw: [String], autonomousEdits: Int)]
    let replayMismatches: [String]
    let auditDisagreements: [String]
    let auditRawDifferenceOnly: [String]

    var completeCount: Int {
        self.completeEntries.count
    }

    var nondeterminismFlag: Bool {
        self.auditDisagreements.count >= 2
    }
}

struct ComparisonScreeningAnalysis {
    struct CandidateAssessment {
        let summary: ComparisonModelSummary
        let gates: ComparisonGateResults
        /// Discordant pairs versus the baseline on per-entry complete/not-complete: baseline-only, candidate-only.
        let discordantBaselineOnly: Int
        let discordantCandidateOnly: Int
        let mcNemarP: Double
        let a1Pass: Bool
        let eligible: Bool
    }

    let baseline: ComparisonModelSummary
    let baselineGates: ComparisonGateResults
    let assessments: [CandidateAssessment]
    /// Eligible candidates by the four V1.27 ranking keys only; exact ties are listed in registry order for presentation.
    let ranking: [String]
    /// nil when no candidate is eligible OR when first place is an exact tie (see `finalistTie`).
    let finalist: String?
    let finalistTie: [String]
    let probeTriggered: Bool
    /// Empty when the probe is not triggered or its population is undecided (see `probeCutoffTie`).
    let probeModels: [String]
    let probeCutoffTie: [String]
    /// Every reason the experiment must stop for architectural review: audit nondeterminism, a first-place tie, a probe-cutoff tie.
    let reviewStops: [String]
    /// True when `reviewStops` is non-empty: stop before finalist selection (S5) / S4 population choice.
    let haltBeforeS5: Bool
}

enum ComparisonAnalysis {
    enum AnalysisError: Error, CustomStringConvertible {
        case recordsDoNotMatchPlan(String)
        var description: String {
            switch self {
            case let .recordsDoNotMatchPlan(detail): "records do not match the pre-registered plan: \(detail)"
            }
        }
    }

    /// Verifies the records are exactly the plan (one record per step, in order, one run) and scores them.
    static func assemble(
        records: [ComparisonCallRecord],
        plan: ComparisonExecutionPlan,
        corpus: ComparisonCorpus,
        processor: LegalDictationProcessor,
        requireEvidenceKind: String = "developmentCorpus"
    ) throws -> [ComparisonModelResult] {
        let ordered = records.sorted { $0.sequence < $1.sequence }
        guard ordered.count == plan.steps.count
        else { throw AnalysisError.recordsDoNotMatchPlan("\(ordered.count) records for \(plan.steps.count) steps") }
        guard Set(ordered.map(\.runID)).count == 1,
              ordered
              .allSatisfy({ $0.evidenceKind == requireEvidenceKind && $0.contractArm == plan.arm.rawValue && $0.corpusSHA256 == corpus.sha256 })
        else {
            throw AnalysisError.recordsDoNotMatchPlan("mixed run ids, evidence kinds, contract arms or corpora")
        }
        let entries = Dictionary(uniqueKeysWithValues: corpus.entries.map { ($0.id, $0) })
        for (record, step) in zip(ordered, plan.steps) {
            guard record.sequence == step.sequence, record.candidateID == step.candidateID, record.phase == step.phase.rawValue,
                  record.entryID == step.entryID, record.entryOrdinal == step.entryOrdinal
            else {
                throw AnalysisError.recordsDoNotMatchPlan("record \(record.sequence) differs from step \(step.sequence)")
            }
        }
        var results: [ComparisonModelResult] = []
        for candidate in plan.candidates {
            var screening: [ComparisonEntryScore] = []
            var audit: [ComparisonEntryScore] = []
            for record in ordered where record.candidateID == candidate.id {
                guard let entry = entries[record.entryID] else { throw AnalysisError.recordsDoNotMatchPlan("unknown entry \(record.entryID)") }
                let score = try ComparisonScoring.score(entry: entry, record: record, processor: processor)
                if record.phase == "screening" {
                    screening.append(score)
                } else {
                    audit.append(score)
                }
            }
            let byID = Dictionary(uniqueKeysWithValues: screening.map { ($0.entry.id, $0) })
            let comparisons = audit.compactMap { second in byID[second.entry.id].map { ComparisonAudit.compare(screening: $0, audit: second) } }
            results.append(ComparisonModelResult(candidate: candidate, screening: screening, audit: audit, auditComparisons: comparisons))
        }
        return results
    }

    // MARK: - Per-model summary

    static func summarize(_ result: ComparisonModelResult) -> ComparisonModelSummary {
        let scores = result.screening
        let responseScores = scores
            .filter { $0.record.preflightFailure == nil && $0.record.providerFailure == nil && $0.record.latencyMilliseconds != nil }
        let reached = responseScores.filter(\.reachedParser)
        var protocolReasons: [String: Int] = [:]
        for score in scores where score.trialKind == .protocolFailure {
            protocolReasons[CapabilityMetrics.cleanReason(score.adjudication.failureDetail ?? "unknown"), default: 0] += 1
        }
        let latencies = scores.compactMap(\.record.latencyMilliseconds).sorted()
        var span: [ComparisonSpanWidth: Int] = [:]
        var rejections: [String: Int] = [:]
        var dispositions: [String: Int] = [:]
        var licensedDispositions: [String: Int] = [:]
        var form = SupplementaryFormAdherence()
        for score in scores {
            form.resolvedEdits += score.formAll.resolvedEdits
            form.exactExpectedPair += score.formAll.exactExpectedPair
            for width in score.spanWidths {
                span[width, default: 0] += 1
            }
            for reason in score.addressingRejectionReasons {
                rejections[CapabilityMetrics.cleanReason(reason), default: 0] += 1
            }
            for edit in score.adjudication.edits {
                dispositions[edit.bucket.rawValue, default: 0] += 1
                if case .correct? = edit.correctness {
                    licensedDispositions[edit.bucket.rawValue, default: 0] += 1
                }
            }
        }
        let warrantedScores = scores.filter(\.entry.isScoredCorrectionWarranted)
        let complete = Set(warrantedScores
            .filter { $0.trialKind != .providerFailure && $0.trialKind != .preflightFailure && $0.autonomousState == .complete }.map(\.entry.id))
        let partial = warrantedScores.filter { $0.autonomousState == .partial }.count
        var nonEmptyByCategory: [String: (nonEmpty: Int, total: Int)] = [:]
        var stateByCategory: [String: [SupplementaryOutcomeState: Int]] = [:]
        for score in warrantedScores {
            var cell = nonEmptyByCategory[score.entry.category] ?? (0, 0)
            cell.total += 1
            if score.isNonEmpty {
                cell.nonEmpty += 1
            }
            nonEmptyByCategory[score.entry.category] = cell
        }
        for score in scores where score.entry.isScored && score.trialKind != .providerFailure && score.trialKind != .preflightFailure {
            if let state = score.autonomousState {
                stateByCategory[score.entry.category, default: [:]][state, default: 0] += 1
            }
        }
        let abstention = scores.filter(\.entry.isScoredAbstentionExpected)
        let respondedAbstention = abstention.filter { $0.trialKind != .providerFailure && $0.trialKind != .preflightFailure }
        let correctAbstention = respondedAbstention.filter { $0.autonomousState == .unchanged }.count
        let foreignAbstention = abstention.filter { $0.autonomousState == .foreign }.count
        let metrics = CapabilityMetrics.aggregate(scores.map(\.adjudication))
        let punctuation = warrantedScores.filter { $0.entry.category == "punctuation-correction-warranted" }
        let manual = scores.filter(\.entry.manualAdjudicationOnly).map {
            (entryID: $0.entry.id, raw: $0.record.rawToolCallArguments, autonomousEdits: $0.acceptedEditCount)
        }
        return ComparisonModelSummary(
            result: result,
            responses: responseScores.count,
            providerFailures: scores.filter { $0.trialKind == .providerFailure }.map { ($0.entry.id, $0.adjudication.failureDetail ?? "") },
            preflightFailures: scores.filter { $0.trialKind == .preflightFailure }.map { ($0.entry.id, $0.adjudication.failureDetail ?? "") },
            toolEngagement: CapabilityFraction(numerator: responseScores.filter(\.toolEngaged).count, denominator: responseScores.count),
            parserCompliance: CapabilityFraction(numerator: reached.filter(\.parserCompliant).count, denominator: reached.count),
            protocolFailureReasons: protocolReasons,
            latencyMedianMs: latencies.isEmpty ? nil : latencies[latencies.count / 2],
            latencyMaxMs: latencies.last,
            callsAbove30s: latencies.filter { $0 > 30_000 }.count,
            exactPairMatchedResolvedEdits: form.exactExpectedPair,
            resolvedEdits: form.resolvedEdits,
            spanWidths: span,
            editsWithOccurrence: scores.reduce(0) { $0 + $1.editsWithOccurrence },
            editsWithContext: scores.reduce(0) { $0 + $1.editsWithContext },
            addressingRejectionReasons: rejections,
            warranted: warrantedScores.count,
            completeEntries: complete,
            partialEntries: partial,
            perCorrection: metrics.recallAutonomous.perCorrection,
            nonEmptyWarranted: warrantedScores.filter(\.isNonEmpty).count,
            punctuationEntries: punctuation.count,
            punctuationNonEmpty: punctuation.filter(\.isNonEmpty).count,
            nonEmptyByCategory: nonEmptyByCategory,
            stateByCategory: stateByCategory,
            abstentionExpected: abstention.count,
            correctAbstentionOnControlsAndHazards: correctAbstention,
            u0: scores.reduce(0) { $0 + $1.exactPairViolations },
            u1Entries: scores.filter { $0.entry.isScored && $0.autonomousState == .foreign }.map(\.entry.id),
            u2Intersections: scores.reduce(0) { $0 + $1.runtime.filter(\.intersectsProtectedSpan).count },
            u2DigitChangedEntries: scores.filter(\.digitSequenceChanged).map(\.entry.id),
            u3Violations: scores.reduce(0) { $0 + $1.runtime.filter(\.u3Violation).count },
            controlHazardForeign: foreignAbstention,
            dispositions: dispositions,
            dispositionsLicensed: licensedDispositions,
            manualEntryOutputs: manual,
            replayMismatches: scores.filter { $0.replayMismatch != nil }.map(\.entry.id),
            auditDisagreements: result.auditComparisons.filter(\.disagrees).map(\.entryID),
            auditRawDifferenceOnly: result.auditComparisons.filter { !$0.disagrees && $0.rawOutputDiffers }.map(\.entryID)
        )
    }

    // MARK: - Gates, A1, ranking, probe

    static func gates(_ summary: ComparisonModelSummary, fixturesContained: Bool) -> ComparisonGateResults {
        func atLeast95(_ fraction: CapabilityFraction) -> Bool {
            fraction.denominator > 0 && fraction.numerator * 100 >= fraction.denominator * 95
        }
        return ComparisonGateResults(
            g1ToolEngagementPass: atLeast95(summary.toolEngagement),
            g1ParserCompliancePass: atLeast95(summary.parserCompliance),
            g2Pass: summary.providerFailures.isEmpty,
            g3U1: summary.u1Entries.count,
            g3U2: summary.u2Intersections + summary.u2DigitChangedEntries.count,
            g3U3: summary.u3Violations,
            g3FixturesContained: fixturesContained,
            g3ControlHazardForeign: summary.controlHazardForeign
        )
    }

    /// Exact two-sided McNemar p on discordant counts (binomial, p = 0.5); 1 when there are no discordant pairs.
    static func mcNemarTwoSided(baselineOnly b: Int, candidateOnly c: Int) -> Double {
        let n = b + c
        guard n > 0 else { return 1 }
        var tail = 0.0
        var coefficient = 1.0
        for k in 0...min(b, c) {
            if k > 0 {
                coefficient = coefficient * Double(n - k + 1) / Double(k)
            }
            tail += coefficient
        }
        return min(1, 2 * tail / pow(2, Double(n)))
    }

    static func screen(results: [ComparisonModelResult], fixturesContained: Bool, baselineID: String = "CAND-BASE") -> ComparisonScreeningAnalysis? {
        let summaries = results.map(self.summarize)
        guard let baseline = summaries.first(where: { $0.result.candidate.id == baselineID }) else { return nil }
        var assessments: [ComparisonScreeningAnalysis.CandidateAssessment] = []
        for summary in summaries where summary.result.candidate.id != baselineID {
            let gates = self.gates(summary, fixturesContained: fixturesContained)
            let baseOnly = baseline.completeEntries.subtracting(summary.completeEntries).count
            let candOnly = summary.completeEntries.subtracting(baseline.completeEntries).count
            let p = self.mcNemarTwoSided(baselineOnly: baseOnly, candidateOnly: candOnly)
            let a1 = summary.completeCount >= baseline.completeCount + 5 && p < 0.10
            assessments.append(.init(
                summary: summary,
                gates: gates,
                discordantBaselineOnly: baseOnly,
                discordantCandidateOnly: candOnly,
                mcNemarP: p,
                a1Pass: a1,
                eligible: gates.g1Pass && gates.g2Pass && gates.g3Pass && a1
            ))
        }
        // Ranking (V1.27, and nothing else): (1) complete-outcome count, higher first; (2) non-empty rate on the punctuation
        // entries, higher first; (3) calls above 30 s, fewer first; (4) on-disk size, smaller first. There is NO further
        // tie-breaker: candidates equal on all four keys are an unresolved exact tie. Registry order is used only to
        // present tied candidates in a deterministic order and never decides anything.
        typealias Assessment = ComparisonScreeningAnalysis.CandidateAssessment
        let registryOrder = Dictionary(uniqueKeysWithValues: results.enumerated().map { ($1.candidate.id, $0) })
        func key(_ item: Assessment) -> [Int] {
            let summary = item.summary
            return [-summary.completeCount, -summary.punctuationNonEmpty, summary.callsAbove30s, summary.result.candidate.onDiskBytes]
        }
        func ranked(_ items: [Assessment]) -> [Assessment] {
            items.sorted { a, b in
                let x = key(a), y = key(b)
                return x == y ? (registryOrder[a.summary.result.candidate.id] ?? 0) < (registryOrder[b.summary.result.candidate.id] ?? 0) : x
                    .lexicographicallyPrecedes(y)
            }
        }
        func ids(_ items: [Assessment]) -> [String] {
            items.map(\.summary.result.candidate.id)
        }
        var reviewStops: [String] = []
        if summaries.contains(where: \.nondeterminismFlag) {
            reviewStops.append("determinism audit: two or more disagreements for a model (stop before S5)")
        }
        // Finalist: the single best eligible candidate; an exact tie for first place is not resolved automatically.
        let eligibleRanked = ranked(assessments.filter(\.eligible))
        let eligibleIDs = ids(eligibleRanked)
        var finalist = eligibleRanked.first.map { ids([$0])[0] }
        var finalistTie: [String] = []
        if let best = eligibleRanked.first {
            let tied = eligibleRanked.filter { key($0) == key(best) }
            if tied.count > 1 {
                finalist = nil
                finalistTie = ids(tied)
                reviewStops.append("exact tie for first place on all four ranking keys: \(finalistTie); no finalist is selected automatically")
            }
        }
        // Probe: triggered when the baseline's non-empty rate on scored warranted entries is below 0.50. Population = baseline plus the
        // top two screened NON-baseline candidates, whether or not they passed G1-G3/A1 (S4 cannot rehabilitate an S3-ineligible
        // candidate: eligibility above is final). An exact tie that straddles the cutoff is not broken: stop for review.
        let trigger = baseline.warranted > 0 && baseline.nonEmptyWarranted * 2 < baseline.warranted
        let screened = ranked(assessments)
        var probeModels: [String] = []
        var cutoffTie: [String] = []
        if trigger {
            if screened.count > 2, key(screened[1]) == key(screened[2]) {
                let straddling = screened.filter { key($0) == key(screened[1]) }
                cutoffTie = ids(straddling)
                reviewStops.append("S4 probe cutoff: exact tie across the top-two boundary \(cutoffTie); population not chosen automatically")
            } else {
                probeModels = [baselineID] + ids(Array(screened.prefix(2)))
            }
        }
        return ComparisonScreeningAnalysis(
            baseline: baseline,
            baselineGates: self.gates(baseline, fixturesContained: fixturesContained),
            assessments: assessments,
            ranking: eligibleIDs,
            finalist: finalist,
            finalistTie: finalistTie,
            probeTriggered: trigger,
            probeModels: probeModels,
            probeCutoffTie: cutoffTie,
            reviewStops: reviewStops,
            haltBeforeS5: !reviewStops.isEmpty
        )
    }

    // MARK: - Report

    private static func tally<K: Hashable>(_ counts: [K: Int], _ name: (K) -> String) -> String {
        counts.map { "\(name($0.key))=\($0.value)" }.sorted().joined(separator: ", ")
    }

    private static func summaryLines(_ summary: ComparisonModelSummary, gates: ComparisonGateResults) -> [String] {
        func fraction(_ numerator: Int, _ denominator: Int) -> String {
            CapabilityFraction(numerator: numerator, denominator: denominator).text
        }
        let candidate = summary.result.candidate
        let latency = "median \(summary.latencyMedianMs.map(String.init) ?? "n/a") ms, max \(summary.latencyMaxMs.map(String.init) ?? "n/a") ms"
        let categories = summary.nonEmptyByCategory.keys.sorted().compactMap { key in
            summary.nonEmptyByCategory[key].map { "\(key): non-empty \($0.nonEmpty)/\($0.total)" }
        }
        let manual = summary.manualEntryOutputs.map { "\($0.entryID): \($0.autonomousEdits) autonomous edit(s)" }
        return [
            "- protocol: tool engagement \(summary.toolEngagement.text); strict-parser compliance \(summary.parserCompliance.text); "
                + "protocol failures \(summary.protocolFailureReasons); provider failures \(summary.providerFailures.count); "
                + "preflight failures \(summary.preflightFailures.count)",
            "- observations (not gated): latency \(latency), calls > 30 s \(summary.callsAbove30s); on-disk bytes \(candidate.onDiskBytes)",
            "- edit form: exact-pair matches \(fraction(summary.exactPairMatchedResolvedEdits, summary.resolvedEdits)) of resolved edits; "
                + "span widths \(self.tally(summary.spanWidths) { $0.rawValue }); occurrence used \(summary.editsWithOccurrence), "
                + "context used \(summary.editsWithContext); addressing rejections \(summary.addressingRejectionReasons)",
            "- outcome: complete \(fraction(summary.completeCount, summary.warranted)) warranted; partial \(summary.partialEntries); "
                + "per-correction \(summary.perCorrection.text); non-empty on warranted \(fraction(summary.nonEmptyWarranted, summary.warranted)); "
                + "punctuation non-empty \(fraction(summary.punctuationNonEmpty, summary.punctuationEntries)); correct abstention on "
                + "controls+hazards \(fraction(summary.correctAbstentionOnControlsAndHazards, summary.abstentionExpected))",
            "- outcome by category: \(categories)",
            "- containment: dispositions \(self.tally(summary.dispositions) { $0 }) (licensed \(self.tally(summary.dispositionsLicensed) { $0 })); "
                + "U0 (report-only) \(summary.u0); U1 \(summary.u1Entries); U2 intersections \(summary.u2Intersections), "
                + "digit-changed \(summary.u2DigitChangedEntries); U3 \(summary.u3Violations)",
            "- manual entries (raw, human review required): \(manual)",
            "- gates: G1 \(gates.g1Pass) (engagement \(gates.g1ToolEngagementPass), parser \(gates.g1ParserCompliancePass)); G2 \(gates.g2Pass); "
                + "G3 \(gates.g3Pass) (U1 \(gates.g3U1), U2 \(gates.g3U2), U3 \(gates.g3U3), fixtures contained \(gates.g3FixturesContained), "
                + "control/hazard foreign \(gates.g3ControlHazardForeign))",
            "- determinism audit: disagreements \(summary.auditDisagreements) (flag \(summary.nondeterminismFlag)); "
                + "raw-text-only differences \(summary.auditRawDifferenceOnly)",
            "- replay mismatches (fidelity defects, expected none): \(summary.replayMismatches)",
            "",
        ]
    }

    static func markdown(_ analysis: ComparisonScreeningAnalysis, runLabel: String, lifecycleLines: [String] = []) -> String {
        var lines = [
            "# \(runLabel)",
            "",
            "Generated from raw records only (`ComparisonAnalysis`); raw counts with denominators, no blended score.",
            "",
        ]
        var sections = [(analysis.baseline, analysis.baselineGates, "baseline")]
        sections += analysis.assessments.map { ($0.summary, $0.gates, $0.eligible ? "ELIGIBLE" : "not eligible") }
        for (summary, gates, label) in sections {
            let candidate = summary.result.candidate
            lines.append("## \(candidate.id) `\(candidate.ollamaTag)` — \(label)")
            lines += self.summaryLines(summary, gates: gates)
        }
        lines.append("## Advancement (A1: complete >= baseline + 5 and exact McNemar p < 0.10)")
        for item in analysis.assessments {
            let id = item.summary.result.candidate.id
            let p = String(format: "%.4f", item.mcNemarP)
            lines.append(
                "- \(id): complete \(item.summary.completeCount) vs baseline \(analysis.baseline.completeCount); discordant baseline-only "
                    + "\(item.discordantBaselineOnly), candidate-only \(item.discordantCandidateOnly); p = \(p); A1 \(item.a1Pass); eligible \(item.eligible)"
            )
        }
        lines.append("- ranking (eligible, lexicographic): \(analysis.ranking); finalist: \(analysis.finalist ?? "none")")
        lines.append("- contract probe triggered: \(analysis.probeTriggered); probe models: \(analysis.probeModels)")
        lines.append("- ranking uses only the four V1.27 keys (registry order is presentation only); exact ties are never broken automatically")
        lines
            .append(
                "- review stops (halt before S5 / S4 population): \(analysis.reviewStops.isEmpty ? "none" : analysis.reviewStops.joined(separator: "; "))"
            )
        lines.append("")
        if !lifecycleLines.isEmpty {
            lines.append("")
            lines.append("## Runtime lifecycle accounting (non-proposer requests; excluded from every count, latency and metric above)")
            lines += lifecycleLines
        }
        lines.append("")
        lines.append("Selecting a finalist is not a production-readiness claim (PO-2/PO-3 unresolved).")
        return lines.joined(separator: "\n") + "\n"
    }
}
