import Foundation

// Intelligence V1.25 -- Supplementary Post-hoc Outcome Evaluation.
//
// Pure, deterministic implementation of the V1.24 supplementary semantics. **Post-hoc and
// supplementary: nothing here recomputes, replaces or supersedes a frozen V1.23 metric.** No
// model, no network. The three concepts V1.24 keeps separate are kept in separate types:
//   - edit-form adherence   -> `SupplementaryFormAdherence` (and the frozen exact-pair U0 reference)
//   - outcome correctness   -> `LicensedOutcomes`, `SupplementaryOutcomeState`, U1
//   - deterministic runtime safety -> `SupplementaryRuntimeSafetyMonitor` (U2, U3)

// MARK: - Licensed outcomes (outcome correctness)

/// `L(entry)`: the set of texts obtained by applying every subset of an entry's expected
/// corrections to the legal-normalized source. Plain text equality; no diff algorithm.
/// An `abstentionExpected` entry has no corrections, so `L` = {source}.
struct LicensedOutcomes: Equatable {
    let texts: Set<String>
    /// The text after applying *every* expected correction (== source when there are none).
    let full: String

    enum Failure: Error, Equatable, CustomStringConvertible {
        case correctionNotUniquelyLocatable(source: String, occurrences: Int)
        case overlappingCorrections

        var description: String {
            switch self {
            case let .correctionNotUniquelyLocatable(source, occurrences): return "expected correction source \"\(source)\" occurs \(occurrences) times"
            case .overlappingCorrections: return "expected corrections overlap"
            }
        }
    }

    static func compute(source: String, corrections: [CapabilityCorpus.Correction]) -> Result<LicensedOutcomes, Failure> {
        let nsSource = source as NSString
        var located: [(range: NSRange, replacement: String)] = []
        for correction in corrections {
            let all = self.occurrences(of: correction.source, in: nsSource)
            guard all.count == 1 else { return .failure(.correctionNotUniquelyLocatable(source: correction.source, occurrences: all.count)) }
            located.append((all[0], correction.replacement))
        }
        for i in located.indices {
            for j in located.indices where j > i {
                let a = located[i].range
                let b = located[j].range
                if NSIntersectionRange(a, b).length > 0 || a.location == b.location {
                    return .failure(.overlappingCorrections)
                }
            }
        }
        var texts = Set<String>()
        var full = source
        for mask in 0..<(1 << located.count) {
            let chosen = located.indices.filter { mask & (1 << $0) != 0 }.map { located[$0] }.sorted { $0.range.location > $1.range.location }
            var text = nsSource
            for item in chosen {
                text = text.replacingCharacters(in: item.range, with: item.replacement) as NSString
            }
            texts.insert(text as String)
            if mask == (1 << located.count) - 1 {
                full = text as String
            }
        }
        return .success(LicensedOutcomes(texts: texts, full: full))
    }

    /// All (possibly overlapping) occurrences of `needle`, by UTF-16 range.
    static func occurrences(of needle: String, in haystack: NSString) -> [NSRange] {
        guard !needle.isEmpty else { return [] }
        var found: [NSRange] = []
        var searchStart = 0
        while searchStart < haystack.length {
            let range = haystack.range(of: needle, options: [.literal], range: NSRange(location: searchStart, length: haystack.length - searchStart))
            if range.location == NSNotFound {
                break
            }
            found.append(range)
            searchStart = range.location + 1
        }
        return found
    }
}

/// Outcome of applying a set of edits, classified against `L(entry)`.
/// Precedence: unchanged -> complete -> partial -> foreign.
enum SupplementaryOutcomeState: String, CaseIterable {
    /// Final text equals the source (nothing licensed or unlicensed reached the text).
    case unchanged
    /// Final text equals the fully corrected text (every expected correction applied, nothing else).
    case complete
    /// Final text is in `L` but is neither the source nor the full correction (a proper, non-empty subset).
    case partial
    /// Final text is not in `L`: the transcript is not one the ground truth licenses.
    case foreign

    static func classify(final: String, source: String, licensed: LicensedOutcomes) -> SupplementaryOutcomeState {
        if final == source {
            return .unchanged
        }
        if final == licensed.full {
            return .complete
        }
        return licensed.texts.contains(final) ? .partial : .foreign
    }
}

// MARK: - Applying edits (deterministic, UTF-16 ranges)

