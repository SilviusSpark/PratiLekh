import Foundation

/// Intelligence V1.36 -- model-independent probe of current whitespace behavior in the two deterministic components that can be
/// executed standalone (illustrative, not a corpus; nothing is scored or authorized):
///   A. the real `LegalDictationProcessor` (Phase-3 legal normalization) on whitespace variants of dictated text;
///   B. the real, unmodified `IntelligenceSafetyAuthority` on whitespace-only edits.
/// The pipeline stages that live in the app target (filler removal, custom dictionary, spoken-punctuation rendering) cannot be compiled
/// standalone and are described from source in the findings document, not executed here. Texts are new synthetic illustrations (none is
/// taken from any corpus); no model produced anything.
///
///   scripts/intelligence_v1_36_whitespace_probe.sh [--write PATH]
@main
enum WhitespaceBehaviorProbe {
    static func visible(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\u{00A0}": out += "\\u00A0"
            case "\u{2009}": out += "\\u2009"
            case " ": out += "\u{00B7}"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    struct LegalCase {
        let id: String
        let note: String
        let input: String
    }

    static let legalCases: [LegalCase] = [
        LegalCase(id: "L1", note: "baseline: single spaces", input: "the court cited section three zero two IPC today"),
        LegalCase(id: "L2", note: "doubled spaces outside the phrase", input: "the court cited  section three zero two IPC  today"),
        LegalCase(id: "L3", note: "doubled space inside the phrase (keyword/number)", input: "the court cited section  three zero two IPC today"),
        LegalCase(id: "L4", note: "doubled spaces between spoken digits", input: "the court cited section three  zero  two IPC today"),
        LegalCase(id: "L5", note: "tab inside the phrase", input: "the court cited section\tthree zero two IPC today"),
        LegalCase(id: "L6", note: "newline inside the phrase", input: "the court cited section\nthree zero two IPC today"),
        LegalCase(id: "L7", note: "NBSP inside the phrase", input: "the court cited section\u{00A0}three zero two IPC today"),
        LegalCase(id: "L8", note: "leading/trailing spaces around the text", input: "  the court cited section three zero two IPC today  "),
        LegalCase(id: "L9", note: "layout away from any rule: newline + indentation + tab", input: "first point\n    second point\n\tthird point"),
        LegalCase(id: "L10", note: "doubled space inside a witness reference", input: "the PW  two witness was examined"),
    ]

    struct EditCase {
        let id: String
        let note: String
        let text: String
        let from: String
        let to: String
    }

    static let editCases: [EditCase] = [
        EditCase(id: "E1", note: "collapse two ordinary spaces", text: "the clerk read  the order aloud", from: "read  the", to: "read the"),
        EditCase(
            id: "E2",
            note: "add a trailing space (creates a doubled space)",
            text: "the usher stopped and he denied every suggestion",
            from: "he denied",
            to: "he denied "
        ),
        EditCase(id: "E3", note: "tab to space", text: "column one\tcolumn two", from: "one\tcolumn", to: "one column"),
        EditCase(id: "E4", note: "NBSP to ordinary space", text: "the order of\u{00A0}Monday was read", from: "of\u{00A0}Monday", to: "of Monday"),
        EditCase(id: "E5", note: "remove the space before a full stop", text: "the notice was served .", from: "served .", to: "served."),
        EditCase(
            id: "E6",
            note: "remove line indentation (spaces after a newline)",
            text: "first point\n    second point",
            from: "    second",
            to: "second"
        ),
        EditCase(id: "E7", note: "remove two trailing spaces before a newline", text: "end of line  \nnext line", from: "line  ", to: "line"),
        EditCase(
            id: "E8",
            note: "insert a space inside an abbreviation",
            text: "the accused was charged under Cr.P.C proceedings",
            from: "Cr.P.C",
            to: "Cr. P.C"
        ),
        EditCase(
            id: "E9",
            note: "collapse a doubled space between digit groups",
            text: "marked as 12  34 in the register",
            from: "12  34",
            to: "12 34"
        ),
        EditCase(id: "E10", note: "thin space to ordinary space", text: "the sum of\u{2009}five was noted", from: "of\u{2009}five", to: "of five"),
    ]

    static func main() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var write: String?
        var arguments = Array(CommandLine.arguments.dropFirst())[...]
        while let argument = arguments.popFirst() {
            if argument == "--write" {
                write = arguments.popFirst()
            }
        }
        let processor = try IntelligenceHarnessLegalPack.makeProcessor(repoRoot: repoRoot.path)
        var lines = [
            "### A. Legal normalization on whitespace variants (real `LegalDictationProcessor`)",
            "",
            "| id | note | input | output | output == input |",
            "|---|---|---|---|---|",
        ]
        for item in self.legalCases {
            let output = processor.process(item.input).normalized
            lines.append("| \(item.id) | \(item.note) | `\(self.visible(item.input))` | `\(self.visible(output))` | \(output == item.input) |")
        }
        lines += [
            "",
            "### B. Current Authority disposition of whitespace edits (real, unmodified)",
            "",
            "| id | edit | disposition |",
            "|---|---|---|",
        ]
        for item in self.editCases {
            guard case let .success(pre) = IntelligenceHarnessPipeline.preflight(rawInputText: item.text, processor: processor) else {
                preconditionFailure("\(item.id): preflight failed")
            }
            let range = (pre.normalizedText as NSString).range(of: item.from)
            guard range.location != NSNotFound else { preconditionFailure("\(item.id): edit source not in normalized text") }
            let proposal = IntelligenceProposal(
                id: item.id,
                range: range,
                expectedSourceText: item.from,
                replacementText: item.to,
                claimedCategory: .other
            )
            let outcome = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: pre.normalizedText, protectedSpans: pre.protectedSpans)
                .outcomes[0]
            let disposition = "\(outcome.disposition)".replacingOccurrences(of: "main.", with: "").replacingOccurrences(
                of: "IntelligenceEditClassification.",
                with: ""
            )
            lines.append("| \(item.id) | \(item.note): `\(self.visible(item.from))` → `\(self.visible(item.to))` | \(disposition) |")
        }
        let text = lines.joined(separator: "\n") + "\n"
        print(text)
        if let write {
            try text.write(toFile: write, atomically: true, encoding: .utf8)
        }
    }
}
