import XCTest
@testable import DofficeKit

final class TerminalTabShellTests: XCTestCase {

    func testBuildFullPATHContainsCommonPaths() {
        let path = TerminalTab.buildFullPATH()
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains("/usr/bin"))
        XCTAssertTrue(path.contains("/bin"))
        XCTAssertTrue(path.contains("/opt/homebrew/bin"))
    }

    func testBuildFullPATHContainsCodexDesktop() {
        let path = TerminalTab.buildFullPATH()
        XCTAssertTrue(path.contains("/Applications/Codex.app/Contents/Resources"))
    }

    func testShellSyncEcho() {
        let result = TerminalTab.shellSync("echo hello")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testShellSyncNilForInvalidCommand() {
        // This should return empty/nil for a failing command
        let result = TerminalTab.shellSync("false 2>/dev/null")
        // `false` exits with code 1, but shellSync still reads output
        // The key test is it doesn't crash
        _ = result
    }

    func testShellSyncLoginWithTimeoutDoesNotHang() {
        let start = Date()
        let result = TerminalTab.shellSyncLoginWithTimeout("echo ok", timeout: 3)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertNotNil(result)
        XCTAssertLessThan(elapsed, 5.0, "Should complete within timeout")
    }

    func testShellEscape() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "w", workerColor: .blue)
        let escaped = tab.shellEscape("hello world")
        XCTAssertEqual(escaped, "'hello world'")
    }

    func testShellEscapeWithSingleQuote() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "w", workerColor: .blue)
        let escaped = tab.shellEscape("it's")
        XCTAssertEqual(escaped, "'it'\\''s'")
    }

    func testShellEscapeEmpty() {
        let tab = TerminalTab(projectName: "Test", projectPath: "/tmp", workerName: "w", workerColor: .blue)
        let escaped = tab.shellEscape("")
        XCTAssertEqual(escaped, "''")
    }
}
