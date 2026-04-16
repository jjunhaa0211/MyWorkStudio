import Foundation
import SwiftUI
import UniformTypeIdentifiers
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Host (런타임 플러그인 관리)
// ═══════════════════════════════════════════════════════

/// 플러그인 실행 시 민감한 환경변수를 제거한 환경 딕셔너리를 반환
public func sanitizedPluginEnvironment() -> [String: String] {
    var env = ProcessInfo.processInfo.environment
    let sensitivePatterns = ["API_KEY", "SECRET", "TOKEN", "PASSWORD", "CREDENTIAL", "ANTHROPIC_", "OPENAI_", "GEMINI_API"]
    for key in env.keys {
        let upper = key.uppercased()
        if sensitivePatterns.contains(where: { upper.contains($0) }) {
            env.removeValue(forKey: key)
        }
    }
    return env
}

/// 활성 플러그인에서 로드된 확장 포인트들을 관리
public class PluginHost: ObservableObject, PluginHostProviding {
    public static let shared = PluginHost()

    /// 활성 패널 목록
    @Published public var panels: [LoadedPanel] = []
    /// 활성 명령어 목록
    @Published public var commands: [LoadedCommand] = []
    /// 상태바 위젯 목록
    @Published public var statusBarItems: [LoadedStatusBarItem] = []

    // ── 네이티브 확장 ──
    @Published public var themes: [LoadedTheme] = []
    @Published public var achievements: [PluginManifest.AchievementDecl] = []
    @Published public var bossLines: [String] = []
    @Published public var effects: [LoadedEffect] = []
    @Published public var furniture: [LoadedFurniture] = []
    @Published public var officePresets: [LoadedOfficePreset] = []
    /// 마지막 플러그인 에러 (UI 알림용)
    @Published public var lastPluginError: String?

    public struct LoadedPanel: Identifiable {
        public let id: String
        public let pluginName: String
        public let title: String
        public let icon: String
        public let htmlURL: URL
        public let position: String
        public let width: Int?
        public let height: Int?
    }

    public struct LoadedCommand: Identifiable {
        public let id: String
        public let pluginName: String
        public let title: String
        public let icon: String
        public let scriptPath: String
    }

    public struct LoadedStatusBarItem: Identifiable {
        public let id: String
        public let pluginName: String
        public let scriptPath: String
        public let interval: Int
        public var text: String = ""
        public var icon: String = ""
        public var color: String = ""
    }

    public struct LoadedTheme: Identifiable {
        public let id: String
        public let pluginName: String
        public let decl: PluginManifest.ThemeDecl
    }

    public struct LoadedEffect: Identifiable {
        public let id: String
        public let pluginName: String
        public let trigger: PluginEventType
        public let effectType: PluginEffectType
        public let config: [String: EffectValue]
        public let enabled: Bool
    }

    public struct LoadedFurniture: Identifiable {
        public let id: String
        public let pluginName: String
        public let decl: PluginManifest.FurnitureDecl
    }

    public struct LoadedOfficePreset: Identifiable {
        public let id: String
        public let pluginName: String
        public let decl: PluginManifest.OfficePresetDecl
    }

    // MARK: - 이벤트 발행

    public func fireEvent(_ event: PluginEventType, context: [String: Any] = [:]) {
        EventBus.shared.post(.pluginEffectEvent(event: event, context: context))
    }

