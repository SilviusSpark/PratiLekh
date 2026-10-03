import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: deterministic scoring from raw records.
///
/// Recomputes every S3 per-entry quantity from a `ComparisonCallRecord` and the committed deterministic
/// chain, with **no model, no network and no new policy**:
///   - the V1.23 adjudication (`CapabilityAdjudicator`, exact-pair correctness, recall levels, buckets);
///   - the V1.25 outcome semantics (`LicensedOutcomes`, `SupplementaryOutcomeState`, U1/U2/U3 monitors,
///     edit-form adherence), applied exactly as `SupplementaryEvaluator` applies them to a trial. This file
///     re-states that per-entry loop (the V1.25 evaluator cannot be linked: it also carries the loader of the
///     V1.23 benchmark artifacts, which the execution path must not contain); a parity test runs both on the
///     same synthetic raw outputs and requires identical results.
/// Scoring is a pure function of (entry, record): re-running it later can only reproduce, never reinterpret.
struct ComparisonEntryScore {
    let entry: CapabilityCorpus.Entry
    let record: ComparisonCallRecord
    let adjudication: CapabilityEntryAdjudication
    let normalized: String?
    let licensed: LicensedOutcomes? // nil for manual entries
    let autonomousFinal: String?
    /// Nil for manual entries. For a trial that produced no response the state is `unchanged` by construction (no
    /// edit reached the text); analysis counts outcome states only over trials with a response.
    let autonomousState: SupplementaryOutcomeState?
    let counterfactualState: SupplementaryOutcomeState?
    let acceptedEditCount: Int
    /// U0 reference: autonomously accepted edits on a scored entry equal to no expected pair (report-only, PO-1).
    let exactPairViolations: Int
    let runtime: [SupplementaryRuntimeObservation]
    let digitSequenceChanged: Bool
    /// Per-edit bucket, in the model's own order (the audit comparison key).
    let bucketSequence: [String]
    /// The response contained the expected tool call.
    let toolEngaged: Bool
    /// The response reached the strict parser: exactly one, correctly named tool call.
    let reachedParser: Bool
    let parserCompliant: Bool
    let formAll: SupplementaryFormAdherence
    let formAutonomous: SupplementaryFormAdherence
    /// Span width of every model edit that resolved addressing (all dispositions).
    let spanWidths: [ComparisonSpanWidth]
    /// Every model edit that set an optional field, and every addressing rejection reason (edit-form group).
    let editsWithOccurrence: Int
    let editsWithContext: Int
    let addressingRejectionReasons: [String]
    /// Re-derived preprocessing disagreed with what the record stored (a fidelity defect; expected none).
    let replayMismatch: String?

    var trialKind: CapabilityTrialKind {
        self.adjudication.trial
    }

    /// An evaluated response proposing at least one edit.
    var isNonEmpty: Bool {
        self.adjudication.trial == .evaluated && !self.adjudication.isZeroProposal
    }
}

