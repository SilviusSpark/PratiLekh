import Foundation
@testable import PratiLekh_Debug
import XCTest

// Regression tests for https://github.com/altic-dev/FluidVoice/issues/295
// Ollama and compatible OpenAI-format providers treat an absent `stream` key as true.
// The fix is to always send the key explicitly, whether streaming or not.

@MainActor
final class LLMClientRequestBodyTests: XCTestCase {
    func testDictationStreamingFallbackSkipsTransportFailuresAndCancellation() {
        XCTAssertFalse(
            DictationStreamingFallbackPolicy.shouldRetryWithoutStreaming(
                after: LLMError.networkError(URLError(.notConnectedToInternet))
            )
        )
        XCTAssertFalse(
            DictationStreamingFallbackPolicy.shouldRetryWithoutStreaming(after: CancellationError())
        )
        XCTAssertFalse(
            DictationStreamingFallbackPolicy.shouldRetryWithoutStreaming(
                after: LLMError.invalidRequest("missing prompt")
            )
        )
    }

    func testDictationStreamingFallbackRetriesProtocolFailure() {
        XCTAssertTrue(
            DictationStreamingFallbackPolicy.shouldRetryWithoutStreaming(after: LLMError.invalidResponse)
        )
        XCTAssertTrue(
            DictationStreamingFallbackPolicy.shouldRetryWithoutStreaming(
                after: LLMError.httpError(400, "streaming unsupported")
            )
        )
    }

    private func config(streaming: Bool) -> LLMClient.Config {
        LLMClient.Config(
            messages: [["role": "user", "content": "hello"]],
            model: "llama3",
            baseURL: "http://localhost:11434/v1",
            apiKey: "",
            streaming: streaming
        )
    }

    private func config(messages: [[String: Any]]) -> LLMClient.Config {
        LLMClient.Config(
            messages: messages,
            model: "llama3",
            baseURL: "http://localhost:11434/v1",
            apiKey: "",
            streaming: false
        )
    }

    // MARK: - Chat Completions endpoint

    func testChatCompletionsBody_streamFalse_keyIsPresentAndFalse() {
        let body = LLMClient.shared.buildChatCompletionsBody(self.config(streaming: false))
        XCTAssertNotNil(body["stream"], "stream key must be present when streaming=false — absent key breaks Ollama-compatible providers")
        XCTAssertEqual(body["stream"] as? Bool, false)
    }

    func testChatCompletionsBody_streamTrue_keyIsPresentAndTrue() {
        let body = LLMClient.shared.buildChatCompletionsBody(self.config(streaming: true))
        XCTAssertEqual(body["stream"] as? Bool, true)
    }

    // MARK: - Responses endpoint

    func testResponsesBody_streamFalse_keyIsPresentAndFalse() {
        let body = LLMClient.shared.buildResponsesBody(self.config(streaming: false))
        XCTAssertNotNil(body["stream"], "stream key must be present when streaming=false")
        XCTAssertEqual(body["stream"] as? Bool, false)
    }

    func testResponsesBody_streamTrue_keyIsPresentAndTrue() {
        let body = LLMClient.shared.buildResponsesBody(self.config(streaming: true))
        XCTAssertEqual(body["stream"] as? Bool, true)
    }

    // MARK: - Dictation custom prompt resolution

    func testCustomPromptOnly_omitsBasePromptFromEffectivePromptAndRequestBody() {
        self.withPromptSettingsRestored {
            let settings = SettingsStore.shared
            self.resetPromptSettings(settings)

            let profile = SettingsStore.DictationPromptProfile(
                name: "Gemma",
                prompt: "Clean this transcript. Return corrected text only.",
                mode: .dictate
            )
            settings.dictationPromptProfiles = [profile]
            settings.selectedDictationPromptID = profile.id
            settings.sendCustomPromptOnly = true

            let prompt = settings.effectiveDictationSystemPrompt(for: .primary)
            XCTAssertEqual(prompt, profile.prompt)

            let userMessage = SettingsStore.renderDictationUserMessage(
                promptText: prompt,
                transcript: "hello comma world"
            )
            let body = LLMClient.shared.buildChatCompletionsBody(self.config(messages: [["role": "user", "content": userMessage]]))
            let messageContents = self.chatMessageContents(from: body)

            XCTAssertFalse(messageContents.contains { $0.contains(Self.basePromptMarker) })
            XCTAssertTrue(messageContents.contains { $0.contains(profile.prompt) })
        }
    }

