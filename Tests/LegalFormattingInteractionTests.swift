import Foundation

// Minimal stand-ins for the app types the real formatting code reads. The real
// `applyGAAVFormatting` / `applyContinuousDictationFormatting` bodies are
// extracted verbatim from ASRService.swift by scripts/test_legal_language.sh
// and compiled with these stubs; only their settings source is faked.
final class SettingsStore {
    static let shared = SettingsStore()
    var literalDictationFormattingEnabled = false
    var gaavLowercaseFirstLetterEnabled = false
    var gaavRemoveTrailingPeriodEnabled = false
    var continuousDictationSpacingEnabled = false
    var contextAwareCapitalizationEnabled = false
}

final class ASRService {}

/// Legal normalization output vs. inherited presentation formatters that can
/// lowercase the first character (GAAV, context-aware capitalization).
@main
enum LegalFormattingInteractionTests {
    static let processor = LegalDictationProcessor(builtinPack: loadPack())
    static let midSentence = "Held that the accused, "

    static func main() {
        testWitnessProtectedUnderGAAV()
        testStatutoryProtectedUnderGAAV()
        testContextAwareCapsMidSentence()
        testOrdinaryTextFollowsSettings()
        testCanonicalWithoutAppliedChangeIsNotProtected()
        testAIRewriteThatMovesTokenDropsProtection()
        testLeadingWhitespaceAndNonLeadingReferences()
        SettingsStore.shared.gaavLowercaseFirstLetterEnabled = false
        SettingsStore.shared.contextAwareCapitalizationEnabled = false
        print("PASS: legal-normalized leading tokens survive GAAV / context-aware capitalization")
    }

    private static func loadPack() -> LanguagePack {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Fluid/Resources")
        guard let bundle = Bundle(path: resources.path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            preconditionFailure("bundled Indian Legal Core must load")
        }
        return pack
    }

    /// Mirrors the ContentView sequence after legal normalization (also the
    /// reprocess sequence): GAAV, then continuous-dictation formatting.
    private static func present(_ dictation: String, preceding: String = "", aiOutput: String? = nil) -> String {
        let outcome = processor.process(dictation)
        var text = aiOutput ?? outcome.normalized
        text = ASRService.applyGAAVFormatting(text, preserveLeadingCapitalization: outcome.protectsLeadingCapitalization(of: text))
        return ASRService.applyContinuousDictationFormatting(
            text,
            precedingText: preceding,
            preserveLeadingCapitalization: outcome.protectsLeadingCapitalization(of: text)
        )
    }

    private static func settings(gaav: Bool = false, smartCaps: Bool = false) {
        SettingsStore.shared.gaavLowercaseFirstLetterEnabled = gaav
        SettingsStore.shared.contextAwareCapitalizationEnabled = smartCaps
    }

    private static func expect(_ actual: String, _ expected: String, _ note: String, line: UInt = #line) {
        precondition(actual == expected, "line \(line) [\(note)]: '\(actual)' != '\(expected)'")
    }

    private static func testWitnessProtectedUnderGAAV() {
        settings(gaav: true)
        expect(present("P W one stated that"), "PW-1 stated that", "PW")
        expect(present("defence witness number two denied it"), "DW-2 denied it", "DW")
    }

    private static func testStatutoryProtectedUnderGAAV() {
        settings(gaav: true)
        expect(present("section three zero two of the I P C applies"), "Section 302 IPC applies", "single")
        expect(
            present("sections two nine four, three two three, three four one and five zero six of the I P C apply"),
            "Sections 294, 323, 341 and 506 IPC apply",
            "list"
        )
    }

    private static func testContextAwareCapsMidSentence() {
        settings(smartCaps: true)
        expect(present("P W one stated", preceding: midSentence), "PW-1 stated", "PW mid-sentence")
        expect(present("section three zero two of the I P C applies", preceding: midSentence), "Section 302 IPC applies", "section mid-sentence")
        // Sentence boundary still capitalizes as before.
        expect(present("P W one stated", preceding: "Done. "), "PW-1 stated", "boundary")
    }

    private static func testOrdinaryTextFollowsSettings() {
        settings(gaav: true)
        expect(present("The court adjourned the matter."), "the court adjourned the matter.", "GAAV on ordinary text")
        settings(smartCaps: true)
        expect(present("The court adjourned", preceding: midSentence), "the court adjourned", "smart caps mid-sentence")
        expect(present("the court adjourned", preceding: "Done. "), "The court adjourned", "smart caps boundary")
        // A legal reference that is not leading is unaffected by protection.
        settings(gaav: true)
        expect(present("The accused faces section three zero two of the I P C"), "the accused faces Section 302 IPC", "non-leading")
    }

    private static func testCanonicalWithoutAppliedChangeIsNotProtected() {
        // Already canonical: no legal change applied, so ordinary settings win.
        settings(gaav: true)
        expect(present("PW-1 stated that"), "pW-1 stated that", "canonical PW, GAAV")
        expect(present("Section 302 IPC applies"), "section 302 IPC applies", "canonical section, GAAV")
        settings(smartCaps: true)
        expect(present("PW-1 stated", preceding: midSentence), "pW-1 stated", "canonical PW, smart caps")
        let outcome = processor.process("PW-1 stated")
        precondition(!outcome.protectsLeadingCapitalization(of: outcome.normalized))
    }

    private static func testAIRewriteThatMovesTokenDropsProtection() {
        // If AI reorders the text so the produced token no longer leads, the
        // formatter follows ordinary settings for whatever now leads.
        settings(gaav: true)
        expect(
            present("P W one stated that", aiOutput: "The witness PW-1 stated that"),
            "the witness PW-1 stated that",
            "AI moved token"
        )
        expect(present("P W one stated that", aiOutput: "PW-1 stated that."), "PW-1 stated that.", "AI kept token")
    }

    private static func testLeadingWhitespaceAndNonLeadingReferences() {
        settings(smartCaps: true)
        expect(present("  P W one stated", preceding: midSentence), "  PW-1 stated", "leading whitespace")
    }
}
