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

    /// Phase 3F.A detection-only guard: does the leading letter, plus the
    /// tokens immediately following it, plausibly continue as a *fragmented*
    /// spelled-out statute alias -- the same shape `matchesSpelledOutLetters`
    /// recognizes, but tolerant of exactly one interposed "and" (the one
    /// shape observed in real dictation, where an abbreviation's letters
    /// were not transcribed as a clean contiguous run, e.g. "B and S S" for
    /// "BNSS"). This never returns a citable statute identity or
    /// reconstructs which statute was meant -- it only signals that treating
    /// `leadingLetter` as a section-letter suffix would be unsafe, so the
    /// caller can decline instead of guessing. The "and" is a positional
    /// wildcard only, for this local check -- it is never rewritten or
    /// treated as meaning any specific letter anywhere else.
    ///
    /// Requires at least 3 known (non-wildcard) letters, including
    /// `leadingLetter` itself, before treating a match as evidence -- fewer
    /// than that coincides with real short aliases (e.g. "BNS") and would
    /// otherwise misfire on ordinary prose such as a name's initial right
    /// after a suffix ("Section 120B and S. Roy filed...").
    static func looksLikeFragmentedAlias(leadingLetter: String, followingTokens: [String], vocabulary: ResolvedRecognitionVocabulary?) -> Bool {
        guard let vocabulary else { return false }
        var knownLetters = [leadingLetter.uppercased()]
        var gapPosition: Int?
        var index = 0
        while index < followingTokens.count {
            let token = followingTokens[index]
            if token.count == 1, token.rangeOfCharacter(from: .letters) != nil {
                knownLetters.append(token.uppercased())
                index += 1
            } else if token.lowercased() == "and", gapPosition == nil {
                gapPosition = knownLetters.count
                index += 1
            } else {
                break
            }
        }
        guard let gap = gapPosition, knownLetters.count >= 3 else { return false }

        let totalLength = knownLetters.count + 1
        let statuteEntries = vocabulary.entries.filter { statuteCanonicalNames.contains($0.canonical) }
        for entry in statuteEntries {
            for alias in entry.aliases where alias.count == totalLength && alias.allSatisfy(\.isLetter) {
                if matchesKnownLetters(knownLetters, wildcardAt: gap, against: Array(alias.uppercased())) {
                    return true
                }
            }
        }
        return false
    }

    /// `aliasChars` and the combined (letters + one wildcard) sequence are
    /// the same length by construction; `wildcardAt` marks the one position
    /// that matches unconditionally.
    private static func matchesKnownLetters(_ knownLetters: [String], wildcardAt gap: Int, against aliasChars: [Character]) -> Bool {
        var knownIndex = 0
        for position in 0..<aliasChars.count {
            if position == gap { continue }
            guard knownIndex < knownLetters.count,
                  let knownChar = knownLetters[knownIndex].first,
                  knownChar == aliasChars[position]
            else { return false }
            knownIndex += 1
        }
        return knownIndex == knownLetters.count
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
