import Foundation
import DesignSystem

#if os(macOS)
import AppKit
#endif

extension PluginManager {

    // MARK: - Debug Logging

    public func logDebug(_ level: PluginDebugEntry.Level, source: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.debugLog.append(PluginDebugEntry(level: level, source: source, message: message))
            if self.debugLog.count > self.maxDebugEntries {
                self.debugLog.removeFirst(self.debugLog.count - self.maxDebugEntries)
            }
        }
    }

    public func clearDebugLog() {
        debugLog.removeAll()
    }

    // MARK: - Finder에서 열기

    public func revealInFinder(_ plugin: PluginEntry) {
        #if os(macOS)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: plugin.localPath)
        #endif
    }

    // MARK: - 삭제

    public func uninstall(_ plugin: PluginEntry) {
        switch plugin.sourceType {
        case .brewFormula, .brewTap:
            #if os(macOS)
            if let brew = Self.findBrewPath() {
                _ = runShell("\(brew) uninstall \(shellEscape(plugin.source))")
            }
            #endif
        case .rawURL:
            try? FileManager.default.removeItem(atPath: plugin.localPath)
        case .local:
            break
        }

        DispatchQueue.main.async { [weak self] in
            self?.plugins.removeAll { $0.id == plugin.id }
            self?.savePlugins()
            // 제거된 플러그인 정리
            EventBus.shared.post(.pluginCharactersChanged)
            Task { @MainActor in PluginHost.shared.reload() }
        }
    }

    // MARK: - 재설치 (경로 누락 시)

    public func reinstallIfPossible(_ plugin: PluginEntry) {
        // 번들 플러그인: 인라인 데이터로 재생성
        if let bundledID = Self.bundledPluginID(from: plugin.source) {
            // 번들 레지스트리에서 해당 항목 찾기
            let catalog = Self.bundledRegistryCatalog()
            if let item = catalog.first(where: { $0.id == bundledID }) {
                installBundledPlugin(item, bundledID: bundledID)
                return
            }
        }

        // URL 플러그인: source에서 재다운로드
        if plugin.sourceType == .rawURL,
           let url = URL(string: plugin.source),
           url.scheme == "https" || url.scheme == "http" {
            install(source: plugin.source)
            return
        }

        // brew 플러그인: 재설치
        #if os(macOS)
        if plugin.sourceType == .brewFormula || plugin.sourceType == .brewTap {
            install(source: plugin.source)
            return
        }
        #endif

        // 로컬: 경로를 찾을 수 없으므로 사용자에게 안내
        finishWithError(NSLocalizedString("plugin.reinstall.manual", comment: ""))
    }

    // MARK: - 토글

    public func toggleEnabled(_ plugin: PluginEntry) {
        if let idx = plugins.firstIndex(where: { $0.id == plugin.id }) {
            plugins[idx].enabled.toggle()
            savePlugins()
        }
    }

    // MARK: - 업데이트 (brew upgrade)

    #if os(macOS)
    public func upgrade(_ plugin: PluginEntry) {
        guard plugin.sourceType != .rawURL else { return }
        guard let brew = Self.findBrewPath() else { return }

        isInstalling = true
        installProgress = String(format: NSLocalizedString("plugin.progress.upgrading", comment: ""), plugin.name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (ok, output) = self.runShell("\(brew) upgrade \(self.shellEscape(plugin.source))")

            if !ok && !output.contains("already installed") && !output.contains("already the newest") {
                self.finishWithError(String(format: NSLocalizedString("plugin.error.upgrade.failed", comment: ""), output))
                return
            }

            // 새 버전 확인
            let (_, versionOut) = self.runShell("\(brew) list --versions \(self.shellEscape(plugin.source))")
            let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").last ?? plugin.version

            DispatchQueue.main.async {
                if let idx = self.plugins.firstIndex(where: { $0.id == plugin.id }) {
                    self.plugins[idx].version = version
                    self.savePlugins()
                }
                self.isInstalling = false
                self.installProgress = ""
            }
        }
    }
    #endif

    // MARK: - Platform Helpers

    static var currentUserName: String {
        #if os(macOS)
        return NSUserName()
        #else
        return "user"
        #endif
    }

    // MARK: - Shell Helpers

    public static func defaultPluginBaseDir() -> URL {
        #if os(macOS)
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DofficePlugins")
        }
        return appSupport.appendingPathComponent("Doffice").appendingPathComponent("Plugins")
        #else
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DofficePlugins")
        #endif
    }

    static func defaultShellCommandRunner(_ command: String, _ cwd: String?) -> (Bool, String) {
        #if os(macOS)
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.environment = sanitizedPluginEnvironment()
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        do {
            try process.run()
        } catch {
            return (false, error.localizedDescription)
        }

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        let output = String(data: outData, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""
        let success = process.terminationStatus == 0
        return (success, success ? output : (errOutput.isEmpty ? output : errOutput))
        #else
        _ = command
        _ = cwd
        return (false, NSLocalizedString("plugin.error.brew.not.supported", comment: ""))
        #endif
    }

    static func defaultDownloadHandler(_ url: URL, _ destinationURL: URL, _ completion: @escaping (Result<Void, Error>) -> Void) {
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let tempURL else {
                completion(.failure(NSError(domain: "PluginManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("plugin.error.download.failed", comment: "")
                ])))
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    static func defaultInstallSideEffectHandler(_ entry: PluginEntry) {
        _ = entry
        EventBus.shared.post(.pluginCharactersChanged)
        Task { @MainActor in PluginHost.shared.reload() }
    }

    #if os(macOS)
    static func findBrewPath() -> String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    @discardableResult
    func runShell(_ command: String) -> (Bool, String) {
        shellCommandRunner(command, nil)
    }

    func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    #endif

    // MARK: - Progress Helpers

    func updateProgress(_ msg: String) {
        DispatchQueue.main.async { [weak self] in self?.installProgress = msg }
    }

    func finishWithError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = msg
            self?.isInstalling = false
            self?.installProgress = ""
        }
    }

    func pluginValidationError(at path: String) -> String? {
        let validation = Self.validatePluginDir(path)
        guard !validation.isValid else { return nil }
        return validation.warnings.first ?? NSLocalizedString("plugin.warn.empty", comment: "")
    }

    func cleanupManagedPluginDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            CrashLogger.shared.warning("PluginManager: Failed to cleanup directory \(directory.path) — \(error.localizedDescription)")
        }
    }

    func finishInstall(_ entry: PluginEntry) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let idx = self.plugins.firstIndex(where: { $0.source == entry.source }) {
                self.plugins[idx].name = entry.name
                self.plugins[idx].localPath = entry.localPath
                self.plugins[idx].version = entry.version
                self.plugins[idx].installedAt = entry.installedAt
                self.plugins[idx].enabled = entry.enabled
                self.plugins[idx].sourceType = entry.sourceType
            } else {
                self.plugins.append(entry)
            }
            self.savePlugins()
            self.installSideEffectHandler(entry)
            self.lastError = nil
            self.isInstalling = false
            self.installProgress = ""
        }
    }

    // MARK: - Registry Helpers

    public static func decodeRegistryPayload(_ data: Data) -> [RegistryPlugin]? {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            CrashLogger.shared.warning("PluginManager: Failed to decode registry payload — \(error.localizedDescription)")
            return nil
        }

        let rawItems: [[String: Any]]
        if let array = json as? [[String: Any]] {
            rawItems = array
        } else if let object = json as? [String: Any],
                  let array = object["plugins"] as? [[String: Any]] {
            rawItems = array
        } else {
            return nil
        }

        let items = rawItems.compactMap(Self.registryPlugin(from:))
        return items.isEmpty ? nil : items
    }

}
