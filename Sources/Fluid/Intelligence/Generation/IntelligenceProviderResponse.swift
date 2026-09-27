import Foundation

/// A minimal, provider-independent representation of an already-decoded
/// model/provider response, as far as `IntelligenceProviderResponseAdapter`
/// needs to see it: optional assistant text, and zero or more tool calls
/// each carrying its **raw, unparsed** argument JSON text.
///
/// Deliberately a distinct type from `LLMClient.ToolCall`, not a reuse of
/// it: that existing type's `arguments` field is decoded into
/// `[String: Any]` via `JSONSerialization.jsonObject(with:)`, and
/// `JSONSerialization`/`JSONDecoder` silently collapse duplicate JSON keys
/// and coerce integer-valued floats before any Swift code can observe the
/// original text (verified empirically in the V1.1 milestone) -- a decoded
/// dictionary can never recover that information after the fact.
/// `IntelligenceProposalTransportParser` depends on seeing the ORIGINAL raw
/// text to detect exactly that class of adversarial input, so this type
/// carries `rawArguments: String`, not a decoded dictionary.
///
/// `LLMClient.ToolCall` now *also* preserves `rawArguments: String`
/// (captured before `JSONSerialization` runs, at all four of its response
/// construction sites) specifically so a real bridge is possible without
/// weakening either type -- see `IntelligenceProviderResponse+LLMClientBridge.swift`,
/// kept in its own file specifically so this file has no dependency on
/// `LLMClient` and remains compilable/testable via this repo's lightweight
/// standalone convention (`scripts/test_intelligence_safety.sh`), unlike
/// `LLMClient.swift` itself. This milestone still performs no live
/// `LLMClient` call anywhere; the bridge exists only to prove the raw
/// payload survives the trip, using synthetic `LLMClient.Response` values
/// constructed directly in tests.
struct IntelligenceProviderResponse: Equatable {
    /// Assistant free-text content, if any. Present so the adapter can
    /// detect and reject prose returned instead of (or alongside) a tool
    /// call -- never inspected for meaning.
    let textContent: String?
    let toolCalls: [IntelligenceProviderToolCall]

    init(textContent: String? = nil, toolCalls: [IntelligenceProviderToolCall] = []) {
        self.textContent = textContent
        self.toolCalls = toolCalls
    }
}

/// One tool call as a provider/model response expressed it, with its
/// argument payload preserved exactly as received -- not decoded, not
/// reformatted, not repaired.
struct IntelligenceProviderToolCall: Equatable {
    let name: String
    let rawArguments: String
}
