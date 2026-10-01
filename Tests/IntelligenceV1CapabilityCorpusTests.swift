import CryptoKit
import Foundation

/// Intelligence V1.22 -- Model Capability Evaluation Design & Freeze.
///
/// Structural integrity and real-pipeline consistency check for the frozen
/// ground-truth corpus (`Evaluation/References/intelligence-v1-capability/corpus.json`).
/// **Runs no model and makes no network call** -- it verifies the corpus
/// file's own SHA-256 against the pinned, frozen value, decodes and validates
/// its schema, and replays every entry's `text` through the real, unmodified
/// `LegalDictationProcessor` / `ProtectedSpanDerivation` (V1.11) /
/// `NumericStructuralProtection` (V1.13) to confirm each entry's premise
/// actually holds against production code -- not merely against the
/// corpus author's assumption. This is the "future runner cannot silently
/// mutate or tune the benchmark" safeguard: any edit to the corpus changes
/// its hash and fails this test until the hash is deliberately re-frozen and
/// re-approved (never silently updated to make a failure go away).
@main
enum IntelligenceV1CapabilityCorpusTests {
    /// Frozen at corpus-authoring time (V1.22). Do not update this value to
    /// make a failing test pass -- a mismatch means the corpus changed since
    /// it was reviewed and approved; re-freezing requires a new review, not
    /// a quiet edit here.
    private static let corpusSHA256 = "0edd60bb456aa34bc62c87cdf3401233f99d7c7e913d30eada3efc511ed3d48b"

    private struct Corpus: Decodable {
        struct Correction: Decodable {
            let source: String
            let replacement: String
        }

        struct Entry: Decodable {
            let id: String
            let category: String
            let tier: String
            let text: String
            let expectation: String
            let expectedCorrections: [Correction]
            let recallRequiresAll: Bool
            let manualAdjudicationOnly: Bool
            let hazardNote: String?
            let knownRiskReference: String?
            let note: String?
        }

        let schemaVersion: Int
        let description: String
        let entries: [Entry]
    }

    private static let allowedCategories: Set<String> = [
        "punctuation-correction-warranted",
        "capitalization-correction-warranted",
        "whitespace-correction-warranted",
        "multi-edit-correction-warranted",
        "clean-control",
        "hazard-protected-resolved-span",
        "hazard-intra-token-punctuation",
        "hazard-word-merge",
        "hazard-acronym-lowering",
        "hazard-digit-case",
        "hazard-independently-protected",
        "ambiguous",
    ]

    private static let allowedExpectations: Set<String> = ["correctionWarranted", "abstentionExpected"]

    /// Frozen composition -- any silent addition/removal of an entry in a
    /// category fails loudly here rather than drifting unnoticed.
    private static let expectedCategoryCounts: [String: Int] = [
        "punctuation-correction-warranted": 6,
        "capitalization-correction-warranted": 5,
        "whitespace-correction-warranted": 3,
        "multi-edit-correction-warranted": 4,
        "clean-control": 6,
        "hazard-protected-resolved-span": 3,
        "hazard-intra-token-punctuation": 3,
        "hazard-word-merge": 3,
        "hazard-acronym-lowering": 3,
        "hazard-digit-case": 2,
        "hazard-independently-protected": 3,
        "ambiguous": 3,
    ]

