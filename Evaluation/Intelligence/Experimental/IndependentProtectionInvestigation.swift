import Foundation

// Experimental research code: regex pattern tables and fixed-width report rows exceed the line limit.
// swiftlint:disable line_length

// EXPERIMENTAL -- Intelligence V1.12 investigation only. Runs the V1.12 corpus
// (`Evaluation/References/independent-protection/corpus.json`) through the REAL
// legal normalization pipeline, the REAL V1.11 protected-span derivation, the
// REAL `IntelligenceEditClassifier` and the REAL `IntelligenceSafetyAuthority`,
// and measures:
//   1. whether the candidate deterministic signals find each category's
//      expressions (exact / superset / partial / missed, and false positives);
//   2. the edit HAZARD: which single-character surface edits the classifier
//      would let Intelligence apply autonomously inside a protected expression,
//      and how many of those change its structure;
//   3. how many of those hazardous edits escape (a) the V1.11 derived spans
//      alone and (b) derived spans plus the candidate independent spans;
//   4. how the expressions sit relative to the derived normalization spans.
// Nothing here is production code and nothing produces a `ProtectedSpan` that
// any production path consumes. Run via
// `scripts/test_independent_protection_investigation.sh`.

private struct Corpus: Decodable {
    struct Entry: Decodable {
        struct Expression: Decodable {
            let category: String
            let text: String
        }

        let id: String
        let category: String
        let kind: String
        let tier: String
        let text: String
        let expressions: [Expression]
        let note: String
    }

    let entries: [Entry]
}

private struct Gold {
    let entryID: String
    let category: String
    let range: NSRange
    let text: String
}

private struct Analysis {
    let entry: Corpus.Entry
    let normalized: String
    let normalizationSpans: [ProtectedSpan]
    let derivationFailed: Bool
    let gold: [Gold]
    let detections: [DetectionCandidate]
    let baselineAll: [DetectionCandidate]
    let baselineNoStart: [DetectionCandidate]
}

private struct Counter {
    var exact = 0
    var superset = 0
    var partial = 0
    var missed = 0
    var detections = 0
    var falsePositives = 0
    var crossCategory = 0
    var falsePositiveIDs: [String] = []
    var crossCategoryIDs: [String] = []
    var missedIDs: [String] = []
    var supersetIDs: [String] = []
    var partialIDs: [String] = []

    var gold: Int { self.exact + self.superset + self.partial + self.missed }
    var covered: Int { self.exact + self.superset }
}

private struct Hazard {
    var mutations = 0
    var eligible = 0
    /// Digit-run structure changed (a merge/split of digit runs) or, for amounts, the
    /// thousands/decimal separator sequence changed -- a value-altering class.
    var digitStructural = 0
    /// Digits intact but the alphabetic token structure changed (`12th July` -> `12thJuly`,
    /// `twenty six` -> `twentysix`, `Ram Das` -> `RamDas`): damage to the recorded form.
    var wordStructural = 0
    var separatorOnly = 0
    var spacingOnly = 0
    var caseOnly = 0
    var digitEscapeDerived = 0
    var digitEscapeIndependent = 0
    var wordEscapeDerived = 0
    var wordEscapeIndependent = 0
    var caseOnlyBlockedByIndependent = 0
    var initialCapTotal = 0
    var initialCapBlocked = 0
}

private func intersects(_ a: NSRange, _ b: NSRange) -> Bool {
    a.location < b.location + b.length && b.location < a.location + a.length
}

private func covers(_ outer: NSRange, _ inner: NSRange) -> Bool {
    outer.location <= inner.location && outer.location + outer.length >= inner.location + inner.length
}

