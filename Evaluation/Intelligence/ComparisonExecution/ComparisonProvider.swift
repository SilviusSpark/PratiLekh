import Foundation

/// Intelligence V1.29 (S2) -- Comparison Execution Tooling: the provider adapter.
///
/// The only execution-path file (with the live runner) that links `LLMClient`. Builds, per step, the request
/// configuration with the existing, unmodified `LLMClient` and the frozen contract text for the step's arm:
/// system = the arm's instructions, user = the step's `legalNormalized` text, tools = the unchanged V1.21 tool
/// definition, non-streaming, temperature 0, `tool_choice` auto (LLMClient's default with tools), 60 s limit,
/// `maxRetries` 1 (`LLMClient`'s own default is 3 and would silently re-submit a failed request). It adds no
/// transport, retry, timeout, sampling or per-model option; anything a candidate's params layer defaults is
/// recorded in the S1 artifact, never tuned. Every error is caught and returned as a recorded failure.
enum ComparisonProvider {
    static func makeLLMConfig(request: ComparisonProposerRequest) -> LLMClient.Config {
        var config = LLMClient.Config(
            messages: [
                ["role": "system", "content": request.instructions],
                ["role": "user", "content": request.userText],
            ],
            model: request.candidate.ollamaTag,
            baseURL: ComparisonExecutionPlan.baseURL,
            apiKey: "",
            streaming: false,
            tools: [ModelFacingGenerationContract.toolDefinition],
            temperature: ComparisonExecutionPlan.temperature
        )
        config.timeoutSeconds = ComparisonExecutionPlan.timeoutSeconds
        config.maxRetries = ComparisonExecutionPlan.maxRetries
        return config
    }

    /// The single provider call for one step. Never retried here or by the caller.
    static func proposer() -> ComparisonProposer {
        { request in
            do {
                let response = try await LLMClient.shared.call(self.makeLLMConfig(request: request))
                return .success(IntelligenceProviderResponse(bridgingFrom: response), thinking: response.thinking)
            } catch {
                return .failure("LLMClient error: \(error)")
            }
        }
    }
}
