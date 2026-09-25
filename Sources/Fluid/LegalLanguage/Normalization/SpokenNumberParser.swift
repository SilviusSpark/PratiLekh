import Foundation

/// A strict, minimal spoken-number parser -- not a general natural-language
/// number interpreter. It recognizes exactly two token shapes, concatenated
/// positionally:
///   - a single digit word ("zero".."nine") contributing one digit
///   - a teens/tens word ("ten".."nineteen", "twenty".."ninety") contributing
///     two digits
/// optionally followed by exactly one trailing single-letter token (a
/// statutory letter suffix, e.g. "A" in "376A").
///
/// This directly covers every number form the approved Phase 3C grammar
/// needs ("three zero two" -> "302", "one twenty" -> "120", "three seven six
/// A" -> "376A") without attempting "hundred"-style multipliers, ordinals,
/// or any other natural-language number construction. Anything outside this
/// strict shape returns nil -- the caller must decline, never guess.
enum SpokenNumberParser {
    private static let digitWords: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
    ]

    private static let tensWords: [String: String] = [
        "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13", "fourteen": "14",
        "fifteen": "15", "sixteen": "16", "seventeen": "17", "eighteen": "18", "nineteen": "19",
        "twenty": "20", "thirty": "30", "forty": "40", "fifty": "50",
        "sixty": "60", "seventy": "70", "eighty": "80", "ninety": "90",
    ]

    /// `digitsTokensConsumed` counts only the digit/tens tokens; `tokensConsumed`
    /// additionally counts the trailing letter suffix when one was found. Both
    /// are exposed because a single trailing letter is structurally
    /// ambiguous on its own -- it might be a genuine section-letter suffix
    /// ("376A"), or it might be the first letter of a spelled-out statute
    /// abbreviation dictated as individual letters ("302 I P C"). This
    /// parser has no statute vocabulary and cannot resolve that; it reports
    /// both possible consumption lengths so a caller that *does* have
    /// vocabulary access (see `StatutoryProvisionNormalizer`) can try both
    /// interpretations and keep whichever one resolves cleanly.
    struct ParsedNumber: Equatable {
        let digits: String
        let digitsTokensConsumed: Int
        let letterSuffix: String?
        let tokensConsumed: Int

        var formatted: String {
            digits + (letterSuffix ?? "")
        }

        /// The same number with any trailing letter suffix discarded.
        var withoutSuffix: ParsedNumber {
            ParsedNumber(digits: digits, digitsTokensConsumed: digitsTokensConsumed, letterSuffix: nil, tokensConsumed: digitsTokensConsumed)
        }
    }

    /// Attempts to parse a number sequence starting at `tokens[startIndex]`.
    /// Returns nil if there is no recognizable digit/tens word at that
    /// position at all (not a candidate) -- this is distinct from a rule
    /// family choosing to decline after a partial/ambiguous parse, which is
    /// the caller's responsibility once it has a `ParsedNumber`.
    static func parse(tokens: [String], startingAt startIndex: Int) -> ParsedNumber? {
        guard startIndex >= 0, startIndex < tokens.count else { return nil }

        var index = startIndex
        var digits = ""
        while index < tokens.count {
            let word = tokens[index].lowercased()
            if let digit = digitWords[word] {
                digits += digit
                index += 1
            } else if let tens = tensWords[word] {
                digits += tens
                index += 1
            } else {
                break
            }
        }
        guard !digits.isEmpty else { return nil }

        let digitsTokensConsumed = index - startIndex
        var consumed = digitsTokensConsumed
        var letterSuffix: String?
        if index < tokens.count {
            let candidate = tokens[index]
            if candidate.count == 1, candidate.rangeOfCharacter(from: .letters) != nil {
                letterSuffix = candidate.uppercased()
                consumed += 1
            }
        }

        return ParsedNumber(digits: digits, digitsTokensConsumed: digitsTokensConsumed, letterSuffix: letterSuffix, tokensConsumed: consumed)
    }
}