private func signature(_ text: String) -> (digitRuns: [String], alphaTokens: [String], separators: String) {
    var digitRuns: [String] = []
    var alphaTokens: [String] = []
    var separators = ""
    var digits = ""
    var letters = ""
    let characters = Array(text)
    for (index, character) in characters.enumerated() {
        if character.isNumber, character.isASCII {
            digits.append(character)
        } else if !digits.isEmpty {
            digitRuns.append(digits)
            digits = ""
        }
        if character.isLetter {
            letters.append(character)
        } else if !letters.isEmpty {
            alphaTokens.append(letters.lowercased())
            letters = ""
        }
        if character == "," || character == ".", index > 0, index + 1 < characters.count, characters[index - 1].isNumber, characters[index + 1].isNumber {
            separators.append(character)
        }
    }
    if !digits.isEmpty { digitRuns.append(digits) }
    if !letters.isEmpty { alphaTokens.append(letters.lowercased()) }
    return (digitRuns, alphaTokens, separators)
}

@main
enum IndependentProtectionInvestigation {
    nonisolated(unsafe) private static var recorded: [String: Int] = [:]
    private static func record(_ key: String, _ value: Int) { self.recorded[key] = value }

    static func main() {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let data = try? Data(contentsOf: root.appendingPathComponent("Evaluation/References/independent-protection/corpus.json")),
              let corpus = try? JSONDecoder().decode(Corpus.self, from: data)
        else { preconditionFailure("cannot load the V1.12 corpus") }
        guard let bundle = Bundle(path: root.appendingPathComponent("Sources/Fluid/Resources").path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            preconditionFailure("cannot load the Indian Legal Core")
        }
        let processor = LegalDictationProcessor(builtinPack: pack)

        var analyses: [Analysis] = []
        var integrity: [String] = []
        for entry in corpus.entries {
            let outcome = processor.process(entry.text)
            let normalized = outcome.normalized
            var spans: [ProtectedSpan] = []
            var failed = false
            switch ProtectedSpanDerivation.derive(from: outcome) {
            case let .success(result): spans = result.spans
            case .failure: failed = true
            }
            let ns = normalized as NSString
            var gold: [Gold] = []
            for expression in entry.expressions {
                let first = ns.range(of: expression.text, options: .literal)
                guard first.location != NSNotFound else { integrity.append("\(entry.id): '\(expression.text)' not in normalized text '\(normalized)'"); continue }
                let restStart = first.location + first.length
                let second = ns.range(of: expression.text, options: .literal, range: NSRange(location: restStart, length: ns.length - restStart))
                if second.location != NSNotFound { integrity.append("\(entry.id): '\(expression.text)' occurs more than once") }
                gold.append(Gold(entryID: entry.id, category: expression.category, range: first, text: expression.text))
            }
            analyses.append(Analysis(
                entry: entry,
                normalized: normalized,
                normalizationSpans: spans,
                derivationFailed: failed,
                gold: gold,
                detections: CandidateDetectors.detectAll(normalized),
                baselineAll: CandidateDetectors.capitalizedRunBaseline(normalized, excludingSentenceStarts: false),
                baselineNoStart: CandidateDetectors.capitalizedRunBaseline(normalized, excludingSentenceStarts: true)
            ))
        }
        precondition(integrity.isEmpty, "corpus integrity failures:\n" + integrity.joined(separator: "\n"))
        precondition(analyses.allSatisfy { !$0.derivationFailed }, "V1.11 derivation must succeed for every corpus entry")

        let categories = ["date", "time", "year", "amount", "quantity", "case", "exhibit", "name", "legalRef"]
        var detections: [String: [String: Counter]] = [:]
        var hazardsByTier: [String: [String: Hazard]] = [:]
        for tier in Set(analyses.map(\.entry.tier)).sorted() {
            let subset = analyses.filter { $0.entry.tier == tier }
            print("\n################ TIER: \(tier) ################")
            Self.reportCorpus(subset)
            detections[tier] = Self.reportDetection(subset, categories: categories, tier: tier)
            Self.reportBaseline(subset, tier: tier)
            hazardsByTier[tier] = Self.reportHazard(subset, categories: categories, tier: tier)
            Self.reportStrategies(subset, categories: categories, tier: tier)
        }
        print("\n################ ALL TIERS ################")
        Self.reportInteraction(analyses)

        // Pinned evidence: the findings document quotes these exact numbers.
        Self.pin(detections: detections, hazards: hazardsByTier, analyses: analyses)
        print("All V1.12 independent-protection investigation checks passed.")
    }