enum ComparisonScoring {
    static func score(
        entry: CapabilityCorpus.Entry,
        record: ComparisonCallRecord,
        processor: LegalDictationProcessor
    ) throws -> ComparisonEntryScore {
        var mismatch: String?
        if record.entryID != entry.id || record.rawInputText != entry.text {
            mismatch = "record does not belong to this entry"
        }
        let pre: IntelligenceHarnessPipeline.Preflight? = switch IntelligenceHarnessPipeline.preflight(
            rawInputText: entry.text,
            processor: processor
        ) {
        case .failure: nil
        case let .success(value): value
        }
        if (pre == nil) != (record.preflightFailure != nil) || (pre != nil && record.legalNormalizedText != pre?.normalizedText) {
            mismatch = (mismatch.map { $0 + "; " } ?? "") + "re-derived preflight differs from the record"
        }

        let hasResponse = record.preflightFailure == nil && record.providerFailure == nil && record.latencyMilliseconds != nil
        let toolEngaged = hasResponse && record.toolCallNames.contains(ModelFacingGenerationContract.toolName)
        let reachedParser = hasResponse && record.toolCallNames == [ModelFacingGenerationContract.toolName]

        // Outcome via the real V1.17 pipeline, exactly as the V1.23A driver builds it.
        let outcome: IntelligenceHarnessSampleOutcome
        let response = IntelligenceProviderResponse(
            textContent: record.modelTextContent,
            toolCalls: zip(record.toolCallNames, record.rawToolCallArguments).map { IntelligenceProviderToolCall(name: $0, rawArguments: $1) }
        )
        if let reason = record.preflightFailure {
            outcome = .preflightFailure(reason)
        } else if let reason = record.providerFailure {
            outcome = .providerFailure(reason)
        } else if let pre, hasResponse {
            switch IntelligenceHarnessPipeline.evaluate(response: response, normalizedText: pre.normalizedText, protectedSpans: pre.protectedSpans) {
            case let .failure(reason): outcome = .wholeResponseRejected(reason.description)
            case let .success(sample): outcome = .evaluated(sample)
            }
        } else {
            outcome = .providerFailure("record carries neither a response nor a failure")
        }
        let adjudication = CapabilityAdjudicator.adjudicate(entry: entry, outcome: outcome)

        var autonomous: [(range: NSRange, replacement: String)] = []
        var addressed: [(range: NSRange, replacement: String)] = []
        var observations: [SupplementaryRuntimeObservation] = []
        var violations = 0
        var buckets: [String] = []
        var formAll = SupplementaryFormAdherence()
        var formAutonomous = SupplementaryFormAdherence()
        var widths: [ComparisonSpanWidth] = []
        var withOccurrence = 0
        var withContext = 0
        var rejections: [String] = []
        if let pre, hasResponse, case let .success(composition) = IntelligenceEditComposition.evaluate(
            response: response,
            source: pre.normalizedText,
            protectedSpans: pre.protectedSpans
        ) {
            for composed in composition.edits {
                let matches = entry.expectedCorrections
                    .contains { $0.source == composed.edit.sourceText && $0.replacement == composed.edit.replacementText }
                if composed.edit.occurrence != nil {
                    withOccurrence += 1
                }
                if composed.edit.leftContext != nil || composed.edit.rightContext != nil {
                    withContext += 1
                }
                switch composed.stage {
                case let .addressingRejected(reason):
                    buckets.append(IntelligenceHarnessBucket.addressingRejected.rawValue)
                    rejections.append("\(reason)")
                case let .evaluated(proposal, _, disposition):
                    widths.append(ComparisonSpanWidth.classify(sourceText: composed.edit.sourceText, normalized: pre.normalizedText))
                    addressed.append((proposal.range, proposal.replacementText))
                    switch disposition {
                    case .autonomouslyAccepted:
                        buckets.append(IntelligenceHarnessBucket.autonomouslyAccepted.rawValue)
                        autonomous.append((proposal.range, proposal.replacementText))
                        observations.append(SupplementaryRuntimeSafetyMonitor.observe(
                            source: pre.normalizedText,
                            range: proposal.range,
                            expectedSourceText: proposal.expectedSourceText,
                            replacementText: proposal.replacementText,
                            protectedSpans: pre.protectedSpans
                        ))
                        if entry.isScored, !matches {
                            violations += 1
                        }
                        formAutonomous.add(
                            sourceText: composed.edit.sourceText,
                            replacementText: composed.edit.replacementText,
                            normalized: pre.normalizedText,
                            matchesExpectedPair: matches
                        )
                    case .reviewOnly: buckets.append(IntelligenceHarnessBucket.reviewOnly.rawValue)
                    case .rejected: buckets.append(IntelligenceHarnessBucket.rejectedBySafetyAuthority.rawValue)
                    }
                    formAll.add(
                        sourceText: composed.edit.sourceText,
                        replacementText: composed.edit.replacementText,
                        normalized: pre.normalizedText,
                        matchesExpectedPair: matches
                    )
                }
            }
        }

        var licensed: LicensedOutcomes?
        var autonomousFinal: String?
        var state: SupplementaryOutcomeState?
        var counterfactualState: SupplementaryOutcomeState?
        if let pre {
            let final = SupplementaryApplication.apply(autonomous, to: pre.normalizedText).text
            autonomousFinal = final
            if entry.isScored {
                switch LicensedOutcomes.compute(source: pre.normalizedText, corrections: entry.expectedCorrections) {
                case .failure: throw ComparisonScoringError.licensedOutcomes(entry.id)
                case let .success(value):
                    licensed = value
                    state = SupplementaryOutcomeState.classify(final: final, source: pre.normalizedText, licensed: value)
                    counterfactualState = SupplementaryOutcomeState.classify(
                        final: SupplementaryApplication.apply(addressed, to: pre.normalizedText).text,
                        source: pre.normalizedText,
                        licensed: value
                    )
                }
            }
        }
        return ComparisonEntryScore(
            entry: entry,
            record: record,
            adjudication: adjudication,
            normalized: pre?.normalizedText,
            licensed: licensed,
            autonomousFinal: autonomousFinal,
            autonomousState: state,
            counterfactualState: counterfactualState,
            acceptedEditCount: autonomous.count,
            exactPairViolations: violations,
            runtime: observations,
            digitSequenceChanged: pre.map { SupplementaryRuntimeSafetyMonitor.digitSequenceChanged(
                source: $0.normalizedText,
                output: autonomousFinal ?? $0.normalizedText
            ) } ?? false,
            bucketSequence: buckets,
            toolEngaged: toolEngaged,
            reachedParser: reachedParser,
            parserCompliant: reachedParser && adjudication.trial == .evaluated,
            formAll: formAll,
            formAutonomous: formAutonomous,
            spanWidths: widths,
            editsWithOccurrence: withOccurrence,
            editsWithContext: withContext,
            addressingRejectionReasons: rejections,
            replayMismatch: mismatch
        )
    }
}

