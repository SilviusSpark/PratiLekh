import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// Runs the frozen corpus through the **real, unmodified V1.17 harness chain**
/// (`IntelligenceHarnessPipeline.preflight`/`.evaluate`), with the model call abstracted behind
/// an injected `CapabilityProposer` so this file has no `LLMClient` dependency and can be
/// exercised with deterministic stand-ins (never a model).
///
/// Frozen methodology enforced structurally, not by convention:
///   - strictly sequential, corpus order, exactly one proposer call per entry, never more --
///     there is no retry loop anywhere in this file;
///   - a provider failure is recorded as that entry's outcome and the run continues; the
///     failed entry is never re-attempted;
///   - a preflight failure means the proposer is never called for that entry.
typealias CapabilityProposer = (_ legalNormalizedText: String) async -> Result<IntelligenceProviderResponse, IntelligenceHarnessFailure>

struct CapabilityTrial {
    let report: IntelligenceHarnessSampleReport
    let adjudication: CapabilityEntryAdjudication
}

enum CapabilityEvaluationDriver {
    static func run(corpus: CapabilityCorpus, processor: LegalDictationProcessor, proposer: CapabilityProposer) async -> [CapabilityTrial] {
        var trials: [CapabilityTrial] = []
        for entry in corpus.entries {
            let report = await self.evaluateOne(entry: entry, processor: processor, proposer: proposer)
            trials.append(CapabilityTrial(report: report, adjudication: CapabilityAdjudicator.adjudicate(entry: entry, outcome: report.outcome)))
        }
        return trials
    }

    /// Preflight only (legal normalization + protected-span derivation) for every entry. No proposer.
    static func preflightAll(corpus: CapabilityCorpus, processor: LegalDictationProcessor) -> [(entryID: String, result: Result<IntelligenceHarnessPipeline.Preflight, IntelligenceHarnessFailure>)] {
        corpus.entries.map { ($0.id, IntelligenceHarnessPipeline.preflight(rawInputText: $0.text, processor: processor)) }
    }

    private static func evaluateOne(entry: CapabilityCorpus.Entry, processor: LegalDictationProcessor, proposer: CapabilityProposer) async -> IntelligenceHarnessSampleReport {
        func report(normalized: String?, response: IntelligenceProviderResponse?, outcome: IntelligenceHarnessSampleOutcome) -> IntelligenceHarnessSampleReport {
            IntelligenceHarnessSampleReport(
                sampleID: entry.id,
                tier: entry.tier,
                rawInputText: entry.text,
                legalNormalizedText: normalized,
                modelTextContent: response?.textContent,
                modelRawToolCallArguments: response?.toolCalls.map(\.rawArguments) ?? [],
                outcome: outcome
            )
        }
        switch IntelligenceHarnessPipeline.preflight(rawInputText: entry.text, processor: processor) {
        case let .failure(reason):
            return report(normalized: nil, response: nil, outcome: .preflightFailure(reason.description))
        case let .success(pre):
            switch await proposer(pre.normalizedText) { // the one and only attempt for this entry
            case let .failure(reason):
                return report(normalized: pre.normalizedText, response: nil, outcome: .providerFailure(reason.description))
            case let .success(response):
                switch IntelligenceHarnessPipeline.evaluate(response: response, normalizedText: pre.normalizedText, protectedSpans: pre.protectedSpans) {
                case let .failure(reason): return report(normalized: pre.normalizedText, response: response, outcome: .wholeResponseRejected(reason.description))
                case let .success(sample): return report(normalized: pre.normalizedText, response: response, outcome: .evaluated(sample))
                }
            }
        }
    }
}
