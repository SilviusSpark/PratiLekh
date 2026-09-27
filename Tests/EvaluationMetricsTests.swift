import Foundation

@main
enum EvaluationMetricsTests {
    static func main() {
        testWER()
        testCER()
        testNormalizationIgnoresCasePunctuationAndApostrophes()
        testEmptyReferenceHasNoRate()
        testFormatting()
        print("PASS: Evaluation text metrics (WER, CER, formatting)")
    }

    private static func near(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }

    private static func testWER() {
        let identical = TextMetrics.wer(reference: "the court adjourned", hypothesis: "the court adjourned")
        precondition(identical.edits == 0 && identical.referenceLength == 3 && near(identical.rate, 0))
        // one substitution in four words
        let sub = TextMetrics.wer(reference: "accused was present today", hypothesis: "accused was absent today")
        precondition(sub.edits == 1 && near(sub.rate, 0.25))
        // deletion of an article: still one edit
        let article = TextMetrics.wer(reference: "he saw the accused", hypothesis: "he saw accused")
        precondition(article.edits == 1 && article.referenceLength == 4)
        // insertion + substitution
        let mixed = TextMetrics.wer(reference: "section three zero two", hypothesis: "section three zero four now")
        precondition(mixed.edits == 2)
        // WER is number-blind on purpose: 302 vs 304 costs one word, same as a dropped article.
        // Legal accuracy is scored separately (critical tokens).
        let number = TextMetrics.wer(reference: "under section 302 ipc", hypothesis: "under section 304 ipc")
        precondition(number.edits == 1)
    }

    private static func testCER() {
        let cer = TextMetrics.cer(reference: "cat", hypothesis: "cut")
        precondition(cer.edits == 1 && cer.referenceLength == 3)
        let spaces = TextMetrics.cer(reference: "a b", hypothesis: "ab")
        precondition(spaces.edits == 1 && spaces.referenceLength == 3)
        precondition(TextMetrics.cer(reference: "same words", hypothesis: "Same, words!").edits == 0)
    }

    private static func testNormalizationIgnoresCasePunctuationAndApostrophes() {
        precondition(TextMetrics.normalizedWords("Don't stop, PW-1!") == ["dont", "stop", "pw", "1"])
        precondition(TextMetrics.wer(reference: "The Court.", hypothesis: "the court").edits == 0)
    }

    private static func testEmptyReferenceHasNoRate() {
        let rate = TextMetrics.wer(reference: "", hypothesis: "extra words")
        precondition(rate.rate == nil && rate.edits == 2)
    }

    private static func testFormatting() {
        let same = FormattingMetrics.score(intended: "PW-1 stated that.", actual: "PW-1 stated that.")
        precondition(same.comparable && same.caseDifferences == 0 && same.punctuationDifferences == 0)
        let cased = FormattingMetrics.score(intended: "PW-1 stated", actual: "pW-1 stated")
        precondition(cased.comparable && cased.caseDifferences == 1 && cased.punctuationDifferences == 0)
        let punct = FormattingMetrics.score(intended: "He left, then returned.", actual: "He left then returned")
        precondition(punct.comparable && punct.caseDifferences == 0 && punct.punctuationDifferences == 2)
        let different = FormattingMetrics.score(intended: "Section 302 IPC", actual: "Section 304 IPC")
        precondition(!different.comparable, "different words are a transcription error, not a formatting one")
    }
}
