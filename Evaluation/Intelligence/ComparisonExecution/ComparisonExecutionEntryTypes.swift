import CryptoKit
import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: corpus-isolation seam.
///
/// The V1.23A adjudicator and metrics (`CapabilityAdjudicator`, `CapabilityMetrics`) are written
/// against `CapabilityCorpus.Entry`, and that type lives in the same source file as the loader of the
/// frozen 44-entry V1.23 benchmark (its path, its pin and `load(from:)`). The execution path must be
/// unable to read that benchmark, and the frozen files may not be edited. So the execution build
/// **does not compile `CapabilityCorpus.swift`**: this file supplies, under the same names, only what the
/// unmodified scoring code needs -- the `Correction`/`Entry` entry schema (text-identical to the frozen
/// declaration, enforced by a test) and an entries container. There is no loader, no benchmark path and no
/// benchmark pin here, so a reference to any of them fails to compile (proved by negative-compile tests).
/// Only `ComparisonCorpus.load` (development corpus, pinned) builds entries for the execution path.
enum CapabilitySHA256 {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hex(of text: String) -> String {
        self.hex(Data(text.utf8))
    }
}

struct CapabilityCorpus {
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

    let entries: [Entry]
    let sha256: String
}
