import Foundation

/// A strict, minimal spoken-number parser -- not a general natural-language
/// number interpreter. It recognizes two families of shape:
///   - a run of pure single digit words ("zero".."nine"), concatenated
///     positionally, of any length ("three zero two" -> "302")
///   - Phase 3F.B's bounded grouped shape: exactly one tens/teens word
///     ("ten".."nineteen", "twenty".."ninety"), optionally preceded by one
///     leading (hundreds) digit-word and/or followed by one trailing
///     (units) digit-word, combined *arithmetically* -- "thirty four" -> 34,
///     "one forty four" -> 144, "one twenty" -> 120 (the trailing-digit slot
///     empty). A teen never combines with a trailing digit (it already
///     encodes both digits; "one thirteen four" is not a recognized shape).
/// optionally followed by exactly one trailing single-letter token (a
/// statutory letter suffix, e.g. "A" in "376A").
///
/// This directly covers every number form the approved Phase 3C/3F grammar
/// needs without attempting "hundred"-style multipliers, ordinals, or any
/// other natural-language number construction. Anything outside this strict
/// shape returns nil -- the caller must decline, never guess. In
/// particular, the grouped shape is deliberately bounded: it does not
/// re-enter its own loop, so a digit/tens word immediately following an
/// already-complete grouped result is left unconsumed for the caller to
/// treat as an unsupported continuation (see
/// `StatutoryProvisionNormalizer.matchUnsupportedNumberContinuation`) rather
/// than silently guessed at here.
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

        let core: (digits: String, tokensConsumed: Int)
        if let grouped = parseGroupedCompound(tokens: tokens, startingAt: startIndex) {
            core = grouped
        } else {
            var index = startIndex
            var digits = ""
            while index < tokens.count, let digit = digitWords[tokens[index].lowercased()] {
                digits += digit
                index += 1
            }
            guard !digits.isEmpty else { return nil }
            core = (digits: digits, tokensConsumed: index - startIndex)
        }

        var consumed = core.tokensConsumed
        var letterSuffix: String?
        let suffixIndex = startIndex + core.tokensConsumed
        if suffixIndex < tokens.count {
            let candidate = tokens[suffixIndex]
            if candidate.count == 1, candidate.rangeOfCharacter(from: .letters) != nil {
                letterSuffix = candidate.uppercased()
                consumed += 1
            }
        }

        return ParsedNumber(digits: core.digits, digitsTokensConsumed: core.tokensConsumed, letterSuffix: letterSuffix, tokensConsumed: consumed)
    }

    /// Phase 3F.B's bounded grouped shape (see the type-level doc comment).
    /// Tried before the pure digit-by-digit loop; returns nil (not this
    /// shape) unless the token at `startIndex` is a digit-word immediately
    /// followed by a tens-word, or is itself a tens-word -- so it never
    /// intercepts a plain digit-by-digit run (which never has a tens-word
    /// as its second token).
    private static func parseGroupedCompound(tokens: [String], startingAt startIndex: Int) -> (digits: String, tokensConsumed: Int)? {
        func digitValue(_ word: String) -> Int? { digitWords[word.lowercased()].flatMap { Int($0) } }
        func tensValue(_ word: String) -> Int? { tensWords[word.lowercased()].flatMap { Int($0) } }
        // A teen ("ten".."nineteen") already encodes both digits and does
        // not compose with a further trailing digit-word; only a genuine
        // tens value (twenty..ninety) does.
        func combinesWithTrailingDigit(_ tens: Int) -> Bool { tens >= 20 }

        var hundredsDigit: Int?
        var tensValueFound: Int?
        var cursor = startIndex

        if let leadingDigit = digitValue(tokens[cursor]), cursor + 1 < tokens.count, let tens = tensValue(tokens[cursor + 1]) {
            hundredsDigit = leadingDigit
            tensValueFound = tens
            cursor += 2
        } else if let tens = tensValue(tokens[cursor]) {
            tensValueFound = tens
            cursor += 1
        } else {
            return nil
        }

        guard let tens = tensValueFound else { return nil }
        var combined = tens
        if combinesWithTrailingDigit(tens), cursor < tokens.count, let units = digitValue(tokens[cursor]) {
            combined += units
            cursor += 1
        }

        let digits = hundredsDigit.map { "\($0)" + String(format: "%02d", combined) } ?? "\(combined)"
        return (digits: digits, tokensConsumed: cursor - startIndex)
    }
}
