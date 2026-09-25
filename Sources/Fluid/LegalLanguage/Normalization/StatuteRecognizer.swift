import Foundation

/// Recognizes a statute mention using the already-approved Phase 2 Indian
/// Legal Core recognition entries -- not a second, uncontrolled statute
/// vocabulary. `statuteCanonicalNames` below only identifies *which* of the
/// resolved recognition entries represent a statute for this rule's
/// purposes; the actual text matched against dictated words (canonical name
/// and aliases) is read from the resolved vocabulary at runtime, so this
/// rule automatically tracks whatever Phase 2 ships under those exact
/// canonical names.
enum StatuteRecognizer {
    private static let statuteCanonicalNames: Set<String> = [
        "Bharatiya Nyaya Sanhita, 2023",
        "Bharatiya Nagarik Suraksha Sanhita, 2023",
        "Bharatiya Sakshya Adhiniyam, 2023",
        "Indian Penal Code, 1860",
        "Code of Criminal Procedure, 1973",
        "Indian Evidence Act, 1872",
        "Code of Civil Procedure, 1908",
    ]

    private static let connectors: Set<String> = ["of", "the", "under"]

    struct Match: Equatable {
        let citationForm: String
        let tokensConsumed: Int
    }

    /// Tries to match a statute mention starting at `tokens[startIndex]`,
    /// skipping a small set of connector words ("of", "the", "under")
    /// immediately before it. `tokensConsumed` counts from `startIndex`,
    /// including any skipped connectors, so the caller can advance its
    /// cursor past the whole match.
    static func match(tokens: [String], startingAt startIndex: Int, vocabulary: ResolvedRecognitionVocabulary?) -> Match? {
        guard let vocabulary else { return nil }
        let statuteEntries = vocabulary.entries.filter { statuteCanonicalNames.contains($0.canonical) }
        guard !statuteEntries.isEmpty, startIndex < tokens.count else { return nil }

        var index = startIndex
        while index < tokens.count, connectors.contains(tokens[index].lowercased()) {
            index += 1
        }
        guard index < tokens.count else { return nil }

        // Alias match first (the common case -- e.g. "IPC"). An all-letter
        // alias like "IPC" or "BNSS" may also be dictated/transcribed as
        // individually spelled letters ("I P C") rather than one fused
        // token -- both forms must resolve to the same citation.
        for entry in statuteEntries {
            for alias in entry.aliases {
                let aliasTokens = alias.split(separator: " ").map(String.init)
                if matches(tokens: tokens, at: index, expected: aliasTokens) {
                    return Match(citationForm: entry.aliases.first ?? entry.canonical, tokensConsumed: (index - startIndex) + aliasTokens.count)
                }
                if let letterCount = matchesSpelledOutLetters(tokens: tokens, at: index, alias: alias) {
                    return Match(citationForm: entry.aliases.first ?? entry.canonical, tokensConsumed: (index - startIndex) + letterCount)
                }
            }
        }
        // Fall back to the canonical full name (minus the trailing ", <year>"), e.g. "Indian Penal Code".
        for entry in statuteEntries {
            let canonicalTokens = nameTokens(entry.canonical)
            if matches(tokens: tokens, at: index, expected: canonicalTokens) {
                return Match(citationForm: entry.aliases.first ?? entry.canonical, tokensConsumed: (index - startIndex) + canonicalTokens.count)
            }
        }
        return nil
    }

    private static func nameTokens(_ canonical: String) -> [String] {
        let withoutYear = canonical.split(separator: ",").first.map(String.init) ?? canonical
        return withoutYear.split(separator: " ").map(String.init)
    }

    /// Matches an all-letter alias (e.g. "IPC") against a sequence of
    /// individually spelled single-letter tokens ("I", "P", "C"). Returns
    /// the number of tokens consumed, or nil if the alias isn't purely
    /// letters or the tokens don't spell it out exactly.
    private static func matchesSpelledOutLetters(tokens: [String], at index: Int, alias: String) -> Int? {
        let letters = Array(alias)
        guard !letters.isEmpty, letters.allSatisfy({ $0.isLetter }) else { return nil }
        guard index + letters.count <= tokens.count else { return nil }
        for (offset, letter) in letters.enumerated() {
            let token = tokens[index + offset]
            guard token.count == 1, let tokenChar = token.first, tokenChar.lowercased() == letter.lowercased() else {
                return nil
            }
        }
        return letters.count
    }

    private static func matches(tokens: [String], at index: Int, expected: [String]) -> Bool {
        guard !expected.isEmpty, index + expected.count <= tokens.count else { return false }
        for (offset, word) in expected.enumerated() where tokens[index + offset].caseInsensitiveCompare(word) != .orderedSame {
            return false
        }
        return true
    }
}
