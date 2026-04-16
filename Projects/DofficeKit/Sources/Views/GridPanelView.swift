import SwiftUI
import DesignSystem

// MARK: - Grid Panel View
// ═══════════════════════════════════════════════════════

public struct GridPanelView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var bottomPanel: BottomPanel = .none
    @State private var bottomPanelHeight: CGFloat = 280

    enum BottomPanel { case none, history, browser }

    private var hasPinnedTabs: Bool { !manager.pinnedTabIds.isEmpty }

    private var pinnedTabs: [TerminalTab] {
        manager.userVisibleTabs.filter { manager.pinnedTabIds.contains($0.id) }
    }

    private var visibleGroups: [SessionManager.ProjectGroup] {
        if let selectedPath = manager.selectedGroupPath {
            let tabs = manager.visibleTabs
            guard let first = tabs.first else { return [] }
            return [SessionManager.ProjectGroup(id: selectedPath, projectName: first.projectName, tabs: tabs, hasActiveTab: tabs.contains(where: { $0.id == manager.activeTabId }))]
        }
        return manager.projectGroups
    }

    private var isFiltered: Bool { manager.selectedGroupPath != nil }

    public var body: some View {
        VStack(spacing: 0) {
            // Main grid area
            if manager.visibleTabs.isEmpty {
                EmptySessionView()
            } else if hasPinnedTabs {
                pinnedGridView
            } else if manager.focusSingleTab, let tab = manager.activeTab {
                EventStreamView(tab: tab, compact: false)
            } else {
                defaultGridView
            }

            // Bottom panel toggle bar
            bottomPanelBar

            // Bottom panel content
            if bottomPanel != .none {
                ResizableDivider(height: $bottomPanelHeight)
                Group {
                    switch bottomPanel {
                    case .history: HistoryPanelView()
                    case .browser: BrowserPanelView()
                    case .none: EmptyView()
                    }
                }
                .frame(height: bottomPanelHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: bottomPanel)
    }

    private var bottomPanelBar: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                bottomPanelButton("clock.arrow.circlepath", NSLocalizedString("terminal.mode.history", comment: ""), panel: .history)
                bottomPanelButton("globe", "Browser", panel: .browser)
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
    }

    private func bottomPanelButton(_ icon: String, _ label: String, panel: BottomPanel) -> some View {
        let selected = bottomPanel == panel
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                bottomPanel = bottomPanel == panel ? .none : panel
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                Text(label).font(Theme.chrome(8, weight: selected ? .bold : .regular))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(selected ? Theme.accent.opacity(0.12) : .clear))
        }.buttonStyle(.plain)
    }

    // Pinned tabs grid: show only selected tabs
    private var pinnedGridView: some View {
        let tabs = pinnedTabs
        let cols = tabs.count <= 1 ? 1 : tabs.count <= 4 ? 2 : 3
        return GeometryReader { geo in
            let totalH = geo.size.height
            let rows = max(1, Int(ceil(Double(tabs.count) / Double(cols))))
            let cellH = max(120, (totalH - CGFloat(rows + 1) * 6) / CGFloat(rows))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: 6) {
                    ForEach(tabs) { tab in
                        GridSinglePanel(tab: tab, isSelected: manager.activeTabId == tab.id)
                            .frame(height: cellH)
                            .onTapGesture { manager.focusSingleTab = true; manager.selectTab(tab.id) }
                    }
                }.padding(6)
            }.background(Theme.bg)
        }
    }

    // Default grid: show groups
    private var defaultGridView: some View {
        let groups = visibleGroups
        let tabCount = groups.reduce(0) { $0 + $1.tabs.count }
        let cols = tabCount <= 1 ? 1 : tabCount <= 4 ? 2 : 3
        return GeometryReader { geo in
            let totalH = geo.size.height
            let rows = max(1, Int(ceil(Double(tabCount) / Double(cols))))
            let cellH = max(120, (totalH - CGFloat(rows + 1) * 6) / CGFloat(rows))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: 6) {
                    ForEach(groups) { group in
                        if isFiltered && group.tabs.count > 1 {
                            ForEach(group.tabs) { tab in
                                GridSinglePanel(tab: tab, isSelected: manager.activeTabId == tab.id)
                                    .frame(height: cellH)
                                    .onTapGesture { manager.focusSingleTab = true; manager.selectTab(tab.id) }
                            }
                        } else {
                            GridGroupPanel(group: group)
                                .frame(height: cellH)
                        }
                    }
                }.padding(6)
            }.background(Theme.bg)
        }
    }
}

