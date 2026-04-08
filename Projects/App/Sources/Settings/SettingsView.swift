import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

// ═══════════════════════════════════════════════════════
// MARK: - Settings View
// ═══════════════════════════════════════════════════════

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @ObservedObject var tokenTracker = TokenTracker.shared
    @ObservedObject var templateStore = AutomationTemplateStore.shared
    @State var editingAppName: String = ""
    @State var editingCompanyName: String = ""

    @State var selectedSettingsTab = 0
    @State var selectedTemplateKind: AutomationTemplateKind = .planner
    @State var cacheSize: String = NSLocalizedString("settings.calculating", comment: "")
    @State var showClearConfirm = false
    @State var clearAllMode = false
    @State var showTokenResetConfirm = false
    @State var showTemplateResetConfirm = false
    @State var newCustomJobName: String = ""
    @State var showLanguageRestartAlert = false
    @State var pendingLanguage: String?
    @State var showThemeRestartAlert = false
    @State var pendingThemeMode: String?
    @State var showFontRestartAlert = false
    @State var pendingFontScale: Double?
    @State var showUpdateSheet = false

    // Custom Theme
    @State var customAccentColor: Color = Theme.accent
    @State var customGradientStart: Color = Color(hex: "3291ff")
    @State var customGradientEnd: Color = Color(hex: "8e4ec6")
    @State var customUseGradient: Bool = false
    @State var customFontName: String = ""
    @State var customFontSize: Double = 11.0
    @State var showImportError = false

    // Custom Theme - Background colors
    @State var customBgColor: Color = Color(hex: "000000")
    @State var customBgCardColor: Color = Color(hex: "0a0a0a")
    @State var customBgSurfaceColor: Color = Color(hex: "111111")
    @State var customBgTertiaryColor: Color = Color(hex: "1a1a1a")
    // Custom Theme - Text colors
    @State var customTextPrimaryColor: Color = Color(hex: "ededed")
    @State var customTextSecondaryColor: Color = Color(hex: "a1a1a1")
    @State var customTextDimColor: Color = Color(hex: "707070")
    @State var customTextMutedColor: Color = Color(hex: "484848")
    // Custom Theme - Border colors
    @State var customBorderColor: Color = Color(hex: "282828")
    @State var customBorderStrongColor: Color = Color(hex: "3e3e3e")
    // Custom Theme - Semantic colors
    @State var customGreenColor: Color = Color(hex: "3ecf8e")
    @State var customRedColor: Color = Color(hex: "f14c4c")
    @State var customYellowColor: Color = Color(hex: "f5a623")
    @State var customPurpleColor: Color = Color(hex: "8e4ec6")
    @State var customOrangeColor: Color = Color(hex: "f97316")
    @State var customCyanColor: Color = Color(hex: "06b6d4")
    @State var customPinkColor: Color = Color(hex: "e54d9e")
    // Expanded state for color groups
    @State var showBgColors: Bool = false
    @State var showTextColors: Bool = false
    @State var showBorderColors: Bool = false
    @State var showSemanticColors: Bool = false

    // CLI check trigger
    @State var cliCheckDone = false

    // Plugin
    @ObservedObject var pluginManager = PluginManager.shared
    @State var pluginSourceInput: String = ""
    @State var showPluginUninstallConfirm = false
    @State var pluginToUninstall: PluginEntry?
    @State var showPluginScaffold = false
    @State var scaffoldName: String = ""
    @State var expandedPluginId: String?   // 상세 정보 토글

    // Secret Key
    @State var secretKeyInput = ""
    @State var secretKeyResult: SecretKeyResult = .none

    // App Icon
    @State var showIconChangeAlert = false
    @State var pendingIconStyle = ""

    let settingsTabs: [(String, String)] = [
        ("slider.horizontal.3", NSLocalizedString("settings.general", comment: "")), ("paintbrush.fill", NSLocalizedString("settings.display", comment: "")), ("building.2.fill", NSLocalizedString("settings.office", comment: "")),
        ("bolt.fill", NSLocalizedString("settings.token", comment: "")), ("externaldrive.fill", NSLocalizedString("settings.data", comment: "")), ("doc.text.fill", NSLocalizedString("settings.template", comment: "")),
        ("puzzlepiece.fill", NSLocalizedString("settings.plugin", comment: "")),
        ("cup.and.saucer.fill", NSLocalizedString("settings.support", comment: "")), ("lock.shield.fill", NSLocalizedString("settings.security", comment: "")),
        ("keyboard.fill", NSLocalizedString("settings.shortcuts", comment: ""))
    ]

    var body: some View {
        DSModalShell {
            DSModalHeader(
                icon: "gearshape.fill",
                iconColor: Theme.textSecondary,
                title: NSLocalizedString("settings.title", comment: ""),
                onClose: { dismiss() }
            )
            .keyboardShortcut(.escape)

            Rectangle().fill(Theme.border).frame(height: 1)

            HStack(spacing: 0) {
                // 세로 사이드바
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(Array(settingsTabs.enumerated()), id: \.offset) { index, tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) { selectedSettingsTab = index }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: tab.0)
                                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                                        .foregroundColor(index == selectedSettingsTab ? Theme.accent : Theme.textDim)
                                        .frame(width: 18)
                                    Text(tab.1)
                                        .font(Theme.mono(10, weight: index == selectedSettingsTab ? .semibold : .regular))
                                        .foregroundColor(index == selectedSettingsTab ? Theme.textPrimary : Theme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                                        .fill(index == selectedSettingsTab ? Theme.bgSurface : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
                .frame(width: 170)
                .background(Theme.bgCard)

                Rectangle().fill(Theme.border).frame(width: 1)

                // 탭 내용
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Theme.sp4) {
                        switch selectedSettingsTab {
                        case 0: generalTab
                        case 1: displayTab
                        case 2: officeTab
                        case 3: tokenTab
                        case 4: dataTab
                        case 5: templateTab
                        case 6: pluginTab
                        case 7: supportTab
                        case 8: securityTab
                        case 9: ShortcutsSettingsTab()
                        default: generalTab
                        }
                    }
                    .padding(Theme.sp5)
                }
            }
        }
        .frame(width: 720, height: 600)
        .background(Theme.bg)
        .onAppear {
            settings.ensureCoffeeSupportPreset()
            editingAppName = settings.appDisplayName
            editingCompanyName = settings.companyName
            calculateCacheSize()
            // 커스텀 테마 상태 초기화
            let ct = settings.customTheme
            if let hex = ct.accentHex, !hex.isEmpty { customAccentColor = Color(hex: hex) }
            if let hex = ct.gradientStartHex, !hex.isEmpty { customGradientStart = Color(hex: hex) }
            if let hex = ct.gradientEndHex, !hex.isEmpty { customGradientEnd = Color(hex: hex) }
            customUseGradient = ct.useGradient
            customFontName = ct.fontName ?? ""
            customFontSize = ct.fontSize ?? 11.0
            // Background
            if let hex = ct.bgHex, !hex.isEmpty { customBgColor = Color(hex: hex) }
            else { customBgColor = settings.isDarkMode ? Color(hex: "000000") : Color(hex: "fafafa") }
            if let hex = ct.bgCardHex, !hex.isEmpty { customBgCardColor = Color(hex: hex) }
            else { customBgCardColor = settings.isDarkMode ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
            if let hex = ct.bgSurfaceHex, !hex.isEmpty { customBgSurfaceColor = Color(hex: hex) }
            else { customBgSurfaceColor = settings.isDarkMode ? Color(hex: "111111") : Color(hex: "f5f5f5") }
            if let hex = ct.bgTertiaryHex, !hex.isEmpty { customBgTertiaryColor = Color(hex: hex) }
            else { customBgTertiaryColor = settings.isDarkMode ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }
            // Text
            if let hex = ct.textPrimaryHex, !hex.isEmpty { customTextPrimaryColor = Color(hex: hex) }
            else { customTextPrimaryColor = settings.isDarkMode ? Color(hex: "ededed") : Color(hex: "171717") }
            if let hex = ct.textSecondaryHex, !hex.isEmpty { customTextSecondaryColor = Color(hex: hex) }
            else { customTextSecondaryColor = settings.isDarkMode ? Color(hex: "a1a1a1") : Color(hex: "636363") }
            if let hex = ct.textDimHex, !hex.isEmpty { customTextDimColor = Color(hex: hex) }
            else { customTextDimColor = settings.isDarkMode ? Color(hex: "707070") : Color(hex: "8f8f8f") }
            if let hex = ct.textMutedHex, !hex.isEmpty { customTextMutedColor = Color(hex: hex) }
            else { customTextMutedColor = settings.isDarkMode ? Color(hex: "484848") : Color(hex: "b0b0b0") }
            // Border
            if let hex = ct.borderHex, !hex.isEmpty { customBorderColor = Color(hex: hex) }
            else { customBorderColor = settings.isDarkMode ? Color(hex: "282828") : Color(hex: "e5e5e5") }
            if let hex = ct.borderStrongHex, !hex.isEmpty { customBorderStrongColor = Color(hex: hex) }
            else { customBorderStrongColor = settings.isDarkMode ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
            // Semantic
            if let hex = ct.greenHex, !hex.isEmpty { customGreenColor = Color(hex: hex) }
            else { customGreenColor = settings.isDarkMode ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
            if let hex = ct.redHex, !hex.isEmpty { customRedColor = Color(hex: hex) }
            else { customRedColor = settings.isDarkMode ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
            if let hex = ct.yellowHex, !hex.isEmpty { customYellowColor = Color(hex: hex) }
            else { customYellowColor = settings.isDarkMode ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
            if let hex = ct.purpleHex, !hex.isEmpty { customPurpleColor = Color(hex: hex) }
            else { customPurpleColor = settings.isDarkMode ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
            if let hex = ct.orangeHex, !hex.isEmpty { customOrangeColor = Color(hex: hex) }
            else { customOrangeColor = settings.isDarkMode ? Color(hex: "f97316") : Color(hex: "e5560a") }
            if let hex = ct.cyanHex, !hex.isEmpty { customCyanColor = Color(hex: hex) }
            else { customCyanColor = settings.isDarkMode ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
            if let hex = ct.pinkHex, !hex.isEmpty { customPinkColor = Color(hex: hex) }
            else { customPinkColor = settings.isDarkMode ? Color(hex: "e54d9e") : Color(hex: "d23197") }
        }
        .onChange(of: settings.isDarkMode) { _, dark in
            // 커스텀 hex가 없는 색상만 다크/라이트 모드 기본값으로 자동 업데이트
            let ct = settings.customTheme
            if ct.bgHex == nil || ct.bgHex!.isEmpty { customBgColor = dark ? Color(hex: "000000") : Color(hex: "fafafa") }
            if ct.bgCardHex == nil || ct.bgCardHex!.isEmpty { customBgCardColor = dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
            if ct.bgSurfaceHex == nil || ct.bgSurfaceHex!.isEmpty { customBgSurfaceColor = dark ? Color(hex: "111111") : Color(hex: "f5f5f5") }
            if ct.bgTertiaryHex == nil || ct.bgTertiaryHex!.isEmpty { customBgTertiaryColor = dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }
            if ct.textPrimaryHex == nil || ct.textPrimaryHex!.isEmpty { customTextPrimaryColor = dark ? Color(hex: "ededed") : Color(hex: "171717") }
            if ct.textSecondaryHex == nil || ct.textSecondaryHex!.isEmpty { customTextSecondaryColor = dark ? Color(hex: "a1a1a1") : Color(hex: "636363") }
            if ct.textDimHex == nil || ct.textDimHex!.isEmpty { customTextDimColor = dark ? Color(hex: "707070") : Color(hex: "8f8f8f") }
            if ct.textMutedHex == nil || ct.textMutedHex!.isEmpty { customTextMutedColor = dark ? Color(hex: "484848") : Color(hex: "b0b0b0") }
            if ct.borderHex == nil || ct.borderHex!.isEmpty { customBorderColor = dark ? Color(hex: "282828") : Color(hex: "e5e5e5") }
            if ct.borderStrongHex == nil || ct.borderStrongHex!.isEmpty { customBorderStrongColor = dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
            if ct.greenHex == nil || ct.greenHex!.isEmpty { customGreenColor = dark ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
            if ct.redHex == nil || ct.redHex!.isEmpty { customRedColor = dark ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
            if ct.yellowHex == nil || ct.yellowHex!.isEmpty { customYellowColor = dark ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
            if ct.purpleHex == nil || ct.purpleHex!.isEmpty { customPurpleColor = dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
            if ct.orangeHex == nil || ct.orangeHex!.isEmpty { customOrangeColor = dark ? Color(hex: "f97316") : Color(hex: "e5560a") }
            if ct.cyanHex == nil || ct.cyanHex!.isEmpty { customCyanColor = dark ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
            if ct.pinkHex == nil || ct.pinkHex!.isEmpty { customPinkColor = dark ? Color(hex: "e54d9e") : Color(hex: "d23197") }
        }
        .alert(clearAllMode ? NSLocalizedString("theme.alert.clear.all", comment: "") : NSLocalizedString("theme.alert.clear.old", comment: ""), isPresented: $showClearConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if clearAllMode { clearAllData() } else { clearOldCache() }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(clearAllMode
                 ? NSLocalizedString("theme.alert.clear.all.msg", comment: "")
                 : NSLocalizedString("theme.alert.clear.old.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.token.reset", comment: ""), isPresented: $showTokenResetConfirm) {
            Button(NSLocalizedString("theme.alert.token.reset.btn", comment: ""), role: .destructive) {
                tokenTracker.clearAllEntries()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.token.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.template.reset", comment: ""), isPresented: $showTemplateResetConfirm) {
            Button(NSLocalizedString("theme.alert.template.reset.btn", comment: ""), role: .destructive) {
                templateStore.resetAll()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.template.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.language.change", comment: ""), isPresented: $showLanguageRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let lang = pendingLanguage {
                    // Write directly to avoid triggering UI re-render
                    UserDefaults.standard.set(lang, forKey: "appLanguage")
                    if lang == "auto" {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
                    }
                    UserDefaults.standard.synchronize()
                    restartApp()
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingLanguage = nil }
        } message: {
            let langName: String = {
                switch pendingLanguage {
                case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
                case "en": return "English"
                case "ja": return "日本語"
                default: return NSLocalizedString("settings.language.system", comment: "")
                }
            }()
            Text(String(format: NSLocalizedString("theme.alert.language.msg", comment: ""), langName))
        }
        .alert(NSLocalizedString("settings.customtheme.import.error", comment: ""), isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(NSLocalizedString("settings.customtheme.import.error.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.theme.change", comment: "테마 변경"), isPresented: $showThemeRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let mode = pendingThemeMode {
                    // Save to UserDefaults directly to avoid triggering
                    // UI re-render before the app exits.
                    UserDefaults.standard.set(mode, forKey: "themeMode")
                    if mode == "light" { UserDefaults.standard.set(false, forKey: "isDarkMode") }
                    else if mode == "dark" { UserDefaults.standard.set(true, forKey: "isDarkMode") }
                    UserDefaults.standard.synchronize()
                    restartApp()
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingThemeMode = nil }
        } message: {
            Text(NSLocalizedString("theme.alert.theme.change.msg", comment: "테마를 변경하면 앱이 재시작됩니다."))
        }
        .alert(NSLocalizedString("theme.alert.font.change", comment: "글꼴 크기 변경"), isPresented: $showFontRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let scale = pendingFontScale {
                    UserDefaults.standard.set(scale, forKey: "fontSizeScale")
                    UserDefaults.standard.synchronize()
                    restartApp()
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingFontScale = nil }
        } message: {
            Text(NSLocalizedString("theme.alert.font.change.msg", comment: "글꼴 크기를 변경하면 앱이 재시작됩니다."))
        }
    }

    func langButton(_ label: String, code: String) -> some View {
        let isActive = settings.appLanguage == code
        return Button(action: {
            guard code != settings.appLanguage else { return }
            pendingLanguage = code
            showLanguageRestartAlert = true
        }) {
            Text(label)
                .font(Theme.mono(9, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : Theme.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Theme.accent : Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? Theme.accent : Theme.border.opacity(0.3), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }

    // MARK: - Tab Button

    func settingsTabButton(_ title: String, icon: String, tab: Int) -> some View {
        let selected = selectedSettingsTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedSettingsTab = tab } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(12), weight: .medium))
                Text(title)
                    .font(Theme.mono(8, weight: selected ? .bold : .medium))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(selected ? Theme.accent.opacity(0.08) : Theme.bgSurface.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .stroke(selected ? Theme.accent.opacity(0.18) : Theme.border.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

}