    // MARK: - Corpus

    private static func reportCorpus(_ analyses: [Analysis]) {
        let kinds = Dictionary(grouping: analyses, by: \.entry.kind).mapValues(\.count)
        let goldCounts = Dictionary(grouping: analyses.flatMap(\.gold), by: \.category).mapValues(\.count)
        self.record("corpus.\(analyses.first?.entry.tier ?? "none")", analyses.count)
        print("== Corpus: \(analyses.count) entries, kinds \(kinds.sorted { $0.key < $1.key }), gold expressions \(goldCounts.sorted { $0.key < $1.key })")
    }

    // MARK: - Detection

    private static func reportDetection(_ analyses: [Analysis], categories: [String], tier: String) -> [String: Counter] {
        var result: [String: Counter] = [:]
        print("\n== Detection (candidate signals vs gold expressions)")
        print("category   gold exact super part miss | detections unexplainedFP crossCat")
        for category in categories {
            var counter = Counter()
            for analysis in analyses {
                let golds = analysis.gold.filter { $0.category == category }
                let detections = analysis.detections.filter { $0.category == category }
                for gold in golds {
                    if detections.contains(where: { $0.range == gold.range }) {
                        counter.exact += 1
                    } else if detections.contains(where: { covers($0.range, gold.range) }) {
                        counter.superset += 1
                        counter.supersetIDs.append(gold.entryID)
                    } else if detections.contains(where: { intersects($0.range, gold.range) }) {
                        counter.partial += 1
                        counter.partialIDs.append(gold.entryID)
                    } else {
                        counter.missed += 1
                        counter.missedIDs.append(gold.entryID)
                    }
                }
                for detection in detections {
                    counter.detections += 1
                    guard !golds.contains(where: { intersects($0.range, detection.range) }) else { continue }
                    if analysis.gold.contains(where: { intersects($0.range, detection.range) }) || analysis.normalizationSpans.contains(where: { covers($0.range, detection.range) }) {
                        // Explained: it overlaps a gold expression of another category, or lies inside a span normalization already protects.
                        counter.crossCategory += 1
                        counter.crossCategoryIDs.append(analysis.entry.id)
                    } else {
                        counter.falsePositives += 1
                        counter.falsePositiveIDs.append(analysis.entry.id)
                    }
                }
            }
            result[category] = counter
            for (key, value) in [("gold", counter.gold), ("exact", counter.exact), ("superset", counter.superset), ("partial", counter.partial), ("missed", counter.missed), ("unexplainedFP", counter.falsePositives)] { self.record("det.\(tier).\(category).\(key)", value) }
            print("\(category.padding(toLength: 10, withPad: " ", startingAt: 0)) \(String(counter.gold).padding(toLength: 4, withPad: " ", startingAt: 0)) \(String(counter.exact).padding(toLength: 5, withPad: " ", startingAt: 0)) \(String(counter.superset).padding(toLength: 5, withPad: " ", startingAt: 0)) \(String(counter.partial).padding(toLength: 4, withPad: " ", startingAt: 0)) \(String(counter.missed).padding(toLength: 4, withPad: " ", startingAt: 0)) | \(String(counter.detections).padding(toLength: 10, withPad: " ", startingAt: 0)) \(String(counter.falsePositives).padding(toLength: 12, withPad: " ", startingAt: 0)) \(counter.crossCategory)")
            if !counter.missedIDs.isEmpty { print("    missed:    \(counter.missedIDs.joined(separator: " "))") }
            if !counter.partialIDs.isEmpty { print("    partial:   \(counter.partialIDs.joined(separator: " "))") }
            if !counter.supersetIDs.isEmpty { print("    superset:  \(counter.supersetIDs.joined(separator: " "))") }
            if !counter.falsePositiveIDs.isEmpty { print("    unexplained false pos: \(counter.falsePositiveIDs.joined(separator: " "))") }
        }
        return result
    }

