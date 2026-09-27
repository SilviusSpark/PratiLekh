import Foundation

struct ErrorRate: Codable, Equatable {
    let edits: Int
    let referenceLength: Int

    /// nil when the reference is empty (a rate is undefined).
    var rate: Double? {
        self.referenceLength == 0 ? nil : Double(self.edits) / Double(self.referenceLength)
    }
}

/// General transcription accuracy. Comparison is case-insensitive and ignores
/// punctuation (formatting is scored separately).
enum TextMetrics {
    static func normalizedWords(_ text: String) -> [String] {
        var mapped = ""
        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                mapped.unicodeScalars.append(scalar)
            } else if scalar == "'" || scalar == "\u{2019}" {
                continue
            } else {
                mapped.append(" ")
            }
        }
        return mapped.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func wer(reference: String, hypothesis: String) -> ErrorRate {
        let ref = self.normalizedWords(reference)
        let hyp = self.normalizedWords(hypothesis)
        return ErrorRate(edits: self.editDistance(ref, hyp), referenceLength: ref.count)
    }

    static func cer(reference: String, hypothesis: String) -> ErrorRate {
        let ref = Array(self.normalizedWords(reference).joined(separator: " "))
        let hyp = Array(self.normalizedWords(hypothesis).joined(separator: " "))
        return ErrorRate(edits: self.editDistance(ref, hyp), referenceLength: ref.count)
    }

    static func editDistance<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        var previous = Array(0...rhs.count)
        for (i, left) in lhs.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: rhs.count)
            for (j, right) in rhs.enumerated() {
                let substitution = previous[j] + (left == right ? 0 : 1)
                current[j + 1] = min(substitution, previous[j + 1] + 1, current[j] + 1)
            }
            previous = current
        }
        return previous[rhs.count]
    }
}

/// Punctuation / capitalization differences between a final text and the
/// intended final text, counted only when the two contain the same words.
struct FormattingScore: Codable, Equatable {
    let comparable: Bool
    let tokenCount: Int
    let caseDifferences: Int
    let punctuationDifferences: Int
}

enum FormattingMetrics {
    static func score(intended: String, actual: String) -> FormattingScore {
        let intendedTokens = intended.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let actualTokens = actual.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard intendedTokens.count == actualTokens.count,
              zip(intendedTokens, actualTokens).allSatisfy({ self.core($0).lowercased() == self.core($1).lowercased() })
        else {
            return FormattingScore(comparable: false, tokenCount: intendedTokens.count, caseDifferences: 0, punctuationDifferences: 0)
        }
        var caseDifferences = 0
        var punctuationDifferences = 0
        for (want, got) in zip(intendedTokens, actualTokens) {
            if self.core(want) != self.core(got) { caseDifferences += 1 }
            if self.punctuation(want) != self.punctuation(got) { punctuationDifferences += 1 }
        }
        return FormattingScore(
            comparable: true,
            tokenCount: intendedTokens.count,
            caseDifferences: caseDifferences,
            punctuationDifferences: punctuationDifferences
        )
    }

    private static func core(_ token: String) -> String {
        String(token.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func punctuation(_ token: String) -> String {
        String(token.unicodeScalars.filter { !CharacterSet.alphanumerics.contains($0) })
    }
}
