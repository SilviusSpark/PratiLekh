import Foundation

/// The edit category `IntelligenceSafetyAuthority` itself derives from the
/// character-level difference between a proposal's `expectedSourceText` and
/// `replacementText`. This is the ONLY category the authority ever acts on
/// -- `IntelligenceProposal.claimedCategory` is diagnostic metadata and
/// grants no permission.
enum IntelligenceEditClassification: Equatable {
    case punctuationOnly
    case capitalizationOnly
    case whitespaceOnly
    /// Anything else: a lexical change, an edit that touches more than one
    /// of the safe dimensions at once (e.g. punctuation *and* whitespace
    /// together), a newline-introducing edit, or a no-op. Never
    /// autonomously eligible in V1.
    case other
}

enum IntelligenceEditClassifier {
    /// Independently derives what a proposed edit actually changes, wholly
    /// ignoring any category the proposal itself claims. Deliberately
    /// narrow per the committed V1 contract: autonomous scope is
    /// punctuation-only, capitalization-only, or whitespace-only, and
    /// nothing else -- see CLAUDE.md's "PratiLekh Intelligence architecture"
    /// section.
    static func classify(from expectedSourceText: String, to replacementText: String) -> IntelligenceEditClassification {
        // A proposal that changes nothing is not a safe surface edit -- it
        // is a no-op. `IntelligenceSafetyAuthority` rejects it explicitly
        // and earlier (`.noOpProposal`) than classification, but the
        // classifier itself never calls a no-op "safe" either, in case it
        // is ever consulted directly.
        guard expectedSourceText != replacementText else {
            return .other
        }

        if self.isPunctuationOnlyEdit(expectedSourceText, replacementText) {
            return .punctuationOnly
        }
        if self.isCapitalizationOnlyEdit(expectedSourceText, replacementText) {
            return .capitalizationOnly
        }
        if self.isWhitespaceOnlyEdit(expectedSourceText, replacementText) {
            return .whitespaceOnly
        }
        return .other
    }

    /// Punctuation-only: removing every Unicode-punctuation character (any
    /// `Character` where `isPunctuation` is true) from both strings makes
    /// them identical. Because that equality already requires every
    /// non-punctuation character (letters, digits, whitespace) to match
    /// exactly and in the same order, this single check already guarantees
    /// whitespace was not also touched -- an edit that changes punctuation
    /// *and* whitespace together therefore correctly falls through to
    /// `.other`, not `.punctuationOnly`.
    private static func isPunctuationOnlyEdit(_ expected: String, _ replacement: String) -> Bool {
        self.removing(from: expected, where: \.isPunctuation) == self.removing(from: replacement, where: \.isPunctuation)
    }

    /// Capitalization-only: case-folded (Unicode-aware `.lowercased()`, not
    /// ASCII-only), the two strings are identical. Case-folding is a no-op
    /// on punctuation, digits, and whitespace, so this single check already
    /// guarantees nothing else changed. Known, accepted limitation: exotic
    /// locale-specific casing behavior (e.g. Turkish dotless I) is not
    /// specially handled -- out of scope for this English/Indian-English
    /// legal-dictation contract.
    private static func isCapitalizationOnlyEdit(_ expected: String, _ replacement: String) -> Bool {
        expected.lowercased() == replacement.lowercased()
    }

    /// Whitespace-only: removing every Unicode-whitespace character from
    /// both strings makes them identical, and neither string contains a
    /// newline. Introducing a line/paragraph break is a deliberate,
    /// user-triggered concern (see CLAUDE.md's Phase 5 note), never an
    /// autonomous surface edit, even though it would otherwise satisfy the
    /// stripped-equality half of this predicate.
    private static func isWhitespaceOnlyEdit(_ expected: String, _ replacement: String) -> Bool {
        guard !expected.contains(where: \.isNewline), !replacement.contains(where: \.isNewline) else {
            return false
        }
        return self.removing(from: expected, where: \.isWhitespace) == self.removing(from: replacement, where: \.isWhitespace)
    }

    private static func removing(from text: String, where predicate: (Character) -> Bool) -> String {
        String(text.filter { !predicate($0) })
    }
}
