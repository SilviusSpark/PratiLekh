import Foundation

/// One untrusted, model-facing replacement edit, in the shape frozen by
/// Intelligence V1.5 (`Evaluation/Intelligence/V1_5_ADDRESSING_CONTRACT_FREEZE.md`,
/// sections 3-4): the model identifies *which* text it means by quoting it
/// literally, never by computing a UTF-16 offset. This is deliberately a
/// different contract from `IntelligenceProposal` (the strict internal
/// contract) -- the two are bridged only by `IntelligenceAddressingBridge`,
/// after `IntelligenceAddressingResolver` deterministically locates the
/// text. A `ModelFacingEdit` has no `id`, no claimed category and no range,
/// and grants no authority: nothing about it is trusted until it has both
/// resolved and passed `IntelligenceSafetyAuthority`.
///
/// This type is transport-independent. No wire JSON/schema/parser for it
/// exists yet; a future milestone will own that. It covers replacement and
/// deletion (`replacementText == ""`) only -- insertion is out of scope for
/// V1.6.
struct ModelFacingEdit: Equatable {
    /// Exact literal text in the immutable source that this edit targets.
    /// Exact only: no case-folding, no Unicode normalization, no fuzzy or
    /// semantic matching, no typo repair. Must be non-empty.
    let sourceText: String
    /// The text that would replace `sourceText`. Carries no addressing
    /// meaning at all; irrelevant to resolution.
    let replacementText: String
    /// 1-based ordinal among the literal occurrences of `sourceText`, in
    /// source order (first = 1). `0` and negative values are invalid and are
    /// never auto-corrected.
    let occurrence: Int?
    /// Exact literal text that must immediately precede the intended
    /// occurrence. `nil` and `""` are equivalent: both mean "not supplied",
    /// never a wildcard.
    let leftContext: String?
    /// Exact literal text that must immediately follow the intended
    /// occurrence. `nil` and `""` are equivalent, as for `leftContext`.
    let rightContext: String?

    init(
        sourceText: String,
        replacementText: String,
        occurrence: Int? = nil,
        leftContext: String? = nil,
        rightContext: String? = nil
    ) {
        self.sourceText = sourceText
        self.replacementText = replacementText
        self.occurrence = occurrence
        self.leftContext = leftContext
        self.rightContext = rightContext
    }
}
