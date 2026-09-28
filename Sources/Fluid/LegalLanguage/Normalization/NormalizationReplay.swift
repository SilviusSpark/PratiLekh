import Foundation

/// Deterministically replays a `NormalizationOutcome`'s provenance to
/// reconstruct every intermediate text from `recognized` alone, verifying at
/// each step that the recorded provenance is internally consistent and that the
/// replay ends at exactly `normalized`. It is the executable proof that
/// provenance is sufficient -- no intermediate text needs to be stored -- and a
/// fail-closed check for any consumer that maps provenance into final-text
/// coordinates.
///
/// It performs no relocation, search, or inference: it only applies the
/// recorded ranges to the recorded coordinate spaces (see the contract in
/// `LegalNormalizer.swift`). Any inconsistency yields a typed failure, never a
/// best-effort result.
enum NormalizationReplay {
    /// One replayed step: the text a step's records index (`input`), and the
    /// text after applying that step's applied changes (`output`).
    struct Step: Equatable {
        let pass: NormalizationPassID
        let step: Int
        let input: String
        let output: String
    }

    enum Failure: Error, Equatable {
        /// A record names a pass that is not in `outcome.passes`.
        case unknownPass(NormalizationPassID)
        /// A record's `range` is negative or outside its step's input.
        case rangeOutOfBounds(pass: NormalizationPassID, step: Int)
        /// A record's `trigger` is not the text at its `range` in the step input.
        case triggerMismatch(pass: NormalizationPassID, step: Int)
        /// Two records of one step intersect.
        case overlappingRecords(pass: NormalizationPassID, step: Int)
        /// The replay did not end at `outcome.normalized`.
        case finalTextMismatch
    }

    /// The ordered steps that contain at least one record, in pass order then
    /// ascending step, or the first inconsistency found. Passes/steps with no
    /// records are identity transitions and are omitted. Ends with a check that
    /// the last output equals `outcome.normalized`.
    static func steps(of outcome: NormalizationOutcome) -> Result<[Step], Failure> {
        struct Record {
            let trigger: String
            let replacement: String?
            let range: NSRange
        }
        var byPassStep: [NormalizationPassID: [Int: [Record]]] = [:]
        for change in outcome.appliedChanges {
            byPassStep[change.pass, default: [:]][change.step, default: []]
                .append(Record(trigger: change.trigger, replacement: change.replacement, range: change.range))
        }
        for change in outcome.declinedChanges {
            byPassStep[change.pass, default: [:]][change.step, default: []]
                .append(Record(trigger: change.trigger, replacement: nil, range: change.range))
        }
        if let stray = byPassStep.keys.first(where: { !outcome.passes.contains($0) }) {
            return .failure(.unknownPass(stray))
        }

        var text = outcome.recognized
        var steps: [Step] = []
        for pass in outcome.passes {
            for step in (byPassStep[pass] ?? [:]).keys.sorted() {
                let records = byPassStep[pass]?[step] ?? []
                let input = text as NSString
                for record in records {
                    guard record.range.location >= 0, record.range.length >= 0,
                          record.range.location + record.range.length <= input.length
                    else { return .failure(.rangeOutOfBounds(pass: pass, step: step)) }
                    guard input.substring(with: record.range) == record.trigger else {
                        return .failure(.triggerMismatch(pass: pass, step: step))
                    }
                }
                let ordered = records.sorted { $0.range.location < $1.range.location }
                for index in ordered.indices.dropFirst()
                    where ordered[index - 1].range.location + ordered[index - 1].range.length > ordered[index].range.location {
                    return .failure(.overlappingRecords(pass: pass, step: step))
                }
                var output = input
                for record in ordered.reversed() {
                    if let replacement = record.replacement {
                        output = output.replacingCharacters(in: record.range, with: replacement) as NSString
                    }
                }
                text = output as String
                steps.append(Step(pass: pass, step: step, input: input as String, output: text))
            }
        }
        guard text == outcome.normalized else { return .failure(.finalTextMismatch) }
        return .success(steps)
    }
}
