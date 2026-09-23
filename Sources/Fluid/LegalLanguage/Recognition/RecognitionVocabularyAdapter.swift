import Foundation

/// Translates resolved recognition vocabulary into whatever shape a specific
/// provider capability needs. One adapter per capability *shape*, not per
/// named engine -- so a future provider with, say, a weighted-term-list
/// capability reuses `WeightedTermListAdapter` without new code.
protocol RecognitionVocabularyAdapter {
    func adapt(_ vocabulary: ResolvedRecognitionVocabulary, capability: ProviderRecognitionCapability) -> ProviderRecognitionHint
}

struct NoOpAdapter: RecognitionVocabularyAdapter {
    func adapt(_ vocabulary: ResolvedRecognitionVocabulary, capability: ProviderRecognitionCapability) -> ProviderRecognitionHint {
        .none
    }
}

struct WeightedTermListAdapter: RecognitionVocabularyAdapter {
    func adapt(_ vocabulary: ResolvedRecognitionVocabulary, capability: ProviderRecognitionCapability) -> ProviderRecognitionHint {
        guard case let .weightedTermList(limits) = capability else { return .none }
        let entries = limits.maxTerms.map { Array(vocabulary.entries.prefix($0)) } ?? vocabulary.entries
        return .terms(entries.map { WeightedRecognitionTerm(text: $0.canonical, aliases: $0.aliases) })
    }
}

struct PromptStringAdapter: RecognitionVocabularyAdapter {
    func adapt(_ vocabulary: ResolvedRecognitionVocabulary, capability: ProviderRecognitionCapability) -> ProviderRecognitionHint {
        guard case let .promptString(limits) = capability else { return .none }
        let joined = vocabulary.entries.map(\.canonical).joined(separator: ", ")
        guard let maxLength = limits.maxPromptLength, joined.count > maxLength else {
            return .prompt(joined)
        }
        return .prompt(String(joined.prefix(maxLength)))
    }
}

enum RecognitionAdapterSelector {
    static func adapter(for capability: ProviderRecognitionCapability) -> RecognitionVocabularyAdapter {
        switch capability {
        case .none:
            return NoOpAdapter()
        case .weightedTermList:
            return WeightedTermListAdapter()
        case .promptString:
            return PromptStringAdapter()
        }
    }
}
