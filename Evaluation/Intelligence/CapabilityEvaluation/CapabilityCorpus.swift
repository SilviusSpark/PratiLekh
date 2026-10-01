import CryptoKit
import Foundation

/// Intelligence V1.23A -- Frozen Capability Evaluation Infrastructure.
///
/// Loads the committed, frozen V1.22 capability corpus
/// (`Evaluation/References/intelligence-v1-capability/corpus.json`). The pinned SHA-256 is
/// verified against the raw file bytes **before** anything is decoded, so a corpus that
/// drifted since the freeze can never reach scoring. Read-only: nothing here writes,
/// repairs, or filters the corpus. Runs no model and makes no network call.
enum CapabilitySHA256 {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hex(of text: String) -> String {
        self.hex(Data(text.utf8))
    }
}

struct CapabilityCorpus {
    /// Frozen at V1.22. Mirrors `Tests/IntelligenceV1CapabilityCorpusTests.swift`'s own pin;
    /// never update this to make a failure pass -- a mismatch means the benchmark changed.
    static let frozenSHA256 = "0edd60bb456aa34bc62c87cdf3401233f99d7c7e913d30eada3efc511ed3d48b"
    static let frozenEntryCount = 44
    static let relativePath = "Evaluation/References/intelligence-v1-capability/corpus.json"

    struct Correction: Decodable, Equatable {
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

        /// Scored automatically (README Sec.4: `manualAdjudicationOnly` entries never are).
        var isScored: Bool {
            !self.manualAdjudicationOnly
        }

        /// A scored entry where a correction is warranted -- the recall denominator population.
        var isScoredCorrectionWarranted: Bool {
            self.isScored && self.expectation == "correctionWarranted"
        }

        /// A scored entry where abstention (or any non-accepted outcome) is the correct behavior.
        var isScoredAbstentionExpected: Bool {
            self.isScored && self.expectation == "abstentionExpected"
        }

        /// README Sec.5.2: the 14 single-edit entries each contribute 1 correction; a
        /// `recallRequiresAll` entry contributes one per listed correction.
        var perCorrectionDenominator: Int {
            guard self.isScoredCorrectionWarranted else { return 0 }
            return self.recallRequiresAll ? self.expectedCorrections.count : 1
        }
    }

    private struct File: Decodable {
        let schemaVersion: Int
        let entries: [Entry]
    }

    enum LoadError: Error, CustomStringConvertible {
        case unreadable(String)
        case hashMismatch(actual: String, expected: String)
        case undecodable
        case structural(String)

        var description: String {
            switch self {
            case let .unreadable(path): return "cannot read corpus at \(path)"
            case let .hashMismatch(actual, expected):
                return "corpus SHA-256 \(actual) != frozen \(expected) -- the benchmark changed since V1.22; do not repin to make a run proceed"
            case .undecodable: return "corpus.json could not be decoded"
            case let .structural(detail): return "corpus structural check failed: \(detail)"
            }
        }
    }

    let entries: [Entry]
    let sha256: String

    static func load(from url: URL, expectedSHA256: String = CapabilityCorpus.frozenSHA256) throws -> CapabilityCorpus {
        guard let data = try? Data(contentsOf: url) else { throw LoadError.unreadable(url.path) }
        let actual = CapabilitySHA256.hex(data)
        guard actual == expectedSHA256 else { throw LoadError.hashMismatch(actual: actual, expected: expectedSHA256) }
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { throw LoadError.undecodable }
        guard file.schemaVersion == 1 else { throw LoadError.structural("schemaVersion \(file.schemaVersion) != 1") }
        guard file.entries.count == self.frozenEntryCount else {
            throw LoadError.structural("entry count \(file.entries.count) != \(self.frozenEntryCount)")
        }
        guard Set(file.entries.map(\.id)).count == file.entries.count else { throw LoadError.structural("duplicate entry id") }
        return CapabilityCorpus(entries: file.entries, sha256: actual)
    }

    // MARK: - Frozen denominators (README Sec.5; asserted by tests against the real corpus)

    var scoredEntries: [Entry] {
        self.entries.filter(\.isScored)
    }

    var manualEntries: [Entry] {
        self.entries.filter(\.manualAdjudicationOnly)
    }

    var scoredCorrectionWarrantedEntries: [Entry] {
        self.entries.filter(\.isScoredCorrectionWarranted)
    }

    var scoredAbstentionExpectedEntries: [Entry] {
        self.entries.filter(\.isScoredAbstentionExpected)
    }

    var perCorrectionDenominator: Int {
        self.entries.reduce(0) { $0 + $1.perCorrectionDenominator }
    }
}
