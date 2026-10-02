import Foundation

/// Intelligence V1.27 -- Model Comparison Development Corpus & Protocol.
///
/// Contamination guard between the development material and the frozen V1.23 benchmark. This is
/// the ONLY file in the comparison tooling that touches the frozen benchmark, and only to compare
/// text deterministically; no model ever sees either corpus here.
///
/// **Prohibited overlap** (a subject is a development entry or a stored-hazard-fixture text; any
/// match against any frozen entry is a violation):
///   - P1  exact raw-text equality;
///   - P2  equality after folding (lower-case, every non-letter/digit run collapsed to one space);
///   - P3  an expected correction `(source, replacement)` pair exactly equal to a frozen pair;
///   - P4  reuse of a frozen personal-name token (tokens of the replacement of every frozen
///         capitalization-only correction whose replacement is a capitalized name);
///   - P5  any shared run of four consecutive folded words;
///   - P6  near-duplication: normalized edit similarity of the folded texts >= 0.80;
///   - P7  reuse of a frozen digit-bearing token (identifiers, amounts, dates, numbers).
/// **Allowed:** shared domain vocabulary (statute acronyms, ordinary legal words, common sentence
/// frames shorter than four words). Dev-internal exact/folded duplicates are also reported.
enum ComparisonOverlap {
    static let ngramLength = 4
    static let nearDuplicateThreshold = 0.80

    enum Rule: String, CaseIterable {
        case exactText = "P1"
        case foldedText = "P2"
        case correctionPair = "P3"
        case nameToken = "P4"
        case fourGram = "P5"
        case nearDuplicate = "P6"
        case digitToken = "P7"
    }

    struct Subject {
        let id: String
        let text: String
        let corrections: [CapabilityCorpus.Correction]
        /// Expectation class (e.g. correction-warranted vs abstention-expected). Matched minimal pairs
        /// (a warranted entry and its already-correct control) are intentional and fold to the same text;
        /// only same-group folded duplicates count as internal duplicates.
        var group: String = ""
    }

    struct Violation: Equatable {
        let subjectID: String
        let against: String
        let rule: Rule
        let detail: String
    }

    // MARK: - Folding

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func folded(_ text: String) -> String {
        self.tokens(text).joined(separator: " ")
    }

    static func ngrams(_ tokens: [String], length: Int) -> Set<String> {
        guard tokens.count >= length else { return [] }
        return Set((0...(tokens.count - length)).map { tokens[$0..<($0 + length)].joined(separator: " ") })
    }

    /// Normalized edit similarity in [0, 1]: 1 - distance / max length (characters).
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a)
        let y = Array(b)
        if x.isEmpty || y.isEmpty {
            return x.isEmpty && y.isEmpty ? 1 : 0
        }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var current = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return 1 - Double(previous[y.count]) / Double(max(x.count, y.count))
    }

    // MARK: - Frozen reference sets

    /// Tokens of the replacement of every frozen capitalization-only correction that is a capitalized name.
    static func frozenNameTokens(_ frozen: [CapabilityCorpus.Entry]) -> Set<String> {
        var names = Set<String>()
        for entry in frozen {
            for correction in entry.expectedCorrections where correction.replacement != correction.source {
                guard correction.replacement.lowercased() == correction.source.lowercased() else { continue }
                let words = correction.replacement.split(separator: " ")
                guard !words.isEmpty, words.allSatisfy({ $0.first?.isUppercase == true }) else { continue }
                names.formUnion(self.tokens(correction.replacement))
            }
        }
        return names
    }

    static func frozenDigitTokens(_ frozen: [CapabilityCorpus.Entry]) -> Set<String> {
        Set(frozen.flatMap { self.tokens($0.text) }.filter { $0.unicodeScalars.contains { $0.properties.generalCategory == .decimalNumber } })
    }

    // MARK: - Check

    static func check(subjects: [Subject], frozen: [CapabilityCorpus.Entry]) -> [Violation] {
        let names = self.frozenNameTokens(frozen)
        let digits = self.frozenDigitTokens(frozen)
        let frozenFolded = frozen.map { (entry: $0, folded: self.folded($0.text), grams: self.ngrams(self.tokens($0.text), length: self.ngramLength)) }
        var violations: [Violation] = []
        for subject in subjects {
            let subjectTokens = self.tokens(subject.text)
            let subjectFolded = subjectTokens.joined(separator: " ")
            let subjectGrams = self.ngrams(subjectTokens, length: self.ngramLength)
            for item in frozenFolded {
                if subject.text == item.entry.text {
                    violations.append(Violation(subjectID: subject.id, against: item.entry.id, rule: .exactText, detail: subject.text))
                } else if subjectFolded == item.folded {
                    violations.append(Violation(subjectID: subject.id, against: item.entry.id, rule: .foldedText, detail: subjectFolded))
                } else if self.similarity(subjectFolded, item.folded) >= self.nearDuplicateThreshold {
                    violations.append(Violation(subjectID: subject.id, against: item.entry.id, rule: .nearDuplicate, detail: "\(subjectFolded) ~ \(item.folded)"))
                }
                if let gram = subjectGrams.intersection(item.grams).sorted().first {
                    violations.append(Violation(subjectID: subject.id, against: item.entry.id, rule: .fourGram, detail: gram))
                }
                for correction in subject.corrections where item.entry.expectedCorrections.contains(correction) {
                    violations.append(Violation(subjectID: subject.id, against: item.entry.id, rule: .correctionPair, detail: "\(correction.source) -> \(correction.replacement)"))
                }
            }
            for token in Set(subjectTokens).intersection(names).sorted() {
                violations.append(Violation(subjectID: subject.id, against: "frozen-names", rule: .nameToken, detail: token))
            }
            for token in Set(subjectTokens).intersection(digits).sorted() {
                violations.append(Violation(subjectID: subject.id, against: "frozen-digit-tokens", rule: .digitToken, detail: token))
            }
        }
        return violations
    }

    /// Duplicates inside the development material itself: identical raw text anywhere, or identical
    /// folded text within the same expectation group (cross-group folded equality is a minimal pair).
    static func internalDuplicates(_ subjects: [Subject]) -> [Violation] {
        var rawSeen: [String: String] = [:]
        var foldedSeen: [String: String] = [:]
        var violations: [Violation] = []
        for subject in subjects {
            if let first = rawSeen[subject.text] {
                violations.append(Violation(subjectID: subject.id, against: first, rule: .exactText, detail: subject.text))
            } else {
                rawSeen[subject.text] = subject.id
            }
            let key = subject.group + "|" + self.folded(subject.text)
            if let first = foldedSeen[key] {
                violations.append(Violation(subjectID: subject.id, against: first, rule: .foldedText, detail: key))
            } else {
                foldedSeen[key] = subject.id
            }
        }
        return violations
    }
}
