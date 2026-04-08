import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SettingsView {
    // MARK: - 일반 탭

    var generalTab: some View {
        VStack(spacing: 14) {
            // CLI 설치 상태
            settingsSection(title: "AI CLI", subtitle: NSLocalizedString("settings.cli.subtitle", comment: "")) {
                VStack(spacing: 8) {
                    ForEach(AgentProvider.allCases) { provider in
                        cliStatusRow(provider: provider)
                    }
                    Text(NSLocalizedString("settings.cli.login.hint", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .task {
                // Run CLI install checks on background thread
                guard !cliCheckDone else { return }
                await Task.detached(priority: .utility) {
                    for provider in AgentProvider.allCases {
                        provider.installChecker.check(force: true)
                    }
                }.value
                await MainActor.run { cliCheckDone = true }
            }

            settingsSection(title: NSLocalizedString("theme.section.profile", comment: ""), subtitle: NSLocalizedString("theme.section.profile.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.app.name", comment: "")) {
                        TextField(NSLocalizedString("theme.label.app.name", comment: ""), text: $editingAppName)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                            .frame(maxWidth: 180)
                            .onSubmit { settings.appDisplayName = editingAppName; settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.company", comment: "")) {
                        TextField(NSLocalizedString("theme.label.company.placeholder", comment: ""), text: $editingCompanyName)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                            .frame(maxWidth: 180)
                            .onSubmit { settings.companyName = editingCompanyName; settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.secret.key", comment: "")) {
                        HStack(spacing: 6) {
                            SecureField(NSLocalizedString("theme.label.secret.key.placeholder", comment: ""), text: $secretKeyInput)
                                .font(Theme.mono(10)).textFieldStyle(.plain)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                                    secretKeyResult == .wrong ? Theme.red : Theme.border, lineWidth: 0.5))
                                .frame(maxWidth: 140)
                                .onSubmit { applySecretKey() }
                            Button(NSLocalizedString("theme.label.apply", comment: "")) { applySecretKey() }
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBackground))
                                .buttonStyle(.plain)
                        }
                    }
                    if secretKeyResult == .success {
                        statusHint(icon: "checkmark.circle.fill", text: NSLocalizedString("theme.secret.unlocked", comment: ""), tint: Theme.green)
                    } else if secretKeyResult == .wrong {
                        statusHint(icon: "xmark.circle.fill", text: NSLocalizedString("theme.secret.invalid", comment: ""), tint: Theme.red)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("theme.section.language", comment: ""), subtitle: settings.currentLanguageLabel) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.app.language", comment: "")) {
                        HStack(spacing: 8) {
                            langButton(NSLocalizedString("theme.lang.system", comment: ""), code: "auto")
                            langButton(NSLocalizedString("theme.lang.korean", comment: ""), code: "ko")
                            langButton("English", code: "en")
                            langButton("日本語", code: "ja")
                        }
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.appicon", comment: ""), subtitle: appIconLabel(settings.appIconStyle)) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                    appIconButton(style: "classic", label: NSLocalizedString("settings.icon.classic", comment: ""), iconName: "AppIcon", color: Color(red: 0.8, green: 0.65, blue: 0.25))
                    appIconButton(style: "pixel", label: NSLocalizedString("settings.icon.pixel", comment: ""), iconName: "AppIconPixelPreview", color: Color(red: 0.35, green: 0.55, blue: 0.82))
                    appIconButton(style: "ocean", label: NSLocalizedString("settings.icon.ocean", comment: ""), iconName: "AppIconOceanPreview", color: Color(red: 0.12, green: 0.62, blue: 0.82))
                    appIconButton(style: "sunset", label: NSLocalizedString("settings.icon.sunset", comment: ""), iconName: "AppIconSunsetPreview", color: Color(red: 0.88, green: 0.48, blue: 0.18))
                    appIconButton(style: "mint", label: NSLocalizedString("settings.icon.mint", comment: ""), iconName: "AppIconMintPreview", color: Color(red: 0.18, green: 0.78, blue: 0.55))
                    appIconButton(style: "slate", label: NSLocalizedString("settings.icon.slate", comment: ""), iconName: "AppIconSlatePreview", color: Color(red: 0.38, green: 0.45, blue: 0.65))
                }
            }
            .alert(NSLocalizedString("settings.icon.change.title", comment: ""), isPresented: Binding(
                get: { showIconChangeAlert },
                set: { showIconChangeAlert = $0 }
            )) {
                Button(NSLocalizedString("settings.icon.restart", comment: ""), role: .destructive) {
                    restartApp()
                }
                Button(NSLocalizedString("button.cancel", comment: ""), role: .cancel) {
                    // revert
                    settings.appIconStyle = pendingIconStyle == "terminal" ? "classic" : "terminal"
                }
            } message: {
                Text(NSLocalizedString("settings.icon.change.message", comment: ""))
            }

            settingsSection(title: NSLocalizedString("theme.section.terminal", comment: ""), subtitle: settings.rawTerminalMode ? NSLocalizedString("theme.terminal.raw", comment: "") : NSLocalizedString("theme.terminal.doffice", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.raw.terminal", comment: "")) {
                        Toggle("", isOn: $settings.rawTerminalMode)
                            .toggleStyle(.switch).tint(Theme.green).labelsHidden()
                            .onChange(of: settings.rawTerminalMode) { _, _ in settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.auto.refresh", comment: "")) {
                        Toggle("", isOn: $settings.autoRefreshOnSettingsChange)
                            .toggleStyle(.switch).tint(Theme.accent).labelsHidden()
                    }
                    securityRow(label: NSLocalizedString("theme.label.tutorial.reset", comment: "")) {
                        Button(action: { settings.hasCompletedOnboarding = false; dismiss() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(Theme.textDim)
                        }.buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.performance", comment: ""), subtitle: settings.performanceMode ? NSLocalizedString("settings.performance.manual", comment: "") : (settings.autoPerformanceMode ? NSLocalizedString("settings.performance.auto", comment: "") : NSLocalizedString("settings.performance.off", comment: ""))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("settings.performance.mode", comment: ""), isOn: $settings.performanceMode)
                        .font(Theme.mono(10, weight: .medium))
                    Toggle(NSLocalizedString("settings.performance.auto.mode", comment: ""), isOn: $settings.autoPerformanceMode)
                        .font(Theme.mono(10, weight: .medium))
                    Text(NSLocalizedString("settings.performance.desc", comment: ""))
                        .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }

            settingsSection(title: NSLocalizedString("settings.appinfo", comment: ""), subtitle: "v\(UpdateChecker.shared.currentVersion)") {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.appinfo.version", comment: "")) {
                        Text("v\(UpdateChecker.shared.currentVersion)")
                            .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                    }
                    HStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/jjunhaa0211/MyWorkStudio") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("GitHub").font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .accent, compact: true)
                        }.buttonStyle(.plain)
                        Button(action: {
                            UpdateChecker.shared.checkForUpdates()
                            showUpdateSheet = true
                        }) {
                            Text(NSLocalizedString("settings.appinfo.update", comment: "")).font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .green, compact: true)
                        }.buttonStyle(.plain)
                        .sheet(isPresented: $showUpdateSheet) {
                            UpdateSheet().dofficeSheetPresentation()
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func appIconLabel(_ style: String) -> String {
        switch style {
        case "classic": return NSLocalizedString("settings.icon.classic", comment: "")
        case "pixel": return NSLocalizedString("settings.icon.pixel", comment: "")
        case "ocean": return NSLocalizedString("settings.icon.ocean", comment: "")
        case "sunset": return NSLocalizedString("settings.icon.sunset", comment: "")
        case "mint": return NSLocalizedString("settings.icon.mint", comment: "")
        case "slate": return NSLocalizedString("settings.icon.slate", comment: "")
        default: return style
        }
    }

}
