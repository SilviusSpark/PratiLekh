import Foundation

/// Intelligence V1.27 -- Model Comparison Development Corpus & Protocol.
///
/// Loader for the **development** corpus used for candidate screening and the pre-registered
/// contract probe. It is a different artifact from the frozen V1.22/V1.23 benchmark (which this
/// type never reads). The pinned SHA-256 is verified against the raw bytes before decoding.
/// Entry schema and adjudication conventions are the V1.22 ones (`CapabilityCorpus.Entry`).
struct ComparisonCorpus {
    static let relativePath = "Evaluation/References/intelligence-v1-comparison-dev/corpus.json"
    /// Frozen at V1.27. Never update this to make a failure pass: a mismatch means the development
    /// corpus changed after the pre-registration.
    static let frozenSHA256 = "e164297ec472e7f750d8e3e18f52f939e22a89bd7578ecc42df18d5b7941e364"

    /// Frozen composition: any silent addition or removal fails loudly.
    static let frozenComposition: [String: Int] = [
        "punctuation-correction-warranted": 10,
        "capitalization-correction-warranted": 8,
        "whitespace-correction-warranted": 6,
        "multi-edit-correction-warranted": 8,
        "multi-sentence-correction-warranted": 6,
        "clean-control": 12,
        "hazard-protected-resolved-span": 2,
        "hazard-intra-token-punctuation": 2,
        "hazard-word-merge": 2,
        "hazard-acronym-lowering": 2,
        "hazard-digit-case": 2,
        "hazard-independently-protected": 2,
        "ambiguous": 4,
    ]

    private struct File: Decodable {
        let schemaVersion: Int
        let description: String
        let entries: [CapabilityCorpus.Entry]
    }

    enum LoadError: Error, CustomStringConvertible {
        case unreadable(String)
        case hashMismatch(actual: String, expected: String)
        case undecodable
        case structural(String)

        var description: String {
            switch self {
            case let .unreadable(path): return "cannot read \(path)"
            case let .hashMismatch(actual, expected): return "development corpus SHA-256 \(actual) != frozen \(expected)"
            case .undecodable: return "development corpus could not be decoded"
            case let .structural(detail): return "development corpus structural check failed: \(detail)"
            }
        }
    }

    let entries: [CapabilityCorpus.Entry]
    let sha256: String

    static func load(from url: URL, expectedSHA256: String = ComparisonCorpus.frozenSHA256) throws -> ComparisonCorpus {
        guard let data = try? Data(contentsOf: url) else { throw LoadError.unreadable(url.path) }
        let actual = CapabilitySHA256.hex(data)
        guard actual == expectedSHA256 else { throw LoadError.hashMismatch(actual: actual, expected: expectedSHA256) }
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { throw LoadError.undecodable }
        guard file.schemaVersion == 1 else { throw LoadError.structural("schemaVersion \(file.schemaVersion) != 1") }
        guard Set(file.entries.map(\.id)).count == file.entries.count else { throw LoadError.structural("duplicate entry id") }
        let counts = Dictionary(grouping: file.entries, by: \.category).mapValues(\.count)
        guard counts == self.frozenComposition else { throw LoadError.structural("category composition drifted: \(counts)") }
        for entry in file.entries {
            guard entry.tier == "synthetic" else { throw LoadError.structural("\(entry.id): tier must be synthetic") }
            if entry.expectation == "abstentionExpected", !entry.expectedCorrections.isEmpty {
                throw LoadError.structural("\(entry.id): abstentionExpected must list no corrections")
            }
            if entry.isScoredCorrectionWarranted, entry.expectedCorrections.isEmpty {
                throw LoadError.structural("\(entry.id): a scored warranted entry needs at least one correction")
            }
            if entry.manualAdjudicationOnly, !entry.expectedCorrections.isEmpty {
                throw LoadError.structural("\(entry.id): a manual entry must not carry automatic ground truth")
            }
        }
        return ComparisonCorpus(entries: file.entries, sha256: actual)
    }

    var scoredEntries: [CapabilityCorpus.Entry] {
        self.entries.filter(\.isScored)
    }

    var manualEntries: [CapabilityCorpus.Entry] {
        self.entries.filter(\.manualAdjudicationOnly)
    }

    var scoredCorrectionWarranted: [CapabilityCorpus.Entry] {
        self.entries.filter(\.isScoredCorrectionWarranted)
    }

    var scoredAbstentionExpected: [CapabilityCorpus.Entry] {
        self.entries.filter(\.isScoredAbstentionExpected)
    }

    var perCorrectionDenominator: Int {
        self.entries.reduce(0) { $0 + $1.perCorrectionDenominator }
    }
}
