import Foundation

// Experimental research code: regex pattern tables and fixed-width report rows exceed the line limit.
// swiftlint:disable line_length

// EXPERIMENTAL -- Intelligence V1.12 investigation only. NOT production code
// and NOT a recommendation to ship these patterns: they exist so the
// investigation can MEASURE what a deterministic signal can and cannot do on
// the V1.12 corpus (see `V1_12_INDEPENDENT_PROTECTION_FINDINGS.md`). Nothing
// under `Sources/` references this file, and no `ProtectedSpan` is produced
// from it. Each detector is deliberately small and its signals are documented
// so failures are attributable to the signal, not to regex sprawl.

struct DetectionCandidate: Equatable {
    let category: String
    let range: NSRange
}

enum CandidateDetectors {
    // MARK: - Building blocks

    private static let month = #"(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?"#
    private static let ones = #"(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)"#
    private static let scale = #"(?:hundred|thousand|lakhs?|crores?)"#
    private static let numberWord = "(?:\(ones)|\(scale)|and)\\b"
    private static let numberWords = "\(numberWord)(?:[\\s-]+\(numberWord))*"
    private static let ordinalWord = #"(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|seventeenth|eighteenth|nineteenth|twentieth|twenty[\s-]first|twenty[\s-]second|twenty[\s-]third|twenty[\s-]fourth|twenty[\s-]fifth|twenty[\s-]sixth|twenty[\s-]seventh|twenty[\s-]eighth|twenty[\s-]ninth|thirtieth|thirty[\s-]first)"#
    private static let dayWord = "(?:\(ordinalWord)|\(ones)(?:[\\s-]+(?:one|two|three|four|five|six|seven|eight|nine))?)"
    private static let unit = #"(?:one|two|three|four|five|six|seven|eight|nine)"#
    private static let yearWords = "(?:two[\\s-]+thousand(?:[\\s-]+and)?(?:[\\s-]+\(ones)(?:[\\s-]+\(unit))?)?|(?:twenty|nineteen)[\\s-]+\(ones)(?:[\\s-]+\(unit))?)"
    private static let number = #"(?:\d{1,3}(?:,\d{2,3})+(?:\.\d+)?|\d+(?:\.\d+)?)"#
    private static let roman = #"(?:I{1,3}|IV|VI{0,3}|IX|X{1,2})"#

    // MARK: - Patterns per category (each: pattern, capture group holding the span, 0 = whole match)