enum ComparisonScoringError: Error, CustomStringConvertible {
    case licensedOutcomes(String)
    case missingRecord(String)
    case duplicateRecord(String)
    var description: String {
        switch self {
        case let .licensedOutcomes(id): "\(id): expected corrections are not uniquely locatable/non-overlapping"
        case let .missingRecord(id): "no screening record for \(id)"
        case let .duplicateRecord(id): "more than one record for \(id) in the same phase"
        }
    }
}

/// Pre-registered determinism-audit comparison: "any disagreement between the two attempts (disposition
/// bucket or outcome state) is reported as nondeterminism". Operationalized as: the trial kind, the ordered
/// per-edit disposition buckets, or the V1.25 autonomous outcome state differ. Whether the raw text differs
/// while those agree is reported separately and is not, by the protocol's wording, a disagreement.
struct ComparisonAuditComparison {
    let entryID: String
    let disagrees: Bool
    let reasons: [String]
    let rawOutputDiffers: Bool
}

enum ComparisonAudit {
    static func compare(screening: ComparisonEntryScore, audit: ComparisonEntryScore) -> ComparisonAuditComparison {
        var reasons: [String] = []
        if screening.trialKind != audit.trialKind {
            reasons.append("trial kind \(screening.trialKind.rawValue) vs \(audit.trialKind.rawValue)")
        }
        if screening.bucketSequence != audit.bucketSequence {
            reasons.append("disposition buckets \(screening.bucketSequence) vs \(audit.bucketSequence)")
        }
        if screening.autonomousState != audit.autonomousState {
            reasons.append("outcome state \(String(describing: screening.autonomousState)) vs \(String(describing: audit.autonomousState))")
        }
        let rawA = screening.record.rawToolCallArguments + [screening.record.modelTextContent ?? ""]
        let rawB = audit.record.rawToolCallArguments + [audit.record.modelTextContent ?? ""]
        return ComparisonAuditComparison(entryID: screening.entry.id, disagrees: !reasons.isEmpty, reasons: reasons, rawOutputDiffers: rawA != rawB)
    }
}

/// Edit-form span width (protocol metric group 2): minimal / whole-sentence / whole-text. Deterministic and
/// fixed here, before any inference. `wholeText`: the edit's source text is the entire legal-normalized text.
/// `wholeSentence`: not the whole text, but exactly one sentence of a multi-sentence text, where sentences are
/// maximal runs ending at `.`, `?` or `!` followed by whitespace or the end of the text (trailing/leading
/// whitespace ignored). Everything else is `minimal`. A single-sentence text can only be `wholeText`/`minimal`.
enum ComparisonSpanWidth: String, CaseIterable {
    case minimal, wholeSentence, wholeText

    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let scalars = Array(text)
        for (index, character) in scalars.enumerated() {
            current.append(character)
            if ".?!".contains(character), index + 1 == scalars.count || scalars[index + 1].isWhitespace {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty {
            result.append(rest)
        }
        return result
    }

    static func classify(sourceText: String, normalized: String) -> ComparisonSpanWidth {
        if sourceText == normalized {
            return .wholeText
        }
        let all = self.sentences(normalized)
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.count > 1 && all.contains(trimmed) ? .wholeSentence : .minimal
    }
}
