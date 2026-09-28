import Foundation

/// Normalizes statutory provision references dictated by a judge, per the
/// Phase 3B-approved bounded grammar. Governing principle: format what was
/// dictated, never complete what was not dictated -- a statute suffix is
/// added only if a statute was actually present in the input.
///
/// This type only *parses* -- it produces a `StatutoryProvisionReference`
/// per candidate, and defers all text rendering to
/// `StatutoryProvisionRenderer`. Recognized input shape (e.g. whether a
/// list happened to use commas) never selects an output drafting style;
/// see `StatutoryProvisionReference.swift` for why that separation exists.
///
/// Supported shapes only:
///   1. `section <number>`                          -> one provision, no statute
///   2. `section <number> <statute>`                 -> one provision, with statute
///   3. `sections <enumerated provisions> <statute>` -> two or more provisions, one statute
///      (enumeration via "and" alone, commas, or both -- e.g. "X and Y",
///      "X, Y and Z"; the enumeration syntax used does not affect the
///      resulting structure or its rendering)
///
/// Everything else recognized as a "section"/"sections" reference but not
/// matching one of these shapes exactly -- `read with`, sub-sections,
/// ranges, cross-statute compounds, ambiguous bare continuations, a bare
/// (statute-less) multi-provision list -- declines the entire candidate
/// span with `.unsupportedStructure`, never a partial transformation.
///
/// Any uncertainty (a hedge, a self-correction) structurally attached to a
/// candidate's number or statute declines the whole candidate. Uncertainty
/// about a *mentioned* statute is never treated the same as no statute
/// having been mentioned at all -- the two are semantically different, so
/// the former always fully declines rather than falling back to shape 1.
struct StatutoryProvisionNormalizer: LegalNormalizer {
    var passID: NormalizationPassID { .statutoryProvision }

    private struct Candidate {
        let startToken: Int
        let endToken: Int // exclusive
        let range: NSRange
        let outcome: Outcome
    }

    private enum Outcome {
        case applied(StatutoryProvisionReference)
        case declined(DeclineReason, String)
    }

    private static let hedgeConnectors: Set<String> = ["or", "maybe"]
    private static let confirmatoryContinuations: Set<String> = ["possibly", "was", "it"]

    func normalize(_ text: String, using context: NormalizationContext) -> NormalizationPassResult {
        let tokens = WordTokenizer.tokenize(text)
        let words = tokens.map(\.text)
        var candidates: [Candidate] = []
        var i = 0

        while i < tokens.count {
            let word = words[i].lowercased()
            if word == "section", let candidate = Self.matchSingular(tokens: tokens, words: words, triggerIndex: i, vocabulary: context.resolvedRecognitionVocabulary) {
                candidates.append(candidate)
                i = candidate.endToken
                continue
            }
            if word == "sections", let candidate = Self.matchPlural(tokens: tokens, words: words, text: text, triggerIndex: i, vocabulary: context.resolvedRecognitionVocabulary) {
                candidates.append(candidate)
                i = candidate.endToken
                continue
            }
            i += 1
        }

        return Self.build(candidates: candidates, text: text)
    }

    // MARK: - Singular ("section <number>[ <statute>]")

