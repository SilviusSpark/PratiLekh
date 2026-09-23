import Foundation

@main
enum PrecedenceResolverTests {
    static func main() {
        testRecognitionMergesAndDeduplicatesAliases()
        testNormalizationOverridesWithoutMutatingInput()
        testNormalizationSkipLevelOverride()
        testSameRankSameValueDeduplicates()
        testSameRankDifferentValueConflicts()
        print("PASS: PrecedenceResolver recognition merge and normalization precedence/conflict rules")
    }

    private static func pack(
        id: String,
        kind: PackKind,
        recognition: [RecognitionEntry] = [],
        normalization: [NormalizationEntry] = []
    ) -> LanguagePack {
        LanguagePack(
            id: id,
            version: "1.0.0",
            kind: kind,
            displayName: id,
            recognitionEntries: recognition,
            normalizationEntries: normalization
        )
    }

    private static func testRecognitionMergesAndDeduplicatesAliases() {
        let builtinPack = pack(
            id: "builtin",
            kind: .builtin,
            recognition: [RecognitionEntry(canonical: "BNS", aliases: ["bee en es", "b n s"])]
        )
        let userPack = pack(
            id: "user",
            kind: .user,
            recognition: [RecognitionEntry(canonical: "BNS", aliases: ["b n s", "bharatiya nyaya sanhita"])]
        )
        let resolved = PrecedenceResolver.resolveRecognitionVocabulary(from: [builtinPack, userPack])
        precondition(resolved.entries.count == 1, "Same canonical term from two packs must merge into one entry")
        let entry = resolved.entries[0]
        precondition(entry.canonical == "BNS")
        precondition(
            Set(entry.aliases) == Set(["bee en es", "b n s", "bharatiya nyaya sanhita"]),
            "Aliases must union and deduplicate across packs"
        )
        precondition(
            Set(entry.sourcePackIDs) == Set(["builtin", "user"]),
            "Both contributing packs must be recorded"
        )
    }

    private static func testNormalizationOverridesWithoutMutatingInput() {
        let builtinPack = pack(
            id: "builtin",
            kind: .builtin,
            normalization: [NormalizationEntry(trigger: "sec.", canonicalReplacement: "Section")]
        )
        let jurisdictionPack = pack(
            id: "odisha",
            kind: .jurisdiction,
            normalization: [NormalizationEntry(trigger: "sec.", canonicalReplacement: "Sec.")]
        )
        let inputPacks = [builtinPack, jurisdictionPack]
        let resolved = PrecedenceResolver.resolveNormalizationTable(from: inputPacks)

        guard case let .resolved(replacement, sourcePackID) = resolved.resolution(forTrigger: "sec.") else {
            preconditionFailure("Expected a clean resolution")
        }
        precondition(replacement == "Sec.", "Jurisdiction pack must override builtin")
        precondition(sourcePackID == "odisha")

        // The lower-precedence pack's own data must be untouched by resolution.
        precondition(
            builtinPack.normalizationEntries == [NormalizationEntry(trigger: "sec.", canonicalReplacement: "Section")],
            "Resolving must never mutate a lower-precedence pack's stored entries"
        )
        precondition(inputPacks == [builtinPack, jurisdictionPack], "Input packs must be unchanged after resolution")
    }

    private static func testNormalizationSkipLevelOverride() {
        let builtinPack = pack(
            id: "builtin",
            kind: .builtin,
            normalization: [NormalizationEntry(trigger: "sec.", canonicalReplacement: "Section")]
        )
        let userPack = pack(
            id: "user",
            kind: .user,
            normalization: [NormalizationEntry(trigger: "sec.", canonicalReplacement: "§")]
        )
        // No jurisdiction pack at all -- user must still win over builtin.
        let resolved = PrecedenceResolver.resolveNormalizationTable(from: [builtinPack, userPack])
        guard case let .resolved(replacement, sourcePackID) = resolved.resolution(forTrigger: "sec.") else {
            preconditionFailure("Expected a clean resolution")
        }
        precondition(replacement == "§")
        precondition(sourcePackID == "user")
    }

    private static func testSameRankSameValueDeduplicates() {
        let jurisdictionA = pack(
            id: "jurisdiction-a",
            kind: .jurisdiction,
            normalization: [NormalizationEntry(trigger: "hon'ble", canonicalReplacement: "Hon'ble")]
        )
        let jurisdictionB = pack(
            id: "jurisdiction-b",
            kind: .jurisdiction,
            normalization: [NormalizationEntry(trigger: "hon'ble", canonicalReplacement: "Hon'ble")]
        )
        let resolved = PrecedenceResolver.resolveNormalizationTable(from: [jurisdictionA, jurisdictionB])
        guard case let .resolved(replacement, _) = resolved.resolution(forTrigger: "hon'ble") else {
            preconditionFailure("Same-rank, same-value contributions must deduplicate to a clean resolution")
        }
        precondition(replacement == "Hon'ble")
        precondition(resolved.conflicts.isEmpty, "No conflict expected when values agree")
    }

    private static func testSameRankDifferentValueConflicts() {
        let jurisdictionA = pack(
            id: "jurisdiction-a",
            kind: .jurisdiction,
            normalization: [NormalizationEntry(trigger: "distt.", canonicalReplacement: "District")]
        )
        let jurisdictionB = pack(
            id: "jurisdiction-b",
            kind: .jurisdiction,
            normalization: [NormalizationEntry(trigger: "distt.", canonicalReplacement: "Dist.")]
        )
        let resolved = PrecedenceResolver.resolveNormalizationTable(from: [jurisdictionA, jurisdictionB])
        guard case let .conflicted(candidates) = resolved.resolution(forTrigger: "distt.") else {
            preconditionFailure("Same-rank, different-value contributions must produce a conflict, never a silent pick")
        }
        precondition(candidates.count == 2)
        precondition(Set(candidates.map(\.replacement)) == Set(["District", "Dist."]))
        precondition(resolved.conflicts.count == 1)
        precondition(resolved.conflicts[0].key == "distt.")
    }
}