// 선택된 그룹 내 개별 탭 패널
public struct GridSinglePanel: View {
    @ObservedObject var tab: TerminalTab
    @ObservedObject private var settings = AppSettings.shared
    public let isSelected: Bool

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(tab.isBrowserTab ? Theme.accent : tab.workerColor).frame(width: 3, height: 12)
                if tab.isBrowserTab {
                    Image(systemName: "globe").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.accent)
                    Text("Browser").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.accent)
                } else {
                    Text(tab.workerName).font(Theme.chrome(9, weight: .bold)).foregroundColor(tab.workerColor)
                    Text(tab.projectName).font(Theme.chrome(9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                if !tab.isBrowserTab {
                    if tab.isProcessing { ProgressView().scaleEffect(0.35).frame(width: 8, height: 8) }
                    Text(tab.selectedModel.icon).font(Theme.chrome(9))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(isSelected ? Theme.bgSelected : Theme.bgCard)

            if tab.isBrowserTab {
                // Grid에서는 경량 플레이스홀더 — 클릭 시 Single 모드로 전환
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "globe")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(Theme.accent.opacity(0.5))
                    Text(tab.browserURL.isEmpty ? "Browser" : tab.browserURL)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                    Text(NSLocalizedString("terminal.click.to.open", comment: "클릭하여 열기"))
                        .font(Theme.chrome(8))
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
            } else {
                EventStreamView(tab: tab, compact: true)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1))
    }
}

public struct GridGroupPanel: View {
    public let group: SessionManager.ProjectGroup
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedWorkerIndex = 0

    private var activeTab: TerminalTab? {
        guard !group.tabs.isEmpty else { return nil }
        let idx = min(max(0, selectedWorkerIndex), group.tabs.count - 1)
        return group.tabs[idx]
    }

    public var body: some View {
        Group {
            if let activeTab = activeTab {
                VStack(spacing: 0) {
                    // Header: project name + worker tabs
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(activeTab.workerColor).frame(width: 3, height: 12)
                        Text(group.projectName).font(Theme.chrome(10, weight: .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        Spacer()

                        if group.tabs.count > 1 {
                            HStack(spacing: 2) {
                                ForEach(Array(group.tabs.enumerated()), id: \.element.id) { i, tab in
                                    Button(action: { selectedWorkerIndex = i; manager.selectTab(tab.id) }) {
                                        Text(tab.workerName).font(Theme.chrome(7, weight: selectedWorkerIndex == i ? .bold : .regular))
                                            .foregroundColor(selectedWorkerIndex == i ? tab.workerColor : Theme.textDim)
                                            .padding(.horizontal, 4).padding(.vertical, 2)
                                            .background(selectedWorkerIndex == i ? tab.workerColor.opacity(0.1) : .clear)
                                            .cornerRadius(3)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        if activeTab.isProcessing { ProgressView().scaleEffect(0.35).frame(width: 8, height: 8) }
                        Text(activeTab.selectedModel.icon).font(Theme.chrome(9))
                    }

                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(group.hasActiveTab ? Theme.bgSelected : Theme.bgCard)

                    EventStreamView(tab: activeTab, compact: true)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(group.hasActiveTab ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1))
                .onTapGesture { manager.selectTab(activeTab.id) }
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Resizable Divider

private struct ResizableDivider: View {
    @Binding var height: CGFloat

    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 3)
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering in
                if hovering { NSCursor.resizeUpDown.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        height = max(120, min(600, height - value.translation.height))
                    }
            )
    }
}