    private static func reportBaseline(_ analyses: [Analysis], tier: String) {
        print("\n== Capitalized-run baseline for names (the rule the investigation rejects)")
        for (label, pick) in [("all capitalized runs", { (a: Analysis) in a.baselineAll }), ("excluding sentence starts", { (a: Analysis) in a.baselineNoStart })] {
            var goldTotal = 0
            var covered = 0
            var detections = 0
            var falsePositives = 0
            var negativeEntriesFlagged = 0
            var negatives = 0
            for analysis in analyses {
                let golds = analysis.gold.filter { $0.category == "name" }
                let found = pick(analysis)
                goldTotal += golds.count
                covered += golds.filter { gold in found.contains { covers($0.range, gold.range) } }.count
                detections += found.count
                falsePositives += found.filter { detection in !golds.contains { intersects($0.range, detection.range) } }.count
                if analysis.entry.kind == "negative" {
                    negatives += 1
                    if !found.isEmpty { negativeEntriesFlagged += 1 }
                }
            }
            let tag = label.hasPrefix("all") ? "all" : "noStart"
            for (key, value) in [("gold", goldTotal), ("covered", covered), ("detections", detections), ("fp", falsePositives), ("flagged", negativeEntriesFlagged), ("negatives", negatives)] { self.record("baseline.\(tier).\(tag).\(key)", value) }
            print("\(label): gold names \(goldTotal), covered \(covered), detections \(detections), false-positive detections \(falsePositives), negative entries flagged \(negativeEntriesFlagged)/\(negatives)")
        }
    }

    // MARK: - Hazard

    private struct Mutation {
        let range: NSRange
        let replacement: String
    }

    private static func mutations(in text: NSString, expression: NSRange) -> [Mutation] {
        var result: [Mutation] = []
        let punctuation = [",", ".", "-", "/"]
        for index in expression.location..<(expression.location + expression.length) {
            let unit = text.substring(with: NSRange(location: index, length: 1))
            guard let character = unit.first else { continue }
            let range = NSRange(location: index, length: 1)
            if character.isPunctuation {
                result.append(Mutation(range: range, replacement: ""))
                for other in punctuation where other != unit { result.append(Mutation(range: range, replacement: other)) }
            } else if character.isWhitespace {
                result.append(Mutation(range: range, replacement: ""))
            } else if character.isLetter {
                let flipped = character.isUppercase ? unit.lowercased() : unit.uppercased()
                if flipped != unit { result.append(Mutation(range: range, replacement: flipped)) }
            }
        }
        if expression.length > 1 {
            for position in (expression.location + 1)..<(expression.location + expression.length) {
                for insertion in punctuation + [" "] { result.append(Mutation(range: NSRange(location: position, length: 0), replacement: insertion)) }
            }
        }
        return result
    }

