import Foundation

/// Phase 1's only normalizer: exact-substring trigger replacement, generalizing
/// what `SettingsStore.CustomDictionaryEntry` already does today, now sourced
/// from resolved pack data instead of a single flat list.
///
/// Each resolved-table entry is one sequential *step* (`step` = the entry's
/// index in the table). A cleanly resolved entry replaces every occurrence of
/// its trigger in the running text; a conflicted entry leaves its occurrences
/// untouched and records them as declined. An unrelated conflict elsewhere in
/// the text never blocks an otherwise-safe transformation -- one call's result
/// can legitimately contain both applied and declined entries (see
/// `NormalizationPassResult`).
///
/// Provenance (V1.10): every occurrence is recorded individually, located by
/// its exact UTF-16 range in that step's input -- the running text as left by
/// the previous entries (see the coordinate contract in `LegalNormalizer.swift`).
/// Locations are found directly, never inferred later, and the output text is
/// built from those same located occurrences, so provenance and text agree by
/// construction.
///
/// Behavior preserved exactly from the pre-V1.10 implementation: entries are
/// applied in table order, each against the text left by the previous entries;
/// an entry is considered only if its trigger occurs in the ORIGINAL input
/// (`text.contains`); occurrences are found with the same comparison
/// `String.replacingOccurrences(of:with:)` uses (non-literal, so canonically
/// equivalent forms match), non-overlapping, left to right. Two documented
/// provenance refinements follow from making records per-occurrence:
///   - an entry that passes the original-input check but whose trigger no
///     longer occurs in the running text (an earlier entry consumed it) now
///     records nothing, where it previously recorded a phantom aggregate
///     change (text output is unchanged either way);
///   - `trigger` is the exact matched text, which can differ from the table's
///     trigger only when the match was a canonically-equivalent form.
///
/// Known Phase 1 limitation, documented rather than solved: trigger matching
/// is plain substring search with no tokenization, so overlapping triggers
/// (e.g. "IPC" and "Section 302 IPC" both present in the same table) can
/// interact in ways this simple pass does not reason about. Phase 3's rule
/// engine is expected to replace this matching strategy when real,
/// potentially-overlapping legal vocabulary is seeded.
struct LookupTableNormalizer: LegalNormalizer {
    var passID: NormalizationPassID { .lookupTable }

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
        for (step, entry) in table.entries.enumerated() where text.contains(entry.trigger) {
            let input = updatedText as NSString
            let occurrences = Self.occurrences(of: entry.trigger, in: input)
            guard occurrences.isEmpty == false else { continue }

            switch entry.resolution {
            case let .resolved(replacement, packID):
                applied.append(contentsOf: occurrences.map { range in
                    AppliedNormalizationChange(
                        trigger: input.substring(with: range),
                        replacement: replacement,
                        sourcePackID: packID,
                        pass: .lookupTable,
                        step: step,
                        range: range
                    )
                })
                // Right to left, so earlier ranges stay valid.
                var output = input
                for range in occurrences.reversed() {
                    output = output.replacingCharacters(in: range, with: replacement) as NSString
                }
                updatedText = output as String
            case let .conflicted(candidates):
                declined.append(contentsOf: occurrences.map { range in
                    DeclinedNormalization(
                        trigger: input.substring(with: range),
                        candidates: candidates,
                        reason: "Conflicting normalization for trigger '\(entry.trigger)'",
                        pass: .lookupTable,
                        step: step,
                        range: range
                    )
                })
            }
        }

        return NormalizationPassResult(text: updatedText, appliedChanges: applied, declinedChanges: declined)
    }

    /// Every non-overlapping occurrence of `trigger` in `text`, left to right,
    /// as UTF-16 ranges, using the same (non-literal) comparison as
    /// `String.replacingOccurrences(of:with:)`.
    private static func occurrences(of trigger: String, in text: NSString) -> [NSRange] {
        var results: [NSRange] = []
        var searchStart = 0
        while searchStart < text.length {
            let found = text.range(of: trigger, options: [], range: NSRange(location: searchStart, length: text.length - searchStart))
            guard found.location != NSNotFound, found.length > 0 else { break }
            results.append(found)
            searchStart = found.location + found.length
        }
        return results
    }
}
