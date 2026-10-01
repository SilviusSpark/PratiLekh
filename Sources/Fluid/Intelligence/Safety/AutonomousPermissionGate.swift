import Foundation

/// Every way `AutonomousPermissionGate` can decline to trust an edit
/// `IntelligenceEditClassifier` already classified as one of the three
/// autonomous categories. One case per validated V1.14/V1.15 invariant, so
/// tests assert exactly which rule fired -- never merely that an edit was or
/// was not blocked.
enum AutonomousPermissionBlock: Equatable {
    /// Punctuation-only edit (P-A): a changed punctuation run contains a
    /// character outside the routine sentence-punctuation set.
    case nonRoutinePunctuationChanged
    /// Punctuation-only edit (P-B): a changed punctuation run sits between
    /// two word-forming scalars -- inside a word/identifier/abbreviation,
    /// not between sentence elements.
    case intraTokenPunctuationChanged
    /// Whitespace-only edit (W-A1, merge-only): the edit removes the last
    /// whitespace between two word-forming scalars, merging two tokens.
    /// Splitting a token is deliberately NOT blocked (out of scope; see
    /// `Evaluation/Intelligence/V1_14_AUTONOMOUS_EDIT_POLICY_FINDINGS.md`).
    case wordBoundaryMerged
    /// Capitalization-only edit (C-A2): an uppercase letter is lowered
    /// inside a token that contains at least two uppercase letters (an
    /// acronym-shaped token, e.g. `IPC`, `CrPC`).
    case acronymCapitalizationLowered
    /// Capitalization-only edit (C-C): a letter's case changes inside a
    /// token that also contains a decimal digit (an alphanumeric
    /// identifier, e.g. `P9`).
    case identifierCapitalizationChanged
}

/// The deterministic autonomous-permission gate: whether an edit
/// `IntelligenceEditClassifier` already classified as safe should actually
/// be trusted to apply without review, given the text immediately
/// surrounding it. Classification answers "what shape is this edit?"; this
/// type answers "does structural context make that shape unsafe here?" --
/// a distinct question, deliberately kept out of the classifier (which has
/// no access to surrounding text at all) and out of the model-facing
/// contract (the model is never asked about this).
///
/// Implements exactly the five-rule bundle validated in
/// `Evaluation/Intelligence/V1_14_AUTONOMOUS_EDIT_POLICY_FINDINGS.md` and
/// re-validated on fresh data in
/// `Evaluation/Intelligence/V1_15_FRESH_AUTONOMOUS_POLICY_VALIDATION.md`
/// (`core-merge-only+P-A`: P-A, P-B, W-A1, C-A2, C-C). Deliberately does
/// NOT implement split-blocking, a residual-punctuation lexicon, or any
/// single-letter-designator handling -- those were evaluated and are
/// explicitly out of scope (too costly, or would repeat a rejected
/// per-category-lexicon pattern).
///
/// No model, no lexicon, no category recognition: every rule is a
/// structural property of Unicode general categories only.
enum AutonomousPermissionGate {
    /// A resource bound only -- never a permissiveness threshold. Every rule
    /// below seeks the TRUE structural boundary (the first scalar outside
    /// its own matching class), which for any real word, punctuation run, or
    /// whitespace gap in judicial dictation is always a handful of scalars
    /// away. This bound exists only so a pathological or adversarial
    /// `source` cannot force unbounded work per proposal; if the true
    /// boundary is not found within this many scalars, the scan gives up
    /// and every caller below treats that as "the boundary is unknown" --
    /// which always maps to a block, never to permission.
    private static let maxBoundaryScan = 64

    private static let routinePunctuation: Set<Unicode.Scalar> = [".", ",", ";", ":", "?", "!", "\u{0964}"]

