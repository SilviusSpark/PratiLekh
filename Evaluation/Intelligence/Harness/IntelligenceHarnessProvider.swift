import Foundation

/// Intelligence V1.17 -- Controlled Local-Model Integration Harness.
///
/// The only file in this harness that links `LLMClient` and therefore the
/// only place a real local model is ever called. Builds the exact request
/// for one sample's legal-normalized text using the frozen V1.7 model-facing
/// contract (`ModelFacingGenerationContract`) and the existing, unmodified
/// `LLMClient` -- no new transport, no new retry/timeout logic, nothing
/// Intelligence-specific added to `LLMClient` itself.
///
/// Fail-closed by construction: every thrown error is caught here and
/// returned as `.failure`; `IntelligenceHarnessRunner` never calls any
/// Intelligence/composition code when this returns `.failure` -- a
/// provider/runtime failure therefore never reaches Intelligence at all.
enum IntelligenceHarnessProvider {
    struct LocalProviderConfig {
        let baseURL: String
        let model: String
        let apiKey: String
        let timeoutSeconds: TimeInterval?
        /// `nil` keeps `LLMClient`'s own default (3 attempts on transient network errors) --
        /// the V1.17 behavior, unchanged. V1.23 sets this to 1 explicitly: its frozen retry
        /// policy is exactly one attempt per corpus entry, and `LLMClient` would otherwise
        /// silently re-submit a timed-out/dropped request up to twice more.
        var maxRetries: Int?

        static let defaultBaseURL = "http://localhost:11434/v1"
    }

    /// Calls the configured local provider once, non-streaming, with
    /// `tool_choice: "auto"` (via `LLMClient`'s existing default when tools
    /// are present) and temperature 0 -- chosen for run-to-run
    /// reproducibility of this diagnostic harness, not as model tuning.
    static func propose(normalizedText: String, config: LocalProviderConfig) async -> Result<LLMClient.Response, IntelligenceHarnessFailure> {
        let llmConfig = self.makeLLMConfig(normalizedText: normalizedText, config: config)
        do {
            return .success(try await LLMClient.shared.call(llmConfig))
        } catch {
            return .failure(IntelligenceHarnessFailure("LLMClient error: \(error)"))
        }
    }

    /// The exact request configuration `propose` sends, factored out so it can be
    /// inspected without a network call (V1.23's request-freeze test).
    static func makeLLMConfig(normalizedText: String, config: LocalProviderConfig) -> LLMClient.Config {
        let messages: [[String: Any]] = [
            ["role": "system", "content": ModelFacingGenerationContract.instructions],
            ["role": "user", "content": normalizedText],
        ]
        var llmConfig = LLMClient.Config(
            messages: messages,
            model: config.model,
            baseURL: config.baseURL,
            apiKey: config.apiKey,
            streaming: false,
            tools: [ModelFacingGenerationContract.toolDefinition],
            temperature: 0
        )
        if let timeoutSeconds = config.timeoutSeconds {
            llmConfig.timeoutSeconds = timeoutSeconds
        }
        if let maxRetries = config.maxRetries {
            llmConfig.maxRetries = maxRetries
        }
        return llmConfig
    }
}
