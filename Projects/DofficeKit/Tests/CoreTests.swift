import XCTest
@testable import DofficeKit
import DesignSystem

final class CoreTests: XCTestCase {

    func testBuildFullPATH() {
        let path = TerminalTab.buildFullPATH()
        XCTAssertFalse(path.isEmpty, "PATH should not be empty")
        XCTAssertTrue(path.contains("/usr/bin"), "PATH should contain /usr/bin")
        XCTAssertTrue(path.contains("/bin"), "PATH should contain /bin")
        XCTAssertTrue(
            path.contains("/Applications/Codex.app/Contents/Resources"),
            "PATH should include the Codex Desktop CLI bundle directory"
        )
    }

    func testCodexMissingRolloutResumeErrorDetection() {
        XCTAssertTrue(
            TerminalTab.isCodexMissingRolloutResumeError(
                "Error: thread/resume: thread/resume failed: no rollout found for thread id 9c8598ab-fa1a-4d59-9cf1-b511f53b8a78"
            )
        )
        XCTAssertFalse(
            TerminalTab.isCodexMissingRolloutResumeError(
                "Error: thread/resume: permission denied"
            )
        )
    }

    func testIgnorableCodexStderrDetection() {
        XCTAssertTrue(
            TerminalTab.isIgnorableCodexStderr(
                "2026-03-31T07:17:04.359854Z ERROR codex_core::models_manager::manager: failed to refresh available models: timeout waiting for child process to exit"
            )
        )
        XCTAssertTrue(
            TerminalTab.isIgnorableCodexStderr(
                "2026-03-31T07:17:50.127368Z  WARN codex_core::shell_snapshot: Failed to delete shell snapshot at \"/tmp/foo\": Os { code: 2, kind: NotFound, message: \"No such file or directory\" }"
            )
        )
        XCTAssertFalse(
            TerminalTab.isIgnorableCodexStderr(
                "Error: thread/resume: thread/resume failed: no rollout found for thread id 9c8598ab-fa1a-4d59-9cf1-b511f53b8a78"
            )
        )
    }

    func testGitDataParserSanitizePath() {
        // Test that dangerous characters are stripped
        let safe = GitDataParser.sanitizePath("normal/path.swift")
        XCTAssertEqual(safe, "normal/path.swift")

        let dangerous = GitDataParser.sanitizePath("path;rm -rf /")
        XCTAssertFalse(dangerous.contains(";"), "Semicolons should be stripped")
    }

    func testTokenTrackerInitialization() {
        let tracker = TokenTracker.shared
        XCTAssertNotNil(tracker, "TokenTracker should initialize")
        XCTAssertGreaterThanOrEqual(tracker.history.count, 0, "History should be accessible")
    }

    func testClaudeModelDetect() {
        XCTAssertEqual(ClaudeModel.detect(from: "opus"), .opus)
        XCTAssertEqual(ClaudeModel.detect(from: "sonnet"), .sonnet)
        XCTAssertEqual(ClaudeModel.detect(from: "haiku"), .haiku)
        XCTAssertNil(ClaudeModel.detect(from: "unknown"))
    }

    func testAbsHashValueSafety() {
        // Verify the UInt bitPattern approach doesn't crash on Int.min
        let hash = Int.min
        let safeIndex = Int(UInt(bitPattern: hash) % UInt(8))
        XCTAssertTrue(safeIndex >= 0 && safeIndex < 8)
    }

    func testRegistryPayloadDecodesEnvelopeWithLegacyKeys() {
        let json = """
        {
          "plugins": [
            {
              "name": "Hidden Pack",
              "author": "Tester",
              "description": "Adds secret characters",
              "version": "1.2.3",
              "download_url": "bundled://hidden-pack",
              "character_count": "3",
              "tags": "hidden,market"
            }
          ]
        }
        """

        let data = Data(json.utf8)
        let items = PluginManager.decodeRegistryPayload(data)

        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?.name, "Hidden Pack")
        XCTAssertEqual(items?.first?.downloadURL, "bundled://hidden-pack")
        XCTAssertEqual(items?.first?.characterCount, 3)
        XCTAssertEqual(items?.first?.tags, ["hidden", "market"])
    }

    func testBundledRegistryIncludesFleaMarketHiddenPack() {
        let items = PluginManager.bundledRegistryCatalog()

        XCTAssertTrue(items.contains(where: {
            $0.id == "flea-market-hidden-pack" &&
            $0.downloadURL == "bundled://flea-market-hidden-pack" &&
            $0.characterCount == 3
        }))
    }

    func testFleaMarketHiddenCharactersPreferHiddenNames() {
        XCTAssertEqual(
            CharacterRegistry.syncedPluginCharacterName(
                pluginName: "flea-market-hidden-pack",
                originalID: "night_vendor",
                bundledName: "히든 야시장",
                existingName: "야시장"
            ),
            "히든 야시장"
        )

        XCTAssertEqual(
            CharacterRegistry.syncedPluginCharacterName(
                pluginName: "flea-market-hidden-pack",
                originalID: "ghost_dealer",
                bundledName: "히든 고스트딜러",
                existingName: "내 고스트"
            ),
            "내 고스트"
        )
    }
}
