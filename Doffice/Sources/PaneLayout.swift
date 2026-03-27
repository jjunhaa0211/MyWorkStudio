import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Pane Layout (tmux-style Split Model)
// ═══════════════════════════════════════════════════════

enum SplitAxis: String, Codable {
    case horizontal  // ─── 좌우 분할
    case vertical    // │ 상하 분할
}

/// 재귀적 트리 구조로 pane 분할을 표현
indirect enum PaneNode: Identifiable, Codable {
    case leaf(id: String, tabId: String)
    case split(id: String, axis: SplitAxis, children: [PaneChild])

    var id: String {
        switch self {
        case .leaf(let id, _): return id
        case .split(let id, _, _): return id
        }
    }

    /// 트리에 포함된 모든 tabId 목록
    var allTabIds: [String] {
        switch self {
        case .leaf(_, let tabId): return [tabId]
        case .split(_, _, let children): return children.flatMap { $0.node.allTabIds }
        }
    }

    /// 특정 tabId를 가진 leaf를 찾아서 분할
    func splitting(tabId: String, axis: SplitAxis, newTabId: String) -> PaneNode {
        switch self {
        case .leaf(let id, let tid):
            if tid == tabId {
                return .split(
                    id: UUID().uuidString,
                    axis: axis,
                    children: [
                        PaneChild(node: .leaf(id: id, tabId: tid), proportion: 0.5),
                        PaneChild(node: .leaf(id: UUID().uuidString, tabId: newTabId), proportion: 0.5)
                    ]
                )
            }
            return self

        case .split(let id, let ax, let children):
            return .split(
                id: id,
                axis: ax,
                children: children.map { child in
                    PaneChild(node: child.node.splitting(tabId: tabId, axis: axis, newTabId: newTabId), proportion: child.proportion)
                }
            )
        }
    }

    /// 특정 tabId를 제거하고 트리를 정리
    func removing(tabId: String) -> PaneNode? {
        switch self {
        case .leaf(_, let tid):
            return tid == tabId ? nil : self

        case .split(let id, let axis, let children):
            let remaining = children.compactMap { child -> PaneChild? in
                guard let node = child.node.removing(tabId: tabId) else { return nil }
                return PaneChild(node: node, proportion: child.proportion)
            }
            if remaining.isEmpty { return nil }
            if remaining.count == 1 { return remaining[0].node }  // 단일 자식이면 승격
            // 비율 재조정
            let totalProp = max(0.001, remaining.reduce(0) { $0 + $1.proportion })
            let normalized = remaining.map { PaneChild(node: $0.node, proportion: $0.proportion / totalProp) }
            return .split(id: id, axis: axis, children: normalized)
        }
    }

    /// leaf 개수
    var leafCount: Int {
        switch self {
        case .leaf: return 1
        case .split(_, _, let children): return children.reduce(0) { $0 + $1.node.leafCount }
        }
    }
}

struct PaneChild: Codable, Identifiable {
    let node: PaneNode
    let proportion: CGFloat
    var id: String { node.id }
}

// ═══════════════════════════════════════════════════════
// MARK: - Pane Split View (Recursive Renderer)
// ═══════════════════════════════════════════════════════

struct PaneSplitView: View {
    let node: PaneNode
    let focusedTabId: String?
    let onSelectTab: (String) -> Void
    let onClosePane: (String) -> Void
    let onSplitPane: (String, SplitAxis) -> Void

    var body: some View {
        paneContent(node)
    }

