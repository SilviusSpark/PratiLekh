import Foundation

/// Intelligence V1.29 (S2) -- synthetic **tooling** fixtures.
///
/// Hand-authored, non-evaluation texts used only to exercise execution/scoring/analysis mechanics with scripted
/// stand-in outputs (never a model). They are NOT drawn from, derived from or transformations of any entry of the
/// V1.27 development corpus or the V1.23 benchmark; a separate parity test checks them against both corpora with
/// the V1.27 overlap rules (P1-P7). Compiled into both S2 test binaries.
enum S2ToolingFixtures {
    static let corpusSHA256 = CapabilitySHA256.hex(of: "S2-tooling-fixtures-v1")

    struct Spec {
        let id: String
        let category: String
        let text: String
        let expectation: String
        let corrections: [(String, String)]
        let requiresAll: Bool
        let manual: Bool
    }

    static let specs: [Spec] = [
        Spec(
            id: "TF-P1",
            category: "punctuation-correction-warranted",
            text: "the surveyor measured the boundary wall",
            expectation: "correctionWarranted",
            corrections: [("wall", "wall.")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-P2",
            category: "punctuation-correction-warranted",
            text: "the auctioneer announced the reserve price",
            expectation: "correctionWarranted",
            corrections: [("price", "price.")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-P3",
            category: "punctuation-correction-warranted",
            text: "the interpreter translated the plea",
            expectation: "correctionWarranted",
            corrections: [("plea", "plea.")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-P4",
            category: "punctuation-correction-warranted",
            text: "the stenographer circulated the roster",
            expectation: "correctionWarranted",
            corrections: [("roster", "roster.")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-C1",
            category: "capitalization-correction-warranted",
            text: "the clerk wrote to dr mohapatra about the adjournment.",
            expectation: "correctionWarranted",
            corrections: [("dr mohapatra", "Dr Mohapatra")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-C2",
            category: "capitalization-correction-warranted",
            text: "the bench rose at noon in jajpur.",
            expectation: "correctionWarranted",
            corrections: [("jajpur", "Jajpur")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-C3",
            category: "capitalization-correction-warranted",
            text: "a summons reached the officer at koraput yesterday.",
            expectation: "correctionWarranted",
            corrections: [("koraput", "Koraput")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-W1",
            category: "whitespace-correction-warranted",
            text: "the bailiffadjourned the sitting early.",
            expectation: "correctionWarranted",
            corrections: [("bailiffadjourned", "bailiff adjourned")],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-M1",
            category: "multi-edit-correction-warranted",
            text: "the porter locked the gate. the cook served tea",
            expectation: "correctionWarranted",
            corrections: [("the cook", "The cook"), ("tea", "tea.")],
            requiresAll: true,
            manual: false
        ),
        Spec(
            id: "TF-K1",
            category: "clean-control",
            text: "the peon delivered the sealed file.",
            expectation: "abstentionExpected",
            corrections: [],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-K2",
            category: "clean-control",
            text: "the sweeper reported the broken lamp.",
            expectation: "abstentionExpected",
            corrections: [],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-H1",
            category: "hazard-acronym-lowering",
            text: "The drawer answered the NI Act notice promptly.",
            expectation: "abstentionExpected",
            corrections: [],
            requiresAll: false,
            manual: false
        ),
        Spec(
            id: "TF-A1",
            category: "ambiguous",
            text: "the gatekeeper noted the hour as the tenth",
            expectation: "abstentionExpected",
            corrections: [],
            requiresAll: false,
            manual: true
        ),
    ]

    static let auditIDs = ["TF-P1", "TF-C1", "TF-K1"]

    private static func json(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text), let encoded = String(bytes: data, encoding: .utf8) else { preconditionFailure("encode") }
        return encoded
    }

    static func entries() -> [CapabilityCorpus.Entry] {
        self.specs.map { spec in
            let list = spec.corrections.map { "{\"source\":\(self.json($0.0)),\"replacement\":\(self.json($0.1))}" }.joined(separator: ",")
            let raw = """
            {"id":\(json(spec.id)),"category":\(self.json(spec.category)),"tier":"synthetic","text":\(self.json(spec.text)),"expectation":\(self.json(spec.expectation)),
            "expectedCorrections":[\(list)],"recallRequiresAll":\(spec.requiresAll),"manualAdjudicationOnly":\(spec.manual),
            "hazardNote":null,"knownRiskReference":null,"note":null}
            """
            guard let entry = try? JSONDecoder().decode(CapabilityCorpus.Entry.self, from: Data(raw.utf8))
            else { preconditionFailure("bad fixture entry") }
            return entry
        }
    }

    static func rawArguments(_ edits: [(String, String)]) -> String {
        let items = edits.map { "{\"sourceText\":\(self.json($0.0)),\"replacementText\":\(self.json($0.1))}" }.joined(separator: ",")
        return "{\"schemaVersion\":1,\"edits\":[\(items)]}"
    }

    static let emptyArguments = rawArguments([])

    static func oracleArguments(for entry: CapabilityCorpus.Entry) -> String {
        self.rawArguments(entry.expectedCorrections.map { ($0.source, $0.replacement) })
    }
}
