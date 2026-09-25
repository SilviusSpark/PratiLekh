import Foundation

/// A single alphanumeric word and its exact location in the original text.
/// Shared by Phase 3's structured rules so each can scan text as tokens
/// while still performing exact-span replacement against the source string.
struct WordToken: Equatable {
    let text: String
    let range: NSRange
}

enum WordTokenizer {
    // swiftlint:disable:next force_try
    private static let pattern = try! NSRegularExpression(pattern: "[A-Za-z0-9]+")

    static func tokenize(_ text: String) -> [WordToken] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return pattern.matches(in: text, range: fullRange).map {
            WordToken(text: nsText.substring(with: $0.range), range: $0.range)
        }
    }

    /// True if a comma character appears anywhere between the end of one
    /// token and the start of another within the original text -- used to
    /// distinguish a plain "X and Y" pair from a comma-enumerated list.
    static func hasComma(in text: String, from startRange: NSRange, to endRange: NSRange) -> Bool {
        let nsText = text as NSString
        guard startRange.location + startRange.length <= endRange.location else { return false }
        let between = NSRange(
            location: startRange.location + startRange.length,
            length: endRange.location - (startRange.location + startRange.length)
        )
        return nsText.substring(with: between).contains(",")
    }
}
