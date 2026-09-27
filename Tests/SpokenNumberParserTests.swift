import Foundation

@main
enum SpokenNumberParserTests {
    static func main() {
        testDigitByDigit()
        testTensChunk()
        testLetterSuffix()
        testMixedDigitAndTensChunk()
        testNoNumberAtStart()
        testUnrecognizedWordStopsParsing()
        testConsumesOnlyOneTrailingLetter()

        // Phase 3F.B: bounded grouped-number grammar.
        testTensOnlyLeadingDigit()
        testGroupedDigitTensDigit()
        testExistingDigitByDigitFormsUnaffectedByGrouping()
        testExistingDigitPlusTensNoTrailingDigitUnaffected()
        testTeenDoesNotComposeWithTrailingDigit()
        testGroupedShapeWithLetterSuffix()

        print("PASS: SpokenNumberParser strict digit/tens parsing and letter-suffix handling")
    }

    private static func testDigitByDigit() {
        let result = SpokenNumberParser.parse(tokens: ["three", "zero", "two"], startingAt: 0)
        precondition(result?.digits == "302")
        precondition(result?.letterSuffix == nil)
        precondition(result?.tokensConsumed == 3)
    }

    private static func testTensChunk() {
        // "one twenty" -> "1" + "20" = "120", per the approved concatenation grammar.
        let result = SpokenNumberParser.parse(tokens: ["one", "twenty"], startingAt: 0)
        precondition(result?.digits == "120")
        precondition(result?.tokensConsumed == 2)
    }

    private static func testLetterSuffix() {
        let a = SpokenNumberParser.parse(tokens: ["three", "seven", "six", "A"], startingAt: 0)
        precondition(a?.formatted == "376A")
        precondition(a?.tokensConsumed == 4)

        let b = SpokenNumberParser.parse(tokens: ["one", "twenty", "B"], startingAt: 0)
        precondition(b?.formatted == "120B")
        precondition(b?.tokensConsumed == 3)
    }

    private static func testMixedDigitAndTensChunk() {
        // Amendment corpus values, all pure digit-by-digit.
        let cases: [([String], String)] = [
            (["two", "nine", "four"], "294"),
            (["three", "two", "three"], "323"),
            (["three", "four", "one"], "341"),
            (["five", "zero", "six"], "506"),
        ]
        for (tokens, expected) in cases {
            let result = SpokenNumberParser.parse(tokens: tokens, startingAt: 0)
            precondition(result?.digits == expected, "Expected \(expected) from \(tokens)")
        }
    }

    private static func testNoNumberAtStart() {
        precondition(SpokenNumberParser.parse(tokens: ["the", "argument"], startingAt: 0) == nil)
    }

    private static func testUnrecognizedWordStopsParsing() {
        // "three zero maybe two" -- parsing stops at the unrecognized word;
        // caller sees a 2-digit result ("30"), not a guess spanning "maybe".
        let result = SpokenNumberParser.parse(tokens: ["three", "zero", "maybe", "two"], startingAt: 0)
        precondition(result?.digits == "30")
        precondition(result?.tokensConsumed == 2)
    }

    private static func testConsumesOnlyOneTrailingLetter() {
        // A multi-character token right after a number is not a letter suffix.
        let result = SpokenNumberParser.parse(tokens: ["three", "zero", "two", "of"], startingAt: 0)
        precondition(result?.letterSuffix == nil)
        precondition(result?.tokensConsumed == 3)
    }

    // MARK: - Phase 3F.B: bounded grouped-number grammar
    //
    // Distinct from pure concatenation: a tens-word combines arithmetically
    // with an optional leading (hundreds) digit and/or an optional trailing
    // (units) digit, rather than each token contributing its own
    // independent string segment.

    private static func testTensOnlyLeadingDigit() {
        // "thirty four" -> 34, not "30"+"4"="304".
        let result = SpokenNumberParser.parse(tokens: ["thirty", "four"], startingAt: 0)
        precondition(result?.digits == "34", "\(String(describing: result?.digits))")
        precondition(result?.tokensConsumed == 2)
    }

    private static func testGroupedDigitTensDigit() {
        // digit + tens + digit -> hundreds*100 + tens + units, not textual concatenation.
        let cases: [([String], String)] = [
            (["one", "forty", "four"], "144"),
            (["three", "twenty", "three"], "323"),
            (["three", "seventy", "six"], "376"),
            (["one", "twenty", "five"], "125"),
        ]
        for (tokens, expected) in cases {
            let result = SpokenNumberParser.parse(tokens: tokens, startingAt: 0)
            precondition(result?.digits == expected, "Expected \(expected) from \(tokens), got \(String(describing: result?.digits))")
            precondition(result?.tokensConsumed == 3, "\(tokens)")
        }
    }

    private static func testExistingDigitByDigitFormsUnaffectedByGrouping() {
        // None of these contain a tens-word, so grouping must never engage.
        let cases: [([String], String)] = [
            (["three", "four"], "34"),
            (["one", "four", "four"], "144"),
            (["three", "two", "three"], "323"),
            (["three", "seven", "six"], "376"),
            (["five", "zero", "six"], "506"),
            (["one", "two", "five"], "125"),
        ]
        for (tokens, expected) in cases {
            let result = SpokenNumberParser.parse(tokens: tokens, startingAt: 0)
            precondition(result?.digits == expected, "Expected \(expected) from \(tokens), got \(String(describing: result?.digits))")
            precondition(result?.tokensConsumed == tokens.count, "\(tokens)")
        }
    }

    private static func testExistingDigitPlusTensNoTrailingDigitUnaffected() {
        // The pre-existing, already-approved "digit + tens" idiom (no
        // trailing digit) must still produce the same value the same way.
        let result = SpokenNumberParser.parse(tokens: ["one", "twenty"], startingAt: 0)
        precondition(result?.digits == "120", "\(String(describing: result?.digits))")
        precondition(result?.tokensConsumed == 2)
    }

    private static func testTeenDoesNotComposeWithTrailingDigit() {
        // A teen ("ten".."nineteen") already encodes both digits and must
        // not absorb a further trailing digit-word the way twenty..ninety do.
        let result = SpokenNumberParser.parse(tokens: ["one", "thirteen", "four"], startingAt: 0)
        precondition(result?.digits == "113", "\(String(describing: result?.digits))")
        precondition(result?.tokensConsumed == 2, "must stop after the teen, leaving 'four' unconsumed")
    }

    private static func testGroupedShapeWithLetterSuffix() {
        // The existing trailing-letter-suffix mechanic must still apply on
        // top of a newly-grouped result.
        let result = SpokenNumberParser.parse(tokens: ["one", "twenty", "five", "B"], startingAt: 0)
        precondition(result?.formatted == "125B", "\(String(describing: result?.formatted))")
        precondition(result?.tokensConsumed == 4)
    }
}
