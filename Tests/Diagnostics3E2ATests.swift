import Foundation

/// Phase 3E.2A: verifies the D01-D10 diagnostic references are loadable and
/// valid, that D06-D10 remain five separately identifiable samples (not
/// collapsed into one), and replays them through the real
/// `LegalDictationProcessor` under a perfect-ASR assumption (post-ASR text ==
/// dictated reference).
///
/// Deliberate split, per review: this file asserts only genuine evaluation
/// invariants -- D01 (the reliable working baseline) is asserted strictly,
/// because it staying `correctApplication` is a real regression signal.
/// D02/D03 are known, currently-open normalization findings (see
/// `Evaluation/DIAGNOSTICS_3E2A.md` for the exact observed baseline): this
/// file intentionally does NOT assert their current (defective) replacement
/// text, outcome kind, or transition, so that fixing the underlying
/// statutory-number parser later requires no companion edit here. It only
/// asserts that recognition itself succeeded for them (the dictated words
/// are present at the first observable stage) -- if that ever stops being
/// true, that is a real regression, independent of whether the normalization
/// gap is later fixed.
@main
enum Diagnostics3E2ATests {
    static func main() {
        let references = loadReferences()
        testAllTenLoadAndValidate(references)
        testPunctuationCasesAreFiveDistinctSamples(references)
        testSectionNumberPhrasingCurrentBehavior(references)
        testDatePhrasingProducesNoCandidate(references)
        testPunctuationCaseUsesExistingFormattingMachinery(references)
        print("PASS: Phase 3E.2A diagnostic references (D01-D10) load, validate, and replay as expected")
    }

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func loadReferences() -> [String: EvaluationReference] {
        let directory = root.appendingPathComponent("Evaluation/References/diagnostics-3e2a")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            preconditionFailure("cannot read \(directory.path)")
        }
        var byID: [String: EvaluationReference] = [:]
        for name in names.filter({ $0.hasSuffix(".json") }).sorted() {
            do {
                let reference = try EvaluationReference.load(from: directory.appendingPathComponent(name))
                byID[reference.id] = reference
            } catch {
                preconditionFailure("\(name): \(error)")
            }
        }
        return byID
    }

    private static func testAllTenLoadAndValidate(_ references: [String: EvaluationReference]) {
        let expectedIDs = (1...10).map { String(format: "D%02d", $0) }
        precondition(Set(references.keys) == Set(expectedIDs), "expected exactly D01..D10, found \(references.keys.sorted())")
        for id in expectedIDs {
            guard let reference = references[id] else { preconditionFailure("missing \(id)") }
            precondition(reference.validate().isEmpty, "\(id): \(reference.validate())")
            precondition(reference.tier == "synthetic", "\(id) is not synthetic")
        }
    }

    private static func testPunctuationCasesAreFiveDistinctSamples(_ references: [String: EvaluationReference]) {
        let punctuationIDs = (6...10).map { String(format: "D%02d", $0) }
        let samples = punctuationIDs.compactMap { references[$0] }
        precondition(samples.count == 5)
        precondition(Set(samples.map(\.id)).count == 5, "D06-D10 must remain five separately identifiable samples")
        // Same intended passage in every repetition -- that sameness is what makes repeatability measurable.
        precondition(Set(samples.map(\.reference)).count == 1, "D06-D10 must share one intended passage")
        precondition(Set(samples.map { $0.intendedFinal ?? "" }).count == 1)
        precondition(samples.allSatisfy { $0.legalExpectations == [LegalExpectation(kind: .noCandidate, source: nil, replacement: nil)] })
    }

    private static func loadPack() -> LanguagePack {
        let resources = root.appendingPathComponent("Sources/Fluid/Resources")
        guard let bundle = Bundle(path: resources.path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            preconditionFailure("bundled Indian Legal Core must load")
        }
        return pack
    }

    private static func replay(_ reference: EvaluationReference, _ processor: LegalDictationProcessor) -> SampleScore {
        let outcome = processor.process(reference.reference)
        let stages = [
            StageText(stage: EvaluationStage.postASRDeterministic, text: reference.reference),
            StageText(stage: EvaluationStage.legalNormalized, text: outcome.normalized),
        ]
        let observed = ObservedNormalization(
            input: reference.reference,
            output: outcome.normalized,
            applied: outcome.appliedChanges.map { .init(source: $0.trigger, replacement: $0.replacement) },
            declinedSources: outcome.declinedChanges.map(\.trigger)
        )
        return SampleScoring.score(reference: reference, stages: stages, observed: observed)
    }

    /// Anchors the exact known-current statutory-parsing behavior this milestone measured under a
    /// perfect-ASR assumption. D01 (digit-by-digit) is the working baseline; D02/D03 are recorded
    /// diagnostic evidence of a normalization gap in the mixed and hundreds-form phrasings -- this
    /// test does not assert those two forms should work, only that the run reports them precisely.
    /// D01 (evaluation invariant -- the reliable digit-by-digit baseline must
    /// keep working) is asserted strictly. D02/D03 (open normalization
    /// findings) are asserted only for recognition-level soundness: the
    /// dictated provision/statute words must still be *present* at the first
    /// observable stage. Their normalization outcome/kind/replacement text is
    /// deliberately NOT asserted here -- see the file-level doc comment.
    private static func testSectionNumberPhrasingCurrentBehavior(_ references: [String: EvaluationReference]) {
        guard let d01 = references["D01"], let d02 = references["D02"], let d03 = references["D03"] else {
            preconditionFailure("D01-D03 must be present")
        }
        let processor = LegalDictationProcessor(builtinPack: loadPack())

        let s01 = replay(d01, processor)
        precondition(s01.normalization.map(\.kind) == [.correctApplication], "\(s01.normalization)")
        let d01Provision = s01.criticalTokens.first { $0.type == .provision }
        precondition(d01Provision?.transitions.last?.transition == .recovered, "D01 provision token: \(String(describing: d01Provision))")
        let d01Statute = s01.criticalTokens.first { $0.type == .statute }
        precondition(d01Statute?.transitions.last?.transition == .preserved, "D01 statute token (already canonical in the dictation): \(String(describing: d01Statute))")

        for reference in [d02, d03] {
            let score = replay(reference, processor)
            precondition(!score.normalization.isEmpty, "\(reference.id): expected the statutory rule to recognize a candidate at all")
            let provisionAtStageOne = score.criticalTokens.first { $0.type == .provision }?.states.first?.state
            precondition(provisionAtStageOne == .spoken, "\(reference.id): dictated provision words must be present in postASRDeterministic (recognition, not normalization, would be the regression here)")
            let statuteAtStageOne = score.criticalTokens.first { $0.type == .statute }?.states.first?.state
            precondition(statuteAtStageOne == .canonical, "\(reference.id): dictated statute abbreviation must be present in postASRDeterministic")
        }
    }

    private static func testDatePhrasingProducesNoCandidate(_ references: [String: EvaluationReference]) {
        guard let d04 = references["D04"], let d05 = references["D05"] else { preconditionFailure("D04-D05 must be present") }
        let processor = LegalDictationProcessor(builtinPack: loadPack())
        for reference in [d04, d05] {
            let score = replay(reference, processor)
            precondition(score.normalization.map(\.kind) == [.correctNoCandidate], "\(reference.id): \(score.normalization)")
            let date = score.criticalTokens.first { $0.type == .date }
            precondition(date?.states.first?.state == .spoken, "\(reference.id) date token not preserved as dictated: \(String(describing: date))")
        }
    }

    /// Confirms the existing `FormattingScore` machinery (not a new subsystem) already reports
    /// exactly the missing-punctuation evidence D06-D10 need, under the no-punctuation-heard
    /// assumption that motivates `reference` carrying no periods here.
    private static func testPunctuationCaseUsesExistingFormattingMachinery(_ references: [String: EvaluationReference]) {
        guard let d06 = references["D06"] else { preconditionFailure("D06 must be present") }
        let processor = LegalDictationProcessor(builtinPack: loadPack())
        let score = replay(d06, processor)
        guard let formatting = score.formatting else { preconditionFailure("D06 must produce a formatting score") }
        precondition(formatting.comparable, "words must match for a formatting comparison to be meaningful")
        precondition(formatting.punctuationDifferences == 3, "expected all three sentence-ending stops missing under a no-punctuation-heard reference, got \(formatting.punctuationDifferences)")
        precondition(formatting.caseDifferences == 0)
    }
}