enum SupplementaryApplication {
    /// Applies non-overlapping `(range, replacement)` edits right-to-left. Any edit overlapping an
    /// already-applied (later) edit is skipped and counted, never silently merged.
    static func apply(_ edits: [(range: NSRange, replacement: String)], to source: String) -> (text: String, skippedOverlapping: Int) {
        var text = source as NSString
        var skipped = 0
        var lowestApplied = Int.max
        for edit in edits.sorted(by: { $0.range.location > $1.range.location }) {
            if edit.range.location + edit.range.length > lowestApplied {
                skipped += 1; continue
            }
            text = text.replacingCharacters(in: edit.range, with: edit.replacement) as NSString
            lowestApplied = edit.range.location
        }
        return (text as String, skipped)
    }
}

// MARK: - Deterministic runtime safety (U2, U3): independent monitors of the safeguards' own invariants

struct SupplementaryRuntimeObservation: Equatable {
    /// U2: an autonomously accepted edit's range intersects a protected span of any kind.
    var intersectsProtectedSpan: Bool
    /// U3: independently re-derived classification is outside the V1 autonomous set.
    var classificationOutsideAutonomousSet: Bool
    /// U3: the V1.16 gate would block this edit.
    var gateBlock: AutonomousPermissionBlock?
    /// The edit's range could not be located in the source, so neither classification nor gate
    /// could be re-derived: reported as a U3 violation (fail closed), never as clean.
    var rangeUnconvertible = false

    var u3Violation: Bool {
        self.classificationOutsideAutonomousSet || self.gateBlock != nil || self.rangeUnconvertible
    }
}

enum SupplementaryRuntimeSafetyMonitor {
    /// Range-intersection written independently of `IntelligenceSafetyAuthority`: a positive-length
    /// overlap, or a zero-length insertion strictly inside a span.
    static func intersects(_ range: NSRange, _ span: NSRange) -> Bool {
        if range.length == 0 {
            return range.location > span.location && range.location < span.location + span.length
        }
        return range.location < span.location + span.length && span.location < range.location + range.length
    }

    /// Independently re-derives classification (classifier) and the gate decision for one accepted
    /// edit against the immutable `source`. Re-uses the rule implementations, not the Authority's
    /// decision pipeline; a non-clean result would indicate an Authority defect.
    static func observe(source: String, range: NSRange, expectedSourceText: String, replacementText: String, protectedSpans: [ProtectedSpan]) -> SupplementaryRuntimeObservation {
        let classification = IntelligenceEditClassifier.classify(from: expectedSourceText, to: replacementText)
        let outside = classification == .other
        var block: AutonomousPermissionBlock?
        var unconvertible = false
        if !outside {
            if let swiftRange = Range(range, in: source) {
                block = AutonomousPermissionGate.block(
                    classification: classification,
                    source: source,
                    range: swiftRange,
                    expectedSourceText: expectedSourceText,
                    replacementText: replacementText
                )
            } else {
                unconvertible = true
            }
        }
        return SupplementaryRuntimeObservation(
            intersectsProtectedSpan: protectedSpans.contains { self.intersects(range, $0.range) },
            classificationOutsideAutonomousSet: outside,
            gateBlock: block,
            rangeUnconvertible: unconvertible
        )
    }

    /// U2 (digit invariant): the sequence of decimal-digit characters must be identical in source and output.
    static func digitSequenceChanged(source: String, output: String) -> Bool {
        self.digits(source) != self.digits(output)
    }

    private static func digits(_ text: String) -> [Unicode.Scalar] {
        text.unicodeScalars.filter { $0.properties.generalCategory == .decimalNumber }
    }
}

// MARK: - Edit-form adherence

struct SupplementaryFormAdherence: Equatable {
    /// Resolved edits (addressing succeeded) considered.
    var resolvedEdits = 0
    /// Resolved edits whose `sourceText` is the entire legal-normalized text (a proxy for ignoring
    /// the V1.21 smallest-span instruction).
    var wholeTextSpan = 0
    /// Resolved edits whose `(sourceText, replacementText)` equals an expected pair (frozen exact-pair form).
    var exactExpectedPair = 0

    mutating func add(sourceText: String, replacementText: String, normalized: String, matchesExpectedPair: Bool) {
        self.resolvedEdits += 1
        if sourceText == normalized {
            self.wholeTextSpan += 1
        }
        if matchesExpectedPair {
            self.exactExpectedPair += 1
        }
    }
}
