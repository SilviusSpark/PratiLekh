import Foundation

@main
enum LookupTableNormalizerTests {
    static func main() {
        testUnchangedWhenNoTriggerPresent()
        testAppliedWhenOnlySafeMatchesPresent()
        testDeclinedWhenOnlyConflictedMatchesPresent()
        testMixedSafeAndConflictedMatchesInSameInput()
        testSameRankSameValueDeduplicationIsAppliedNotDeclined()
        print("PASS: LookupTableNormalizer unchanged/applied/declined semantics, including mixed outcomes")
    }

    private static func resolved(_ trigger: String, _ replacement: String, packID: String = "fixture") -> ResolvedNormalizationEntry {
        ResolvedNormalizationEntry(trigger: trigger, resolution: .resolved(replacement: replacement, sourcePackID: packID))
    }

    private static func conflicted(_ trigger: String, _ candidates: [(String, String)]) -> ResolvedNormalizationEntry {
        ResolvedNormalizationEntry(
            trigger: trigger,
            resolution: .conflicted(candidates: candidates.map { NormalizationCandidate(sourcePackID: $0.0, replacement: $0.1) })
        )
    }

    private static func testUnchangedWhenNoTriggerPresent() {
        let table = ResolvedNormalizationTable(entries: [resolved("sec.", "Section")])
        let result = LookupTableNormalizer().normalize("no triggers here", using: table)
        precondition(result.isUnchanged, "No matching trigger must be unchanged")
        precondition(result.text == "no triggers here")
        precondition(result.appliedChanges.isEmpty && result.declinedChanges.isEmpty)
    }

    private static func testAppliedWhenOnlySafeMatchesPresent() {
        let table = ResolvedNormalizationTable(entries: [
            resolved("sec.", "Section"),
            resolved("distt.", "District"),
        ])
        let result = LookupTableNormalizer().normalize("sec. 302, distt. court", using: table)
        precondition(result.text == "Section 302, District court")
        precondition(result.appliedChanges.count == 2)
        precondition(result.declinedChanges.isEmpty)
        precondition(!result.isUnchanged)
    }

    private static func testDeclinedWhenOnlyConflictedMatchesPresent() {
        let table = ResolvedNormalizationTable(entries: [
            conflicted("distt.", [("jurisdiction-a", "District"), ("jurisdiction-b", "Dist.")]),
        ])
        let result = LookupTableNormalizer().normalize("the distt. court", using: table)
        precondition(result.text == "the distt. court", "Conflicted trigger must be left unchanged in the output")
        precondition(result.appliedChanges.isEmpty)
        precondition(result.declinedChanges.count == 1)
        precondition(result.declinedChanges[0].trigger == "distt.")
        precondition(Set(result.declinedChanges[0].candidates.map(\.replacement)) == Set(["District", "Dist."]))
        precondition(!result.isUnchanged)
    }

    private static func testMixedSafeAndConflictedMatchesInSameInput() {
        // A clean match and a conflicted match coexist in the same text.
        // The clean one must still be applied; the conflicted one must be
        // left unchanged and recorded as declined -- neither blocks the other.
        let table = ResolvedNormalizationTable(entries: [
            resolved("sec.", "Section"),
            conflicted("distt.", [("jurisdiction-a", "District"), ("jurisdiction-b", "Dist.")]),
        ])
        let result = LookupTableNormalizer().normalize("sec. 302, distt. court", using: table)
        precondition(result.text == "Section 302, distt. court", "Safe match applied, conflicted match left untouched")
        precondition(result.appliedChanges == [AppliedNormalizationChange(trigger: "sec.", replacement: "Section", sourcePackID: "fixture")])
        precondition(result.declinedChanges.count == 1 && result.declinedChanges[0].trigger == "distt.")
    }

    private static func testSameRankSameValueDeduplicationIsAppliedNotDeclined() {
        // A trigger resolved cleanly because two same-rank packs agreed on the
        // same value (see PrecedenceResolverTests.testSameRankSameValueDeduplicates)
        // must flow through as .applied here, not .declined.
        let jurisdictionA = LanguagePack(
            id: "jurisdiction-a", version: "1.0.0", kind: .jurisdiction, displayName: "A",
            recognitionEntries: [], normalizationEntries: [NormalizationEntry(trigger: "hon'ble", canonicalReplacement: "Hon'ble")]
        )
        let jurisdictionB = LanguagePack(
            id: "jurisdiction-b", version: "1.0.0", kind: .jurisdiction, displayName: "B",
            recognitionEntries: [], normalizationEntries: [NormalizationEntry(trigger: "hon'ble", canonicalReplacement: "Hon'ble")]
        )
        let table = PrecedenceResolver.resolveNormalizationTable(from: [jurisdictionA, jurisdictionB])
        let result = LookupTableNormalizer().normalize("hon'ble judge", using: table)
        precondition(result.text == "Hon'ble judge")
        precondition(result.appliedChanges.count == 1)
        precondition(result.declinedChanges.isEmpty, "Same-rank/same-value agreement must never be treated as a conflict")
    }
}
