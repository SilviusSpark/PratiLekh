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

        static let defaultBaseURL = "http://localhost:11434/v1"
    }

    /// Calls the configured local provider once, non-streaming, with
    /// `tool_choice: "auto"` (via `LLMClient`'s existing default when tools
    /// are present) and temperature 0 -- chosen for run-to-run
    /// reproducibility of this diagnostic harness, not as model tuning.
    static func propose(normalizedText: String, config: LocalProviderConfig) async -> Result<LLMClient.Response, IntelligenceHarnessFailure> {
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
        do {
            return .success(try await LLMClient.shared.call(llmConfig))
        } catch {
            return .failure(IntelligenceHarnessFailure("LLMClient error: \(error)"))
        }
    }
}
