import XCTest
@testable import DofficeKit
import DesignSystem

final class CoreTests: XCTestCase {
    private func waitUntil(
        timeout: TimeInterval = 3.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) {
        let expectation = expectation(description: "Condition fulfilled")

        func poll() {
            if condition() {
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: poll)
            }
        }

        DispatchQueue.main.async(execute: poll)
        wait(for: [expectation], timeout: timeout)
        XCTAssertTrue(condition(), file: file, line: line)
    }

    private func makeSuite(_ name: String = UUID().uuidString) -> UserDefaults {
        let suiteName = "CoreTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

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

    func testTerminalTabBrowserDefaults() {
        let tab = TerminalTab(
            id: "browser-defaults",
            projectName: "Demo",
            projectPath: "/tmp/demo",
            workerName: "Tester",
            workerColor: .blue
        )

        XCTAssertFalse(tab.isBrowserTab)
        XCTAssertEqual(tab.browserURL, "")
    }

    func testPluginValidationRejectsEmptyDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let validation = PluginManager.validatePluginDir(root.path)

        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.warnings.first, NSLocalizedString("plugin.warn.empty", comment: ""))
    }

    func testPluginValidationAcceptsMinimalPluginDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "# Demo Plugin".write(to: root.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

        let validation = PluginManager.validatePluginDir(root.path)

        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.hasClaudeMD)
        XCTAssertTrue(validation.warnings.isEmpty)
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

    func testPluginManagerInstallLocalPersistsIntoInjectedStore() throws {
        let defaults = makeSuite()
        let baseDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pluginDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: baseDir)
            try? FileManager.default.removeItem(at: pluginDir)
        }

        try "# Demo Plugin".write(to: pluginDir.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try #"{"name":"demo-plugin","version":"0.4.2"}"#.write(
            to: pluginDir.appendingPathComponent("package.json"),
            atomically: true,
            encoding: .utf8
        )

        let manager = PluginManager(
            pluginBaseDir: baseDir,
            userDefaults: defaults,
            installSideEffectHandler: { _ in }
        )

        manager.install(source: pluginDir.path)
        waitUntil { !manager.isInstalling }

        XCTAssertNil(manager.lastError)
        XCTAssertEqual(manager.plugins.count, 1)
        XCTAssertEqual(manager.plugins.first?.sourceType, .local)
        XCTAssertEqual(manager.plugins.first?.version, "0.4.2")
        XCTAssertEqual(manager.plugins.first?.localPath, pluginDir.path)

        let reloaded = PluginManager(
            pluginBaseDir: baseDir,
            userDefaults: defaults,
            installSideEffectHandler: { _ in }
        )
        XCTAssertEqual(reloaded.plugins.count, 1)
        XCTAssertEqual(reloaded.plugins.first?.source, pluginDir.path)
    }

    func testPluginManagerInstallFromURLUsesInjectedDownloader() throws {
        let defaults = makeSuite()
        let baseDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let manager = PluginManager(
            pluginBaseDir: baseDir,
            userDefaults: defaults,
            downloadHandler: { _, destinationURL, completion in
                do {
                    try "# Downloaded Plugin".write(to: destinationURL, atomically: true, encoding: .utf8)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            },
            installSideEffectHandler: { _ in }
        )

        manager.install(source: "https://example.com/plugins/CLAUDE.md")
        waitUntil { !manager.isInstalling }

        XCTAssertNil(manager.lastError)
        XCTAssertEqual(manager.plugins.count, 1)
        XCTAssertEqual(manager.plugins.first?.sourceType, .rawURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: baseDir.appendingPathComponent("CLAUDE/CLAUDE.md").path))
    }

    func testPluginManagerBrokenArchiveCleansUpManagedDirectory() throws {
        let defaults = makeSuite()
        let baseDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let manager = PluginManager(
            pluginBaseDir: baseDir,
            userDefaults: defaults,
            shellCommandRunner: { command, _ in
                if command.contains("unzip -o") {
                    return (false, "invalid zip payload")
                }
                return (true, "")
            },
            downloadHandler: { _, destinationURL, completion in
                do {
                    try Data("not-a-zip".utf8).write(to: destinationURL)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            },
            installSideEffectHandler: { _ in }
        )

        manager.install(source: "https://example.com/plugins/Broken.zip")
        waitUntil { !manager.isInstalling }

        XCTAssertNotNil(manager.lastError)
        XCTAssertTrue(manager.plugins.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: baseDir.appendingPathComponent("Broken").path))
    }
}
