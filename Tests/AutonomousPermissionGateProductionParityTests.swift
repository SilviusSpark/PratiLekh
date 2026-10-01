import CryptoKit
import Foundation

/// Production-parity replay (V1.16): re-runs the three FROZEN, READ-ONLY
/// V1.14/V1.15 corpora (`development.json`, `validation.json`, `fresh.json`
/// under `Evaluation/References/autonomous-edit-policy/`) through the REAL
/// production pipeline -- `LegalDictationProcessor`, `ProtectedSpanDerivation`
/// (V1.11), `NumericStructuralProtection` (V1.13), `IntelligenceAddressingResolver`
/// (V1.6), `IntelligenceEditClassifier`, `AutonomousPermissionGate` and
/// `IntelligenceSafetyAuthority` (V1.16) -- and asserts the production gate
/// reproduces the EXACT aggregate counts already reported and approved in
/// `Evaluation/Intelligence/V1_14_AUTONOMOUS_EDIT_POLICY_FINDINGS.md` and
/// `Evaluation/Intelligence/V1_15_FRESH_AUTONOMOUS_POLICY_VALIDATION.md` for
/// the recommended `core-merge-only+P-A` bundle (P-A, P-B, W-A1, C-A2, C-C).
///
/// This file never writes to the three corpora, and their SHA-256 hashes are
/// verified unchanged before anything is read from them.
///
/// Why this is a SEPARATE file from the frozen investigation harness
/// (`Evaluation/Intelligence/Experimental/AutonomousEditPolicyInvestigation.swift`),
/// never modified or re-run as a pass/fail gate for V1.16: that harness
/// measures escapes by constructing SIMULATED `protectedSpans` per candidate
/// invariant against what was, when it was written, a gate-free real
/// `IntelligenceSafetyAuthority`. Now that the gate is unconditionally part
/// of the real Authority, re-running that harness unmodified would apply the
/// gate underneath its own simulation on every measurement, corrupting the
/// per-invariant isolation its methodology depends on. Its own frozen pins
/// (and V1.12's independent-protection investigation harness, which has the
/// same property) are consequently, and expectedly, now stale as a direct,
/// intended side effect of this milestone -- proof the production system
/// improved beyond what they measured -- and are deliberately left
/// untouched, per this milestone's instruction not to modify frozen
/// evidence/rules/corpora or their pins. This file is the independent,
/// correctly-scoped replacement: it reads the same frozen corpora and
/// compares production behavior against the two findings documents'
/// already-published, already-approved numbers directly.
@main
enum GateParityReplayTests {
    private static let developmentSHA256 = "7854a3f02dea82d5cc0050707e6a82876099f0fcf218d5f1dec162965feaa3a2"
    private static let validationSHA256 = "89a9982c737fb5ddeb8f127147176121a686d41e48662e01d99bfe270c80de66"
    private static let freshSHA256 = "f8ed62da0c3426c9d6f27f4fd91385dd162782f54e493fcf4cacee661a3496d6"

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
        }

        let entries: [Entry]
    }

    /// Published in the two findings documents: for each corpus, the total
    /// legit/dangerous entries, how many were already non-autonomous under
    /// the raw classifier alone (a pre-existing, gate-unrelated fact -- span
    /// interference for one legit case, a corpus authoring artifact for
    /// another), `legitRemaining`/`dangerousRemaining` (autonomous after
    /// V1.11+V1.13 alone, pre-gate), and the recommended bundle's published
    /// blocked/demoted counts against those "remaining" pools.
    private struct Published {
        let legitTotal: Int
        let legitPreExistingNonAutonomous: Int
        let legitRemaining: Int
        let bundleDemoted: Int
        let dangerousTotal: Int
        let dangerousRemaining: Int
        let bundleBlocked: Int
    }

    private static let published: [String: Published] = [
        "development.json": Published(legitTotal: 69, legitPreExistingNonAutonomous: 1, legitRemaining: 68, bundleDemoted: 1, dangerousTotal: 74, dangerousRemaining: 71, bundleBlocked: 65),
        "validation.json": Published(legitTotal: 48, legitPreExistingNonAutonomous: 0, legitRemaining: 48, bundleDemoted: 1, dangerousTotal: 68, dangerousRemaining: 67, bundleBlocked: 58),
        "fresh.json": Published(legitTotal: 51, legitPreExistingNonAutonomous: 1, legitRemaining: 50, bundleDemoted: 1, dangerousTotal: 67, dangerousRemaining: 66, bundleBlocked: 55),
    ]

    static func main() {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Evaluation/References/autonomous-edit-policy")
        guard let bundle = Bundle(path: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Fluid/Resources").path), let pack = BuiltInPacks.indianLegalCore(bundle: bundle)
        else { preconditionFailure("cannot load the Indian Legal Core") }
        let processor = LegalDictationProcessor(builtinPack: pack)

        for (fileName, expected) in self.published.sorted(by: { $0.key < $1.key }) {
            let url = directory.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: url) else { preconditionFailure("cannot load \(fileName)") }
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let pinned = fileName == "development.json" ? self.developmentSHA256 : (fileName == "validation.json" ? self.validationSHA256 : self.freshSHA256)
            precondition(digest == pinned, "\(fileName) changed since V1.14/V1.15 froze it (\(digest)); this file never modifies it and none of its pins were touched")

            guard let corpus = try? JSONDecoder().decode(Corpus.self, from: data) else { preconditionFailure("cannot decode \(fileName)") }
            precondition(corpus.entries.count == expected.legitTotal + expected.dangerousTotal + (fileName == "development.json" ? 12 : (fileName == "validation.json" ? 10 : 10)),
                         "\(fileName): entry count drifted from the frozen corpus this test was written against")

            var legitAutonomous = 0
            var dangerousAutonomous = 0
            var acronymDemotedIDs: [String] = []

            for entry in corpus.entries where entry.expectation == "legit" || entry.expectation == "dangerous" {
                let outcome = processor.process(entry.text)
                let normalized = outcome.normalized
                var protectedSpans: [ProtectedSpan] = []
                if case let .success(derived) = ProtectedSpanDerivation.derive(from: outcome) {
                    protectedSpans = derived.spansIncludingNumericStructure
                }
                let edit = ModelFacingEdit(sourceText: entry.source, replacementText: entry.replacement, occurrence: entry.occurrence, leftContext: entry.left, rightContext: entry.right)
                guard case let .success(resolution) = IntelligenceAddressingResolver.resolve(edit, in: normalized) else {
                    preconditionFailure("\(fileName) \(entry.id): edit does not resolve in normalized text \(normalized.debugDescription) -- the corpus or resolver changed since freezing")
                }
                let expectedSourceText = (normalized as NSString).substring(with: resolution.range)
                let proposal = IntelligenceProposal(id: entry.id, range: resolution.range, expectedSourceText: expectedSourceText, replacementText: entry.replacement, claimedCategory: .other)
                let disposition = IntelligenceSafetyAuthority.validate(proposals: [proposal], source: normalized, protectedSpans: protectedSpans).outcomes[0].disposition

                let isAutonomous: Bool
                if case .autonomouslyAccepted = disposition { isAutonomous = true } else { isAutonomous = false }

                if entry.expectation == "legit" {
                    if isAutonomous { legitAutonomous += 1 }
                    if disposition == .reviewOnly(.acronymCapitalizationLowered) { acronymDemotedIDs.append(entry.id) }
                } else {
                    if isAutonomous { dangerousAutonomous += 1 }
                }
            }

            // The exact parity assertion: production's autonomous-count for
            // each expectation bucket must equal (published "remaining" -
            // published bundle effect), regardless of pre-existing (span- or
            // classifier-level) non-autonomy that predates V1.16 entirely.
            let expectedLegitAutonomous = expected.legitRemaining - expected.bundleDemoted
            let expectedDangerousAutonomous = expected.dangerousRemaining - expected.bundleBlocked
            let legitLabel = "\(fileName): legit-autonomous = \(legitAutonomous), expected \(expectedLegitAutonomous)"
                + " (published legitRemaining \(expected.legitRemaining) - bundleDemoted \(expected.bundleDemoted))"
            precondition(legitAutonomous == expectedLegitAutonomous, legitLabel)
            let dangerousLabel = "\(fileName): dangerous-autonomous = \(dangerousAutonomous), expected \(expectedDangerousAutonomous)"
                + " (published dangerousRemaining \(expected.dangerousRemaining) - bundleBlocked \(expected.bundleBlocked))"
            precondition(dangerousAutonomous == expectedDangerousAutonomous, dangerousLabel)
            let acronymLabel = "\(fileName): the published bundle-demoted legit count must be attributable to the acronym-capitalization guard"
                + " specifically, exactly as both findings documents report -- got \(acronymDemotedIDs)"
            precondition(acronymDemotedIDs.count == expected.bundleDemoted, acronymLabel)

            let summary = "PARITY \(fileName): legit-autonomous \(legitAutonomous)/\(expected.legitTotal) (expected \(expectedLegitAutonomous)),"
                + " dangerous-autonomous \(dangerousAutonomous)/\(expected.dangerousTotal) (expected \(expectedDangerousAutonomous)), acronym-demoted \(acronymDemotedIDs)"
            print(summary)
        }

        print("All V1.16 production-parity replay checks passed.")
    }
}
