import Foundation

/// Normalizes witness references dictated by a judge, per the Phase 3B/3C
/// approval. Exhibit normalization is explicitly out of scope for this
/// slice (deferred pending separate research into Indian exhibit
/// conventions) -- only witnesses are handled here.
///
/// Supported:
///   "prosecution witness" + number -> `PW-<n>`
///   "PW" (or "P W") + number       -> `PW-<n>`
///   "defence witness" + number     -> `DW-<n>`
///   "DW" (or "D W") + number       -> `DW-<n>`
///
/// A role word with no clear number, or a number with no role word, is not
/// a candidate at all. Self-correction directly attached to the number
/// ("PW one, or was it PW two") declines the whole reference -- a hedge
/// elsewhere in the sentence does not.
struct WitnessReferenceNormalizer: LegalNormalizer {
    private static let hedgeConnectors: Set<String> = ["or", "maybe"]
    private static let confirmatoryContinuations: Set<String> = ["possibly", "was", "it"]

    func normalize(_ text: String, using context: NormalizationContext) -> NormalizationPassResult {
        let tokens = WordTokenizer.tokenize(text)
        let words = tokens.map(\.text)
        var applied: [AppliedNormalizationChange] = []
        var declined: [DeclinedNormalization] = []
        var replacements: [(range: NSRange, text: String)] = []

        var i = 0
        while i < tokens.count {
            if let match = Self.matchRole(words: words, at: i) {
                var numberStart = i + match.tokensConsumed
                // Optional connector word between the role and the numeral,
                // e.g. "witness number one" (vs. the bare "PW one").
                if numberStart < words.count, words[numberStart].lowercased() == "number" {
                    numberStart += 1
                }
                guard let number = SpokenNumberParser.parse(tokens: words, startingAt: numberStart) else {
                    i += 1
                    continue
                }
                let afterNumber = numberStart + number.tokensConsumed

                if let hedgeEnd = Self.matchHedge(words: words, at: afterNumber) {
                    let full = Self.span(tokens, i, hedgeEnd - 1)
                    declined.append(
                        DeclinedNormalization(
                            trigger: (text as NSString).substring(with: full),
                            candidates: [],
                            reason: "\(DeclineReason.unresolvedUncertainty.rawValue): witness reference expressed with uncertainty",
                            range: full
                        )
                    )
                    i = hedgeEnd
                    continue
                }

                let fullRange = Self.span(tokens, i, afterNumber - 1)
                let replacement = "\(match.prefix)-\(number.digits)"
                replacements.append((fullRange, replacement))
                applied.append(
                    AppliedNormalizationChange(
                        trigger: (text as NSString).substring(with: fullRange),
                        replacement: replacement,
                        sourcePackID: "phase3.witnessReference",
                        range: fullRange
                    )
                )
                i = afterNumber
                continue
            }
            i += 1
        }

        var resultText = text as NSString
        for entry in replacements.sorted(by: { $0.range.location > $1.range.location }) {
            resultText = resultText.replacingCharacters(in: entry.range, with: entry.text) as NSString
        }

        return NormalizationPassResult(text: resultText as String, appliedChanges: applied, declinedChanges: declined)
    }

    private struct RoleMatch { let prefix: String; let tokensConsumed: Int }

    private static func matchRole(words: [String], at index: Int) -> RoleMatch? {
        guard index < words.count else { return nil }
        let word = words[index].lowercased()

        if word == "prosecution", index + 1 < words.count, words[index + 1].lowercased() == "witness" {
            return RoleMatch(prefix: "PW", tokensConsumed: 2)
        }
        if word == "defence", index + 1 < words.count, words[index + 1].lowercased() == "witness" {
            return RoleMatch(prefix: "DW", tokensConsumed: 2)
        }
        if word == "pw" {
            return RoleMatch(prefix: "PW", tokensConsumed: 1)
        }
        if word == "dw" {
            return RoleMatch(prefix: "DW", tokensConsumed: 1)
        }
        if word == "p", index + 1 < words.count, words[index + 1].lowercased() == "w" {
            return RoleMatch(prefix: "PW", tokensConsumed: 2)
        }
        if word == "d", index + 1 < words.count, words[index + 1].lowercased() == "w" {
            return RoleMatch(prefix: "DW", tokensConsumed: 2)
        }
        return nil
    }

    /// The alternative in a self-correction may restate the role ("or was
    /// it PW two") or just give a bare number ("or possibly two") -- both
    /// forms must be recognized so the correction is never mistaken for an
    /// unrelated second reference.
    private static func matchHedge(words: [String], at index: Int) -> Int? {
        guard index < words.count, hedgeConnectors.contains(words[index].lowercased()) else { return nil }
        var cursor = index + 1
        while cursor < words.count, confirmatoryContinuations.contains(words[cursor].lowercased()) {
            cursor += 1
        }
        if let role = matchRole(words: words, at: cursor) {
            cursor += role.tokensConsumed
            if cursor < words.count, words[cursor].lowercased() == "number" {
                cursor += 1
            }
        }
        guard let alt = SpokenNumberParser.parse(tokens: words, startingAt: cursor) else { return nil }
        return cursor + alt.tokensConsumed
    }

    private static func span(_ tokens: [WordToken], _ startToken: Int, _ endToken: Int) -> NSRange {
        let start = tokens[startToken].range
        let end = tokens[min(endToken, tokens.count - 1)].range
        return NSRange(location: start.location, length: (end.location + end.length) - start.location)
    }
}
