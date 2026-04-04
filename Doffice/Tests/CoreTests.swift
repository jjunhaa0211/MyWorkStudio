import XCTest
@testable import Doffice

final class CoreTests: XCTestCase {
    private func makeSuite(_ name: String = UUID().uuidString) -> UserDefaults {
        let suiteName = "LegacyCoreTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testBuildFullPATH() {
        let path = TerminalTab.buildFullPATH()
        XCTAssertFalse(path.isEmpty, "PATH should not be empty")
        XCTAssertTrue(path.contains("/usr/bin"), "PATH should contain /usr/bin")
        XCTAssertTrue(path.contains("/bin"), "PATH should contain /bin")
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

    // MARK: - Cancel/ForceStop Safety Regression

    func testCancelProcessingDoesNotCrashWithoutProcess() {
        let tab = TerminalTab(
            id: "cancel-test",
            projectName: "Test",
            projectPath: "/tmp",
            workerName: "Tester",
            workerColor: .blue
        )
        tab.isProcessing = true
        tab.claudeActivity = .thinking

        tab.cancelProcessing()

        XCTAssertFalse(tab.isProcessing)
        XCTAssertEqual(tab.claudeActivity, .idle)
    }

    func testForceStopDoesNotCrashWithoutProcess() {
        let tab = TerminalTab(
            id: "force-stop-test",
            projectName: "Test",
            projectPath: "/tmp",
            workerName: "Tester",
            workerColor: .blue
        )
        tab.isProcessing = true
        tab.isRunning = true

        tab.forceStop()

        XCTAssertFalse(tab.isProcessing)
        XCTAssertFalse(tab.isRunning)
    }

    // MARK: - SessionStore Corruption Safety

    func testSessionStoreHandlesCorruptedFile() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        try? "{{invalid json content!!!".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = SessionStore(fileURL: fileURL)
        let sessions = store.load()
        XCTAssertTrue(sessions.isEmpty, "Corrupted file should result in empty sessions, not crash")
    }

    func testSSHProfileCommandEscapesRemoteDirectory() {
        let profile = SSHProfile(
            name: "Prod",
            host: "example.com",
            username: "deploy",
            authMethod: .agent,
            remoteWorkDir: "/srv/team's app"
        )

        XCTAssertTrue(profile.sshCommand.contains("deploy@example.com"))
        XCTAssertTrue(profile.sshCommand.contains("/srv/team'\\''s app"))
        XCTAssertTrue(profile.sshCommand.contains("exec $SHELL -l"))
        XCTAssertFalse(profile.sshCommand.contains("\\(escaped)"))
    }

    func testSSHConnectionManagerPersistsWithInjectedUserDefaults() {
        let defaults = makeSuite()
        let storageKey = "sshProfiles"

        let manager = SSHConnectionManager(userDefaults: defaults, storageKey: storageKey)
        let original = SSHProfile(name: "Stage", host: "stage.example.com", username: "junha")

        manager.addProfile(original)
        XCTAssertEqual(manager.profiles.count, 1)

        var updated = original
        updated.port = 2202
        updated.remoteWorkDir = "/workspace"
        manager.updateProfile(updated)

        let reloaded = SSHConnectionManager(userDefaults: defaults, storageKey: storageKey)
        XCTAssertEqual(reloaded.profiles.count, 1)
        XCTAssertEqual(reloaded.profiles.first?.port, 2202)
        XCTAssertEqual(reloaded.profiles.first?.remoteWorkDir, "/workspace")

        reloaded.deleteProfile(id: updated.id)
        XCTAssertTrue(reloaded.profiles.isEmpty)
    }

    func testTmuxSessionBridgeParsesPrefixedSessionsOnly() {
        let bridge = TmuxSessionBridge(
            sessionPrefix: "doffice-",
            tmuxPathOverride: "/opt/homebrew/bin/tmux",
            fileExists: { _ in true },
            shellRunner: { command, _ in
                if command.contains("list-sessions") {
                    return """
                    doffice-alpha\t1711992000\t2\t1
                    scratch\t1711991000\t1\t0
                    """
                }
                return ""
            }
        )

        let sessions = bridge.listSessions()

        XCTAssertTrue(bridge.isTmuxAvailable)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, "alpha")
        XCTAssertEqual(sessions.first?.windowCount, 2)
        XCTAssertEqual(sessions.first?.isAttached, true)
    }

    func testTmuxSessionBridgeUsesInjectedShellForCreateAndLookup() {
        var recordedCommands: [(String, String?)] = []
        let bridge = TmuxSessionBridge(
            sessionPrefix: "doffice-",
            tmuxPathOverride: "/usr/bin/tmux",
            fileExists: { _ in true },
            shellRunner: { command, cwd in
                recordedCommands.append((command, cwd))
                return ""
            }
        )

        XCTAssertTrue(bridge.createSession(id: "demo", cwd: "/tmp/doffice", cols: 100, rows: 40))
        XCTAssertTrue(bridge.sessionExists(id: "demo"))

        XCTAssertTrue(recordedCommands.contains(where: {
            $0.0.contains("new-session -d -s 'doffice-demo' -x 100 -y 40") && $0.1 == "/tmp/doffice"
        }))
        XCTAssertTrue(recordedCommands.contains(where: {
            $0.0.contains("has-session -t 'doffice-demo'")
        }))
    }
}
