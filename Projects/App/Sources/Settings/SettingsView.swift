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
    @StateObject var vm = SettingsViewModel()

    @ObservedObject var tokenTracker = TokenTracker.shared
    @ObservedObject var templateStore = AutomationTemplateStore.shared

    // Plugin
    @ObservedObject var pluginManager = PluginManager.shared
    @ObservedObject var pluginHost = PluginHost.shared

    // Convenience accessors for backward compatibility with extensions
    var editingAppName: String { get { vm.editingAppName } nonmutating set { vm.editingAppName = newValue } }
    var editingCompanyName: String { get { vm.editingCompanyName } nonmutating set { vm.editingCompanyName = newValue } }
    var selectedSettingsTab: Int { get { vm.selectedSettingsTab } nonmutating set { vm.selectedSettingsTab = newValue } }
    var selectedTemplateKind: AutomationTemplateKind { get { vm.selectedTemplateKind } nonmutating set { vm.selectedTemplateKind = newValue } }
    var cacheSize: String { get { vm.cacheSize } nonmutating set { vm.cacheSize = newValue } }
    var showClearConfirm: Bool { get { vm.showClearConfirm } nonmutating set { vm.showClearConfirm = newValue } }
    var clearAllMode: Bool { get { vm.clearAllMode } nonmutating set { vm.clearAllMode = newValue } }
    var showTokenResetConfirm: Bool { get { vm.showTokenResetConfirm } nonmutating set { vm.showTokenResetConfirm = newValue } }
    var showTemplateResetConfirm: Bool { get { vm.showTemplateResetConfirm } nonmutating set { vm.showTemplateResetConfirm = newValue } }
    var newCustomJobName: String { get { vm.newCustomJobName } nonmutating set { vm.newCustomJobName = newValue } }
    var showLanguageRestartAlert: Bool { get { vm.showLanguageRestartAlert } nonmutating set { vm.showLanguageRestartAlert = newValue } }
    var pendingLanguage: String? { get { vm.pendingLanguage } nonmutating set { vm.pendingLanguage = newValue } }
    var showThemeRestartAlert: Bool { get { vm.showThemeRestartAlert } nonmutating set { vm.showThemeRestartAlert = newValue } }
    var pendingThemeMode: String? { get { vm.pendingThemeMode } nonmutating set { vm.pendingThemeMode = newValue } }
    var showFontRestartAlert: Bool { get { vm.showFontRestartAlert } nonmutating set { vm.showFontRestartAlert = newValue } }
    var pendingFontScale: Double? { get { vm.pendingFontScale } nonmutating set { vm.pendingFontScale = newValue } }
    var showUpdateSheet: Bool { get { vm.showUpdateSheet } nonmutating set { vm.showUpdateSheet = newValue } }
    var showImportError: Bool { get { vm.showImportError } nonmutating set { vm.showImportError = newValue } }
    var cliCheckDone: Bool { get { vm.cliCheckDone } nonmutating set { vm.cliCheckDone = newValue } }
    var showIconChangeAlert: Bool { get { vm.showIconChangeAlert } nonmutating set { vm.showIconChangeAlert = newValue } }
    var pendingIconStyle: String { get { vm.pendingIconStyle } nonmutating set { vm.pendingIconStyle = newValue } }

    // Custom Theme
    var customAccentColor: Color { get { vm.customAccentColor } nonmutating set { vm.customAccentColor = newValue } }
    var customGradientStart: Color { get { vm.customGradientStart } nonmutating set { vm.customGradientStart = newValue } }
    var customGradientEnd: Color { get { vm.customGradientEnd } nonmutating set { vm.customGradientEnd = newValue } }
    var customUseGradient: Bool { get { vm.customUseGradient } nonmutating set { vm.customUseGradient = newValue } }
    var customFontName: String { get { vm.customFontName } nonmutating set { vm.customFontName = newValue } }
    var customFontSize: Double { get { vm.customFontSize } nonmutating set { vm.customFontSize = newValue } }
    var customBgColor: Color { get { vm.customBgColor } nonmutating set { vm.customBgColor = newValue } }
    var customBgCardColor: Color { get { vm.customBgCardColor } nonmutating set { vm.customBgCardColor = newValue } }
    var customBgSurfaceColor: Color { get { vm.customBgSurfaceColor } nonmutating set { vm.customBgSurfaceColor = newValue } }
    var customBgTertiaryColor: Color { get { vm.customBgTertiaryColor } nonmutating set { vm.customBgTertiaryColor = newValue } }
    var customTextPrimaryColor: Color { get { vm.customTextPrimaryColor } nonmutating set { vm.customTextPrimaryColor = newValue } }
    var customTextSecondaryColor: Color { get { vm.customTextSecondaryColor } nonmutating set { vm.customTextSecondaryColor = newValue } }
    var customTextDimColor: Color { get { vm.customTextDimColor } nonmutating set { vm.customTextDimColor = newValue } }
    var customTextMutedColor: Color { get { vm.customTextMutedColor } nonmutating set { vm.customTextMutedColor = newValue } }
    var customBorderColor: Color { get { vm.customBorderColor } nonmutating set { vm.customBorderColor = newValue } }
    var customBorderStrongColor: Color { get { vm.customBorderStrongColor } nonmutating set { vm.customBorderStrongColor = newValue } }
    var customGreenColor: Color { get { vm.customGreenColor } nonmutating set { vm.customGreenColor = newValue } }
    var customRedColor: Color { get { vm.customRedColor } nonmutating set { vm.customRedColor = newValue } }
    var customYellowColor: Color { get { vm.customYellowColor } nonmutating set { vm.customYellowColor = newValue } }
    var customPurpleColor: Color { get { vm.customPurpleColor } nonmutating set { vm.customPurpleColor = newValue } }
    var customOrangeColor: Color { get { vm.customOrangeColor } nonmutating set { vm.customOrangeColor = newValue } }
    var customCyanColor: Color { get { vm.customCyanColor } nonmutating set { vm.customCyanColor = newValue } }
    var customPinkColor: Color { get { vm.customPinkColor } nonmutating set { vm.customPinkColor = newValue } }
    var showBgColors: Bool { get { vm.showBgColors } nonmutating set { vm.showBgColors = newValue } }
    var showTextColors: Bool { get { vm.showTextColors } nonmutating set { vm.showTextColors = newValue } }
    var showBorderColors: Bool { get { vm.showBorderColors } nonmutating set { vm.showBorderColors = newValue } }
    var showSemanticColors: Bool { get { vm.showSemanticColors } nonmutating set { vm.showSemanticColors = newValue } }

    // Plugin state
    var pluginSourceInput: String { get { vm.pluginSourceInput } nonmutating set { vm.pluginSourceInput = newValue } }
    var showPluginUninstallConfirm: Bool { get { vm.showPluginUninstallConfirm } nonmutating set { vm.showPluginUninstallConfirm = newValue } }
    var pluginToUninstall: PluginEntry? { get { vm.pluginToUninstall } nonmutating set { vm.pluginToUninstall = newValue } }
    var showPluginScaffold: Bool { get { vm.showPluginScaffold } nonmutating set { vm.showPluginScaffold = newValue } }
    var scaffoldName: String { get { vm.scaffoldName } nonmutating set { vm.scaffoldName = newValue } }
    var expandedPluginId: String? { get { vm.expandedPluginId } nonmutating set { vm.expandedPluginId = newValue } }
    var secretKeyInput: String { get { vm.secretKeyInput } nonmutating set { vm.secretKeyInput = newValue } }
    var secretKeyResult: SecretKeyResult { get { vm.secretKeyResult } nonmutating set { vm.secretKeyResult = newValue } }
    var showDebugConsole: Bool { get { vm.showDebugConsole } nonmutating set { vm.showDebugConsole = newValue } }

    let settingsTabs: [(String, String)] = [
        ("slider.horizontal.3", NSLocalizedString("settings.general", comment: "")), ("paintbrush.fill", NSLocalizedString("settings.display", comment: "")), ("building.2.fill", NSLocalizedString("settings.office", comment: "")),
        ("bolt.fill", NSLocalizedString("settings.token", comment: "")), ("externaldrive.fill", NSLocalizedString("settings.data", comment: "")), ("doc.text.fill", NSLocalizedString("settings.template", comment: "")),
        ("puzzlepiece.fill", NSLocalizedString("settings.plugin", comment: "")),
        ("cup.and.saucer.fill", NSLocalizedString("settings.support", comment: "")), ("lock.shield.fill", NSLocalizedString("settings.security", comment: "")),
        ("keyboard.fill", NSLocalizedString("settings.shortcuts", comment: "")),
        ("light.beacon.max.fill", NSLocalizedString("settings.emergency", comment: ""))
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
                        case 10: emergencyTab
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
            vm.hydrateFromSettings(settings)
        }
        .onChange(of: settings.isDarkMode) { _, dark in
            vm.syncColorsForMode(dark, theme: settings.customTheme)
        }
        .alert(vm.clearAllMode ? NSLocalizedString("theme.alert.clear.all", comment: "") : NSLocalizedString("theme.alert.clear.old", comment: ""), isPresented: $vm.showClearConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if clearAllMode { clearAllData() } else { clearOldCache() }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(clearAllMode
                 ? NSLocalizedString("theme.alert.clear.all.msg", comment: "")
                 : NSLocalizedString("theme.alert.clear.old.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.token.reset", comment: ""), isPresented: $vm.showTokenResetConfirm) {
            Button(NSLocalizedString("theme.alert.token.reset.btn", comment: ""), role: .destructive) {
                tokenTracker.clearAllEntries()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.token.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.template.reset", comment: ""), isPresented: $vm.showTemplateResetConfirm) {
            Button(NSLocalizedString("theme.alert.template.reset.btn", comment: ""), role: .destructive) {
                templateStore.resetAll()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.template.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.language.change", comment: ""), isPresented: $vm.showLanguageRestartAlert) {
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
        .alert(NSLocalizedString("settings.customtheme.import.error", comment: ""), isPresented: $vm.showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(NSLocalizedString("settings.customtheme.import.error.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.theme.change", comment: "테마 변경"), isPresented: $vm.showThemeRestartAlert) {
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
        .alert(NSLocalizedString("theme.alert.font.change", comment: "글꼴 크기 변경"), isPresented: $vm.showFontRestartAlert) {
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