    static func main() {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let corpusURL = repoRoot.appendingPathComponent("Evaluation/References/intelligence-v1-capability/corpus.json")

        guard let data = try? Data(contentsOf: corpusURL) else { preconditionFailure("cannot load corpus.json at \(corpusURL.path)") }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        precondition(
            digest == self.corpusSHA256,
            "corpus.json changed since V1.22 froze it (sha256=\(digest)); do not silently update the pinned hash -- re-review and re-freeze deliberately"
        )

        guard let corpus = try? JSONDecoder().decode(Corpus.self, from: data) else { preconditionFailure("cannot decode corpus.json") }
        precondition(corpus.schemaVersion == 1)

        var seenIDs = Set<String>()
        for entry in corpus.entries {
            precondition(!seenIDs.contains(entry.id), "duplicate id \(entry.id)")
            seenIDs.insert(entry.id)
            precondition(self.allowedCategories.contains(entry.category), "\(entry.id): unknown category \(entry.category)")
            precondition(self.allowedExpectations.contains(entry.expectation), "\(entry.id): unknown expectation \(entry.expectation)")
            if entry.expectation == "correctionWarranted", !entry.manualAdjudicationOnly {
                precondition(!entry.expectedCorrections.isEmpty, "\(entry.id): a non-manual correctionWarranted entry must list at least one expected correction")
            }
            if entry.expectation == "abstentionExpected" {
                precondition(entry.expectedCorrections.isEmpty, "\(entry.id): an abstentionExpected entry must not list expected corrections")
            }
        }

        let categoryCounts = Dictionary(grouping: corpus.entries, by: \.category).mapValues(\.count)
        for (category, expectedCount) in self.expectedCategoryCounts {
            precondition(
                categoryCounts[category] == expectedCount,
                "category \(category) count drifted: expected \(expectedCount), found \(categoryCounts[category] ?? 0)"
            )
        }
        precondition(corpus.entries.count == self.expectedCategoryCounts.values.reduce(0, +), "total entry count drifted from the frozen composition")

        // MARK: - Real-pipeline structural validation (no model, no network)

        let resourcesPath = repoRoot.appendingPathComponent("Sources/Fluid/Resources").path
        guard let bundle = Bundle(path: resourcesPath), let pack = BuiltInPacks.indianLegalCore(bundle: bundle) else {
            preconditionFailure("could not load the Indian Legal Core pack from \(resourcesPath)")
        }
        let processor = LegalDictationProcessor(builtinPack: pack)

        for entry in corpus.entries {
            let outcome = processor.process(entry.text)
            let normalized = outcome.normalized

            switch ProtectedSpanDerivation.derive(from: outcome) {
            case let .failure(failure):
                preconditionFailure("\(entry.id): protected-span derivation failed: \(failure)")
            case let .success(derivedSpans):
                let numericSpans = NumericStructuralProtection.spans(in: normalized)
                let totalSpanCount = derivedSpans.spans.count + numericSpans.count

                switch entry.category {
                case "hazard-protected-resolved-span":
                    precondition(normalized != entry.text, "\(entry.id): expected the statutory normalizer to apply; normalized text is unchanged")
                    precondition(
                        derivedSpans.entries.contains { $0.span.kind == .deterministicallyResolved },
                        "\(entry.id): expected at least one .deterministicallyResolved span, found none"
                    )
                case "hazard-independently-protected":
                    precondition(!numericSpans.isEmpty, "\(entry.id): expected at least one independently-protected numeric span, found none")
                case "hazard-intra-token-punctuation", "hazard-word-merge", "hazard-acronym-lowering":
                    precondition(
                        totalSpanCount == 0,
                        "\(entry.id): expected zero protected spans so the V1.16 gate is the only isolated defense under test; found \(totalSpanCount)"
                    )
                case "hazard-digit-case":
                    // Digit-bearing identifiers (P9, D2, ...) are, by construction,
                    // always covered by a NumericStructuralProtection span too --
                    // unlike the other gate-isolation categories, this one is
                    // legitimately defended by both the gate AND V1.13 together.
                    precondition(!numericSpans.isEmpty, "\(entry.id): expected the digit-bearing identifier to produce a numeric protected span, found none")
                case "multi-edit-correction-warranted":
                    // Deliberately combines already-covered surface categories with
                    // no new safety-policy complexity: zero protected spans, same as
                    // the single-edit correction-warranted categories.
                    precondition(totalSpanCount == 0, "\(entry.id): multi-edit entries are built from plain surface corrections and must carry zero protected spans")
                default:
                    break
                }
            }

            for correction in entry.expectedCorrections {
                let occurrences = normalized.components(separatedBy: correction.source).count - 1
                precondition(occurrences >= 1, "\(entry.id): expectedCorrections.source \"\(correction.source)\" is not present in the derived legalNormalized text \"\(normalized)\"")
                if !entry.manualAdjudicationOnly {
                    precondition(
                        occurrences == 1,
                        "\(entry.id): expectedCorrections.source \"\(correction.source)\" occurs \(occurrences) times in \"\(normalized)\" -- must be unique for a non-manual entry"
                    )
                }
            }

            if entry.category == "multi-edit-correction-warranted" {
                self.validateMultiEditInvariants(entry: entry, normalized: normalized)
            }
        }

        print("PASS: Intelligence V1.22 capability corpus is frozen, structurally valid, and consistent with the real deterministic pipeline (\(corpus.entries.count) entries)")
    }

    /// Exercises the multi-edit ground-truth invariants directly, not merely
    /// the schema field's presence:
    ///   - at least two independent expected corrections (otherwise this is
    ///     not actually a multi-edit entry);
    ///   - `recallRequiresAll == true`, since partial detection of a
    ///     multi-edit entry's corrections must be distinguishable from full
    ///     recall, per README Sec.4/Sec.5's partial-recall definition;
    ///   - the expected corrections' source spans are pairwise
    ///     non-overlapping in the real derived text, so a future run's real
    ///     `IntelligenceSafetyAuthority` overlap check (which rejects BOTH
    ///     members of any intersecting pair, regardless of correctness)
    ///     could never spuriously reject two genuinely independent, correct
    ///     proposals -- a benchmark design defect this test is specifically
    ///     built to catch before any model exposure.
    private static func validateMultiEditInvariants(entry: Corpus.Entry, normalized: String) {
        precondition(entry.expectedCorrections.count >= 2, "\(entry.id): a multi-edit entry must list at least two independent expected corrections")
        precondition(entry.recallRequiresAll, "\(entry.id): multi-edit entries must set recallRequiresAll=true so partial detection is distinguishable from full recall")

        let nsNormalized = normalized as NSString
        var ranges: [NSRange] = []
        for correction in entry.expectedCorrections {
            let range = nsNormalized.range(of: correction.source)
            precondition(range.location != NSNotFound, "\(entry.id): expectedCorrections.source \"\(correction.source)\" not found")
            ranges.append(range)
        }
        for i in 0..<ranges.count {
            for j in (i + 1)..<ranges.count {
                let a = ranges[i]
                let b = ranges[j]
                let intersects = NSIntersectionRange(a, b).length > 0 || a.location == b.location
                precondition(
                    !intersects,
                    "\(entry.id): expected corrections \"\(entry.expectedCorrections[i].source)\" and \"\(entry.expectedCorrections[j].source)\" overlap in the derived text -- "
                        + "a real Safety Authority run would reject both as conflicting, defeating this entry's purpose of testing two independently-acceptable edits"
                )
            }
        }
    }
}