    private static func matchSingular(
        tokens: [WordToken], words: [String], triggerIndex: Int, vocabulary: ResolvedRecognitionVocabulary?
    ) -> Candidate? {
        let numberStart = triggerIndex + 1
        guard let rawNumber = SpokenNumberParser.parse(tokens: words, startingAt: numberStart) else { return nil }

        // Phase 3F.A fail-closed safety: a token immediately after the raw
        // digit run that itself signals the number expression is not
        // finished (currently just "hundred") must never be silently
        // dropped. `SpokenNumberParser` has no cardinal-number grammar for
        // this (deferred to a future phase) -- decline the whole candidate
        // rather than commit to the shorter, wrong number already parsed.
        // Checked against the raw digit run, before any suffix/statute
        // disambiguation, since the number is already known-incomplete
        // regardless of what (if anything) follows it.
        if let continuationEnd = matchUnsupportedNumberContinuation(words: words, at: numberStart + rawNumber.digitsTokensConsumed) {
            return Candidate(
                startToken: triggerIndex,
                endToken: continuationEnd,
                range: span(tokens, triggerIndex, continuationEnd - 1),
                outcome: .declined(.unclearValue, "unsupported numeric continuation")
            )
        }

        // A trailing single letter is structurally ambiguous on its own --
        // it might be a genuine section suffix ("376A") or the first letter
        // of a spelled-out statute abbreviation ("302 I P C"). Try the
        // suffix interpretation first; if no statute is found there but one
        // *is* found by treating the letter as part of the statute instead,
        // prefer that interpretation. See `SpokenNumberParser.ParsedNumber`.
        let resolved = resolveNumberAndStatute(rawNumber, numberStart: numberStart, words: words, vocabulary: vocabulary)
        let number = resolved.number
        let afterNumber = numberStart + number.tokensConsumed

        // Uncertainty directly attached to the number itself, e.g.
        // "section three zero two, or possibly three zero four".
        if let hedgeEnd = matchNumberHedge(words: words, at: afterNumber) {
            return Candidate(
                startToken: triggerIndex,
                endToken: hedgeEnd,
                range: span(tokens, triggerIndex, hedgeEnd - 1),
                outcome: .declined(.unresolvedUncertainty, "number expressed with uncertainty")
            )
        }

        let statute: StatuteRecognizer.Match
        switch resolved.resolution {
        case let .found(match):
            statute = match
        case .ambiguousFragment:
            // Phase 3F.A: neither a genuine suffix nor a statute could be
            // established -- what follows plausibly continues as a
            // fragmented statute abbreviation. Decline rather than guess.
            return Candidate(
                startToken: triggerIndex,
                endToken: afterNumber,
                range: span(tokens, triggerIndex, afterNumber - 1),
                outcome: .declined(.unresolvedUncertainty, "statute abbreviation appears fragmented")
            )
        case .none:
            // No statute mentioned at all. Before falling back to the bare
            // form, rule out an unsupported continuation (read with /
            // sub-section) right after the bare number.
            if let unsupportedEnd = matchUnsupportedContinuation(tokens: tokens, words: words, at: afterNumber, vocabulary: vocabulary) {
                return Candidate(
                    startToken: triggerIndex,
                    endToken: unsupportedEnd,
                    range: span(tokens, triggerIndex, unsupportedEnd - 1),
                    outcome: .declined(.unsupportedStructure, "unsupported statutory structure")
                )
            }
            return Candidate(
                startToken: triggerIndex,
                endToken: afterNumber,
                range: span(tokens, triggerIndex, afterNumber - 1),
                outcome: .applied(StatutoryProvisionReference(
                    provisionNumbers: [number.formatted],
                    statute: nil,
                    range: span(tokens, triggerIndex, afterNumber - 1)
                ))
            )
        }

        let afterStatute = afterNumber + statute.tokensConsumed

        // Uncertainty about the *mentioned* statute -- must decline the
        // whole candidate, never silently drop to the bare-number form.
        if let hedgeEnd = matchStatuteHedge(words: words, at: afterStatute, vocabulary: vocabulary) {
            return Candidate(
                startToken: triggerIndex,
                endToken: hedgeEnd,
                range: span(tokens, triggerIndex, hedgeEnd - 1),
                outcome: .declined(.unresolvedUncertainty, "statute expressed with uncertainty")
            )
        }

        // Ambiguous compound: "... IPC and 101 BNS" -- a bare number (no
        // "section" keyword of its own) following "and". Never infer the
        // omitted "section"; decline the whole extended structure.
        if let ambiguousEnd = matchAmbiguousBareContinuation(words: words, at: afterStatute, vocabulary: vocabulary) {
            return Candidate(
                startToken: triggerIndex,
                endToken: ambiguousEnd,
                range: span(tokens, triggerIndex, ambiguousEnd - 1),
                outcome: .declined(.unsupportedStructure, "ambiguous compound reference")
            )
        }

        if let unsupportedEnd = matchUnsupportedContinuation(tokens: tokens, words: words, at: afterStatute, vocabulary: vocabulary) {
            return Candidate(
                startToken: triggerIndex,
                endToken: unsupportedEnd,
                range: span(tokens, triggerIndex, unsupportedEnd - 1),
                outcome: .declined(.unsupportedStructure, "unsupported statutory structure")
            )
        }

        return Candidate(
            startToken: triggerIndex,
            endToken: afterStatute,
            range: span(tokens, triggerIndex, afterStatute - 1),
            outcome: .applied(StatutoryProvisionReference(
                provisionNumbers: [number.formatted],
                statute: statute.citationForm,
                range: span(tokens, triggerIndex, afterStatute - 1)
            ))
        )
    }