    func testCustomPromptOnly_defaultFalsePrependsBasePrompt() {
        self.withPromptSettingsRestored {
            let settings = SettingsStore.shared
            self.resetPromptSettings(settings)

            let profile = SettingsStore.DictationPromptProfile(
                name: "Back Compat",
                prompt: "Use my cleanup rules.",
                mode: .dictate
            )
            settings.dictationPromptProfiles = [profile]
            settings.selectedDictationPromptID = profile.id
            settings.sendCustomPromptOnly = false

            XCTAssertEqual(
                settings.effectiveDictationSystemPrompt(for: .primary),
                SettingsStore.combineBasePrompt(for: .dictate, with: profile.prompt)
            )
        }
    }

    func testCustomPromptOnly_defaultPromptStillUsesBuiltInPrompt() {
        self.withPromptSettingsRestored {
            let settings = SettingsStore.shared
            self.resetPromptSettings(settings)

            settings.sendCustomPromptOnly = true

            let prompt = settings.effectiveDictationSystemPrompt(for: .primary)
            XCTAssertFalse(prompt.isEmpty)
            XCTAssertEqual(prompt, SettingsStore.defaultSystemPromptText(for: .dictate))
        }
    }

    func testCustomPromptOnly_omitsBasePromptForAppBoundCustomPrompt() {
        self.withPromptSettingsRestored {
            let settings = SettingsStore.shared
            self.resetPromptSettings(settings)

            let global = SettingsStore.DictationPromptProfile(
                name: "Global",
                prompt: "Global cleanup rules.",
                mode: .dictate
            )
            let mail = SettingsStore.DictationPromptProfile(
                name: "Mail",
                prompt: "Mail cleanup rules only.",
                mode: .dictate
            )

            settings.dictationPromptProfiles = [global, mail]
            settings.selectedDictationPromptID = nil
            settings.appPromptBindings = [
                SettingsStore.AppPromptBinding(
                    mode: .dictate,
                    appBundleID: "com.apple.mail",
                    appName: "Mail",
                    promptID: mail.id
                ),
            ]
            settings.sendCustomPromptOnly = true

            XCTAssertEqual(
                settings.effectiveDictationSystemPrompt(for: .primary, appBundleID: "com.apple.mail"),
                mail.prompt
            )
            XCTAssertEqual(
                settings.effectiveDictationSystemPrompt(for: .primary, appBundleID: "com.apple.notes"),
                SettingsStore.defaultSystemPromptText(for: .dictate)
            )
        }
    }

    func testCustomPromptOnly_shortcutProfileOverrideOmitsBasePrompt() {
        self.withPromptSettingsRestored {
            let settings = SettingsStore.shared
            self.resetPromptSettings(settings)

            let profile = SettingsStore.DictationPromptProfile(
                name: "Cleaner",
                prompt: "Normalize the transcript. Output only the cleaned text.",
                mode: .dictate
            )
            settings.dictationPromptProfiles = [profile]
            settings.sendCustomPromptOnly = true

            XCTAssertEqual(
                settings.shortcutOverrideSystemPrompt(for: profile),
                profile.prompt
            )

            settings.sendCustomPromptOnly = false
            XCTAssertEqual(
                settings.shortcutOverrideSystemPrompt(for: profile),
                SettingsStore.combineBasePrompt(for: .dictate, with: profile.prompt)
            )
        }
    }

    private static let basePromptMarker = "You are a voice-to-text dictation cleaner"

    private func resetPromptSettings(_ settings: SettingsStore) {
        settings.dictationPromptProfiles = []
        settings.appPromptBindings = []
        settings.selectedDictationPromptID = nil
        settings.isDictationPromptOff = false
        settings.dictationPromptRoutingScope = .allApps
        settings.defaultDictationPromptOverride = nil
        settings.sendCustomPromptOnly = false
    }