    private static func reportHazard(_ analyses: [Analysis], categories: [String], tier: String) -> [String: Hazard] {
        var result: [String: Hazard] = [:]
        print("\n== Edit hazard: single-character surface edits inside each gold expression")
        print("category    mutations eligible | digitStruct wordStruct sepOnly spacing caseOnly | escaping (derived-only -> +category detectors): digit  word | caseOnly blocked | initial-letter capitalizations blocked/total")
        for category in categories {
            var hazard = Hazard()
            for analysis in analyses {
                let ns = analysis.normalized as NSString
                let independent = analysis.detections.map { ProtectedSpan(range: $0.range, kind: .independentlyProtected) }
                for gold in analysis.gold where gold.category == category {
                    let original = ns.substring(with: gold.range)
                    let originalSignature = signature(original)
                    for mutation in self.mutations(in: ns, expression: gold.range) {
                        hazard.mutations += 1
                        let expected = ns.substring(with: mutation.range)
                        let classification = IntelligenceEditClassifier.classify(from: expected, to: mutation.replacement)
                        guard classification != .other else { continue }
                        hazard.eligible += 1
                        let mutatedExpression = ns.replacingCharacters(in: NSRange(location: mutation.range.location, length: mutation.range.length), with: mutation.replacement)
                        let mutatedSlice = (mutatedExpression as NSString).substring(with: NSRange(location: gold.range.location, length: gold.range.length - mutation.range.length + (mutation.replacement as NSString).length))
                        let mutatedSignature = signature(mutatedSlice)
                        let digitStructural = mutatedSignature.digitRuns != originalSignature.digitRuns
                            || (category == "amount" && mutatedSignature.separators != originalSignature.separators)
                        let wordStructural = !digitStructural && mutatedSignature.alphaTokens != originalSignature.alphaTokens
                        let proposal = IntelligenceProposal(id: "m", range: mutation.range, expectedSourceText: expected, replacementText: mutation.replacement, claimedCategory: .other)
                        func accepted(_ spans: [ProtectedSpan]) -> Bool {
                            let outcome = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: analysis.normalized, protectedSpans: spans)
                            if case .autonomouslyAccepted = outcome.outcomes[0].disposition { return true }
                            return false
                        }
                        let escapesDerived = accepted(analysis.normalizationSpans)
                        let escapesWithIndependent = accepted(analysis.normalizationSpans + independent)
                        if classification == .capitalizationOnly {
                            hazard.caseOnly += 1
                            let previous = mutation.range.location > 0 ? ns.substring(with: NSRange(location: mutation.range.location - 1, length: 1)) : " "
                            if previous.first.map({ !$0.isLetter && !$0.isNumber }) ?? true, expected.first?.isLowercase == true {
                                hazard.initialCapTotal += 1
                                if escapesDerived, !escapesWithIndependent { hazard.initialCapBlocked += 1 }
                            }
                            precondition(!digitStructural && !wordStructural, "a capitalization-only edit must never change structure")
                            if escapesDerived, !escapesWithIndependent { hazard.caseOnlyBlockedByIndependent += 1 }
                        } else if digitStructural {
                            hazard.digitStructural += 1
                            if escapesDerived { hazard.digitEscapeDerived += 1 }
                            if escapesWithIndependent { hazard.digitEscapeIndependent += 1 }
                        } else if wordStructural {
                            hazard.wordStructural += 1
                            if escapesDerived { hazard.wordEscapeDerived += 1 }
                            if escapesWithIndependent { hazard.wordEscapeIndependent += 1 }
                        } else if classification == .punctuationOnly {
                            hazard.separatorOnly += 1
                        } else {
                            hazard.spacingOnly += 1
                        }
                    }
                }
            }
            result[category] = hazard
            self.record("haz.\(tier).\(category).digit", hazard.digitStructural)
            self.record("haz.\(tier).\(category).word", hazard.wordStructural)
            self.record("haz.\(tier).\(category).eligible", hazard.eligible)
            print("\(category.padding(toLength: 11, withPad: " ", startingAt: 0)) \(String(hazard.mutations).padding(toLength: 9, withPad: " ", startingAt: 0)) \(String(hazard.eligible).padding(toLength: 8, withPad: " ", startingAt: 0)) | \(String(hazard.digitStructural).padding(toLength: 11, withPad: " ", startingAt: 0)) \(String(hazard.wordStructural).padding(toLength: 10, withPad: " ", startingAt: 0)) \(String(hazard.separatorOnly).padding(toLength: 7, withPad: " ", startingAt: 0)) \(String(hazard.spacingOnly).padding(toLength: 7, withPad: " ", startingAt: 0)) \(String(hazard.caseOnly).padding(toLength: 8, withPad: " ", startingAt: 0)) | digit \(hazard.digitEscapeDerived)->\(hazard.digitEscapeIndependent)  word \(hazard.wordEscapeDerived)->\(hazard.wordEscapeIndependent) | \(hazard.caseOnlyBlockedByIndependent) | \(hazard.initialCapBlocked)/\(hazard.initialCapTotal)")
        }
        return result
    }

    // MARK: - Protection strategies (coverage of structural hazards vs over-protection)

    private static let strategyNames = ["category", "numericRun", "numericRun+words", "category+numericRun", "category+numericRun+words"]

    private static func strategySpans(_ name: String, _ analysis: Analysis) -> [NSRange] {
        let category = analysis.detections.map(\.range)
        let numeric = CandidateDetectors.numericRuns(analysis.normalized).map(\.range)
        let words = CandidateDetectors.numberWordRuns(analysis.normalized).map(\.range)
        switch name {
        case "category": return category
        case "numericRun": return numeric
        case "numericRun+words": return numeric + words
        case "category+numericRun": return category + numeric
        default: return category + numeric + words
        }
    }

    private static func reportStrategies(_ analyses: [Analysis], categories: [String], tier: String) {
        for (label, wantDigit) in [("DIGIT-structural hazard edits (value-altering: digit-run merge/split, amount separators) that ESCAPE", true), ("WORD-structural hazard edits (recorded-form damage: token merge/split) that ESCAPE", false)] {
            print("\n== Strategy comparison: \(label), per gold category")
            print("strategy                   " + categories.map { $0.padding(toLength: 9, withPad: " ", startingAt: 0) }.joined() + "| total / escaping | negatives touched | protected chars outside gold")
            for strategy in self.strategyNames {
                var perCategory: [String: Int] = [:]
                var total = 0
                var escaped = 0
                var negativesTouched = 0
                var negatives = 0
                var outsideGold = 0
                var allCharacters = 0
                for analysis in analyses {
                    let ns = analysis.normalized as NSString
                    let spans = self.strategySpans(strategy, analysis)
                    let protectedSpans = analysis.normalizationSpans + spans.map { ProtectedSpan(range: $0, kind: .independentlyProtected) }
                    allCharacters += ns.length
                    if analysis.entry.kind == "negative" {
                        negatives += 1
                        if !spans.isEmpty { negativesTouched += 1 }
                    }
                    var covered = Set<Int>()
                    for span in spans { for index in span.location..<(span.location + span.length) { covered.insert(index) } }
                    var inGold = Set<Int>()
                    for gold in analysis.gold { for index in gold.range.location..<(gold.range.location + gold.range.length) { inGold.insert(index) } }
                    outsideGold += covered.subtracting(inGold).count
                    for gold in analysis.gold {
                        let original = signature(ns.substring(with: gold.range))
                        for mutation in self.mutations(in: ns, expression: gold.range) {
                            let expected = ns.substring(with: mutation.range)
                            let classification = IntelligenceEditClassifier.classify(from: expected, to: mutation.replacement)
                            guard classification != .other, classification != .capitalizationOnly else { continue }
                            let mutated = ns.replacingCharacters(in: mutation.range, with: mutation.replacement) as NSString
                            let slice = mutated.substring(with: NSRange(location: gold.range.location, length: gold.range.length - mutation.range.length + (mutation.replacement as NSString).length))
                            let after = signature(slice)
                            let digit = after.digitRuns != original.digitRuns || (gold.category == "amount" && after.separators != original.separators)
                            let word = !digit && after.alphaTokens != original.alphaTokens
                            guard wantDigit ? digit : word else { continue }
                            total += 1
                            let proposal = IntelligenceProposal(id: "m", range: mutation.range, expectedSourceText: expected, replacementText: mutation.replacement, claimedCategory: .other)
                            let outcome = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: analysis.normalized, protectedSpans: protectedSpans)
                            if case .autonomouslyAccepted = outcome.outcomes[0].disposition {
                                escaped += 1
                                perCategory[gold.category, default: 0] += 1
                            }
                        }
                    }
                }
                if wantDigit {
                    self.record("strat.\(tier).\(strategy).digitTotal", total)
                    self.record("strat.\(tier).\(strategy).digitEscaped", escaped)
                    self.record("strat.\(tier).\(strategy).negativesTouched", negativesTouched)
                    self.record("strat.\(tier).\(strategy).negatives", negatives)
                }
                let row = categories.map { String(perCategory[$0, default: 0]).padding(toLength: 9, withPad: " ", startingAt: 0) }.joined()
                let percent = String(format: "%.1f", Double(outsideGold) * 100 / Double(max(allCharacters, 1)))
                print("\(strategy.padding(toLength: 27, withPad: " ", startingAt: 0))\(row)| \(total) / \(escaped) | \(negativesTouched)/\(negatives) | \(outsideGold) chars (\(percent)% of all)")
            }
        }
    }

    // MARK: - Interaction with derived normalization spans

    private static func reportInteraction(_ analyses: [Analysis]) {
        print("\n== Interaction of gold expressions with V1.11 derived normalization spans")
        var relations: [String: [String: Int]] = [:]
        var legalRefGold = 0
        var legalRefCovered = 0
        for analysis in analyses {
            for gold in analysis.gold {
                var relation = "no-span-in-entry"
                if !analysis.normalizationSpans.isEmpty {
                    if analysis.normalizationSpans.contains(where: { covers($0.range, gold.range) }) {
                        relation = "inside-span"
                    } else if analysis.normalizationSpans.contains(where: { covers(gold.range, $0.range) }) {
                        relation = "contains-span"
                    } else if analysis.normalizationSpans.contains(where: { intersects($0.range, gold.range) }) {
                        relation = "partial-overlap"
                    } else if analysis.normalizationSpans.contains(where: { abs($0.range.location + $0.range.length - gold.range.location) <= 1 || abs(gold.range.location + gold.range.length - $0.range.location) <= 1 }) {
                        relation = "adjacent"
                    } else {
                        relation = "disjoint"
                    }
                }
                relations[gold.category, default: [:]][relation, default: 0] += 1
                if gold.category == "legalRef" {
                    legalRefGold += 1
                    if analysis.normalizationSpans.contains(where: { intersects($0.range, gold.range) }) { legalRefCovered += 1 }
                }
            }
        }
        for category in relations.keys.sorted() { print("\(category): \(relations[category, default: [:]].sorted { $0.key < $1.key })") }
        print("already-canonical legal references covered by derived spans: \(legalRefCovered)/\(legalRefGold)")
        self.record("legalRef.gold", legalRefGold)
        self.record("legalRef.coveredByDerived", legalRefCovered)
        for analysis in analyses where analysis.entry.category == "mixed" { print("  \(analysis.entry.id): \(analysis.normalized)") }
        interactionSummary = (legalRefGold, legalRefCovered, relations)
    }

    nonisolated(unsafe) private static var interactionSummary: (legalGold: Int, legalCovered: Int, relations: [String: [String: Int]]) = (0, 0, [:])

    // MARK: - Pinned numbers

    private static func pin(detections: [String: [String: Counter]], hazards: [String: [String: Hazard]], analyses: [Analysis]) {
        _ = (detections, hazards, analyses)
        // The findings document quotes exactly these numbers; a change to the corpus, the candidate
        // signals, the normalizer, the classifier or the Authority that moves them must be reviewed.
        let expected: [(String, Int)] = [
            ("corpus.development", 234), ("corpus.heldout", 65),
            // development tier detection (candidate signals were shaped while looking at this tier)
            ("det.development.date.gold", 36), ("det.development.date.exact", 36),
            ("det.development.time.exact", 3), ("det.development.year.gold", 7), ("det.development.year.exact", 6), ("det.development.year.missed", 1),
            ("det.development.amount.gold", 34), ("det.development.amount.exact", 34), ("det.development.quantity.gold", 16), ("det.development.quantity.exact", 16),
            ("det.development.case.gold", 33), ("det.development.case.exact", 33), ("det.development.exhibit.gold", 26), ("det.development.exhibit.exact", 26),
            ("det.development.name.gold", 36), ("det.development.name.exact", 27), ("det.development.name.superset", 2), ("det.development.name.missed", 7),
            ("det.development.name.unexplainedFP", 1), ("det.development.legalRef.gold", 8), ("det.development.legalRef.exact", 8),
            // held-out tier: authored after the signals were fixed and scored WITHOUT tuning
            ("det.heldout.date.gold", 12), ("det.heldout.date.exact", 7), ("det.heldout.date.partial", 2), ("det.heldout.date.missed", 3),
            ("det.heldout.amount.gold", 11), ("det.heldout.amount.exact", 9), ("det.heldout.amount.missed", 2),
            ("det.heldout.quantity.gold", 6), ("det.heldout.quantity.exact", 4), ("det.heldout.quantity.missed", 2),
            ("det.heldout.case.gold", 7), ("det.heldout.case.exact", 4), ("det.heldout.case.partial", 1), ("det.heldout.case.missed", 2),
            ("det.heldout.exhibit.gold", 8), ("det.heldout.exhibit.exact", 8),
            ("det.heldout.name.gold", 14), ("det.heldout.name.exact", 5), ("det.heldout.name.missed", 9), ("det.heldout.name.unexplainedFP", 1),
            ("det.heldout.legalRef.gold", 4), ("det.heldout.legalRef.exact", 2), ("det.heldout.legalRef.missed", 2),
            // the rejected capitalized-run rule
            ("baseline.development.all.gold", 36), ("baseline.development.all.covered", 28), ("baseline.development.all.detections", 451),
            ("baseline.development.all.fp", 409), ("baseline.development.all.flagged", 57), ("baseline.development.all.negatives", 57),
            ("baseline.development.noStart.covered", 24), ("baseline.development.noStart.detections", 241), ("baseline.development.noStart.fp", 205), ("baseline.development.noStart.flagged", 27),
            ("baseline.heldout.all.covered", 13), ("baseline.heldout.all.detections", 130), ("baseline.heldout.all.fp", 115), ("baseline.heldout.all.flagged", 7),
            ("baseline.heldout.noStart.covered", 11), ("baseline.heldout.noStart.detections", 75), ("baseline.heldout.noStart.fp", 61), ("baseline.heldout.noStart.flagged", 6),
            // value-altering (digit-structural) hazard edits and which protection strategy lets them escape
            ("strat.development.category.digitTotal", 2277), ("strat.development.category.digitEscaped", 15),
            ("strat.development.numericRun.digitEscaped", 0), ("strat.development.numericRun.negativesTouched", 12), ("strat.development.numericRun.negatives", 57),
            ("strat.heldout.category.digitTotal", 647), ("strat.heldout.category.digitEscaped", 93),
            ("strat.heldout.numericRun.digitEscaped", 0), ("strat.heldout.numericRun.negativesTouched", 2), ("strat.heldout.numericRun.negatives", 7),
            // canonical legal references that normalization never touched are not covered by derived spans
            ("legalRef.gold", 12), ("legalRef.coveredByDerived", 1),
        ]
        for (key, value) in expected {
            precondition(self.recorded[key] == value, "pinned evidence changed: \(key) = \(String(describing: self.recorded[key])), expected \(value)")
        }
    }
}

// swiftlint:enable line_length
