import XCTest
@testable import GooglyMac

final class AssistantCoreTests: XCTestCase {
    func testClaudeProxyRequestAndEndpoint() throws {
        let config = LLMConfiguration(format: .claude, baseURL: "http://localhost:6655/anthropic/v1", model: "claude-sonnet-4-6")
        let request = try AssistantCore.request(mode: .excel, context: "my notes", turns: [AssistantTurn(role: "user", text: "hello")], configuration: config, key: "test-placeholder")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:6655/anthropic/v1/messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-placeholder")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-placeholder")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(body["max_tokens"] as? Int, 1200)
        XCTAssertNil(body["input"])
        XCTAssertEqual((body["messages"] as? [[String: Any]])?.count, 1)
        XCTAssertFalse(config.isDirectOpenAI)
    }

    func testEndpointNormalizationAndInvalidURLs() throws {
        for base in ["http://localhost:6655", "http://localhost:6655/v1/", "http://localhost:6655/v1/messages"] {
            XCTAssertEqual(try LLMConfiguration(format: .claude, baseURL: base, model: "test").endpoint().absoluteString,
                           "http://localhost:6655/v1/messages")
        }
        for base in ["http://remote.example", "https://user:password@example.com", "https://example.com?key=test", "garbage"] {
            XCTAssertThrowsError(try LLMConfiguration(baseURL: base).endpoint())
        }
    }

    func testClaudeAndChatReplyParsing() throws {
        let claude = Data(#"{"stop_reason":"end_turn","content":[{"type":"text","text":"Hello"}],"usage":{"input_tokens":12,"output_tokens":8}}"#.utf8)
        XCTAssertEqual(try AssistantCore.parseReply(claude, format: .claude).tokens, 20)
        let chat = Data(#"{"choices":[{"finish_reason":"stop","message":{"content":"Hello"}}],"usage":{"total_tokens":20}}"#.utf8)
        XCTAssertEqual(try AssistantCore.parseReply(chat, format: .chat).text, "Hello")
        let truncated = Data(#"{"stop_reason":"max_tokens","content":[{"type":"text","text":"Partial"}]}"#.utf8)
        XCTAssertThrowsError(try AssistantCore.parseReply(truncated, format: .claude))
    }

    func testQuotaTakesPrecedenceOverRateLimitType() {
        let data = Data(#"{"error":{"code":"insufficient_quota","type":"rate_limit_error","message":"private details"}}"#.utf8)
        guard case .quota = AssistantCore.failure(status: 429, data: data) else { return XCTFail("Expected quota") }
        XCTAssertFalse(AssistantCore.failure(status: 429, data: data).localizedDescription.contains("private details"))
    }

    func testTemporaryAndUnknownRateLimits() {
        let data = Data(#"{"error":{"type":"rate_limit_error","code":"slow_down"}}"#.utf8)
        guard case .rateLimit = AssistantCore.failure(status: 429, data: data) else { return XCTFail("Expected temporary limit") }
        guard case .unknown429 = AssistantCore.failure(status: 429, data: Data()) else { return XCTFail("Expected unknown 429") }
        guard case .http(401) = AssistantCore.failure(status: 401, data: data) else { return XCTFail("Expected 401") }
    }

    func testRequestLimitsAndNoServerStorage() throws {
        let turns = (0..<20).map { AssistantTurn(role: $0 % 2 == 0 ? "user" : "assistant", text: String(repeating: "x", count: 5000)) }
        let bounded = AssistantCore.boundedHistory(turns)
        XCTAssertLessThanOrEqual(bounded.count, 8)
        XCTAssertLessThanOrEqual(bounded.reduce(0) { $0 + $1.text.count }, AssistantCore.historyLimit)
        XCTAssertEqual(bounded.last?.role, "assistant")
        let body = AssistantCore.requestBody(mode: .excel, context: String(repeating: "n", count: 9000), turns: turns)
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["max_output_tokens"] as? Int, 1200)
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        XCTAssertTrue((input.first?["content"] as? String ?? "").hasSuffix(String(repeating: "n", count: 6000)))
        XCTAssertTrue((body["instructions"] as? String ?? "").contains("Never invent data"))
    }

    func testContextCanBeOmitted() {
        let body = AssistantCore.requestBody(mode: .everyday, context: "", turns: [AssistantTurn(role: "user", text: "Hallo")])
        XCTAssertEqual((body["input"] as? [[String: Any]])?.count, 1)
    }

    func testParseOnlyOutputTextAndUsage() throws {
        let data = Data(#"{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"Hallo"},{"type":"other","text":"ignore"}]}],"usage":{"total_tokens":42}}"#.utf8)
        let reply = try AssistantCore.parseReply(data)
        XCTAssertEqual(reply.text, "Hallo")
        XCTAssertEqual(reply.tokens, 42)
    }

    func testIncompleteAndEmptyAnswersAreRejected() {
        for json in [#"{"status":"incomplete","output":[]}"#, #"{"status":"completed","output":[]}"#] {
            XCTAssertThrowsError(try AssistantCore.parseReply(Data(json.utf8)))
        }
    }

    func testMissingKeyDoesNotMakeNetworkRequest() async {
        do {
            _ = try await AssistantCore.ask(mode: .everyday, context: "", turns: [], key: nil)
            XCTFail("Expected missing key error")
        } catch { XCTAssertTrue(error is AssistantCore.Failure) }
    }
}
