import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// The deterministic, model/provider-independent core: preprocessing (legal
/// normalization + V1.11 protected-span derivation + V1.13 numeric
/// structural protection) and evaluation (the existing, unmodified
/// `IntelligenceEditComposition` / `IntelligenceSafetyAuthority` chain).
///
/// Deliberately has **no dependency on `LLMClient`** -- it is compiled and
/// exercised on its own by `scripts/test_intelligence_harness.sh` against
/// hand-written fixtures, so the harness's own plumbing can be proven correct
/// without a model, a network call, or even `LLMClient` being present in the
/// build. `IntelligenceHarnessRunner` (a separate file, compiled only by
/// `scripts/intelligence_harness_run.sh`, which does link `LLMClient`) is the
/// only place a real provider is ever called; it bridges a real
/// `LLMClient.Response` into the same `IntelligenceProviderResponse` this
/// file consumes, so one code path serves both fixtures and live runs.

/// A plain, human-readable failure reason -- used instead of the chain's own
/// typed failures so this file can report any of several unrelated typed
/// errors (`ProtectedSpanDerivationFailure`, `ModelFacingAdapterFailure`)
/// uniformly, via `String(describing:)` over the real value. Never
/// interpreted programmatically; always rendered verbatim for a human.
struct IntelligenceHarnessFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

enum IntelligenceHarnessPipeline {
    /// Legal normalization + protected-span derivation for one raw input.
    /// Mirrors `Evaluation/Runner/EvalRunner.swift`'s own use of
    /// `LegalDictationProcessor`/`ProtectedSpanDerivation` exactly -- this is
    /// not a new preprocessing path, just the existing one reused here.
    struct Preflight {
        let normalizedText: String
        let protectedSpans: [ProtectedSpan]
    }

    static func preflight(rawInputText: String, processor: LegalDictationProcessor) -> Result<Preflight, IntelligenceHarnessFailure> {
        let outcome = processor.process(rawInputText)
        switch ProtectedSpanDerivation.derive(from: outcome) {
        case let .success(spans):
            return .success(Preflight(normalizedText: outcome.normalized, protectedSpans: spans.spansIncludingNumericStructure))
        case let .failure(failure):
            return .failure(IntelligenceHarnessFailure("protected-span derivation failed: \(failure)"))
        }
    }

    /// Runs one already-obtained provider response through the existing,
    /// unmodified composition/Safety Authority chain and shapes the result
    /// for adjudication. This function never calls a model and never
    /// mutates `normalizedText` -- `wouldBeOutput` is a value computed from
    /// `result.accepted`, not a live edit.
    static func evaluate(
        response: IntelligenceProviderResponse,
        normalizedText: String,
        protectedSpans: [ProtectedSpan]
    ) -> Result<IntelligenceHarnessEvaluatedSample, IntelligenceHarnessFailure> {
        switch IntelligenceEditComposition.evaluate(response: response, source: normalizedText, protectedSpans: protectedSpans) {
        case let .failure(failure):
            return .failure(IntelligenceHarnessFailure("whole-response rejected: \(failure)"))
        case let .success(result):
            let records = result.edits.enumerated().map { offset, composed -> IntelligenceHarnessEditRecord in
                let (addressingSummary, dispositionSummary, bucket) = self.summarize(composed)
                return IntelligenceHarnessEditRecord(
                    position: offset + 1,
                    id: composed.id,
                    modelEdit: composed.edit,
                    addressingSummary: addressingSummary,
                    dispositionSummary: dispositionSummary,
                    bucket: bucket
                )
            }
            return .success(IntelligenceHarnessEvaluatedSample(
                schemaVersion: result.schemaVersion,
                edits: records,
                wouldBeOutput: self.applyAccepted(result.accepted, to: normalizedText)
            ))
        }
    }

    private static func summarize(_ composed: IntelligenceComposedEdit) -> (addressing: String, disposition: String, bucket: IntelligenceHarnessBucket) {
        switch composed.stage {
        case let .addressingRejected(reason):
            return ("rejected: \(reason)", "addressingRejected", .addressingRejected)
        case let .evaluated(_, basis, disposition):
            let addressing = "resolved (basis: \(basis))"
            switch disposition {
            case .autonomouslyAccepted:
                return (addressing, "\(disposition)", .autonomouslyAccepted)
            case .reviewOnly:
                return (addressing, "\(disposition)", .reviewOnly)
            case .rejected:
                return (addressing, "\(disposition)", .rejectedBySafetyAuthority)
            }
        }
    }

    /// Replays only `.autonomouslyAccepted` edits, right-to-left by source
    /// range, over the immutable `source`. Mirrors
    /// `IntelligenceSafetyAuthority`'s own (already-tested)
    /// `applyAcceptedEdits` algorithm, duplicated here deliberately rather
    /// than changing `IntelligenceEditComposition`'s public shape to expose
    /// its discarded `resultingText`: `accepted` edits are already
    /// guaranteed pairwise non-overlapping by the Authority itself (any
    /// overlapping pair is rejected together, regardless of classification),
    /// so this replay is a direct, conflict-free splice -- not new policy.
    private static func applyAccepted(_ accepted: [IntelligenceComposedEdit], to source: String) -> String {
        let ordered = accepted.compactMap(\.proposal).sorted { $0.range.location > $1.range.location }
        var text = source
        for proposal in ordered {
            guard let range = Range(proposal.range, in: text) else { continue }
            text.replaceSubrange(range, with: proposal.replacementText)
        }
        return text
    }
}
