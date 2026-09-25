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

    /// Runs the table-driven normalizer (Phase 1/2) followed by Phase 3's
    /// structured rules, in that fixed order. This is coordinator-level
    /// composition only -- nothing outside this class calls it, and it is
    /// not wired into `ASRService` or any live transcription path.
    func normalize(_ recognizedText: String) -> NormalizationOutcome {
        let context = NormalizationContext(
            resolvedTable: PrecedenceResolver.resolveNormalizationTable(from: repository.packs),
            resolvedRecognitionVocabulary: PrecedenceResolver.resolveRecognitionVocabulary(from: repository.packs)
        )
        return LegalNormalizationPipeline.run(
            recognizedText: recognizedText,
            context: context,
            normalizers: [LookupTableNormalizer(), StatutoryProvisionNormalizer(), WitnessReferenceNormalizer()]
        )
    }
}
