import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Accessory View (휴게실 배치 & 가구 설정)
// ═══════════════════════════════════════════════════════

struct AccessoryView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var pluginHost = PluginHost.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0  // 0=악세서리, 1=배경

    private let accessoryTabs: [(String, String)] = [("sofa.fill", NSLocalizedString("accessory.tab.furniture", comment: "")), ("photo.fill", NSLocalizedString("accessory.tab.background", comment: ""))]

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "paintpalette.fill",
                iconColor: Theme.purple,
                title: NSLocalizedString("accessory.title", comment: ""),
                subtitle: NSLocalizedString("accessory.subtitle", comment: ""),
                onClose: { dismiss() }
            )

            // 탭 선택
            DSTabBar(tabs: accessoryTabs, selectedIndex: $selectedTab)
                .padding(.horizontal, Theme.sp4)
                .padding(.vertical, Theme.sp2)

            Rectangle().fill(Theme.border).frame(height: 1)

            // 탭 내용
            if selectedTab == 0 {
                accessoryTabContent
            } else {
                backgroundTabContent
            }
        }
        .padding(24)
        .background(Theme.bg.opacity(1))
        .background(.ultraThickMaterial)
    }

    private func tabButton(_ title: String, icon: String, tab: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(10)))
                Text(title).font(Theme.mono(11, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundColor(selectedTab == tab ? Theme.purple : Theme.textDim)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(selectedTab == tab ? Theme.purple.opacity(0.1) : .clear)
            .cornerRadius(6)
        }.buttonStyle(.plain)
    }

    // MARK: - 악세서리 탭

    private var accessoryTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // 가구 목록 (빌트인 + 플러그인 통합 그리드)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(FurnitureItem.all) { item in
                        furnitureCard(item)
                    }
                    ForEach(pluginHost.furniture) { item in
                        pluginFurnitureCard(item)
                    }
                }

                // 오피스 프리셋 (플러그인)
                if !pluginHost.officePresets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("accessory.presets", comment: "PRESETS"))
                            .font(Theme.pixel)
                            .foregroundColor(Theme.textDim)
                            .tracking(1.5)
                        ForEach(pluginHost.officePresets) { preset in
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: Theme.iconSize(9)))
                                    .foregroundColor(Theme.cyan)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(preset.decl.name)
                                        .font(Theme.mono(8, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text(preset.pluginName)
                                        .font(Theme.mono(7))
                                        .foregroundColor(Theme.cyan)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                // ── 가구 배치 ──
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("accessory.placement", comment: "")).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                    Button(action: { settings.isEditMode = true; dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.textOnAccent)
                            Text(NSLocalizedString("accessory.drag.hint", comment: "")).font(Theme.mono(11, weight: .bold)).foregroundColor(Theme.textOnAccent)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: Theme.iconSize(14))).foregroundColor(Theme.textOnAccent.opacity(0.7))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            LinearGradient(colors: [Theme.purple, Theme.accent], startPoint: .leading, endPoint: .trailing)))
                    }.buttonStyle(.plain)

                    Button(action: { settings.resetFurniturePositions() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.textDim)
                            Text(NSLocalizedString("accessory.reset.placement", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 배경 탭

    private var backgroundTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                HStack {
                    Text(NSLocalizedString("accessory.bg.theme", comment: "")).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                    Spacer()
                    Text(currentTheme.displayName).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.purple)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(BackgroundTheme.allCases) { theme in
                        bgThemeButton(theme)
                    }
                }

                if !pluginHost.themes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PLUGIN THEMES")
                                .font(Theme.pixel)
                                .foregroundColor(Theme.textDim)
                                .tracking(1.5)
                            Spacer()
                            Text("\(pluginHost.themes.count)")
                                .font(Theme.mono(8, weight: .bold))
                                .foregroundColor(Theme.purple)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                            ForEach(pluginHost.themes) { theme in
                                pluginThemeCard(theme)
                            }
                        }

                        // 플러그인 테마 사용 중일 때 기본 테마 복원 버튼
                        if settings.themeMode == "custom" {
                            Button(action: { resetToDefaultTheme() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: Theme.iconSize(10)))
                                        .foregroundColor(Theme.textDim)
                                    Text(NSLocalizedString("accessory.theme.reset", comment: "Reset to default theme"))
                                        .font(Theme.mono(9, weight: .medium))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 8).padding(.horizontal, 10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 플러그인 테마 카드

    private func pluginThemeCard(_ theme: PluginHost.LoadedTheme) -> some View {
        let selected = isPluginThemeSelected(theme)
        return Button(action: { pluginHost.applyTheme(theme) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: theme.decl.accentHex))
                        .frame(width: 14, height: 14)
                    Text(theme.decl.name)
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: Theme.iconSize(8)))
                            .foregroundColor(Theme.green)
                    }
                }

                Text(theme.pluginName)
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.purple)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.purple.opacity(0.1)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.purple.opacity(0.08) : Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Theme.purple.opacity(0.42) : Theme.border.opacity(0.24), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func isPluginThemeSelected(_ theme: PluginHost.LoadedTheme) -> Bool {
        let customTheme = settings.customTheme
        return settings.themeMode == "custom"
            && settings.isDarkMode == theme.decl.isDark
            && customTheme.accentHex == theme.decl.accentHex
            && customTheme.bgHex == theme.decl.bgHex
    }

    private func resetToDefaultTheme() {
        withAnimation(.easeInOut(duration: 0.15)) {
            settings.themeMode = settings.isDarkMode ? "dark" : "light"
        }
        settings.requestRefreshIfNeeded()
    }

    // MARK: - 가구 카드 (미리보기 포함)

    private func furnitureCard(_ item: FurnitureItem) -> some View {
        let isOn = isFurnitureOn(item.id)
        let locked = !item.isUnlocked
        return Button(action: { guard !locked else { return }; withAnimation(.easeInOut(duration: 0.15)) { toggleFurniture(item.id) } }) {
            VStack(spacing: 6) {
                // 미리보기 영역
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(locked ? Theme.bgSurface.opacity(0.5) : (isOn ? Theme.purple.opacity(0.08) : Theme.bgSurface))
                        .frame(height: 50)

                    // 픽셀 아트 미리보기 (Canvas)
                    Canvas { context, size in
                        let cx = size.width / 2 - item.width / 2
                        let cy = size.height / 2 - item.height / 2 + 2
                        drawFurniturePreview(context: context, item: item, at: CGPoint(x: cx, y: cy))
                    }
                    .frame(height: 50)
                    .opacity(locked ? 0.15 : (isOn ? 1.0 : 0.4))

                    // 잠금 오버레이
                    if locked {
                        VStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.iconSize(14)))
                                .foregroundColor(Theme.textDim)
                            Text(item.lockReason)
                                .font(Theme.mono(6, weight: .medium))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // 이름 + 체크
                HStack(spacing: 3) {
                    Image(systemName: locked ? "lock.fill" : item.icon)
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (isOn ? Theme.purple : Theme.textDim))
                    Text(item.name)
                        .font(Theme.mono(8, weight: isOn ? .bold : .medium))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (isOn ? Theme.textPrimary : Theme.textDim))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: locked ? "lock.fill" : (isOn ? "checkmark.circle.fill" : "circle"))
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.3) : (isOn ? Theme.green : Theme.textDim.opacity(0.4)))
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8)
                .stroke(locked ? Theme.border.opacity(0.1) : (isOn ? Theme.purple.opacity(0.4) : Theme.border.opacity(0.2)), lineWidth: isOn && !locked ? 1.5 : 0.5))
        }.buttonStyle(.plain)
    }

    // 미리보기 그리기 (간소화된 버전)
    private func drawFurniturePreview(context: GraphicsContext, item: FurnitureItem, at pos: CGPoint) {
        let dark = settings.isDarkMode
        let theme = resolvedAccessoryPreviewTheme(settings)
        let previewRect = CGRect(x: pos.x - 8, y: pos.y - 6, width: max(item.width + 16, 52), height: max(item.height + 12, 34))
        drawAccessoryPreviewRoom(context: context, item: item, rect: previewRect, theme: theme, dark: dark, frame: 18)
        drawAccessoryPixelFurniture(context: context, itemId: item.id, at: pos, dark: dark, frame: 18)
    }

    // MARK: - 플러그인 가구 카드 (빌트인과 동일한 스타일)

    private func pluginFurnitureCard(_ item: PluginHost.LoadedFurniture) -> some View {
        VStack(spacing: 6) {
            // 스프라이트 미리보기 영역
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.bgSurface)
                    .frame(height: 50)

                Canvas { context, size in
                    drawPluginSpritePreview(context: context, size: size, sprite: item.decl.sprite)
                }
                .frame(height: 50)
            }

            // 이름 (빌트인 가구와 동일한 레이아웃)
            HStack(spacing: 3) {
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(Theme.purple)
                Text(item.decl.name)
                    .font(Theme.mono(8, weight: .medium))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8)
            .stroke(Theme.border.opacity(0.2), lineWidth: 0.5))
    }

    private func drawPluginSpritePreview(context: GraphicsContext, size: CGSize, sprite: [[String]]) {
        guard !sprite.isEmpty, !sprite[0].isEmpty else { return }
        let rows = sprite.count
        let cols = sprite[0].count
        let px = min(size.width / CGFloat(cols), size.height / CGFloat(rows))
        let offX = (size.width - CGFloat(cols) * px) / 2
        let offY = (size.height - CGFloat(rows) * px) / 2
        for r in 0..<rows {
            let row = sprite[r]
            for c in 0..<min(cols, row.count) {
                let hex = row[c]
                guard !hex.isEmpty, hex != "transparent" else { continue }
                let rect = CGRect(x: offX + CGFloat(c) * px, y: offY + CGFloat(r) * px, width: px, height: px)
                context.fill(Path(rect), with: .color(Color(hex: hex)))
            }
        }
    }

    // MARK: - Helpers

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    private func isFurnitureOn(_ id: String) -> Bool {
        switch id {
        case "sofa": return settings.breakRoomShowSofa
        case "coffeeMachine": return settings.breakRoomShowCoffeeMachine
        case "plant": return settings.breakRoomShowPlant
        case "sideTable": return settings.breakRoomShowSideTable
        case "picture": return settings.breakRoomShowPicture
        case "neonSign": return settings.breakRoomShowNeonSign
        case "rug": return settings.breakRoomShowRug
        case "bookshelf": return settings.breakRoomShowBookshelf
        case "aquarium": return settings.breakRoomShowAquarium
        case "arcade": return settings.breakRoomShowArcade
        case "whiteboard": return settings.breakRoomShowWhiteboard
        case "lamp": return settings.breakRoomShowLamp
        case "cat": return settings.breakRoomShowCat
        case "tv": return settings.breakRoomShowTV
        case "fan": return settings.breakRoomShowFan
        case "calendar": return settings.breakRoomShowCalendar
        case "poster": return settings.breakRoomShowPoster
        case "trashcan": return settings.breakRoomShowTrashcan
        case "cushion": return settings.breakRoomShowCushion
        default: return false
        }
    }

    private func toggleFurniture(_ id: String) {
        switch id {
        case "sofa": settings.breakRoomShowSofa.toggle()
        case "coffeeMachine": settings.breakRoomShowCoffeeMachine.toggle()
        case "plant": settings.breakRoomShowPlant.toggle()
        case "sideTable": settings.breakRoomShowSideTable.toggle()
        case "picture": settings.breakRoomShowPicture.toggle()
        case "neonSign": settings.breakRoomShowNeonSign.toggle()
        case "rug": settings.breakRoomShowRug.toggle()
        case "bookshelf": settings.breakRoomShowBookshelf.toggle()
        case "aquarium": settings.breakRoomShowAquarium.toggle()
        case "arcade": settings.breakRoomShowArcade.toggle()
        case "whiteboard": settings.breakRoomShowWhiteboard.toggle()
        case "lamp": settings.breakRoomShowLamp.toggle()
        case "cat": settings.breakRoomShowCat.toggle()
        case "tv": settings.breakRoomShowTV.toggle()
        case "fan": settings.breakRoomShowFan.toggle()
        case "calendar": settings.breakRoomShowCalendar.toggle()
        case "poster": settings.breakRoomShowPoster.toggle()
        case "trashcan": settings.breakRoomShowTrashcan.toggle()
        case "cushion": settings.breakRoomShowCushion.toggle()
        default: break
        }
    }

    private func bgThemeButton(_ theme: BackgroundTheme) -> some View {
        let selected = settings.backgroundTheme == theme.rawValue
        let locked = !theme.isUnlocked
        return Button(action: { guard !locked else { return }; settings.backgroundTheme = theme.rawValue }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(hex: theme.skyColors.top), Color(hex: theme.skyColors.bottom)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(height: 28)
                        .opacity(locked ? 0.3 : 1.0)
                    if locked {
                        VStack(spacing: 1) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.iconSize(9)))
                                .foregroundColor(.white.opacity(0.7))
                            Text(theme.lockReason)
                                .font(Theme.mono(5, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: theme.icon)
                            .font(.system(size: Theme.iconSize(10)))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                Text(theme.displayName)
                    .font(Theme.mono(7, weight: selected ? .bold : .medium))
                    .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (selected ? Theme.purple : Theme.textDim))
                    .lineLimit(1)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected && !locked ? Theme.purple.opacity(0.1) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(locked ? Theme.border.opacity(0.1) : (selected ? Theme.purple.opacity(0.5) : Theme.border.opacity(0.2)), lineWidth: selected && !locked ? 1.5 : 0.5)))
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Accessory Preview Backgrounds
// ═══════════════════════════════════════════════════════

