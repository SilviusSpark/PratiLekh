import Foundation

/// The deterministic authority PratiLekh Intelligence's proposals must pass
/// through before anything can affect `legalNormalized`. There is no model
/// here, and none of its inputs are trusted: `proposals` may be arbitrary,
/// including incorrect, malformed, misleading, stale, conflicting, or
/// adversarial values. This type's entire purpose is to prove that only
/// demonstrably safe V1 surface edits can pass through regardless -- see
/// CLAUDE.md's "PratiLekh Intelligence architecture" section.
///
/// Governing invariants (do not weaken any of these to make a future
/// correction easier to apply):
///   - Every proposal is validated against the immutable `source` string.
///     Proposal N+1 is never validated against text already modified by
///     proposal N; mutation happens only after every disposition is fixed.
///   - `expectedSourceText` must match the real source exactly at `range`
///     -- no fuzzy matching, no relocating a stale/shifted proposal by
///     searching the source for it.
///   - A proposal's own `claimedCategory` never grants permission; the
///     independently-derived `IntelligenceEditClassification` is the only
///     category ever acted on.
///   - A `.deterministicallyResolved` protected span forbids any proposal
///     at all; a `.deterministicallyUnresolved` or `.independentlyProtected`
///     span forbids autonomous application but allows a review-only
///     disposition -- a decline is not a resolved fact, so it is never
///     collapsed into the resolved category.
///   - Overlapping/conflicting proposals never gain authority through
///     input order: both members of an intersecting pair are rejected,
///     independent of which came first in `proposals`.
///   - An independently-derived punctuation-only/capitalization-only/
///     whitespace-only classification is necessary but not sufficient for
///     autonomous application: `AutonomousPermissionGate` (V1.16) may still
///     downgrade it to review-only when a validated structural invariant
///     says the classification's category, though technically correct,
///     should not be trusted here (see the gate's own documentation). This
///     never applies to `.other`, and never rejects outright.
enum IntelligenceSafetyAuthority {
    struct ProposalOutcome: Equatable {
        let proposal: IntelligenceProposal
        let disposition: ProposalDisposition
    }

    struct Result: Equatable {
        /// One outcome per input proposal, in input order.
        let outcomes: [ProposalOutcome]
        /// `source` with every autonomously-accepted proposal applied, and
        /// nothing else -- rejected and review-only proposals never affect
        /// this value.
        let resultingText: String

        var accepted: [ProposalOutcome] {
            self.outcomes.filter {
                if case .autonomouslyAccepted = $0.disposition { return true }
                return false
            }
        }

        var rejected: [ProposalOutcome] {
            self.outcomes.filter {
                if case .rejected = $0.disposition { return true }
                return false
            }
        }

        var reviewOnly: [ProposalOutcome] {
            self.outcomes.filter {
                if case .reviewOnly = $0.disposition { return true }
                return false
            }
        }
    }

