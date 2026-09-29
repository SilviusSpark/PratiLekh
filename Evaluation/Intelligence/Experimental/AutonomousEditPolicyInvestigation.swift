import CryptoKit
import Foundation

// EXPERIMENTAL -- Intelligence V1.14 investigation only. Evaluates the candidate
// structural invariants of `AutonomousEditInvariants.swift` against the corpora in
// `Evaluation/References/autonomous-edit-policy/` through the REAL normalization,
// V1.11 derivation, V1.13 numeric protection, V1.6 resolver, classifier and
// Safety Authority, so measured gaps are those that remain AFTER existing
// protections. Run via `scripts/test_autonomous_edit_policy_investigation.sh`.
// Nothing here is production code and nothing changes production policy.

private struct Corpus: Decodable {
    struct Entry: Decodable {
        let id: String
        let expectation: String
        let hazard: String
        let text: String
        let source: String
        let replacement: String
        let left: String?
        let right: String?
        let occurrence: Int?
        let note: String
    }

    let entries: [Entry]
}

private struct Evaluated {
    let entry: Corpus.Entry
    let classification: IntelligenceEditClassification
    let autonomousClassifier: Bool
    let autonomousWithDerived: Bool
    let autonomousEffective: Bool
    let verdicts: [String: Bool]
}