    // MARK: - Plural ("sections <enumerated provisions> <statute>")

    //
    // Whether the enumeration used commas, "and" alone, or both has no
    // bearing on the resulting structure -- it's tracked only to bound each
    // member's number parse (see `parseNumberRespectingCommaBoundary`), not
    // to select a rendering shape. Two-item and three-or-more-item lists
    // are the same kind of candidate here, differing only in element count.

    private static func matchPlural(
        tokens: [WordToken], words: [String], text: String, triggerIndex: Int, vocabulary: ResolvedRecognitionVocabulary?
    ) -> Candidate? {
        var numbers: [SpokenNumberParser.ParsedNumber] = []
        var cursor = triggerIndex + 1
        var lastNumberStartToken = triggerIndex

        while true {
            // A pure digit-word run has no lexical marker of its own end --
            // "three two three, three four one" would otherwise greedily
            // parse as one six-digit number, swallowing the comma-separated
            // boundary between two list members. Truncate at the first
            // comma found within the run.
            guard let number = parseNumberRespectingCommaBoundary(tokens: tokens, words: words, text: text, at: cursor) else {
                // No number where one was expected -- malformed enumeration.
                return declinedUnsupported(tokens: tokens, from: triggerIndex, to: max(cursor, triggerIndex + 1))
            }

            // Uncertainty directly attached to any single member declines
            // the entire list -- omitting one charge could alter the record.
            let afterThisNumber = cursor + number.tokensConsumed
            if let hedgeEnd = matchNumberHedge(words: words, at: afterThisNumber) {
                return Candidate(
                    startToken: triggerIndex,
                    endToken: hedgeEnd,
                    range: span(tokens, triggerIndex, hedgeEnd - 1),
                    outcome: .declined(.unresolvedUncertainty, "a listed provision was expressed with uncertainty")
                )
            }

            numbers.append(number)
            lastNumberStartToken = cursor
            cursor = afterThisNumber

            if cursor >= tokens.count {
                break
            }

            if WordTokenizer.hasComma(in: text, from: tokens[lastNumberStartToken].range, to: tokens[cursor].range) {
                // Comma may be followed directly by the next number, or by "and <number>".
                if words[cursor].lowercased() == "and" {
                    cursor += 1
                    continue // loop to parse the number after "and"
                }
                continue // loop to parse the next comma-separated number directly
            }

            let word = words[cursor].lowercased()
            if word == "and" {
                cursor += 1
                continue // parse the final number after "and"; loop condition below ends enumeration
            }
            if word == "to" {
                return declinedUnsupported(tokens: tokens, from: triggerIndex, to: min(cursor + 2, tokens.count), reason: "section range is not supported")
            }
            if word == "read", cursor + 1 < tokens.count, words[cursor + 1].lowercased() == "with" {
                return declinedUnsupported(tokens: tokens, from: triggerIndex, to: min(cursor + 4, tokens.count), reason: "'read with' is not supported")
            }
            // Nothing more connects -- enumeration ends here.
            break
        }

        guard numbers.count >= 2 else {
            // "sections <number>" alone with no proper conjunction/list --
            // a recognized-but-malformed plural, not a silent no-op.
            return declinedUnsupported(tokens: tokens, from: triggerIndex, to: cursor)
        }

        // Disambiguate the last item's trailing letter the same way the
        // singular path does -- it may be a suffix, or it may be the first
        // letter of the trailing statute mention.
        let lastIndex = numbers.count - 1
        let resolvedLast = resolveNumberAndStatute(numbers[lastIndex], numberStart: lastNumberStartToken, words: words, vocabulary: vocabulary)
        if resolvedLast.number.tokensConsumed != numbers[lastIndex].tokensConsumed {
            numbers[lastIndex] = resolvedLast.number
            cursor = lastNumberStartToken + resolvedLast.number.tokensConsumed
        }
        // A multi-provision reference requires a statute in Phase 3C -- no
        // approved bare-list canonical form exists for a statute-less list.
        let statute: StatuteRecognizer.Match
        switch resolvedLast.resolution {
        case let .found(match):
            statute = match
        case .ambiguousFragment:
            // Phase 3F.A: same fragmented-statute ambiguity as the singular
            // path, on the list's last member -- decline the whole list
            // rather than apply a partial one.
            return declinedUnsupported(tokens: tokens, from: triggerIndex, to: cursor, reason: "statute abbreviation appears fragmented", kind: .unresolvedUncertainty)
        case .none:
            return declinedUnsupported(tokens: tokens, from: triggerIndex, to: cursor, reason: "multi-provision list without a statute is not supported")
        }
        let afterStatute = cursor + statute.tokensConsumed
        if let hedgeEnd = matchStatuteHedge(words: words, at: afterStatute, vocabulary: vocabulary) {
            return Candidate(
                startToken: triggerIndex,
                endToken: hedgeEnd,
                range: span(tokens, triggerIndex, hedgeEnd - 1),
                outcome: .declined(.unresolvedUncertainty, "statute expressed with uncertainty")
            )
        }
        let reference = StatutoryProvisionReference(
            provisionNumbers: numbers.map(\.formatted),
            statute: statute.citationForm,
            range: span(tokens, triggerIndex, afterStatute - 1)
        )
        return Candidate(startToken: triggerIndex, endToken: afterStatute, range: span(tokens, triggerIndex, afterStatute - 1), outcome: .applied(reference))
    }

