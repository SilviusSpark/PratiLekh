import Foundation

/// Loads the synthetic reference fixtures and replays each through the real
/// `LegalDictationProcessor`, assuming a perfect recognizer (post-ASR text ==
/// the dictated reference). Proves the fixtures are valid and that the scorer
/// classifies real normalizer behavior as expected.
@main
enum EvaluationFixtureReplayTests {
    static func main() {
        let references = loadReferences()
        testFixturesAreValidAndSynthetic(references)
        testReplay(references)
        print("PASS: Evaluation synthetic fixtures validate and replay through the real legal processor")
    }

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func loadReferences() -> [EvaluationReference] {
        let directory = root.appendingPathComponent("Evaluation/References/synthetic")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            preconditionFailure("cannot read \(directory.path)")
        }
        return names.filter { $0.hasSuffix(".json") }.sorted().map { name in
            do {
                return try EvaluationReference.load(from: directory.appendingPathComponent(name))
            } catch {
                preconditionFailure("\(name): \(error)")
            }
        }
    }

    private static func testFixturesAreValidAndSynthetic(_ references: [EvaluationReference]) {
        precondition(references.count >= 6)
        precondition(Set(references.map(\.id)).count == references.count, "duplicate ids")
        for reference in references {
            precondition(reference.validate().isEmpty, "\(reference.id): \(reference.validate())")
            precondition(reference.tier == "synthetic", "\(reference.id) is not synthetic")
        }
        let kinds = Set(references.flatMap { $0.legalExpectations.map(\.kind) })
        precondition(kinds == [.apply, .decline, .noCandidate], "fixtures must exercise every expectation kind")
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

    private static func testReplay(_ references: [EvaluationReference]) {
        let processor = LegalDictationProcessor(builtinPack: loadPack())
        var corrupted = 0
        var severe = 0
        for reference in references {
            let score = replay(reference, processor)
            precondition(score.stageErrors[0].wer.edits == 0, "\(reference.id): perfect ASR must have zero WER")
            corrupted += score.criticalTokens.flatMap(\.transitions).filter { $0.transition == .corrupted }.count
            severe += score.normalization.filter { $0.kind.isSevere }.count
            switch reference.id {
            case "syn-prose-001", "syn-mixed-001", "syn-canonical-001":
                precondition(score.normalization.map(\.kind) == [.correctNoCandidate], "\(reference.id): \(score.normalization)")
            case "syn-stat-001", "syn-dw-001":
                precondition(score.normalization.map(\.kind) == [.correctApplication], "\(reference.id): \(score.normalization)")
                precondition(score.stageErrors[1].wer.edits == 0, "\(reference.id): final text must equal intendedFinal")
            case "syn-multi-001":
                precondition(score.normalization.allSatisfy { $0.kind == .correctApplication } && score.normalization.count == 2)
                precondition(score.criticalTokens.allSatisfy { $0.transitions[0].transition == .recovered })
                precondition(score.formatting?.comparable == true && score.formatting?.caseDifferences == 0)
            case "syn-decline-001", "syn-selfcorrection-001":
                precondition(score.normalization.map(\.kind) == [.correctDecline], "\(reference.id): \(score.normalization)")
                precondition(score.normalization[0].detail.contains("explicitly"), "declines must be explicit, not silent no-candidate")
                precondition(score.criticalTokens.allSatisfy { $0.transitions[0].transition == .unrecovered })
            default:
                break
            }
            if reference.id == "syn-canonical-001" {
                precondition(score.criticalTokens.allSatisfy { $0.transitions[0].transition == .preserved })
            }
        }
        precondition(corrupted == 0 && severe == 0, "real normalizer must not corrupt or falsely transform the synthetic corpus")
    }
}