private enum AccessoryPreviewBackdropKind {
    case brightOffice
    case sunsetOffice
    case nightOffice
    case weather
    case blossom
    case forest
    case neon
    case ocean
    case desert
    case volcano
}

private struct AccessoryPreviewPalette {
    let wallTop: String
    let wallBottom: String
    let trim: String
    let baseboard: String
    let floorA: String
    let floorB: String
    let floorShadow: String
    let windowFrame: String
    let windowTop: String
    let windowBottom: String
    let windowGlow: String
    let reflection: String
    let sill: String
}

private func resolvedAccessoryPreviewTheme(_ settings: AppSettings) -> BackgroundTheme {
    let selected = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    guard selected == .auto else { return selected }

    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6..<11: return .sunny
    case 11..<17: return .clearSky
    case 17..<19: return .goldenHour
    case 19..<21: return .dusk
    default: return settings.isDarkMode ? .moonlit : .sunny
    }
}

private func accessoryPreviewBackdropKind(for theme: BackgroundTheme) -> AccessoryPreviewBackdropKind {
    switch theme {
    case .sunny, .clearSky:
        return .brightOffice
    case .sunset, .goldenHour, .dusk, .autumn:
        return .sunsetOffice
    case .moonlit, .starryNight, .milkyWay, .aurora:
        return .nightOffice
    case .storm, .rain, .snow, .fog:
        return .weather
    case .cherryBlossom:
        return .blossom
    case .forest:
        return .forest
    case .neonCity:
        return .neon
    case .ocean:
        return .ocean
    case .desert:
        return .desert
    case .volcano:
        return .volcano
    case .auto:
        return .brightOffice
    }
}

