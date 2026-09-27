import Foundation

/// The bridge from a real `LLMClient.Response` into the generic,
/// provider-independent `IntelligenceProviderResponse` shape. Deliberately
/// isolated to its own file: everything else under
/// `Sources/Fluid/Intelligence/Generation/` has no dependency on `LLMClient`
/// and stays compilable/testable via this repo's lightweight standalone
/// convention (`scripts/test_intelligence_safety.sh`) with no app-bundle or
/// Xcode-hosted-target dependency; `LLMClient.swift` itself pulls in much of
/// the app's dependency graph and cannot join that standalone build, so this
/// one bridging function -- and only this function -- lives where the full
/// app build already needs to compile it.
extension IntelligenceProviderResponse {
    /// Bridges an already-obtained `LLMClient.Response` into this generic,
    /// provider-independent shape, carrying each tool call's raw argument
    /// text through **unchanged** -- no reserialization from a decoded
    /// dictionary, which could never recover a duplicate key or a
    /// float-vs-integer distinction lost in decoding. This performs no
    /// network call and invokes no model; it only reshapes a value already
    /// in hand, which is exactly what makes it safe to exercise with a
    /// synthetically constructed `LLMClient.Response` in tests, with no
    /// live `LLMClient` call anywhere in this milestone.
    init(bridgingFrom response: LLMClient.Response) {
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            textContent: text.isEmpty ? nil : response.content,
            toolCalls: response.toolCalls.map { IntelligenceProviderToolCall(name: $0.name, rawArguments: $0.rawArguments) }
        )
    }
}
