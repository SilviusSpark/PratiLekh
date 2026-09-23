import Foundation

/// The one place precedence logic lives. Order-independent: callers do not
/// need to pass packs in any particular order, since rank is derived from
/// `pack.kind`, not array position -- this is what makes resolution
/// deterministic given the same set of packs regardless of load order.
enum PrecedenceResolver {
    /// Highest precedence first.
    static let rankOrder: [PackKind] = [.user, .jurisdiction, .builtin]

    static func resolveRecognitionVocabulary(from packs: [LanguagePack]) -> ResolvedRecognitionVocabulary {
        let orderedPacks = packs.sorted { rank(of: $0) < rank(of: $1) }

        var order: [String] = []
        var aliasesByCanonical: [String: [String]] = [:]
        var packIDsByCanonical: [String: [String]] = [:]

        for pack in orderedPacks {
            for entry in pack.recognitionEntries {
                if aliasesByCanonical[entry.canonical] == nil {
                    order.append(entry.canonical)
                    aliasesByCanonical[entry.canonical] = []
                    packIDsByCanonical[entry.canonical] = []
                }
                for alias in entry.aliases where !(aliasesByCanonical[entry.canonical] ?? []).contains(alias) {
                    aliasesByCanonical[entry.canonical]?.append(alias)
                }
                if !(packIDsByCanonical[entry.canonical] ?? []).contains(pack.id) {
                    packIDsByCanonical[entry.canonical]?.append(pack.id)
                }
            }
        }

        let entries = order.map { canonical in
            ResolvedRecognitionEntry(
                canonical: canonical,
                aliases: aliasesByCanonical[canonical] ?? [],
                sourcePackIDs: packIDsByCanonical[canonical] ?? []
            )
        }
        return ResolvedRecognitionVocabulary(entries: entries)
    }

    static func resolveNormalizationTable(from packs: [LanguagePack]) -> ResolvedNormalizationTable {
        struct Contribution {
            let packID: String
            let kind: PackKind
            let replacement: String
        }

        var order: [String] = []
        var contributionsByTrigger: [String: [Contribution]] = [:]

        for pack in packs {
            for entry in pack.normalizationEntries {
                if contributionsByTrigger[entry.trigger] == nil {
                    order.append(entry.trigger)
                    contributionsByTrigger[entry.trigger] = []
                }
                contributionsByTrigger[entry.trigger]?.append(
                    Contribution(packID: pack.id, kind: pack.kind, replacement: entry.canonicalReplacement)
                )
            }
        }

        let resolvedEntries: [ResolvedNormalizationEntry] = order.compactMap { trigger in
            guard let contributions = contributionsByTrigger[trigger], !contributions.isEmpty else { return nil }

            // The topmost rank actually present for this trigger -- not every
            // trigger needs a contribution from all three kinds.
            guard let topRank = rankOrder.first(where: { rank in contributions.contains { $0.kind == rank } })
            else { return nil }

            let topContributions = contributions.filter { $0.kind == topRank }
            let distinctReplacements = Set(topContributions.map(\.replacement))

            let resolution: NormalizationResolution
            if distinctReplacements.count == 1, let replacement = distinctReplacements.first {
                // Same rank, same value (including the common case of a single
                // contributor) -- dedupes to one clean resolution.
                resolution = .resolved(replacement: replacement, sourcePackID: topContributions[0].packID)
            } else {
                // Same rank, different values -- a genuine ambiguity. Recorded,
                // never silently picked.
                resolution = .conflicted(
                    candidates: topContributions.map {
                        NormalizationCandidate(sourcePackID: $0.packID, replacement: $0.replacement)
                    }
                )
            }
            return ResolvedNormalizationEntry(trigger: trigger, resolution: resolution)
        }

        return ResolvedNormalizationTable(entries: resolvedEntries)
    }

    private static func rank(of pack: LanguagePack) -> Int {
        rankOrder.firstIndex(of: pack.kind) ?? rankOrder.count
    }
}
