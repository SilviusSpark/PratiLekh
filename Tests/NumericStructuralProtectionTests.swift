import CryptoKit
import Foundation

/// Coverage and acceptance validation for `NumericStructuralProtection`.
///
/// The acceptance corpus (`Evaluation/References/numeric-structural-protection/`)
/// was frozen BEFORE the production detector existed; its SHA-256 is pinned below
/// so any post-hoc label edit fails this test and must be documented as a
/// labeling correction. Acceptance is judged (1) from a whole-text hazard oracle
/// that is independent of the labels and runs the REAL classifier and the REAL
/// Safety Authority, and (2) from the labels. Deterministic only -- no model.
@main
enum NumericStructuralProtectionTests {
    private static let frozenCorpusSHA256 = "2aefbc42dceb3bf0aae127bc3a6a17116026e5e3022bb13c331c69c349853a86"

    private struct Corpus: Decodable {
        struct Entry: Decodable {
            let id: String
            let group: String
            let kind: String
            let text: String
            let expressions: [String]
        }

        let entries: [Entry]
    }

    static func main() {
        self.testRuleSemantics()
        self.testUTF16CoordinatesAndOrdering()
        self.testWhitespaceSeparatedNumeralsAreOneSpan()
        self.testGapBreakers()
        self.testDigitFreeAndDegenerateInputs()
        self.testZeroLengthInsertionEdges()
        self.testDeterminismAndIdempotence()
        self.testFrozenCorpusAcceptance()
        self.testRandomizedRobustnessBeyondTheFrozenCorpus()
        self.testCompositionWithDerivedSpansAndTheV18Path()
        print("PASS: NumericStructuralProtection rule semantics, frozen-corpus acceptance and composition suite")
    }

    // MARK: - Helpers

    private static func ranges(_ text: String) -> [NSRange] {
        NumericStructuralProtection.spans(in: text).map(\.range)
    }

    private static func covered(_ text: String) -> [String] {
        let ns = text as NSString
        return self.ranges(text).map { ns.substring(with: $0) }
    }

    private static func expect(_ text: String, _ expected: [String], file: StaticString = #file, line: UInt = #line) {
        let got = self.covered(text)
        precondition(got == expected, "\(text.debugDescription): expected \(expected), got \(got)", file: file, line: line)
    }

    private static func disposition(_ text: String, edit range: NSRange, to replacement: String, spans: [ProtectedSpan]) -> ProposalDisposition {
        let expected = (text as NSString).substring(with: range)
        let proposal = IntelligenceProposal(id: "e", range: range, expectedSourceText: expected, replacementText: replacement, claimedCategory: .other)
        return IntelligenceSafetyAuthority.validate(proposals: [proposal], source: text, protectedSpans: spans).outcomes[0].disposition
    }

    // MARK: - Rule semantics

    private static func testRuleSemantics() {
        self.expect("on 12.07.2026 at 10:45", ["12.07.2026", "10:45"])
        self.expect("Rs. 5,000/- paid", ["5,000"])
        self.expect("Rs.2,50,000/-", ["2,50,000"])
        self.expect("PW-12 and DW-3", ["12", "3"])
        self.expect("Sections 302/34 IPC", ["302/34"])
        self.expect("Section 20(b)(ii)(C)", ["20"])
        self.expect("Sec. 3(1)(r)", ["3(1"])
        self.expect("376A and 354D", ["376", "354"])
        self.expect("12th July 2026", ["12", "2026"])
        // Every script's decimal digits, and mixed scripts, are digits.
        self.expect("\u{0B67}\u{0B68}.\u{0B6D}", ["\u{0B67}\u{0B68}.\u{0B6D}"])
        self.expect("\u{0967}\u{0968}/\u{096B}", ["\u{0967}\u{0968}/\u{096B}"])
        self.expect("12.\u{0B6D}.2026", ["12.\u{0B6D}.2026"])
        self.expect("\u{FF11}\u{FF12}\u{FF13}\u{FF0C}\u{FF14}", ["\u{FF11}\u{FF12}\u{FF13}\u{FF0C}\u{FF14}"])
        // Numeric-valued characters that are not decimal digits are outside the rule.
        self.expect("\u{00BD} \u{00B2} \u{216B}", [])
    }