    /// Phase 3F.A: the three genuinely different outcomes of suffix/statute
    /// disambiguation. `.ambiguousFragment` is new -- previously, when
    /// neither interpretation below found a statute, the function silently
    /// defaulted to keeping the suffix. That default is unsafe when what
    /// follows plausibly continues as a fragmented statute abbreviation
    /// (see `StatuteRecognizer.looksLikeFragmentedAlias`); this case must
    /// decline instead of guessing either interpretation.
    private enum StatuteResolution {
        case found(StatuteRecognizer.Match)
        case none
        case ambiguousFragment
    }

    /// Disambiguates a number's trailing single-letter suffix against an
    /// immediately-following statute mention (see `matchSingular`'s doc
    /// comment). Tries the eager suffix interpretation first; falls back to
    /// treating the letter as part of the statute only if that's the
    /// interpretation that actually finds one.
    private static func resolveNumberAndStatute(
        _ number: SpokenNumberParser.ParsedNumber, numberStart: Int, words: [String], vocabulary: ResolvedRecognitionVocabulary?
    ) -> (number: SpokenNumberParser.ParsedNumber, resolution: StatuteResolution) {
        let cursorWithSuffix = numberStart + number.tokensConsumed
        if let statute = StatuteRecognizer.match(tokens: words, startingAt: cursorWithSuffix, vocabulary: vocabulary) {
            return (number, .found(statute))
        }
        if let suffix = number.letterSuffix {
            let stripped = number.withoutSuffix
            let cursorWithoutSuffix = numberStart + stripped.tokensConsumed
            if let statute = StatuteRecognizer.match(tokens: words, startingAt: cursorWithoutSuffix, vocabulary: vocabulary) {
                return (stripped, .found(statute))
            }
            // Neither interpretation found a statute. Before defaulting to
            // "keep the suffix," check whether what follows the letter
            // plausibly continues as a fragmented statute abbreviation.
            let lookaheadStart = numberStart + number.tokensConsumed
            let lookahead = Array(words[min(lookaheadStart, words.count)...].prefix(6))
            if StatuteRecognizer.looksLikeFragmentedAlias(leadingLetter: suffix, followingTokens: lookahead, vocabulary: vocabulary) {
                return (number, .ambiguousFragment)
            }
        }
        return (number, .none)
    }

