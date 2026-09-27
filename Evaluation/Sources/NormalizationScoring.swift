import Foundation

/// What the real legal normalizer did, reduced to what scoring needs.
struct ObservedNormalization: Codable, Equatable {
    struct Change: Codable, Equatable {
        let source: String
        let replacement: String
    }

    let input: String
    let output: String
    let applied: [Change]
    let declinedSources: [String]
}

enum NormalizationOutcomeKind: String, Codable {
    case correctApplication
    case correctDecline
    /// Nothing was a candidate and the text was correctly left untouched.
    case correctNoCandidate
    case missedOpportunity
    /// Severe: a transformation where none (or a decline) was expected.
    case falsePositive
    /// Severe: a transformation was made but not to the expected output.
    case incorrectTransformation
    /// The expected source span is not in the post-ASR text (ASR heard something else),
    /// so normalization cannot fairly be blamed or credited.
    case notEvaluable

    var isSevere: Bool { self == .falsePositive || self == .incorrectTransformation }
}

struct NormalizationFinding: Codable, Equatable {
    let kind: NormalizationOutcomeKind
    let source: String?
    let expectedReplacement: String?
    let observedReplacement: String?
    let detail: String
}

enum NormalizationScoring {
    /// `dictated` is the reference text. An unexplained applied change whose
    /// source is not part of what was dictated was made on words the recognizer
    /// invented, so it is attributed upstream (`notEvaluable`) rather than
    /// counted as a normalizer false positive.
    static func score(
        expectations: [LegalExpectation], observed: ObservedNormalization, dictated: String? = nil
    ) -> [NormalizationFinding] {
        var findings: [NormalizationFinding] = []
        var explained = Set<Int>()

        for expectation in expectations {
            switch expectation.kind {
            case .apply:
                findings.append(self.scoreApply(expectation, observed, &explained))
            case .decline:
                findings.append(contentsOf: self.scoreDecline(expectation, observed, &explained))
            case .noCandidate:
                findings.append(contentsOf: self.scoreNoCandidate(observed, &explained))
            }
        }

        // Any applied change no expectation accounts for changed the record unasked.
        for (index, change) in observed.applied.enumerated() where !explained.contains(index) {
            if let dictated, dictated.range(of: change.source, options: .caseInsensitive) == nil {
                findings.append(NormalizationFinding(
                    kind: .notEvaluable,
                    source: change.source,
                    expectedReplacement: nil,
                    observedReplacement: change.replacement,
                    detail: "transformed text that was not dictated (upstream recognition error)"
                ))
                continue
            }
            findings.append(NormalizationFinding(
                kind: .falsePositive,
                source: change.source,
                expectedReplacement: nil,
                observedReplacement: change.replacement,
                detail: "unexpected transformation"
            ))
        }
        return findings
    }

    private static func scoreApply(_ e: LegalExpectation, _ o: ObservedNormalization, _ explained: inout Set<Int>) -> NormalizationFinding {
        let source = e.source ?? ""
        let expected = e.replacement
        guard o.input.range(of: source, options: .caseInsensitive) != nil else {
            return NormalizationFinding(
                kind: .notEvaluable,
                source: source,
                expectedReplacement: expected,
                observedReplacement: nil,
                detail: "expected source span not present in post-ASR text"
            )
        }
        if let index = self.matchingChange(for: source, in: o.applied) {
            explained.insert(index)
            let observed = o.applied[index].replacement
            let ok = observed == expected
            return NormalizationFinding(
                kind: ok ? .correctApplication : .incorrectTransformation,
                source: source,
                expectedReplacement: expected,
                observedReplacement: observed,
                detail: ok ? "applied as expected" : "applied a different replacement"
            )
        }
        let declined = o.declinedSources.contains { self.overlaps($0, source) }
        return NormalizationFinding(
            kind: .missedOpportunity,
            source: source,
            expectedReplacement: expected,
            observedReplacement: nil,
            detail: declined ? "candidate was explicitly declined" : "no candidate detected"
        )
    }

    private static func scoreDecline(_ e: LegalExpectation, _ o: ObservedNormalization, _ explained: inout Set<Int>) -> [NormalizationFinding] {
        let source = e.source ?? ""
        guard o.input.range(of: source, options: .caseInsensitive) != nil else {
            return [NormalizationFinding(
                kind: .notEvaluable,
                source: source,
                expectedReplacement: nil,
                observedReplacement: nil,
                detail: "expected source span not present in post-ASR text"
            )]
        }
        if let index = self.matchingChange(for: source, in: o.applied) {
            explained.insert(index)
            return [NormalizationFinding(
                kind: .falsePositive,
                source: source,
                expectedReplacement: nil,
                observedReplacement: o.applied[index].replacement,
                detail: "transformed a span that must be preserved"
            )]
        }
        if o.output.range(of: source, options: .caseInsensitive) == nil {
            return [NormalizationFinding(
                kind: .incorrectTransformation,
                source: source,
                expectedReplacement: nil,
                observedReplacement: nil,
                detail: "span changed without an applied-change record"
            )]
        }
        let explicit = o.declinedSources.contains { self.overlaps($0, source) }
        return [NormalizationFinding(
            kind: .correctDecline,
            source: source,
            expectedReplacement: nil,
            observedReplacement: nil,
            detail: explicit ? "explicitly declined and preserved" : "preserved without an explicit decline (no candidate)"
        )]
    }

    private static func scoreNoCandidate(_ o: ObservedNormalization, _ explained: inout Set<Int>) -> [NormalizationFinding] {
        var findings: [NormalizationFinding] = []
        for (index, change) in o.applied.enumerated() {
            explained.insert(index)
            findings.append(NormalizationFinding(
                kind: .falsePositive,
                source: change.source,
                expectedReplacement: nil,
                observedReplacement: change.replacement,
                detail: "transformed text with no expected candidate"
            ))
        }
        if findings.isEmpty {
            if o.output != o.input {
                findings.append(NormalizationFinding(
                    kind: .incorrectTransformation,
                    source: nil,
                    expectedReplacement: nil,
                    observedReplacement: nil,
                    detail: "output differs from input without an applied-change record"
                ))
            } else {
                findings.append(NormalizationFinding(
                    kind: .correctNoCandidate,
                    source: nil,
                    expectedReplacement: nil,
                    observedReplacement: nil,
                    detail: "text left untouched"
                ))
            }
        }
        return findings
    }

    private static func matchingChange(for source: String, in applied: [ObservedNormalization.Change]) -> Int? {
        if let exact = applied.firstIndex(where: { $0.source.caseInsensitiveCompare(source) == .orderedSame }) { return exact }
        return applied.firstIndex { self.overlaps($0.source, source) }
    }

    private static func overlaps(_ lhs: String, _ rhs: String) -> Bool {
        lhs.range(of: rhs, options: .caseInsensitive) != nil || rhs.range(of: lhs, options: .caseInsensitive) != nil
    }
}
