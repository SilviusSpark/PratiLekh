import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// Pure, model/provider-independent data types for one sample's journey
/// through the existing, unmodified Intelligence chain. Nothing here calls a
/// model, mutates live dictation, or adds a new safety rule: every
/// disposition/reason value is read straight from `IntelligenceSafetyAuthority`
/// (via `IntelligenceEditComposition`), `IntelligenceAddressingBridge`, and
/// `ModelFacingResponseAdapter` -- this file only shapes those existing typed
/// outcomes for adjudication-focused reporting.
enum IntelligenceHarnessBucket: String {
    case autonomouslyAccepted
    case reviewOnly
    case rejectedBySafetyAuthority
    case addressingRejected
}

/// One model-proposed edit's complete, ordered journey:
/// `model proposal -> addressing result -> deterministic disposition/reason`.
struct IntelligenceHarnessEditRecord {
    /// 1-based position in the model's own edit array (matches the `p<n>` ids
    /// `IntelligenceAddressingBridge`/`IntelligenceEditComposition` assign).
    let position: Int
    let id: String
    let modelEdit: ModelFacingEdit
    /// Human-readable addressing outcome, e.g. "resolved (basis: occurrence)"
    /// or "rejected: noLiteralMatch". Built with `String(describing:)` over
    /// the real typed value -- never a separate, hand-maintained taxonomy.
    let addressingSummary: String
    /// Human-readable deterministic disposition, e.g.
    /// "autonomouslyAccepted(punctuationOnly)" or
    /// "reviewOnly(acronymCapitalizationLowered)" or
    /// "rejected(unsupportedEditCategory)" or "addressingRejected".
    let dispositionSummary: String
    let bucket: IntelligenceHarnessBucket
}

/// A sample that reached the deterministic chain and produced zero or more
/// edit outcomes.
struct IntelligenceHarnessEvaluatedSample {
    let schemaVersion: Int
    let edits: [IntelligenceHarnessEditRecord]
    /// `source` with only `.autonomouslyAccepted` edits applied -- computed
    /// in the harness itself (never by changing `IntelligenceEditComposition`'s
    /// public shape) by replaying `result.accepted` right-to-left over the
    /// immutable source. Accepted edits are guaranteed pairwise
    /// non-overlapping by the Safety Authority itself (overlapping proposals
    /// are always rejected together), so this replay can never conflict.
    let wouldBeOutput: String

    var isZeroProposal: Bool { self.edits.isEmpty }
}

/// Every way one sample's run can end, kept as distinct cases rather than
/// one flattened status -- exactly mirroring the inspection the V1.16
/// readiness assessment asked to preserve:
///   `input -> model proposal -> addressing result -> deterministic
///   disposition/reason -> would-be output`.
enum IntelligenceHarnessSampleOutcome {
    /// Legal normalization or V1.11 protected-span derivation could not be
    /// trusted for this input (an `invalidProvenance`/`unprojectable`/
    /// `projectionVerificationFailed` result from `ProtectedSpanDerivation`).
    /// The model is never called for a sample in this state -- there is
    /// nothing an Intelligence proposal could be safely checked against.
    case preflightFailure(String)
    /// `LLMClient` (or the harness's own request construction) threw or
    /// otherwise failed. No Intelligence/composition code was invoked for
    /// this sample -- this is the literal fail-closed behavior requested:
    /// a provider/runtime failure never reaches Intelligence at all.
    case providerFailure(String)
    /// The response reached the chain but failed a whole-response check
    /// before any individual edit could be addressed: no tool call, the
    /// wrong tool, more than one tool call, free text instead of a tool
    /// call, or a malformed/adversarial wire payload
    /// (`ModelFacingAdapterFailure`, via `ModelFacingResponseAdapter`).
    case wholeResponseRejected(String)
    /// The response was structurally valid; see `evaluated` for per-edit
    /// outcomes (which may still be an empty list -- a valid, often
    /// preferred, zero-edit proposal).
    case evaluated(IntelligenceHarnessEvaluatedSample)
}

/// One sample's complete record, in the exact order needed for manual
/// adjudication: raw input, the real legal-normalized Intelligence source,
/// the model's raw (unparsed) output for transparency, and the outcome.
struct IntelligenceHarnessSampleReport {
    let sampleID: String
    /// "synthetic" or "real-dictation" -- the evidence tier this sample's
    /// input text belongs to. Carried on every record so a report can never
    /// silently blend the two.
    let tier: String
    let rawInputText: String
    /// `NormalizationOutcome.normalized` -- the actual, immutable Intelligence
    /// source text (identical to what `IntelligenceEditComposition` validated
    /// against). `nil` only when preprocessing itself could not run at all.
    let legalNormalizedText: String?
    /// The model's own free-text content, if any (should be empty/nil for a
    /// well-behaved response per the frozen contract; present for
    /// transparency, never interpreted).
    let modelTextContent: String?
    /// Every tool call's raw, unparsed argument JSON text, exactly as the
    /// provider returned it -- not the decoded/re-serialized form -- so a
    /// human reviewer can see precisely what the model said.
    let modelRawToolCallArguments: [String]
    let outcome: IntelligenceHarnessSampleOutcome
}