private func accessoryPreviewPalette(for theme: BackgroundTheme, dark: Bool) -> AccessoryPreviewPalette {
    let baseFloor = theme.floorColors.base
    let baseDot = theme.floorColors.dot
    let kind = accessoryPreviewBackdropKind(for: theme)

    switch kind {
    case .brightOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "C6D2DA" : "E3EDF3",
            wallBottom: dark ? "9DB1BF" : "C8D9E2",
            trim: dark ? "8E6A45" : "C59056",
            baseboard: dark ? "6E4B2F" : "A06E3D",
            floorA: baseFloor.isEmpty ? (dark ? "BB8A54" : "D9A76A") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "A57446" : "C78F55") : baseDot,
            floorShadow: dark ? "6A4528" : "966234",
            windowFrame: dark ? "C7D5E2" : "F8FBFF",
            windowTop: "6AB0E9",
            windowBottom: "D7F0FF",
            windowGlow: dark ? "D8F3FF" : "FFFFFF",
            reflection: dark ? "6F8292" : "A9BACA",
            sill: dark ? "A97140" : "D29559"
        )
    case .sunsetOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "DAB88D" : "F2D0A5",
            wallBottom: dark ? "B9926A" : "E7BF92",
            trim: dark ? "91603A" : "B87543",
            baseboard: dark ? "70462A" : "8E5632",
            floorA: baseFloor.isEmpty ? "B9824C" : baseFloor,
            floorB: baseDot.isEmpty ? "A16B39" : baseDot,
            floorShadow: "7A4C27",
            windowFrame: dark ? "D9B48D" : "FCE2BF",
            windowTop: "8F4A68",
            windowBottom: "F0A24A",
            windowGlow: "FFF2D0",
            reflection: dark ? "8D6B5C" : "C89A80",
            sill: dark ? "A2683A" : "D88D4D"
        )
    case .nightOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "55627C" : "6F7E9D",
            wallBottom: dark ? "394762" : "55637E",
            trim: dark ? "8FA5C6" : "A9C0DD",
            baseboard: dark ? "283444" : "40526B",
            floorA: baseFloor.isEmpty ? (dark ? "4A5970" : "5E718C") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "38465A" : "4A5971") : baseDot,
            floorShadow: dark ? "263243" : "3B4A5E",
            windowFrame: dark ? "CBD7EA" : "F2F7FF",
            windowTop: "0A1631",
            windowBottom: "233F6C",
            windowGlow: dark ? "D4E8FF" : "F3FAFF",
            reflection: dark ? "677A97" : "8799B6",
            sill: dark ? "4A5C75" : "6F86A4"
        )
    case .weather:
        return AccessoryPreviewPalette(
            wallTop: dark ? "ACB5BE" : "D7DEE4",
            wallBottom: dark ? "8E98A3" : "BCC8D0",
            trim: dark ? "6A7581" : "8E9BA6",
            baseboard: dark ? "59636D" : "76828C",
            floorA: baseFloor.isEmpty ? (dark ? "7B866D" : "CBD3C0") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "687354" : "B3BEA8") : baseDot,
            floorShadow: dark ? "4E5844" : "8C947E",
            windowFrame: dark ? "D9E3EA" : "F6FAFC",
            windowTop: theme.skyColors.top,
            windowBottom: theme.skyColors.bottom,
            windowGlow: dark ? "DCE8EF" : "FFFFFF",
            reflection: dark ? "7C8A94" : "ABB8C1",
            sill: dark ? "858E95" : "A4AEB6"
        )
    case .blossom:
        return AccessoryPreviewPalette(
            wallTop: dark ? "E5C7D3" : "F7DEE7",
            wallBottom: dark ? "CBA8B4" : "EBC6D3",
            trim: dark ? "A37584" : "C68FA0",
            baseboard: dark ? "875866" : "B17384",
            floorA: baseFloor.isEmpty ? "D9CEC8" : baseFloor,
            floorB: baseDot.isEmpty ? "C7B8B2" : baseDot,
            floorShadow: "A7938E",
            windowFrame: dark ? "F0DCE5" : "FFF6FA",
            windowTop: "E8B5C4",
            windowBottom: "F6E3EE",
            windowGlow: "FFFFFF",
            reflection: dark ? "A68893" : "CCAFB8",
            sill: dark ? "C28E9F" : "E8AFC0"
        )
    case .forest:
        return AccessoryPreviewPalette(
            wallTop: dark ? "B4C6B0" : "D5E1D2",
            wallBottom: dark ? "8EA08A" : "B6C7B2",
            trim: dark ? "6B7C58" : "8AA06F",
            baseboard: dark ? "506040" : "71875A",
            floorA: baseFloor.isEmpty ? "9C7B54" : baseFloor,
            floorB: baseDot.isEmpty ? "846544" : baseDot,
            floorShadow: "654C33",
            windowFrame: dark ? "D8E6D6" : "F5FCF3",
            windowTop: "4D875A",
            windowBottom: "99C882",
            windowGlow: "EAF9E8",
            reflection: dark ? "778B74" : "A3B69F",
            sill: dark ? "7C9163" : "A4BB7E"
        )
    case .neon:
        return AccessoryPreviewPalette(
            wallTop: dark ? "483B66" : "6B5B8C",
            wallBottom: dark ? "30284A" : "43375E",
            trim: dark ? "9F7BE0" : "C09CFF",
            baseboard: dark ? "211B35" : "32284A",
            floorA: baseFloor.isEmpty ? (dark ? "1C1631" : "2D2247") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "2D1F4F" : "45316D") : baseDot,
            floorShadow: dark ? "120E20" : "241933",
            windowFrame: dark ? "D8D0FF" : "F5F0FF",
            windowTop: "120B2A",
            windowBottom: "2E1854",
            windowGlow: "FF7BE7",
            reflection: dark ? "8A73B5" : "A28BD0",
            sill: dark ? "7B58C8" : "A57BFF"
        )
    case .ocean:
        return AccessoryPreviewPalette(
            wallTop: dark ? "B7D7E6" : "D8EEF7",
            wallBottom: dark ? "93C0D3" : "B9DDE9",
            trim: dark ? "4F7FA4" : "6AA8D2",
            baseboard: dark ? "345874" : "497898",
            floorA: baseFloor.isEmpty ? "93B4C8" : baseFloor,
            floorB: baseDot.isEmpty ? "7399AF" : baseDot,
            floorShadow: "54758B",
            windowFrame: dark ? "ECF8FF" : "FFFFFF",
            windowTop: "2B86CF",
            windowBottom: "8BE2F5",
            windowGlow: "F4FFFF",
            reflection: dark ? "6EA1B8" : "92BED0",
            sill: dark ? "5D99B1" : "86BED1"
        )
    case .desert:
        return AccessoryPreviewPalette(
            wallTop: dark ? "E4CC9E" : "F4DFB1",
            wallBottom: dark ? "C9AE7A" : "E5C78A",
            trim: dark ? "A97842" : "C88F4E",
            baseboard: dark ? "7D582F" : "9F6D38",
            floorA: baseFloor.isEmpty ? "C99B59" : baseFloor,
            floorB: baseDot.isEmpty ? "B48547" : baseDot,
            floorShadow: "916734",
            windowFrame: dark ? "F3E7C6" : "FFF7DE",
            windowTop: "E3A85D",
            windowBottom: "F3D38C",
            windowGlow: "FFF8DA",
            reflection: dark ? "A98A67" : "C9A47B",
            sill: dark ? "C18D4A" : "E5A95D"
        )
    case .volcano:
        return AccessoryPreviewPalette(
            wallTop: dark ? "7C5E5E" : "A27D7D",
            wallBottom: dark ? "583E3E" : "6D4E4E",
            trim: dark ? "A46A55" : "CC8467",
            baseboard: dark ? "3B2727" : "503636",
            floorA: baseFloor.isEmpty ? (dark ? "2C1616" : "3D2222") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "431F1F" : "5A2C2C") : baseDot,
            floorShadow: dark ? "180C0C" : "2A1414",
            windowFrame: dark ? "E6D4D4" : "FAEAEA",
            windowTop: "3C0F15",
            windowBottom: "A52A1F",
            windowGlow: "FFC388",
            reflection: dark ? "8A6262" : "A98181",
            sill: dark ? "793A30" : "AA5344"
            )
        }
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(Theme.bgSurface.opacity(0.45))
        )
    }

    private func limitStepperCard(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("\(value.wrappedValue)회")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(tint)
            }

            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(Theme.bgSurface.opacity(0.45))
        )
    }

