import Foundation

/// The provenance Phase 1 actually needs: the untouched recognizer input, the
/// text after normalization, and what happened along the way. No separate
/// staged-text wrapper or reserved future-stage cases -- those are added when
/// AI and final-output provenance actually exist (Phase 7 and beyond).
struct NormalizationOutcome: Equatable {
    let recognized: String
    let normalized: String
    let appliedChanges: [AppliedNormalizationChange]
    let declinedChanges: [DeclinedNormalization]

    var isUnchanged: Bool {
        appliedChanges.isEmpty && declinedChanges.isEmpty
    }
}

/// Composes a sequence of normalizers over one piece of text. Phase 1 runs
/// exactly one (`LookupTableNormalizer`); Phase 3 adds more to the same list
/// without this type needing to change. Applied and declined changes
/// accumulate across the whole pipeline -- one normalizer's (or one
/// trigger's) decline never prevents another's clean application.
enum LegalNormalizationPipeline {
    static func run(
        recognizedText: String,
        table: ResolvedNormalizationTable,
        normalizers: [LegalNormalizer] = [LookupTableNormalizer()]
    ) -> NormalizationOutcome {
        var currentText = recognizedText
        var applied: [AppliedNormalizationChange] = []
        var declined: [DeclinedNormalization] = []

        for normalizer in normalizers {
            let result = normalizer.normalize(currentText, using: table)
            currentText = result.text
            applied.append(contentsOf: result.appliedChanges)
            declined.append(contentsOf: result.declinedChanges)
        }

        return NormalizationOutcome(
            recognized: recognizedText,
            normalized: currentText,
            appliedChanges: applied,
            declinedChanges: declined
        )
    }
}