    private static let patterns: [(category: String, pattern: String, group: Int, caseInsensitive: Bool)] = [
        // Dates: every pattern requires a numeric/number-word day or year ADJACENT to a month word or a d/m/y shape,
        // so 'may' / 'march' as ordinary words never match on their own.
        ("date", #"\b\d{1,2}[./-]\d{1,2}[./-](?:\d{4}|\d{2})\b"#, 0, false),
        ("date", #"\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+the\s+\d{1,2}(?:st|nd|rd|th)?\s+\#(month),?\s+\d{4}\b"#, 0, true),
        ("date", #"\b\d{1,2}(?:st|nd|rd|th)?\s+and\s+\d{1,2}(?:st|nd|rd|th)?\s+\#(month),?\s+\d{4}\b"#, 0, true),
        ("date", #"\b\d{1,2}(?:st|nd|rd|th)?(?:\s+day)?(?:\s+of)?\s+\#(month),?\s+\d{4}\b"#, 0, true),
        ("date", #"\b\#(month)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b"#, 0, true),
        ("date", "\\b\(dayWord)(?:\\s+of)?\\s+\(month)\\s+\(yearWords)\\b", 0, true),
        ("date", #"\b\#(month),?\s+\d{4}\b"#, 0, true),
        ("date", #"\b\d{1,2}(?:st|nd|rd|th)\s+\#(month)\b"#, 0, true),
        ("date", #"(?<=year )\d{4}-\d{2}\b"#, 0, true),
        ("time", #"\b\d{1,2}[.:]\d{2}\s?(?:AM|PM|a\.m\.|p\.m\.)(?![A-Za-z])"#, 0, true),
        ("time", #"\b\d{1,2}\s?(?:AM|PM)\b"#, 0, false),
        // A bare year is deliberately its own detector: it is the weakest signal (a preceding preposition or 'Act,').
        ("year", #"(?<=\b(?:in|of|year|during|since|from|by|between|and) )(?:19|20)\d{2}\b"#, 0, true),
        ("year", #"(?<=(?:Act|Code), )(?:1[89]|20)\d{2}\b"#, 0, true),

        // Amounts.
        ("amount", #"(?<![A-Za-z])(?:Rs\.?|₹|INR|USD|Re\.)\s?\#(number)(?:\s?(?:lakhs?|crores?|thousand|million))?(?:/-)?"#, 0, true),
        ("amount", #"\b\#(number)\s+(?:lakhs?|crores?)(?:\s+rupees?)?\b"#, 0, true),
        ("amount", "\\b(?:Rupees?|Rs\\.?)\\s+\(numberWords)(?:\\s+only)?\\b", 0, true),
        ("amount", #"\b\#(number)\s+paise\b"#, 0, true),
        ("quantity", #"\b\d+(?:\.\d+)?\s?%"#, 0, false),
        ("quantity", "\\b\(numberWords)\\s+per\\s?cent\\b", 0, true),
        ("quantity", "\\b(?:\(number)|\(numberWords))\\s+(?:years?|months?|days?)(?:\\s+and\\s+(?:\(number)|\(numberWords))\\s+(?:years?|months?|days?))?\\b", 0, true),
        ("quantity", #"\b\#(number)\s?(?:kgs?|gms?|grams?|litres?|liters?|metres?|meters?|km|cm)\b"#, 0, true),
        ("quantity", "\\b(?:\(number)|\(numberWords))\\s+persons\\b", 0, true),

        // Case / reference numbers: a closed case-type lexicon + 'No.' + identifier (+ year).
        ("case", "(?:Crl\\.?\\s?A(?:ppeal|\\.)?|CRLA|Criminal\\s+Appeal|Criminal\\s+Revision|Crl\\.?\\s?Rev(?:ision)?\\.?|Sessions\\s+(?:Case|Trial)|S\\.?T\\.?\\s+Case|G\\.?R\\.?\\s+Case|P\\.?S\\.?\\s+Case|Police\\s+Station\\s+Case|FIR|Cr\\.|C\\.?C\\.|W\\.?P\\.?\\(?C?\\)?|BLAPL|Bail\\s+Application|Misc\\.?\\s+Case|Crl\\.?\\s?M\\.?C\\.?|T\\.?R\\.|ICC\\s+Case|Title\\s+Suit|Civil\\s+Appeal|RSA|Special\\s+\\(?Vigilance\\)?\\s+Case|Vigilance\\s+Case|Case)\\s*(?:No\\.?|Number)\\s*(?:\\d+(?:[/-]\\d+)?|\(numberWords))(?:\\s+of\\s+(?:\\d{4}|\(numberWords))|/\\d{2,4})?", 0, true),
        ("case", #"\b[A-Z]{4}\d{12}\b"#, 0, false),

        // Exhibits / material objects.
        ("exhibit", #"\b(?:Exhibits|Exts?\.?)\s+[A-Z]-?\d+\s+to\s+[A-Z]-?\d+\b"#, 0, false),
        ("exhibit", "\\b(?:Ext|Exb|Exhibit|Ex)\\b\\.?\\s*(?:No\\.?\\s*)?-?\\s*(?:(?-i:[A-Z]{1,2})[\\s./-]*)?(?:\\d+|(?:\(roman))\\b|(?:one|two|three|four|five|six|seven|eight|nine|ten)\\b)(?:[/-][A-Za-z0-9]+)?", 0, true),
        ("exhibit", #"\b(?:Ext|Exhibit)\b\.?\s?(?-i:[A-Z])\b"#, 0, true),
        ("exhibit", "\\bM\\.?O\\.?\\s?-?\\s?(?:\(roman)|\\d+)\\b", 0, false),
        ("exhibit", "\\bMaterial\\s+Object(?:\\s+No\\.?)?\\s+(?:\\d+|\(roman))\\b", 0, true),
        ("exhibit", #"\bMark\s+[A-Z]\b"#, 0, false),

        // Already-canonical legal references (which normalization leaves untouched and therefore never derives spans for).
        ("legalRef", #"\bSections?\s+\d+[A-Z]?(?:(?:,\s*|\s+and\s+)\d+[A-Z]?)*(?:\s+read\s+with\s+Sections?\s+\d+[A-Z]?)?\s+(?:IPC|BNSS|BNS|BSA|CrPC|CPC)\b"#, 0, false),
        ("legalRef", #"\b[PD]W-\d+\b"#, 0, false),
    ]

    // MARK: - Names: anchored signals only (capture group 1 = the name portion where an anchor word precedes it)

    private static let nameToken = #"(?:[A-Z][a-z]+(?:-[A-Z][a-z]+)?|[A-Z]\.|[A-Z]{2,3})"#
    private static let honorific = #"(?:Shri|Sri|Smt\.?|Kumari|Mr\.?|Mrs\.?|Ms\.?|Dr\.?|Md\.?|Mohd\.?|Sk\.?|Late|Justice)"#
    private static let nameStoplist: Set<String> = ["No", "Nos", "Number", "The", "A", "An", "Court", "State", "Judge"]

    private static let namePatterns: [(pattern: String, group: Int)] = [
        (#"(?<![A-Za-z])\#(honorific)\s+(?:\#(nameToken)\s+){0,3}\#(nameToken)"#, 0),
        (#"(?i:\bS/o|\bW/o|\bD/o|\bson of|\bwife of|\bdaughter of|\balias)\s+(?:Late\s+)?((?:\#(nameToken)\s+){0,3}\#(nameToken))"#, 1),
        (#"(?i:\b(?:accused|complainant|informant|witness|victim|appellant|respondent|petitioner|deceased|mother|father|doctor|priest)|\b[PD]W-\d+),?\s+((?:\#(nameToken)\s+){0,3}\#(nameToken))"#, 1),
    ]

    private static func regex(_ pattern: String, caseInsensitive: Bool) -> NSRegularExpression {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []) else {
            fatalError("invalid candidate detector pattern: \(pattern)")
        }
        return expression
    }

    // MARK: - Detection

    /// All candidate spans for every category, with overlapping spans of the
    /// same category merged into their union (a protection covers the union).
    static func detectAll(_ text: String) -> [DetectionCandidate] {
        let full = NSRange(location: 0, length: (text as NSString).length)
        var raw: [DetectionCandidate] = []
        for entry in self.patterns {
            for match in self.regex(entry.pattern, caseInsensitive: entry.caseInsensitive).matches(in: text, range: full) {
                let range = match.range(at: entry.group)
                if range.location != NSNotFound, range.length > 0 { raw.append(DetectionCandidate(category: entry.category, range: range)) }
            }
        }
        for entry in self.namePatterns {
            for match in self.regex(entry.pattern, caseInsensitive: false).matches(in: text, range: full) {
                let range = match.range(at: entry.group)
                guard range.location != NSNotFound, range.length > 0 else { continue }
                let firstToken = (text as NSString).substring(with: range).split(separator: " ").first.map(String.init) ?? ""
                if self.nameStoplist.contains(firstToken.trimmingCharacters(in: .punctuationCharacters)) { continue }
                raw.append(DetectionCandidate(category: "name", range: range))
            }
        }
        return self.merged(raw)
    }

    /// COARSE, category-agnostic signals used to compare protection STRATEGIES
    /// (see the investigation): every run of digits joined by single
    /// separators (`12.07.2026`, `1,50,000`, `123/2019`, `2.5`), and every run
    /// of spelled number words / ordinals. Neither knows what the number means.
    static func numericRuns(_ text: String) -> [DetectionCandidate] {
        let ns = text as NSString
        return self.regex(#"\d+(?:[,./:-]\d+)*"#, caseInsensitive: false)
            .matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { DetectionCandidate(category: "numericRun", range: $0.range) }
    }

    static func numberWordRuns(_ text: String) -> [DetectionCandidate] {
        let ns = text as NSString
        let word = "(?:\(ones)|\(scale)|\(ordinalWord))\\b"
        return self.regex("\\b\(word)(?:[\\s-]+(?:and[\\s-]+)?\(word))*", caseInsensitive: true)
            .matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { DetectionCandidate(category: "numberWordRun", range: $0.range) }
    }

    /// The naive "capitalized words are names" rule the investigation rejects,
    /// measured for evidence only. `excludingSentenceStarts` drops a capitalized
    /// token that begins a sentence.
    static func capitalizedRunBaseline(_ text: String, excludingSentenceStarts: Bool) -> [DetectionCandidate] {
        let ns = text as NSString
        let token = self.regex(#"[A-Z][a-z]+(?:-[A-Z][a-z]+)?|[A-Z]\.?"#, caseInsensitive: false)
        var tokens: [NSRange] = []
        for match in token.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var start = match.range.location
            if excludingSentenceStarts {
                // Sentence start: text start, or preceded by ". " / "? " / "! ".
                var cursor = start
                while cursor > 0, ns.substring(with: NSRange(location: cursor - 1, length: 1)) == " " { cursor -= 1 }
                let atStart = cursor == 0 || [".", "?", "!"].contains(ns.substring(with: NSRange(location: cursor - 1, length: 1)))
                if atStart { start = -1 }
            }
            if start >= 0 { tokens.append(match.range) }
        }
        var runs: [DetectionCandidate] = []
        var current: NSRange?
        for range in tokens {
            if let existing = current, ns.substring(with: NSRange(location: existing.location + existing.length, length: range.location - existing.location - existing.length))
                .trimmingCharacters(in: .whitespaces).isEmpty, range.location - (existing.location + existing.length) <= 1 {
                current = NSRange(location: existing.location, length: range.location + range.length - existing.location)
            } else {
                if let existing = current { runs.append(DetectionCandidate(category: "name", range: existing)) }
                current = range
            }
        }
        if let existing = current { runs.append(DetectionCandidate(category: "name", range: existing)) }
        return runs
    }

    private static func merged(_ candidates: [DetectionCandidate]) -> [DetectionCandidate] {
        var result: [DetectionCandidate] = []
        for category in Set(candidates.map(\.category)).sorted() {
            let ranges = candidates.filter { $0.category == category }.map(\.range).sorted { $0.location < $1.location }
            var current: NSRange?
            for range in ranges {
                if let existing = current, range.location < existing.location + existing.length {
                    current = NSRange(location: existing.location, length: max(existing.location + existing.length, range.location + range.length) - existing.location)
                } else {
                    if let existing = current { result.append(DetectionCandidate(category: category, range: existing)) }
                    current = range
                }
            }
            if let existing = current { result.append(DetectionCandidate(category: category, range: existing)) }
        }
        return result.sorted { ($0.range.location, $0.category) < ($1.range.location, $1.category) }
    }
}

// swiftlint:enable line_length