private func drawAccessoryPreviewRoom(
    context: GraphicsContext,
    item: FurnitureItem,
    rect: CGRect,
    theme: BackgroundTheme,
    dark: Bool,
    frame: Int
) {
    let palette = accessoryPreviewPalette(for: theme, dark: dark)
    let kind = accessoryPreviewBackdropKind(for: theme)

    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: String, _ opacity: Double = 1) {
        context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: hex).opacity(opacity)))
    }

    let floorHeight: CGFloat = item.isWallItem ? 8 : 11
    let wallHeight = rect.height - floorHeight
    let windowWidth = min(item.isWallItem ? rect.width * 0.42 : rect.width * 0.34, 22)
    let windowHeight = max(12, wallHeight - 9)
    let windowX = item.isWallItem ? rect.midX - windowWidth / 2 : rect.maxX - windowWidth - 6
    let windowY = rect.minY + 4
    let reflectionPulse = (sin(Double(frame) * 0.18) + 1) * 0.5

    px(rect.minX, rect.minY, rect.width, wallHeight, palette.wallBottom)
    px(rect.minX, rect.minY, rect.width, wallHeight * 0.48, palette.wallTop)
    px(rect.minX, rect.minY, rect.width, 1, palette.windowGlow, 0.4)
    px(rect.minX, rect.minY, 1, wallHeight, palette.windowGlow, 0.12)
    px(rect.maxX - 1, rect.minY, 1, wallHeight, palette.baseboard, 0.22)
    px(rect.minX, rect.minY + wallHeight - 3, rect.width, 3, palette.trim, 0.65)
    px(rect.minX, rect.minY + wallHeight - 1, rect.width, 1, palette.baseboard, 0.9)

    let shelfY = rect.minY + wallHeight - 9
    if !item.isWallItem {
        px(rect.minX + 4, shelfY, 9, 2, palette.baseboard, 0.55)
        px(rect.minX + 5, shelfY - 4, 2, 4, palette.reflection, 0.20)
        px(rect.minX + 8, shelfY - 3, 3, 3, palette.reflection, 0.18)
    }

    px(windowX, windowY, windowWidth, windowHeight, palette.windowFrame, 0.95)
    px(windowX + 1, windowY + 1, windowWidth - 2, windowHeight - 2, palette.windowBottom)
    px(windowX + 1, windowY + 1, windowWidth - 2, (windowHeight - 2) * 0.46, palette.windowTop)

    switch kind {
    case .brightOffice:
        px(windowX + 3, windowY + 3, 7, 2, "F9FFFF", 0.55)
        px(windowX + 9, windowY + 5, 5, 2, "F9FFFF", 0.40)
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "8EB27B", 0.75)
        px(windowX + 4, windowY + windowHeight - 7, 3, 3, "A1C490", 0.55)
        px(windowX + 12, windowY + windowHeight - 8, 4, 4, "8CA2B5", 0.5)
    case .sunsetOffice:
        px(windowX + 2, windowY + 2, windowWidth - 4, 1, "FFD58E", 0.40)
        px(windowX + windowWidth - 7, windowY + 3, 4, 4, "FFF0B2", 0.55)
        px(windowX + 2, windowY + windowHeight - 5, windowWidth - 4, 2, "70475A", 0.55)
        px(windowX + 4, windowY + windowHeight - 8, 5, 3, "8E5A4C", 0.35)
        px(windowX + 11, windowY + windowHeight - 7, 4, 2, "9F6A51", 0.3)
    case .nightOffice:
        px(windowX + windowWidth - 6, windowY + 3, 3, 3, "F7E89B", 0.65)
        px(windowX + 4, windowY + 4, 1, 1, "F7F8FF", 0.8)
        px(windowX + 9, windowY + 6, 1, 1, "F7F8FF", 0.55)
        px(windowX + 3, windowY + windowHeight - 5, windowWidth - 6, 2, "263247", 0.85)
        px(windowX + 4, windowY + windowHeight - 7, 2, 2, "F5D36B", 0.5)
        px(windowX + 9, windowY + windowHeight - 7, 2, 2, "8BC1FF", 0.35)
    case .weather:
        if theme == .snow {
            for i in 0..<4 {
                px(windowX + 3 + CGFloat(i * 3), windowY + 4 + CGFloat((i * 5) % 6), 1, 1, "FFFFFF", 0.7)
            }
        } else if theme == .fog {
            px(windowX + 2, windowY + 4, windowWidth - 4, 3, "F4F7FB", 0.22)
            px(windowX + 3, windowY + 8, windowWidth - 6, 2, "E7EDF2", 0.18)
        } else {
            for i in 0..<4 {
                px(windowX + 4 + CGFloat(i * 4), windowY + 3, 1, windowHeight - 6, "D9EAF4", theme == .storm ? 0.26 : 0.18)
            }
        }
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "75838D", 0.45)
    case .blossom:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "809F73", 0.58)
        px(windowX + 3, windowY + 4, 6, 4, "F3BCD0", 0.80)
        px(windowX + 8, windowY + 3, 6, 5, "F8D4E2", 0.74)
        px(windowX + 7, windowY + 10, 1, 1, "FFFFFF", 0.55)
        px(windowX + 12, windowY + 8, 1, 1, "FFFFFF", 0.55)
    case .forest:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "456A42", 0.78)
        px(windowX + 4, windowY + 4, 3, windowHeight - 8, "57764A", 0.72)
        px(windowX + 9, windowY + 5, 3, windowHeight - 9, "3E5C37", 0.78)
        px(windowX + 2, windowY + 4, 5, 4, "86AF78", 0.45)
        px(windowX + 10, windowY + 3, 6, 5, "A2CA7F", 0.36)
    case .neon:
        px(windowX + 3, windowY + windowHeight - 5, windowWidth - 6, 2, "1B1838", 0.9)
        px(windowX + 4, windowY + windowHeight - 8, 3, 3, "FF4CD2", 0.65)
        px(windowX + 10, windowY + windowHeight - 9, 4, 4, "54D7FF", 0.50)
        px(windowX + 5, windowY + 3, 1, windowHeight - 8, "FFF4FF", 0.18)
    case .ocean:
        px(windowX + 1, windowY + windowHeight - 5, windowWidth - 2, 1, "DDF6FF", 0.55)
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "2E8DC1", 0.60)
        px(windowX + 4, windowY + windowHeight - 7, 4, 1, "F7FFFF", 0.45)
        px(windowX + 11, windowY + windowHeight - 8, 5, 1, "B7F3FF", 0.40)
    case .desert:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "D8B16B", 0.75)
        px(windowX + 5, windowY + windowHeight - 8, 6, 3, "C28A4A", 0.45)
        px(windowX + 12, windowY + windowHeight - 9, 1, 5, "63844D", 0.35)
        px(windowX + 11, windowY + windowHeight - 7, 3, 1, "86A66E", 0.30)
    case .volcano:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "311315", 0.90)
        px(windowX + 7, windowY + windowHeight - 9, 5, 4, "4B1819", 0.55)
        px(windowX + 10, windowY + 4, 2, 6, "FFB261", 0.25)
        px(windowX + 11, windowY + 4, 1, 5, "FFD78A", 0.18)
    }

    px(windowX + 2, windowY + 1, 1, windowHeight - 2, palette.windowGlow, 0.16 + reflectionPulse * 0.08)
    px(windowX + windowWidth * 0.55, windowY + 1, 1, windowHeight - 2, palette.windowGlow, 0.10)
    px(windowX + 2, windowY + windowHeight - 6, windowWidth - 4, 1, palette.reflection, 0.26)
    px(windowX + 4, windowY + windowHeight - 5, 4, 2, palette.reflection, 0.20)
    px(windowX + windowWidth - 8, windowY + windowHeight - 7, 3, 3, palette.reflection, 0.12)
    px(windowX - 1, windowY + windowHeight, windowWidth + 2, 2, palette.sill, 0.95)

    let floorTop = rect.maxY - floorHeight
    px(rect.minX, floorTop, rect.width, floorHeight, palette.floorA)
    for row in stride(from: floorTop, to: rect.maxY, by: 4) {
        px(rect.minX, row, rect.width, 1, palette.floorShadow, 0.18)
    }
    if kind == .neon || kind == .ocean || kind == .weather {
        for col in stride(from: rect.minX, to: rect.maxX, by: 6) {
            px(col, floorTop, 1, floorHeight, palette.floorB, 0.22)
        }
    } else {
        for col in stride(from: rect.minX, to: rect.maxX, by: 8) {
            px(col, floorTop, 1, floorHeight, palette.floorB, 0.26)
        }
    }
    px(rect.minX, floorTop, rect.width, 1, palette.windowGlow, 0.16)
    px(rect.minX, rect.maxY - 1, rect.width, 1, palette.floorShadow, 0.34)
}

