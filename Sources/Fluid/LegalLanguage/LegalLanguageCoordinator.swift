import Foundation

/// The single facade this module exposes. Nothing outside `LegalLanguage/`
/// should need to know about packs, resolvers, or adapters directly -- that
/// is the point of keeping this seam narrow for whichever later phase wires
/// it into the live transcription pipeline (not done in Phase 1).
final class LegalLanguageCoordinator {
    private let repository: PackRepository

    init(repository: PackRepository) {
        self.repository = repository
    }

    func recognitionHint(forProviderNamed providerName: String) -> ProviderRecognitionHint {
        let vocabulary = PrecedenceResolver.resolveRecognitionVocabulary(from: repository.packs)
        let capability = ProviderCapabilityResolver.capability(forProviderNamed: providerName)
        let adapter = RecognitionAdapterSelector.adapter(for: capability)
        return adapter.adapt(vocabulary, capability: capability)
    }

    func normalize(_ recognizedText: String) -> NormalizationOutcome {
        let table = PrecedenceResolver.resolveNormalizationTable(from: repository.packs)
        return LegalNormalizationPipeline.run(recognizedText: recognizedText, table: table)
    }
}
