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

    func testDofficeServerExtractCompleteLinesKeepsPartialRequestBuffered() {
        var buffer = Data("{\"command\":\"list-tabs\"}".utf8)

        XCTAssertTrue(DofficeServer.extractCompleteLines(from: &buffer).isEmpty)

        buffer.append(Data("\n{\"command\":\"ping\"}\n{\"command\":\"partial".utf8))
        let lines = DofficeServer.extractCompleteLines(from: &buffer).compactMap {
            String(data: $0, encoding: .utf8)
        }

        XCTAssertEqual(lines, [
            "{\"command\":\"list-tabs\"}",
            "{\"command\":\"ping\"}",
        ])
        XCTAssertEqual(String(data: buffer, encoding: .utf8), "{\"command\":\"partial")
    }

    func testDofficeServerExtractCompleteLinesStripsCarriageReturns() {
        var buffer = Data("first\r\nsecond\r\n".utf8)

        let lines = DofficeServer.extractCompleteLines(from: &buffer).compactMap {
            String(data: $0, encoding: .utf8)
        }

        XCTAssertEqual(lines, ["first", "second"])
        XCTAssertTrue(buffer.isEmpty)
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

    // MARK: - VT100Terminal Regression Tests

    func testVT100DeleteCharAtEndOfRow() {
        // Bug: 커서가 행 끝에 있을 때 "P" (문자 삭제) 명령이
        // 정수 언더플로우로 크래시할 수 있음
        let terminal = VT100Terminal(rows: 2, cols: 5)

        // 행에 "ABCDE" 입력
        terminal.feed("ABCDE")

        // 커서를 마지막 열에 놓고 삭제 시도 — 크래시하면 안 됨
        terminal.feed("\u{1B}[5G")  // 커서를 5열로 (0-indexed: 4)
        terminal.feed("\u{1B}[1P")  // 1문자 삭제

        let text = terminal.render(fontSize: 12).string
        // 크래시 없이 정상 동작하면 성공
        XCTAssertFalse(text.isEmpty)
    }

    func testVT100DeleteCharEmptyRow() {
        // Bug: 빈 행에서 삭제 시도 시 guard로 안전하게 건너뛰어야 함
        let terminal = VT100Terminal(rows: 2, cols: 5)

        // 아무것도 입력하지 않은 상태에서 삭제 시도
        terminal.feed("\u{1B}[1P")

        // 크래시 없이 정상 동작
        let text = terminal.render(fontSize: 12).string
        XCTAssertTrue(text.isEmpty || text.allSatisfy { $0 == " " || $0 == "\n" })
    }

    func testVT100DeleteCharLargeCount() {
        // 행 길이보다 큰 삭제 요청 — available로 클램핑되어야 함
        let terminal = VT100Terminal(rows: 2, cols: 5)
        terminal.feed("ABC")
        terminal.feed("\u{1B}[1G")  // 커서를 1열로
        terminal.feed("\u{1B}[99P") // 99문자 삭제 시도

        // 크래시 없이 정상 동작
        let text = terminal.render(fontSize: 12).string
        XCTAssertNotNil(text)
    }

    // MARK: - CrashLogger Tests

    func testCrashLoggerWritesFile() {
        let logger = CrashLogger.shared
        logger.info("Test log entry from unit test")
        logger.flush()

        let logFiles = logger.recentLogFiles()
        XCTAssertFalse(logFiles.isEmpty, "Log directory should contain at least one log file")

        if let latest = logFiles.first,
           let content = try? String(contentsOf: latest, encoding: .utf8) {
            XCTAssertTrue(content.contains("Test log entry from unit test"))
        }
    }

    // MARK: - SessionStore Regression Tests

    func testSessionStoreHandlesCorruptedFile() {
        // 손상된 세션 파일이 있을 때 크래시하지 않고 빈 세션으로 복구해야 함
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        try? "{{invalid json content!!!".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = SessionStore(fileURL: fileURL)
        // 크래시 없이 빈 세션 반환
        let sessions = store.load()
        XCTAssertTrue(sessions.isEmpty, "Corrupted file should result in empty sessions, not crash")
    }

    func testSessionStoreSaveAndLoad() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        let store = SessionStore(fileURL: fileURL)

        // 빈 상태에서 시작
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.sessionCount, 0)
    }

    // MARK: - SessionStore Concurrent Load Race (TOCTOU Regression)

    func testSessionStoreConcurrentLoadDoesNotCrash() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        let store = SessionStore(fileURL: fileURL)

        // Concurrent loads must not crash or corrupt state (TOCTOU regression test)
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                _ = store.load()
                group.leave()
            }
        }
        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "Concurrent loads should complete without deadlock")
    }

    // MARK: - sanitizeTerminalText Regression

    func testSanitizeTerminalTextStripsAnsiCodes() {
        let tab = TerminalTab(
            id: "ansi-test",
            projectName: "Test",
            projectPath: "/tmp",
            workerName: "Tester",
            workerColor: .blue
        )

        let input = "\u{001B}[32mHello\u{001B}[0m World\u{001B}[1;31m!\u{001B}[0m"
        let result = tab.sanitizeTerminalText(input)
        XCTAssertEqual(result, "Hello World!")
    }

    func testSanitizeTerminalTextHandlesEmptyString() {
        let tab = TerminalTab(
            id: "ansi-empty",
            projectName: "Test",
            projectPath: "/tmp",
            workerName: "Tester",
            workerColor: .blue
        )

        XCTAssertEqual(tab.sanitizeTerminalText(""), "")
        XCTAssertEqual(tab.sanitizeTerminalText("\r\n"), "")
    }

    func testSanitizeTerminalTextNormalizesLineEndings() {
        let tab = TerminalTab(
            id: "ansi-crlf",
            projectName: "Test",
            projectPath: "/tmp",
            workerName: "Tester",
            workerColor: .blue
        )

        let result = tab.sanitizeTerminalText("line1\r\nline2\rline3")
        XCTAssertEqual(result, "line1\nline2\nline3")
    }

    // MARK: - AuditLog Trim Regression

    func testAuditLogTrimDoesNotCrash() {
        let log = AuditLog.shared
        let initialCount = log.entries.count

        // Insert enough entries to trigger trim (maxEntries = 5000)
        // We just verify that inserting works without crash
        for i in 0..<10 {
            log.log(.sessionStart, tabId: "trim-test-\(i)", projectName: "Test", detail: "entry \(i)")
        }

        let expectation = expectation(description: "Entries inserted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertGreaterThanOrEqual(log.entries.count, initialCount)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - DofficeServer extractCompleteLines Edge Cases

    func testDofficeServerExtractCompleteLinesEmptyBuffer() {
        var buffer = Data()
        let lines = DofficeServer.extractCompleteLines(from: &buffer)
        XCTAssertTrue(lines.isEmpty)
        XCTAssertTrue(buffer.isEmpty)
    }

    func testDofficeServerExtractCompleteLinesOnlyNewlines() {
        var buffer = Data("\n\n\n".utf8)
        let lines = DofficeServer.extractCompleteLines(from: &buffer)
        // Should produce 3 empty strings
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(buffer.isEmpty)
    }

    // MARK: - GitDataParser Bounds Safety

    func testGitDataParserSanitizePathRemovesDangerousCharacters() {
        // sanitizePath strips injection characters: null, backtick, $, ;, &, |, newlines
        let dangerous = "file`name;rm$PATH|test&\0"
        let sanitized = GitDataParser.sanitizePath(dangerous)
        XCTAssertFalse(sanitized.contains("`"))
        XCTAssertFalse(sanitized.contains(";"))
        XCTAssertFalse(sanitized.contains("$"))
        XCTAssertFalse(sanitized.contains("|"))
        XCTAssertFalse(sanitized.contains("&"))
        XCTAssertFalse(sanitized.contains("\0"))
        XCTAssertEqual(sanitized, "filenamermPATHtest")
    }

    func testGitDataParserSanitizePathStripsLeadingDashes() {
        let flagInjection = "--exec=malicious"
        let sanitized = GitDataParser.sanitizePath(flagInjection)
        XCTAssertFalse(sanitized.hasPrefix("-"))
    }

    // MARK: - SessionStore Silent Failure Logging Tests

    func testSessionStoreInitLogsDirectoryCreationFailure() {
        // SessionStore init should not crash even with an invalid path
        // (it logs the error and continues)
        let impossibleURL = URL(fileURLWithPath: "/dev/null/impossible/sessions.json")
        let store = SessionStore(fileURL: impossibleURL)
        // Should gracefully handle — load returns empty, no crash
        XCTAssertTrue(store.load().isEmpty)
    }

    func testSessionStoreSaveAndReloadPreservesData() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        let store = SessionStore(fileURL: fileURL, writeDelay: 0)

        let tab = TerminalTab(
            id: "save-reload-test",
            projectName: "TestProject",
            projectPath: "/tmp/test",
            workerName: "TestWorker",
            workerColor: .blue
        )
        tab.tokensUsed = 1234
        tab.totalCost = 0.05
        tab.selectedModel = .opus
        tab.effortLevel = .high
        tab.permissionMode = .bypassPermissions
        tab.systemPrompt = "Be helpful"

        store.save(tabs: [tab], immediately: true)

        // Load from a fresh store instance to verify persistence
        let store2 = SessionStore(fileURL: fileURL)
        let loaded = store2.load()
        XCTAssertEqual(loaded.count, 1)

        let saved = loaded[0]
        XCTAssertEqual(saved.tabId, "save-reload-test")
        XCTAssertEqual(saved.projectName, "TestProject")
        XCTAssertEqual(saved.projectPath, "/tmp/test")
        XCTAssertEqual(saved.tokensUsed, 1234)
        XCTAssertEqual(saved.totalCost, 0.05)
        XCTAssertEqual(saved.selectedModel, ClaudeModel.opus.rawValue)
        XCTAssertEqual(saved.effortLevel, EffortLevel.high.rawValue)
        XCTAssertEqual(saved.systemPrompt, "Be helpful")
    }

    func testSessionStoreRestoredTabMatchesOriginal() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        let store = SessionStore(fileURL: fileURL, writeDelay: 0)

        // Create a tab with specific configuration
        let original = TerminalTab(
            id: "restore-test",
            projectName: "Restore",
            projectPath: "/tmp/restore",
            workerName: "Worker",
            workerColor: .red
        )
        original.selectedModel = .haiku
        original.effortLevel = .low
        original.continueSession = true
        original.useWorktree = true
        original.sessionName = "my-session"
        original.customAgent = "custom-agent"
        original.enableBrief = true
        original.tmuxMode = true
        original.tokenLimit = 5000

        store.save(tabs: [original], immediately: true)

        let store2 = SessionStore(fileURL: fileURL)
        let saved = store2.load().first!

        // Restore into a new tab and verify
        let restored = TerminalTab(
            id: saved.tabId ?? "unknown",
            projectName: saved.projectName,
            projectPath: saved.projectPath,
            workerName: saved.workerName,
            workerColor: .red
        )
        restored.applySavedSessionConfiguration(saved)

        XCTAssertEqual(restored.selectedModel, .haiku)
        XCTAssertEqual(restored.effortLevel, .low)
        XCTAssertTrue(restored.continueSession)
        XCTAssertTrue(restored.useWorktree)
        XCTAssertEqual(restored.sessionName, "my-session")
        XCTAssertEqual(restored.customAgent, "custom-agent")
        XCTAssertTrue(restored.enableBrief)
        XCTAssertTrue(restored.tmuxMode)
        XCTAssertEqual(restored.tokenLimit, 5000)
    }

    // MARK: - BuildFullPATH Thread Safety

    func testBuildFullPATHConcurrentCallsDoNotCrash() {
        // Verify that concurrent calls to buildFullPATH don't crash due to static var race
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async {
                let path = TerminalTab.buildFullPATH()
                XCTAssertFalse(path.isEmpty)
                group.leave()
            }
        }
        let result = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(result, .success, "Concurrent buildFullPATH should not deadlock")
    }

    // MARK: - TerminalTab Cancel Ordering Regression

    func testCancelProcessingDoesNotCrashWithoutProcess() {
        // cancelProcessing() should be safe to call when no process is running
        let tab = TerminalTab(
            id: "cancel-test",
            projectName: "Test",
            projectPath: "/tmp",
            workerName: "Tester",
            workerColor: .blue
        )
        tab.isProcessing = true
        tab.claudeActivity = .thinking

        // Should not crash even with no currentProcess
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

        // Should not crash even with no process
        tab.forceStop()

        XCTAssertFalse(tab.isProcessing)
        XCTAssertFalse(tab.isRunning)
    }

    // MARK: - SessionStore Recovery Bundle

    func testSessionStoreRecoveryBundleCreation() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DofficeTest-\(UUID().uuidString)")
        let projectDir = tempDir.appendingPathComponent("project")
        try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sessions.json")
        let store = SessionStore(fileURL: fileURL, writeDelay: 0)

        let tab = TerminalTab(
            id: "recovery-test",
            projectName: "RecoveryProject",
            projectPath: projectDir.path,
            workerName: "Worker",
            workerColor: .green
        )
        tab.lastPromptText = "Fix the bug"
        tab.lastResultText = "Done fixing"
        tab.tokensUsed = 500

        let bundleURL = store.writeRecoveryBundle(for: tab, reason: "test-crash")
        XCTAssertNotNil(bundleURL)

        if let bundleURL {
            let readmePath = bundleURL.appendingPathComponent("README.md")
            XCTAssertTrue(FileManager.default.fileExists(atPath: readmePath.path))

            if let content = try? String(contentsOf: readmePath, encoding: .utf8) {
                XCTAssertTrue(content.contains("RecoveryProject"))
                XCTAssertTrue(content.contains("test-crash"))
                XCTAssertTrue(content.contains("Fix the bug"))
            }
        }
    }
}
