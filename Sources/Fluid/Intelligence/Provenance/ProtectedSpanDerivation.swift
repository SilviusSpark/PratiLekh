import Foundation

/// Protected spans derived from one `NormalizationOutcome`, in the exact
/// UTF-16 coordinate space of `normalizedText` (= `NormalizationOutcome.normalized`,
/// the text handed to AI and therefore the immutable source of any Intelligence
/// pass). Pass `normalizedText` as the composition/Authority `source` and
/// `spans` as its protected spans.
struct NormalizationProtectedSpans: Equatable {
    struct Entry: Equatable {
        /// `.deterministicallyResolved` for an applied change,
        /// `.deterministicallyUnresolved` for a declined one.
        let span: ProtectedSpan
        /// Where the span came from -- diagnostics only; grants nothing.
        let pass: NormalizationPassID
        let step: Int
        /// The provenance record's range in its own step's input space.
        let sourceRange: NSRange
    }

    /// The text the spans' coordinates refer to.
    let normalizedText: String
    /// Deterministically ordered: final location, then length, then pass order,
    /// then step. Spans are never merged, deduplicated or trimmed; overlapping
    /// spans are legitimate (the Safety Authority resolves overlaps
    /// most-restrictive-wins).
    let entries: [Entry]

    var spans: [ProtectedSpan] { self.entries.map(\.span) }
}

/// A provenance record whose span could not be projected into final
/// coordinates without inventing a destination.
struct UnprojectableProtectedSpan: Equatable {
    /// The span kind it would have had.
    let kind: ProtectedSpanKind
    let pass: NormalizationPassID
    let step: Int
    /// The record's range in its own step's input space.
    let sourceRange: NSRange
    /// The later change that blocks the projection: one of the span's
    /// boundaries falls strictly inside the text it replaced.
    let blockedByPass: NormalizationPassID
    let blockedByStep: Int
    let blockedByRange: NSRange
}

enum ProtectedSpanDerivationFailure: Error, Equatable {
    /// The provenance itself is inconsistent or tampered with
    /// (`NormalizationReplay` rejected it). No span can be trusted.
    case invalidProvenance(NormalizationReplay.Failure)
    /// The provenance is valid but at least one span cannot be projected into
    /// final coordinates without ambiguity. Every such span is listed; none is
    /// silently omitted, and no partial result is offered -- a caller must
    /// treat this as "protection cannot be established" for this text.
    case unprojectable([UnprojectableProtectedSpan])
    /// A projected span did not match the final text it was projected onto.
    /// Unreachable for valid provenance; reported (never ignored) if the
    /// projection arithmetic ever disagrees with the actual text.
    case projectionVerificationFailed(pass: NormalizationPassID, step: Int, sourceRange: NSRange)
}

/// Deterministically derives `ProtectedSpan`s in final normalized coordinates
/// from V1.10 provenance. No model, no search, no text relocation and no
/// inference: it replays the provenance through `NormalizationReplay` (which
/// verifies it), then projects each record's range forward through the applied
/// replacements of every later step.
///
/// Span-kind mapping (the existing Safety Authority semantics, unchanged):
///   - applied normalization  -> `.deterministicallyResolved`
///   - declined normalization -> `.deterministicallyUnresolved`
///
/// Projection rules. Every record indexes the input of its `(pass, step)`. Its
/// projected span in that step's OUTPUT is `[start', start' + n)`, where
/// `start'` shifts the record's start by the net length change of the other
/// applied records of the same step that end at or before it, and `n` is the
/// replacement's length (applied) or the preserved text's length (declined).
/// It is then carried through each later step (in replay order) by mapping its
/// two boundaries independently through that step's applied replacements
/// `[a, b) -> L`:
///   - a boundary at or after `b` shifts by `L - (b - a)`;
///   - a boundary at or before `a` is unaffected;
///   - a boundary **strictly inside** `(a, b)` has no exact image: the span is
///     reported in `unprojectable`, never given an invented coordinate;
///   - a boundary at exactly `a` or `b` is a boundary, not "inside" (adjacency
///     and exact-boundary coincidence are therefore well defined);
///   - a later replacement lying wholly inside the span simply resizes it
///     (nested changes); one exactly equal to the span maps the span onto the
///     replacement's output; a zero-length replacement located exactly at a
///     boundary is ambiguous and reported.
/// Steps with no records are identity transitions. Finally each projected span
/// is verified against the actual final text (its expected content is the
/// record's replacement/trigger with any nested later replacements applied).
enum ProtectedSpanDerivation {
    private struct StepKey: Hashable {
        let pass: NormalizationPassID
        let step: Int
    }

    private struct Replacement {
        let range: NSRange
        let text: String
        let pass: NormalizationPassID
        let step: Int
    }

    private struct Source {
        let kind: ProtectedSpanKind
        let pass: NormalizationPassID
        let step: Int
        let range: NSRange
        /// The text the span holds right after its own step.
        let text: String
    }

