import SwiftUI
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Area
// ═══════════════════════════════════════════════════════

public struct TerminalAreaView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var viewMode: ViewMode = .grid
    public enum ViewMode { case grid, single, git, history, browser }

    public init() {}

    /// Pre-computed counts of tabs sharing the same projectPath (avoids O(n²) filter inside ForEach)
    private var projectPathCounts: [String: Int] {
        Dictionary(grouping: manager.userVisibleTabs, by: \.projectPath).mapValues(\.count)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            switch viewMode {
            case .grid: GridPanelView()
            case .single:
                if let tab = manager.activeTab {
                    if tab.isBrowserTab { BrowserPanelView() }
                    else { EventStreamView(tab: tab, compact: false) }
                } else { EmptySessionView() }
            case .git: GitPanelView()
            case .history: HistoryPanelView()
            case .browser: BrowserPanelView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dofficeToggleBrowser)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { viewMode = .browser }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                modeBtn("square.grid.2x2", .grid); modeBtn("rectangle", .single)
                Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                modeBtn("arrow.triangle.branch", .git)
                modeBtn("clock.arrow.circlepath", .history)
                modeBtn("globe", .browser)
            }.padding(.horizontal, 8)
            Rectangle().fill(Theme.border).frame(width: 1, height: 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    if viewMode == .grid {
                        // Grid mode: show tabs for shift-click multi-select
                        ForEach(manager.userVisibleTabs) { t in gridTabBtn(t) }
                        if !manager.pinnedTabIds.isEmpty {
                            Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                            Button(action: { manager.clearPinnedTabs() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 8))
                                    Text(NSLocalizedString("terminal.deselect", comment: "")).font(Theme.chrome(8))
                                }
                                .foregroundColor(Theme.textDim)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                            }.buttonStyle(.plain)
                        }
                    }
                    if viewMode == .single || viewMode == .git || viewMode == .history { ForEach(manager.userVisibleTabs) { t in singleTabBtn(t) } }
                }.padding(.horizontal, 6)
            }
            Spacer(minLength: 0)
            Button(action: { manager.addBrowserTab() }) {
                Image(systemName: "globe").font(Theme.scaled(10, weight: .medium)).foregroundColor(Theme.textDim).frame(width: 28, height: 28)
            }.buttonStyle(.plain)
            Button(action: { manager.showNewTabSheet = true }) {
                Image(systemName: "plus").font(Theme.scaled(10, weight: .medium)).foregroundColor(Theme.textDim).frame(width: 28, height: 28)
            }.buttonStyle(.plain).padding(.trailing, 6)
        }
        .frame(height: 34).background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func modeBtn(_ icon: String, _ mode: ViewMode) -> some View {
        let label: String = {
            switch mode {
            case .grid: return "Grid"
            case .single: return "Single"
            case .git: return "Git"
            case .history: return NSLocalizedString("terminal.mode.history", comment: "")
            case .browser: return "Browser"
            }
        }()
        let selected = viewMode == mode
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode } }) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                Text(label).font(Theme.chrome(8, weight: selected ? .bold : .regular))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim).padding(.horizontal, Theme.sp2 - 2).padding(.vertical, Theme.sp1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(selected ? Theme.accent.opacity(0.12) : .clear))
        }.buttonStyle(.plain)
    }
    private func singleTabBtn(_ t: TerminalTab) -> some View {
        let a = manager.activeTabId == t.id
        let status = t.statusPresentation
        let needsInput = t.pendingApproval != nil
        let dotColor: Color = {
            if needsInput { return Color.blue }
            switch status.category {
            case .processing: return status.tint
            case .attention: return Theme.red
            case .completed: return Theme.green
            case .active, .idle: return t.workerColor
            }
        }()
        return Button(action: { manager.selectTab(t.id) }) {
            HStack(spacing: 4) {
                ZStack {
                    Circle().fill(dotColor).frame(width: 5, height: 5)
                    if needsInput {
                        AgentRingView(color: .blue, size: 12)
                    }
                }
                .frame(width: 12, height: 12)
                if t.isBrowserTab {
                    Image(systemName: "globe").font(.system(size: Theme.iconSize(9))).foregroundColor(a ? Theme.accent : Theme.textDim)
                    Text("Browser").font(Theme.chrome(10)).foregroundColor(a ? Theme.accent : Theme.textSecondary).lineLimit(1)
                } else {
                    Text(t.projectName).font(Theme.chrome(10)).foregroundColor(a ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                }
                if (projectPathCounts[t.projectPath] ?? 0) > 1 {
                    Text(t.workerName).font(Theme.chrome(9)).foregroundColor(t.workerColor)
                }
                if needsInput {
                    Text(NSLocalizedString("terminal.waiting", comment: ""))
                        .font(Theme.mono(7, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                }
            }.padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(needsInput ? Color.blue.opacity(0.08) : (a ? Theme.bgSelected : .clear))
            )
            .overlay(
                needsInput ?
                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                : nil
            )
        }.buttonStyle(.plain)
    }

    private func gridTabBtn(_ t: TerminalTab) -> some View {
        let isPinned = manager.pinnedTabIds.contains(t.id)
        return Button(action: {
            // Shift+클릭은 onTapGesture로 감지할 수 없으므로
            // 그리드 모드에서는 항상 토글 동작
            withAnimation(.easeInOut(duration: 0.15)) {
                manager.togglePinTab(t.id)
            }
        }) {
            HStack(spacing: 4) {
                if isPinned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                } else {
                    Circle().fill(t.workerColor.opacity(0.5)).frame(width: 5, height: 5)
                }
                Text(t.projectName).font(Theme.chrome(10)).foregroundColor(isPinned ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                if (projectPathCounts[t.projectPath] ?? 0) > 1 {
                    Text(t.workerName).font(Theme.chrome(9)).foregroundColor(t.workerColor)
                }
            }
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(isPinned ? Theme.accent.opacity(0.12) : .clear)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(isPinned ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)))
        }.buttonStyle(.plain)
        .help(NSLocalizedString("terminal.help.grid.toggle", comment: ""))
    }
}
