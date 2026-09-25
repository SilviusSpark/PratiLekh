import Foundation

/// Phase 1's only normalizer: exact-substring trigger replacement, generalizing
/// what `SettingsStore.CustomDictionaryEntry` already does today, now sourced
/// from resolved pack data instead of a single flat list.
///
/// Each resolved-table entry is evaluated independently against the original
/// input text: a cleanly resolved match is applied; a conflicted match is
/// left untouched in the output and recorded as declined. An unrelated
/// conflict elsewhere in the text never blocks an otherwise-safe
/// transformation -- one call's result can legitimately contain both applied
/// and declined entries (see `NormalizationPassResult`).
///
/// Known Phase 1 limitation, documented rather than solved: trigger matching
/// is plain substring search with no tokenization, so overlapping triggers
/// (e.g. "IPC" and "Section 302 IPC" both present in the same table) can
/// interact in ways this simple pass does not reason about. Phase 3's rule
/// engine is expected to replace this matching strategy when real,
/// potentially-overlapping legal vocabulary is seeded.
struct LookupTableNormalizer: LegalNormalizer {
    func normalize(_ text: String, using context: NormalizationContext) -> NormalizationPassResult {
        guard let table = context.resolvedTable else {
            return NormalizationPassResult(text: text, appliedChanges: [], declinedChanges: [])
        }
        var updatedText = text
        var applied: [AppliedNormalizationChange] = []
        var declined: [DeclinedNormalization] = []

        // Applicability is checked against the original `text`, not the
        // running `updatedText`, so one entry's replacement can never change
        // whether a later entry is considered a match in this same pass.
        for entry in table.entries where text.contains(entry.trigger) {
            switch entry.resolution {
            case let .resolved(replacement, packID):
                updatedText = updatedText.replacingOccurrences(of: entry.trigger, with: replacement)
                applied.append(
                    AppliedNormalizationChange(trigger: entry.trigger, replacement: replacement, sourcePackID: packID)
                )
            case let .conflicted(candidates):
                declined.append(
                    DeclinedNormalization(
                        trigger: entry.trigger,
                        candidates: candidates,
                        reason: "Conflicting normalization for trigger '\(entry.trigger)'"
                    )
                )
            }
        }

        return NormalizationPassResult(text: updatedText, appliedChanges: applied, declinedChanges: declined)
    }
}