    private func withPromptSettingsRestored(run: () -> Void) {
        let settings = SettingsStore.shared
        let profiles = settings.dictationPromptProfiles
        let appBindings = settings.appPromptBindings
        let selectedDictationPromptID = settings.selectedDictationPromptID
        let isDictationPromptOff = settings.isDictationPromptOff
        let dictationPromptRoutingScope = settings.dictationPromptRoutingScope
        let defaultDictationPromptOverride = settings.defaultDictationPromptOverride
        let sendCustomPromptOnly = settings.sendCustomPromptOnly

        defer {
            settings.dictationPromptProfiles = profiles
            settings.appPromptBindings = appBindings
            settings.selectedDictationPromptID = selectedDictationPromptID
            settings.isDictationPromptOff = isDictationPromptOff
            settings.dictationPromptRoutingScope = dictationPromptRoutingScope
            settings.defaultDictationPromptOverride = defaultDictationPromptOverride
            settings.sendCustomPromptOnly = sendCustomPromptOnly
        }

        run()
    }

    private func chatMessageContents(from body: [String: Any]) -> [String] {
        guard let messages = body["messages"] as? [[String: Any]] else { return [] }
        return messages.compactMap { $0["content"] as? String }
    }
}

@MainActor
final class LLMClientStreamingTests: XCTestCase {
    // Regression test for https://github.com/altic-dev/FluidVoice/issues/445
    func testReasoningContentDeltaPreservesChunkedToolCall() async throws {
        let client = makeClient()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "Show the working directory"]],
            model: "qwen3.5:9b",
            baseURL: "https://issue-445.test/v1",
            apiKey: "",
            streaming: true
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5

        let response = try await client.call(config)

        XCTAssertEqual(response.thinking, "I should inspect the current directory.")
        XCTAssertEqual(response.content, "")
        XCTAssertEqual(response.toolCalls.count, 1)
        XCTAssertEqual(response.toolCalls.first?.id, "call_445")
        XCTAssertEqual(response.toolCalls.first?.name, "run_terminal")
        XCTAssertEqual(response.toolCalls.first?.getString("command"), "pwd")
    }

    func testTagBasedReasoningStillPreservesChunkedToolCall() async throws {
        let client = makeClient()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "Show the working directory"]],
            model: "qwen-thinking",
            baseURL: "https://issue-445.test/tag-parser/v1",
            apiKey: "",
            streaming: true
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5

        let response = try await client.call(config)

        XCTAssertEqual(response.thinking, "Inspecting.")
        XCTAssertEqual(response.content, "Ready.")
        XCTAssertEqual(response.toolCalls.count, 1)
        XCTAssertEqual(response.toolCalls.first?.id, "call_tag_control")
        XCTAssertEqual(response.toolCalls.first?.name, "run_terminal")
        XCTAssertEqual(response.toolCalls.first?.getString("command"), "pwd")
    }

    // Raw-argument preservation, added for the Intelligence V1.2 integration
    // gap: `LLMClient.ToolCall.rawArguments` must carry the exact original
    // argument text through the streaming path, never a reconstruction from
    // the decoded `arguments` dictionary.
    func testRawArgumentsPreserveExactTextIncludingUnusualSpacing() async throws {
        let client = makeClient()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "propose edits"]],
            model: "qwen3.5:9b",
            baseURL: "https://issue-445.test/raw-preservation/v1",
            apiKey: "",
            streaming: true
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5

        let response = try await client.call(config)

        XCTAssertEqual(response.toolCalls.count, 1)
        // Unusual (but valid) spacing that a decode-then-reserialize round
        // trip would normalize away -- surviving exactly proves this is the
        // original text, not a reconstruction.
        XCTAssertEqual(response.toolCalls.first?.rawArguments, "{\"schemaVersion\" : 1, \"proposals\" : []}")
    }

    func testRawArgumentsPreserveDuplicateKeyForV11Rejection() async throws {
        let client = makeClient()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "propose edits"]],
            model: "qwen3.5:9b",
            baseURL: "https://issue-445.test/raw-duplicate-key/v1",
            apiKey: "",
            streaming: true
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5

        let response = try await client.call(config)
        XCTAssertEqual(response.toolCalls.count, 1)
        // The decoded dictionary can never show this -- Foundation silently
        // resolves the duplicate before Codable/JSONSerialization callers
        // ever see it (verified in the V1.1 milestone). Only rawArguments
        // still contains the literal duplicate substring.
        XCTAssertEqual(
            response.toolCalls.first?.rawArguments,
            "{\"schemaVersion\":1,\"schemaVersion\":999,\"proposals\":[]}"
        )

        let intelligenceResponse = IntelligenceProviderResponse(bridgingFrom: response)
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: intelligenceResponse) {
        case .success:
            XCTFail("a duplicate-key payload must be rejected, not silently resolved")
        case let .failure(failure):
            XCTAssertEqual(failure, .transportParseFailure(.duplicateKey("schemaVersion")))
        }
    }

    func testRawArgumentsPreserveWholeNumberFloatForV11Rejection() async throws {
        let client = makeClient()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "propose edits"]],
            model: "qwen3.5:9b",
            baseURL: "https://issue-445.test/raw-float-schema-version/v1",
            apiKey: "",
            streaming: true
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5

        let response = try await client.call(config)
        XCTAssertEqual(response.toolCalls.count, 1)
        XCTAssertEqual(response.toolCalls.first?.rawArguments, "{\"schemaVersion\":1.0,\"proposals\":[]}")

        let intelligenceResponse = IntelligenceProviderResponse(bridgingFrom: response)
        switch IntelligenceProviderResponseAdapter.extractProposalBatch(from: intelligenceResponse) {
        case .success:
            XCTFail("a whole-number float in an integer contract field must be rejected, not silently coerced")
        case let .failure(failure):
            XCTAssertEqual(failure, .transportParseFailure(.invalidFieldType("schemaVersion")))
        }
    }

    // The 3 tests above all exercise the streaming Chat Completions path,
    // where `rawArguments` is assembled by accumulating SSE deltas. The
    // non-streaming path is architecturally distinct -- a single already-
    // complete JSON response body, no delta accumulation -- so this test
    // covers that second family directly, without expanding into a full
    // matrix across all 4 construction sites.
    func testRawArgumentsPreserveExactTextNonStreamingChatCompletions() async throws {
        let client = makeClient()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "propose edits"]],
            model: "qwen3.5:9b",
            baseURL: "https://issue-445.test/raw-preservation-nonstreaming/v1",
            apiKey: "",
            streaming: false
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5

        let response = try await client.call(config)

        XCTAssertEqual(response.toolCalls.count, 1)
        XCTAssertEqual(response.toolCalls.first?.rawArguments, "{\"schemaVersion\" : 1, \"proposals\" : []}")
    }

    func testStreamingDecodeAndCallbacksStayOffMainThread() async throws {
        let client = self.makeClient()
        let probe = LLMCallbackThreadProbe()
        var config = LLMClient.Config(
            messages: [["role": "user", "content": "Keep UI responsive"]],
            model: "qwen-thinking",
            baseURL: "https://issue-445.test/tag-parser/v1",
            apiKey: "",
            streaming: true
        )
        config.maxRetries = 1
        config.timeoutSeconds = 5
        config.onContentChunk = { _ in probe.recordCallback() }

        let response = try await client.call(config)

        XCTAssertEqual(response.content, "Ready.")
        XCTAssertGreaterThan(probe.callbackCount, 0)
        XCTAssertFalse(probe.sawMainThread)
    }

    private func makeClient() -> LLMClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Issue445StreamURLProtocol.self]
        return LLMClient(session: URLSession(configuration: configuration))
    }
}

