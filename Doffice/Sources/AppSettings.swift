import SwiftUI
import UniformTypeIdentifiers
import os
// ═══════════════════════════════════════════════════════
// MARK: - Custom Theme Config (JSON 직렬화 모델)
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Custom Job (사용자 정의 직업)
// ═══════════════════════════════════════════════════════

struct CustomJob: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var icon: String = "person.fill"
    var promptTemplate: String = ""
    var statusMarker: String = ""  // e.g., "CUSTOM_STATUS: READY"
}

struct CustomThemeConfig: Codable, Equatable {
    var accentHex: String?          // nil = 기본 accent 사용
    var useGradient: Bool = false
    var gradientStartHex: String?
    var gradientEndHex: String?
    var fontName: String?           // nil = 시스템 폰트
    var fontSize: Double?           // nil = 기존 scale 시스템 사용

    // Background colors
    var bgHex: String?
    var bgCardHex: String?
    var bgSurfaceHex: String?
    var bgTertiaryHex: String?

    // Text colors
    var textPrimaryHex: String?
    var textSecondaryHex: String?
    var textDimHex: String?
    var textMutedHex: String?

    // Border colors
    var borderHex: String?
    var borderStrongHex: String?

    // Semantic colors
    var greenHex: String?
    var redHex: String?
    var yellowHex: String?
    var purpleHex: String?
    var orangeHex: String?
    var cyanHex: String?
    var pinkHex: String?

    static let `default` = CustomThemeConfig()
}