    /// Parses a number starting at `cursor`, truncated at the first comma
    /// (in the original text) that falls within its digit-word run. Without
    /// this, two adjacent pure-digit-word list members separated only by a
    /// comma ("three two three, three four one") would be indistinguishable
    /// from a single longer number to `SpokenNumberParser`, which has no
    /// concept of punctuation.
    private static func parseNumberRespectingCommaBoundary(
        tokens: [WordToken], words: [String], text: String, at cursor: Int
    ) -> SpokenNumberParser.ParsedNumber? {
        guard let raw = SpokenNumberParser.parse(tokens: words, startingAt: cursor) else { return nil }
        guard raw.digitsTokensConsumed > 1 else { return raw }
        for offset in 1..<raw.digitsTokensConsumed
            where WordTokenizer.hasComma(in: text, from: tokens[cursor + offset - 1].range, to: tokens[cursor + offset].range) {
            let truncated = Array(words[cursor..<(cursor + offset)])
            return SpokenNumberParser.parse(tokens: truncated, startingAt: 0)
        }
        return raw
    }

    private static func declinedUnsupported(
        tokens: [WordToken], from start: Int, to end: Int, reason: String = "unsupported statutory structure", kind: DeclineReason = .unsupportedStructure
    ) -> Candidate {
        let clampedEnd = max(min(end, tokens.count), start + 1)
        return Candidate(startToken: start, endToken: clampedEnd, range: span(tokens, start, clampedEnd - 1), outcome: .declined(kind, reason))
    }

    // MARK: - Hedge / uncertainty detection (structurally local only)

    /// "<number>, or possibly <number>" / "<number>, or was it <number>" --
    /// consumes through the alternative candidate so the whole ambiguity is
    /// captured in the declined span.
    private static func matchNumberHedge(words: [String], at index: Int) -> Int? {
        guard index < words.count, hedgeConnectors.contains(words[index].lowercased()) else { return nil }
        var cursor = index + 1
        while cursor < words.count, confirmatoryContinuations.contains(words[cursor].lowercased()) {
            cursor += 1
        }
        guard let alt = SpokenNumberParser.parse(tokens: words, startingAt: cursor) else { return nil }
        return cursor + alt.tokensConsumed
    }

    /// "<statute>, or possibly <statute>" -- same local-attachment shape as
    /// the number hedge, but the alternative is a statute mention.
    private static func matchStatuteHedge(words: [String], at index: Int, vocabulary: ResolvedRecognitionVocabulary?) -> Int? {
        guard index < words.count, hedgeConnectors.contains(words[index].lowercased()) else { return nil }
        var cursor = index + 1
        while cursor < words.count, confirmatoryContinuations.contains(words[cursor].lowercased()) {
            cursor += 1
        }
        guard let altStatute = StatuteRecognizer.match(tokens: words, startingAt: cursor, vocabulary: vocabulary) else { return nil }
        return cursor + altStatute.tokensConsumed
    }

    /// "... <statute> and <bare number>[ <statute>]" -- a second number with
    /// no "section" keyword of its own. Never infer the omitted keyword;
    /// this always declines the combined structure.
    private static func matchAmbiguousBareContinuation(words: [String], at index: Int, vocabulary: ResolvedRecognitionVocabulary?) -> Int? {
        guard index < words.count, words[index].lowercased() == "and" else { return nil }
        let numberStart = index + 1
        guard let number = SpokenNumberParser.parse(tokens: words, startingAt: numberStart) else { return nil }
        var end = numberStart + number.tokensConsumed
        if let statute = StatuteRecognizer.match(tokens: words, startingAt: end, vocabulary: vocabulary) {
            end += statute.tokensConsumed
        }
        return end
    }

