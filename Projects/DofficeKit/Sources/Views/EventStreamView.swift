import SwiftUI
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Event Stream View
// ═══════════════════════════════════════════════════════

public struct EventStreamView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var tab: TerminalTab
    @StateObject var settings = AppSettings.shared
    public let compact: Bool
    @State var inputText = ""
    @State var pastedChunks: [(id: Int, text: String)] = []
    @State var pasteCounter: Int = 0
    @FocusState var isFocused: Bool
    @State var autoScroll = true
    @State var lastBlockCount = 0
    @State var blockFilter = BlockFilter()
    @State var showFilterBar = false
    @State var showFilePanel = false
    @State var elapsedSeconds: Int = 0
    @State var selectedCommandIndex: Int = 0
    @State var planSelectionDraft: [String: String] = [:]
    @State var planSelectionSignature: String = ""
    @State var sentPlanSignatures: Set<String> = []
    @State var scrollWorkItem: DispatchWorkItem?
    @State var showSleepWorkSetup = false
    @State var unavailableProviderAlert: AgentProvider?
    public let elapsedTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // ═══════════════════════════════════════════
    var matchingCommands: [SlashCommand] {
        guard isCommandMode, !hasTypedArgs else { return [] }
        let typed = String(inputText.dropFirst()).lowercased().trimmingCharacters(in: .whitespaces)
        if typed.isEmpty { return Self.allSlashCommands }
        return Self.allSlashCommands.filter { $0.name.hasPrefix(typed) }
    }

    public var body: some View {
        Group {
            if settings.rawTerminalMode {
                rawTerminalBody
                    .id("raw-\(tab.id)")  // 모드 전환 시 뷰 완전 재생성
                    .overlay(AgentWaitingOverlay(isWaiting: tab.pendingApproval != nil))
            } else {
                normalBody
                    .id("normal-\(tab.id)")
                    .overlay(AgentWaitingOverlay(isWaiting: tab.pendingApproval != nil))
            }
        }
        .alert(item: $unavailableProviderAlert) { provider in
            Alert(
                title: Text(provider.selectionUnavailableTitle),
                message: Text(provider.selectionUnavailableDetail),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    func selectProvider(_ provider: AgentProvider) {
        guard tab.provider != provider else { return }
        guard provider.refreshAvailability(force: false) else {
            unavailableProviderAlert = provider
            return
        }
        // Reset session state when switching providers
        tab.isProcessing = false
        tab.claudeActivity = .idle
        tab.selectedModel = provider.defaultModel
        tab.isClaude = provider == .claude
    }

    // MARK: - Raw Terminal Body (NSView 기반 진짜 CLI)

    var rawTerminalBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { tab.forceStop() }) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 10, height: 10)
                }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.close.session", comment: ""))
                Text("\(tab.provider.shellLabel) — \(tab.projectName)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textDim)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.bgSurface)

            CLITerminalView(tab: tab, fontSize: 13 * settings.fontSizeScale)
        }
        .background(Theme.bgTerminal)
    }

    // MARK: - Normal Body (Doffice UI)

    var normalBody: some View {
        VStack(spacing: 0) {
            // [Feature 2] 작업 상태 바
            if !compact { statusBar }

            // [Feature 6] 필터 바
            if showFilterBar && !compact { filterBar }

            // Main content
            HStack(spacing: 0) {
                // Event stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredBlocks) { block in
                                EventBlockView(block: block, compact: compact)
                                    .id(block.id)
                                    .textSelection(.enabled)
                            }

                            if tab.isProcessing {
                                ProcessingIndicator(activity: tab.claudeActivity, workerColor: tab.workerColor, workerName: tab.workerName)
                                    .id("processing")
                            }

                            Color.clear.frame(height: 1).id("streamEnd")
                        }
                        .padding(.horizontal, compact ? 8 : 14)
                        .padding(.vertical, 8)
                    }
                    .background(Theme.bgTerminal)
                    .compositingGroup()
                    .onChange(of: tab.blocks.count) { _, newCount in
                        if autoScroll && newCount != lastBlockCount {
                            lastBlockCount = newCount
                            debouncedScroll(proxy, delay: 0.1)
                        }
                    }
                    .onChange(of: tab.isProcessing) { _, processing in
                        // 처리 완료 시 최종 결과로 스크롤
                        if !processing && autoScroll {
                            debouncedScroll(proxy, delay: 0.15)
                        }
                    }
                    .onChange(of: tab.claudeActivity) { _, _ in
                        // 활동 상태 변경될 때마다 스크롤 (tool 전환 등)
                        if autoScroll {
                            debouncedScroll(proxy, delay: 0.2)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToEnd(proxy) }
                    }
                }

                // [Feature 4] 파일 변경 패널
                if showFilePanel && !compact {
                    Rectangle().fill(Theme.border).frame(width: 1)
                    fileChangePanel
                }
            }

            // Slash command suggestions
            if isCommandMode && !matchingCommands.isEmpty {
                commandSuggestionsView
            }

            if let request = activePlanSelectionRequest {
                planSelectionPanel(request)
            }

            if !compact { fullInputBar } else { compactInputBar }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true }
            syncPlanSelectionState(with: activePlanSelectionRequest)
        }
        .onChange(of: activePlanSelectionRequest?.signature ?? "") { _, _ in
            syncPlanSelectionState(with: activePlanSelectionRequest)
        }
        .onReceive(elapsedTimer) { _ in
            if tab.isProcessing || tab.claudeActivity != .idle {
                elapsedSeconds = Int(Date().timeIntervalSince(tab.startTime))
            }
        }
        // 승인 모달 + 슬립워크 (단일 overlay로 합쳐 투명 렌더링 버그 방지)
        .overlay {
            ZStack {
                if tab.pendingApproval != nil || showSleepWorkSetup {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .compositingGroup()
                        .onTapGesture {
                            if showSleepWorkSetup { showSleepWorkSetup = false }
                        }
                }
                if let approval = tab.pendingApproval {
                    ApprovalSheet(approval: approval)
                }
                if showSleepWorkSetup {
                    SleepWorkSetupSheet(tab: tab, onDismiss: { showSleepWorkSetup = false })
                }
            }
        }
        // 보안 경고 오버레이
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if let warning = tab.dangerousCommandWarning {
                    securityBanner(warning, color: Theme.red, icon: "exclamationmark.octagon.fill") {
                        tab.dangerousCommandWarning = nil
                    }
                }
                if let warning = tab.sensitiveFileWarning {
                    securityBanner(warning, color: Theme.orange, icon: "lock.shield.fill") {
                        tab.sensitiveFileWarning = nil
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: tab.dangerousCommandWarning)
            .animation(.easeInOut(duration: 0.2), value: tab.sensitiveFileWarning)
        }
    }

    func securityBanner(_ message: String, color: Color, icon: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(12), weight: .bold))
                .foregroundColor(color)
            Text(message)
                .font(Theme.mono(9, weight: .medium))
                .foregroundColor(color)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Theme.iconSize(10)))
                    .foregroundColor(color.opacity(0.5))
            }.buttonStyle(.plain)
        }
        .padding(Theme.sp3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(color.opacity(0.3), lineWidth: 1))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 2] Status Bar
    // ═══════════════════════════════════════════

    var statusBar: some View {
        HStack(spacing: 8) {
            // Worker + Activity
            HStack(spacing: 4) {
                Circle().fill(tab.workerColor).frame(width: 6, height: 6)
                Text(tab.workerName).font(Theme.chrome(9, weight: .semibold)).foregroundColor(tab.workerColor)
                Text(activityLabel).font(Theme.chrome(9)).foregroundColor(activityLabelColor)
            }

            Rectangle().fill(Theme.border).frame(width: 1, height: 12)

            // Elapsed time
            HStack(spacing: 0) {
                Text(formatElapsed(elapsedSeconds)).font(Theme.chrome(9)).foregroundColor(Theme.textSecondary)
            }

            // File count
            if !tab.fileChanges.isEmpty {
                Rectangle().fill(Theme.border).frame(width: 1, height: 12)
                HStack(spacing: 3) {
                    Image(systemName: "doc.fill").font(Theme.chrome(8)).foregroundColor(Theme.green)
                    Text("\(Set(tab.fileChanges.map(\.fileName)).count) files").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.green)
                }
            }

            // Error count
            if tab.errorCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill").font(Theme.chrome(7)).foregroundColor(Theme.red)
                    Text("\(tab.errorCount) errors").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.red)
                }
            }

            // Commands
            if tab.commandCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "terminal").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                    Text("\(tab.commandCount) cmds").font(Theme.chrome(9)).foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            // Toggle buttons
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilterBar.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "line.3.horizontal.decrease.circle\(showFilterBar ? ".fill" : "")")
                        .font(Theme.chrome(8))
                    Text(NSLocalizedString("terminal.filter", comment: "")).font(Theme.chrome(8, weight: showFilterBar ? .bold : .regular))
                }
                .foregroundColor(showFilterBar || blockFilter.isActive ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilterBar ? Theme.accent.opacity(0.08) : .clear).cornerRadius(Theme.cornerSmall)
            }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.log.filter", comment: ""))

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilePanel.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text.magnifyingglass").font(Theme.chrome(8))
                    Text(NSLocalizedString("terminal.file", comment: "")).font(Theme.chrome(8, weight: showFilePanel ? .bold : .regular))
                }
                .foregroundColor(showFilePanel ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilePanel ? Theme.accent.opacity(0.08) : .clear).cornerRadius(Theme.cornerSmall)
            }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.file.changes", comment: ""))

            Button(action: {
                let text = tab.blocks.map { block -> String in
                    let prefix: String
                    switch block.blockType {
                    case .userPrompt: prefix = "> "
                    case .thought: prefix = "💭 "
                    case .toolUse(let name, _): prefix = "⏺ [\(name)] "
                    case .toolOutput: prefix = "  ⎿ "
                    case .toolError: prefix = "  ✗ "
                    case .status(let msg): return "ℹ️ \(msg)"
                    case .completion: prefix = "✅ "
                    case .error(let msg): return "🚨 \(msg)"
                    default: prefix = ""
                    }
                    return prefix + block.content
                }.joined(separator: "\n")
                if !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.copied.to.clipboard", comment: ""), text.count)))
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc").font(Theme.chrome(8))
                    Text(NSLocalizedString("terminal.copyall", comment: "")).font(Theme.chrome(8))
                }
                .foregroundColor(Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
            }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.copyall", comment: ""))
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, 5)
        .background(Theme.bgSurface.opacity(0.5))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    var activityLabel: String {
        switch tab.claudeActivity {
        case .idle: return NSLocalizedString("terminal.status.idle", comment: ""); case .thinking: return NSLocalizedString("terminal.status.thinking", comment: ""); case .reading: return NSLocalizedString("terminal.status.reading", comment: "")
        case .writing: return NSLocalizedString("terminal.status.writing", comment: ""); case .searching: return NSLocalizedString("terminal.status.searching", comment: ""); case .running: return NSLocalizedString("terminal.status.running", comment: "")
        case .done: return NSLocalizedString("terminal.status.done", comment: ""); case .error: return NSLocalizedString("terminal.status.error", comment: "")
        }
    }

    var activityLabelColor: Color {
        switch tab.claudeActivity {
        case .thinking: return Theme.purple; case .reading: return Theme.accent; case .writing: return Theme.green
        case .searching: return Theme.cyan; case .running: return Theme.yellow; case .done: return Theme.green
        case .error: return Theme.red; case .idle: return Theme.textDim
        }
    }

    func formatElapsed(_ secs: Int) -> String {
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs / 60)m \(secs % 60)s" }
        return "\(secs / 3600)h \((secs % 3600) / 60)m"
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 6] Filter Bar
    // ═══════════════════════════════════════════

    var filterBar: some View {
        HStack(spacing: 4) {
            Text("Filter").font(Theme.chrome(8, weight: .bold)).foregroundColor(Theme.textDim)
            ForEach(["Bash", "Read", "Write", "Edit", "Grep", "Glob"], id: \.self) { tool in
                filterChip(tool, color: toolColor(tool))
            }
            Rectangle().fill(Theme.border).frame(width: 1, height: 12)
            Button(action: { blockFilter.onlyErrors.toggle() }) {
                Text("Errors").font(Theme.chrome(8, weight: blockFilter.onlyErrors ? .bold : .regular))
                    .foregroundColor(blockFilter.onlyErrors ? Theme.red : Theme.textDim)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(blockFilter.onlyErrors ? Theme.red.opacity(0.1) : .clear).cornerRadius(3)
            }.buttonStyle(.plain)
            Spacer()
            if blockFilter.isActive {
                Button(action: { blockFilter = BlockFilter() }) {
                    Text("Clear").font(Theme.chrome(8)).foregroundStyle(Theme.accentBackground)
                }.buttonStyle(.plain)
            }
            // Search
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                TextField(NSLocalizedString("terminal.search.placeholder", comment: ""), text: $blockFilter.searchText)
                    .textFieldStyle(.plain).font(Theme.chrome(9)).frame(width: 80)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Theme.bgSurface.opacity(0.3))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    func filterChip(_ tool: String, color: Color) -> some View {
        let active = blockFilter.toolTypes.contains(tool)
        return Button(action: {
            if active { blockFilter.toolTypes.remove(tool) }
            else { blockFilter.toolTypes.insert(tool) }
        }) {
            Text(tool).font(Theme.chrome(8, weight: active ? .bold : .regular))
                .foregroundColor(active ? color : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(active ? color.opacity(0.1) : .clear).cornerRadius(3)
        }.buttonStyle(.plain)
        .accessibilityLabel(String(format: NSLocalizedString("terminal.filter.a11y", comment: ""), tool))
    }

    func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow; case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green; case "Grep", "Glob": return Theme.cyan
        default: return Theme.textSecondary
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 4] File Change Panel
    // ═══════════════════════════════════════════

    var fileChangePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.text").font(Theme.chrome(9)).foregroundStyle(Theme.accentBackground)
                Text("FILES").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                Spacer()
                Text("\(Set(tab.fileChanges.map(\.fileName)).count)")
                    .font(Theme.chrome(9, weight: .bold)).foregroundStyle(Theme.accentBackground)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.bgSurface.opacity(0.5))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    // Group by unique file
                    let grouped = Dictionary(grouping: tab.fileChanges, by: \.path)
                    ForEach(Array(grouped.keys.sorted()), id: \.self) { path in
                        if let records = grouped[path], let latest = records.last {
                        HStack(spacing: 6) {
                            Image(systemName: latest.action == "Write" ? "doc.badge.plus" : "pencil.line")
                                .font(Theme.chrome(8)).foregroundColor(Theme.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(latest.fileName).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                Text("\(latest.action) x\(records.count)")
                                    .font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        } // if let records
                    }

                    if tab.fileChanges.isEmpty {
                        Text(NSLocalizedString("terminal.no.file.changes", comment: "")).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
            }
        }
        .frame(width: 180)
        .background(Theme.bgCard)
    }

    // ═══════════════════════════════════════════
    // MARK: - Filtered Blocks (기존 확장)
    // ═══════════════════════════════════════════

    func scrollToEnd(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("streamEnd", anchor: .bottom)
    }

    func debouncedScroll(_ proxy: ScrollViewProxy, delay: Double) {
        scrollWorkItem?.cancel()
        let item = DispatchWorkItem { scrollToEnd(proxy) }
        scrollWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    var filteredBlocks: [StreamBlock] {
        // Fast path: no filtering needed
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
        // 추가 필터 적용
        if blockFilter.isActive {
            blocks = blocks.filter { blockFilter.matches($0) }
        }
        return blocks
    }

    // MARK: - Setting Helpers

    func settingGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.chrome(8, weight: .medium))
                .foregroundColor(Theme.textDim)
                .fixedSize()
            HStack(spacing: 2) {
                content()
            }
        }
        .padding(.horizontal, 6)
    }

    var settingSep: some View {
        Rectangle().fill(Theme.textDim.opacity(0.25)).frame(width: 1, height: 18).padding(.horizontal, 4)
    }

    func settingChip(_ label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.12)) { action() } }) {
            Text(label)
                .font(Theme.chrome(9, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? color : Theme.textDim)
                .fixedSize()
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? color.opacity(0.14) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? color.opacity(0.3) : .clear, lineWidth: 1)
                )
        }.buttonStyle(.plain)
    }

    func settingMenuChip<Content: View>(_ label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(Theme.chrome(9, weight: .bold))
                    .foregroundColor(color)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color.opacity(0.85))
            }
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }

    func modelColor(_ m: ClaudeModel) -> Color {
        switch m {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
        case .gpt54: return Theme.accent
        case .gpt54Mini: return Theme.cyan
        case .gpt53Codex: return Theme.orange
        case .gpt52Codex: return Theme.orange
        case .gpt52: return Theme.green
        case .gpt51CodexMax: return Theme.red
        case .gpt51CodexMini: return Theme.yellow
        case .gemini25Pro: return Theme.cyan
        case .gemini25Flash: return Theme.green
        }
    }

    func providerColor(_ provider: AgentProvider) -> Color {
        switch provider {
        case .claude: return Theme.accent
        case .codex: return Theme.orange
        case .gemini: return Theme.cyan
        }
    }

    func approvalColor(_ m: ApprovalMode) -> Color {
        switch m {
        case .auto: return Theme.yellow
        case .ask: return Theme.orange
        case .safe: return Theme.green
        }
    }

    func permissionColor(_ m: PermissionMode) -> Color {
        switch m {
        case .acceptEdits: return Theme.green
        case .bypassPermissions: return Theme.yellow
        case .auto: return Theme.cyan
        case .defaultMode: return Theme.orange
        case .plan: return Theme.purple
        }
    }

    func codexSandboxColor(_ mode: CodexSandboxMode) -> Color {
        switch mode {
        case .readOnly: return Theme.green
        case .workspaceWrite: return Theme.cyan
        case .dangerFullAccess: return Theme.red
        }
    }

    func codexApprovalColor(_ mode: CodexApprovalPolicy) -> Color {
        switch mode {
        case .untrusted: return Theme.green
        case .onRequest: return Theme.orange
        case .never: return Theme.yellow
        }
    }
}

