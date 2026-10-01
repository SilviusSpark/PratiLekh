import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// Deterministic, model-free verification of the harness's own plumbing
/// (`Evaluation/Intelligence/Harness/*.swift`) against the fixtures in
/// `IntelligenceHarnessFixtures.swift`. No network call, no `LLMClient`, no
/// model: every fixture supplies its own stand-in `IntelligenceProviderResponse`
/// so a bug in the harness's wiring can never be confused with a real model's
/// behavior. This is the hard gate the V1.17 instructions require before any
/// substantive model-quality evaluation. Run via
/// `scripts/test_intelligence_harness.sh`.
@main
enum IntelligenceHarnessPipelineTests {
    static func main() {
        self.testZeroEdits()
        self.testSafePunctuationAccepted()
        self.testIntersectsResolvedSpanRejected()
        self.testUnsupportedCategoryRejected()
        self.testAddressingNoMatchRejected()
        self.testMalformedDuplicateKeyWholeResponseRejected()
        self.testFreeTextInsteadOfToolCallRejected()
        self.testGateBlocksWordMergeReviewOnly()
        self.testRepeatedTextByOccurrenceAccepted()
        self.testProviderFailureNeverReachesIntelligence()
        self.testSummaryAggregatesAllFixturesWithoutDoubleCounting()
        self.printSampleReportForVisualInspection()
        print("PASS: Intelligence V1.17 harness pipeline -- all fixtures produced their expected deterministic outcome")
    }

