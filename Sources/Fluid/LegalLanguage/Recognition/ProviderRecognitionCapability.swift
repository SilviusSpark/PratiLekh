import Foundation

/// Limits are supplied by whichever provider is active -- never hardcoded
/// into the domain model above this layer. A 256-term cap (today's Parakeet
/// reality) is just a value that happens to flow through here; nothing in
/// `Packs/` or `Resolution/` knows it exists.
struct ProviderVocabularyLimits: Equatable {
    let maxTerms: Int?
    let maxPromptLength: Int?
}

/// What kind of recognition assistance a `TranscriptionProvider` can accept.
/// Modeled by capability shape, not by provider identity, so the domain layer
/// never needs to know which specific engine is active.
enum ProviderRecognitionCapability: Equatable {
    case none
    case weightedTermList(limits: ProviderVocabularyLimits)
    case promptString(limits: ProviderVocabularyLimits)
}

struct WeightedRecognitionTerm: Equatable {
    let text: String
    let aliases: [String]
}

/// The adapted result, ready to be handed to a provider. Phase 1 stops at
/// producing this value -- no provider file is ever handed one yet.
enum ProviderRecognitionHint: Equatable {
    case none
    case terms([WeightedRecognitionTerm])
    case prompt(String)
}
