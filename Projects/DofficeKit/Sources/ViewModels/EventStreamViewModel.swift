import SwiftUI
import Combine
import DesignSystem

// MARK: - EventStreamViewModel

/// EventStreamView의 비즈니스 로직 및 필터/상태 관리를 담당합니다.
@MainActor
public final class EventStreamViewModel: ObservableObject {

    // MARK: - Filter & Plan State

    @Published public var blockFilter = BlockFilter()
    @Published public var planSelectionDraft: [String: String] = [:]
    @Published public var planSelectionSignature = ""
    @Published public var sentPlanSignatures: Set<String> = []
    @Published public var selectedCommandIndex = 0
    @Published public var elapsedSeconds = 0

    // MARK: - UI Toggle State

    @Published public var showFilterBar = false
    @Published public var showFilePanel = false
    @Published public var showSleepWorkSetup = false
    @Published public var unavailableProviderAlert: AgentProvider?

    // MARK: - Scroll State

    @Published public var autoScroll = true
    @Published public var lastBlockCount = 0
    public var scrollWorkItem: DispatchWorkItem?

    // MARK: - Filter Tool Types

    public static let filterToolNames = ["Bash", "Read", "Write", "Edit", "Grep", "Glob"]

    // MARK: - Computed Blocks

    public func filteredBlocks(tab: TerminalTab) -> [StreamBlock] {
        if tab.outputMode == .full && !blockFilter.isActive {
            return tab.blocks
        }
        var blocks: [StreamBlock]
        switch tab.outputMode {
        case .full: blocks = tab.blocks
        case .realtime: blocks = tab.blocks.filter { if case .sessionStart = $0.blockType { return false }; return true }
        case .resultOnly:
            blocks = tab.blocks.filter {
                switch $0.blockType {
                case .userPrompt, .thought, .completion, .error: return true
                default: return false
                }
            }
        }
        if blockFilter.isActive {
            blocks = blocks.filter { blockFilter.matches($0) }
        }
        return blocks
    }

    // MARK: - Provider Selection

    public func selectProvider(_ provider: AgentProvider, tab: TerminalTab) {
        guard tab.provider != provider else { return }
        guard provider.refreshAvailability(force: false) else {
            unavailableProviderAlert = provider
            return
        }
        tab.switchProvider(to: provider)
    }

    // MARK: - Activity Display

    public func activityLabel(for activity: ClaudeActivity) -> String {
        switch activity {
        case .idle: return NSLocalizedString("terminal.status.idle", comment: "")
        case .thinking: return NSLocalizedString("terminal.status.thinking", comment: "")
        case .reading: return NSLocalizedString("terminal.status.reading", comment: "")
        case .writing: return NSLocalizedString("terminal.status.writing", comment: "")
        case .searching: return NSLocalizedString("terminal.status.searching", comment: "")
        case .running: return NSLocalizedString("terminal.status.running", comment: "")
        case .done: return NSLocalizedString("terminal.status.done", comment: "")
        case .error: return NSLocalizedString("terminal.status.error", comment: "")
        }
    }

    public func activityLabelColor(for activity: ClaudeActivity) -> Color {
        switch activity {
        case .thinking: return Theme.purple
        case .reading: return Theme.accent
        case .writing: return Theme.green
        case .searching: return Theme.cyan
        case .running: return Theme.yellow
        case .done: return Theme.green
        case .error: return Theme.red
        case .idle: return Theme.textDim
        }
    }

    // MARK: - Time Formatting

    public func formatElapsed(_ secs: Int) -> String {
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs / 60)m \(secs % 60)s" }
        return "\(secs / 3600)h \((secs % 3600) / 60)m"
    }

    // MARK: - Tool Color

    public func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow
        case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green
        case "Grep", "Glob": return Theme.cyan
        default: return Theme.textSecondary
        }
    }

    public func toolColor(for role: WorkerJob) -> Color {
        switch role {
        case .developer: return Theme.accent
        case .planner: return Theme.orange
        case .designer: return Theme.pink
        case .reviewer: return Theme.cyan
        case .qa: return Theme.green
        case .reporter: return Theme.purple
        case .sre: return Theme.yellow
        case .boss: return Theme.orange
        }
    }

    // MARK: - Scroll Helpers

    public func scrollToEnd(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("streamEnd", anchor: .bottom)
    }

    public func debouncedScroll(_ proxy: ScrollViewProxy, delay: Double) {
        scrollWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.scrollToEnd(proxy) }
        scrollWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - Filter Chip Toggle

    public func toggleFilterTool(_ tool: String) {
        if blockFilter.toolTypes.contains(tool) {
            blockFilter.toolTypes.remove(tool)
        } else {
            blockFilter.toolTypes.insert(tool)
        }
    }

    public func clearFilter() {
        blockFilter = BlockFilter()
    }
}