    private static let processor: LegalDictationProcessor = {
        do {
            return try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: FileManager.default.currentDirectoryPath)
        } catch {
            preconditionFailure("could not load the Indian Legal Core pack for the harness test: \(error)")
        }
    }()

    private static func evaluateFixture(_ fixture: IntelligenceHarnessFixtures.Fixture) -> IntelligenceHarnessSampleReport {
        switch IntelligenceHarnessPipeline.preflight(rawInputText: fixture.rawInputText, processor: self.processor) {
        case let .failure(reason):
            return IntelligenceHarnessSampleReport(
                sampleID: fixture.id,
                tier: "fixture",
                rawInputText: fixture.rawInputText,
                legalNormalizedText: nil,
                modelTextContent: nil,
                modelRawToolCallArguments: [],
                outcome: .preflightFailure(reason.description)
            )
        case let .success(pre):
            let outcome: IntelligenceHarnessSampleOutcome
            switch IntelligenceHarnessPipeline.evaluate(response: fixture.response, normalizedText: pre.normalizedText, protectedSpans: pre.protectedSpans) {
            case let .failure(reason): outcome = .wholeResponseRejected(reason.description)
            case let .success(sample): outcome = .evaluated(sample)
            }
            return IntelligenceHarnessSampleReport(
                sampleID: fixture.id,
                tier: "fixture",
                rawInputText: fixture.rawInputText,
                legalNormalizedText: pre.normalizedText,
                modelTextContent: fixture.response.textContent,
                modelRawToolCallArguments: fixture.response.toolCalls.map(\.rawArguments),
                outcome: outcome
            )
        }
    }

    private static func requireEvaluated(_ report: IntelligenceHarnessSampleReport, _ fixtureID: String) -> IntelligenceHarnessEvaluatedSample {
        guard case let .evaluated(sample) = report.outcome else {
            preconditionFailure("\(fixtureID): expected .evaluated, got \(report.outcome)")
        }
        return sample
    }

    private static func testZeroEdits() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.zeroEdits)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.zeroEdits.id)
        precondition(sample.isZeroProposal, "F-A: expected zero proposals")
        precondition(sample.wouldBeOutput == IntelligenceHarnessFixtures.zeroEdits.rawInputText, "F-A: wouldBeOutput must equal the unchanged normalized text")
    }

    private static func testSafePunctuationAccepted() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.safePunctuation)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.safePunctuation.id)
        precondition(sample.edits.count == 1, "F-B: expected exactly one edit")
        precondition(sample.edits[0].bucket == .autonomouslyAccepted, "F-B: expected autonomouslyAccepted, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.wouldBeOutput.hasSuffix("agreed."), "F-B: wouldBeOutput must reflect the accepted edit")
    }

    private static func testIntersectsResolvedSpanRejected() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.intersectsResolvedSpan)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.intersectsResolvedSpan.id)
        precondition(sample.edits.count == 1, "F-C: expected exactly one edit")
        precondition(sample.edits[0].bucket == .rejectedBySafetyAuthority, "F-C: expected rejectedBySafetyAuthority, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.edits[0].dispositionSummary.contains("intersectsResolvedSpan"), "F-C: expected intersectsResolvedSpan reason, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.wouldBeOutput == report.legalNormalizedText, "F-C: a rejected edit must never change wouldBeOutput")
        precondition(report.legalNormalizedText?.contains("Section 302 IPC") == true, "F-C: expected the statutory normalizer to have applied first, got \(report.legalNormalizedText ?? "nil")")
    }

    private static func testUnsupportedCategoryRejected() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.unsupportedCategory)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.unsupportedCategory.id)
        precondition(sample.edits.count == 1, "F-D: expected exactly one edit")
        precondition(sample.edits[0].bucket == .rejectedBySafetyAuthority, "F-D: expected rejectedBySafetyAuthority, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.edits[0].dispositionSummary.contains("unsupportedEditCategory"), "F-D: expected unsupportedEditCategory, got \(sample.edits[0].dispositionSummary)")
    }

    private static func testAddressingNoMatchRejected() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.addressingNoMatch)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.addressingNoMatch.id)
        precondition(sample.edits.count == 1, "F-E: expected exactly one edit")
        precondition(sample.edits[0].bucket == .addressingRejected, "F-E: expected addressingRejected, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.edits[0].addressingSummary.contains("noLiteralMatch"), "F-E: expected noLiteralMatch, got \(sample.edits[0].addressingSummary)")
    }

    private static func testMalformedDuplicateKeyWholeResponseRejected() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.malformedDuplicateKey)
        guard case let .wholeResponseRejected(reason) = report.outcome else {
            preconditionFailure("F-F: expected .wholeResponseRejected, got \(report.outcome)")
        }
        precondition(reason.contains("duplicateKey"), "F-F: expected duplicateKey in the whole-response failure, got \(reason)")
    }

    private static func testFreeTextInsteadOfToolCallRejected() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.freeTextInsteadOfToolCall)
        guard case let .wholeResponseRejected(reason) = report.outcome else {
            preconditionFailure("F-G: expected .wholeResponseRejected, got \(report.outcome)")
        }
        precondition(reason.contains("unexpectedTextContent"), "F-G: expected unexpectedTextContent, got \(reason)")
    }

    private static func testGateBlocksWordMergeReviewOnly() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.gateBlocksWordMerge)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.gateBlocksWordMerge.id)
        precondition(sample.edits.count == 1, "F-I: expected exactly one edit")
        precondition(sample.edits[0].bucket == .reviewOnly, "F-I: expected reviewOnly, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.edits[0].dispositionSummary.contains("wordBoundaryMerged"), "F-I: expected wordBoundaryMerged (V1.16 gate), got \(sample.edits[0].dispositionSummary)")
        precondition(sample.wouldBeOutput == report.legalNormalizedText, "F-I: a review-only edit must never change wouldBeOutput")
    }

    private static func testRepeatedTextByOccurrenceAccepted() {
        let report = self.evaluateFixture(IntelligenceHarnessFixtures.repeatedTextByOccurrence)
        let sample = self.requireEvaluated(report, IntelligenceHarnessFixtures.repeatedTextByOccurrence.id)
        precondition(sample.edits.count == 1, "F-J: expected exactly one edit")
        precondition(sample.edits[0].addressingSummary.contains("occurrence"), "F-J: expected basis: occurrence, got \(sample.edits[0].addressingSummary)")
        precondition(sample.edits[0].bucket == .autonomouslyAccepted, "F-J: expected autonomouslyAccepted, got \(sample.edits[0].dispositionSummary)")
        precondition(sample.wouldBeOutput.hasSuffix("not present."), "F-J: the second occurrence must be the one edited")
    }

    /// Structural, not a runtime assertion of production code: a real caller
    /// (the live `IntelligenceHarnessRunner`) must check its provider call's
    /// result and build `.providerFailure` directly, in which case
    /// `IntelligenceHarnessPipeline.evaluate` is simply never called for that
    /// sample -- there is no code path from a provider failure into
    /// Intelligence. This test documents and exercises exactly that shape.
    private static func testProviderFailureNeverReachesIntelligence() {
        let simulatedProviderResult: Result<IntelligenceProviderResponse, IntelligenceHarnessFailure> = .failure(IntelligenceHarnessFailure("simulated: could not connect to local provider"))
        let report: IntelligenceHarnessSampleReport
        switch simulatedProviderResult {
        case let .failure(reason):
            report = IntelligenceHarnessSampleReport(
                sampleID: "F-H-provider-failure",
                tier: "fixture",
                rawInputText: "irrelevant -- never normalized for this case",
                legalNormalizedText: nil,
                modelTextContent: nil,
                modelRawToolCallArguments: [],
                outcome: .providerFailure(reason.description)
            )
        case .success:
            preconditionFailure("unreachable: this fixture always simulates a failure")
        }
        guard case let .providerFailure(reason) = report.outcome else {
            preconditionFailure("F-H: expected .providerFailure")
        }
        precondition(reason.contains("simulated"), "F-H: expected the simulated reason to be preserved verbatim")
    }

    private static func testSummaryAggregatesAllFixturesWithoutDoubleCounting() {
        let reports = IntelligenceHarnessFixtures.all.map(self.evaluateFixture)
        let summary = IntelligenceHarnessReportFormatter.summarize(tier: "fixture", reports: reports)
        precondition(summary.sampleCount == IntelligenceHarnessFixtures.all.count, "summary must count every fixture once")
        precondition(summary.zeroProposalSamples == [IntelligenceHarnessFixtures.zeroEdits.id], "only F-A has zero proposals")
        precondition(summary.wholeResponseRejections.count == 2, "F-F and F-G are the only whole-response rejections")
        precondition((summary.bucketCounts[.autonomouslyAccepted] ?? 0) == 2, "F-B and F-J are autonomouslyAccepted")
        precondition((summary.bucketCounts[.reviewOnly] ?? 0) == 1, "F-I is the only reviewOnly edit")
        precondition((summary.bucketCounts[.rejectedBySafetyAuthority] ?? 0) == 2, "F-C and F-D are rejectedBySafetyAuthority")
        precondition((summary.bucketCounts[.addressingRejected] ?? 0) == 1, "F-E is the only addressingRejected edit")
        precondition(summary.autonomouslyAcceptedDetail.count == 2, "the safety-headline detail list must list exactly the 2 accepted edits")
    }

    /// Not an assertion -- prints one full sample report and the aggregate
    /// summary so a human can see the exact adjudication-format output this
    /// harness produces, verified here rather than only in a live run.
    private static func printSampleReportForVisualInspection() {
        print(IntelligenceHarnessReportFormatter.render(self.evaluateFixture(IntelligenceHarnessFixtures.intersectsResolvedSpan)))
        print("")
        let reports = IntelligenceHarnessFixtures.all.map(self.evaluateFixture)
        print(IntelligenceHarnessReportFormatter.render(IntelligenceHarnessReportFormatter.summarize(tier: "fixture", reports: reports)))
    }
}
