import Foundation

@main
enum EditClassificationTests {
    static func main() {
        testCommaInsertionIsPunctuationOnly()
        testFullStopReplacementIsPunctuationOnly()
        testPunctuationDeletionIsPunctuationOnly()
        testPunctuationPlusWhitespaceChangeIsOther()
        testLowercaseToUppercaseIsCapitalizationOnly()
        testMixedCaseCorrectionIsCapitalizationOnly()
        testCapitalizationClaimHidingLexicalChangeIsOther()
        testDoubleSpaceCollapseIsWhitespaceOnly()
        testWhitespaceClaimHidingWordDeletionIsOther()
        testNewlineInsertionIsOtherEvenThoughOtherwiseWhitespaceOnly()
        testNoOpEditIsOther()
        testPunctuationOnlyAroundIndianNameIsPunctuationOnly()
        testCapitalizationOnlyOnIndianNameIsCapitalizationOnly()
        print("PASS: IntelligenceEditClassifier punctuation/capitalization/whitespace predicates")
    }

    private static func testCommaInsertionIsPunctuationOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "Section 302 IPC and Section 34", to: "Section 302 IPC, and Section 34")
        precondition(classification == .punctuationOnly, "\(classification)")
    }

    private static func testFullStopReplacementIsPunctuationOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "the accused was present,", to: "the accused was present.")
        precondition(classification == .punctuationOnly, "\(classification)")
    }

    private static func testPunctuationDeletionIsPunctuationOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "the witness stated, that", to: "the witness stated that")
        precondition(classification == .punctuationOnly, "\(classification)")
    }

    private static func testPunctuationPlusWhitespaceChangeIsOther() {
        // Adding a comma AND removing the following space is not purely a
        // punctuation edit: stripping punctuation from both sides no longer
        // yields equal strings once whitespace is also touched.
        let classification = IntelligenceEditClassifier.classify(from: "Hello world", to: "Hello,world")
        precondition(classification == .other, "\(classification)")
    }

    private static func testLowercaseToUppercaseIsCapitalizationOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "ipc", to: "IPC")
        precondition(classification == .capitalizationOnly, "\(classification)")
    }

    private static func testMixedCaseCorrectionIsCapitalizationOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "the Accused", to: "the accused")
        precondition(classification == .capitalizationOnly, "\(classification)")
    }

    private static func testCapitalizationClaimHidingLexicalChangeIsOther() {
        // BNS -> BNSS changes the actual word, not merely its case: the
        // case-folded forms differ ("bns" vs "bnss"), so this must never be
        // .capitalizationOnly no matter what a proposal claims.
        let classification = IntelligenceEditClassifier.classify(from: "BNS", to: "BNSS")
        precondition(classification == .other, "\(classification)")
    }

    private static func testDoubleSpaceCollapseIsWhitespaceOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "the accused  shall appear", to: "the accused shall appear")
        precondition(classification == .whitespaceOnly, "\(classification)")
    }

    private static func testWhitespaceClaimHidingWordDeletionIsOther() {
        // Deleting "the " changes the words present, not merely whitespace.
        let classification = IntelligenceEditClassifier.classify(from: "shall pay the amount", to: "shall pay amount")
        precondition(classification == .other, "\(classification)")
    }

    private static func testNewlineInsertionIsOtherEvenThoughOtherwiseWhitespaceOnly() {
        // Stripping whitespace from both sides would otherwise make this
        // look whitespace-only; the newline guard forces .other, since
        // introducing a line break is a deliberate, user-triggered concern,
        // not an autonomous surface edit.
        let classification = IntelligenceEditClassifier.classify(from: "first second", to: "first\nsecond")
        precondition(classification == .other, "\(classification)")
    }

    private static func testNoOpEditIsOther() {
        let classification = IntelligenceEditClassifier.classify(from: "unchanged", to: "unchanged")
        precondition(classification == .other, "\(classification)")
    }

    private static func testPunctuationOnlyAroundIndianNameIsPunctuationOnly() {
        let classification = IntelligenceEditClassifier.classify(
            from: "the complainant Sabyasachi Mohapatra stated",
            to: "the complainant, Sabyasachi Mohapatra, stated"
        )
        precondition(classification == .punctuationOnly, "\(classification)")
    }

    private static func testCapitalizationOnlyOnIndianNameIsCapitalizationOnly() {
        let classification = IntelligenceEditClassifier.classify(from: "sabyasachi mohapatra", to: "Sabyasachi Mohapatra")
        precondition(classification == .capitalizationOnly, "\(classification)")
    }
}