struct PlanSelectionRequest {
    public struct Group: Identifiable {
        public let id: String
        public let title: String
        public let options: [Option]
    }

    public struct Option: Identifiable {
        public let id: String
        public let key: String
        public let label: String
    }

    public let signature: String
    public let promptLine: String?
    public let groups: [Group]

    public static func parse(from text: String) -> PlanSelectionRequest? {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        let lowered = normalizedText.lowercased()
        let requestMarkers = ["선호", "선택", "알려주세요", "골라", "정해주세요", "말씀해주세요", "어떤 것", "어떤 방식", "결정", "어떻게 할", "무엇을", "choose", "pick", "prefer", "which one", "which option", "select", "what would you", "would you like", "option"]
        guard requestMarkers.contains(where: { lowered.contains($0) }) else { return nil }

        let lines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var groups: [Group] = []
        var currentTitle: String?
        var currentOptions: [Option] = []

        let flushCurrentGroup: () -> Void = {
            guard let title = currentTitle, currentOptions.count >= 2 else {
                currentTitle = nil
                currentOptions = []
                return
            }
            let index = groups.count + 1
            groups.append(
                Group(
                    id: "plan-group-\(index)",
                    title: title,
                    options: currentOptions
                )
            )
            currentTitle = nil
            currentOptions = []
        }

        for line in lines {
            if let title = parseGroupTitle(from: line) {
                flushCurrentGroup()
                currentTitle = title
                continue
            }

            if let option = parseOption(from: line) {
                if currentTitle == nil {
                    currentTitle = NSLocalizedString("terminal.choice.select", comment: "")
                }
                currentOptions.append(option)
                continue
            }

            if !currentOptions.isEmpty {
                let lastIndex = currentOptions.count - 1
                let last = currentOptions[lastIndex]
                currentOptions[lastIndex] = Option(
                    id: last.id,
                    key: last.key,
                    label: "\(last.label) \(line)"
                )
            }
        }

        flushCurrentGroup()

        guard !groups.isEmpty else { return nil }
        let promptLine = lines.last(where: { line in
            requestMarkers.contains(where: { marker in line.lowercased().contains(marker) })
        })

        return PlanSelectionRequest(
            signature: normalizedText,
            promptLine: promptLine,
            groups: groups
        )
    }

