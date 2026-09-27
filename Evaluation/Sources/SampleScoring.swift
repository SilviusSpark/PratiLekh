import Foundation

enum EvaluationStage {
    /// Phase 3G.A, observability only: the transcription provider's own
    /// returned text, captured before filler removal, custom dictionary and
    /// spoken-punctuation formatting. Only available when audio was
    /// transcribed via the Local API (absent for `--text-dir` runs, where no
    /// provider was invoked). NOT raw acoustic/model output -- providers may
    /// already perform their own internal formatting before returning this
    /// string. Precedes `postASRDeterministic` in the pipeline, but is
    /// reported as its own field on `SampleRunRecord` (see RunReport.swift),
    /// not as an entry in the scored `stages` list, so it does not shift the
    /// positional reference/intendedFinal comparison `SampleScoring.score`
    /// performs over `stages`.
    static let providerTranscript = "providerTranscript"
    /// `/v1/transcribe` output: provider text after filler removal, custom
    /// dictionary and spoken punctuation. NOT raw provider recognition.
    static let postASRDeterministic = "postASRDeterministic"
    static let legalNormalized = "legalNormalized"
}

struct StageText: Codable, Equatable {
    let stage: String
    let text: String
}

struct StageErrorScore: Codable, Equatable {
    let stage: String
    /// "reference" (as dictated) or "intendedFinal".
    let against: String
    let wer: ErrorRate
    let cer: ErrorRate
}

/// Separate measures only; there is deliberately no blended score.
struct SampleScore: Codable, Equatable {
    let id: String
    let stageErrors: [StageErrorScore]
    let criticalTokens: [CriticalTokenResult]
    let normalization: [NormalizationFinding]
    let formatting: FormattingScore?
}

enum SampleScoring {
    /// `stages` are in pipeline order. The first stage is measured against the
    /// dictated `reference`; later stages against `intendedFinal` when given.
    static func score(reference: EvaluationReference, stages: [StageText], observed: ObservedNormalization?) -> SampleScore {
        var stageErrors: [StageErrorScore] = []
        for (index, stage) in stages.enumerated() {
            let usesIntended = index > 0 && reference.intendedFinal != nil
            let target = usesIntended ? (reference.intendedFinal ?? reference.reference) : reference.reference
            stageErrors.append(StageErrorScore(
                stage: stage.stage,
                against: usesIntended ? "intendedFinal" : "reference",
                wer: TextMetrics.wer(reference: target, hypothesis: stage.text),
                cer: TextMetrics.cer(reference: target, hypothesis: stage.text)
            ))
        }

        let named = stages.map { (name: $0.stage, text: $0.text) }
        let tokens = reference.criticalTokens.map { CriticalTokenScoring.score(token: $0, stages: named) }
        let normalization = observed.map { NormalizationScoring.score(expectations: reference.legalExpectations, observed: $0, dictated: reference.reference) } ?? []

        var formatting: FormattingScore?
        if let intended = reference.intendedFinal, let last = stages.last, stages.count > 1 {
            formatting = FormattingMetrics.score(intended: intended, actual: last.text)
        }
        return SampleScore(id: reference.id, stageErrors: stageErrors, criticalTokens: tokens, normalization: normalization, formatting: formatting)
    }
}
