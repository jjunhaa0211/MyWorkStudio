import XCTest
@testable import DofficeKit

final class AgentEnumTests: XCTestCase {

    // MARK: - AgentModel.detect

    func testDetectSonnet() {
        XCTAssertEqual(AgentModel.detect(from: "claude-sonnet-4"), .sonnet)
        XCTAssertEqual(AgentModel.detect(from: "Sonnet"), .sonnet)
    }

    func testDetectOpus() {
        XCTAssertEqual(AgentModel.detect(from: "claude-opus-4"), .opus)
    }

    func testDetectGemini() {
        XCTAssertEqual(AgentModel.detect(from: "gemini-2.5-pro-preview"), .gemini25Pro)
    }

    func testDetectReturnsNilForUnknown() {
        XCTAssertNil(AgentModel.detect(from: "unknown-model"))
        XCTAssertNil(AgentModel.detect(from: ""))
    }

    // MARK: - Provider-Model Mapping

    func testClaudeModelsReturnClaudeProvider() {
        for model in [AgentModel.opus, .sonnet, .haiku] {
            XCTAssertEqual(model.provider, .claude, "\(model) should map to claude provider")
        }
    }

    func testCodexModelsReturnCodexProvider() {
        for model in [AgentModel.gpt54, .gpt54Mini, .gpt53Codex, .gpt52Codex, .gpt52, .gpt51CodexMax, .gpt51CodexMini] {
            XCTAssertEqual(model.provider, .codex, "\(model) should map to codex provider")
        }
    }

    func testGeminiModelsReturnGeminiProvider() {
        for model in [AgentModel.gemini25Pro, .gemini25Flash] {
            XCTAssertEqual(model.provider, .gemini, "\(model) should map to gemini provider")
        }
    }

    // MARK: - AgentProvider

    func testProviderDefaultModel() {
        XCTAssertEqual(AgentProvider.claude.defaultModel, .sonnet)
        XCTAssertEqual(AgentProvider.codex.defaultModel, .gpt54)
        XCTAssertEqual(AgentProvider.gemini.defaultModel, .gemini25Pro)
    }

    func testProviderModelsFilter() {
        let claudeModels = AgentProvider.claude.models
        XCTAssertTrue(claudeModels.contains(.sonnet))
        XCTAssertTrue(claudeModels.contains(.opus))
        XCTAssertFalse(claudeModels.contains(.gpt54))
    }

    // MARK: - EffortLevel

    func testEffortLevelAllCases() {
        XCTAssertEqual(EffortLevel.allCases.count, 4)
    }

    // MARK: - PermissionMode

    func testPermissionModeRawValues() {
        XCTAssertEqual(PermissionMode.bypassPermissions.rawValue, "bypassPermissions")
        XCTAssertEqual(PermissionMode.auto.rawValue, "auto")
    }

    // MARK: - BlockFilter

    func testBlockFilterDefault() {
        let filter = BlockFilter()
        XCTAssertFalse(filter.isActive)
    }

    func testBlockFilterWithSearchText() {
        let filter = BlockFilter(searchText: "hello")
        XCTAssertTrue(filter.isActive)
    }

    func testBlockFilterMatchesContent() {
        let filter = BlockFilter(searchText: "hello")
        let matchBlock = StreamBlock(type: .text, content: "say hello world")
        let noMatchBlock = StreamBlock(type: .text, content: "goodbye")
        XCTAssertTrue(filter.matches(matchBlock))
        XCTAssertFalse(filter.matches(noMatchBlock))
    }

    func testBlockFilterErrorOnly() {
        let filter = BlockFilter(onlyErrors: true)
        XCTAssertTrue(filter.isActive)
        let errorBlock = StreamBlock(type: .error(message: "fail"), content: "error happened")
        let textBlock = StreamBlock(type: .text, content: "normal text")
        XCTAssertTrue(filter.matches(errorBlock))
        XCTAssertFalse(filter.matches(textBlock))
    }
}
