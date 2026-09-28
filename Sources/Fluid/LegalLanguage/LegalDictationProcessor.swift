import Foundation

/// The production-facing entry point for PratiLekh's deterministic legal
/// normalization of finalized dictation. It only owns pack loading and the
/// `LegalLanguageCoordinator`; all rules, pack resolution and provenance
/// live in the Phase 1-3 types it delegates to.
///
/// It expects text that has already been through the deterministic
/// ASR/dictation formatting stages and is about to be handed to optional AI
/// post-processing. It is not used for streaming preview.
final class LegalDictationProcessor {
    /// Process-wide instance backed by the bundled Indian Legal Core. If the
    /// pack cannot be loaded the processor still runs with no packs: rules
    /// that need statute vocabulary decline to match, and ordinary text is
    /// left unchanged.
    static let shared = LegalDictationProcessor(builtinPack: BuiltInPacks.indianLegalCore())

    private let coordinator: LegalLanguageCoordinator

    init(builtinPack: LanguagePack?) {
        self.coordinator = LegalLanguageCoordinator(
            repository: PackRepository(packs: builtinPack.map { [$0] } ?? [])
        )
    }

    /// Returns the normalized text together with the applied/declined
    /// provenance. Each change's `range` indexes the input of the pass/step
    /// that produced it (see the coordinate contract in `LegalNormalizer.swift`).
    func process(_ text: String) -> NormalizationOutcome {
        coordinator.normalize(text)
    }
}

extension NormalizationOutcome {
    /// True when an applied legal normalization produced the text that now
    /// begins `text`, so a later presentation formatter (GAAV lowercasing,
    /// context-aware capitalization) must not lowercase its first character.
    ///
    /// Derived from provenance only: an applied change whose source span
    /// starts at the first non-whitespace position of this pass's input.
    /// Such a change necessarily produced the output's leading text, so its
    /// `replacement` is checked against `text` (which may have been through
    /// AI since). Text that merely *looks* canonical, with no applied change,
    /// is never protected.
    func protectsLeadingCapitalization(of text: String) -> Bool {
        let leadingWhitespace = normalized.prefix { $0.isWhitespace }.utf16.count
        // Structured Phase 3 rules only: lookup-table replacements (which had
        // no range before V1.10 and so never matched here) are deliberately
        // still excluded, preserving this presentation rule's behavior exactly.
        guard let leading = appliedChanges.last(where: { $0.pass != .lookupTable && $0.range.location == leadingWhitespace }) else {
            return false
        }
        return text.drop { $0.isWhitespace }.hasPrefix(leading.replacement)
    }
}
