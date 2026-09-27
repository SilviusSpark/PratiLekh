import Foundation

@main
enum EvaluationScoringTests {
    static func main() {
        testExactCriticalTokenStates()
        testTransitions()
        testNormalizationOutcomes()
        testSampleScoringOrdinaryProse()
        testMultipleCriticalTokensInOneSample()
        testPlausibleButDifferentProvisionIsWrong()
        testReferenceValidation()
        testReferenceJSONRoundTrip()
        print("PASS: Evaluation scoring (critical tokens, transitions, normalization outcomes, references)")
    }

    private static let section302 = CriticalToken(type: .provision, expected: "302", spokenForms: ["three zero two"])
    private static let ipc = CriticalToken(type: .statute, expected: "IPC", spokenForms: ["I P C"])

    // MARK: - Critical tokens

    private static func testExactCriticalTokenStates() {
        precondition(CriticalTokenScoring.state(of: section302, in: "under Section 302 IPC") == .canonical)
        precondition(CriticalTokenScoring.state(of: section302, in: "under section three zero two of the I P C") == .spoken)
        precondition(CriticalTokenScoring.state(of: section302, in: "under Section 304 IPC") == .wrong)
        precondition(CriticalTokenScoring.state(of: section302, in: "under Section 3020 IPC") == .wrong, "boundary: 3020 is not 302")
        precondition(CriticalTokenScoring.state(of: section302, in: "under Section 302A IPC") == .wrong, "suffix changes the provision")
        precondition(CriticalTokenScoring.state(of: ipc, in: "under CrPC") == .wrong)
        precondition(CriticalTokenScoring.state(of: ipc, in: "under ipc") == .wrong, "canonical form is case-sensitive")
        let witness = CriticalToken(type: .witness, expected: "PW-1")
        precondition(CriticalTokenScoring.state(of: witness, in: "PW-10 stated") == .wrong, "PW-10 is not PW-1")
        precondition(CriticalTokenScoring.state(of: witness, in: "PW-1 stated") == .canonical)
        let negation = CriticalToken(type: .negation, expected: "not")
        precondition(CriticalTokenScoring.state(of: negation, in: "the accused did appear") == .wrong, "dropped negation")
    }

    private static func testTransitions() {
        typealias Scoring = CriticalTokenScoring
        precondition(Scoring.transition(from: .canonical, to: .canonical) == .preserved)
        precondition(Scoring.transition(from: .spoken, to: .canonical) == .recovered)
        precondition(Scoring.transition(from: .wrong, to: .canonical) == .recovered)
        precondition(Scoring.transition(from: .wrong, to: .wrong) == .unrecovered)
        precondition(Scoring.transition(from: .spoken, to: .spoken) == .unrecovered)
        precondition(Scoring.transition(from: .wrong, to: .spoken) == .unrecovered)
        precondition(Scoring.transition(from: .canonical, to: .wrong) == .corrupted)
        precondition(Scoring.transition(from: .spoken, to: .wrong) == .corrupted, "right words dictated, then lost")
        precondition(Scoring.transition(from: .canonical, to: .spoken) == .corrupted)

        let stages = [(name: "a", text: "section three zero two"), (name: "b", text: "Section 302"), (name: "c", text: "Section 304")]
        let result = Scoring.score(token: section302, stages: stages)
        precondition(result.states.map(\.state) == [.spoken, .canonical, .wrong])
        precondition(result.transitions.map(\.transition) == [.recovered, .corrupted])
        precondition(result.transitions[1].fromStage == "b" && result.transitions[1].toStage == "c")
    }

    // MARK: - Normalization outcomes

    private static func observed(input: String, output: String, applied: [(String, String)] = [], declined: [String] = []) -> ObservedNormalization {
        ObservedNormalization(
            input: input, output: output, applied: applied.map { .init(source: $0.0, replacement: $0.1) }, declinedSources: declined
        )
    }

    private static func kinds(_ findings: [NormalizationFinding]) -> [NormalizationOutcomeKind] { findings.map(\.kind) }

