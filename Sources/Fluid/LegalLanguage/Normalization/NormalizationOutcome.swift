import Foundation

/// The provenance normalization records: the untouched recognizer input, the
/// text after normalization, the passes that ran (in order), and what happened
/// along the way. Intermediate texts are deliberately not stored: `recognized`
/// plus the records and `passes` reconstruct every one of them exactly (see the
/// coordinate contract in `LegalNormalizer.swift` and `NormalizationReplay`).
///
/// `appliedChanges`/`declinedChanges` list records pass by pass in `passes`
/// order. Each record carries its own typed `pass`, `step` and `range`, so the
/// flat lists lose no information.
struct NormalizationOutcome: Equatable {
    let recognized: String
    let normalized: String
    /// The normalizers that ran, in order (including any that changed nothing).
    let passes: [NormalizationPassID]
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
        context: NormalizationContext,
        normalizers: [LegalNormalizer] = [LookupTableNormalizer()]
    ) -> NormalizationOutcome {
        var currentText = recognizedText
        var passes: [NormalizationPassID] = []
        var applied: [AppliedNormalizationChange] = []
        var declined: [DeclinedNormalization] = []

        for normalizer in normalizers {
            // Pass identity must be unambiguous: a pipeline configuration
            // error (two normalizers sharing an id), not a runtime condition.
            precondition(!passes.contains(normalizer.passID), "duplicate normalization pass id \(normalizer.passID)")
            passes.append(normalizer.passID)
            let result = normalizer.normalize(currentText, using: context)
            currentText = result.text
            applied.append(contentsOf: result.appliedChanges)
            declined.append(contentsOf: result.declinedChanges)
        }

        return NormalizationOutcome(
            recognized: recognizedText,
            normalized: currentText,
            passes: passes,
            appliedChanges: applied,
            declinedChanges: declined
        )
    }
}
