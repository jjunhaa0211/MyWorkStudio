import XCTest
@testable import DofficeKit

final class CLIInstallCheckerTests: XCTestCase {

    func testCheckerInitialState() {
        let checker = CLIInstallChecker(
            executableName: "zzz_absolutely_not_a_real_cli_12345",
            knownExecutablePaths: [],
            installHint: "Install with: brew install zzz"
        )
        // Before check, properties should be defaults
        XCTAssertFalse(checker.isInstalled)
        XCTAssertTrue(checker.version.isEmpty)
        XCTAssertTrue(checker.path.isEmpty)
    }

    func testClaudeInstallCheckerShared() {
        let checker = ClaudeInstallChecker.shared
        XCTAssertNotNil(checker)
        // Force check to verify it doesn't crash
        checker.check(force: true)
    }

    func testCodexInstallCheckerShared() {
        let checker = CodexInstallChecker.shared
        XCTAssertNotNil(checker)
        checker.check(force: true)
    }

    func testGeminiInstallCheckerShared() {
        let checker = GeminiInstallChecker.shared
        XCTAssertNotNil(checker)
        checker.check(force: true)
    }

    func testProviderInstallCheckerMapping() {
        // Each provider should return a valid checker
        XCTAssertTrue(AgentProvider.claude.installChecker === ClaudeInstallChecker.shared)
        XCTAssertTrue(AgentProvider.codex.installChecker === CodexInstallChecker.shared)
        XCTAssertTrue(AgentProvider.gemini.installChecker === GeminiInstallChecker.shared)
    }

    func testInstallCommandsMatchSupportedCLIs() {
        XCTAssertEqual(AgentProvider.claude.installCommand, "npm install -g @anthropic-ai/claude-code")
        XCTAssertEqual(AgentProvider.codex.installCommand, "npm install -g @openai/codex")
        XCTAssertEqual(AgentProvider.gemini.installCommand, "npm install -g @google/gemini-cli")
        XCTAssertTrue(AgentProvider.gemini.installDetail.contains("@google/gemini-cli"))
    }
}
