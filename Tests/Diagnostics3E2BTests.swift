import Foundation

/// Phase 3E.2B: verifies the N01-N12 / Y01-Y10 / P01-P06 diagnostic
/// references (28 total) are loadable, valid, and structurally paired as
/// intended, and does one real replay pass per case under a perfect-ASR
/// assumption to confirm each is recognized (a candidate is found where one
/// is expected, or none where none is expected).
///
/// Deliberately, per the Phase 3E.2A review lesson: this file does NOT
/// assert any case's current normalization outcome kind or exact replacement
/// text. N01-N12's current behavior (six currently correct, six currently
/// garbled) is documented evidence in the fixtures' own `notes`, not a
/// regression requirement in either direction -- a future parser change
/// (fixing the garbled six, or an unrelated regression in the currently
/// correct six) should not require editing this file.
@main
enum Diagnostics3E2BTests {
    static func main() {
        let references = loadReferences()
        testAllTwentyEightLoadAndValidate(references)
        testStatutoryNumberPairsAreStructured(references)
        testYearPhrasingAlternatesAndSharesOneIntendedDate(references)
        testPunctuationPassagesAreSixIndependentTakes(references)
        testStatutoryNumberRecognitionSoundness(references)
        testYearAndPunctuationProduceNoCandidate(references)
        print("PASS: Phase 3E.2B diagnostic references (N01-N12, Y01-Y10, P01-P06) load, validate, and replay as expected")
    }

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func loadReferences() -> [String: EvaluationReference] {
        let directory = root.appendingPathComponent("Evaluation/References/diagnostics-3e2b")
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

    private static func testAllTwentyEightLoadAndValidate(_ references: [String: EvaluationReference]) {
        let nIDs = (1...12).map { String(format: "N%02d", $0) }
        let yIDs = (1...10).map { String(format: "Y%02d", $0) }
        let pIDs = (1...6).map { String(format: "P%02d", $0) }
        let expected = Set(nIDs + yIDs + pIDs)
        precondition(references.count == 28, "expected exactly 28 references, found \(references.count)")
        precondition(Set(references.keys) == expected, "id set mismatch: \(Set(references.keys).symmetricDifference(expected))")
        for (id, reference) in references {
            precondition(reference.validate().isEmpty, "\(id): \(reference.validate())")
            precondition(reference.tier == "synthetic", "\(id) is not synthetic")
        }
    }

    /// Structural pairing only -- not which one is currently "better".
    private static func testStatutoryNumberPairsAreStructured(_ references: [String: EvaluationReference]) {
        let pairs: [(String, String, String, String)] = [
            ("N01", "N02", "34", "IPC"), ("N03", "N04", "144", "BNSS"), ("N05", "N06", "323", "IPC"),
            ("N07", "N08", "376", "IPC"), ("N09", "N10", "506", "IPC"), ("N11", "N12", "125", "BNSS"),
        ]
        for (oddID, evenID, provision, statute) in pairs {
            guard let odd = references[oddID], let even = references[evenID] else { preconditionFailure("\(oddID)/\(evenID) must both be present") }
            for reference in [odd, even] {
                let desiredFinal = "Section \(provision) \(statute)."
                precondition(reference.intendedFinal == desiredFinal, "\(reference.id): intendedFinal \(String(describing: reference.intendedFinal)) != \(desiredFinal)")
                guard case .apply = reference.legalExpectations.first?.kind else { preconditionFailure("\(reference.id) must be an apply expectation") }
                precondition(reference.legalExpectations.first?.replacement == "Section \(provision) \(statute)", "\(reference.id) desired replacement mismatch")
                let statuteToken = reference.criticalTokens.first { $0.type == .statute }
                precondition(statuteToken?.expected == statute, "\(reference.id) statute token mismatch")
                precondition(statuteToken?.spokenForms.contains(statute.lowercased()) == true, "\(reference.id) must proactively accept lowercase statute casing (Phase 3E.2A D03 lesson)")
                let provisionToken = reference.criticalTokens.first { $0.type == .provision }
                precondition(provisionToken?.expected == provision, "\(reference.id) provision token mismatch")
            }
            precondition(odd.reference != even.reference, "\(oddID)/\(evenID) must dictate the provision differently")
        }
    }

    private static func testYearPhrasingAlternatesAndSharesOneIntendedDate(_ references: [String: EvaluationReference]) {
        let ids = (1...10).map { String(format: "Y%02d", $0) }
        let phrasings = ids.map { id -> String in
            guard let reference = references[id] else { preconditionFailure("\(id) must be present") }
            return reference.reference
        }
        precondition(Set(phrasings).count == 2, "Y01-Y10 must use exactly two phrasings, found \(Set(phrasings).count)")
        for (index, id) in ids.enumerated() {
            guard let reference = references[id] else { preconditionFailure("\(id) must be present") }
            let expectedFamilyIsA = index % 2 == 0 // Y01,Y03,Y05,Y07,Y09 (1-based odd) -> index 0,2,4,6,8
            precondition(reference.reference.contains("Two thousand") == expectedFamilyIsA, "\(id) does not alternate A/B as required")
            precondition(reference.criticalTokens.first { $0.type == .date }?.expected == "12 July 2026", "\(id) must target the shared intended date")
            precondition(reference.legalExpectations == [LegalExpectation(kind: .noCandidate, source: nil, replacement: nil)])
        }
        let aCount = phrasings.filter { $0.contains("Two thousand") }.count
        precondition(aCount == 5, "expected exactly 5 trials of each phrasing, found \(aCount) of phrasing A")
    }

    private static func testPunctuationPassagesAreSixIndependentTakes(_ references: [String: EvaluationReference]) {
        let passagePairs = [("P01", "P02"), ("P03", "P04"), ("P05", "P06")]
        var allReferenceTexts: Set<String> = []
        for (firstID, secondID) in passagePairs {
            guard let first = references[firstID], let second = references[secondID] else { preconditionFailure("\(firstID)/\(secondID) must both be present") }
            precondition(first.reference == second.reference, "\(firstID)/\(secondID) must share one intended passage")
            precondition(first.intendedFinal == second.intendedFinal)
            // Two internal boundaries + one final boundary: three sentences.
            let sentenceCount = first.intendedFinal.map { $0.filter { $0 == "." }.count } ?? 0
            precondition(sentenceCount == 3, "\(firstID) must have exactly three intended sentences (two internal boundaries), found \(sentenceCount)")
            precondition(first.legalExpectations == [LegalExpectation(kind: .noCandidate, source: nil, replacement: nil)])
            allReferenceTexts.insert(first.reference)
        }
        precondition(allReferenceTexts.count == 3, "P01-P06 must be three distinct passages, found \(allReferenceTexts.count)")
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

    /// Recognition-level soundness only, for every N case regardless of which
    /// half currently normalizes correctly: the dictated provision/statute
    /// words must be present at the first observable stage. This does not
    /// assert normalization kind (see the file-level doc comment).
    private static func testStatutoryNumberRecognitionSoundness(_ references: [String: EvaluationReference]) {
        let processor = LegalDictationProcessor(builtinPack: loadPack())
        for id in (1...12).map({ String(format: "N%02d", $0) }) {
            guard let reference = references[id] else { preconditionFailure("\(id) must be present") }
            let score = replay(reference, processor)
            precondition(!score.normalization.isEmpty, "\(id): expected the statutory rule to recognize a candidate at all")
            let provisionAtStageOne = score.criticalTokens.first { $0.type == .provision }?.states.first?.state
            precondition(provisionAtStageOne == .spoken, "\(id): dictated provision words must be present in postASRDeterministic")
            let statuteAtStageOne = score.criticalTokens.first { $0.type == .statute }?.states.first?.state
            precondition(statuteAtStageOne == .canonical, "\(id): dictated statute abbreviation must be present in postASRDeterministic")
        }
    }

    private static func testYearAndPunctuationProduceNoCandidate(_ references: [String: EvaluationReference]) {
        let processor = LegalDictationProcessor(builtinPack: loadPack())
        for id in (1...10).map({ String(format: "Y%02d", $0) }) + (1...6).map({ String(format: "P%02d", $0) }) {
            guard let reference = references[id] else { preconditionFailure("\(id) must be present") }
            let score = replay(reference, processor)
            precondition(score.normalization.map(\.kind) == [.correctNoCandidate], "\(id): \(score.normalization)")
        }
    }
}
