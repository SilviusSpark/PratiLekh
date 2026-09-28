import Foundation

/// One edit's complete, ordered outcome through the deterministic chain.
/// Keeps the three failure/decision domains distinct rather than flattening
/// them into one status:
///   - a whole-response **transport/batch** failure never reaches this type
///     (see `IntelligenceEditComposition.evaluate`'s `Failure`);
///   - `.addressingRejected` -- the edit could not be located exactly once
///     in the immutable source (V1.6); it never became a proposal and never
///     reached the Safety Authority;
///   - `.evaluated` -- it resolved to a strict `IntelligenceProposal` and the
///     unmodified `IntelligenceSafetyAuthority` returned `disposition`.
///     Resolution is not permission: `disposition` alone says whether the
///     edit may proceed.
struct IntelligenceComposedEdit: Equatable {
    enum Stage: Equatable {
        case addressingRejected(IntelligenceAddressingRejection)
        case evaluated(proposal: IntelligenceProposal, basis: IntelligenceAddressingBasis, disposition: ProposalDisposition)
    }

    /// Zero-based position in the model's original edit array.
    let index: Int
    /// Batch-local id assigned by the V1.6 bridge (`p<index + 1>`), present for
    /// rejected and evaluated edits alike, so identity never depends on any
    /// other edit's outcome.
    let id: String
    /// The model-facing edit exactly as parsed.
    let edit: ModelFacingEdit
    let stage: Stage

    var disposition: ProposalDisposition? {
        if case let .evaluated(_, _, disposition) = self.stage { return disposition }
        return nil
    }

    var proposal: IntelligenceProposal? {
        if case let .evaluated(proposal, _, _) = self.stage { return proposal }
        return nil
    }
}

/// The structured result of composing a provider response with an immutable
/// source. **Carries no resulting text**: composition never applies an edit,
/// and never turns a rejected or review-only proposal into text. A later
/// milestone that applies edits must consume `accepted` deliberately.
struct IntelligenceCompositionResult: Equatable {
    /// The wire schema version the payload declared (V1: always 1).
    let schemaVersion: Int
    /// One entry per model edit, in original order (empty for a zero-edit
    /// response).
    let edits: [IntelligenceComposedEdit]

    /// Evaluated and `.autonomouslyAccepted` by the Safety Authority.
    var accepted: [IntelligenceComposedEdit] {
        self.edits.filter { if case .autonomouslyAccepted = $0.disposition { return true } else { return false } }
    }

    /// Evaluated and `.reviewOnly`: never autonomous.
    var reviewOnly: [IntelligenceComposedEdit] {
        self.edits.filter { if case .reviewOnly = $0.disposition { return true } else { return false } }
    }

    /// Resolved, then `.rejected` by the Safety Authority.
    var rejectedBySafetyAuthority: [IntelligenceComposedEdit] {
        self.edits.filter { if case .rejected = $0.disposition { return true } else { return false } }
    }

    /// Never resolved; never reached the Safety Authority.
    var addressingRejected: [IntelligenceComposedEdit] {
        self.edits.filter { if case .addressingRejected = $0.stage { return true } else { return false } }
    }
}

/// The single deterministic, model- and provider-independent entry point that
/// composes the V1 Intelligence chain:
///
///     IntelligenceProviderResponse + immutable source
///       -> ModelFacingResponseAdapter.extractEdits   (V1.7 policy + strict parse)
///       -> IntelligenceAddressingBridge.bridge       (V1.6, per-edit isolation)
///       -> IntelligenceSafetyAuthority.validate      (unmodified, one batch)
///       -> IntelligenceCompositionResult
///
/// It contains no policy of its own -- every decision is made by one of those
/// components -- knows nothing about any model, prompt, provider or runtime,
/// and **applies nothing**: no text is mutated and no resulting text is
/// returned. The caller supplies the immutable `source` and the Safety
/// Authority's `protectedSpans`.
///
/// Why the Safety Authority runs once over the whole resolved batch, not per
/// proposal: overlap/conflict detection is inherently pairwise across the
/// batch, so per-proposal invocation would silently defeat it (each proposal
/// alone can never overlap anything). Addressing-rejected edits are excluded
/// from that batch -- they have no range and cannot overlap or conflict with
/// anything -- and the Authority's per-proposal outcomes are then attributed
/// back to their edits by position. The Authority's own applied-text output
/// (`resultingText`) is deliberately discarded.
enum IntelligenceEditComposition {
    /// Whole-response failure: the response shape or wire payload was
    /// rejected before any edit was addressed. (Reused, not wrapped: the
    /// adapter's failure type already names exactly this domain.)
    typealias Failure = ModelFacingAdapterFailure

    static func evaluate(
        response: IntelligenceProviderResponse,
        source: String,
        protectedSpans: [ProtectedSpan] = []
    ) -> Result<IntelligenceCompositionResult, Failure> {
        ModelFacingResponseAdapter.extractEdits(from: response).map { parsed in
            let batch = IntelligenceAddressingBridge.bridge(parsed.edits, source: source)
            let authority = IntelligenceSafetyAuthority.validate(proposals: batch.proposals, source: source, protectedSpans: protectedSpans)

            var nextOutcome = 0
            let composed = batch.items.map { item -> IntelligenceComposedEdit in
                switch item.result {
                case let .rejected(reason):
                    return IntelligenceComposedEdit(index: item.index, id: item.id, edit: item.edit, stage: .addressingRejected(reason))
                case let .resolved(proposal, basis):
                    // The Authority returns exactly one outcome per input
                    // proposal, in input order; `batch.proposals` is these
                    // resolved items in the same order. Fail closed, as the
                    // Authority itself does for its own unreachable cases,
                    // rather than ever defaulting to acceptance.
                    let disposition = authority.outcomes.indices.contains(nextOutcome)
                        ? authority.outcomes[nextOutcome].disposition
                        : ProposalDisposition.rejected(.invalidRange)
                    nextOutcome += 1
                    return IntelligenceComposedEdit(
                        index: item.index,
                        id: item.id,
                        edit: item.edit,
                        stage: .evaluated(proposal: proposal, basis: basis, disposition: disposition)
                    )
                }
            }
            return IntelligenceCompositionResult(schemaVersion: parsed.schemaVersion, edits: composed)
        }
    }
}