    /// A token immediately after a parsed number that itself signals the
    /// number expression continues in a form this candidate should not
    /// commit to. Two cases:
    ///   - "hundred" (Phase 3F.A), optionally followed by "and" and more
    ///     digit/tens words, e.g. "hundred and twenty three" -- unsupported
    ///     cardinal-number continuation, deliberately not implemented.
    ///   - Phase 3F.B: the token is itself another recognizable digit/tens
    ///     word. `SpokenNumberParser`'s grouped shape is deliberately
    ///     bounded (at most one tens-word plus one digit on each side) and
    ///     never re-enters itself, so it can stop short of real adjacent
    ///     numeric content rather than the number having naturally ended.
    ///     A pure digit-by-digit parse can never leave such a token
    ///     immediately adjacent (it already consumes every consecutive
    ///     digit/tens word), so this branch only ever fires for the bounded
    ///     grouped shape -- exactly where the grammar intentionally stopped
    ///     short rather than guessing further.
    /// Neither branch implements the continuation -- both only identify how
    /// far it extends, for the declined span; the decline itself is what
    /// keeps the original text unchanged regardless of exactly how much of
    /// the continuation this consumes.
    private static func matchUnsupportedNumberContinuation(words: [String], at index: Int) -> Int? {
        guard index < words.count else { return nil }

        if words[index].lowercased() == "hundred" {
            var cursor = index + 1
            if let more = SpokenNumberParser.parse(tokens: words, startingAt: cursor) {
                cursor += more.tokensConsumed
            } else if cursor < words.count, words[cursor].lowercased() == "and" {
                var afterAnd = cursor + 1
                if let more = SpokenNumberParser.parse(tokens: words, startingAt: afterAnd) {
                    afterAnd += more.tokensConsumed
                }
                cursor = afterAnd
            }
            return cursor
        }

        if let more = SpokenNumberParser.parse(tokens: words, startingAt: index) {
            return index + more.tokensConsumed
        }
        return nil
    }

    /// "read with ..." or "sub section <number>" immediately following a
    /// citation -- recognized, unsupported structures. Consumes as much of
    /// the trailing content as forms a citation-like continuation so the
    /// main scan never re-processes it as an independent candidate.
    private static func matchUnsupportedContinuation(tokens: [WordToken], words: [String], at index: Int, vocabulary: ResolvedRecognitionVocabulary?) -> Int? {
        guard index < words.count else { return nil }
        let word = words[index].lowercased()

        if word == "read", index + 1 < words.count, words[index + 1].lowercased() == "with" {
            var cursor = index + 2
            if cursor < words.count, words[cursor].lowercased() == "section" {
                cursor += 1
                if let number = SpokenNumberParser.parse(tokens: words, startingAt: cursor) {
                    cursor += number.tokensConsumed
                    if let statute = StatuteRecognizer.match(tokens: words, startingAt: cursor, vocabulary: vocabulary) {
                        cursor += statute.tokensConsumed
                    }
                }
            }
            return cursor
        }

        if word == "sub", index + 1 < words.count, words[index + 1].lowercased() == "section" {
            var cursor = index + 2
            if let number = SpokenNumberParser.parse(tokens: words, startingAt: cursor) {
                cursor += number.tokensConsumed
            }
            return cursor
        }
        if word == "subsection" {
            var cursor = index + 1
            if let number = SpokenNumberParser.parse(tokens: words, startingAt: cursor) {
                cursor += number.tokensConsumed
            }
            return cursor
        }

        return nil
    }

    private static func span(_ tokens: [WordToken], _ startToken: Int, _ endToken: Int) -> NSRange {
        let start = tokens[startToken].range
        let end = tokens[min(endToken, tokens.count - 1)].range
        return NSRange(location: start.location, length: (end.location + end.length) - start.location)
    }

    // MARK: - Applying candidates to text (exact-span replacement only)

    private static func build(candidates: [Candidate], text: String) -> NormalizationPassResult {
        var applied: [AppliedNormalizationChange] = []
        var declined: [DeclinedNormalization] = []
        let nsText = text as NSString
        var resultText = text as NSString

        // Apply from the end of the string backward so earlier ranges stay valid.
        for candidate in candidates.sorted(by: { $0.range.location > $1.range.location }) {
            let original = nsText.substring(with: candidate.range)
            switch candidate.outcome {
            case let .applied(reference):
                let replacement = StatutoryProvisionRenderer.renderDefault(reference)
                resultText = resultText.replacingCharacters(in: candidate.range, with: replacement) as NSString
                applied.append(
                    AppliedNormalizationChange(trigger: original, replacement: replacement, sourcePackID: "phase3.statutoryProvision", pass: .statutoryProvision, range: candidate.range)
                )
            case let .declined(reason, detail):
                declined.append(
                    DeclinedNormalization(trigger: original, candidates: [], reason: "\(reason.rawValue): \(detail)", pass: .statutoryProvision, range: candidate.range)
                )
            }
        }

        return NormalizationPassResult(text: resultText as String, appliedChanges: applied, declinedChanges: declined)
    }
}