    static func derive(from outcome: NormalizationOutcome) -> Result<NormalizationProtectedSpans, ProtectedSpanDerivationFailure> {
        let steps: [NormalizationReplay.Step]
        switch NormalizationReplay.steps(of: outcome) {
        case let .success(replayed): steps = replayed
        case let .failure(failure): return .failure(.invalidProvenance(failure))
        }

        var stepIndex: [StepKey: Int] = [:]
        for (index, step) in steps.enumerated() {
            stepIndex[StepKey(pass: step.pass, step: step.step)] = index
        }
        var replacements = [[Replacement]](repeating: [], count: steps.count)
        var sources: [Source] = []
        for change in outcome.appliedChanges {
            guard let index = stepIndex[StepKey(pass: change.pass, step: change.step)] else { return .failure(.invalidProvenance(.unknownPass(change.pass))) }
            replacements[index].append(Replacement(range: change.range, text: change.replacement, pass: change.pass, step: change.step))
            sources.append(Source(kind: .deterministicallyResolved, pass: change.pass, step: change.step, range: change.range, text: change.replacement))
        }
        for change in outcome.declinedChanges {
            guard stepIndex[StepKey(pass: change.pass, step: change.step)] != nil else { return .failure(.invalidProvenance(.unknownPass(change.pass))) }
            sources.append(Source(kind: .deterministicallyUnresolved, pass: change.pass, step: change.step, range: change.range, text: change.trigger))
        }

        var entries: [(entry: NormalizationProtectedSpans.Entry, passOrder: Int)] = []
        var unprojectable: [UnprojectableProtectedSpan] = []
        for source in sources {
            guard let ownStep = stepIndex[StepKey(pass: source.pass, step: source.step)] else { return .failure(.invalidProvenance(.unknownPass(source.pass))) }
            let own = replacements[ownStep]
            // The span right after its own step.
            let shift = own.filter { $0.range.location + $0.range.length <= source.range.location && !($0.range == source.range) }
                .reduce(0) { $0 + $1.text.utf16.count - $1.range.length }
            var start = source.range.location + shift
            var end = start + source.text.utf16.count
            var text = source.text

            var blocked: Replacement?
            for later in replacements.dropFirst(ownStep + 1) {
                let inside = later.filter { $0.range.location >= start && $0.range.location + $0.range.length <= end }
                if let block = later.first(where: { self.blocks($0, position: start) || self.blocks($0, position: end) }) {
                    blocked = block
                    break
                }
                // Apply wholly-nested replacements to the span's own text.
                let nsText = NSMutableString(string: text)
                for replacement in inside.sorted(by: { $0.range.location > $1.range.location }) {
                    nsText.replaceCharacters(in: NSRange(location: replacement.range.location - start, length: replacement.range.length), with: replacement.text)
                }
                text = nsText as String
                start += self.shift(before: start, later)
                end += self.shift(before: end, later)
            }
            if let blocked {
                unprojectable.append(UnprojectableProtectedSpan(
                    kind: source.kind,
                    pass: source.pass,
                    step: source.step,
                    sourceRange: source.range,
                    blockedByPass: blocked.pass,
                    blockedByStep: blocked.step,
                    blockedByRange: blocked.range
                ))
                continue
            }

            let final = outcome.normalized as NSString
            guard start >= 0, end >= start, end <= final.length, final.substring(with: NSRange(location: start, length: end - start)) == text else {
                return .failure(.projectionVerificationFailed(pass: source.pass, step: source.step, sourceRange: source.range))
            }
            entries.append((
                NormalizationProtectedSpans.Entry(
                    span: ProtectedSpan(range: NSRange(location: start, length: end - start), kind: source.kind),
                    pass: source.pass,
                    step: source.step,
                    sourceRange: source.range
                ),
                outcome.passes.firstIndex(of: source.pass) ?? Int.max
            ))
        }

        guard unprojectable.isEmpty else {
            return .failure(.unprojectable(unprojectable.sorted {
                ($0.pass.rawValue, $0.step, $0.sourceRange.location, $0.sourceRange.length) < ($1.pass.rawValue, $1.step, $1.sourceRange.location, $1.sourceRange.length)
            }))
        }
        let ordered = entries.sorted {
            ($0.entry.span.range.location, $0.entry.span.range.length, $0.passOrder, $0.entry.step)
                < ($1.entry.span.range.location, $1.entry.span.range.length, $1.passOrder, $1.entry.step)
        }
        return .success(NormalizationProtectedSpans(normalizedText: outcome.normalized, entries: ordered.map(\.entry)))
    }

    /// True when `position` cannot be mapped through `replacement`: strictly
    /// inside its replaced range, or coinciding with a zero-length one.
    private static func blocks(_ replacement: Replacement, position: Int) -> Bool {
        let start = replacement.range.location
        let end = start + replacement.range.length
        if start < position && position < end { return true }
        return replacement.range.length == 0 && position == start
    }

    /// Net length change of every replacement that ends at or before `position`.
    private static func shift(before position: Int, _ replacements: [Replacement]) -> Int {
        replacements
            .filter { $0.range.location + $0.range.length <= position }
            .reduce(0) { $0 + $1.text.utf16.count - $1.range.length }
    }
}