    private static func testUTF16CoordinatesAndOrdering() {
        let text = "\u{1F60A}\u{1F60A} 12.07 x \u{1D7CF}\u{1D7D0}"
        let spans = NumericStructuralProtection.spans(in: text)
        precondition(spans.map(\.range) == [NSRange(location: 5, length: 5), NSRange(location: 13, length: 4)], "\(spans.map(\.range))")
        precondition(spans.allSatisfy { $0.kind == .independentlyProtected })
        precondition(self.covered(text) == ["12.07", "\u{1D7CF}\u{1D7D0}"], "astral digits count as 2 UTF-16 units each")
        for pair in zip(spans, spans.dropFirst()) {
            precondition(pair.0.range.location + pair.0.range.length < pair.1.range.location, "spans are ascending, non-overlapping and never adjacent")
        }
    }

    private static func testWhitespaceSeparatedNumeralsAreOneSpan() {
        // The pre-registered rule: numerals separated only by non-letter, non-line-break
        // characters are ONE span.
        self.expect("12 34", ["12 34"])
        self.expect("1 2 3", ["1 2 3"])
        self.expect("12  34", ["12  34"])
        self.expect("12\t34", ["12\t34"])
        self.expect("5 \u{00A0} 6", ["5 \u{00A0} 6"])
        self.expect("1\u{00A0}2", ["1\u{00A0}2"])
        self.expect("2026. 5 witnesses", ["2026. 5"])
        self.expect("294, 323, 506", ["294, 323, 506"])
        self.expect("(1) (2) (3)", ["1) (2) (3"])
        // ... and the rule is what protects the value: deleting the space is blocked.
        let text = "Aadhaar 1234 5678 9012 was produced."
        let spans = NumericStructuralProtection.spans(in: text)
        let space = (text as NSString).range(of: " ", options: [], range: NSRange(location: 12, length: 5))
        precondition(self.disposition(text, edit: space, to: "", spans: spans) == .reviewOnly(.intersectsIndependentlyProtectedSpan), "deleting the space between numeral groups must not be autonomous")
        precondition({ if case .autonomouslyAccepted = self.disposition(text, edit: space, to: "", spans: []) { return true } else { return false } }(), "premise: without spans that same edit IS autonomous")
    }

    private static func testGapBreakers() {
        self.expect("12 apples 34", ["12", "34"]) // a letter
        self.expect("12\n34", ["12", "34"]) // line break
        self.expect("12\r\n34", ["12", "34"])
        self.expect("12\u{2028}34", ["12", "34"])
        self.expect("12\u{2029}34", ["12", "34"])
        self.expect("12\u{0085}34", ["12", "34"])
        self.expect("12\u{0301} 34", ["12", "34"]) // a combining mark
        self.expect("1\u{FE0F}\u{20E3}2\u{FE0F}\u{20E3}", ["1", "2"])
        self.expect("\u{0B67}\u{0B68} \u{0B93} \u{0B69}", ["\u{0B67}\u{0B68}", "\u{0B69}"]) // an Odia-script letter (Tamil letter here) breaks
        self.expect("\u{0B67} \u{0B13} \u{0B68}", ["\u{0B67}", "\u{0B68}"]) // an Odia letter breaks
        self.expect("\u{0967} \u{0915} \u{0968}", ["\u{0967}", "\u{0968}"]) // a Devanagari letter breaks
        // Non-letters do not break: symbols, currency, emoji, format characters.
        self.expect("1 + 2", ["1 + 2"])
        self.expect("1 \u{20B9} 2", ["1 \u{20B9} 2"])
        self.expect("1\u{200D}2", ["1\u{200D}2"])
        self.expect("\u{200F}12\u{200F}.\u{200F}07\u{200F}", ["12\u{200F}.\u{200F}07"])
    }

