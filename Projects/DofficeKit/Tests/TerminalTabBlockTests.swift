import XCTest
@testable import DofficeKit

final class TerminalTabBlockTests: XCTestCase {

    func testAppendBlockReturnsBlock() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        let block = tab.appendBlock(.text, content: "Hello")
        XCTAssertEqual(block.content, "Hello")
        XCTAssertEqual(tab.blocks.count, 1)
    }

    func testAppendMultipleBlocks() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        _ = tab.appendBlock(.text, content: "First")
        _ = tab.appendBlock(.thought, content: "Thinking...")
        _ = tab.appendBlock(.text, content: "Second")
        XCTAssertEqual(tab.blocks.count, 3)
    }

    func testAppendUserPromptBlock() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        _ = tab.appendBlock(.userPrompt, content: "Fix the bug")
        XCTAssertEqual(tab.blocks.count, 1)
        if case .userPrompt = tab.blocks[0].blockType {
            // OK
        } else {
            XCTFail("Expected userPrompt block type")
        }
    }

    func testIsAutomationTabDefault() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        XCTAssertFalse(tab.isAutomationTab)
    }

    func testIsAutomationTabWhenAutomationSource() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.automationSourceTabId = "parent-tab-id"
        XCTAssertTrue(tab.isAutomationTab)
    }

    func testProviderProperty() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "Worker", workerColor: .blue)
        tab.selectedModel = .sonnet
        XCTAssertEqual(tab.provider, .claude)
        tab.selectedModel = .gpt54
        XCTAssertEqual(tab.provider, .codex)
        tab.selectedModel = .gemini25Pro
        XCTAssertEqual(tab.provider, .gemini)
    }
}