    private static func testNormalizationOutcomes() {
        let apply = LegalExpectation(kind: .apply, source: "section three zero two", replacement: "Section 302")
        let decline = LegalExpectation(kind: .decline, source: "section three zero two read with section thirty four", replacement: nil)
        let none = LegalExpectation(kind: .noCandidate, source: nil, replacement: nil)

        // correct application
        var f = NormalizationScoring.score(
            expectations: [apply],
            observed: observed(
                input: "under section three zero two now",
                output: "under Section 302 now",
                applied: [("section three zero two", "Section 302")]
            )
        )
        precondition(kinds(f) == [.correctApplication])

        // incorrect transformation: applied, wrong replacement
        f = NormalizationScoring.score(
            expectations: [apply],
            observed: observed(
                input: "under section three zero two now",
                output: "under Section 304 now",
                applied: [("section three zero two", "Section 304")]
            )
        )
        precondition(kinds(f) == [.incorrectTransformation] && f[0].kind.isSevere)

        // missed opportunity: no candidate, and explicitly declined
        f = NormalizationScoring.score(
            expectations: [apply], observed: observed(input: "under section three zero two now", output: "under section three zero two now")
        )
        precondition(kinds(f) == [.missedOpportunity] && f[0].detail.contains("no candidate"))
        f = NormalizationScoring.score(
            expectations: [apply],
            observed: observed(
                input: "under section three zero two now",
                output: "under section three zero two now",
                declined: ["section three zero two"]
            )
        )
        precondition(kinds(f) == [.missedOpportunity] && f[0].detail.contains("declined"))

        // not evaluable: ASR heard something else, so normalization is not blamed
        f = NormalizationScoring.score(
            expectations: [apply], observed: observed(input: "under sexy on three zero two", output: "under sexy on three zero two")
        )
        precondition(kinds(f) == [.notEvaluable])

        // correct decline: explicit, and preserved without an explicit decline
        let readWith = "section three zero two read with section thirty four"
        f = NormalizationScoring.score(
            expectations: [decline], observed: observed(input: readWith + " of the I P C", output: readWith + " of the I P C", declined: [readWith])
        )
        precondition(kinds(f) == [.correctDecline] && f[0].detail.contains("explicitly"))
        f = NormalizationScoring.score(
            expectations: [decline], observed: observed(input: readWith + " of the I P C", output: readWith + " of the I P C")
        )
        precondition(kinds(f) == [.correctDecline] && f[0].detail.contains("no candidate"))

        // false positive: transformed a span that must be preserved
        f = NormalizationScoring.score(
            expectations: [decline],
            observed: observed(input: readWith, output: "Section 302", applied: [(readWith, "Section 302")])
        )
        precondition(kinds(f) == [.falsePositive] && f[0].kind.isSevere)

        // false positive on ordinary text, and unexpected extra transformation beside a correct one
        f = NormalizationScoring.score(
            expectations: [none],
            observed: observed(input: "this section of the road", output: "this Section of the road", applied: [("section", "Section")]),
            dictated: "this section of the road"
        )
        precondition(kinds(f) == [.falsePositive])
        f = NormalizationScoring.score(
            expectations: [apply],
            observed: observed(
                input: "section three zero two and P W one",
                output: "Section 302 and PW-1",
                applied: [("section three zero two", "Section 302"), ("P W one", "PW-1")]
            ),
            dictated: "section three zero two and P W one"
        )
        precondition(Set(kinds(f)) == [.correctApplication, .falsePositive] && f.count == 2)

        // upstream ASR error: the normalizer faithfully normalized misheard words
        // (304 instead of the dictated 302). That is not a normalizer false positive.
        f = NormalizationScoring.score(
            expectations: [apply],
            observed: observed(
                input: "under section three zero four now",
                output: "under Section 304 now",
                applied: [("section three zero four", "Section 304")]
            ),
            dictated: "under section three zero two now"
        )
        precondition(Set(kinds(f)) == [.notEvaluable] && f.count == 2, "\(f)")

        // ordinary prose left untouched
        f = NormalizationScoring.score(expectations: [none], observed: observed(input: "the court adjourned", output: "the court adjourned"))
        precondition(kinds(f) == [.correctNoCandidate])
        // silent change without provenance
        f = NormalizationScoring.score(expectations: [none], observed: observed(input: "the court", output: "The court"))
        precondition(kinds(f) == [.incorrectTransformation])
    }

    // MARK: - Whole samples

    private static func reference(
        _ text: String, final: String? = nil, tokens: [CriticalToken] = [], expectations: [LegalExpectation]
    ) -> EvaluationReference {
        EvaluationReference(id: "t-1", category: "test", reference: text, intendedFinal: final, criticalTokens: tokens, legalExpectations: expectations)
    }

    private static func testSampleScoringOrdinaryProse() {
        let ref = reference("the court adjourned the matter", expectations: [.init(kind: .noCandidate, source: nil, replacement: nil)])
        let stages = [
            StageText(stage: EvaluationStage.postASRDeterministic, text: "the court adjourned a matter"),
            StageText(stage: EvaluationStage.legalNormalized, text: "the court adjourned a matter"),
        ]
        let score = SampleScoring.score(
            reference: ref,
            stages: stages,
            observed: ObservedNormalization(input: stages[0].text, output: stages[1].text, applied: [], declinedSources: [])
        )
        precondition(score.stageErrors[0].wer.edits == 1 && score.stageErrors[0].against == "reference")
        precondition(score.criticalTokens.isEmpty)
        precondition(score.normalization.map(\.kind) == [.correctNoCandidate])
        precondition(score.formatting == nil)
    }

