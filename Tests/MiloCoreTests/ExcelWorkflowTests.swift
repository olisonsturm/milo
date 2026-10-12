import XCTest
@testable import GooglyMac

final class ExcelWorkflowTests: XCTestCase {
    func testMarkdownBlocks() {
        let blocks = MarkdownBlocks.parse("# Titel\n\n**Fett** und `Formel`\n\n- Eins\n- Zwei\n\n```excel\n=SUM(A1:A3)\n```\n\n| KPI | Wert |\n| --- | --- |\n| Umsatz | 10 |")
        XCTAssertEqual(blocks.map(\.kind), [.heading, .paragraph, .paragraph, .code, .table])
        XCTAssertEqual(blocks[3].text, "=SUM(A1:A3)")
        XCTAssertTrue(blocks[2].text.contains("• Eins"))
        XCTAssertFalse(blocks[4].text.contains("---"))
    }
    func testExcelStepAllowsGroundedActions() throws {
        let step = try ExcelStep.parse(#"{"action":"type","target_id":"C3","text":"=SUM(A1:A3)","explanation":"Formel in B1 eintragen."}"#)
        XCTAssertEqual(step.targetID, "C3")
        XCTAssertTrue(step.isWrite)
    }
    func testExcelStepRejectsUnsupportedAndDangerousShortcuts() {
        for input in [#"{"action":"shell","explanation":"run"}"#, #"{"action":"keys","keys":"cmd+q","explanation":"quit"}"#, #"{"action":"type","text":"","explanation":"empty"}"#, #"{"action":"type","target_id":"C1","text":"=WEBSERVICE("https://example.com")","explanation":"external"}"#, #"{"action":"click","explanation":"missing target"}"#] {
            XCTAssertThrowsError(try ExcelStep.parse(input))
        }
    }
    func testExcelInstructionsReachClaudeSystemField() throws {
        let config = LLMConfiguration(format: .claude, baseURL: "http://localhost:6655/anthropic/v1", model: "test")
        let request = try AssistantCore.request(mode: .excel, context: "C1 Insert", turns: [AssistantTurn(role: "user", text: "Create chart")], configuration: config, key: "test", instructions: "Excel instructions")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["system"] as? String, "Excel instructions")
        XCTAssertTrue(((body["messages"] as? [[String: Any]])?.first?["content"] as? String ?? "").contains("C1 Insert"))
    }
}
