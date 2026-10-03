import Foundation

/// Intelligence V1.31 -- model-independent probe of the CURRENT autonomous policy (illustrative, not a corpus).
///
/// Runs a small, hand-authored set of representative edits through the real, unmodified preflight (legal normalization +
/// protected spans) and `IntelligenceSafetyAuthority` and prints the disposition each receives today, beside the tier the V1.31
/// proposed taxonomy assigns it. The texts are new, synthetic illustrations written for this probe (none is taken from the
/// V1.23 benchmark or the V1.27 development corpus, and no model produced any edit). It measures nothing about any model, scores
/// nothing, and changes no policy: it exists so the "current vs proposed" comparison in the findings document is reproducible.
///
///   scripts/intelligence_v1_31_policy_probe.sh [--write PATH]
@main
enum CurrentPolicyProbe {
    struct Case {
        let id: String
        let policyClass: String
        let text: String
        /// The exact substring the edit replaces (must occur exactly once in the legal-normalized text).
        let from: String
        let to: String
        /// V1.31 tier (adopted framework; the per-class assignment is a proposal): T1 deterministic processing, T2 potentially autonomous
        /// only with deterministic evidence that does not yet exist, T3 review-only, T4 prohibited / abstain.
        let tier: String
        let note: String
    }

    static let cases: [Case] = [
        Case(
            id: "W1",
            policyClass: "whitespace: collapse repeated space",
            text: "the clerk read  the order aloud",
            from: "read  the",
            to: "read the",
            tier: "T1",
            note: "deterministic normalization"
        ),
        Case(
            id: "W2",
            policyClass: "whitespace: add trailing space (creates doubled space)",
            text: "the usher stopped and he denied every suggestion",
            from: "he denied",
            to: "he denied ",
            tier: "T4",
            note: "result would contain a doubled space"
        ),
        Case(
            id: "W3",
            policyClass: "whitespace: split run-together token",
            text: "the noticewas served personally",
            from: "noticewas",
            to: "notice was",
            tier: "T3",
            note: "token-sequence change; T2 only with lexicon evidence"
        ),
        Case(
            id: "W4",
            policyClass: "whitespace: split inside a name-shaped token",
            text: "the witness Ramdas appeared",
            from: "Ramdas",
            to: "Ram das",
            tier: "T4",
            note: "name identity"
        ),
        Case(
            id: "W5",
            policyClass: "whitespace: merge two words",
            text: "the witness Ram Das appeared",
            from: "Ram Das",
            to: "RamDas",
            tier: "T4",
            note: "token-sequence change"
        ),
        Case(
            id: "W6",
            policyClass: "whitespace: introduce a line break",
            text: "first point second point",
            from: "point second",
            to: "point\nsecond",
            tier: "T4",
            note: "layout is user-triggered"
        ),
        Case(
            id: "P1",
            policyClass: "punctuation: terminal period where none exists",
            text: "the petition was dismissed",
            from: "dismissed",
            to: "dismissed.",
            tier: "T2",
            note: "needs end-of-segment evidence"
        ),
        Case(
            id: "P2",
            policyClass: "punctuation: comma after introductory adverb",
            text: "however the accused did not appear",
            from: "however",
            to: "however,",
            tier: "T3",
            note: "stylistic, not rule-derivable"
        ),
        Case(
            id: "P3",
            policyClass: "punctuation: comma that changes clause scope",
            text: "the accused who was present objected",
            from: "accused who",
            to: "accused, who",
            tier: "T4",
            note: "restrictive vs non-restrictive meaning"
        ),
        Case(
            id: "P4",
            policyClass: "punctuation: replace existing period with comma",
            text: "the clerk rose. and the bench retired",
            from: "rose.",
            to: "rose,",
            tier: "T4",
            note: "changes an existing mark"
        ),
        Case(
            id: "P5",
            policyClass: "punctuation: delete an existing comma",
            text: "the witness, said nothing further",
            from: "witness,",
            to: "witness",
            tier: "T4",
            note: "changes an existing mark"
        ),
        Case(
            id: "P6",
            policyClass: "punctuation: question mark added",
            text: "was the notice served",
            from: "served",
            to: "served?",
            tier: "T3",
            note: "question vs statement is information"
        ),
        Case(
            id: "P7",
            policyClass: "punctuation: replace period with question mark",
            text: "the notice was served.",
            from: "served.",
            to: "served?",
            tier: "T4",
            note: "changes an existing mark"
        ),
        Case(
            id: "P8",
            policyClass: "punctuation: intra-token apostrophe",
            text: "the Honble Court rose",
            from: "Honble",
            to: "Hon'ble",
            tier: "T3",
            note: "inside a word"
        ),
        Case(
            id: "C1",
            policyClass: "capitalization: sentence-initial after a terminal period",
            text: "The bench rose. the clerk read the order.",
            from: "the clerk",
            to: "The clerk",
            tier: "T2",
            note: "needs sentence-boundary evidence"
        ),
        Case(
            id: "C2",
            policyClass: "capitalization: raise ordinary non-initial word (title)",
            text: "the matter was argued by counsel yesterday",
            from: "counsel",
            to: "Counsel",
            tier: "T3",
            note: "asserts a title/role"
        ),
        Case(
            id: "C3",
            policyClass: "capitalization: raise a name-shaped token",
            text: "the report was prepared by lakshmi nayak",
            from: "lakshmi nayak",
            to: "Lakshmi Nayak",
            tier: "T3",
            note: "T2 only with a case vocabulary"
        ),
        Case(
            id: "C4",
            policyClass: "capitalization: lower a title",
            text: "the Court rose at noon",
            from: "Court",
            to: "court",
            tier: "T4",
            note: "lowering changes a deliberate form"
        ),
        Case(
            id: "C5",
            policyClass: "capitalization: lower an acronym",
            text: "charged under the NDPS Act",
            from: "NDPS",
            to: "ndps",
            tier: "T4",
            note: "acronym"
        ),
        Case(
            id: "C6",
            policyClass: "capitalization: lower a sentence-initial letter",
            text: "The bench rose at noon.",
            from: "The bench",
            to: "the bench",
            tier: "T4",
            note: "lowering"
        ),
        Case(
            id: "C7",
            policyClass: "capitalization: raise after an abbreviation period",
            text: "the vehicle viz. the truck was seized",
            from: "the truck",
            to: "The truck",
            tier: "T3",
            note: "the period is not a sentence boundary"
        ),
        Case(
            id: "C8",
            policyClass: "capitalization: month name (closed lexicon)",
            text: "the hearing was adjourned to the twelfth of july",
            from: "july",
            to: "July",
            tier: "T2",
            note: "closed calendar lexicon"
        ),
        Case(
            id: "C9",
            policyClass: "capitalization: identifier case",
            text: "marked as Exhibit P9 in evidence",
            from: "P9",
            to: "p9",
            tier: "T4",
            note: "identifier"
        ),
        Case(
            id: "N1",
            policyClass: "numeric: change a digit inside an applied statutory normalization",
            text: "section three zero two IPC was invoked",
            from: "302",
            to: "303",
            tier: "T4",
            note: "applied normalization is final"
        ),
        Case(
            id: "N2",
            policyClass: "numeric: spelled amount to digits",
            text: "he paid five thousand rupees as a fine",
            from: "five thousand",
            to: "5,000",
            tier: "T4",
            note: "deterministic grammar only"
        ),
        Case(
            id: "N3",
            policyClass: "numeric: change a date separator",
            text: "the order dated 12.07.2026 was produced",
            from: "12.07.2026",
            to: "12/07/2026",
            tier: "T4",
            note: "protected numeric structure"
        ),
        Case(
            id: "G1",
            policyClass: "grammar: delete a repeated word",
            text: "he was was released on bail",
            from: "was was",
            to: "was",
            tier: "T3",
            note: "dictated word removed"
        ),
        Case(
            id: "G2",
            policyClass: "grammar: agreement",
            text: "the witnesses was examined",
            from: "was",
            to: "were",
            tier: "T4",
            note: "wording change"
        ),
        Case(
            id: "L1",
            policyClass: "lexical: homophone substitution",
            text: "the accused was granted bale",
            from: "bale",
            to: "bail",
            tier: "T3",
            note: "recognition repair"
        ),
        Case(
            id: "A1",
            policyClass: "ambiguity: comma choosing a reading",
            text: "the witness said no he was not there",
            from: "no he",
            to: "no, he",
            tier: "T4",
            note: "resolves an ambiguity"
        ),
        Case(
            id: "S1",
            policyClass: "structural: whole-sentence span, one-letter capital",
            text: "The bench rose. the clerk read the order.",
            from: "the clerk read the order.",
            to: "The clerk read the order.",
            tier: "T2",
            note: "judged on net effect"
        ),
        Case(
            id: "S2",
            policyClass: "structural: span merely containing protected digits",
            text: "the fine of 5000 rupees was paid late",
            from: "the fine of 5000 rupees was paid late",
            to: "The fine of 5000 rupees was paid late",
            tier: "T2",
            note: "net effect touches no digit"
        ),
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
            "| id | class | tier | current disposition | relation |",
            "|---|---|---|---|---|",
        ]
        var counts: [String: Int] = [:]
        for item in self.cases {
            guard case let .success(pre) = IntelligenceHarnessPipeline.preflight(rawInputText: item.text, processor: processor) else {
                preconditionFailure("\(item.id): preflight failed")
            }
            let source = pre.normalizedText as NSString
            let range = source.range(of: item.from)
            guard range.location != NSNotFound else { preconditionFailure("\(item.id): edit source not in normalized text: \(pre.normalizedText)") }
            let proposal = IntelligenceProposal(
                id: item.id,
                range: range,
                expectedSourceText: item.from,
                replacementText: item.to,
                claimedCategory: .other
            )
            let outcome = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: pre.normalizedText, protectedSpans: pre.protectedSpans)
                .outcomes[0]
            let disposition: String
            let kind: String
            switch outcome.disposition {
            case let .autonomouslyAccepted(classification):
                disposition = "autonomous (\(classification))"
                kind = "autonomous"
            case let .reviewOnly(reason):
                disposition = "review-only (\(reason))"
                kind = "review"
            case let .rejected(reason):
                disposition = "rejected (\(reason))"
                kind = "rejected"
            }
            let relation = switch (item.tier, kind) {
            case ("T1", "autonomous"), ("T2", "autonomous"): "autonomous; adopted policy needs deterministic processing/evidence not yet present"
            case ("T1", _), ("T2", _): "not autonomous (potential T1/T2 class)"
            case ("T3", "review"), ("T4", "rejected"): "agrees"
            case ("T3", "autonomous"): "broader than T3 (review-only)"
            case ("T4", "autonomous"): "broader than T4 (prohibited)"
            case ("T3", "rejected"): "stricter than T3 (rejected)"
            case ("T4", "review"): "not autonomous (review-only; T4 prohibits autonomy)"
            default: "?"
            }
            counts[relation, default: 0] += 1
            let cleaned = disposition.replacingOccurrences(of: "main.", with: "").replacingOccurrences(
                of: "IntelligenceEditClassification.",
                with: ""
            )
            lines.append("| \(item.id) | \(item.policyClass) | \(item.tier) | \(cleaned) | \(relation) |")
        }
        lines.append("")
        lines.append("counts: \(counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")) of \(self.cases.count)")
        let output = lines.joined(separator: "\n") + "\n"
        print(output)
        if let write {
            try output.write(toFile: write, atomically: true, encoding: .utf8)
        }
    }
}
