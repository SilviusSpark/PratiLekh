import Foundation

/// The result for one `ModelFacingEdit` in a batch.
enum IntelligenceAddressingItemResult: Equatable {
    /// Located exactly once. `proposal` is a standard, strict
    /// `IntelligenceProposal`, indistinguishable to
    /// `IntelligenceSafetyAuthority` from any other; resolving is not
    /// permission.
    case resolved(proposal: IntelligenceProposal, basis: IntelligenceAddressingBasis)
    case rejected(IntelligenceAddressingRejection)
}

/// One batch item's outcome, tied back to its original position.
struct IntelligenceAddressingItemOutcome: Equatable {
    /// Zero-based position in the original edit array.
    let index: Int
    /// The batch-local identifier assigned from `index` -- assigned to every
    /// item, resolved or rejected, so it never depends on any other item's
    /// outcome.
    let id: String
    let edit: ModelFacingEdit
    let result: IntelligenceAddressingItemResult
}

struct IntelligenceAddressingBatchResult: Equatable {
    /// One outcome per input edit, in original input order.
    let items: [IntelligenceAddressingItemOutcome]

    /// The resolved proposals only, in original input order, ready for
    /// `IntelligenceSafetyAuthority.validate`.
    var proposals: [IntelligenceProposal] {
        self.items.compactMap {
            if case let .resolved(proposal, _) = $0.result { return proposal }
            return nil
        }
    }

    var rejections: [(index: Int, id: String, reason: IntelligenceAddressingRejection)] {
        self.items.compactMap {
            if case let .rejected(reason) = $0.result { return (index: $0.index, id: $0.id, reason: reason) }
            return nil
        }
    }
}

/// The deterministic bridge from the model-facing addressing contract to the
/// strict internal one:
///
///     [ModelFacingEdit] -> IntelligenceAddressingResolver -> [IntelligenceProposal]
///
/// This type resolves and converts; it does not judge safety, detect
/// overlap or conflict, classify edit categories, consult protected spans,
/// or apply anything -- all of that remains
/// `IntelligenceSafetyAuthority`'s exclusive responsibility, downstream.
///
/// Governing invariants:
///   - Every edit resolves against the **same original, immutable
///     `source`**, independently of every other edit. Resolution is a pure
///     function of (edit, source): one item's success or failure can never
///     change another's outcome, and reversing the array yields the same
///     per-item results.
///   - Original order is preserved.
///   - An addressing failure is isolated to its own item and reported
///     explicitly; it never aborts the batch.
///   - `IntelligenceProposal.id` is assigned here (model-facing edits carry
///     none): `"p<n>"` with `n` the 1-based original position, matching the
///     `p1`, `p2`, ... convention used throughout the Intelligence tests.
///   - `claimedCategory` is always `.other`. The bridge makes no claim about
///     the edit; the Authority re-derives the real category independently
///     and never trusts this field anyway.
///   - `expectedSourceText` is always read from the actual immutable source
///     at the resolved range -- never from the model's own echo.
enum IntelligenceAddressingBridge {
    static func bridge(_ edits: [ModelFacingEdit], source: String) -> IntelligenceAddressingBatchResult {
        let nsSource = source as NSString
        let items = edits.enumerated().map { index, edit -> IntelligenceAddressingItemOutcome in
            let id = "p\(index + 1)"
            switch IntelligenceAddressingResolver.resolve(edit, in: source) {
            case let .success(resolution):
                let proposal = IntelligenceProposal(
                    id: id,
                    range: resolution.range,
                    expectedSourceText: nsSource.substring(with: resolution.range),
                    replacementText: edit.replacementText,
                    claimedCategory: .other
                )
                return IntelligenceAddressingItemOutcome(
                    index: index,
                    id: id,
                    edit: edit,
                    result: .resolved(proposal: proposal, basis: resolution.basis)
                )
            case let .failure(reason):
                return IntelligenceAddressingItemOutcome(index: index, id: id, edit: edit, result: .rejected(reason))
            }
        }
        return IntelligenceAddressingBatchResult(items: items)
    }
}