    public func reload() {
        // Move file I/O and JSON decoding off the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?._reloadOnBackground()
        }
    }

    private func _reloadOnBackground() {
        var newPanels: [LoadedPanel] = []
        var newCommands: [LoadedCommand] = []
        var newStatusBars: [LoadedStatusBarItem] = []
        var newThemes: [LoadedTheme] = []
        var newEffects: [LoadedEffect] = []
        var newAchievements: [PluginManifest.AchievementDecl] = []
        var newBossLines: [String] = []
        var newFurniture: [LoadedFurniture] = []
        var newOfficePresets: [LoadedOfficePreset] = []

        for pluginPath in PluginManager.shared.activePluginPaths {
            let baseURL = URL(fileURLWithPath: pluginPath)
            let manifestURL = baseURL.appendingPathComponent("plugin.json")

            // Use cached manifest from PluginManager when available
            let manifest: PluginManifest
            if let cached = PluginManager.shared.manifestCacheGet(pluginPath) {
                manifest = cached
            } else {
                do {
                    let data = try Data(contentsOf: manifestURL)
                    let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
                    manifest = decoded
                    PluginManager.shared.manifestCacheSet(pluginPath, manifest)
                } catch {
                    CrashLogger.shared.warning("PluginHost: Failed to load manifest at \(manifestURL.path) — \(error.localizedDescription)")
                    DispatchQueue.main.async { [weak self] in
                        self?.lastPluginError = "Plugin manifest load failed: \(manifestURL.lastPathComponent) — \(error.localizedDescription)"
                    }
                    continue
                }
            }
            guard let contributes = manifest.contributes else { continue }

            let pluginName = manifest.name

            // 패널
            if let panelDecls = contributes.panels {
                for decl in panelDecls {
                    let htmlURL = baseURL.appendingPathComponent(decl.entry)
                    guard FileManager.default.fileExists(atPath: htmlURL.path) else { continue }
                    newPanels.append(LoadedPanel(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        title: decl.title,
                        icon: decl.icon ?? "puzzlepiece.fill",
                        htmlURL: htmlURL,
                        position: decl.position ?? "panel",
                        width: decl.width,
                        height: decl.height
                    ))
                }
            }

            // 명령어
            if let cmdDecls = contributes.commands {
                for decl in cmdDecls {
                    let scriptPath = baseURL.appendingPathComponent(decl.script).path
                    guard FileManager.default.fileExists(atPath: scriptPath) else { continue }
                    newCommands.append(LoadedCommand(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        title: decl.title,
                        icon: decl.icon ?? "terminal",
                        scriptPath: scriptPath
                    ))
                }
            }

            // 상태바
            if let statusDecls = contributes.statusBar {
                for decl in statusDecls {
                    let scriptPath = baseURL.appendingPathComponent(decl.script).path
                    guard FileManager.default.fileExists(atPath: scriptPath) else { continue }
                    newStatusBars.append(LoadedStatusBarItem(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        scriptPath: scriptPath,
                        interval: decl.interval ?? 30
                    ))
                }
            }

            // ── 네이티브 확장 ──

            // 테마
            if let themeDecls = contributes.themes {
                for decl in themeDecls {
                    newThemes.append(LoadedTheme(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 업적
            if let achDecls = contributes.achievements {
                newAchievements.append(contentsOf: achDecls)
            }

            // 사장 대사
            if let lines = contributes.bossLines {
                newBossLines.append(contentsOf: lines)
            }

            // 가구
            if let furnitureDecls = contributes.furniture {
                for decl in furnitureDecls {
                    newFurniture.append(LoadedFurniture(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 오피스 프리셋
            if let presetDecls = contributes.officePresets {
                for decl in presetDecls {
                    newOfficePresets.append(LoadedOfficePreset(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 이펙트
            if let effectDecls = contributes.effects {
                for decl in effectDecls {
                    guard let trigger = PluginEventType(rawValue: decl.trigger),
                          let effectType = PluginEffectType(rawValue: decl.type) else { continue }
                    newEffects.append(LoadedEffect(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        trigger: trigger,
                        effectType: effectType,
                        config: decl.config ?? [:],
                        enabled: decl.enabled ?? true
                    ))
                }
            }
        }

        // 개별 비활성화된 확장 포인트 필터링
        let disabled = PluginManager.shared.disabledExtensions

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            OfficeSpriteRenderer.clearPluginFurnitureImageCache()
            self.panels = newPanels.filter { !disabled.contains($0.id) }
            self.commands = newCommands.filter { !disabled.contains($0.id) }
            self.statusBarItems = newStatusBars.filter { !disabled.contains($0.id) }
            self.themes = newThemes.filter { !disabled.contains($0.id) }
            self.effects = newEffects.filter { !disabled.contains($0.id) }
            self.furniture = newFurniture.filter { !disabled.contains($0.id) }
            self.officePresets = newOfficePresets.filter { !disabled.contains($0.id) }
            // Note: achievements use raw AchievementDecl with local IDs (not "pluginName::id"),
            // so they cannot be matched against disabledExtensions which stores composite IDs.
            self.achievements = newAchievements
            self.bossLines = newBossLines
            self.startStatusBarTimers()
            // 충돌 캐시 갱신
            PluginManager.shared.detectConflicts()
        }
    }

    // MARK: - 테마 적용

    public func applyTheme(_ theme: LoadedTheme) {
        let d = theme.decl
        let current = AppSettings.shared.customTheme
        let config = CustomThemeConfig(
            accentHex: d.accentHex,
            useGradient: d.useGradient ?? false,
            gradientStartHex: d.gradientStartHex,
            gradientEndHex: d.gradientEndHex,
            fontName: d.fontName,
            fontSize: current.fontSize,
            bgHex: d.bgHex,
            bgCardHex: d.cardHex,
            bgSurfaceHex: d.cardHex ?? d.bgHex,
            bgTertiaryHex: d.bgHex,
            textPrimaryHex: d.textHex,
            textSecondaryHex: d.textHex,
            textDimHex: d.textHex,
            textMutedHex: current.textMutedHex,
            borderHex: current.borderHex,
            borderStrongHex: current.borderStrongHex,
            greenHex: d.greenHex,
            redHex: d.redHex,
            yellowHex: d.yellowHex,
            purpleHex: d.purpleHex,
            orangeHex: current.orangeHex,
            cyanHex: d.cyanHex,
            pinkHex: current.pinkHex
        )

        AppSettings.shared.performBatchUpdate {
            AppSettings.shared.isDarkMode = d.isDark
            AppSettings.shared.themeMode = "custom"
            AppSettings.shared.saveCustomTheme(config)
        }
        AppSettings.shared.requestRefreshIfNeeded()
    }

    // MARK: - 오피스 프리셋 적용

    @discardableResult
    public func applyOfficePreset(_ preset: LoadedOfficePreset, to map: OfficeMap) -> [FurniturePlacement] {
        guard let placements = preset.decl.furniture, !placements.isEmpty else { return [] }

        var inserted: [FurniturePlacement] = []

        for placement in placements {
            guard let furnitureDecl = furniture.first(where: { $0.decl.id == placement.furnitureId })?.decl else {
                continue
            }

            guard !furnitureDecl.sprite.isEmpty,
                  furnitureDecl.sprite.contains(where: { $0.contains(where: { !$0.isEmpty }) }) else {
                continue
            }

            guard placement.col >= 0, placement.row >= 0,
                  placement.col + furnitureDecl.width <= map.cols,
                  placement.row + furnitureDecl.height <= map.rows else {
                continue
            }

            let zone: OfficeZone = {
                switch furnitureDecl.zone ?? "mainOffice" {
                case "pantry": return .pantry
                case "meetingRoom": return .meetingRoom
                case "hallway": return .hallway
                default: return .mainOffice
                }
            }()

            let furniturePlacement = FurniturePlacement(
                id: "plugin_\(preset.pluginName)_\(placement.furnitureId)_\(placement.col)_\(placement.row)",
                type: .plugin,
                position: TileCoord(col: placement.col, row: placement.row),
                size: TileSize(w: furnitureDecl.width, h: furnitureDecl.height),
                zone: zone,
                pluginFurnitureId: furnitureDecl.id
            )

            let collidesWithExisting = map.furniture.contains { existing in
                guard existing.type != .rug else { return false }
                let eMinCol = existing.position.col
                let eMaxCol = existing.position.col + existing.size.w
                let eMinRow = existing.position.row
                let eMaxRow = existing.position.row + existing.size.h
                let pMinCol = placement.col
                let pMaxCol = placement.col + furnitureDecl.width
                let pMinRow = placement.row
                let pMaxRow = placement.row + furnitureDecl.height
                return pMinCol < eMaxCol && pMaxCol > eMinCol && pMinRow < eMaxRow && pMaxRow > eMinRow
            }

            guard !collidesWithExisting,
                  !map.furniture.contains(where: { $0.id == furniturePlacement.id }) else {
                continue
            }

            map.furniture.append(furniturePlacement)
            inserted.append(furniturePlacement)
        }

        if !inserted.isEmpty {
            map.rebuildWalkability()
        }

        return inserted
    }

    // MARK: - 명령어 실행

    public func executeCommand(_ command: LoadedCommand, projectPath: String? = nil) {
        #if os(macOS)
        // 스크립트 경로가 플러그인 디렉토리 내에 있는지 검증
        let pluginBaseDir = PluginManager.defaultPluginBaseDir().path
        let resolvedScript = URL(fileURLWithPath: command.scriptPath).standardizedFileURL.path
        guard resolvedScript.hasPrefix(pluginBaseDir) || resolvedScript.hasPrefix("/usr/") || resolvedScript.hasPrefix("/bin/") else {
            CrashLogger.shared.warning("PluginHost: Script path outside plugin directory — blocked: \(command.scriptPath)")
            return
        }

        PluginManager.shared.requestPermission(
            pluginName: command.pluginName,
            scriptPath: command.scriptPath
        ) {
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command.scriptPath]
                if let path = projectPath {
                    process.currentDirectoryURL = URL(fileURLWithPath: path)
                }
                process.environment = sanitizedPluginEnvironment()
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    CrashLogger.shared.warning("PluginHost: Shortcut command failed — \(error.localizedDescription)")
                }
            }
        }
        #endif
    }

    // MARK: - 상태바 타이머

    private var statusTimers: [String: Timer] = [:]

    private func startStatusBarTimers() {
        #if os(macOS)
        for timer in statusTimers.values { timer.invalidate() }
        statusTimers.removeAll()

        for item in statusBarItems {
            refreshStatusBarItem(item.id)
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(item.interval), repeats: true) { [weak self] _ in
                self?.refreshStatusBarItem(item.id)
            }
            statusTimers[item.id] = timer
        }
        #endif
    }

    #if os(macOS)
    private func refreshStatusBarItem(_ id: String) {
        guard let idx = statusBarItems.firstIndex(where: { $0.id == id }) else { return }
        let item = statusBarItems[idx]

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", item.scriptPath]
            process.standardOutput = pipe
            process.environment = sanitizedPluginEnvironment()
            do {
                try process.run()
            } catch {
                CrashLogger.shared.warning("PluginHost: Status bar script failed for '\(id)' — \(error.localizedDescription)")
                return
            }
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if !data.isEmpty {
                    CrashLogger.shared.debug("PluginHost: Status bar script '\(id)' returned invalid JSON")
                }
                return
            }

            DispatchQueue.main.async {
                guard let self = self,
                      let idx = self.statusBarItems.firstIndex(where: { $0.id == id }) else { return }
                self.statusBarItems[idx].text = json["text"] as? String ?? ""
                self.statusBarItems[idx].icon = json["icon"] as? String ?? ""
                self.statusBarItems[idx].color = json["color"] as? String ?? ""
            }
        }
    }
    #endif
}
