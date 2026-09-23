import Foundation

@main
enum RecognitionVocabularyAdapterTests {
    static func main() {
        testCapabilityResolverKnownAndUnknownNames()
        testWeightedTermListAdapterTruncatesInPrecedenceOrder()
        testPromptStringAdapterTruncatesToMaxLength()
        testNoOpAdapterAndNoneCapabilityProduceNoHint()
        print("PASS: provider capability resolution and recognition vocabulary adapters")
    }

    private static func vocabulary(_ canonicals: [String]) -> ResolvedRecognitionVocabulary {
        ResolvedRecognitionVocabulary(
            entries: canonicals.map { ResolvedRecognitionEntry(canonical: $0, aliases: [], sourcePackIDs: ["fixture"]) }
        )
    }

    private static func testCapabilityResolverKnownAndUnknownNames() {
        // "FluidAudio (Apple Silicon Optimized)" is the one provider with a
        // confirmed recognition-hint mechanism (ParakeetVocabularyStore +
        // AsrManager.configureVocabularyBoosting) as of this Phase 1
        // hardening pass -- see ProviderCapabilityResolver's doc comment.
        guard case let .weightedTermList(limits) = ProviderCapabilityResolver.capability(
            forProviderNamed: "FluidAudio (Apple Silicon Optimized)"
        ) else {
            preconditionFailure("Expected the real FluidAudio provider name to resolve to a weighted term list capability")
        }
        precondition(limits.maxTerms == 256, "Must match ParakeetVocabularyStore.Defaults.maxTerms exactly")

        // Every other real, currently-existing provider name has no confirmed
        // recognition-hint mechanism in this codebase and must safely default
        // to .none -- not be guessed at.
        for realButUnmappedName in [
            "Whisper (Universal)",
            "Parakeet Flash (FluidAudio)",
            "External CoreML",
            "Apple Speech (Legacy)",
            "Apple Speech (macOS 26+)",
            "Nemotron 3.5 Multilingual",
            "Nemotron Speech 3.5 - Ultra Fast Low Latency",
        ] {
            precondition(
                ProviderCapabilityResolver.capability(forProviderNamed: realButUnmappedName) == .none,
                "'\(realButUnmappedName)' has no confirmed hint mechanism and must resolve to .none"
            )
        }

        precondition(
            ProviderCapabilityResolver.capability(forProviderNamed: "Some Future Engine") == .none,
            "Unrecognized provider names must safely default to .none"
        )
    }

    private static func testWeightedTermListAdapterTruncatesInPrecedenceOrder() {
        let vocab = vocabulary(["one", "two", "three", "four"])
        let capability = ProviderRecognitionCapability.weightedTermList(
            limits: ProviderVocabularyLimits(maxTerms: 2, maxPromptLength: nil)
        )
        let hint = WeightedTermListAdapter().adapt(vocab, capability: capability)
        guard case let .terms(terms) = hint else {
            preconditionFailure("Expected .terms")
        }
        precondition(terms.map(\.text) == ["one", "two"], "Must keep the first N entries in resolver precedence order, not reorder")
    }

    private static func testPromptStringAdapterTruncatesToMaxLength() {
        // This exercises the adapter's own logic directly against a
        // constructed .promptString capability -- it is not a claim that any
        // current provider actually has this capability (none do; see
        // ProviderCapabilityResolver).
        let vocab = vocabulary(["alpha", "beta", "gamma"])
        let capability = ProviderRecognitionCapability.promptString(
            limits: ProviderVocabularyLimits(maxTerms: nil, maxPromptLength: 10)
        )
        let hint = PromptStringAdapter().adapt(vocab, capability: capability)
        guard case let .prompt(text) = hint else {
            preconditionFailure("Expected .prompt")
        }
        precondition(text.count == 10, "Prompt must be truncated to the provider's max length")

        let unbounded = PromptStringAdapter().adapt(
            vocab,
            capability: .promptString(limits: ProviderVocabularyLimits(maxTerms: nil, maxPromptLength: nil))
        )
        guard case let .prompt(fullText) = unbounded else {
            preconditionFailure("Expected .prompt")
        }
        precondition(fullText == "alpha, beta, gamma")
    }

    private static func testNoOpAdapterAndNoneCapabilityProduceNoHint() {
        let vocab = vocabulary(["anything"])
        precondition(NoOpAdapter().adapt(vocab, capability: .none) == .none)

        // Mismatched adapter/capability pairing must also degrade safely to .none,
        // never crash or fabricate a hint.
        precondition(WeightedTermListAdapter().adapt(vocab, capability: .none) == .none)
        precondition(PromptStringAdapter().adapt(vocab, capability: .none) == .none)
    }
}
