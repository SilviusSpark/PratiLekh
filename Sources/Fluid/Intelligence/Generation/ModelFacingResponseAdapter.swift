import Foundation

/// Every way a provider response can fail to yield resolved model-facing
/// edits' *input*: response-shape failures (mirroring
/// `IntelligenceAdapterFailure`, for the model-facing tool name) and typed
/// wire-parse failures. Addressing failures are NOT here: they are isolated
/// per edit inside `IntelligenceAddressingBatchResult`, never a whole-response
/// failure.
enum ModelFacingAdapterFailure: Error, Equatable {
    case noToolCall
    case unexpectedToolName(String)
    case multipleToolCalls(count: Int)
    case unexpectedTextContent
    /// The raw argument payload reached `ModelFacingEditTransportParser` and
    /// it rejected it; the typed reason is preserved.
    case wireParseFailure(ModelFacingEditParseFailure)
}

/// Deterministic path from a provider response's preserved **raw** tool-call
/// arguments to model-facing edits, and on through the V1.6 bridge:
///
///     IntelligenceProviderResponse (raw arguments)
///       -> tool-call policy            (this type)
///       -> ModelFacingEditTransportParser   (strict wire parse)
///       -> [ModelFacingEdit]
///       -> IntelligenceAddressingBridge     (resolve against immutable source)
///       -> [IntelligenceProposal]      (caller then runs the Safety Authority)
///
/// Like `IntelligenceProviderResponseAdapter` it never repairs malformed
/// output, strips fences, searches prose for JSON, normalizes arguments, or
/// picks among ambiguous tool calls. It does **not** call the Safety
/// Authority -- callers do, so parsing, addressing and safety stay separate
/// components. Its tool-call policy intentionally mirrors V1.2's
/// (`IntelligenceProviderResponseAdapter`), which is left unmodified; both
/// adapters' tests assert the same response-shape cases.
enum ModelFacingResponseAdapter {
    /// Extracts and strictly parses the expected tool call's raw arguments.
    /// Success carries no authority: the edits are not yet resolved, let
    /// alone validated.
    static func extractEdits(from response: IntelligenceProviderResponse) -> Result<ParsedModelFacingEditBatch, ModelFacingAdapterFailure> {
        self.rawArgumentPayload(from: response).flatMap { rawArguments in
            do {
                return .success(try ModelFacingEditTransportParser.parse(Data(rawArguments.utf8)))
            } catch let failure as ModelFacingEditParseFailure {
                return .failure(.wireParseFailure(failure))
            } catch {
                // The parser only throws ModelFacingEditParseFailure; this
                // branch exists so an unexpected error type still fails closed.
                return .failure(.wireParseFailure(.invalidRootStructure))
            }
        }
    }

    /// Extracts, parses, then resolves every edit against the same immutable
    /// `source` via the V1.6 bridge. A whole-response (shape or wire)
    /// failure returns `.failure`; a per-edit addressing failure is reported
    /// inside the returned batch and never aborts it.
    static func resolveEdits(
        from response: IntelligenceProviderResponse,
        source: String
    ) -> Result<IntelligenceAddressingBatchResult, ModelFacingAdapterFailure> {
        self.extractEdits(from: response).map { IntelligenceAddressingBridge.bridge($0.edits, source: source) }
    }

    private static func rawArgumentPayload(from response: IntelligenceProviderResponse) -> Result<String, ModelFacingAdapterFailure> {
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
        guard call.name == ModelFacingGenerationContract.toolName else {
            return .failure(.unexpectedToolName(call.name))
        }
        return .success(call.rawArguments)
    }
}