    /// `range` is the proposal's already-validated range in `source`, as a
    /// `Range<String.Index>` -- the caller (`IntelligenceSafetyAuthority`)
    /// already computed this exact index range at an earlier step; passing
    /// it through (rather than an `NSRange` the gate would have to convert
    /// again) avoids a second O(range.location) index conversion per
    /// proposal.
    ///
    /// Returns `nil` when the edit's autonomous claim should be trusted;
    /// otherwise the specific rule that says it should not be.
    /// `classification` must not be `.other` -- the gate is never consulted
    /// for it (an edit outside all three autonomous categories is already
    /// rejected before classification-specific policy is relevant); passing
    /// `.other` defensively returns `nil` rather than crashing, but callers
    /// must not rely on that.
    static func block(
        classification: IntelligenceEditClassification,
        source: String,
        range: Range<String.Index>,
        expectedSourceText: String,
        replacementText: String
    ) -> AutonomousPermissionBlock? {
        switch classification {
        case .punctuationOnly:
            return self.punctuationBlock(source: source, range: range, expectedSourceText: expectedSourceText, replacementText: replacementText)
        case .whitespaceOnly:
            return self.whitespaceBlock(source: source, range: range, expectedSourceText: expectedSourceText, replacementText: replacementText)
        case .capitalizationOnly:
            return self.capitalizationBlock(source: source, range: range, expectedSourceText: expectedSourceText, replacementText: replacementText)
        case .other:
            return nil
        }
    }

    // MARK: - Character classes (matching categories already established by
    // IntelligenceEditClassifier/NumericStructuralProtection for the same concepts)

    private static func isWordForming(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }

