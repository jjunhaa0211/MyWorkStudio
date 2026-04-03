import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SettingsView {
    // MARK: - 화면 탭

    var displayTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.theme", comment: ""), subtitle: NSLocalizedString("settings.theme.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        themeModeButton(title: "Light", icon: "sun.max.fill", mode: "light")
                        themeModeButton(title: "Dark", icon: "moon.fill", mode: "dark")
                        themeModeButton(title: "Custom", icon: "paintpalette.fill", mode: "custom")
                    }

                    // 플러그인 테마
                    if !PluginHost.shared.themes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "puzzlepiece.fill")
                                    .font(.system(size: Theme.iconSize(8)))
                                Text(NSLocalizedString("plugin.themes.label", comment: ""))
                                    .font(Theme.mono(8, weight: .medium))
                            }.foregroundColor(Theme.textDim)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                                ForEach(PluginHost.shared.themes) { theme in
                                    Button(action: { PluginHost.shared.applyTheme(theme) }) {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: theme.decl.accentHex))
                                                .frame(width: 16, height: 16)
                                            Text(theme.decl.name)
                                                .font(Theme.mono(7, weight: .medium))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.backdrop", comment: ""), subtitle: currentTheme.displayName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(quickBackgroundThemes, id: \.rawValue) { theme in
                        quickBackgroundButton(theme)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.fontsize", comment: ""), subtitle: fontSizeLabel) {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(fontSizeOptions, id: \.value) { opt in
                            Button(action: {
                                guard !isSelectedSize(opt.value) else { return }
                                pendingFontScale = opt.value
                                showFontRestartAlert = true
                            }) {
                                VStack(spacing: 4) {
                                    Text("Aa")
                                        .font(.system(size: CGFloat(10 * opt.value), weight: .medium, design: .monospaced))
                                        .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textSecondary)
                                    Text(opt.label)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textDim)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(isSelectedSize(opt.value) ? Theme.accent.opacity(0.11) : Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelectedSize(opt.value) ? Theme.accent.opacity(0.38) : Theme.border.opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            // ── 커스텀 테마 (Custom 모드일 때만 표시) ──
            if settings.themeMode == "custom" {
            settingsSection(title: NSLocalizedString("settings.customtheme", comment: ""), subtitle: NSLocalizedString("settings.customtheme.subtitle", comment: "")) {
                VStack(spacing: 12) {
                    // ── 강조 색상 / 그라데이션 통합 행 ──
                    VStack(spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("settings.customtheme.accent", comment: ""))
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            // 그라데이션 토글
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("settings.customtheme.gradient", comment: ""))
                                    .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                                Toggle("", isOn: $customUseGradient)
                                    .toggleStyle(.switch).controlSize(.mini)
                                    .onChange(of: customUseGradient) { _, newVal in
                                        var config = settings.customTheme
                                        config.useGradient = newVal
                                        if newVal {
                                            config.gradientStartHex = customGradientStart.hexString
                                            config.gradientEndHex = customGradientEnd.hexString
                                        }
                                        settings.saveCustomTheme(config)
                                    }
                            }
                        }
                        if customUseGradient {
                            // 그라데이션 모드: 그라데이션 바가 accent
                            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                                .fill(LinearGradient(colors: [customGradientStart, customGradientEnd], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 32)
                                .overlay(
                                    Text("● Accent Gradient")
                                        .font(Theme.mono(9, weight: .bold))
                                        .foregroundColor(customGradientStart.contrastingTextColor)
                                )
                                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border, lineWidth: 1))
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    Text(NSLocalizedString("settings.customtheme.gradient.start", comment: ""))
                                        .font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                    ColorPicker("", selection: $customGradientStart, supportsOpacity: false)
                                        .labelsHidden()
                                        .onChange(of: customGradientStart) { _, newColor in
                                            var config = settings.customTheme
                                            config.gradientStartHex = newColor.hexString
                                            settings.saveCustomTheme(config)
                                        }
                                }
                                HStack(spacing: 6) {
                                    Text(NSLocalizedString("settings.customtheme.gradient.end", comment: ""))
                                        .font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                    ColorPicker("", selection: $customGradientEnd, supportsOpacity: false)
                                        .labelsHidden()
                                        .onChange(of: customGradientEnd) { _, newColor in
                                            var config = settings.customTheme
                                            config.gradientEndHex = newColor.hexString
                                            settings.saveCustomTheme(config)
                                        }
                                }
                            }
                        } else {
                            // 단색 모드: 강조 색상 피커
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(customAccentColor)
                                    .frame(width: 28, height: 18)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1))
                                Text("● Accent")
                                    .font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                ColorPicker("", selection: $customAccentColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .onChange(of: customAccentColor) { _, newColor in
                                        var config = settings.customTheme
                                        config.accentHex = newColor.hexString
                                        settings.saveCustomTheme(config)
                                    }
                                Button(action: {
                                    var config = settings.customTheme
                                    config.accentHex = nil
                                    settings.saveCustomTheme(config)
                                    customAccentColor = settings.isDarkMode ? Color(hex: "3291ff") : Color(hex: "0070f3")
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 9)).foregroundColor(Theme.textDim)
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    // 배경 색상
                    DisclosureGroup(isExpanded: $showBgColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "배경 (bg)", color: $customBgColor,
                                savedHex: settings.customTheme.bgHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "000000") : Color(hex: "fafafa")) { hex in
                                var c = settings.customTheme; c.bgHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "카드 (bgCard)", color: $customBgCardColor,
                                savedHex: settings.customTheme.bgCardHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "0a0a0a") : Color(hex: "ffffff")) { hex in
                                var c = settings.customTheme; c.bgCardHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "서피스 (bgSurface)", color: $customBgSurfaceColor,
                                savedHex: settings.customTheme.bgSurfaceHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "111111") : Color(hex: "f5f5f5")) { hex in
                                var c = settings.customTheme; c.bgSurfaceHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "3단계 배경 (bgTertiary)", color: $customBgTertiaryColor,
                                savedHex: settings.customTheme.bgTertiaryHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "1a1a1a") : Color(hex: "ebebeb")) { hex in
                                var c = settings.customTheme; c.bgTertiaryHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("배경 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // 텍스트 색상
                    DisclosureGroup(isExpanded: $showTextColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "기본 텍스트", color: $customTextPrimaryColor,
                                savedHex: settings.customTheme.textPrimaryHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "ededed") : Color(hex: "171717")) { hex in
                                var c = settings.customTheme; c.textPrimaryHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "보조 텍스트", color: $customTextSecondaryColor,
                                savedHex: settings.customTheme.textSecondaryHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "a1a1a1") : Color(hex: "636363")) { hex in
                                var c = settings.customTheme; c.textSecondaryHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "흐린 텍스트 (dim)", color: $customTextDimColor,
                                savedHex: settings.customTheme.textDimHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "707070") : Color(hex: "8f8f8f")) { hex in
                                var c = settings.customTheme; c.textDimHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "뮤트 텍스트 (muted)", color: $customTextMutedColor,
                                savedHex: settings.customTheme.textMutedHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "484848") : Color(hex: "b0b0b0")) { hex in
                                var c = settings.customTheme; c.textMutedHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("텍스트 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // 테두리 색상
                    DisclosureGroup(isExpanded: $showBorderColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "기본 테두리", color: $customBorderColor,
                                savedHex: settings.customTheme.borderHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "282828") : Color(hex: "e5e5e5")) { hex in
                                var c = settings.customTheme; c.borderHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "강조 테두리", color: $customBorderStrongColor,
                                savedHex: settings.customTheme.borderStrongHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0")) { hex in
                                var c = settings.customTheme; c.borderStrongHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("테두리 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // 시맨틱 색상
                    DisclosureGroup(isExpanded: $showSemanticColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "초록 (green)", color: $customGreenColor,
                                savedHex: settings.customTheme.greenHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "3ecf8e") : Color(hex: "18a058")) { hex in
                                var c = settings.customTheme; c.greenHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "빨강 (red)", color: $customRedColor,
                                savedHex: settings.customTheme.redHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "f14c4c") : Color(hex: "e5484d")) { hex in
                                var c = settings.customTheme; c.redHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "노랑 (yellow)", color: $customYellowColor,
                                savedHex: settings.customTheme.yellowHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "f5a623") : Color(hex: "ca8a04")) { hex in
                                var c = settings.customTheme; c.yellowHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "보라 (purple)", color: $customPurpleColor,
                                savedHex: settings.customTheme.purpleHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "8e4ec6") : Color(hex: "6e56cf")) { hex in
                                var c = settings.customTheme; c.purpleHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "주황 (orange)", color: $customOrangeColor,
                                savedHex: settings.customTheme.orangeHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "f97316") : Color(hex: "e5560a")) { hex in
                                var c = settings.customTheme; c.orangeHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "청록 (cyan)", color: $customCyanColor,
                                savedHex: settings.customTheme.cyanHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "06b6d4") : Color(hex: "0891b2")) { hex in
                                var c = settings.customTheme; c.cyanHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "분홍 (pink)", color: $customPinkColor,
                                savedHex: settings.customTheme.pinkHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "e54d9e") : Color(hex: "d23197")) { hex in
                                var c = settings.customTheme; c.pinkHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("시맨틱 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Rectangle().fill(Theme.border).frame(height: 1)

                    // 폰트 선택
                    HStack {
                        Text(NSLocalizedString("settings.customtheme.font", comment: ""))
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Picker("", selection: $customFontName) {
                            Text(NSLocalizedString("settings.customtheme.font.system", comment: ""))
                                .tag("")
                            ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                                Text(family).font(.custom(family, size: 12)).tag(family)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        .onChange(of: customFontName) { _, newVal in
                            var config = settings.customTheme
                            config.fontName = newVal.isEmpty ? nil : newVal
                            settings.saveCustomTheme(config)
                        }
                    }

                    // 폰트 크기 슬라이더
                    VStack(spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("settings.customtheme.fontsize", comment: ""))
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(String(format: "%.0fpt", customFontSize))
                                .font(Theme.code(10))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Slider(value: $customFontSize, in: 8...24, step: 1)
                            .onChange(of: customFontSize) { _, newVal in
                                var config = settings.customTheme
                                config.fontSize = newVal
                                settings.saveCustomTheme(config)
                            }
                    }

                    // 미리보기
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .fill(Theme.accent.opacity(0.12))
                        .overlay(
                            VStack(spacing: 4) {
                                Text("The quick brown fox")
                                    .font(Theme.mono(11, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                Text(NSLocalizedString("theme.custom.preview", comment: ""))
                                    .font(Theme.mono(9))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        )
                        .frame(height: 52)
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accent.opacity(0.2), lineWidth: 1))

                    Rectangle().fill(Theme.border).frame(height: 1)

                    // Import / Export / Reset 버튼
                    HStack(spacing: 8) {
                        Button(action: { settings.exportThemeToFile() }) {
                            Label(NSLocalizedString("settings.customtheme.export", comment: ""), systemImage: "square.and.arrow.up")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.cyan)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cyan.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cyan.opacity(0.25), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.json]
                            panel.allowsMultipleSelection = false
                            panel.title = NSLocalizedString("settings.customtheme.import", comment: "")
                            if panel.runModal() == .OK, let url = panel.url {
                                guard let data = try? Data(contentsOf: url),
                                      let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else {
                                    showImportError = true
                                    return
                                }
                                settings.saveCustomTheme(config)
                                // 상태 동기화
                                if let hex = config.accentHex, !hex.isEmpty { customAccentColor = Color(hex: hex) }
                                if let hex = config.gradientStartHex, !hex.isEmpty { customGradientStart = Color(hex: hex) }
                                if let hex = config.gradientEndHex, !hex.isEmpty { customGradientEnd = Color(hex: hex) }
                                customUseGradient = config.useGradient
                                customFontName = config.fontName ?? ""
                                customFontSize = config.fontSize ?? 11.0
                                let dark = settings.isDarkMode
                                if let hex = config.bgHex, !hex.isEmpty { customBgColor = Color(hex: hex) } else { customBgColor = dark ? Color(hex: "000000") : Color(hex: "fafafa") }
                                if let hex = config.bgCardHex, !hex.isEmpty { customBgCardColor = Color(hex: hex) } else { customBgCardColor = dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
                                if let hex = config.bgSurfaceHex, !hex.isEmpty { customBgSurfaceColor = Color(hex: hex) } else { customBgSurfaceColor = dark ? Color(hex: "111111") : Color(hex: "f5f5f5") }
                                if let hex = config.bgTertiaryHex, !hex.isEmpty { customBgTertiaryColor = Color(hex: hex) } else { customBgTertiaryColor = dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }
                                if let hex = config.textPrimaryHex, !hex.isEmpty { customTextPrimaryColor = Color(hex: hex) } else { customTextPrimaryColor = dark ? Color(hex: "ededed") : Color(hex: "171717") }
                                if let hex = config.textSecondaryHex, !hex.isEmpty { customTextSecondaryColor = Color(hex: hex) } else { customTextSecondaryColor = dark ? Color(hex: "a1a1a1") : Color(hex: "636363") }
                                if let hex = config.textDimHex, !hex.isEmpty { customTextDimColor = Color(hex: hex) } else { customTextDimColor = dark ? Color(hex: "707070") : Color(hex: "8f8f8f") }
                                if let hex = config.textMutedHex, !hex.isEmpty { customTextMutedColor = Color(hex: hex) } else { customTextMutedColor = dark ? Color(hex: "484848") : Color(hex: "b0b0b0") }
                                if let hex = config.borderHex, !hex.isEmpty { customBorderColor = Color(hex: hex) } else { customBorderColor = dark ? Color(hex: "282828") : Color(hex: "e5e5e5") }
                                if let hex = config.borderStrongHex, !hex.isEmpty { customBorderStrongColor = Color(hex: hex) } else { customBorderStrongColor = dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
                                if let hex = config.greenHex, !hex.isEmpty { customGreenColor = Color(hex: hex) } else { customGreenColor = dark ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
                                if let hex = config.redHex, !hex.isEmpty { customRedColor = Color(hex: hex) } else { customRedColor = dark ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
                                if let hex = config.yellowHex, !hex.isEmpty { customYellowColor = Color(hex: hex) } else { customYellowColor = dark ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
                                if let hex = config.purpleHex, !hex.isEmpty { customPurpleColor = Color(hex: hex) } else { customPurpleColor = dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
                                if let hex = config.orangeHex, !hex.isEmpty { customOrangeColor = Color(hex: hex) } else { customOrangeColor = dark ? Color(hex: "f97316") : Color(hex: "e5560a") }
                                if let hex = config.cyanHex, !hex.isEmpty { customCyanColor = Color(hex: hex) } else { customCyanColor = dark ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
                                if let hex = config.pinkHex, !hex.isEmpty { customPinkColor = Color(hex: hex) } else { customPinkColor = dark ? Color(hex: "e54d9e") : Color(hex: "d23197") }
                            }
                        }) {
                            Label(NSLocalizedString("settings.customtheme.import", comment: ""), systemImage: "square.and.arrow.down")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundStyle(Theme.accentBackground)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.25), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            settings.saveCustomTheme(.default)
                            customAccentColor = Theme.accent
                            customGradientStart = Color(hex: "3291ff")
                            customGradientEnd = Color(hex: "8e4ec6")
                            customUseGradient = false
                            customFontName = ""
                            customFontSize = 11.0
                            let dark = settings.isDarkMode
                            customBgColor = dark ? Color(hex: "000000") : Color(hex: "fafafa")
                            customBgCardColor = dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff")
                            customBgSurfaceColor = dark ? Color(hex: "111111") : Color(hex: "f5f5f5")
                            customBgTertiaryColor = dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb")
                            customTextPrimaryColor = dark ? Color(hex: "ededed") : Color(hex: "171717")
                            customTextSecondaryColor = dark ? Color(hex: "a1a1a1") : Color(hex: "636363")
                            customTextDimColor = dark ? Color(hex: "707070") : Color(hex: "8f8f8f")
                            customTextMutedColor = dark ? Color(hex: "484848") : Color(hex: "b0b0b0")
                            customBorderColor = dark ? Color(hex: "282828") : Color(hex: "e5e5e5")
                            customBorderStrongColor = dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0")
                            customGreenColor = dark ? Color(hex: "3ecf8e") : Color(hex: "18a058")
                            customRedColor = dark ? Color(hex: "f14c4c") : Color(hex: "e5484d")
                            customYellowColor = dark ? Color(hex: "f5a623") : Color(hex: "ca8a04")
                            customPurpleColor = dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf")
                            customOrangeColor = dark ? Color(hex: "f97316") : Color(hex: "e5560a")
                            customCyanColor = dark ? Color(hex: "06b6d4") : Color(hex: "0891b2")
                            customPinkColor = dark ? Color(hex: "e54d9e") : Color(hex: "d23197")
                        }) {
                            Text(NSLocalizedString("settings.customtheme.reset", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.orange)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.orange.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.orange.opacity(0.25), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
            } // end if themeMode == "custom"
        }
    }

}