    private static func testDigitFreeAndDegenerateInputs() {
        for text in ["", " ", "....", "The accused was present.", "Roman IV and half \u{00BD}", "twelve July twenty twenty six", "\u{0B38}\u{0B3E}\u{0B15}\u{0B4D}\u{0B37}\u{0B40}"] {
            precondition(self.ranges(text).isEmpty, "digit-free text must receive no span: \(text.debugDescription)")
        }
        self.expect("7", ["7"])
        self.expect("-5", ["5"])
        self.expect(".5", ["5"])
        self.expect("5.", ["5"])
    }

    // MARK: - Zero-length insertion edges (Authority intersection semantics)

    private static func testZeroLengthInsertionEdges() {
        let text = "Rs. 5,000 paid"
        let spans = NumericStructuralProtection.spans(in: text)
        precondition(spans.map(\.range) == [NSRange(location: 4, length: 5)])
        func insertion(at position: Int, _ character: String) -> ProposalDisposition {
            self.disposition(text, edit: NSRange(location: position, length: 0), to: character, spans: spans)
        }
        // Immediately BEFORE the first digit and immediately AFTER the last digit: outside the span.
        for character in [",", ".", " "] {
            guard case .autonomouslyAccepted = insertion(at: 4, character) else { preconditionFailure("insertion at the span start must not be blocked: \(character.debugDescription)") }
            guard case .autonomouslyAccepted = insertion(at: 9, character) else { preconditionFailure("insertion at the span end must not be blocked: \(character.debugDescription)") }
        }
        // Strictly INSIDE the span (between any two of its characters): blocked.
        for position in 5...8 {
            for character in [",", ".", " ", "-"] {
                precondition(insertion(at: position, character) == .reviewOnly(.intersectsIndependentlyProtectedSpan), "position \(position) inside the span must be blocked")
            }
        }
        // A positive-length edit that merely touches the boundary is outside; one crossing it is inside.
        let touching = NSRange(location: 3, length: 1) // the space before the digits
        guard case .autonomouslyAccepted = self.disposition(text, edit: touching, to: "", spans: spans) else { preconditionFailure("deleting the space before a numeral is outside the span") }
        precondition(self.disposition(text, edit: NSRange(location: 3, length: 2), to: "  ", spans: spans) != .autonomouslyAccepted(.whitespaceOnly), "an edit reaching into the span must not be autonomous")
        // Two zero-length spans of different sources at the same point conflict, but a single insertion at a
        // shared boundary of two spans is judged only by strict-inside semantics.
        let gapText = "12 x 34"
        let gapSpans = NumericStructuralProtection.spans(in: gapText)
        precondition(gapSpans.map(\.range) == [NSRange(location: 0, length: 2), NSRange(location: 5, length: 2)])
        guard case .autonomouslyAccepted = self.disposition(gapText, edit: NSRange(location: 2, length: 0), to: ",", spans: gapSpans) else { preconditionFailure("boundary between a span and its following letter gap") }
    }

    // MARK: - Determinism and idempotence

    private static func testDeterminismAndIdempotence() {
        let texts = ["on 12.07.2026 at 10:45", "Aadhaar 1234 5678 9012", "\u{0B67}\u{0B68} \u{0B69}", "\u{1F60A}12\u{1F60A}", "no digits", ""]
        for text in texts {
            let first = NumericStructuralProtection.spans(in: text)
            for _ in 0..<10 { precondition(NumericStructuralProtection.spans(in: text) == first) }
            precondition(NumericStructuralProtection.spans(in: String(text.unicodeScalars)) == first, "depends on the text only")
            // Re-protecting a protected region yields exactly that region: protection is idempotent.
            let ns = text as NSString
            for span in first {
                let inner = ns.substring(with: span.range)
                precondition(NumericStructuralProtection.spans(in: inner).map(\.range) == [NSRange(location: 0, length: (inner as NSString).length)], "re-protecting \(inner.debugDescription)")
            }
        }
    }