private final nonisolated class LLMCallbackThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCallbackCount = 0
    private var recordedMainThreadCallback = false

    var callbackCount: Int {
        self.lock.withLock { self.recordedCallbackCount }
    }

    var sawMainThread: Bool {
        self.lock.withLock { self.recordedMainThreadCallback }
    }

    func recordCallback() {
        self.lock.withLock {
            self.recordedCallbackCount += 1
            self.recordedMainThreadCallback = self.recordedMainThreadCallback || Thread.isMainThread
        }
    }
}

private class Issue445StreamURLProtocol: URLProtocol {
    // The empty-string `content` fields are load-bearing: HEAD skips tool calls only
    // when `delta["content"] as? String` succeeds, so replacing them with null defangs the regression.
    private static let separateReasoningFixture = #"""
    data: {"choices":[{"index":0,"delta":{"reasoning_content":"I should inspect the current directory.","content":"","tool_calls":[{"index":0,"id":"call_445","type":"function","function":{"name":"run_terminal","arguments":"{\"command\":\""}}]}}]}

    data: {"choices":[{"index":0,"delta":{"content":"","tool_calls":[{"index":0,"function":{"arguments":"pwd\"}"}}]},"finish_reason":"tool_calls"}]}

    data: [DONE]

    """#

    private static let tagParserFixture = #"""
    data: {"choices":[{"index":0,"delta":{"content":"<think>Inspecting.</think>Ready.","tool_calls":[{"index":0,"id":"call_tag_control","type":"function","function":{"name":"run_terminal","arguments":"{\"command\":\""}}]}}]}

