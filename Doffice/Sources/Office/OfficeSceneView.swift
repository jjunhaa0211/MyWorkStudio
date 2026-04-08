import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Scene View (메인 씬 뷰)
// ═══════════════════════════════════════════════════════

struct OfficeSceneView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var registry = CharacterRegistry.shared
    @ObservedObject private var pluginHost = PluginHost.shared
    @ObservedObject private var store: OfficeSceneStore
    @ObservedObject private var controller: OfficeCharacterController
    @State private var selectedFurnitureId: String?
    @State private var draggingAnchorId: String?
    @State private var dragFurnitureOffset = TileCoord(col: 0, row: 0)
    @State private var currentFPS: Double = OfficeConstants.fps
    @State private var tappedCharacterTabId: String?
    @State private var pluginPlacementNotice: String?
    @State private var editPanelCollapsed = false

    private let map: OfficeMap
    /// Single consolidated timer — fires at max FPS, advance() throttles internally
    let timer = Timer.publish(every: 1.0 / OfficeConstants.fps, on: .main, in: .common).autoconnect()
    /// Chrome screenshots & FPS check on slower cadence
    let slowTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    private static func computeAdaptiveFPS() -> Double {
        if AppSettings.shared.effectivePerformanceMode {
            return 4  // Very low FPS in performance mode
        }
        let tabs = SessionManager.shared.userVisibleTabs
        // Single pass: determine highest activity level across all tabs
        var hasActive = false
        for tab in tabs {
            if tab.isProcessing { return OfficeConstants.fps } // 24 — early exit
            if tab.claudeActivity != .idle { hasActive = true }
        }
        return hasActive ? 12 : 6
    }

    init(store: OfficeSceneStore = .shared) {
        self._store = ObservedObject(wrappedValue: store)
        self._controller = ObservedObject(wrappedValue: store.controller)
        self.map = store.map
    }

    private var sceneTheme: BackgroundTheme {
        resolvedOfficeSceneTheme(settings)
    }

    private var scenePalette: OfficeScenePalette {
        OfficeScenePalette(theme: sceneTheme, dark: settings.isDarkMode)
    }

    private var viewportBackground: LinearGradient {
        if settings.isDarkMode {
            return LinearGradient(
                colors: [
                    Theme.bgCard.opacity(0.98),
                    Theme.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        return LinearGradient(
            colors: [
                HexColorCache.shared.color(for: scenePalette.backdropTop).opacity(0.92),
                HexColorCache.shared.color(for: scenePalette.backdropBottom)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var isFocusMode: Bool {
        settings.officeViewMode == "side"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let metrics = sceneMetrics(for: size)
                    let visibleTabs = manager.userVisibleTabs
                    let palette = store.cachedPalette(theme: sceneTheme, dark: settings.isDarkMode)
                    store.updateTabLookupIfNeeded(tabs: visibleTabs)
                    var renderer = OfficeSpriteRenderer(
                        map: map,
                        characters: controller.characters,
                        tabs: visibleTabs,
                        frame: store.frame,
                        dark: settings.isDarkMode,
                        theme: sceneTheme,
                        selectedTabId: manager.activeTabId,
                        selectedFurnitureId: selectedFurnitureId,
                        cachedPalette: palette,
                        cachedTabLookup: store.cachedTabLookup
                    )
                    renderer.chromeScreenshots = store.chromeScreenshots
                    if let background = store.backgroundSnapshot {
                        var bgContext = context
                        bgContext.translateBy(x: metrics.offsetX, y: metrics.offsetY)
                        bgContext.scaleBy(x: metrics.scale, y: metrics.scale)
                        bgContext.draw(
                            Image(decorative: background, scale: 1),
                            in: CGRect(
                                x: 0,
                                y: 0,
                                width: CGFloat(map.cols) * OfficeConstants.tileSize,
                                height: CGFloat(map.rows) * OfficeConstants.tileSize
                            )
                        )
                        renderer.renderDynamicLayers(
                            context: context,
                            scale: metrics.scale,
                            offsetX: metrics.offsetX,
                            offsetY: metrics.offsetY
                        )
                    } else {
                        renderer.render(
                            context: context,
                            scale: metrics.scale,
                            offsetX: metrics.offsetX,
                            offsetY: metrics.offsetY
                        )
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value, size: geometry.size)
                        }
                        .onEnded { value in
                            handleDragEnded(value, size: geometry.size)
                        }
                )

                // 편집 모드에서는 가구 드래그를 방해하므로 숨김
                if !settings.isEditMode, let activeTab = manager.activeTab {
                    selectionPanel(tab: activeTab)
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: isFollowing ? .bottomLeading : .topLeading)
                }

                if let boss = registry.activeBossCharacter {
                    bossTicker(character: boss)
                        .padding(.top, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if settings.isEditMode {
                    editPanel
                        .padding(10)
                        .frame(width: 220, alignment: .topTrailing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                if isFollowing, let followId = store.followingCharacterId,
                   let character = controller.characters[followId] {
                    followIndicator(name: character.displayName)
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }

                // 캐릭터 탭 시 액션 메뉴
                if let tabId = tappedCharacterTabId,
                   let tab = manager.userVisibleTabs.first(where: { $0.id == tabId }) {
                    characterActionPopover(tab: tab)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
        .background(viewportBackground)
        .clipped()
        .task(id: "\(sceneTheme.rawValue)-\(settings.isDarkMode)-\(store.currentPreset.rawValue)") {
            await MainActor.run {
                store.prepareBackgroundSnapshot(theme: sceneTheme, dark: settings.isDarkMode)
            }
        }
        .onReceive(timer) { _ in
            store.advance(with: manager.userVisibleTabs, activeTabId: manager.activeTab?.id, focusMode: isFocusMode, fps: currentFPS)
        }
        .onReceive(slowTimer) { _ in
            // FPS check
            let newFPS = Self.computeAdaptiveFPS()
            if newFPS != currentFPS { currentFPS = newFPS }
            // Chrome refresh
            Task { @MainActor in
                store.prepareBackgroundSnapshot(theme: sceneTheme, dark: settings.isDarkMode)
                await store.refreshChromeScreenshots(for: manager.userVisibleTabs, activeTabId: manager.activeTab?.id)
            }
        }
        .onChange(of: settings.isEditMode) { _, isEditMode in
            if !isEditMode {
                draggingAnchorId = nil
                selectedFurnitureId = nil
            }
        }
        .onChange(of: settings.officePreset) { _, newValue in
            guard let preset = OfficePreset(rawValue: newValue),
                  preset != store.currentPreset else { return }
            store.applyPreset(preset, with: manager.userVisibleTabs)
            selectedFurnitureId = nil
            draggingAnchorId = nil
        }
    }

    // MARK: - Character Action Popover

    @ViewBuilder
    private func characterActionPopover(tab: TerminalTab) -> some View {
        let rosterChar = tab.characterId.flatMap { registry.character(with: $0) }
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let char = rosterChar {
                    CharacterMiniAvatar(character: char, pixelScale: 2.0, bgOpacity: 0)
                        .frame(width: 32, height: 38)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(rosterChar?.name ?? tab.workerName)
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(rosterChar?.localizedArchetype ?? tab.projectName)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Button(action: { withAnimation(.easeOut(duration: 0.15)) { tappedCharacterTabId = nil } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.bgSurface))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Rectangle().fill(Theme.border).frame(height: 1)

            VStack(spacing: 4) {
                actionButton(NSLocalizedString("office.action.terminal", comment: ""), icon: "terminal", tint: Theme.accent) {
                    tappedCharacterTabId = nil
                    NotificationCenter.default.post(name: .dofficeFocusCharacterTab, object: nil, userInfo: ["tabId": tab.id])
                }

                if let char = rosterChar {
                    Menu {
                        ForEach(WorkerJob.allCases, id: \.self) { role in
                            Button(action: { registry.setJobRole(role, for: char.id) }) {
                                HStack {
                                    Text(role.icon)
                                    Text(role.displayName)
                                    if char.jobRole == role { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.text.rectangle").font(.system(size: 9))
                            Text(NSLocalizedString("office.action.role", comment: "")).font(Theme.mono(9, weight: .medium))
                            Spacer()
                            Text("\(char.jobRole.icon) \(char.jobRole.displayName)").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.cyan)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cyan.opacity(0.06)))
                    }

                    actionButton(
                        char.isOnVacation ? NSLocalizedString("char.return.to.work", comment: "") : NSLocalizedString("char.vacation", comment: ""),
                        icon: char.isOnVacation ? "figure.walk.arrival" : "beach.umbrella",
                        tint: char.isOnVacation ? Theme.green : Theme.orange
                    ) { registry.setVacation(!char.isOnVacation, for: char.id) }

                    actionButton(NSLocalizedString("char.fire", comment: ""), icon: "person.fill.xmark", tint: Theme.red) {
                        registry.fire(char.id)
                        withAnimation(.easeOut(duration: 0.15)) { tappedCharacterTabId = nil }
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgCard).shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 9))
                Text(title).font(Theme.mono(9, weight: .medium))
                Spacer()
            }
            .foregroundColor(tint)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overlay Panels

    private func selectionPanel(tab: TerminalTab) -> some View {
        let status = tab.statusPresentation
        let rosterCharacter = tab.characterId.flatMap { registry.character(with: $0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if let char = rosterCharacter {
                    CharacterMiniAvatar(character: char, pixelScale: 1.4, bgOpacity: 0.15)
                        .frame(width: 30, height: 36)
                        .id(char.id)
                } else {
                    Circle()
                        .fill(tab.workerColor)
                        .padding(.top, 4)
                        .frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.workerName)
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(tab.projectName)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    selectionBadge(tab.workerJob.displayName, tint: roleTint(for: tab.workerJob))
                    AppStatusBadge(title: status.label, symbol: status.symbol, tint: status.tint)
                }
            }

            HStack(spacing: 6) {
                if let badge = tab.officeLatestToolBadge {
                    selectionBadge(badge.label, tint: badge.tint)
                }
                if tab.pendingApproval != nil && tab.officeLatestToolBadge == nil {
                    selectionBadge(NSLocalizedString("office.approval.needed", comment: ""), tint: Theme.yellow)
                }
            }

            if tab.officeSelectionSubtitle != status.label {
                Text(tab.officeSelectionSubtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(tab.officeActivityTint)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                infoStat(title: NSLocalizedString("office.activity", comment: ""), value: status.label, tint: status.tint)
                infoStat(title: NSLocalizedString("office.tokens", comment: ""), value: tab.officeCompactTokenText, tint: Theme.accent)
                infoStat(title: NSLocalizedString("office.files", comment: ""), value: "\(tab.fileChanges.count)", tint: Theme.green)
            }

            if let parallelSummary = tab.officeParallelSummary {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: Theme.iconSize(9), weight: .bold))
                        .foregroundColor(Theme.purple)
                    Text(parallelSummary)
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundColor(Theme.purple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .fill(Theme.purple.opacity(0.1))
                )
            }

            if !tab.officeRecentFileNames.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("office.recent.changes", comment: ""))
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundColor(Theme.textDim)
                    ForEach(tab.officeRecentFileNames, id: \.self) { name in
                        Text("• \(name)")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            if let pendingApproval = tab.pendingApproval {
                Text(String(format: NSLocalizedString("office.approval.pending", comment: ""), pendingApproval.command))
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.yellow)
                    .lineLimit(2)
            }
        }
        .frame(width: 250, alignment: .leading)
        .appPanelStyle(padding: Theme.sp3, radius: Theme.cornerXL, fill: Theme.bgCard.opacity(0.92), strokeOpacity: 0.20, shadow: false)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .stroke(tab.workerColor.opacity(0.26), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("office.accessibility.worker.info", comment: ""), tab.workerName))
        .accessibilityValue(String(format: NSLocalizedString("office.accessibility.worker.value", comment: ""), status.label, tab.officeCompactTokenText, tab.fileChanges.count))
    }

    private func selectionBadge(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(Theme.mono(8, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(0.12))
            )
    }

    private func bossTicker(character: WorkerCharacter) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: Theme.iconSize(11)))
                .foregroundColor(Theme.orange)
            Text("\(character.name) 사장: \(registry.bossLine(frame: store.frame))")
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                .fill(Theme.bgCard.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                        .stroke(Theme.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Furniture Catalog Data

    private struct FurnitureCatalogItem: Identifiable {
        let id: String
        let type: FurnitureType?
        let isDeskSet: Bool
        let name: String
        let icon: String
        let size: TileSize

        init(type: FurnitureType, name: String, icon: String, size: TileSize) {
            self.id = type.rawValue
            self.type = type
            self.isDeskSet = false
            self.name = name
            self.icon = icon
            self.size = size
        }

        init(deskSetName: String, icon: String) {
            self.id = "deskSet"
            self.type = nil
            self.isDeskSet = true
            self.name = deskSetName
            self.icon = icon
            self.size = TileSize(w: 3, h: 2)
        }
    }

    private var furnitureCatalog: [FurnitureCatalogItem] {
        [
            FurnitureCatalogItem(deskSetName: NSLocalizedString("furniture.deskSet", value: "책상 세트", comment: ""), icon: "desktopcomputer"),
            FurnitureCatalogItem(type: .roundTable, name: NSLocalizedString("furniture.roundTable", value: "원탁", comment: ""), icon: "circle.grid.2x2", size: TileSize(w: 2, h: 2)),
            FurnitureCatalogItem(type: .sofa, name: NSLocalizedString("furniture.sofa", value: "소파", comment: ""), icon: "sofa", size: TileSize(w: 3, h: 2)),
            FurnitureCatalogItem(type: .bookshelf, name: NSLocalizedString("furniture.bookshelf", value: "책장", comment: ""), icon: "books.vertical", size: TileSize(w: 2, h: 1)),
            FurnitureCatalogItem(type: .plant, name: NSLocalizedString("furniture.plant", value: "화분", comment: ""), icon: "leaf", size: TileSize(w: 1, h: 1)),
            FurnitureCatalogItem(type: .coffeeMachine, name: NSLocalizedString("furniture.coffeeMachine", value: "커피머신", comment: ""), icon: "cup.and.saucer", size: TileSize(w: 1, h: 1)),
            FurnitureCatalogItem(type: .waterCooler, name: NSLocalizedString("furniture.waterCooler", value: "정수기", comment: ""), icon: "drop", size: TileSize(w: 1, h: 1)),
            FurnitureCatalogItem(type: .printer, name: NSLocalizedString("furniture.printer", value: "프린터", comment: ""), icon: "printer", size: TileSize(w: 1, h: 1)),
            FurnitureCatalogItem(type: .trashBin, name: NSLocalizedString("furniture.trashBin", value: "휴지통", comment: ""), icon: "trash", size: TileSize(w: 1, h: 1)),
            FurnitureCatalogItem(type: .lamp, name: NSLocalizedString("furniture.lamp", value: "조명", comment: ""), icon: "lamp.desk", size: TileSize(w: 1, h: 1)),
            FurnitureCatalogItem(type: .rug, name: NSLocalizedString("furniture.rug", value: "러그", comment: ""), icon: "rectangle.checkered", size: TileSize(w: 5, h: 3)),
            FurnitureCatalogItem(type: .whiteboard, name: NSLocalizedString("furniture.whiteboard", value: "화이트보드", comment: ""), icon: "rectangle.on.rectangle", size: TileSize(w: 4, h: 1)),
            FurnitureCatalogItem(type: .pictureFrame, name: NSLocalizedString("furniture.pictureFrame", value: "액자", comment: ""), icon: "photo", size: TileSize(w: 3, h: 1)),
            FurnitureCatalogItem(type: .clock, name: NSLocalizedString("furniture.clock", value: "시계", comment: ""), icon: "clock", size: TileSize(w: 1, h: 1)),
        ]
    }

    // MARK: - Edit Panel

    private var selectedFurniture: FurniturePlacement? {
        guard let selectedFurnitureId else { return nil }
        return map.furniture.first(where: { $0.id == selectedFurnitureId })
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("LAYOUT EDIT")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(Theme.textDim)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { editPanelCollapsed.toggle() }
                } label: {
                    Image(systemName: editPanelCollapsed ? "chevron.right" : "chevron.left")
                        .font(.system(size: Theme.iconSize(8), weight: .bold))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }

            // 선택된 가구 정보 + 액션 버튼
            if let furniture = selectedFurniture {
                VStack(alignment: .leading, spacing: 4) {
                    Text(furniture.type.rawValue.uppercased())
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(Theme.yellow)

                    HStack(spacing: 4) {
                        Button {
                            let id = furniture.id
                            _ = map.removeFurniture(id: id)
                            selectedFurnitureId = nil
                            store.refreshLayout(with: manager.userVisibleTabs)
                            store.saveCurrentLayout()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: Theme.iconSize(8)))
                                Text("Delete")
                                    .font(Theme.mono(8, weight: .bold))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.red.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.red.opacity(0.28), lineWidth: 1))

                        Button {
                            toggleMirror(for: furniture.id)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                    .font(.system(size: Theme.iconSize(8)))
                                Text("Mirror")
                                    .font(Theme.mono(8, weight: .bold))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.purple.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.purple.opacity(0.28), lineWidth: 1))
                    }
                }
            } else {
                Text(NSLocalizedString("office.furniture.move", comment: ""))
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textSecondary)
            }

            if let pluginPlacementNotice {
                Text(pluginPlacementNotice)
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.green.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.green.opacity(0.24), lineWidth: 1))
            }

            if !editPanelCollapsed {
            ScrollView(.vertical, showsIndicators: false) {
                let gridColumns = [GridItem(.adaptive(minimum: 72, maximum: 90), spacing: 6)]
                VStack(alignment: .trailing, spacing: 8) {
                    // 기본 가구 카탈로그
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FURNITURE")
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(Theme.orange)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        LazyVGrid(columns: gridColumns, spacing: 6) {
                            ForEach(furnitureCatalog) { item in
                                Button {
                                    placeStandardFurniture(item)
                                } label: {
                                    VStack(spacing: 3) {
                                        Canvas { ctx, canvasSize in
                                            let furnitureType = item.type ?? .desk
                                            OfficeSpriteRenderer.drawDetailedFurniture(
                                                ctx, type: furnitureType,
                                                x: 2, y: 2,
                                                w: canvasSize.width - 4,
                                                h: canvasSize.height - 4,
                                                dark: false, frame: 0
                                            )
                                        }
                                        .frame(width: 48, height: 48)
                                        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgSurface.opacity(0.6)))
                                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border.opacity(0.3), lineWidth: 1))

                                        Text(item.name)
                                            .font(Theme.mono(7, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                            .lineLimit(1)
                                        Text("\(item.size.w)x\(item.size.h)")
                                            .font(Theme.mono(6))
                                            .foregroundColor(Theme.textDim)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard.opacity(0.6)))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.green.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Plugin furniture placement section
                    if !pluginHost.furniture.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PLUGIN FURNITURE")
                                .font(Theme.mono(8, weight: .bold))
                                .foregroundColor(Theme.purple)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            LazyVGrid(columns: gridColumns, spacing: 6) {
                                ForEach(pluginHost.furniture) { item in
                                    Button {
                                        placePluginFurniture(item)
                                    } label: {
                                        VStack(spacing: 3) {
                                            Canvas { ctx, canvasSize in
                                                OfficeSpriteRenderer.drawDetailedFurniture(
                                                    ctx, type: .plugin,
                                                    x: 2, y: 2,
                                                    w: canvasSize.width - 4,
                                                    h: canvasSize.height - 4,
                                                    dark: false, frame: 0,
                                                    pluginFurnitureId: item.decl.id
                                                )
                                            }
                                            .frame(width: 48, height: 48)
                                            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgSurface.opacity(0.6)))
                                            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.purple.opacity(0.3), lineWidth: 1))

                                            Text(item.decl.name)
                                                .font(Theme.mono(7, weight: .bold))
                                                .foregroundColor(Theme.textPrimary)
                                                .lineLimit(1)
                                            Text("\(item.decl.width)x\(item.decl.height)")
                                                .font(Theme.mono(6))
                                                .foregroundColor(Theme.purple)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard.opacity(0.6)))
                                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.purple.opacity(0.2), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
            } // end if !editPanelCollapsed

            HStack(spacing: 6) {
                Button(NSLocalizedString("office.save", comment: "")) {
                    store.saveCurrentLayout()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, Theme.sp2 - 2)
                .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.accent.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accent.opacity(0.36), lineWidth: 1))

                Button(NSLocalizedString("office.reset", comment: "")) {
                    store.resetCurrentLayout(with: manager.userVisibleTabs)
                    selectedFurnitureId = nil
                    pluginPlacementNotice = nil
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, Theme.sp2 - 2)
                .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgCard.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border.opacity(0.7), lineWidth: 1))

                Button(NSLocalizedString("office.done", comment: "")) {
                    settings.isEditMode = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, Theme.sp2 - 2)
                .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.yellow.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.yellow.opacity(0.34), lineWidth: 1))
            }
        }
        .padding(Theme.sp3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .fill(Theme.bgCard.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerXL)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Place a plugin furniture item at the first available open position on the map
    private func placePluginFurniture(_ item: PluginHost.LoadedFurniture) {
        let decl = item.decl
        let zone: OfficeZone
        switch decl.zone ?? "mainOffice" {
        case "pantry": zone = .pantry
        case "meetingRoom": zone = .meetingRoom
        case "hallway": zone = .hallway
        default: zone = .mainOffice
        }

        // Find an open position by scanning the map for a non-colliding spot
        let maxRow = map.rows - decl.height
        let maxCol = map.cols - decl.width
        var placementPosition: TileCoord?
        guard maxRow >= 1 && maxCol >= 1 else { return }
        for row in 1..<maxRow {
            for col in 1..<maxCol {
                // Check that all tiles are walkable floor (not void/wall)
                var allFloor = true
                for dr in 0..<decl.height {
                    for dc in 0..<decl.width {
                        guard row + dr < map.rows && col + dc < map.cols else {
                            allFloor = false; break
                        }
                        let t = map.tiles[row + dr][col + dc]
                        if !t.isWalkable { allFloor = false; break }
                    }
                    if !allFloor { break }
                }
                guard allFloor else { continue }

                // Check no collision with existing furniture (except rugs)
                let collides = map.furniture.contains { existing in
                    guard existing.type != .rug else { return false }
                    let eMinCol = existing.position.col
                    let eMaxCol = existing.position.col + existing.size.w
                    let eMinRow = existing.position.row
                    let eMaxRow = existing.position.row + existing.size.h
                    return col < eMaxCol && col + decl.width > eMinCol && row < eMaxRow && row + decl.height > eMinRow
                }
                if !collides {
                    placementPosition = TileCoord(col: col, row: row)
                    break
                }
            }
            if placementPosition != nil { break }
        }

        guard let position = placementPosition else { return }

        let uniqueId = "plugin_\(item.pluginName)_\(decl.id)_\(Int(Date().timeIntervalSince1970))"
        let placement = FurniturePlacement(
            id: uniqueId,
            type: .plugin,
            position: position,
            size: TileSize(w: decl.width, h: decl.height),
            zone: zone,
            pluginFurnitureId: decl.id
        )

        map.furniture.append(placement)
        map.rebuildWalkability()
        selectedFurnitureId = uniqueId
        store.refreshLayout(with: manager.userVisibleTabs)
        store.saveCurrentLayout()
    }

    private func placeStandardFurniture(_ item: FurnitureCatalogItem) {
        if item.isDeskSet {
            let maxRow = map.rows - 2
            let maxCol = map.cols - 3
            for row in 1..<maxRow {
                for col in 1..<maxCol {
                    let pos = TileCoord(col: col, row: row)
                    if map.addDeskSet(at: pos, zone: .mainOffice) {
                        selectedFurnitureId = map.furniture.last(where: { $0.id.hasPrefix("desk_") })?.id
                        pluginPlacementNotice = "ADDED \(item.name.uppercased())"
                        store.refreshLayout(with: manager.userVisibleTabs)
                        store.saveCurrentLayout()
                        return
                    }
                }
            }
            pluginPlacementNotice = "NO OPEN SPACE"
            return
        }

        guard let type = item.type else { return }
        let size = item.size
        let maxRow = map.rows - size.h
        let maxCol = map.cols - size.w
        guard maxRow >= 1 && maxCol >= 1 else {
            pluginPlacementNotice = "NO OPEN SPACE"
            return
        }
        for row in 1..<maxRow {
            for col in 1..<maxCol {
                let pos = TileCoord(col: col, row: row)
                if let placed = map.addFurniture(type, at: pos, zone: .mainOffice, size: size) {
                    selectedFurnitureId = placed.id
                    pluginPlacementNotice = "ADDED \(item.name.uppercased())"
                    store.refreshLayout(with: manager.userVisibleTabs)
                    store.saveCurrentLayout()
                    return
                }
            }
        }
        pluginPlacementNotice = "NO OPEN SPACE"
    }

    private func toggleMirror(for furnitureId: String) {
        guard let idx = map.furniture.firstIndex(where: { $0.id == furnitureId }) else { return }
        map.furniture[idx].mirrored.toggle()
        store.invalidateBackgroundSnapshot()
        store.saveCurrentLayout()
    }

    private func infoStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.mono(7, weight: .bold))
                .foregroundColor(Theme.textDim)
            Text(value)
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .fill(Theme.bgSurface.opacity(0.85))
        )
    }

    private func followIndicator(name: String) -> some View {
        VStack(spacing: 6) {
            // 줌 조절 버튼
            HStack(spacing: 0) {
                Button(action: {
                    store.followZoomLevel = max(1.2, store.followZoomLevel - 0.3)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                        .foregroundColor(store.followZoomLevel <= 1.2 ? Theme.textDim.opacity(0.4) : Theme.textPrimary)
                        .frame(width: 30, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(store.followZoomLevel <= 1.2)

                Text("\(Int(store.followZoomLevel * 100))%")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 44)

                Button(action: {
                    store.followZoomLevel = min(3.0, store.followZoomLevel + 0.3)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                        .foregroundColor(store.followZoomLevel >= 3.0 ? Theme.textDim.opacity(0.4) : Theme.textPrimary)
                        .frame(width: 30, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(store.followZoomLevel >= 3.0)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.bgCard.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )

            // 추적 상태 + 닫기
            Button(action: { store.followingCharacterId = nil }) {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .font(.system(size: Theme.iconSize(9), weight: .bold))
                        .foregroundColor(Theme.cyan)
                    Text("\(name) 추적 중")
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(Theme.cyan)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(Theme.textDim)
                }
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, Theme.sp2 - 1)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                        .fill(Theme.bgCard.opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                                .stroke(Theme.cyan.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func roleTint(for role: WorkerJob) -> Color {
        switch role {
        case .developer: return Theme.accent
        case .qa: return Theme.green
        case .reporter: return Theme.purple
        case .boss: return Theme.orange
        case .planner: return Theme.cyan
        case .reviewer: return Theme.yellow
        case .designer: return Theme.pink
        case .sre: return Theme.red
        }
    }

    // MARK: - Interaction

    private func handleDragChanged(_ value: DragGesture.Value, size: CGSize) {
        let tile = tileCoord(for: value.location, size: size)

        if settings.isEditMode {
            if draggingAnchorId == nil {
                guard let tappedFurniture = map.selectedFurniture(at: tile) else {
                    selectedFurnitureId = nil
                    return
                }

                let anchorId = map.movableAnchorId(for: tappedFurniture.id)
                guard let anchor = map.furniture.first(where: { $0.id == anchorId }) else { return }
                draggingAnchorId = anchorId
                selectedFurnitureId = anchorId
                dragFurnitureOffset = TileCoord(
                    col: tile.col - anchor.position.col,
                    row: tile.row - anchor.position.row
                )
                return
            }

            guard let draggingAnchorId else { return }
            let newOrigin = TileCoord(
                col: tile.col - dragFurnitureOffset.col,
                row: tile.row - dragFurnitureOffset.row
            )
            if map.placeFurnitureGroup(anchorId: draggingAnchorId, at: newOrigin) {
                store.refreshLayout(with: manager.userVisibleTabs)
            }
            return
        }

        draggingAnchorId = nil
    }

    private func handleDragEnded(_ value: DragGesture.Value, size: CGSize) {
        defer {
            draggingAnchorId = nil
        }

        if settings.isEditMode {
            if selectedFurnitureId != nil {
                store.saveCurrentLayout()
                store.refreshLayout(with: manager.userVisibleTabs)
            }
            return
        }

        let movement = hypot(value.translation.width, value.translation.height)
        guard movement < 8 else { return }

        let scenePoint = scenePoint(for: value.location, size: size)

        // 팔로우 중 빈 곳 탭 → 팔로우 해제
        if isFollowing {
            if let tabId = hitTestCharacter(at: scenePoint) {
                if tabId == store.followingCharacterId {
                    // 같은 캐릭터 다시 탭 → 팔로우 해제
                    store.followingCharacterId = nil
                } else {
                    // 다른 캐릭터 탭 → 대상 변경
                    store.followingCharacterId = tabId
                    manager.selectTab(tabId)
                }
            } else {
                store.followingCharacterId = nil
            }
            selectedFurnitureId = nil
            return
        }

        guard let tabId = hitTestCharacter(at: scenePoint) else { return }
        // 캐릭터를 탭하면 선택 + 팔로우 + 메뉴 표시
        manager.selectTab(tabId)
        store.followingCharacterId = tabId
        selectedFurnitureId = nil
        tappedCharacterTabId = tabId
    }

    private func hitTestCharacter(at point: CGPoint) -> String? {
        // Find nearest character within threshold without sorting all characters
        let threshold: CGFloat = 12
        var bestId: String?
        var bestDist: CGFloat = threshold
        for (id, character) in controller.characters {
            let dist = hypot(character.pixelX - point.x, character.pixelY - point.y)
            if dist < bestDist {
                bestDist = dist
                bestId = id
            }
        }
        return bestId
    }

    // MARK: - Scene Coordinates

    private var isFollowing: Bool {
        store.followingCharacterId != nil
    }

    private func sceneMetrics(for size: CGSize) -> (scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let worldWidth = max(1, CGFloat(map.cols) * OfficeConstants.tileSize)
        let worldHeight = max(1, CGFloat(map.rows) * OfficeConstants.tileSize)
        let overviewScale = min(size.width / worldWidth, size.height / worldHeight)
        let useZoom = isFocusMode || isFollowing
        let scale = useZoom ? min(max(overviewScale * store.cameraZoom, overviewScale), overviewScale * 3.2) : overviewScale

        let rawOffsetX = size.width / 2 - store.cameraCenter.x * scale
        let rawOffsetY = size.height / 2 - store.cameraCenter.y * scale
        let minOffsetX = min(0, size.width - worldWidth * scale)
        let minOffsetY = min(0, size.height - worldHeight * scale)
        let offsetX = worldWidth * scale < size.width ? (size.width - worldWidth * scale) / 2 : min(0, max(minOffsetX, rawOffsetX))
        let offsetY = worldHeight * scale < size.height ? (size.height - worldHeight * scale) / 2 : min(0, max(minOffsetY, rawOffsetY))
        return (scale, offsetX, offsetY)
    }

    private func scenePoint(for location: CGPoint, size: CGSize) -> CGPoint {
        let metrics = sceneMetrics(for: size)
        let x = (location.x - metrics.offsetX) / metrics.scale
        let y = (location.y - metrics.offsetY) / metrics.scale
        return CGPoint(x: x, y: y)
    }

    private func tileCoord(for location: CGPoint, size: CGSize) -> TileCoord {
        let point = scenePoint(for: location, size: size)
        let col = min(max(Int(point.x / OfficeConstants.tileSize), 0), map.cols - 1)
        let row = min(max(Int(point.y / OfficeConstants.tileSize), 0), map.rows - 1)
        return TileCoord(col: col, row: row)
    }
}