    // MARK: - The frozen corpus

    private static func signature(_ text: String) -> (runs: [String], separators: [String]) {
        let scalars = Array(text.unicodeScalars)
        func isDigit(_ scalar: Unicode.Scalar) -> Bool { scalar.properties.generalCategory == .decimalNumber }
        var runs: [String] = []
        var separators: [String] = []
        var run = ""
        for (index, scalar) in scalars.enumerated() {
            if isDigit(scalar) {
                run.unicodeScalars.append(scalar)
            } else if !run.isEmpty {
                runs.append(run)
                run = ""
            }
            if ",./:-".unicodeScalars.contains(scalar), index > 0, index + 1 < scalars.count, isDigit(scalars[index - 1]), isDigit(scalars[index + 1]) {
                separators.append(String(scalar))
            }
        }
        if !run.isEmpty { runs.append(run) }
        return (runs, separators)
    }

    private struct Mutation {
        let range: NSRange
        let replacement: String
    }

    /// Every single surface edit over the WHOLE text (not just labeled expressions).
    private static func mutations(of text: String) -> [Mutation] {
        let scalars = Array(text.unicodeScalars)
        var offsets: [Int] = []
        var offset = 0
        for scalar in scalars {
            offsets.append(offset)
            offset += scalar.utf16.count
        }
        offsets.append(offset)
        func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
            switch scalar.properties.generalCategory {
            case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation: return true
            default: return false
            }
        }
        func isHorizontalSpace(_ scalar: Unicode.Scalar) -> Bool {
            scalar.properties.isWhitespace && !(0x000A...0x000D).contains(scalar.value) && scalar.value != 0x0085 && scalar.value != 0x2028 && scalar.value != 0x2029
        }
        let inserted = [",", ".", "-", "/", ":"]
        var result: [Mutation] = []
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            let range = NSRange(location: offsets[index], length: offsets[index + 1] - offsets[index])
            if isPunctuation(scalar) {
                result.append(Mutation(range: range, replacement: ""))
                for other in inserted where other != String(scalar) { result.append(Mutation(range: range, replacement: other)) }
            } else if isHorizontalSpace(scalar) {
                var end = index
                while end < scalars.count, isHorizontalSpace(scalars[end]) { end += 1 }
                result.append(Mutation(range: range, replacement: ""))
                if end - index > 1 { result.append(Mutation(range: NSRange(location: offsets[index], length: offsets[end] - offsets[index]), replacement: "")) }
            }
            index += 1
        }
        if scalars.count > 1 {
            for boundary in 1..<scalars.count {
                for character in inserted + [" "] { result.append(Mutation(range: NSRange(location: offsets[boundary], length: 0), replacement: character)) }
            }
        }
        return result
    }

    private static func testFrozenCorpusAcceptance() {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Evaluation/References/numeric-structural-protection/corpus.json")
        guard let data = try? Data(contentsOf: url), let corpus = try? JSONDecoder().decode(Corpus.self, from: data) else { preconditionFailure("cannot load the frozen corpus") }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        precondition(digest == self.frozenCorpusSHA256, "the frozen corpus changed (\(digest)); any edit must be a documented labeling correction with a new pin")
        precondition(corpus.entries.count == 192, "\(corpus.entries.count)")
        precondition(Set(corpus.entries.map(\.id)).count == 192)

        var totalCharacters = 0
        var outsideLabeled = 0
        var expressionsChecked = 0
        var exactEntries = 0
        var structuralHazards = 0
        var escapesWithSpans = 0
        var escapesWithoutSpans = 0
        var perGroup: [String: (hazards: Int, escapes: Int, uncovered: Int)] = [:]
        var digitFreeEntries = 0

        for entry in corpus.entries {
            let ns = entry.text as NSString
            let spans = NumericStructuralProtection.spans(in: entry.text)
            totalCharacters += ns.length
            let hasDigit = entry.text.unicodeScalars.contains { $0.properties.generalCategory == .decimalNumber }

            // (3) digit-free text receives no span; text with digits receives at least one.
            if !hasDigit {
                digitFreeEntries += 1
                precondition(spans.isEmpty, "\(entry.id): digit-free text must have no span")
            } else {
                precondition(!spans.isEmpty, "\(entry.id): text with digits must have a span")
            }

            // (2) every labeled expression is covered completely by exactly one span.
            var labeled = Set<Int>()
            for expression in entry.expressions {
                let range = ns.range(of: expression, options: .literal)
                let tail = NSRange(location: range.location + range.length, length: ns.length - range.location - range.length)
                let isUnique = range.location != NSNotFound && ns.range(of: expression, options: .literal, range: tail).location == NSNotFound
                precondition(isUnique, "\(entry.id): label \(expression.debugDescription) must occur exactly once")
                let containing = spans.filter { $0.range.location <= range.location && $0.range.location + $0.range.length >= range.location + range.length }
                let touching = spans.filter { NSIntersectionRange($0.range, range).length > 0 }
                var isCovered = containing.count == 1 && touching.count == 1
                if !isCovered { perGroup[entry.group, default: (0, 0, 0)].uncovered += 1 }
                precondition(isCovered, "\(entry.id): \(expression.debugDescription) is not covered completely by one span (spans \(spans.map(\.range)))")
                isCovered = true
                expressionsChecked += 1
                for index in range.location..<(range.location + range.length) { labeled.insert(index) }
            }
            if spans.map({ ns.substring(with: $0.range) }) == entry.expressions { exactEntries += 1 }

            // (4) protected characters outside labeled expressions.
            var protectedIndices = Set<Int>()
            for span in spans { for index in span.range.location..<(span.range.location + span.range.length) { protectedIndices.insert(index) } }
            outsideLabeled += protectedIndices.subtracting(labeled).count

            // (1) whole-text hazard oracle through the real classifier and the real Authority.
            let original = self.signature(entry.text)
            for mutation in self.mutations(of: entry.text) {
                let expected = ns.substring(with: mutation.range)
                let classification = IntelligenceEditClassifier.classify(from: expected, to: mutation.replacement)
                guard classification != .other else { continue }
                let mutated = ns.replacingCharacters(in: mutation.range, with: mutation.replacement)
                let after = self.signature(mutated)
                guard after.runs != original.runs || after.separators != original.separators else { continue }
                structuralHazards += 1
                let proposal = IntelligenceProposal(id: "m", range: mutation.range, expectedSourceText: expected, replacementText: mutation.replacement, claimedCategory: .other)
                func accepted(_ protectedSpans: [ProtectedSpan]) -> Bool {
                    if case .autonomouslyAccepted = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: entry.text, protectedSpans: protectedSpans).outcomes[0].disposition { return true }
                    return false
                }
                perGroup[entry.group, default: (0, 0, 0)].hazards += 1
                if accepted([]) { escapesWithoutSpans += 1 }
                if accepted(spans) {
                    escapesWithSpans += 1
                    perGroup[entry.group, default: (0, 0, 0)].escapes += 1
                    print("ESCAPE \(entry.id) \(mutation.range) -> \(mutation.replacement.debugDescription) in \(entry.text.debugDescription)")
                }
            }
        }

        let percent = Double(outsideLabeled) * 100 / Double(totalCharacters)
        print("frozen corpus: 192 entries, \(expressionsChecked) labeled expressions all covered, exact span==label entries \(exactEntries)/192, digit-free entries \(digitFreeEntries)")
        let hazardSummary = "\(structuralHazards) digit-structural hazard edits; escape with no spans \(escapesWithoutSpans), with numeric spans \(escapesWithSpans)"
        print("hazard oracle: \(hazardSummary); protected chars outside labels \(outsideLabeled)/\(totalCharacters) (\(String(format: "%.3f", percent))%)")
        for group in perGroup.keys.sorted() { print("  \(group): hazards \(perGroup[group]?.hazards ?? 0), escapes \(perGroup[group]?.escapes ?? 0)") }

        precondition(structuralHazards > 0 && escapesWithoutSpans == structuralHazards, "the oracle must be live: with no spans every hazard escapes")
        precondition(escapesWithSpans == 0, "acceptance criterion 1 failed: \(escapesWithSpans) digit-structural hazard edits escaped")
        precondition(percent <= 2.0, "acceptance criterion 4 failed: \(percent)% protected outside labeled expressions")
        for group in ["odia-digits", "devanagari-digits"] { precondition(perGroup[group]?.escapes == 0 && perGroup[group]?.uncovered ?? 0 == 0, "acceptance criterion 5 failed for \(group)") }
        precondition(exactEntries == 192, "spans equal the labels for every entry (labels follow the same rule): \(exactEntries)/192")
    }

    /// Evidence that does not depend on any authored case: seeded random strings over an alphabet of
    /// digits (Latin, Odia, Devanagari), joiners, spaces, tabs, line breaks, letters and marks, run through
    /// the same whole-text hazard oracle. Not part of the frozen corpus and never tuned against.
    private static func testRandomizedRobustnessBeyondTheFrozenCorpus() {
        let alphabet = ["0", "1", "5", "9", "\u{0B67}", "\u{0B6A}", "\u{0967}", "\u{096D}", ",", ".", "-", "/", ":", " ", " ", "\t", "\n", "a", "Z", "\u{0B13}", "\u{0915}", "\u{0301}", "(", ")", "+", "\u{20B9}", "\u{00A0}"]
        var seed: UInt64 = 0x1234_5678_9ABC_DEF0
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }
        var hazards = 0
        var escapes = 0
        for _ in 0..<1500 {
            let text = (0..<(1 + next(22))).map { _ in alphabet[next(alphabet.count)] }.joined()
            let ns = text as NSString
            let spans = NumericStructuralProtection.spans(in: text)
            let original = self.signature(text)
            for mutation in self.mutations(of: text) {
                let expected = ns.substring(with: mutation.range)
                guard IntelligenceEditClassifier.classify(from: expected, to: mutation.replacement) != .other else { continue }
                let after = self.signature(ns.replacingCharacters(in: mutation.range, with: mutation.replacement))
                guard after.runs != original.runs || after.separators != original.separators else { continue }
                hazards += 1
                let proposal = IntelligenceProposal(id: "r", range: mutation.range, expectedSourceText: expected, replacementText: mutation.replacement, claimedCategory: .other)
                if case .autonomouslyAccepted = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: text, protectedSpans: spans).outcomes[0].disposition {
                    escapes += 1
                    print("RANDOM ESCAPE \(text.debugDescription) \(mutation.range) -> \(mutation.replacement.debugDescription)")
                }
            }
        }
        print("randomized robustness: 1500 seeded strings, \(hazards) digit-structural hazard edits, \(escapes) escapes")
        precondition(hazards > 1000, "the randomized oracle must be live")
        precondition(escapes == 0, "randomized robustness found \(escapes) escaping hazard edits")
    }

    // MARK: - Composition with V1.11 spans and the V1.8 path

    private static func testCompositionWithDerivedSpansAndTheV18Path() {
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/Fluid/Resources")
        guard let bundle = Bundle(path: resources.path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else { preconditionFailure("cannot load the Indian Legal Core") }
        let processor = LegalDictationProcessor(builtinPack: pack)
        let outcome = processor.process("P W one Ram Das proved Ext. P-1 dated 12.07.2026 for Rs. 5,000 under section three zero two I P C on 12 34 and stands.")
        precondition(outcome.normalized == "PW-1 Ram Das proved Ext. P-1 dated 12.07.2026 for Rs. 5,000 under Section 302 IPC on 12 34 and stands.", outcome.normalized)
        guard case let .success(derived) = ProtectedSpanDerivation.derive(from: outcome) else { preconditionFailure("derivation must succeed") }
        let combined = derived.spansIncludingNumericStructure
        precondition(combined.count == derived.spans.count + NumericStructuralProtection.spans(in: outcome.normalized).count, "composition is concatenation; nothing dropped or merged")
        precondition(Array(combined.prefix(derived.spans.count)) == derived.spans, "V1.11 spans are preserved verbatim and first")
        precondition(combined.contains { $0.kind == .independentlyProtected } && combined.contains { $0.kind == .deterministicallyResolved })

        func response(_ edits: [(String, String)]) -> IntelligenceProviderResponse {
            func quote(_ value: String) -> String { String(data: (try? JSONEncoder().encode(value)) ?? Data(), encoding: .utf8) ?? "\"\"" }
            let body = edits.map { #"{"sourceText":\#(quote($0.0)),"replacementText":\#(quote($0.1))}"# }.joined(separator: ",")
            return IntelligenceProviderResponse(toolCalls: [IntelligenceProviderToolCall(name: ModelFacingGenerationContract.toolName, rawArguments: #"{"schemaVersion":1,"edits":[\#(body)]}"#)])
        }
        func compose(_ edits: [(String, String)], spans: [ProtectedSpan]) -> IntelligenceCompositionResult {
            guard case let .success(result) = IntelligenceEditComposition.evaluate(response: response(edits), source: outcome.normalized, protectedSpans: spans) else { preconditionFailure("composition failed") }
            return result
        }
        let edits = [
            ("12.07.2026", "12072026"), // punctuation-only, inside a numeric span
            ("5,000", "5.000"), // punctuation-only, inside a numeric span
            ("12 34", "1234"), // whitespace-only, merges numerals
            ("Section", "SECTION"), // capitalization inside a V1.11 resolved span
            ("302", "3,02"), // punctuation edit on digits INSIDE a V1.11 resolved span (overlapping spans)
            ("stands", "Stands"), // outside every span
            ("Ram Das", "RamDas"), // names remain unprotected (out of scope)
        ]
        // Without the numeric spans (V1.11 alone) the numeric hazards are autonomous.
        let v111Only = compose(edits, spans: derived.spans)
        for index in [0, 1, 2] {
            guard case .autonomouslyAccepted = v111Only.edits[index].disposition ?? .rejected(.invalidRange) else { preconditionFailure("premise: V1.11 alone lets edit \(index) through") }
        }
        // With them: review-only for the numeric ones; resolved spans still win where they overlap.
        let protected = compose(edits, spans: combined)
        precondition(protected.edits[0].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(protected.edits[1].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(protected.edits[2].disposition == .reviewOnly(.intersectsIndependentlyProtectedSpan))
        precondition(protected.edits[3].disposition == .rejected(.intersectsResolvedSpan))
        precondition(protected.edits[4].disposition == .rejected(.intersectsResolvedSpan), "overlap of a resolved and an independent span: the more restrictive (resolved) wins")
        guard case .autonomouslyAccepted = protected.edits[5].disposition ?? .rejected(.invalidRange) else { preconditionFailure("an edit outside every span is still accepted") }
        guard case .autonomouslyAccepted = protected.edits[6].disposition ?? .rejected(.invalidRange) else { preconditionFailure("names are out of scope and stay unprotected") }
        precondition(protected.accepted.map(\.id) == ["p6", "p7"] && protected.reviewOnly.map(\.id) == ["p1", "p2", "p3"] && protected.rejectedBySafetyAuthority.map(\.id) == ["p4", "p5"])
    }
}