    public func responseText(from selections: [String: String]) -> String {
        let lines = groups.enumerated().compactMap { index, group -> String? in
            guard let selectedKey = selections[group.id],
                  let option = group.options.first(where: { $0.key == selectedKey }) else { return nil }
            return "\(index + 1). \(group.title): \(option.key) - \(option.label)"
        }

        guard lines.count == groups.count else { return "" }
        return """
        플랜 모드 선택:
        \(lines.joined(separator: "\n"))

        이 선택 기준으로 이어서 진행해주세요.
        """
    }

    private static func parseGroupTitle(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }

        let marker = String(parts[0])
        guard marker.count >= 2,
              let last = marker.last,
              last == "." || last == ")" else { return nil }

        let digits = marker.dropLast()
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }

        let title = String(parts[1])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "：", with: "")
        return title.isEmpty ? nil : title
    }

    private static func parseOption(from line: String) -> Option? {
        let trimmed = line
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "-", with: "", options: [], range: line.startIndex..<line.index(line.startIndex, offsetBy: min(1, line.count)))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else { return nil }

        // Circled numbers: ①, ②, ③ ...
        let circledNumbers: [Character: String] = ["①": "1", "②": "2", "③": "3", "④": "4", "⑤": "5", "⑥": "6", "⑦": "7", "⑧": "8", "⑨": "9"]
        if let first = trimmed.first, let num = circledNumbers[first] {
            let label = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return Option(id: "plan-option-\(num)-\(label)", key: num, label: label)
        }

        // Parenthesized: (1), (2), (A), (B)
        if trimmed.hasPrefix("("), let closeIdx = trimmed.firstIndex(of: ")") {
            let afterStart = trimmed.index(after: trimmed.startIndex)
            guard afterStart < trimmed.endIndex, afterStart <= closeIdx else { return nil }
            let inner = trimmed[afterStart..<closeIdx]
            guard inner.count >= 1, inner.count <= 2 else { return nil }
            let key = String(inner).uppercased()
            let afterClose = trimmed.index(after: closeIdx)
            guard afterClose <= trimmed.endIndex else { return nil }
            let label = String(trimmed[afterClose...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return Option(id: "plan-option-\(key)-\(label)", key: key, label: label)
        }

        guard trimmed.count >= 3 else { return nil }
        let characters = Array(trimmed)
        let marker = characters[0]
        let separator = characters[1]

        // Single letter (A, B...), digit (1, 2...), or Korean marker (가, 나, 다...)
        let koreanOrderMarkers: Set<Character> = ["가", "나", "다", "라", "마"]
        let isValidMarker = marker.isLetter || marker.isNumber || koreanOrderMarkers.contains(marker)
        guard isValidMarker, separator == ")" || separator == "." || separator == ":" else { return nil }

        let key: String
        if marker.isNumber || koreanOrderMarkers.contains(marker) {
            key = String(marker)
        } else {
            key = String(marker).uppercased()
        }
        let label = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return nil }

        return Option(
            id: "plan-option-\(key)-\(label)",
            key: key,
            label: label
        )
    }
}