    private static func testMultipleCriticalTokensInOneSample() {
        let pw1 = CriticalToken(type: .witness, expected: "PW-1", spokenForms: ["P W one"])
        let s294 = CriticalToken(type: .provision, expected: "294", spokenForms: ["two nine four"])
        let s323 = CriticalToken(type: .provision, expected: "323", spokenForms: ["three two three"])
        let ref = reference(
            "P W one said sections two nine four and three two three",
            final: "PW-1 said Sections 294 and 323",
            tokens: [pw1, s294, s323],
            expectations: [.init(kind: .apply, source: "P W one", replacement: "PW-1")]
        )
        // post-ASR right; legal step recovers PW-1, preserves nothing else, and corrupts 323 -> 328
        let stages = [
            StageText(stage: EvaluationStage.postASRDeterministic, text: "P W one said sections two nine four and three two three"),
            StageText(stage: EvaluationStage.legalNormalized, text: "PW-1 said Sections 294 and 328"),
        ]
        let score = SampleScoring.score(
            reference: ref,
            stages: stages,
            observed: ObservedNormalization( input: stages[0].text, output: stages[1].text, applied: [.init(source: "P W one", replacement: "PW-1")], declinedSources: [] )
        )
        let byExpected = Dictionary(uniqueKeysWithValues: score.criticalTokens.map { ($0.expected, $0.transitions[0].transition) })
        precondition(byExpected == ["PW-1": .recovered, "294": .recovered, "323": .corrupted], "\(byExpected)")
        precondition(score.stageErrors[1].against == "intendedFinal" && score.stageErrors[1].wer.edits == 1)
        precondition(score.formatting?.comparable == false, "328 vs 323 is a transcription difference, not formatting")
    }

    private static func testPlausibleButDifferentProvisionIsWrong() {
        // The judge dictated 302 IPC. An output that "helpfully" substitutes the
        // corresponding BNS provision, or a neighbouring one, is wrong, never credited.
        let statute = CriticalToken(type: .statute, expected: "IPC", spokenForms: ["I P C"])
        for substituted in ["Section 103 BNS", "Section 304 IPC", "Section 300 IPC"] {
            precondition(CriticalTokenScoring.state(of: section302, in: substituted) == .wrong, substituted)
        }
        precondition(CriticalTokenScoring.state(of: statute, in: "Section 103 BNS") == .wrong)
        let ref = reference(
            "under section three zero two of the I P C",
            final: "under Section 302 IPC",
            tokens: [section302, statute],
            expectations: [.init(kind: .apply, source: "section three zero two of the I P C", replacement: "Section 302 IPC")]
        )
        let stages = [
            StageText(stage: EvaluationStage.postASRDeterministic, text: "under section three zero two of the I P C"),
            StageText(stage: EvaluationStage.legalNormalized, text: "under Section 103 BNS"),
        ]
        let score = SampleScoring.score(
            reference: ref,
            stages: stages,
            observed: ObservedNormalization( input: stages[0].text, output: stages[1].text, applied: [.init(source: "section three zero two of the I P C", replacement: "Section 103 BNS")], declinedSources: [] )
        )
        precondition(score.criticalTokens.allSatisfy { $0.transitions[0].transition == .corrupted })
        precondition(score.normalization.map(\.kind) == [.incorrectTransformation])
    }

    // MARK: - References

    private static func testReferenceValidation() {
        let good = reference("under section three zero two", expectations: [.init(kind: .apply, source: "section three zero two", replacement: "Section 302")])
        precondition(good.validate().isEmpty)
        let cases: [(EvaluationReference, String)] = [
            (reference("x", expectations: []), "legalExpectations must be explicit"),
            (reference("x", expectations: [.init(kind: .apply, source: "x", replacement: nil)]), "needs source and replacement"),
            (reference("hello", expectations: [.init(kind: .decline, source: "absent", replacement: nil)]), "does not occur"),
            (reference("x", expectations: [.init(kind: .noCandidate, source: nil, replacement: nil), .init(kind: .decline, source: "x", replacement: nil)]), "cannot be combined"),
            (reference("", expectations: [.init(kind: .noCandidate, source: nil, replacement: nil)]), "reference is empty"),
            (reference("x", tokens: [CriticalToken(type: .date, expected: "")], expectations: [.init(kind: .noCandidate, source: nil, replacement: nil)]), "empty expected"),
        ]
        for (ref, expected) in cases {
            precondition(ref.validate().contains { $0.contains(expected) }, "expected problem '\(expected)' in \(ref.validate())")
        }
        let badID = EvaluationReference(id: "bad id!", category: "c", reference: "x", legalExpectations: [.init(kind: .noCandidate, source: nil, replacement: nil)])
        precondition(badID.validate().contains { $0.contains("id must match") })
    }

    private static func testReferenceJSONRoundTrip() {
        let json = """
        {"schemaVersion":1,"id":"rt-1","tier":"synthetic","category":"c","reference":"x y",
         "criticalTokens":[{"type":"provision","expected":"302"}],
         "legalExpectations":[{"kind":"noCandidate"}]}
        """
        guard let decoded = try? JSONDecoder().decode(EvaluationReference.self, from: Data(json.utf8)) else {
            preconditionFailure("minimal reference must decode (tags/spokenForms/intendedFinal/notes optional)")
        }
        precondition(decoded.tags.isEmpty && decoded.criticalTokens[0].spokenForms.isEmpty && decoded.intendedFinal == nil)
        precondition(decoded.validate().isEmpty)
        let data = try? JSONEncoder().encode(decoded)
        precondition(data.flatMap { try? JSONDecoder().decode(EvaluationReference.self, from: $0) } == decoded)
    }
}
