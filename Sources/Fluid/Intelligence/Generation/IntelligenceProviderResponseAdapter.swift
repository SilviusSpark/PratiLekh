import Foundation

/// Every way an `IntelligenceProviderResponse` can fail to yield a raw
/// proposal-batch payload worth handing to `IntelligenceProposalTransportParser`.
/// Structural response-shape failures only -- this type never itself judges
/// JSON validity or proposal safety; both remain the parser's and the
/// Safety Authority's jobs respectively. A downstream transport failure is
/// wrapped, never translated into a vaguer generic error, so its exact
/// reason is never lost.
enum IntelligenceAdapterFailure: Error, Equatable {
    /// No tool call was present, and no text content was present either --
    /// a genuinely empty response.
    case noToolCall
    /// The single tool call present was not named
    /// `IntelligenceGenerationContract.toolName`.
    case unexpectedToolName(String)
    /// More than one tool call was present, regardless of composition
    /// (two calls to the expected tool, the expected tool plus an
    /// unrelated one, or multiple unrelated ones). Never merged, never
    /// resolved by picking one -- an ambiguous response fails closed.
    case multipleToolCalls(count: Int)
    /// Non-empty assistant text was present, either instead of a tool call
    /// or alongside one. The model is not expected to need prose for this
    /// contract, so this is rejected strictly rather than tolerated.
    case unexpectedTextContent
    /// The extracted raw argument payload reached
    /// `IntelligenceProposalTransportParser` and it rejected it. The
    /// original typed transport failure is preserved, not translated away.
    case transportParseFailure(IntelligenceProposalParseFailure)
}

/// Extracts the raw V1.1 proposal-batch JSON text from a provider/model
/// response and forces it through the existing, committed transport parser.
/// This is deliberately the *only* thing this type does:
///
///   - it does NOT decode proposals itself;
///   - it does NOT repair malformed JSON;
///   - it does NOT strip markdown fences or search prose for embedded JSON;
///   - it does NOT normalize tool arguments or correct field names;
///   - it does NOT convert an alternative provider's schema into this one;
///   - it does NOT infer a missing field;
///   - it does NOT silently choose among ambiguous tool calls.
///
/// Every one of those would be a step toward the model quietly gaining
/// authority this contract does not grant it. A malformed or ambiguous
/// response always fails closed instead.
enum IntelligenceProviderResponseAdapter {
    /// Extracts and parses the expected tool call's raw arguments into a
    /// structurally-validated (never semantically-validated) proposal
    /// batch. The result still carries zero authority over transcript
    /// text -- callers must still run it through `IntelligenceSafetyAuthority`.
    static func extractProposalBatch(from response: IntelligenceProviderResponse) -> Result<ParsedIntelligenceProposalBatch, IntelligenceAdapterFailure> {
        self.rawArgumentPayload(from: response).flatMap { rawArguments in
            do {
                let batch = try IntelligenceProposalTransportParser.parse(Data(rawArguments.utf8))
                return .success(batch)
            } catch let failure as IntelligenceProposalParseFailure {
                return .failure(.transportParseFailure(failure))
            } catch {
                // IntelligenceProposalTransportParser.parse never throws
                // anything other than IntelligenceProposalParseFailure;
                // this branch exists only so an unexpected error type still
                // fails closed rather than propagating untyped.
                return .failure(.transportParseFailure(.invalidRootStructure))
            }
        }
    }

    /// Resolves the expected-tool-call policy only -- never touches JSON
    /// validity, which remains entirely the transport parser's concern.
    private static func rawArgumentPayload(from response: IntelligenceProviderResponse) -> Result<String, IntelligenceAdapterFailure> {
        let hasMeaningfulText = (response.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

        if response.toolCalls.isEmpty {
            return .failure(hasMeaningfulText ? .unexpectedTextContent : .noToolCall)
        }
        if hasMeaningfulText {
            return .failure(.unexpectedTextContent)
        }
        guard response.toolCalls.count == 1 else {
            return .failure(.multipleToolCalls(count: response.toolCalls.count))
        }

        let call = response.toolCalls[0]
        guard call.name == IntelligenceGenerationContract.toolName else {
            return .failure(.unexpectedToolName(call.name))
        }
        return .success(call.rawArguments)
    }
}
