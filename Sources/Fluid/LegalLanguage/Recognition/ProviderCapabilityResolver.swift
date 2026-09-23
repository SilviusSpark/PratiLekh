import Foundation

/// A PratiLekh-side, name-keyed lookup from a provider's reported `name` to
/// its recognition capability. Chosen deliberately over adding a capability
/// requirement to the `TranscriptionProvider` protocol (which would touch
/// that protocol and every conforming provider file) -- see the Phase 1
/// implementation report for the full rationale.
///
/// Every key below was verified directly against the real `name` property
/// declared in each provider's source file (not guessed), as of this Phase 1
/// hardening pass:
///   - WhisperProvider.swift:6            `let name = "Whisper (Universal)"`
///   - FluidAudioProvider.swift:25        `let name = "FluidAudio (Apple Silicon Optimized)"` (#if arch(arm64))
///   - FluidAudioProvider.swift:802       `let name = "FluidAudio (Apple Silicon ONLY)"` (#else stub, isAvailable == false)
///   - ParakeetRealtimeProvider.swift:9   `let name = "Parakeet Flash (FluidAudio)"` (#if arch(arm64))
///   - NemotronProvider.swift:34          `var name: String { self.mode.displayName }` ->
///                                        "Nemotron 3.5 Multilingual" (.offline) or
///                                        "Nemotron Speech 3.5 - Ultra Fast Low Latency" (.streaming/.streaming320)
///   - ExternalCoreMLTranscriptionProvider.swift:8  `let name = "External CoreML"`
///   - AppleSpeechProvider.swift:10        `var name: String { "Apple Speech (Legacy)" }`
///   - AppleSpeechAnalyzerProvider.swift:15 `var name: String { "Apple Speech (macOS 26+)" }`
///
/// Of these, only `FluidAudioProvider`'s real (arm64) implementation has a
/// *confirmed* recognition-hint mechanism today: it loads
/// `ParakeetVocabularyStore` and calls `AsrManager.configureVocabularyBoosting`
/// (see `FluidAudioProvider.swift` around its manager-initialization code).
/// No other provider file shows any evidence of prompt injection or term
/// boosting -- in particular, `WhisperProvider.swift` has no "prompt"
/// reference at all, and `ParakeetRealtimeProvider.swift` has no
/// "vocabulary"/"boost" reference at all. Rather than assume a shape for
/// those (e.g. a Whisper initial-prompt capability), they are intentionally
/// left out of this table and fall through to the safe `.none` default. Add
/// them here only once a concrete mechanism exists in their source.
enum ProviderCapabilityResolver {
    private static let knownCapabilities: [String: ProviderRecognitionCapability] = [
        "FluidAudio (Apple Silicon Optimized)": .weightedTermList(
            limits: ProviderVocabularyLimits(maxTerms: 256, maxPromptLength: nil)
        ),
    ]

    static func capability(forProviderNamed name: String) -> ProviderRecognitionCapability {
        knownCapabilities[name] ?? .none
    }
}