// ═══════════════════════════════════════════════════════
// MARK: - Shared Pixel Furniture Renderer
// ═══════════════════════════════════════════════════════

func drawAccessoryPixelFurniture(context: GraphicsContext, itemId: String, at pos: CGPoint, dark: Bool, frame: Int = 0) {
    let x = pos.x
    let y = pos.y

    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, _ opacity: Double = 1) {
        context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color.opacity(opacity)))
    }

    switch itemId {
    case "sofa":
        let base = dark ? Color(hex: "70508E") : Color(hex: "8E6AB0")
        let shade = dark ? Color(hex: "533A6C") : Color(hex: "73588F")
        let light = dark ? Color(hex: "8A6BA7") : Color(hex: "AF8BCB")
        px(x + 1, y + 15, 43, 3, .black, dark ? 0.22 : 0.12)
        px(x - 2, y - 9, 49, 10, shade)
        px(x, y, 45, 13, base)
        px(x + 3, y + 2, 18, 8, light, 0.55)
        px(x + 24, y + 2, 18, 8, light, 0.55)
        px(x + 22, y + 2, 1, 8, shade, 0.7)
        px(x - 4, y - 8, 7, 22, base)
        px(x + 42, y - 8, 7, 22, base)
        px(x + 1, y - 8, 1, 20, Color.white, 0.08)
        px(x + 4, y + 13, 4, 7, shade)
        px(x + 37, y + 13, 4, 7, shade)

    case "sideTable":
        let wood = dark ? Color(hex: "7A5631") : Color(hex: "B8824A")
        let woodLight = dark ? Color(hex: "9E7248") : Color(hex: "E1AA6E")
        let woodDark = dark ? Color(hex: "5A3A1F") : Color(hex: "8B5A2D")
        px(x + 1, y + 11, 16, 2, .black, dark ? 0.20 : 0.10)
        px(x, y + 1, 18, 3, woodLight)
        px(x, y + 4, 18, 2, wood)
        px(x + 2, y + 6, 14, 7, wood)
        px(x + 8, y + 4, 2, 10, woodDark)
        px(x + 3, y + 8, 2, 2, Color(hex: "D7D0C5"))
        px(x + 6, y + 7, 5, 1, Color(hex: "5F7FB0"))
        px(x + 12, y + 3, 3, 3, Color(hex: "F2E7D7"))
        px(x + 14, y + 4, 1, 2, Color(hex: "F2E7D7"))
        px(x + 2, y + 13, 2, 6, woodDark)
        px(x + 14, y + 13, 2, 6, woodDark)

    case "coffeeMachine":
        let body = dark ? Color(hex: "59626E") : Color(hex: "7F8895")
        let top = dark ? Color(hex: "7A8591") : Color(hex: "A5B0BA")
        let slot = dark ? Color(hex: "2E3740") : Color(hex: "505A65")
        px(x + 2, y + 15, 12, 2, .black, dark ? 0.22 : 0.12)
        px(x + 1, y, 14, 16, body)
        px(x, y - 1, 16, 3, top)
        px(x + 3, y + 3, 10, 6, top, 0.9)
        px(x + 4, y + 4, 4, 1, Theme.green, 0.8)
        px(x + 3, y + 11, 10, 5, slot)
        px(x + 5, y + 13, 6, 5, Color(hex: "F7F3EE"))
        px(x + 11, y + 14, 2, 3, Color(hex: "F7F3EE"), 0.8)
        px(x + 6, y + 12, 4, 1, Color(hex: "7A4B35"), 0.65)
        let steam = sin(Double(frame) * 0.12)
        px(x + 6 + CGFloat(steam * 1.5), y + 9, 1, 2, .white, 0.25)
        px(x + 8 - CGFloat(steam), y + 7, 1, 2, .white, 0.18)

    case "plant":
        let pot = dark ? Color(hex: "A96A45") : Color(hex: "C98958")
        let potShade = dark ? Color(hex: "7C4B2E") : Color(hex: "955B33")
        let leaf = dark ? Color(hex: "3E7A38") : Color(hex: "5BAF4E")
        let leafLight = dark ? Color(hex: "5CA351") : Color(hex: "7ED16B")
        px(x + 1, y + 17, 12, 2, .black, dark ? 0.18 : 0.09)
        px(x, y + 12, 12, 6, pot)
        px(x - 1, y + 10, 14, 3, Color(hex: dark ? "BC7E57" : "E4A772"))
        px(x + 1, y + 10, 10, 2, potShade, 0.45)
        px(x + 5, y + 4, 2, 8, Color(hex: "497A35"))
        px(x - 1, y + 3, 8, 8, leaf)
        px(x + 4, y, 9, 9, leafLight, 0.95)
        px(x + 1, y - 3, 7, 7, leaf, 0.9)
        px(x + 4, y - 4, 4, 4, Color(hex: "F0B4B8"), 0.75)
        px(x + 5, y - 3, 2, 2, Color(hex: "F7E08A"), 0.8)

    case "clock":
        let rim = dark ? Color(hex: "CCD3DA") : Color(hex: "F5F6F8")
        let face = dark ? Color(hex: "F3EEE4") : Color(hex: "FFFDF8")
        let hand = dark ? Color(hex: "243040") : Color(hex: "3B4652")
        let cx = x + 7
        let cy = y + 7
        px(x, y, 14, 14, Color(hex: dark ? "8792A0" : "BEC8D1"), 0.8)
        px(x + 1, y + 1, 12, 12, rim)
        px(x + 2, y + 2, 10, 10, face)
        let minuteAngle = Double(frame % 120) / 120.0 * .pi * 2 - .pi / 2
        var minute = Path()
        minute.move(to: CGPoint(x: cx, y: cy))
        minute.addLine(to: CGPoint(x: cx + cos(minuteAngle) * 4, y: cy + sin(minuteAngle) * 4))
        context.stroke(minute, with: .color(hand.opacity(0.8)), lineWidth: 0.8)
        var hour = Path()
        hour.move(to: CGPoint(x: cx, y: cy))
        hour.addLine(to: CGPoint(x: cx + 1.6, y: cy - 2.6))
        context.stroke(hour, with: .color(hand), lineWidth: 0.9)
        px(cx - 1, cy - 1, 2, 2, Theme.red, 0.7)

    case "picture":
        let frame = dark ? Color(hex: "7C5B3C") : Color(hex: "B2895A")
        let frameLight = dark ? Color(hex: "9D734D") : Color(hex: "D7AB78")
        px(x, y, 20, 16, frame)
        px(x + 1, y, 18, 1, frameLight, 0.6)
        px(x + 2, y + 2, 16, 12, Color(hex: dark ? "CAE0F0" : "D9EEF8"))
        px(x + 2, y + 9, 16, 5, Color(hex: dark ? "527749" : "79B06C"), 0.75)
        var mountain = Path()
        mountain.move(to: CGPoint(x: x + 4, y: y + 13))
        mountain.addLine(to: CGPoint(x: x + 9, y: y + 6))
        mountain.addLine(to: CGPoint(x: x + 13, y: y + 10))
        mountain.addLine(to: CGPoint(x: x + 17, y: y + 5))
        mountain.addLine(to: CGPoint(x: x + 18, y: y + 13))
        mountain.closeSubpath()
        context.fill(mountain, with: .color(Color(hex: dark ? "5C7AA2" : "8AB7DE").opacity(0.8)))
        px(x + 13, y + 4, 3, 3, Color(hex: "F6E28D"), 0.85)

    case "neonSign":
        px(x, y, 64, 16, Color(hex: dark ? "0E1118" : "252B36"))
        px(x - 1, y - 1, 66, 18, Theme.yellow, dark ? 0.08 : 0.12)
        px(x + 3, y + 3, 12, 2, Theme.yellow, 0.7)
        px(x + 17, y + 3, 8, 2, Theme.yellow, 0.7)
        px(x + 27, y + 3, 11, 2, Theme.yellow, 0.7)
        px(x + 40, y + 3, 10, 2, Theme.yellow, 0.7)
        px(x + 52, y + 3, 8, 2, Theme.yellow, 0.7)
        context.draw(
            Text("BREAK").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Theme.yellow.opacity(0.9)),
            at: CGPoint(x: x + 23, y: y + 8)
        )
        context.draw(
            Text("ROOM").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Theme.cyan.opacity(0.85)),
            at: CGPoint(x: x + 47, y: y + 8)
        )

    case "rug":
        let rug = dark ? Color(hex: "91A582") : Color(hex: "B4C89C")
        let border = dark ? Color(hex: "617255") : Color(hex: "7E926A")
        px(x, y, 100, 14, rug, 0.82)
        px(x + 2, y + 2, 96, 10, border, 0.18)
        px(x + 4, y + 4, 92, 6, Color(hex: dark ? "D8E8BB" : "EFF7D8"), 0.12)
        for stripe in stride(from: CGFloat(6), to: 94, by: 8) {
            px(x + stripe, y + 6, 3, 1, border, 0.45)
        }

    case "bookshelf":
        let wood = dark ? Color(hex: "765132") : Color(hex: "A97444")
        let woodShade = dark ? Color(hex: "5A3A22") : Color(hex: "85572E")
        let woodHi = dark ? Color(hex: "976A46") : Color(hex: "D39A66")
        let bookColors = [
            Color(hex: "D85A4F"), Color(hex: "4F7FDE"), Color(hex: "59B569"),
            Color(hex: "E5B04E"), Color(hex: "A26BDA"), Color(hex: "42B7C6")
        ]
        px(x, y, 20, 36, wood)
        px(x + 1, y, 18, 1, woodHi, 0.55)
        for row in 0..<3 {
            let shelfY = y + CGFloat(row) * 12 + 11
            px(x, shelfY, 20, 2, woodShade)
            let startY = y + CGFloat(row) * 12 + 2
            for b in 0..<4 {
                let bx = x + 2 + CGFloat(b) * 4
                let color = bookColors[(row * 4 + b) % bookColors.count]
                px(bx, startY + CGFloat(b % 2), 3, 8 - CGFloat(b % 2), color, 0.85)
                px(bx + 1, startY + 1 + CGFloat(b % 2), 1, 5, .white, 0.18)
            }
        }

    case "aquarium":
        let glass = Color(hex: dark ? "7AA9C6" : "A8D9F1")
        let water = Color(hex: dark ? "2D6A9D" : "5FB5E4")
        let stand = dark ? Color(hex: "55626F") : Color(hex: "8696A4")
        px(x + 1, y + 18, 20, 2, .black, dark ? 0.18 : 0.10)
        px(x, y, 22, 18, glass, 0.35)
        px(x + 1, y + 3, 20, 14, water, 0.55)
        px(x + 2, y + 2, 18, 1, .white, 0.18)
        px(x + 2, y + 14, 18, 2, Color(hex: "CFB078"), 0.65)
        let fishX = x + 5 + sin(Double(frame) * 0.06) * 5
        px(CGFloat(fishX), y + 8, 5, 3, Color(hex: "F48E47"), 0.85)
        px(CGFloat(fishX) + 4, y + 9, 2, 1, Color(hex: "F48E47"), 0.85)
        let fish2X = x + 12 + sin(Double(frame) * 0.04 + 2) * 4
        px(CGFloat(fish2X), y + 12, 4, 2, Color(hex: "63D4E6"), 0.8)
        px(CGFloat(fish2X) + 3, y + 12, 1, 1, Color(hex: "63D4E6"), 0.8)
        let bubbleY = y + 7 - sin(Double(frame) * 0.08) * 3
        px(x + 15, CGFloat(bubbleY), 2, 2, .white, 0.28)
        px(x + 13, CGFloat(bubbleY) + 4, 1.5, 1.5, .white, 0.22)
        px(x - 1, y + 17, 24, 2, stand)

    case "arcade":
        let body = dark ? Color(hex: "4B2A80") : Color(hex: "6B43B8")
        let bodyDark = dark ? Color(hex: "33195B") : Color(hex: "4B2D83")
        px(x + 1, y + 28, 14, 2, .black, dark ? 0.24 : 0.13)
        px(x, y + 2, 16, 28, body)
        px(x + 2, y, 12, 5, Color(hex: dark ? "6B4DAD" : "8F6CDB"))
        px(x + 2, y + 4, 12, 9, Color(hex: dark ? "12202E" : "1B2C38"))
        px(x + 4, y + 6, 8, 5, Theme.green, 0.35)
        px(x + 5, y + 16, 2, 2, Theme.red, 0.82)
        px(x + 10, y + 17, 2, 2, Color(hex: "F1D05A"), 0.7)
        px(x + 2, y + 27, 3, 4, bodyDark)
        px(x + 11, y + 27, 3, 4, bodyDark)
        px(x + 6, y + 1, 4, 1, Color.white, 0.2)

    case "whiteboard":
        let frameColor = dark ? Color(hex: "9BA5B3") : Color(hex: "C2C8D0")
        let board = dark ? Color(hex: "EEF2F6") : Color(hex: "F9FBFD")
        px(x + 1, y + 20, 28, 2, .black, dark ? 0.14 : 0.08)
        px(x, y, 30, 22, frameColor)
        px(x + 1.5, y + 1.5, 27, 19, board)
        px(x + 3, y + 4, 12, 1, Theme.red, 0.45)
        px(x + 3, y + 7, 18, 1, Theme.accent, 0.35)
        px(x + 3, y + 10, 10, 1, Theme.green, 0.35)
        px(x + 18, y + 6, 6, 4, Color(hex: "EACB93"), 0.35)
        px(x + 8, y + 20, 14, 2, Color(hex: dark ? "7D8793" : "9AA4AE"))

    case "lamp":
        let pole = dark ? Color(hex: "556270") : Color(hex: "90A0AE")
        let shade = dark ? Color(hex: "E7C76B") : Color(hex: "F4DB8B")
        let glow = 0.08 + sin(Double(frame) * 0.04) * 0.03
        px(x + 4, y + 8, 2, 22, pole)
        px(x + 1, y + 28, 8, 2, pole)
        px(x, y, 10, 8, shade, 0.8)
        px(x + 1, y + 1, 8, 2, .white, 0.12)
        context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y + 5, width: 20, height: 22)), with: .color(shade.opacity(glow)))

    case "cat":
        let fur = dark ? Color(hex: "CE9B58") : Color(hex: "D3A05E")
        let furLight = dark ? Color(hex: "E0BD7D") : Color(hex: "E9C889")
        px(x + 1, y + 10, 10, 2, .black, dark ? 0.14 : 0.08)
        px(x + 1, y + 3, 8, 6, fur)
        px(x + 7, y, 5, 5, fur)
        px(x + 7, y - 1, 2, 2, furLight)
        px(x + 10, y - 1, 2, 2, furLight)
        px(x + 8, y + 2, 1, 1, Theme.green, 0.85)
        px(x + 10, y + 2, 1, 1, Theme.green, 0.85)
        let tailWave = sin(Double(frame) * 0.08) * 2
        px(x - 1, y + 4 + CGFloat(tailWave), 3, 1, fur)

    case "tv":
        let body = dark ? Color(hex: "1A1E28") : Color(hex: "2A2E38")
        let screen = dark ? Color(hex: "0E2436") : Color(hex: "16364A")
        let cabinet = dark ? Color(hex: "765031") : Color(hex: "A16F44")
        px(x + 1, y + 16, 26, 2, .black, dark ? 0.20 : 0.10)
        px(x, y, 28, 18, body)
        px(x + 2, y + 2, 24, 13, screen)
        px(x + 4, y + 4, 20, 9, Theme.accent, 0.25)
        px(x + 11, y + 16, 6, 2, body)
        px(x + 4, y + 19, 20, 3, cabinet)
        px(x + 7, y + 20, 4, 1, Color(hex: "F0C25A"), 0.55)

    case "fan":
        let body = dark ? Color(hex: "5B6772") : Color(hex: "94A1AC")
        px(x + 5, y + 10, 2, 12, body)
        px(x + 2, y + 20, 8, 3, body)
        let fanAngle = Double(frame) * 0.3
        for blade in 0..<3 {
            let angle = fanAngle + Double(blade) * 2.094
            let bx = x + 6 + cos(angle) * 5
            let by = y + 6 + sin(angle) * 5
            context.fill(Path(ellipseIn: CGRect(x: CGFloat(bx) - 2, y: CGFloat(by) - 1, width: 4, height: 3)),
                         with: .color(body.opacity(0.6)))
        }
        px(x + 4, y + 4, 4, 4, body)

    case "calendar":
        let paper = dark ? Color(hex: "EDF0F5") : Color(hex: "FFFDF8")
        px(x, y, 14, 14, paper, 0.95)
        px(x, y, 14, 4, Theme.red, 0.82)
        px(x + 3, y + 2, 2, 2, Theme.overlayBg, 0.18)
        context.draw(
            Text("23").font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundColor(Theme.overlay.opacity(0.55)),
            at: CGPoint(x: x + 7, y: y + 10)
        )

    case "poster":
        px(x, y, 16, 20, Color(hex: dark ? "2D4D72" : "4178C2"), 0.92)
        px(x + 2, y + 2, 12, 16, Color(hex: dark ? "3B658F" : "5E90D7"), 0.45)
        px(x + 5, y + 4, 6, 6, Color(hex: "F6D96E"), 0.55)
        px(x + 3, y + 13, 10, 1, .white, 0.32)
        px(x + 4, y + 16, 8, 1, .white, 0.24)

    case "trashcan":
        let bin = dark ? Color(hex: "69737E") : Color(hex: "88929D")
        let lid = dark ? Color(hex: "85909B") : Color(hex: "A0A9B3")
        px(x + 1, y + 10, 8, 2, .black, dark ? 0.16 : 0.08)
        px(x + 1, y + 2, 8, 10, bin)
        px(x, y, 10, 3, lid)
        px(x + 4, y - 1, 2, 2, lid)
        px(x + 2, y + 4, 1, 5, .white, 0.10)

    case "cushion":
        let base = dark ? Color(hex: "A76B86") : Color(hex: "DD95B6")
        let light = dark ? Color(hex: "C288A1") : Color(hex: "F5B5CE")
        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 12, height: 8)), with: .color(base.opacity(0.85)))
        context.fill(Path(ellipseIn: CGRect(x: x + 2, y: y + 1, width: 8, height: 5)), with: .color(light.opacity(0.45)))
        px(x + 5.5, y + 2, 1, 3, Color(hex: dark ? "8B536C" : "C27A98"), 0.45)

    default:
        break
    }
}