    private static func isPunctuationScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    /// Non-newline whitespace -- the classifier's own notion of "whitespace"
    /// for the whitespace-only category (see
    /// `IntelligenceEditClassifier.isWhitespaceOnlyEdit`: it never treats a
    /// newline-introducing edit as whitespace-only in the first place, so a
    /// newline immediately adjacent to the edit is never mergeable content).
    /// The exact scalar set matches `NumericStructuralProtection`'s line-break
    /// set, for consistency across the two production types.
    private static func isMergeableWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        guard scalar.properties.isWhitespace else { return false }
        switch scalar.value {
        case 0x000A...0x000D, 0x0085, 0x2028, 0x2029: return false
        default: return true
        }
    }

    // MARK: - Bounded, boundary-directed scanning

    private struct ScanResult {
        /// Matching scalars found, in document order, nearest-to-the-edit
        /// last... no: in document order overall (left scans are reversed
        /// back into document order before being returned).
        let scalars: [Unicode.Scalar]
        /// The first non-matching scalar encountered (not included in
        /// `scalars`), or `nil` if the start/end of `source` was reached
        /// first. Always `nil` when `exceededBound` is true.
        let boundaryScalar: Unicode.Scalar?
        /// True iff `maxBoundaryScan` matching scalars were found without
        /// ever reaching a non-matching scalar or the start/end of `source`.
        /// Every rule below treats this as "the boundary could not be
        /// established" and blocks, never as "no boundary exists."
        let exceededBound: Bool
    }

    /// Scans outward from `start` in `source.unicodeScalars`, in `direction`
    /// (`-1` = backward from `start`, exclusive; `+1` = forward from `start`,
    /// inclusive), collecting scalars while `matches` holds. Each step is a
    /// single adjacent-index move (`index(before:)`/`index(after:)`), so the
    /// cost is proportional only to how far the actual matching run extends
    /// -- never to the length of `source` -- up to `maxBoundaryScan`.
    private static func scan(
        _ source: String,
        from start: String.Index,
        direction: Int,
        matches: (Unicode.Scalar) -> Bool
    ) -> ScanResult {
        let scalars = source.unicodeScalars
        var collected: [Unicode.Scalar] = []
        var index = start
        while collected.count < self.maxBoundaryScan {
            if direction < 0 {
                guard index > scalars.startIndex else { return ScanResult(scalars: collected.reversed(), boundaryScalar: nil, exceededBound: false) }
                index = scalars.index(before: index)
                let scalar = scalars[index]
                guard matches(scalar) else { return ScanResult(scalars: collected.reversed(), boundaryScalar: scalar, exceededBound: false) }
                collected.append(scalar)
            } else {
                guard index < scalars.endIndex else { return ScanResult(scalars: collected, boundaryScalar: nil, exceededBound: false) }
                let scalar = scalars[index]
                index = scalars.index(after: index)
                guard matches(scalar) else { return ScanResult(scalars: collected, boundaryScalar: scalar, exceededBound: false) }
                collected.append(scalar)
            }
        }
        return ScanResult(scalars: [], boundaryScalar: nil, exceededBound: true)
    }

    // MARK: - W-A1: merge-only whitespace blocking

    /// `tokens` are the individual non-whitespace scalars of `scalars`, in
    /// order (a proposal may span more than one word, e.g. a whole
    /// `"Ram Das"` -> `"RamDas"` replacement, not just a single gap); `gaps`
    /// has exactly `tokens.count + 1` entries, `gaps[i]` being the whitespace
    /// immediately before `tokens[i]` (`gaps[0]` is leading whitespace,
    /// `gaps[tokens.count]` trailing). Matches the token/gap model already
    /// validated experimentally, just scalar-based.
    private static func scalarGaps(_ scalars: [Unicode.Scalar]) -> (tokens: [Unicode.Scalar], gaps: [[Unicode.Scalar]]) {
        var tokens: [Unicode.Scalar] = []
        var gaps: [[Unicode.Scalar]] = [[]]
        for scalar in scalars {
            if self.isMergeableWhitespace(scalar) {
                gaps[gaps.count - 1].append(scalar)
            } else {
                tokens.append(scalar)
                gaps.append([])
            }
        }
        return (tokens, gaps)
    }

    /// A merge: some whitespace GAP anywhere in the edit -- not only at its
    /// own outer boundary, since a single proposal may replace an entire
    /// `"Word1 Word2"` span at once, moving the gap being closed into the
    /// interior of `expectedSourceText`/`replacementText` -- goes from
    /// non-empty to fully empty, with a word-forming scalar immediately on
    /// each side. The outer two gaps are extended into the surrounding,
    /// untouched `source` (via the bounded scan) so a proposal that targets
    /// only part of a gap, or a zero-length insertion at a word boundary,
    /// is judged by the TRUE flanking scalar, not just what's inside the
    /// proposal's own text. Splitting (the reverse transition) is
    /// deliberately never blocked here.
    private static func whitespaceBlock(
        source: String, range: Range<String.Index>, expectedSourceText: String, replacementText: String
    ) -> AutonomousPermissionBlock? {
        let left = self.scan(source, from: range.lowerBound, direction: -1, matches: self.isMergeableWhitespace)
        guard !left.exceededBound else { return .wordBoundaryMerged }
        let right = self.scan(source, from: range.upperBound, direction: +1, matches: self.isMergeableWhitespace)
        guard !right.exceededBound else { return .wordBoundaryMerged }

        let originalScalars = left.scalars + Array(expectedSourceText.unicodeScalars) + right.scalars
        let editedScalars = left.scalars + Array(replacementText.unicodeScalars) + right.scalars
        let original = self.scalarGaps(originalScalars)
        let edited = self.scalarGaps(editedScalars)
        // Guaranteed equal by whitespace-only classification (the two
        // strings share the same non-whitespace scalars in the same order);
        // fails closed rather than indexing mismatched arrays if that
        // invariant were ever violated.
        guard original.tokens == edited.tokens, original.gaps.count == edited.gaps.count else { return .wordBoundaryMerged }

        for index in original.gaps.indices {
            let merges = !original.gaps[index].isEmpty && edited.gaps[index].isEmpty
            guard merges else { continue }
            // The leading gap's left flank, and the trailing gap's right
            // flank, are outside `tokens` entirely -- the scalar the outward
            // scan stopped on (`nil` at a document boundary, which is never
            // word-forming).
            let leftScalar: Unicode.Scalar? = index > 0 ? original.tokens[index - 1] : left.boundaryScalar
            let rightScalar: Unicode.Scalar? = index < original.tokens.count ? original.tokens[index] : right.boundaryScalar
            if let leftScalar, self.isWordForming(leftScalar), let rightScalar, self.isWordForming(rightScalar) {
                return .wordBoundaryMerged
            }
        }
        return nil
    }

    // MARK: - P-A, P-B: punctuation-only edits

    /// Scans outward from both edges of the edit for any punctuation
    /// immediately adjacent (which may belong to the same run as
    /// punctuation at the very edge of `expectedSourceText`/`replacementText`,
    /// if this proposal's span cuts through the middle of a longer run),
    /// then evaluates both punctuation rules against the union of what the
    /// edit touches.
    private static func punctuationBlock(
        source: String, range: Range<String.Index>, expectedSourceText: String, replacementText: String
    ) -> AutonomousPermissionBlock? {
        let left = self.scan(source, from: range.lowerBound, direction: -1, matches: self.isPunctuationScalar)
        guard !left.exceededBound else { return .nonRoutinePunctuationChanged }
        let right = self.scan(source, from: range.upperBound, direction: +1, matches: self.isPunctuationScalar)
        guard !right.exceededBound else { return .nonRoutinePunctuationChanged }

        // P-A: every punctuation scalar that participates in the changed
        // run(s) -- the untouched adjacent extension on each side, plus
        // expectedSourceText's and replacementText's own punctuation --
        // must be in the routine sentence-punctuation set.
        let touchedPunctuation = left.scalars
            + expectedSourceText.unicodeScalars.filter(self.isPunctuationScalar)
            + replacementText.unicodeScalars.filter(self.isPunctuationScalar)
            + right.scalars
        if touchedPunctuation.contains(where: { !self.routinePunctuation.contains($0) }) {
            return .nonRoutinePunctuationChanged
        }

        // P-B: the change is intra-token if the TRUE boundary scalar on each
        // side (found by extending through any adjacent punctuation this
        // edit's own span didn't fully cover) is word-forming. If a side
        // never leaves the punctuation run within expectedSourceText itself
        // (e.g. this proposal's span is empty on that side and the
        // immediately adjacent scalar is not punctuation), that side's
        // boundary is simply the immediately adjacent scalar -- already what
        // `left`/`right` report.
        if let leftBoundary = left.boundaryScalar, self.isWordForming(leftBoundary),
           let rightBoundary = right.boundaryScalar, self.isWordForming(rightBoundary) {
            return .intraTokenPunctuationChanged
        }
        return nil
    }

    // MARK: - C-A2, C-C: capitalization-only edits

    /// Capitalization-only means `expectedSourceText`/`replacementText` are
    /// equal in length and differ only by letter case, scalar for scalar
    /// (guaranteed by `IntelligenceEditClassifier.isCapitalizationOnlyEdit`).
    /// For each changed position, this finds the FULL enclosing token --
    /// extending outward past `expectedSourceText`'s own edges into the
    /// surrounding untouched `source` when the changed position's word-forming
    /// run reaches all the way to one of them -- and checks both rules
    /// against that token's content, matching the frozen invariants' own
    /// per-changed-position token derivation exactly, just computed locally
    /// and boundedly instead of over a whole reconstructed document.
    private static func capitalizationBlock(
        source: String, range: Range<String.Index>, expectedSourceText: String, replacementText: String
    ) -> AutonomousPermissionBlock? {
        let expected = Array(expectedSourceText.unicodeScalars)
        let replacement = Array(replacementText.unicodeScalars)
        guard expected.count == replacement.count else {
            // Not reachable for a genuine capitalization-only edit (case
            // mapping never changes scalar count for the letters this
            // contract cares about), but fail closed rather than index out
            // of bounds if that invariant were ever violated.
            return .acronymCapitalizationLowered
        }

        for position in expected.indices where expected[position] != replacement[position] {
            // The token's start/end WITHIN expectedSourceText, by scanning
            // inward-bounded (no outward extension needed yet).
            var start = position
            while start > 0, self.isWordForming(expected[start - 1]) { start -= 1 }
            var end = position
            while end + 1 < expected.count, self.isWordForming(expected[end + 1]) { end += 1 }

            var token = Array(expected[start...end])
            if start == 0, self.isWordForming(expected[0]) {
                let left = self.scan(source, from: range.lowerBound, direction: -1, matches: self.isWordForming)
                guard !left.exceededBound else { return .acronymCapitalizationLowered }
                token = left.scalars + token
            }
            if end == expected.count - 1, self.isWordForming(expected[expected.count - 1]) {
                let right = self.scan(source, from: range.upperBound, direction: +1, matches: self.isWordForming)
                guard !right.exceededBound else { return .acronymCapitalizationLowered }
                token += right.scalars
            }

            let lowering = expected[position].properties.isUppercase && replacement[position].properties.isLowercase
            if lowering, token.filter({ $0.properties.isUppercase }).count >= 2 {
                return .acronymCapitalizationLowered
            }
            if token.contains(where: { $0.properties.generalCategory == .decimalNumber }) {
                return .identifierCapitalizationChanged
            }
        }
        return nil
    }
}
