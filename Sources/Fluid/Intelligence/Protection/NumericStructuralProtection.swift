import Foundation

/// Category-agnostic protection of NUMERIC STRUCTURE in a text: the digit runs
/// and the punctuation/whitespace that sits between numerals. It never asks
/// what a number *means* -- a date, an amount, a statute, a case number, an
/// exhibit and a room number are all just digits -- and it involves no model,
/// no lexicon and no per-category pattern.
///
/// Why it exists (V1.12): `IntelligenceEditClassifier` lets Intelligence
/// autonomously apply punctuation-only and whitespace-only edits, and such an
/// edit inside or between numerals changes the number (`Rs. 5,000` -> `Rs. 5.000`,
/// `12.07.2026` -> `12072026`, `12 34` -> `1234`). Category recognizers proved
/// brittle on unseen forms; a digit-structure signal does not depend on form.
///
/// The rule:
///   1. A *digit* is a Unicode scalar of general category `Nd` in ANY script
///      (Latin, Odia, Devanagari, Arabic-Indic, fullwidth, mathematical, ...).
///      `No`/`Nl` numeric characters (`½`, `²`, `Ⅻ`) are not digits: a
///      deliberate, documented gap.
///   2. A *digit run* is a maximal sequence of consecutive digits.
///   3. Two consecutive digit runs join into ONE span when the *gap* between
///      them contains no letter (category `L*`), no combining mark (`M*`) and no
///      line break (`U+000A`-`U+000D`, `U+0085`, `U+2028`, `U+2029`). Anything
///      else may appear in a gap: spaces, tabs, no-break spaces, punctuation,
///      symbols, currency signs, format characters.
///   4. A span runs from the first digit of its first run to the last digit of
///      its last run, and is `.independentlyProtected`.
///
/// **Whitespace-separated numerals are one span (rule 3).** Deleting the
/// whitespace between `12 34` merges the numerals and changes the value, and a
/// whitespace-only edit is autonomously acceptable, so the gap must be inside the
/// span. The same reasoning covers punctuation-and-space gaps (`2026. 5` ->
/// `2026.5`). The cost is that a legitimate collapse of a double space between
/// two numerals is demoted to review -- deliberate, small.
///
/// Boundaries, by the Safety Authority's existing intersection semantics: an edit
/// touching a span only at its edge (a zero-length insertion immediately before
/// the first digit or after the last digit) is NOT inside it; one strictly inside
/// (including a gap) is. Letters and whitespace attached to a run from outside
/// (`12th`, `Rs.`) are deliberately unprotected: their edits cannot change digit
/// structure.
///
/// Output is a pure, deterministic function of the text: spans are in ascending
/// UTF-16 order, non-overlapping and never adjacent (adjacent runs would be one
/// run), and re-protecting a span's own text yields exactly that span.
enum NumericStructuralProtection {
    /// The independent spans for `text`, in UTF-16 coordinates of `text`.
    static func spans(in text: String) -> [ProtectedSpan] {
        var result: [ProtectedSpan] = []
        var pending: (start: Int, end: Int)?
        var gapBroken = false
        var offset = 0

        func close() {
            if let pending {
                result.append(ProtectedSpan(range: NSRange(location: pending.start, length: pending.end - pending.start), kind: .independentlyProtected))
            }
        }

        for scalar in text.unicodeScalars {
            let width = scalar.utf16.count
            if self.isDigit(scalar) {
                if let current = pending, !gapBroken {
                    pending = (current.start, offset + width)
                } else {
                    close()
                    pending = (offset, offset + width)
                }
                gapBroken = false
            } else if pending != nil, self.breaksGap(scalar) {
                gapBroken = true
            }
            offset += width
        }
        close()
        return result
    }

    /// A decimal digit of any script.
    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.generalCategory == .decimalNumber
    }

    /// Whether `scalar` ends the run of numerals a gap may connect: a letter,
    /// a combining mark, or a line break.
    private static func breaksGap(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark:
            return true
        default:
            break
        }
        switch scalar.value {
        case 0x000A...0x000D, 0x0085, 0x2028, 0x2029:
            return true
        default:
            return false
        }
    }
}

extension NormalizationProtectedSpans {
    /// The V1.11-derived normalization spans together with the numeric-structure
    /// spans of the SAME text (`normalizedText`), so the two can never be paired
    /// with different sources. Composition is plain concatenation: overlaps
    /// (e.g. the digits inside a resolved `Section 302 IPC`) are resolved by the
    /// Safety Authority's existing most-restrictive-wins rule, and the Authority
    /// is unchanged.
    var spansIncludingNumericStructure: [ProtectedSpan] {
        self.spans + NumericStructuralProtection.spans(in: self.normalizedText)
    }
}