    @ViewBuilder
    private func paneContent(_ node: PaneNode) -> some View {
        switch node {
        case .leaf(_, let tabId):
            PaneLeafView(
                tabId: tabId,
                isFocused: focusedTabId == tabId,
                onSelect: { onSelectTab(tabId) },
                onClose: { onClosePane(tabId) },
                onSplitH: { onSplitPane(tabId, .horizontal) },
                onSplitV: { onSplitPane(tabId, .vertical) }
            )

        case .split(_, let axis, let children):
            GeometryReader { geo in
                let isHorizontal = axis == .horizontal
                let totalSize = isHorizontal ? geo.size.width : geo.size.height

                if isHorizontal {
                    HStack(spacing: 0) {
                        ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                            paneContent(child.node)
                                .frame(width: totalSize * child.proportion - (index > 0 ? 2 : 0))

                            if index < children.count - 1 {
                                PaneDivider(axis: .horizontal)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                            paneContent(child.node)
                                .frame(height: totalSize * child.proportion - (index > 0 ? 2 : 0))

                            if index < children.count - 1 {
                                PaneDivider(axis: .vertical)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 개별 pane leaf — 탭의 터미널 뷰를 렌더링
struct PaneLeafView: View {
    let tabId: String
    let isFocused: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onSplitH: () -> Void
    let onSplitV: () -> Void

    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared

    private var tab: TerminalTab? {
        manager.tabs.first(where: { $0.id == tabId })
    }

    var body: some View {
        if let tab = tab {
            VStack(spacing: 0) {
                // Mini title bar
                paneTitleBar(tab)

                // Terminal content
                if settings.rawTerminalMode {
                    CLITerminalView(tab: tab, fontSize: 13 * settings.fontSizeScale)
                } else {
                    EventStreamView(tab: tab, compact: true)
                }
            }
            .background(Theme.bgTerminal)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFocused ? Theme.accent.opacity(0.6) : Theme.border.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
            .shadow(color: .black.opacity(isFocused ? 0.15 : 0.05), radius: isFocused ? 4 : 2, x: 0, y: 1)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.bgCard)
                .overlay(Text("Empty Pane").font(Theme.chrome(10)).foregroundColor(Theme.textDim))
        }
    }

    private func paneTitleBar(_ tab: TerminalTab) -> some View {
        HStack(spacing: 6) {
            Circle().fill(tab.workerColor).frame(width: 6, height: 6)
            Text(tab.workerName)
                .font(Theme.chrome(9, weight: .semibold))
                .foregroundColor(tab.workerColor)
            Text(tab.projectName)
                .font(Theme.chrome(9))
                .foregroundColor(Theme.textDim)
                .lineLimit(1)
            Spacer()

            if tab.isProcessing {
                ProgressView()
                    .scaleEffect(0.3)
                    .frame(width: 10, height: 10)
            }

            // Split buttons
            Button(action: onSplitH) {
                Image(systemName: "rectangle.split.1x2")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("pane.split.horizontal", comment: "Split Horizontal"))

            Button(action: onSplitV) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("pane.split.vertical", comment: "Split Vertical"))

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("pane.close", comment: "Close Pane"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isFocused ? Theme.bgSelected : Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }
}

/// Pane 사이의 구분선 (드래그 가능)
struct PaneDivider: View {
    let axis: SplitAxis
    @State private var isHovering = false

    var body: some View {
        Group {
            if axis == .horizontal {
                Rectangle()
                    .fill(isHovering ? Theme.accent.opacity(0.6) : Theme.border.opacity(0.4))
                    .frame(width: isHovering ? 4 : 2)
                    .onHover { isHovering = $0 }
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            } else {
                Rectangle()
                    .fill(isHovering ? Theme.accent.opacity(0.6) : Theme.border.opacity(0.4))
                    .frame(height: isHovering ? 4 : 2)
                    .onHover { isHovering = $0 }
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Pane Manager (SessionManager Extension)
// ═══════════════════════════════════════════════════════

extension SessionManager {
    static let maxPanes = 6

    /// 현재 pane layout (nil이면 단일 뷰)
    var currentPaneLayout: PaneNode? {
        get { _paneLayout }
        set { _paneLayout = newValue; objectWillChange.send() }
    }

    /// Split the pane containing `tabId` along `axis`
    func splitPane(tabId: String, axis: SplitAxis) {
        let leafCount = _paneLayout?.leafCount ?? 1
        guard leafCount < Self.maxPanes else { return }

        // 새 탭 생성
        let sourceTab = tabs.first(where: { $0.id == tabId })
        let projectPath = sourceTab?.projectPath ?? NSHomeDirectory()
        let newTab = addTab(projectPath: projectPath)

        if let layout = _paneLayout {
            _paneLayout = layout.splitting(tabId: tabId, axis: axis, newTabId: newTab.id)
        } else {
            // 첫 분할: 현재 활성 탭 + 새 탭
            _paneLayout = PaneNode.split(
                id: UUID().uuidString,
                axis: axis,
                children: [
                    PaneChild(node: .leaf(id: UUID().uuidString, tabId: tabId), proportion: 0.5),
                    PaneChild(node: .leaf(id: UUID().uuidString, tabId: newTab.id), proportion: 0.5)
                ]
            )
        }
        selectTab(newTab.id)
    }

    /// Close a pane (removes from layout, keeps tab)
    func closePane(tabId: String) {
        guard let layout = _paneLayout else { return }
        if let newLayout = layout.removing(tabId: tabId) {
            if case .leaf(_, let remainingTabId) = newLayout {
                // 마지막 하나만 남으면 분할 해제
                _paneLayout = nil
                selectTab(remainingTabId)
            } else {
                _paneLayout = newLayout
                // 다른 탭으로 포커스 이동
                if activeTabId == tabId, let firstTabId = newLayout.allTabIds.first {
                    selectTab(firstTabId)
                }
            }
        } else {
            _paneLayout = nil
        }
    }

    /// Pane layout이 활성 상태인지
    var isPaneSplitActive: Bool {
        _paneLayout != nil
    }
}
