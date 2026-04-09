import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - App Settings (전역 설정)
// ═══════════════════════════════════════════════════════

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    public init() {}

    // ── Batch Update Support ──
    // Prevents multiple objectWillChange.send() calls during bulk settings changes.
    // Individual didSet calls still fire for single-property changes (needed for @ObservedObject).
    private var _batchUpdateInProgress = false

    /// Perform multiple settings changes with only a single objectWillChange notification.
    /// Use this from settings UI when changing multiple properties at once.
    public func performBatchUpdate(_ changes: () -> Void) {
        _batchUpdateInProgress = true
        changes()
        _batchUpdateInProgress = false
        objectWillChange.send()
        Theme.invalidateFontCache()
    }

    /// Sends objectWillChange only if not inside a batch update.
    private func notifyIfNeeded() {
        guard !_batchUpdateInProgress else { return }
        objectWillChange.send()
    }

    // MARK: - Theme & Appearance

    @AppStorage("isDarkMode") public var isDarkMode: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // themeMode: "light" | "dark" | "custom"
    // 빈 문자열이면 isDarkMode에서 파생 (기존 사용자 마이그레이션)
    @AppStorage("themeMode") private var _themeMode: String = ""

    public var themeMode: String {
        get { _themeMode.isEmpty ? (isDarkMode ? "dark" : "light") : _themeMode }
        set {
            _themeMode = newValue
            if newValue == "light" { isDarkMode = false }
            else if newValue == "dark" { isDarkMode = true }
            notifyIfNeeded()
        }
    }
    @AppStorage("fontSizeScale") public var fontSizeScale: Double = 1.5 {
        didSet { notifyIfNeeded() }
    }

    // MARK: - Office

    // ── 오피스 뷰 모드 ──
    @AppStorage("officeViewMode") public var officeViewMode: String = "grid" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("officePreset") public var officePreset: String = "cozy" {
        didSet { notifyIfNeeded() }
    }

    // ── 배경 테마 ──
    @AppStorage("backgroundTheme") public var backgroundTheme: String = "auto" {
        didSet { notifyIfNeeded() }
    }

    // ── 커스텀 테마 (JSON) ──
    @AppStorage("customThemeJSON") public var customThemeJSON: String = "" {
        didSet {
            _cachedCustomTheme = nil
            notifyIfNeeded()
        }
    }

    private var _cachedCustomTheme: CustomThemeConfig?

    public var customTheme: CustomThemeConfig {
        if let cached = _cachedCustomTheme { return cached }
        guard !customThemeJSON.isEmpty,
              let data = customThemeJSON.data(using: .utf8),
              let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else {
            return .default
        }
        _cachedCustomTheme = config
        return config
    }

    // MARK: - Automation

    // ── 파이프라인 설정 ──

    @AppStorage("disabledPromptRoles") private var _disabledPromptRoles: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    public var disabledPromptRoles: Set<String> {
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

    public func isPromptEnabled(for role: String) -> Bool {
        !disabledPromptRoles.contains(role)
    }

    public func setPromptEnabled(_ enabled: Bool, for role: String) {
        var roles = disabledPromptRoles
        if enabled { roles.remove(role) } else { roles.insert(role) }
        disabledPromptRoles = roles
    }

    @AppStorage("pipelineOrder") private var _pipelineOrder: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    public static let defaultPipelineOrder = ["planner", "designer", "developerExecution", "reviewer", "qa", "reporter", "sre"]

    public var pipelineOrder: [String] {
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

    public func resetPipelineOrder() { _pipelineOrder = "[]" }

    @AppStorage("customJobs") private var _customJobs: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    public var customJobs: [CustomJob] {
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

    public func addCustomJob(_ job: CustomJob) {
        var jobs = customJobs; jobs.append(job); customJobs = jobs
    }

    public func removeCustomJob(id: String) {
        var jobs = customJobs; jobs.removeAll { $0.id == id }; customJobs = jobs
    }

    @AppStorage("deletedDefaultJobs") private var _deletedDefaultJobs: String = "[]" {
        didSet { notifyIfNeeded() }
    }

    public var deletedDefaultJobs: Set<String> {
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

    public func deleteDefaultJob(_ rawValue: String) {
        var deleted = deletedDefaultJobs; deleted.insert(rawValue); deletedDefaultJobs = deleted
        var order = pipelineOrder; order.removeAll { $0 == rawValue }; pipelineOrder = order
    }

    public func restoreDefaultJob(_ rawValue: String) {
        var deleted = deletedDefaultJobs; deleted.remove(rawValue); deletedDefaultJobs = deleted
    }

    // ── 자동화/성능 보호 설정 ──
    @AppStorage("reviewerMaxPasses") public var reviewerMaxPasses: Int = 2 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("qaMaxPasses") public var qaMaxPasses: Int = 2 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("automationRevisionLimit") public var automationRevisionLimit: Int = 3 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("allowParallelSubagents") public var allowParallelSubagents: Bool = false {
        didSet { notifyIfNeeded() }
    }
    /// 비개발자 역할(리뷰어, QA 등)이 여러 세션을 동시에 담당할 수 있는지 여부
    @AppStorage("allowMultiRole") public var allowMultiRole: Bool = true {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("terminalSidebarLightweight") public var terminalSidebarLightweight: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 성능 모드 ──
    @AppStorage("performanceMode") public var performanceMode: Bool = false {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("autoPerformanceMode") public var autoPerformanceMode: Bool = true {
        didSet { notifyIfNeeded() }
    }

    /// 외부에서 세션 수를 주입 (DofficeKit에서 SessionManager.shared.tabs.count 바인딩)
    public var activeTabCount: Int = 0

    public var effectivePerformanceMode: Bool {
        if performanceMode { return true }
        if autoPerformanceMode {
            // 10개 이상 세션이면 자동 성능 모드
            return activeTabCount >= 10
        }
        return false
    }

    // ── 언어 설정 ──
    // "auto" = 시스템 언어 따르기, "ko"/"en"/"ja" = 강제 지정
    @AppStorage("appLanguage") public var appLanguage: String = "auto" {
        didSet {
            notifyIfNeeded()
            applyLanguage()
        }
    }

    public func applyLanguage() {
        if appLanguage == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        }
    }

    public var currentLanguageLabel: String {
        switch appLanguage {
        case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
        case "en": return "English"
        case "ja": return "日本語"
        default: return NSLocalizedString("settings.language.system", comment: "")
        }
    }

    // MARK: - Terminal

    // ── 터미널 모드 ──
    @AppStorage("rawTerminalMode") public var rawTerminalMode: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // ── 터미널 스크롤백 ──
    @AppStorage("terminalMaxScrollback") public var terminalMaxScrollback: Int = 5000 {
        didSet { notifyIfNeeded() }
    }

    // ── 자동 새로고침 ──
    @AppStorage("autoRefreshOnSettingsChange") public var autoRefreshOnSettingsChange: Bool = true {
        didSet { notifyIfNeeded() }
    }

    /// 설정 변경 후 새로고침 요청 (autoRefresh가 꺼져 있으면 알림만)
    @Published public var pendingRefresh: Bool = false

    public func requestRefreshIfNeeded() {
        if autoRefreshOnSettingsChange {
            NotificationCenter.default.post(name: .dofficeRefresh, object: nil)
        } else {
            pendingRefresh = true
        }
    }

    // ── 휴게실 가구 설정 (UI 빈도 낮음 → didSet 불필요) ──
    @AppStorage("breakRoomShowSofa") public var breakRoomShowSofa: Bool = true
    @AppStorage("breakRoomShowCoffeeMachine") public var breakRoomShowCoffeeMachine: Bool = true
    @AppStorage("breakRoomShowPlant") public var breakRoomShowPlant: Bool = true
    @AppStorage("breakRoomShowSideTable") public var breakRoomShowSideTable: Bool = true
    @AppStorage("breakRoomShowClock") public var breakRoomShowClock: Bool = true
    @AppStorage("breakRoomShowPicture") public var breakRoomShowPicture: Bool = true
    @AppStorage("breakRoomShowNeonSign") public var breakRoomShowNeonSign: Bool = true
    @AppStorage("breakRoomShowRug") public var breakRoomShowRug: Bool = true
    // 새 악세서리
    @AppStorage("breakRoomShowBookshelf") public var breakRoomShowBookshelf: Bool = false
    @AppStorage("breakRoomShowAquarium") public var breakRoomShowAquarium: Bool = false
    @AppStorage("breakRoomShowArcade") public var breakRoomShowArcade: Bool = false
    @AppStorage("breakRoomShowWhiteboard") public var breakRoomShowWhiteboard: Bool = false
    @AppStorage("breakRoomShowLamp") public var breakRoomShowLamp: Bool = false
    @AppStorage("breakRoomShowCat") public var breakRoomShowCat: Bool = false
    @AppStorage("breakRoomShowTV") public var breakRoomShowTV: Bool = false
    @AppStorage("breakRoomShowFan") public var breakRoomShowFan: Bool = false
    @AppStorage("breakRoomShowCalendar") public var breakRoomShowCalendar: Bool = false
    @AppStorage("breakRoomShowPoster") public var breakRoomShowPoster: Bool = false
    @AppStorage("breakRoomShowTrashcan") public var breakRoomShowTrashcan: Bool = false
    @AppStorage("breakRoomShowCushion") public var breakRoomShowCushion: Bool = false

    // ── 가구 위치 (JSON) ──
    @AppStorage("furniturePositionsJSON") public var furniturePositionsJSON: String = ""

    // ── 앱/회사 이름 ──
    @AppStorage("appDisplayName") public var appDisplayName: String = "도피스" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("companyName") public var companyName: String = "" {
        didSet { notifyIfNeeded() }
    }
    // MARK: - Coffee Support

    @AppStorage("coffeeSupportEnabled") public var coffeeSupportEnabled: Bool = true {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportButtonTitle") public var coffeeSupportButtonTitle: String = "후원하기" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportMessage") public var coffeeSupportMessage: String = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다." {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportBankName") public var coffeeSupportBankName: String = "카카오뱅크" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportAccountNumber") public var coffeeSupportAccountNumber: String = "7777015832634" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportURL") public var coffeeSupportURL: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportCopyValue") public var coffeeSupportCopyValue: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportPresetVersion") var coffeeSupportPresetVersion: Int = 0

    // ── 편집 모드 ──
    @Published public var isEditMode: Bool = false

    // MARK: - Security

    // ── 보안 설정 ──
    @AppStorage("dailyCostLimit") public var dailyCostLimit: Double = 0 {  // 0 = 무제한
        didSet { notifyIfNeeded() }
    }
    @AppStorage("perSessionCostLimit") public var perSessionCostLimit: Double = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("costWarningAt80") public var costWarningAt80: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 온보딩 ──
    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // ── 앱 아이콘 ──
    @AppStorage("appIconStyle") public var appIconStyle: String = "classic" {
        didSet { notifyIfNeeded() }
    }

    // MARK: - Token Limits

    // ── 캐릭터 속도 ──
    /// 캐릭터 이동 속도 배율 (0.5 = 느림, 1.0 = 보통, 2.0 = 빠름)
    @AppStorage("characterSpeedMultiplier") public var characterSpeedMultiplier: Double = 1.0 {
        didSet { notifyIfNeeded() }
    }

    // ── 토큰 보호 ──
    @AppStorage("tokenProtectionEnabled") public var tokenProtectionEnabled: Bool = true {
        didSet { notifyIfNeeded() }
    }
    /// Provider별 세션 토큰 한도 (0 = 무제한)
    @AppStorage("claudeSessionTokenLimit") public var claudeSessionTokenLimit: Int = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("codexSessionTokenLimit") public var codexSessionTokenLimit: Int = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("geminiSessionTokenLimit") public var geminiSessionTokenLimit: Int = 0 {
        didSet { notifyIfNeeded() }
    }
    /// Provider별 주간 토큰 한도 (플랜 기반, 0 = 미설정 → 글로벌 한도 사용)
    @AppStorage("claudeWeeklyLimit") public var claudeWeeklyLimit: Int = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("codexWeeklyLimit") public var codexWeeklyLimit: Int = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("geminiWeeklyLimit") public var geminiWeeklyLimit: Int = 0 {
        didSet { notifyIfNeeded() }
    }
    /// Provider별 선택된 플랜 이름
    @AppStorage("claudePlanName") public var claudePlanName: String = ""
    @AppStorage("codexPlanName") public var codexPlanName: String = ""
    @AppStorage("geminiPlanName") public var geminiPlanName: String = ""

    // ── 결제일 알림 ──
    @AppStorage("billingDay") public var billingDay: Int = 0  // 0 = 미설정, 1~31
    @AppStorage("billingLastNotifiedMonth") public var billingLastNotifiedMonth: String = ""

    // ── 세션 잠금 ──
    @AppStorage("lockPIN") public var lockPIN: String = ""
    @AppStorage("autoLockMinutes") public var autoLockMinutes: Int = 0  // 0 = 비활성
    @Published public var isLocked: Bool = false

    public var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    // ── 가구 위치 헬퍼 ──
    public func furniturePosition(for id: String) -> CGPoint? {
        guard !furniturePositionsJSON.isEmpty,
              let data = furniturePositionsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data),
              let arr = dict[id], arr.count == 2 else { return nil }
        return CGPoint(x: arr[0], y: arr[1])
    }

    public func setFurniturePosition(_ pos: CGPoint, for id: String) {
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

    public func resetFurniturePositions() {
        furniturePositionsJSON = ""
    }

    // ── 레이아웃 프리셋 ──

    public struct LayoutPreset: Codable, Identifiable {
        public let id: String
        public var name: String
        public var viewModeRaw: Int
        public var sidebarWidth: Double
        public var isDarkMode: Bool
        public var fontSizeScale: Double

        public init(id: String, name: String, viewModeRaw: Int, sidebarWidth: Double, isDarkMode: Bool, fontSizeScale: Double) {
            self.id = id
            self.name = name
            self.viewModeRaw = viewModeRaw
            self.sidebarWidth = sidebarWidth
            self.isDarkMode = isDarkMode
            self.fontSizeScale = fontSizeScale
        }
    }

    @AppStorage("layoutPresets") public var layoutPresetsData: Data = Data()

    public var layoutPresets: [LayoutPreset] {
        get { (try? JSONDecoder().decode([LayoutPreset].self, from: layoutPresetsData)) ?? [] }
        set { layoutPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    public func saveCurrentAsPreset(name: String, viewModeRaw: Int, sidebarWidth: Double) {
        var presets = layoutPresets
        let preset = LayoutPreset(
            id: UUID().uuidString, name: name,
            viewModeRaw: viewModeRaw, sidebarWidth: sidebarWidth,
            isDarkMode: isDarkMode, fontSizeScale: fontSizeScale
        )
        presets.append(preset)
        layoutPresets = presets
    }

    public func applyPreset(_ preset: LayoutPreset) {
        isDarkMode = preset.isDarkMode
        fontSizeScale = preset.fontSizeScale
    }

    public func deletePreset(_ id: String) {
        var presets = layoutPresets
        presets.removeAll { $0.id == id }
        layoutPresets = presets
    }
}