private func sha256(_ url: URL) -> String {
    guard let data = try? Data(contentsOf: url) else { return "missing" }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func describe(_ classification: IntelligenceEditClassification) -> String {
    switch classification {
    case .punctuationOnly: return "punct"
    case .capitalizationOnly: return "case"
    case .whitespaceOnly: return "space"
    case .other: return "other"
    }
}

@main
enum AutonomousEditPolicyInvestigation {
    nonisolated(unsafe) private static var recorded: [String: Int] = [:]
    private static func record(_ key: String, _ value: Int) { self.recorded[key] = value }

    static func main() {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let bundle = Bundle(path: root.appendingPathComponent("Sources/Fluid/Resources").path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            preconditionFailure("cannot load the Indian Legal Core")
        }
        let processor = LegalDictationProcessor(builtinPack: pack)
        let policyDirectory = root.appendingPathComponent("Evaluation/References/autonomous-edit-policy")

        print("rules file SHA-256: \(sha256(root.appendingPathComponent("Evaluation/Intelligence/Experimental/AutonomousEditInvariants.swift")))")
        for tier in ["development", "validation", "fresh"] {
            let url = policyDirectory.appendingPathComponent("\(tier).json")
            guard let data = try? Data(contentsOf: url), let corpus = try? JSONDecoder().decode(Corpus.self, from: data) else {
                print("\n################ TIER: \(tier) — corpus not present ################")
                continue
            }
            print("\n################ TIER: \(tier) (\(corpus.entries.count) entries, corpus SHA-256 \(sha256(url))) ################")
            let evaluated = self.evaluate(corpus, processor: processor)
            self.report(evaluated, tier: tier)
        }
        if ProcessInfo.processInfo.environment["PRINT_PINS"] != nil {
            for key in self.recorded.keys.sorted() { print("PIN \(key)=\(self.recorded[key] ?? -1)") }
        }
        fflush(stdout)
        self.pin(root: root)
        print("All V1.14 autonomous-edit-policy investigation checks passed.")
    }

    // MARK: - Evaluation

    private static func evaluate(_ corpus: Corpus, processor: LegalDictationProcessor) -> [Evaluated] {
        var integrity: [String] = []
        var result: [Evaluated] = []
        for entry in corpus.entries {
            let outcome = processor.process(entry.text)
            let normalized = outcome.normalized
            var derivedSpans: [ProtectedSpan] = []
            switch ProtectedSpanDerivation.derive(from: outcome) {
            case let .success(spans): derivedSpans = spans.spans
            case .failure: integrity.append("\(entry.id): derivation failed")
            }
            let edit = ModelFacingEdit(sourceText: entry.source, replacementText: entry.replacement, occurrence: entry.occurrence, leftContext: entry.left, rightContext: entry.right)
            guard case let .success(resolution) = IntelligenceAddressingResolver.resolve(edit, in: normalized) else {
                integrity.append("\(entry.id): edit does not resolve in normalized text \(normalized.debugDescription)")
                continue
            }
            let ns = normalized as NSString
            let expected = ns.substring(with: resolution.range)
            let classification = IntelligenceEditClassifier.classify(from: expected, to: entry.replacement)
            let proposal = IntelligenceProposal(id: entry.id, range: resolution.range, expectedSourceText: expected, replacementText: entry.replacement, claimedCategory: .other)
            func accepted(_ spans: [ProtectedSpan]) -> Bool {
                if case .autonomouslyAccepted = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: normalized, protectedSpans: spans).outcomes[0].disposition { return true }
                return false
            }
            let numeric = NumericStructuralProtection.spans(in: normalized)
            let before = ns.substring(to: resolution.range.location)
            let after = ns.substring(from: resolution.range.location + resolution.range.length)
            var verdicts: [String: Bool] = [:]
            for invariant in AutonomousEditInvariant.allCases {
                verdicts[invariant.rawValue] = invariant.allows(before: before, expected: expected, replacement: entry.replacement, after: after, classification: classification)
            }
            for bundle in AutonomousEditInvariant.bundles {
                verdicts[bundle.name] = bundle.members.allSatisfy { verdicts[$0.rawValue] == true }
            }
            result.append(Evaluated(
                entry: entry,
                classification: classification,
                autonomousClassifier: classification != .other,
                autonomousWithDerived: accepted(derivedSpans),
                autonomousEffective: accepted(derivedSpans + numeric),
                verdicts: verdicts
            ))
        }
        precondition(integrity.isEmpty, "corpus integrity failures:\n" + integrity.joined(separator: "\n"))
        return result
    }

    // MARK: - Report

    private static func report(_ evaluated: [Evaluated], tier: String) {
        let names = AutonomousEditInvariant.allCases.map(\.rawValue) + AutonomousEditInvariant.bundles.map(\.name)

        print("\n== Funnel: how many edits remain autonomous after each existing protection")
        print("expectation   n   classifier  +V1.11  +V1.13(effective)")
        for expectation in ["legit", "dangerous", "ambiguous"] {
            let group = evaluated.filter { $0.entry.expectation == expectation }
            let counts = (group.count, group.filter(\.autonomousClassifier).count, group.filter(\.autonomousWithDerived).count, group.filter(\.autonomousEffective).count)
            print("\(expectation.padding(toLength: 12, withPad: " ", startingAt: 0)) \(counts.0)   \(counts.1)          \(counts.2)      \(counts.3)")
            for (key, value) in [("n", counts.0), ("classifier", counts.1), ("v111", counts.2), ("effective", counts.3)] { self.record("\(tier).funnel.\(expectation).\(key)", value) }
        }
        let legitNotAutonomous = evaluated.filter { $0.entry.expectation == "legit" && !$0.autonomousEffective }
        if !legitNotAutonomous.isEmpty {
            print("legit edits NOT autonomous today (classifier/spans already demote): " + legitNotAutonomous.map { "\($0.entry.id)[\(describe($0.classification))\($0.autonomousClassifier ? ",spans" : "")]" }.joined(separator: " "))
        }

        print("\n== Remaining gap: dangerous edits still autonomous after existing protections, by hazard and predicate")
        let dangerous = evaluated.filter { $0.entry.expectation == "dangerous" }
        for hazard in Set(dangerous.map(\.entry.hazard)).sorted() {
            let group = dangerous.filter { $0.entry.hazard == hazard }
            let remaining = group.filter(\.autonomousEffective)
            let predicates = Dictionary(grouping: remaining, by: { describe($0.classification) }).mapValues(\.count).sorted { $0.key < $1.key }
            print("\(hazard.padding(toLength: 22, withPad: " ", startingAt: 0)) total \(group.count)  contained-by-existing \(group.count - remaining.count)  remaining \(remaining.count)  predicate \(predicates)")
            self.record("\(tier).gap.\(hazard).total", group.count)
            self.record("\(tier).gap.\(hazard).remaining", remaining.count)
        }
        let contained = dangerous.filter { !$0.autonomousEffective }
        print("contained already: " + contained.map { "\($0.entry.id)[\($0.autonomousClassifier ? "spans" : "classifier")]" }.joined(separator: " "))

        print("\n== Invariants: benefit (dangerous remaining that they demote) vs cost (legit autonomous that they demote)")
        let dangerousRemaining = dangerous.filter(\.autonomousEffective)
        let legitRemaining = evaluated.filter { $0.entry.expectation == "legit" && $0.autonomousEffective }
        let ambiguousRemaining = evaluated.filter { $0.entry.expectation == "ambiguous" && $0.autonomousEffective }
        print("(dangerous remaining \(dangerousRemaining.count), legit autonomous \(legitRemaining.count), ambiguous autonomous \(ambiguousRemaining.count))")
        print("invariant   blocked/danger  demoted/legit  ambiguous-demoted")
        for name in names {
            let blocked = dangerousRemaining.filter { $0.verdicts[name] == false }.count
            let demoted = legitRemaining.filter { $0.verdicts[name] == false }
            let ambiguous = ambiguousRemaining.filter { $0.verdicts[name] == false }.count
            print("\(name.padding(toLength: 11, withPad: " ", startingAt: 0)) \(blocked)/\(dangerousRemaining.count)            \(demoted.count)/\(legitRemaining.count)          \(ambiguous)/\(ambiguousRemaining.count)")
            self.record("\(tier).inv.\(name).blocked", blocked)
            self.record("\(tier).inv.\(name).demoted", demoted.count)
            self.record("\(tier).inv.\(name).ambiguous", ambiguous)
            if AutonomousEditInvariant.bundles.contains(where: { $0.name == name }) || !demoted.isEmpty {
                print("    legit demoted: " + (demoted.isEmpty ? "-" : demoted.map(\.entry.id).joined(separator: " ")))
            }
        }
        for bundle in AutonomousEditInvariant.bundles {
            let escaping = dangerousRemaining.filter { $0.verdicts[bundle.name] == true }
            print("still autonomous under \(bundle.name): " + (escaping.isEmpty ? "-" : escaping.map { "\($0.entry.id)(\($0.entry.hazard))" }.joined(separator: " ")))
        }
        print("\n== Coverage matrix: dangerous edits still autonomous (remaining) that each invariant demotes, per hazard")
        let columns = ["W-A1", "W-A2", "P-A", "P-B", "C-A2", "C-C", "core+P-A"]
        print("hazard                 remaining " + columns.map { $0.padding(toLength: 9, withPad: " ", startingAt: 0) }.joined())
        for hazard in Set(dangerousRemaining.map(\.entry.hazard)).sorted() {
            let group = dangerousRemaining.filter { $0.entry.hazard == hazard }
            var cells = ""
            for column in columns {
                let blocked = group.filter { $0.verdicts[column] == false }.count
                self.record("\(tier).matrix.\(hazard).\(column)", blocked)
                cells += String(blocked).padding(toLength: 9, withPad: " ", startingAt: 0)
            }
            print("\(hazard.padding(toLength: 22, withPad: " ", startingAt: 0)) \(String(group.count).padding(toLength: 9, withPad: " ", startingAt: 0)) \(cells)")
        }
        self.record("\(tier).dangerousRemaining", dangerousRemaining.count)
        self.record("\(tier).legitRemaining", legitRemaining.count)
        self.record("\(tier).ambiguousRemaining", ambiguousRemaining.count)
    }

    // MARK: - Pinned evidence

    private static let frozenRulesSHA256 = "b20b001153fbecffaede9eec736c50d462a759990469350c9bd42b004416aafe"
    private static let frozenDevelopmentSHA256 = "7854a3f02dea82d5cc0050707e6a82876099f0fcf218d5f1dec162965feaa3a2"
    private static let frozenValidationSHA256 = "89a9982c737fb5ddeb8f127147176121a686d41e48662e01d99bfe270c80de66"
    private static let frozenFreshSHA256 = "f8ed62da0c3426c9d6f27f4fd91385dd162782f54e493fcf4cacee661a3496d6"

    private static func pin(root: URL) {
        // The rule freeze and both corpora are pinned by hash: a change to any of them must be a documented decision.
        let directory = root.appendingPathComponent("Evaluation/References/autonomous-edit-policy")
        precondition(sha256(root.appendingPathComponent("Evaluation/Intelligence/Experimental/AutonomousEditInvariants.swift")) == self.frozenRulesSHA256, "the frozen invariant rules changed")
        precondition(sha256(directory.appendingPathComponent("development.json")) == self.frozenDevelopmentSHA256, "the development corpus changed")
        precondition(sha256(directory.appendingPathComponent("validation.json")) == self.frozenValidationSHA256, "the validation corpus changed")
        precondition(sha256(directory.appendingPathComponent("fresh.json")) == self.frozenFreshSHA256, "the V1.15 fresh corpus changed")
        // The findings document quotes exactly these numbers.
        let expected: [(String, Int)] = [
            ("fresh.ambiguousRemaining", 10), ("fresh.dangerousRemaining", 66), ("fresh.funnel.ambiguous.classifier", 10),
            ("fresh.funnel.ambiguous.effective", 10), ("fresh.funnel.ambiguous.n", 10), ("fresh.funnel.ambiguous.v111", 10),
            ("fresh.funnel.dangerous.classifier", 67), ("fresh.funnel.dangerous.effective", 66), ("fresh.funnel.dangerous.n", 67),
            ("fresh.funnel.dangerous.v111", 67), ("fresh.funnel.legit.classifier", 50), ("fresh.funnel.legit.effective", 50),
            ("fresh.funnel.legit.n", 51), ("fresh.funnel.legit.v111", 50), ("fresh.gap.acronymCase.remaining", 7),
            ("fresh.gap.acronymCase.total", 7), ("fresh.gap.alphanumericIdentifier.remaining", 6), ("fresh.gap.alphanumericIdentifier.total", 6),
            ("fresh.gap.designatorCase.remaining", 4), ("fresh.gap.designatorCase.total", 4), ("fresh.gap.digitLetterBoundary.remaining", 6),
            ("fresh.gap.digitLetterBoundary.total", 6), ("fresh.gap.identifierCase.remaining", 2), ("fresh.gap.identifierCase.total", 3),
            ("fresh.gap.intraTokenPunctuation.remaining", 10), ("fresh.gap.intraTokenPunctuation.total", 10), ("fresh.gap.midTokenCase.remaining", 3),
            ("fresh.gap.midTokenCase.total", 3), ("fresh.gap.spelledNumber.remaining", 6), ("fresh.gap.spelledNumber.total", 6),
            ("fresh.gap.structuralPunctuation.remaining", 8), ("fresh.gap.structuralPunctuation.total", 8), ("fresh.gap.wordMerge.remaining", 9),
            ("fresh.gap.wordMerge.total", 9), ("fresh.gap.wordSplit.remaining", 5), ("fresh.gap.wordSplit.total", 5),
            ("fresh.inv.C-A.ambiguous", 0), ("fresh.inv.C-A.blocked", 10), ("fresh.inv.C-A.demoted", 1),
            ("fresh.inv.C-A2.ambiguous", 0), ("fresh.inv.C-A2.blocked", 10), ("fresh.inv.C-A2.demoted", 1),
            ("fresh.inv.C-B.ambiguous", 0), ("fresh.inv.C-B.blocked", 12), ("fresh.inv.C-B.demoted", 4),
            ("fresh.inv.C-C.ambiguous", 0), ("fresh.inv.C-C.blocked", 2), ("fresh.inv.C-C.demoted", 0),
            ("fresh.inv.C-D.ambiguous", 3), ("fresh.inv.C-D.blocked", 16), ("fresh.inv.C-D.demoted", 2),
            ("fresh.inv.P-A.ambiguous", 2), ("fresh.inv.P-A.blocked", 22), ("fresh.inv.P-A.demoted", 0),
            ("fresh.inv.P-B.ambiguous", 2), ("fresh.inv.P-B.blocked", 18), ("fresh.inv.P-B.demoted", 0),
            ("fresh.inv.W-A.ambiguous", 0), ("fresh.inv.W-A.blocked", 25), ("fresh.inv.W-A.demoted", 3),
            ("fresh.inv.W-A1.ambiguous", 0), ("fresh.inv.W-A1.blocked", 19), ("fresh.inv.W-A1.demoted", 0),
            ("fresh.inv.W-A2.ambiguous", 0), ("fresh.inv.W-A2.blocked", 6), ("fresh.inv.W-A2.demoted", 3),
            ("fresh.inv.W-B.ambiguous", 2), ("fresh.inv.W-B.blocked", 25), ("fresh.inv.W-B.demoted", 4),
            ("fresh.inv.allowlist.ambiguous", 7), ("fresh.inv.allowlist.blocked", 63), ("fresh.inv.allowlist.demoted", 6),
            ("fresh.inv.core+P-A.ambiguous", 3), ("fresh.inv.core+P-A.blocked", 61), ("fresh.inv.core+P-A.demoted", 4),
            ("fresh.inv.core-merge-only+P-A.ambiguous", 3), ("fresh.inv.core-merge-only+P-A.blocked", 55), ("fresh.inv.core-merge-only+P-A.demoted", 1),
            ("fresh.inv.core.ambiguous", 2), ("fresh.inv.core.blocked", 55), ("fresh.inv.core.demoted", 4),
            ("fresh.legitRemaining", 50), ("fresh.matrix.acronymCase.C-A2", 7), ("fresh.matrix.acronymCase.C-C", 0),
            ("fresh.matrix.acronymCase.P-A", 0), ("fresh.matrix.acronymCase.P-B", 0), ("fresh.matrix.acronymCase.W-A1", 0),
            ("fresh.matrix.acronymCase.W-A2", 0), ("fresh.matrix.acronymCase.core+P-A", 7), ("fresh.matrix.alphanumericIdentifier.C-A2", 0),
            ("fresh.matrix.alphanumericIdentifier.C-C", 0), ("fresh.matrix.alphanumericIdentifier.P-A", 6), ("fresh.matrix.alphanumericIdentifier.P-B", 6),
            ("fresh.matrix.alphanumericIdentifier.W-A1", 0), ("fresh.matrix.alphanumericIdentifier.W-A2", 0), ("fresh.matrix.alphanumericIdentifier.core+P-A", 6),
            ("fresh.matrix.designatorCase.C-A2", 1), ("fresh.matrix.designatorCase.C-C", 0), ("fresh.matrix.designatorCase.P-A", 0),
            ("fresh.matrix.designatorCase.P-B", 0), ("fresh.matrix.designatorCase.W-A1", 0), ("fresh.matrix.designatorCase.W-A2", 0),
            ("fresh.matrix.designatorCase.core+P-A", 1), ("fresh.matrix.digitLetterBoundary.C-A2", 0), ("fresh.matrix.digitLetterBoundary.C-C", 0),
            ("fresh.matrix.digitLetterBoundary.P-A", 0), ("fresh.matrix.digitLetterBoundary.P-B", 0), ("fresh.matrix.digitLetterBoundary.W-A1", 5),
            ("fresh.matrix.digitLetterBoundary.W-A2", 1), ("fresh.matrix.digitLetterBoundary.core+P-A", 6), ("fresh.matrix.identifierCase.C-A2", 0),
            ("fresh.matrix.identifierCase.C-C", 2), ("fresh.matrix.identifierCase.P-A", 0), ("fresh.matrix.identifierCase.P-B", 0),
            ("fresh.matrix.identifierCase.W-A1", 0), ("fresh.matrix.identifierCase.W-A2", 0), ("fresh.matrix.identifierCase.core+P-A", 2),
            ("fresh.matrix.intraTokenPunctuation.C-A2", 0), ("fresh.matrix.intraTokenPunctuation.C-C", 0), ("fresh.matrix.intraTokenPunctuation.P-A", 7),
            ("fresh.matrix.intraTokenPunctuation.P-B", 9), ("fresh.matrix.intraTokenPunctuation.W-A1", 0), ("fresh.matrix.intraTokenPunctuation.W-A2", 0),
            ("fresh.matrix.intraTokenPunctuation.core+P-A", 9), ("fresh.matrix.midTokenCase.C-A2", 2), ("fresh.matrix.midTokenCase.C-C", 0),
            ("fresh.matrix.midTokenCase.P-A", 0), ("fresh.matrix.midTokenCase.P-B", 0), ("fresh.matrix.midTokenCase.W-A1", 0),
            ("fresh.matrix.midTokenCase.W-A2", 0), ("fresh.matrix.midTokenCase.core+P-A", 2), ("fresh.matrix.spelledNumber.C-A2", 0),
            ("fresh.matrix.spelledNumber.C-C", 0), ("fresh.matrix.spelledNumber.P-A", 1), ("fresh.matrix.spelledNumber.P-B", 1),
            ("fresh.matrix.spelledNumber.W-A1", 5), ("fresh.matrix.spelledNumber.W-A2", 0), ("fresh.matrix.spelledNumber.core+P-A", 6),
            ("fresh.matrix.structuralPunctuation.C-A2", 0), ("fresh.matrix.structuralPunctuation.C-C", 0), ("fresh.matrix.structuralPunctuation.P-A", 8),
            ("fresh.matrix.structuralPunctuation.P-B", 2), ("fresh.matrix.structuralPunctuation.W-A1", 0), ("fresh.matrix.structuralPunctuation.W-A2", 0),
            ("fresh.matrix.structuralPunctuation.core+P-A", 8), ("fresh.matrix.wordMerge.C-A2", 0), ("fresh.matrix.wordMerge.C-C", 0),
            ("fresh.matrix.wordMerge.P-A", 0), ("fresh.matrix.wordMerge.P-B", 0), ("fresh.matrix.wordMerge.W-A1", 9),
            ("fresh.matrix.wordMerge.W-A2", 0), ("fresh.matrix.wordMerge.core+P-A", 9), ("fresh.matrix.wordSplit.C-A2", 0),
            ("fresh.matrix.wordSplit.C-C", 0), ("fresh.matrix.wordSplit.P-A", 0), ("fresh.matrix.wordSplit.P-B", 0),
            ("fresh.matrix.wordSplit.W-A1", 0), ("fresh.matrix.wordSplit.W-A2", 5), ("fresh.matrix.wordSplit.core+P-A", 5),
            ("development.ambiguousRemaining", 12), ("development.dangerousRemaining", 71), ("development.funnel.ambiguous.classifier", 12),
            ("development.funnel.ambiguous.effective", 12), ("development.funnel.ambiguous.n", 12), ("development.funnel.ambiguous.v111", 12),
            ("development.funnel.dangerous.classifier", 74), ("development.funnel.dangerous.effective", 71), ("development.funnel.dangerous.n", 74),
            ("development.funnel.dangerous.v111", 73), ("development.funnel.legit.classifier", 69), ("development.funnel.legit.effective", 68),
            ("development.funnel.legit.n", 69), ("development.funnel.legit.v111", 68), ("development.gap.acronymCase.remaining", 11),
            ("development.gap.acronymCase.total", 11), ("development.gap.alphanumericIdentifier.remaining", 5), ("development.gap.alphanumericIdentifier.total", 6),
            ("development.gap.digitLetterBoundary.remaining", 6), ("development.gap.digitLetterBoundary.total", 6), ("development.gap.identifierCase.remaining", 4),
            ("development.gap.identifierCase.total", 5), ("development.gap.intraTokenPunctuation.remaining", 11), ("development.gap.intraTokenPunctuation.total", 11),
            ("development.gap.midTokenCase.remaining", 3), ("development.gap.midTokenCase.total", 3), ("development.gap.spelledNumber.remaining", 6),
            ("development.gap.spelledNumber.total", 7), ("development.gap.structuralPunctuation.remaining", 9), ("development.gap.structuralPunctuation.total", 9),
            ("development.gap.wordMerge.remaining", 11), ("development.gap.wordMerge.total", 11), ("development.gap.wordSplit.remaining", 5),
            ("development.gap.wordSplit.total", 5), ("development.inv.C-A.ambiguous", 0), ("development.inv.C-A.blocked", 13),
            ("development.inv.C-A.demoted", 1), ("development.inv.C-A2.ambiguous", 0), ("development.inv.C-A2.blocked", 16),
            ("development.inv.C-A2.demoted", 1), ("development.inv.C-B.ambiguous", 0), ("development.inv.C-B.blocked", 18),
            ("development.inv.C-B.demoted", 5), ("development.inv.C-C.ambiguous", 0), ("development.inv.C-C.blocked", 2),
            ("development.inv.C-C.demoted", 0), ("development.inv.C-D.ambiguous", 3), ("development.inv.C-D.blocked", 18),
            ("development.inv.C-D.demoted", 5), ("development.inv.P-A.ambiguous", 2), ("development.inv.P-A.blocked", 25),
            ("development.inv.P-A.demoted", 0), ("development.inv.P-B.ambiguous", 3), ("development.inv.P-B.blocked", 20),
            ("development.inv.P-B.demoted", 0), ("development.inv.W-A.ambiguous", 0), ("development.inv.W-A.blocked", 26),
            ("development.inv.W-A.demoted", 3), ("development.inv.W-A1.ambiguous", 0), ("development.inv.W-A1.blocked", 20),
            ("development.inv.W-A1.demoted", 0), ("development.inv.W-A2.ambiguous", 0), ("development.inv.W-A2.blocked", 6),
            ("development.inv.W-A2.demoted", 3), ("development.inv.W-B.ambiguous", 3), ("development.inv.W-B.blocked", 26),
            ("development.inv.W-B.demoted", 5), ("development.inv.core+P-A.ambiguous", 4), ("development.inv.core+P-A.blocked", 71),
            ("development.inv.core+P-A.demoted", 4), ("development.inv.core-merge-only+P-A.ambiguous", 4), ("development.inv.core-merge-only+P-A.blocked", 65),
            ("development.inv.core-merge-only+P-A.demoted", 1), ("development.inv.core.ambiguous", 3), ("development.inv.core.blocked", 64),
            ("development.inv.core.demoted", 4), ("development.inv.allowlist.ambiguous", 8), ("development.inv.allowlist.blocked", 69),
            ("development.inv.allowlist.demoted", 10), ("development.legitRemaining", 68),
            ("validation.ambiguousRemaining", 10), ("validation.dangerousRemaining", 67), ("validation.funnel.ambiguous.classifier", 10),
            ("validation.funnel.ambiguous.effective", 10), ("validation.funnel.ambiguous.n", 10), ("validation.funnel.ambiguous.v111", 10),
            ("validation.funnel.dangerous.classifier", 68), ("validation.funnel.dangerous.effective", 67), ("validation.funnel.dangerous.n", 68),
            ("validation.funnel.dangerous.v111", 68), ("validation.funnel.legit.classifier", 48), ("validation.funnel.legit.effective", 48),
            ("validation.funnel.legit.n", 48), ("validation.funnel.legit.v111", 48), ("validation.gap.acronymCase.remaining", 8),
            ("validation.gap.acronymCase.total", 8), ("validation.gap.alphanumericIdentifier.remaining", 6), ("validation.gap.alphanumericIdentifier.total", 6),
            ("validation.gap.designatorCase.remaining", 4), ("validation.gap.designatorCase.total", 4), ("validation.gap.digitLetterBoundary.remaining", 6),
            ("validation.gap.digitLetterBoundary.total", 6), ("validation.gap.identifierCase.remaining", 2), ("validation.gap.identifierCase.total", 3),
            ("validation.gap.intraTokenPunctuation.remaining", 10), ("validation.gap.intraTokenPunctuation.total", 10), ("validation.gap.midTokenCase.remaining", 3),
            ("validation.gap.midTokenCase.total", 3), ("validation.gap.spelledNumber.remaining", 6), ("validation.gap.spelledNumber.total", 6),
            ("validation.gap.structuralPunctuation.remaining", 8), ("validation.gap.structuralPunctuation.total", 8), ("validation.gap.wordMerge.remaining", 9),
            ("validation.gap.wordMerge.total", 9), ("validation.gap.wordSplit.remaining", 5), ("validation.gap.wordSplit.total", 5),
            ("validation.inv.C-A.ambiguous", 0), ("validation.inv.C-A.blocked", 9), ("validation.inv.C-A.demoted", 1),
            ("validation.inv.C-A2.ambiguous", 0), ("validation.inv.C-A2.blocked", 12), ("validation.inv.C-A2.demoted", 1),
            ("validation.inv.C-B.ambiguous", 0), ("validation.inv.C-B.blocked", 14), ("validation.inv.C-B.demoted", 5),
            ("validation.inv.C-C.ambiguous", 0), ("validation.inv.C-C.blocked", 2), ("validation.inv.C-C.demoted", 0),
            ("validation.inv.C-D.ambiguous", 3), ("validation.inv.C-D.blocked", 17), ("validation.inv.C-D.demoted", 4),
            ("validation.inv.P-A.ambiguous", 2), ("validation.inv.P-A.blocked", 22), ("validation.inv.P-A.demoted", 0),
            ("validation.inv.P-B.ambiguous", 2), ("validation.inv.P-B.blocked", 19), ("validation.inv.P-B.demoted", 0),
            ("validation.inv.W-A.ambiguous", 0), ("validation.inv.W-A.blocked", 25), ("validation.inv.W-A.demoted", 3),
            ("validation.inv.W-A1.ambiguous", 0), ("validation.inv.W-A1.blocked", 19), ("validation.inv.W-A1.demoted", 0),
            ("validation.inv.W-A2.ambiguous", 0), ("validation.inv.W-A2.blocked", 6), ("validation.inv.W-A2.demoted", 3),
            ("validation.inv.W-B.ambiguous", 2), ("validation.inv.W-B.blocked", 25), ("validation.inv.W-B.demoted", 5),
            ("validation.inv.core+P-A.ambiguous", 3), ("validation.inv.core+P-A.blocked", 64), ("validation.inv.core+P-A.demoted", 4),
            ("validation.inv.core-merge-only+P-A.ambiguous", 3), ("validation.inv.core-merge-only+P-A.blocked", 58), ("validation.inv.core-merge-only+P-A.demoted", 1),
            ("validation.inv.core.ambiguous", 2), ("validation.inv.core.blocked", 58), ("validation.inv.core.demoted", 4),
            ("validation.inv.allowlist.ambiguous", 7), ("validation.inv.allowlist.blocked", 64), ("validation.inv.allowlist.demoted", 9),
            ("validation.legitRemaining", 48),
        ]
        for (key, value) in expected {
            precondition(self.recorded[key] == value, "pinned evidence changed: \(key) = \(String(describing: self.recorded[key])), expected \(value)")
        }
    }
}