// ═══════════════════════════════════════════════════════
// MARK: - App Settings (전역 설정)
// ═══════════════════════════════════════════════════════

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // ── Batch Update Support ──
    // Prevents multiple objectWillChange.send() calls during bulk settings changes.
    private var _batchUpdateInProgress = false

    /// Perform multiple settings changes with only a single objectWillChange notification.
    /// 중첩 호출 안전: 이미 batch 중이면 내부에서 다시 send하지 않음.
    func performBatchUpdate(_ changes: () -> Void) {
        let wasAlreadyInBatch = _batchUpdateInProgress
        _batchUpdateInProgress = true
        changes()
        if !wasAlreadyInBatch {
            _batchUpdateInProgress = false
            objectWillChange.send()
            Theme.invalidateFontCache()
        }
    }

    /// Sends objectWillChange only if not inside a batch update.
    private func notifyIfNeeded() {
        guard !_batchUpdateInProgress else { return }
        objectWillChange.send()
    }

    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // themeMode: "light" | "dark" | "custom"
    // 빈 문자열이면 isDarkMode에서 파생 (기존 사용자 마이그레이션)
    @AppStorage("themeMode") private var _themeMode: String = ""

    var themeMode: String {
        get { _themeMode.isEmpty ? (isDarkMode ? "dark" : "light") : _themeMode }
        set {
            performBatchUpdate {
                _themeMode = newValue
                // isDarkMode를 동기화
                if newValue == "light" { isDarkMode = false }
                else if newValue == "dark" { isDarkMode = true }
            }
        }
    }
    @AppStorage("fontSizeScale") var fontSizeScale: Double = 1.5 {
        didSet { notifyIfNeeded() }
    }

    // ── 오피스 뷰 모드 ──
    @AppStorage("officeViewMode") var officeViewMode: String = "grid" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("officePreset") var officePreset: String = OfficePreset.cozy.rawValue {
        didSet { notifyIfNeeded() }
    }

    // ── 토큰 보호 ──
    @AppStorage("tokenProtectionEnabled") var tokenProtectionEnabled: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 캐릭터 속도 ──
    /// 캐릭터 이동 속도 배율 (0.5 = 느림, 1.0 = 보통, 2.0 = 빠름)
    @AppStorage("characterSpeedMultiplier") var characterSpeedMultiplier: Double = 1.0 {
        didSet { notifyIfNeeded() }
    }

    // ── 배경 테마 ──
    @AppStorage("backgroundTheme") var backgroundTheme: String = "auto" {
        didSet { notifyIfNeeded() }
    }

    // ── 커스텀 테마 (JSON) ──
    @AppStorage("customThemeJSON") var customThemeJSON: String = "" {
        didSet {
            _cachedCustomTheme = nil
            // notifyIfNeeded는 saveCustomTheme의 디바운스에서 처리
        }
    }

    private var _cachedCustomTheme: CustomThemeConfig?
    private var _themeSaveTimer: Timer?

    var customTheme: CustomThemeConfig {
        if let cached = _cachedCustomTheme { return cached }
        guard !customThemeJSON.isEmpty,
              let data = customThemeJSON.data(using: .utf8),
              let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else {
            return .default
        }
        _cachedCustomTheme = config
        return config
    }

    /// 테마 저장 — ColorPicker 드래그 중 초당 60회 호출될 수 있으므로
    /// 디바운스 적용하여 마지막 변경만 반영. UI 응답없음 방지.
    func saveCustomTheme(_ config: CustomThemeConfig) {
        // 캐시는 즉시 업데이트 (UI에서 바로 반영)
        _cachedCustomTheme = config

        // 디스크 저장 + 알림은 디바운스 (0.15초)
        _themeSaveTimer?.invalidate()
        _themeSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            guard let self else { return }
            do {
                let data = try JSONEncoder().encode(config)
                if let json = String(data: data, encoding: .utf8) {
                    self.customThemeJSON = json
                }
            } catch {
                CrashLogger.shared.error("Theme: Failed to encode custom theme — \(error.localizedDescription)")
            }
            self.notifyIfNeeded()
            Theme.invalidateFontCache()
        }
    }

    func exportThemeToFile() {
        let config = customTheme
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data: Data
        do {
            data = try encoder.encode(config)
        } catch {
            CrashLogger.shared.error("Theme: Failed to encode theme for export — \(error.localizedDescription)")
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "doffice_theme.json"
        panel.title = NSLocalizedString("settings.customtheme.export", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
            } catch {
                CrashLogger.shared.error("Theme: Failed to write theme to \(url.path) — \(error.localizedDescription)")
            }
        }
    }

    func importThemeFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("settings.customtheme.import", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let config = try JSONDecoder().decode(CustomThemeConfig.self, from: data)
                saveCustomTheme(config)
            } catch {
                CrashLogger.shared.error("Theme: Failed to import from \(url.lastPathComponent) — \(error.localizedDescription)")
            }
        }
    }

    // ── 파이프라인 설정 ──

    /// 역할별 프롬프트 자동 주입 비활성화 목록 (JSON 배열)
    @AppStorage("disabledPromptRoles") private var _disabledPromptRoles: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    var disabledPromptRoles: Set<String> {
        get {
            guard let data = _disabledPromptRoles.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(arr)
        }
        set {
            let arr = Array(newValue).sorted()
            if let data = try? JSONEncoder().encode(arr),
               let str = String(data: data, encoding: .utf8) {
                _disabledPromptRoles = str
            }
        }
    }

    func isPromptEnabled(for role: String) -> Bool {
        !disabledPromptRoles.contains(role)
    }

    func setPromptEnabled(_ enabled: Bool, for role: String) {
        var roles = disabledPromptRoles
        if enabled {
            roles.remove(role)
        } else {
            roles.insert(role)
        }
        disabledPromptRoles = roles
    }

    /// 파이프라인 순서 (JSON 배열, 빈 배열이면 기본 순서)
    @AppStorage("pipelineOrder") private var _pipelineOrder: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    static let defaultPipelineOrder = ["planner", "designer", "developerExecution", "reviewer", "qa", "reporter", "sre"]

    var pipelineOrder: [String] {
        get {
            guard let data = _pipelineOrder.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data),
                  !arr.isEmpty else { return Self.defaultPipelineOrder }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                _pipelineOrder = str
            }
        }
    }

    func resetPipelineOrder() {
        _pipelineOrder = "[]"
    }

    /// 커스텀 직업 목록 (JSON 배열)
    @AppStorage("customJobs") private var _customJobs: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    var customJobs: [CustomJob] {
        get {
            guard let data = _customJobs.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([CustomJob].self, from: data) else { return [] }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                _customJobs = str
            }
        }
    }

    func addCustomJob(_ job: CustomJob) {
        var jobs = customJobs
        jobs.append(job)
        customJobs = jobs
    }

    func removeCustomJob(id: String) {
        var jobs = customJobs
        jobs.removeAll { $0.id == id }
        customJobs = jobs
    }

    /// 삭제된 기본 직업 목록
    @AppStorage("deletedDefaultJobs") private var _deletedDefaultJobs: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    var deletedDefaultJobs: Set<String> {
        get {
            guard let data = _deletedDefaultJobs.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(arr)
        }
        set {
            let arr = Array(newValue).sorted()
            if let data = try? JSONEncoder().encode(arr),
               let str = String(data: data, encoding: .utf8) {
                _deletedDefaultJobs = str
            }
        }
    }

    func deleteDefaultJob(_ rawValue: String) {
        var deleted = deletedDefaultJobs
        deleted.insert(rawValue)
        deletedDefaultJobs = deleted
        // 파이프라인에서도 제거
        var order = pipelineOrder
        order.removeAll { $0 == rawValue }
        pipelineOrder = order
    }

    func restoreDefaultJob(_ rawValue: String) {
        var deleted = deletedDefaultJobs
        deleted.remove(rawValue)
        deletedDefaultJobs = deleted
    }

    // ── 자동화/성능 보호 설정 ──
    @AppStorage("reviewerMaxPasses") var reviewerMaxPasses: Int = 2 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("qaMaxPasses") var qaMaxPasses: Int = 2 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("automationRevisionLimit") var automationRevisionLimit: Int = 3 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("allowParallelSubagents") var allowParallelSubagents: Bool = false {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("terminalSidebarLightweight") var terminalSidebarLightweight: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 성능 모드 ──
    @AppStorage("performanceMode") var performanceMode: Bool = false {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("autoPerformanceMode") var autoPerformanceMode: Bool = true {
        didSet { notifyIfNeeded() }
    }

    var effectivePerformanceMode: Bool {
        if performanceMode { return true }
        if autoPerformanceMode {
            // 10개 이상 세션이면 자동 성능 모드
            return SessionManager.shared.tabs.count >= 10
        }
        return false
    }

    // ── 언어 설정 ──
    // "auto" = 시스템 언어 따르기, "ko"/"en"/"ja" = 강제 지정
    @AppStorage("appLanguage") var appLanguage: String = "auto" {
        didSet {
            notifyIfNeeded()
            applyLanguage()
        }
    }

    func applyLanguage() {
        if appLanguage == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        }
    }

    var currentLanguageLabel: String {
        switch appLanguage {
        case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
        case "en": return "English"
        case "ja": return "日本語"
        default: return NSLocalizedString("settings.language.system", comment: "")
        }
    }

    // ── 터미널 모드 ──
    @AppStorage("rawTerminalMode") var rawTerminalMode: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // ── 자동 새로고침 ──
    @AppStorage("autoRefreshOnSettingsChange") var autoRefreshOnSettingsChange: Bool = true {
        didSet { notifyIfNeeded() }
    }

    /// 설정 변경 후 새로고침 요청 (autoRefresh가 꺼져 있으면 알림만)
    @Published var pendingRefresh: Bool = false

    func requestRefreshIfNeeded() {
        if autoRefreshOnSettingsChange {
            NotificationCenter.default.post(name: .dofficeRefresh, object: nil)
        } else {
            pendingRefresh = true
        }
    }

    // ── 휴게실 가구 설정 (UI 빈도 낮음 → didSet 불필요) ──
    @AppStorage("breakRoomShowSofa") var breakRoomShowSofa: Bool = true
    @AppStorage("breakRoomShowCoffeeMachine") var breakRoomShowCoffeeMachine: Bool = true
    @AppStorage("breakRoomShowPlant") var breakRoomShowPlant: Bool = true
    @AppStorage("breakRoomShowSideTable") var breakRoomShowSideTable: Bool = true
    @AppStorage("breakRoomShowClock") var breakRoomShowClock: Bool = true
    @AppStorage("breakRoomShowPicture") var breakRoomShowPicture: Bool = true
    @AppStorage("breakRoomShowNeonSign") var breakRoomShowNeonSign: Bool = true
    @AppStorage("breakRoomShowRug") var breakRoomShowRug: Bool = true
    // 새 악세서리
    @AppStorage("breakRoomShowBookshelf") var breakRoomShowBookshelf: Bool = false
    @AppStorage("breakRoomShowAquarium") var breakRoomShowAquarium: Bool = false
    @AppStorage("breakRoomShowArcade") var breakRoomShowArcade: Bool = false
    @AppStorage("breakRoomShowWhiteboard") var breakRoomShowWhiteboard: Bool = false
    @AppStorage("breakRoomShowLamp") var breakRoomShowLamp: Bool = false
    @AppStorage("breakRoomShowCat") var breakRoomShowCat: Bool = false
    @AppStorage("breakRoomShowTV") var breakRoomShowTV: Bool = false
    @AppStorage("breakRoomShowFan") var breakRoomShowFan: Bool = false
    @AppStorage("breakRoomShowCalendar") var breakRoomShowCalendar: Bool = false
    @AppStorage("breakRoomShowPoster") var breakRoomShowPoster: Bool = false
    @AppStorage("breakRoomShowTrashcan") var breakRoomShowTrashcan: Bool = false
    @AppStorage("breakRoomShowCushion") var breakRoomShowCushion: Bool = false

    // ── 가구 위치 (JSON) ──
    @AppStorage("furniturePositionsJSON") var furniturePositionsJSON: String = ""

    // ── 앱/회사 이름 ──
    @AppStorage("appDisplayName") var appDisplayName: String = "도피스" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("companyName") var companyName: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportEnabled") var coffeeSupportEnabled: Bool = true {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportButtonTitle") var coffeeSupportButtonTitle: String = "후원하기" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportMessage") var coffeeSupportMessage: String = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다." {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportBankName") var coffeeSupportBankName: String = "카카오뱅크" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportAccountNumber") var coffeeSupportAccountNumber: String = "7777015832634" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportURL") var coffeeSupportURL: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportCopyValue") var coffeeSupportCopyValue: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportPresetVersion") private var coffeeSupportPresetVersion: Int = 0

    // ── 편집 모드 ──
    @Published var isEditMode: Bool = false

    // ── 보안 설정 ──
    @AppStorage("dailyCostLimit") var dailyCostLimit: Double = 0 {  // 0 = 무제한
        didSet { notifyIfNeeded() }
    }
    @AppStorage("perSessionCostLimit") var perSessionCostLimit: Double = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("costWarningAt80") var costWarningAt80: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 온보딩 ──
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // ── 결제일 알림 ──
    @AppStorage("billingDay") var billingDay: Int = 0  // 0 = 미설정, 1~31
    @AppStorage("billingLastNotifiedMonth") var billingLastNotifiedMonth: String = ""

    // ── 세션 잠금 ──
    @AppStorage("lockPIN") var lockPIN: String = ""
    @AppStorage("autoLockMinutes") var autoLockMinutes: Int = 0  // 0 = 비활성
    @Published var isLocked: Bool = false

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    var coffeeSupportDisplayTitle: String {
        let trimmed = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("coffee.default.button", comment: "") : trimmed
    }

    var trimmedCoffeeSupportBankName: String {
        coffeeSupportBankName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCoffeeSupportAccountNumber: String {
        coffeeSupportAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var coffeeSupportAccountDisplayText: String {
        let bank = trimmedCoffeeSupportBankName.isEmpty ? NSLocalizedString("coffee.default.bank", comment: "") : trimmedCoffeeSupportBankName
        let account = trimmedCoffeeSupportAccountNumber.isEmpty ? "7777015832634" : trimmedCoffeeSupportAccountNumber
        return "\(bank) \(account)"
    }

    var trimmedCoffeeSupportURL: String {
        coffeeSupportURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCoffeeSupportCopyValue: String {
        coffeeSupportCopyValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedCoffeeSupportURL: URL? {
        Self.normalizedCoffeeSupportURL(from: trimmedCoffeeSupportURL)
    }

    var hasCoffeeSupportDestination: Bool {
        !trimmedCoffeeSupportAccountNumber.isEmpty || normalizedCoffeeSupportURL != nil || !trimmedCoffeeSupportCopyValue.isEmpty
    }

    // ── 가구 위치 헬퍼 ──
    func furniturePosition(for id: String) -> CGPoint? {
        guard !furniturePositionsJSON.isEmpty,
              let data = furniturePositionsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data),
              let arr = dict[id], arr.count == 2 else { return nil }
        return CGPoint(x: arr[0], y: arr[1])
    }

    func setFurniturePosition(_ pos: CGPoint, for id: String) {
        var dict: [String: [Double]] = [:]
        if !furniturePositionsJSON.isEmpty,
           let data = furniturePositionsJSON.data(using: .utf8),
           let existing = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            dict = existing
        }
        dict[id] = [Double(pos.x), Double(pos.y)]
        if let data = try? JSONEncoder().encode(dict), let json = String(data: data, encoding: .utf8) {
            furniturePositionsJSON = json
        }
    }

    func resetFurniturePositions() {
        furniturePositionsJSON = ""
    }

    func ensureCoffeeSupportPreset() {
        let targetVersion = 1
        guard coffeeSupportPresetVersion < targetVersion else { return }

        let currentTitle = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentTitle.isEmpty || currentTitle == "커피 후원" {
            coffeeSupportButtonTitle = "후원하기"
        }

        let currentMessage = coffeeSupportMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentMessage.isEmpty || currentMessage == "이 앱이 도움이 되셨다면 커피 한 잔으로 응원해주세요." {
            coffeeSupportMessage = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다."
        }

        if trimmedCoffeeSupportBankName.isEmpty {
            coffeeSupportBankName = "카카오뱅크"
        }
        if trimmedCoffeeSupportAccountNumber.isEmpty {
            coffeeSupportAccountNumber = "7777015832634"
        }
        if trimmedCoffeeSupportCopyValue.isEmpty {
            coffeeSupportCopyValue = coffeeSupportAccountDisplayText
        }

        coffeeSupportPresetVersion = targetVersion
    }

    func coffeeSupportURL(for tier: CoffeeSupportTier) -> URL? {
        Self.normalizedCoffeeSupportURL(from: renderCoffeeSupportTemplate(trimmedCoffeeSupportURL, tier: tier))
    }

    func coffeeSupportCopyText(for tier: CoffeeSupportTier) -> String {
        renderCoffeeSupportTemplate(trimmedCoffeeSupportCopyValue, tier: tier)
    }

    private func renderCoffeeSupportTemplate(_ template: String, tier: CoffeeSupportTier) -> String {
        guard !template.isEmpty else { return "" }
        let replacements: [String: String] = [
            "{{amount}}": "\(tier.amount)",
            "{{amount_text}}": tier.amountLabel,
            "{{tier}}": tier.title,
            "{{app_name}}": appDisplayName
        ]

        var rendered = template
        for (token, value) in replacements {
            rendered = rendered.replacingOccurrences(of: token, with: value)
        }
        return rendered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedCoffeeSupportURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        return URL(string: "https://" + trimmed)
    }

    // ── 레이아웃 프리셋 ──

    struct LayoutPreset: Codable, Identifiable {
        let id: String
        var name: String
        var viewModeRaw: Int
        var sidebarWidth: Double
        var isDarkMode: Bool
        var fontSizeScale: Double
    }

    @AppStorage("layoutPresets") var layoutPresetsData: Data = Data()

    var layoutPresets: [LayoutPreset] {
        get { (try? JSONDecoder().decode([LayoutPreset].self, from: layoutPresetsData)) ?? [] }
        set { layoutPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func saveCurrentAsPreset(name: String, viewModeRaw: Int, sidebarWidth: Double) {
        var presets = layoutPresets
        let preset = LayoutPreset(
            id: UUID().uuidString, name: name,
            viewModeRaw: viewModeRaw, sidebarWidth: sidebarWidth,
            isDarkMode: isDarkMode, fontSizeScale: fontSizeScale
        )
        presets.append(preset)
        layoutPresets = presets
    }

    func applyPreset(_ preset: LayoutPreset) {
        isDarkMode = preset.isDarkMode
        fontSizeScale = preset.fontSizeScale
    }

    func deletePreset(_ id: String) {
        var presets = layoutPresets
        presets.removeAll { $0.id == id }
        layoutPresets = presets
    }
}
