import SwiftUI
import DesignSystem
import DofficeKit

enum SecretKeyResult { case none, success, wrong }

// MARK: - Theme Color Defaults

/// 다크/라이트 모드별 기본 색상 hex 값
enum ThemeColorDefaults {
    struct ModePair { let dark: String; let light: String }

    // Background
    static let bg = ModePair(dark: "000000", light: "fafafa")
    static let bgCard = ModePair(dark: "0a0a0a", light: "ffffff")
    static let bgSurface = ModePair(dark: "111111", light: "f5f5f5")
    static let bgTertiary = ModePair(dark: "1a1a1a", light: "ebebeb")

    // Text
    static let textPrimary = ModePair(dark: "ededed", light: "171717")
    static let textSecondary = ModePair(dark: "a1a1a1", light: "636363")
    static let textDim = ModePair(dark: "707070", light: "8f8f8f")
    static let textMuted = ModePair(dark: "484848", light: "b0b0b0")

    // Border
    static let border = ModePair(dark: "282828", light: "e5e5e5")
    static let borderStrong = ModePair(dark: "3e3e3e", light: "d0d0d0")

    // Semantic
    static let green = ModePair(dark: "3ecf8e", light: "18a058")
    static let red = ModePair(dark: "f14c4c", light: "e5484d")
    static let yellow = ModePair(dark: "f5a623", light: "ca8a04")
    static let purple = ModePair(dark: "8e4ec6", light: "6e56cf")
    static let orange = ModePair(dark: "f97316", light: "e5560a")
    static let cyan = ModePair(dark: "06b6d4", light: "0891b2")
    static let pink = ModePair(dark: "e54d9e", light: "d23197")

    // Accent/Gradient defaults
    static let accent = "3291ff"
    static let gradientStart = "3291ff"
    static let gradientEnd = "8e4ec6"

    /// hex 값 또는 다크/라이트 모드에 따른 기본값 반환
    static func resolve(_ hex: String?, pair: ModePair, isDark: Bool) -> Color {
        if let hex, !hex.isEmpty { return Color(hex: hex) }
        return Color(hex: isDark ? pair.dark : pair.light)
    }
}

// MARK: - SettingsViewModel

