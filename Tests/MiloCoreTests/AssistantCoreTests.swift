import XCTest
@testable import GooglyMac

final class AssistantCoreTests: XCTestCase {
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