    /// Validates every proposal against the immutable `source` and
    /// `protectedSpans`, then safely applies only the autonomously-accepted
    /// ones. `proposals` and `protectedSpans` are untrusted input; `source`
    /// is never mutated during validation, and every proposal is checked
    /// against it -- never against a partially-edited copy.
    ///
    /// Order (explicit; do not let a later step accidentally override an
    /// earlier safety failure):
    ///   1. range validity (non-negative, within source bounds, no overflow);
    ///   2. safe UTF-16 -> `String.Index` conversion;
    ///   3. exact `expectedSourceText` comparison against the real source;
    ///   4. no-op rejection (`expectedSourceText == replacementText`);
    ///   5. overlap/conflict detection among survivors of 1-4;
    ///   6. protected-span intersection, most-restrictive-wins, for
    ///      survivors of 5;
    ///   7. independent edit classification and comparison against V1's
    ///      autonomous categories, for survivors of 6;
    ///   7a. autonomous-permission gate (`AutonomousPermissionGate`), for
    ///      survivors of 7 that classified as punctuation-only,
    ///      capitalization-only, or whitespace-only: downgrades to
    ///      review-only when a validated structural invariant says the
    ///      edit should not be trusted despite its classification -- never
    ///      consulted for `.other`, never rejects outright;
    ///   8. safe application of every `.autonomouslyAccepted` proposal, in
    ///      descending source-range order, against the original `source`.
    static func validate(
        proposals: [IntelligenceProposal],
        source: String,
        protectedSpans: [ProtectedSpan]
    ) -> Result {
        let sourceUTF16Length = (source as NSString).length
        var dispositions = [ProposalDisposition?](repeating: nil, count: proposals.count)
        // (index, range, swiftRange) for every proposal that survived the
        // structural checks below -- built as an array, not a dictionary, so
        // the overlap/protected-span passes never need a keyed lookup that
        // could fail. `swiftRange` is the same `String.Index` range already
        // derived to verify `expectedSourceText` below; carrying it forward
        // lets step 7a reuse it instead of converting `range` a second time.
        var survivingCandidates: [(index: Int, range: NSRange, swiftRange: Range<String.Index>)] = []

        for (index, proposal) in proposals.enumerated() {
            guard
                proposal.range.location >= 0,
                proposal.range.length >= 0,
                proposal.range.location <= sourceUTF16Length,
                proposal.range.length <= sourceUTF16Length - proposal.range.location
            else {
                dispositions[index] = .rejected(.invalidRange)
                continue
            }

            guard let swiftRange = Range(proposal.range, in: source) else {
                dispositions[index] = .rejected(.rangeConversionFailed)
                continue
            }

            guard String(source[swiftRange]) == proposal.expectedSourceText else {
                dispositions[index] = .rejected(.sourceTextMismatch)
                continue
            }

            guard proposal.replacementText != proposal.expectedSourceText else {
                dispositions[index] = .rejected(.noOpProposal)
                continue
            }

            survivingCandidates.append((index: index, range: proposal.range, swiftRange: swiftRange))
        }

        // Overlap/conflict detection: every pairwise intersection rejects
        // BOTH members. Never resolved by order, confidence, claimed
        // category, or any other tie-break -- see `intersects` below for
        // exactly what counts as intersecting.
        var overlapping = Set<Int>()
        for i in 0..<survivingCandidates.count {
            for j in (i + 1)..<survivingCandidates.count {
                let lhs = survivingCandidates[i]
                let rhs = survivingCandidates[j]
                if self.intersects(lhs.range, rhs.range) {
                    overlapping.insert(lhs.index)
                    overlapping.insert(rhs.index)
                }
            }
        }
        for index in overlapping {
            dispositions[index] = .rejected(.overlapsAnotherProposal)
        }

        // Protected-span intersection, then independent classification --
        // only for proposals that survived every earlier check.
        for candidate in survivingCandidates where !overlapping.contains(candidate.index) {
            let index = candidate.index
            let proposal = proposals[index]
            let range = candidate.range
            let hits = protectedSpans.filter { self.intersects($0.range, range) }

            if hits.contains(where: { $0.kind == .deterministicallyResolved }) {
                dispositions[index] = .rejected(.intersectsResolvedSpan)
                continue
            }
            if hits.contains(where: { $0.kind == .deterministicallyUnresolved }) {
                dispositions[index] = .reviewOnly(.intersectsUnresolvedSpan)
                continue
            }
            if hits.contains(where: { $0.kind == .independentlyProtected }) {
                dispositions[index] = .reviewOnly(.intersectsIndependentlyProtectedSpan)
                continue
            }

            let classification = IntelligenceEditClassifier.classify(
                from: proposal.expectedSourceText,
                to: proposal.replacementText
            )
            switch classification {
            case .punctuationOnly, .capitalizationOnly, .whitespaceOnly:
                if let block = AutonomousPermissionGate.block(
                    classification: classification,
                    source: source,
                    range: candidate.swiftRange,
                    expectedSourceText: proposal.expectedSourceText,
                    replacementText: proposal.replacementText
                ) {
                    dispositions[index] = .reviewOnly(block.reviewReason)
                } else {
                    dispositions[index] = .autonomouslyAccepted(classification)
                }
            case .other:
                dispositions[index] = .rejected(.unsupportedEditCategory)
            }
        }

        let resultingText = self.applyAcceptedEdits(dispositions: &dispositions, proposals: proposals, source: source)

        // Every index is set exactly once by one of the passes above; the
        // fallback below is unreachable by construction, but failing
        // closed to an outright rejection -- never force-unwrapping -- is
        // consistent with this type's own "never crash" invariant even if
        // that construction were ever violated by a future change.
        let outcomes = proposals.indices.map { index in
            ProposalOutcome(proposal: proposals[index], disposition: dispositions[index] ?? .rejected(.invalidRange))
        }
        return Result(outcomes: outcomes, resultingText: resultingText)
    }

    /// Applies every `.autonomouslyAccepted` proposal against the original
    /// `source`, in descending range-location order. Because overlap
    /// detection has already excluded any pair of accepted ranges from
    /// intersecting, applying right-to-left never shifts the position of a
    /// range still waiting to be applied -- so the result is independent of
    /// `proposals`' input order for any fixed *set* of accepted edits.
    private static func applyAcceptedEdits(
        dispositions: inout [ProposalDisposition?],
        proposals: [IntelligenceProposal],
        source: String
    ) -> String {
        let acceptedIndices = proposals.indices
            .filter {
                if case .autonomouslyAccepted = dispositions[$0] { return true }
                return false
            }
            .sorted { proposals[$0].range.location > proposals[$1].range.location }

        var resultingText = source
        for index in acceptedIndices {
            let proposal = proposals[index]
            guard let swiftRange = Range(proposal.range, in: resultingText) else {
                // Defensive only -- unreachable in practice: this range was
                // already validated against `source`, and non-overlapping,
                // right-to-left application never invalidates a range still
                // to come. Fail closed rather than crash if this invariant
                // is ever violated.
                dispositions[index] = .rejected(.rangeConversionFailed)
                continue
            }
            resultingText.replaceSubrange(swiftRange, with: proposal.replacementText)
        }
        return resultingText
    }

    /// Whether two ranges genuinely overlap. Deliberately not
    /// `NSIntersectionRange(a, b).length > 0`: Foundation always reports a
    /// degenerate (zero-length) intersection as length 0, which cannot
    /// distinguish a zero-length proposal range sitting exactly at a
    /// protected span's boundary (must NOT count as intersecting -- an
    /// insertion immediately before/after protected content is fine) from
    /// one sitting strictly inside it (MUST count as intersecting). This
    /// half-open-interval test draws that line explicitly:
    ///   - two positive-length ranges intersect in the ordinary sense;
    ///   - a zero-length range intersects a span iff its position is
    ///     strictly between the span's start and end (touching either
    ///     boundary does not intersect);
    ///   - two zero-length ranges intersect iff they sit at the exact same
    ///     position (two insertions at the same point conflict, even though
    ///     neither is "inside" the other).
    private static func intersects(_ a: NSRange, _ b: NSRange) -> Bool {
        if a.length == 0 && b.length == 0 {
            return a.location == b.location
        }
        return a.location < b.location + b.length && b.location < a.location + a.length
    }
}
