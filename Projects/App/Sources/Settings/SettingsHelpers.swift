import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SettingsView {
    var settingsHeroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.16),
                            Theme.purple.opacity(0.14),
                            Theme.bgCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("settings.title", comment: ""))
                            .font(Theme.mono(16, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                        Text(NSLocalizedString("settings.subtitle", comment: ""))
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: Theme.iconSize(15), weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                        .padding(10)
                        .background(Circle().fill(Theme.accent.opacity(0.12)))
                }

                HStack(spacing: 10) {
                    heroPill(title: settings.appDisplayName, subtitle: "Workspace", tint: Theme.accent)
                    heroPill(title: settings.isDarkMode ? "Dark" : "Light", subtitle: "Theme", tint: Theme.purple)
                    heroPill(title: currentTheme.displayName, subtitle: "Backdrop", tint: Theme.cyan)
                }
            }
            .padding(18)
        }
        .frame(height: 132)
    }

    func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
            content()
        }
        .padding(Theme.sp4)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }

    func securityRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textPrimary)
            Spacer()
            content()
        }
    }

    func labeledField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        emphasized: Bool = false,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textDim)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.mono(11, weight: emphasized ? .semibold : .regular))
                .foregroundColor(Theme.textPrimary)
                .appFieldStyle(emphasized: emphasized)
                .onSubmit { onSubmit() }
                .onChange(of: text.wrappedValue) { _, _ in onSubmit() }
        }
    }

    @ViewBuilder
    func colorPickerRow(
        label: String,
        color: Binding<Color>,
        savedHex: String?,
        defaultColor: Color,
        onChange: @escaping (String?) -> Void
    ) -> some View {
        let isCustomized = savedHex.map({ !$0.isEmpty }) ?? false
        HStack(spacing: 6) {
            Circle()
                .fill(isCustomized ? color.wrappedValue : Color.clear)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            Text(label)
                .font(Theme.mono(9))
                .foregroundColor(isCustomized ? Theme.textPrimary : Theme.textSecondary)
            if isCustomized {
                Text("custom")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundStyle(Theme.accentBackground)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.accent.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.accent.opacity(0.2), lineWidth: 1))
            }
            Spacer()
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color.wrappedValue) { _, newColor in
                    onChange(newColor.hexString)
                }
            if isCustomized {
                Button(action: {
                    color.wrappedValue = defaultColor
                    onChange(nil)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
        }
    }

    func themeModeButton(title: String, icon: String, mode: String) -> some View {
        let selected = settings.themeMode == mode
        let tint: Color = mode == "dark" ? Theme.yellow : (mode == "custom" ? Theme.purple : Theme.orange)
        return Button(action: {
            guard mode != settings.themeMode else { return }
            pendingThemeMode = mode
            showThemeRestartAlert = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(12)))
                    .foregroundColor(selected ? tint : Theme.textDim)
                Text(title)
                    .font(Theme.mono(10, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    struct FontSizeOption {
        let value: Double
        let label: String
    }

    var fontSizeOptions: [FontSizeOption] {
        [
            FontSizeOption(value: 1.2, label: "S"),
            FontSizeOption(value: 1.5, label: "M"),
            FontSizeOption(value: 1.8, label: "L"),
            FontSizeOption(value: 2.2, label: "XL"),
            FontSizeOption(value: 2.7, label: "XXL"),
        ]
    }

    func isSelectedSize(_ v: Double) -> Bool {
        abs(settings.fontSizeScale - v) < 0.05
    }

    var fontSizeLabel: String {
        fontSizeOptions.first(where: { isSelectedSize($0.value) })?.label ?? "\(Int(settings.fontSizeScale * 100))%"
    }

    func cliStatusRow(provider: AgentProvider) -> some View {
        let checker = provider.installChecker
        // Do NOT call checker.check() here — it runs shell commands
        // synchronously and blocks the main thread, causing a hang.
        // The check is triggered in .task below on a background thread.
        let installed = checker.isInstalled
        let version = checker.version

        return HStack(spacing: 8) {
            Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: Theme.iconSize(12)))
                .foregroundColor(installed ? Theme.green : Theme.red)
            VStack(alignment: .leading, spacing: 1) {
                Text(provider.displayName)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                if installed {
                    Text(version.isEmpty ? NSLocalizedString("settings.cli.installed", comment: "") : version)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                } else {
                    Text(cliInstallHint(provider))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }
            }
            Spacer()
            if !installed {
                Button(action: { installCLI(provider) }) {
                    Text(NSLocalizedString("settings.cli.install", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(installed ? Theme.green.opacity(0.05) : Theme.red.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(installed ? Theme.green.opacity(0.2) : Theme.red.opacity(0.2), lineWidth: 1))
    }

    func cliInstallHint(_ provider: AgentProvider) -> String {
        provider.installCommand
    }

    func installCLI(_ provider: AgentProvider) {
        let command = provider.installCommand

        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func restartApp() {
        SessionManager.shared.saveSessions(immediately: true)

        // Schedule relaunch BEFORE exit — use a detached process so
        // it survives our termination.
        let appPath = Bundle.main.bundlePath
        let script = """
        sleep 1
        open "\(appPath)"
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", script]
        task.qualityOfService = .userInitiated
        do { try task.run() } catch { /* best effort */ }

        // Use exit(0) after a short delay to let the Process start.
        // NSApplication.terminate can be blocked by delegate callbacks,
        // and calling it during an alert transition causes crashes.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            exit(0)
        }
    }

    var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    var currentOfficePreset: OfficePreset {
        OfficePreset(rawValue: settings.officePreset) ?? .cozy
    }

    var quickBackgroundThemes: [BackgroundTheme] {
        [.auto, .sunny, .goldenHour, .moonlit, .rain, .neonCity]
    }

    func quickBackgroundButton(_ theme: BackgroundTheme) -> some View {
        let selected = currentTheme == theme
        let locked = !theme.isUnlocked
        return Button(action: {
            guard !locked else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.backgroundTheme = theme.rawValue
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: locked ? "lock.fill" : theme.icon)
                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                Text(theme.displayName)
                    .font(Theme.mono(9, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if locked {
                    Text(theme.lockReason)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (selected ? Theme.purple : Theme.textSecondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected && !locked ? Theme.purple.opacity(0.12) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(locked ? Theme.border.opacity(0.15) : (selected ? Theme.purple.opacity(0.35) : Theme.border.opacity(0.3)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func officePresetButton(_ preset: OfficePreset) -> some View {
        let selected = currentOfficePreset == preset
        let tint = Theme.cyan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officePreset = preset.rawValue
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: Theme.iconSize(12), weight: .bold))
                    .foregroundColor(selected ? tint : Theme.textDim)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.displayName)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    Text(preset.subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func officeCameraButton(title: String, icon: String, mode: String) -> some View {
        let selected = settings.officeViewMode == mode
        let tint = Theme.purple
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officeViewMode = mode
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .foregroundColor(selected ? tint : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func templateKindButton(_ kind: AutomationTemplateKind) -> some View {
        let selected = selectedTemplateKind == kind
        let tint = Theme.cyan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTemplateKind = kind
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                    .foregroundColor(selected ? tint : Theme.textDim)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.shortLabel)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    Text(kind.summary)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func templateTokenPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Theme.mono(8, weight: .semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(tint.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }

    func heroPill(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subtitle)
                .font(Theme.mono(7, weight: .bold))
                .foregroundColor(tint.opacity(0.75))
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.bgSurface.opacity(0.9))
        )
    }

    func usageMetricCard(
        title: String,
        value: String,
        secondary: String,
        tint: Color,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(Theme.textDim)
            Text(value)
                .font(Theme.mono(13, weight: .black))
                .foregroundColor(tint)
            Text(secondary)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bgSurface)
                    Capsule()
                        .fill(tint.opacity(0.88))
                        .frame(width: max(8, geo.size.width * CGFloat(min(progress, 1.0))))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.bgSurface.opacity(0.85))
        )
    }

    func tokenLimitField(title: String, value: Binding<Int>) -> some View {
        let safeBinding = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = max(1, $0) }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(Theme.textDim)
            HStack(spacing: 6) {
                TextField("", value: safeBinding, format: .number)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.bgSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                    )
                Text("tokens")
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func providerTokenLimitField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(Theme.textDim)
            TextField("0", value: value, format: .number)
                .textFieldStyle(.plain)
                .font(Theme.mono(10, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.35), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    func appIconButton(style: String, label: String, iconName: String, color: Color) -> some View {
        let isSelected = settings.appIconStyle == style
        return Button(action: {
            guard settings.appIconStyle != style else { return }
            settings.appIconStyle = style
            pendingIconStyle = style
            showIconChangeAlert = true
        }) {
            VStack(spacing: 6) {
                if let icon = NSImage(named: iconName) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.3))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: style == "classic" ? "figure.run" : "terminal")
                                .font(.system(size: 20))
                                .foregroundColor(color)
                        )
                }
                Text(label)
                    .font(Theme.mono(8, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? color : Theme.textDim)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? color.opacity(0.12) : Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? color : Theme.border.opacity(0.3), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    func statusHint(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(10), weight: .bold))
            Text(text)
                .font(Theme.mono(9, weight: .medium))
        }
        .foregroundColor(tint)
    }

    // ── Secret Key ──

    static let normalizedSecretKey = "i dont like snatch"

    static func normalizeSecretKey(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current).lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
        let stripped = String(folded.unicodeScalars.filter { allowed.contains($0) })
        return stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func applySecretKey() {
        let key = Self.normalizeSecretKey(secretKeyInput)
        if key == Self.normalizedSecretKey {
            _ = CharacterRegistry.shared.unlockAllCharacters()
            UserDefaults.standard.set(true, forKey: "allContentUnlocked")
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .success }
            secretKeyInput = ""
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .wrong }
        }
        // 3초 후 결과 메시지 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { secretKeyResult = .none }
        }
    }
}