    data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"pwd\"}"}}]},"finish_reason":"tool_calls"}]}

    data: [DONE]

    """#

    // The three fixtures below back the Intelligence V1.2 raw-argument
    // integration-gap tests: they prove `LLMClient.ToolCall.rawArguments`
    // preserves the provider's exact original argument text (unusual
    // spacing, a duplicate JSON key, a whole-number float) all the way
    // through the real streaming decode path, not merely in a synthetic
    // Swift value constructed by a test.
    private static let rawPreservationFixture = #"""
    data: {"choices":[{"index":0,"delta":{"content":"","tool_calls":[{"index":0,"id":"call_raw","type":"function","function":{"name":"propose_transcript_edits","arguments":"{\"schemaVersion\" : 1, "}}]}}]}

    data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"proposals\" : []}"}}]},"finish_reason":"tool_calls"}]}

    data: [DONE]

    """#

    private static let duplicateKeyRawArgumentsFixture = #"""
    data: {"choices":[{"index":0,"delta":{"content":"","tool_calls":[{"index":0,"id":"call_dup","type":"function","function":{"name":"propose_transcript_edits","arguments":"{\"schemaVersion\":1,\"schemaVersion\":999,"}}]}}]}

    data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"proposals\":[]}"}}]},"finish_reason":"tool_calls"}]}

    data: [DONE]

    """#

    private static let floatSchemaVersionRawArgumentsFixture = #"""
    data: {"choices":[{"index":0,"delta":{"content":"","tool_calls":[{"index":0,"id":"call_float","type":"function","function":{"name":"propose_transcript_edits","arguments":"{\"schemaVersion\":1.0,"}}]}}]}

    data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"proposals\":[]}"}}]},"finish_reason":"tool_calls"}]}

    data: [DONE]

    """#

    // Plain (non-SSE) Chat Completions body for the non-streaming
    // raw-argument-preservation test: a single already-complete JSON
    // response, not an accumulated stream of deltas.
    private static let nonStreamingRawPreservationFixture = #"""
    {"choices":[{"message":{"content":"","tool_calls":[{"id":"call_raw_ns","type":"function","function":{"name":"propose_transcript_edits","arguments":"{\"schemaVersion\" : 1, \"proposals\" : []}"}}]}}]}
    """#

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "issue-445.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let fixture: String
        if url.path.contains("tag-parser") {
            fixture = Self.tagParserFixture
        } else if url.path.contains("raw-duplicate-key") {
            fixture = Self.duplicateKeyRawArgumentsFixture
        } else if url.path.contains("raw-float-schema-version") {
            fixture = Self.floatSchemaVersionRawArgumentsFixture
        } else if url.path.contains("raw-preservation-nonstreaming") {
            fixture = Self.nonStreamingRawPreservationFixture
        } else if url.path.contains("raw-preservation") {
            fixture = Self.rawPreservationFixture
        } else {
            fixture = Self.separateReasoningFixture
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(fixture.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