/// SettingsView의 테마 색상 초기화, pending 값, 캐시 계산 등을 담당합니다.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Editing State

    @Published var editingAppName = ""
    @Published var editingCompanyName = ""
    @Published var selectedSettingsTab = 0
    @Published var cacheSize = NSLocalizedString("settings.calculating", comment: "")
    @Published var cliCheckDone = false

    // MARK: - Pending Values (Restart Required)

    @Published var pendingLanguage: String?
    @Published var pendingThemeMode: String?
    @Published var pendingFontScale: Double?
    @Published var pendingIconStyle = ""

    // MARK: - Dialog State

    @Published var showClearConfirm = false
    @Published var clearAllMode = false
    @Published var showTokenResetConfirm = false
    @Published var showTemplateResetConfirm = false
    @Published var showLanguageRestartAlert = false
    @Published var showThemeRestartAlert = false
    @Published var showFontRestartAlert = false
    @Published var showUpdateSheet = false
    @Published var showImportError = false
    @Published var showIconChangeAlert = false
    @Published var systemKillResult: String?

    // MARK: - Plugin State

    @Published var pluginSourceInput = ""
    @Published var showPluginUninstallConfirm = false
    @Published var pluginToUninstall: PluginEntry?
    @Published var showPluginScaffold = false
    @Published var scaffoldName = ""
    @Published var expandedPluginId: String?
    @Published var showDebugConsole = false

    // MARK: - Secret Key

    @Published var secretKeyInput = ""
    @Published var secretKeyResult: SecretKeyResult = .none

    // MARK: - Custom Job

    @Published var newCustomJobName = ""
    @Published var selectedTemplateKind: AutomationTemplateKind = .planner

    // MARK: - Custom Theme Colors

    @Published var customAccentColor: Color = Theme.accent
    @Published var customGradientStart = Color(hex: ThemeColorDefaults.gradientStart)
    @Published var customGradientEnd = Color(hex: ThemeColorDefaults.gradientEnd)
    @Published var customUseGradient = false
    @Published var customFontName = ""
    @Published var customFontSize: Double = 11.0

    // Background colors
    @Published var customBgColor = Color(hex: ThemeColorDefaults.bg.dark)
    @Published var customBgCardColor = Color(hex: ThemeColorDefaults.bgCard.dark)
    @Published var customBgSurfaceColor = Color(hex: ThemeColorDefaults.bgSurface.dark)
    @Published var customBgTertiaryColor = Color(hex: ThemeColorDefaults.bgTertiary.dark)

    // Text colors
    @Published var customTextPrimaryColor = Color(hex: ThemeColorDefaults.textPrimary.dark)
    @Published var customTextSecondaryColor = Color(hex: ThemeColorDefaults.textSecondary.dark)
    @Published var customTextDimColor = Color(hex: ThemeColorDefaults.textDim.dark)
    @Published var customTextMutedColor = Color(hex: ThemeColorDefaults.textMuted.dark)

    // Border colors
    @Published var customBorderColor = Color(hex: ThemeColorDefaults.border.dark)
    @Published var customBorderStrongColor = Color(hex: ThemeColorDefaults.borderStrong.dark)

    // Semantic colors
    @Published var customGreenColor = Color(hex: ThemeColorDefaults.green.dark)
    @Published var customRedColor = Color(hex: ThemeColorDefaults.red.dark)
    @Published var customYellowColor = Color(hex: ThemeColorDefaults.yellow.dark)
    @Published var customPurpleColor = Color(hex: ThemeColorDefaults.purple.dark)
    @Published var customOrangeColor = Color(hex: ThemeColorDefaults.orange.dark)
    @Published var customCyanColor = Color(hex: ThemeColorDefaults.cyan.dark)
    @Published var customPinkColor = Color(hex: ThemeColorDefaults.pink.dark)

    // Expansion toggles
    @Published var showBgColors = false
    @Published var showTextColors = false
    @Published var showBorderColors = false
    @Published var showSemanticColors = false

    // MARK: - Initialization

    /// 설정 화면 진입 시 현재 테마 값으로 색상 상태를 초기화합니다.
    func hydrateFromSettings(_ settings: AppSettings) {
        editingAppName = settings.appDisplayName
        editingCompanyName = settings.companyName
        calculateCacheSize()

        let ct = settings.customTheme
        let isDark = settings.isDarkMode

        // Accent/Gradient
        if let hex = ct.accentHex, !hex.isEmpty { customAccentColor = Color(hex: hex) }
        if let hex = ct.gradientStartHex, !hex.isEmpty { customGradientStart = Color(hex: hex) }
        if let hex = ct.gradientEndHex, !hex.isEmpty { customGradientEnd = Color(hex: hex) }
        customUseGradient = ct.useGradient
        customFontName = ct.fontName ?? ""
        customFontSize = ct.fontSize ?? 11.0

        // Background
        customBgColor = ThemeColorDefaults.resolve(ct.bgHex, pair: ThemeColorDefaults.bg, isDark: isDark)
        customBgCardColor = ThemeColorDefaults.resolve(ct.bgCardHex, pair: ThemeColorDefaults.bgCard, isDark: isDark)
        customBgSurfaceColor = ThemeColorDefaults.resolve(ct.bgSurfaceHex, pair: ThemeColorDefaults.bgSurface, isDark: isDark)
        customBgTertiaryColor = ThemeColorDefaults.resolve(ct.bgTertiaryHex, pair: ThemeColorDefaults.bgTertiary, isDark: isDark)

        // Text
        customTextPrimaryColor = ThemeColorDefaults.resolve(ct.textPrimaryHex, pair: ThemeColorDefaults.textPrimary, isDark: isDark)
        customTextSecondaryColor = ThemeColorDefaults.resolve(ct.textSecondaryHex, pair: ThemeColorDefaults.textSecondary, isDark: isDark)
        customTextDimColor = ThemeColorDefaults.resolve(ct.textDimHex, pair: ThemeColorDefaults.textDim, isDark: isDark)
        customTextMutedColor = ThemeColorDefaults.resolve(ct.textMutedHex, pair: ThemeColorDefaults.textMuted, isDark: isDark)

        // Border
        customBorderColor = ThemeColorDefaults.resolve(ct.borderHex, pair: ThemeColorDefaults.border, isDark: isDark)
        customBorderStrongColor = ThemeColorDefaults.resolve(ct.borderStrongHex, pair: ThemeColorDefaults.borderStrong, isDark: isDark)

        // Semantic
        customGreenColor = ThemeColorDefaults.resolve(ct.greenHex, pair: ThemeColorDefaults.green, isDark: isDark)
        customRedColor = ThemeColorDefaults.resolve(ct.redHex, pair: ThemeColorDefaults.red, isDark: isDark)
        customYellowColor = ThemeColorDefaults.resolve(ct.yellowHex, pair: ThemeColorDefaults.yellow, isDark: isDark)
        customPurpleColor = ThemeColorDefaults.resolve(ct.purpleHex, pair: ThemeColorDefaults.purple, isDark: isDark)
        customOrangeColor = ThemeColorDefaults.resolve(ct.orangeHex, pair: ThemeColorDefaults.orange, isDark: isDark)
        customCyanColor = ThemeColorDefaults.resolve(ct.cyanHex, pair: ThemeColorDefaults.cyan, isDark: isDark)
        customPinkColor = ThemeColorDefaults.resolve(ct.pinkHex, pair: ThemeColorDefaults.pink, isDark: isDark)
    }

    /// 다크/라이트 모드 전환 시 커스텀 hex가 없는 색상만 기본값으로 업데이트합니다.
    func syncColorsForMode(_ isDark: Bool, theme: CustomThemeConfig) {
        let pairs: [(hex: String?, pair: ThemeColorDefaults.ModePair, update: (Color) -> Void)] = [
            (theme.bgHex, ThemeColorDefaults.bg, { [weak self] in self?.customBgColor = $0 }),
            (theme.bgCardHex, ThemeColorDefaults.bgCard, { [weak self] in self?.customBgCardColor = $0 }),
            (theme.bgSurfaceHex, ThemeColorDefaults.bgSurface, { [weak self] in self?.customBgSurfaceColor = $0 }),
            (theme.bgTertiaryHex, ThemeColorDefaults.bgTertiary, { [weak self] in self?.customBgTertiaryColor = $0 }),
            (theme.textPrimaryHex, ThemeColorDefaults.textPrimary, { [weak self] in self?.customTextPrimaryColor = $0 }),
            (theme.textSecondaryHex, ThemeColorDefaults.textSecondary, { [weak self] in self?.customTextSecondaryColor = $0 }),
            (theme.textDimHex, ThemeColorDefaults.textDim, { [weak self] in self?.customTextDimColor = $0 }),
            (theme.textMutedHex, ThemeColorDefaults.textMuted, { [weak self] in self?.customTextMutedColor = $0 }),
            (theme.borderHex, ThemeColorDefaults.border, { [weak self] in self?.customBorderColor = $0 }),
            (theme.borderStrongHex, ThemeColorDefaults.borderStrong, { [weak self] in self?.customBorderStrongColor = $0 }),
            (theme.greenHex, ThemeColorDefaults.green, { [weak self] in self?.customGreenColor = $0 }),
            (theme.redHex, ThemeColorDefaults.red, { [weak self] in self?.customRedColor = $0 }),
            (theme.yellowHex, ThemeColorDefaults.yellow, { [weak self] in self?.customYellowColor = $0 }),
            (theme.purpleHex, ThemeColorDefaults.purple, { [weak self] in self?.customPurpleColor = $0 }),
            (theme.orangeHex, ThemeColorDefaults.orange, { [weak self] in self?.customOrangeColor = $0 }),
            (theme.cyanHex, ThemeColorDefaults.cyan, { [weak self] in self?.customCyanColor = $0 }),
            (theme.pinkHex, ThemeColorDefaults.pink, { [weak self] in self?.customPinkColor = $0 }),
        ]

        for entry in pairs {
            if entry.hex == nil || entry.hex!.isEmpty {
                entry.update(Color(hex: isDark ? entry.pair.dark : entry.pair.light))
            }
        }
    }

    // MARK: - Cache Management

    func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var totalBytes: Int64 = 0
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dofficeDir = appSupport.appendingPathComponent("Doffice")
                if let enumerator = FileManager.default.enumerator(at: dofficeDir, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let url as URL in enumerator {
                        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            totalBytes += Int64(size)
                        }
                    }
                }
            }
            let udKeys = ["DofficeTokenHistory", "DofficeCharacters", "DofficeCharacterManualUnlocks", "DofficeAchievements"]
            for key in udKeys {
                if let data = UserDefaults.standard.data(forKey: key) {
                    totalBytes += Int64(data.count)
                } else if let dict = UserDefaults.standard.dictionary(forKey: key),
                          let data = try? JSONSerialization.data(withJSONObject: dict) {
                    totalBytes += Int64(data.count)
                }
            }
            DispatchQueue.main.async {
                self?.cacheSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            }
        }
    }
}
