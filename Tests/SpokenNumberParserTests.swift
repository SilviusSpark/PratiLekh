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
}
