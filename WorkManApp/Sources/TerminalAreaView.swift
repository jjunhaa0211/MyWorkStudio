import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Area
// ═══════════════════════════════════════════════════════

struct TerminalAreaView: View {
    @EnvironmentObject var manager: SessionManager
    @State private var viewMode: ViewMode = .grid
    enum ViewMode { case grid, single }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch viewMode {
            case .grid: GridPanelView()
            case .single:
                if let tab = manager.activeTab { EventStreamView(tab: tab, compact: false) }
                else { EmptySessionView() }
            }
        }
        .sheet(isPresented: $manager.showNewTabSheet) { NewTabSheet() }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                modeBtn("square.grid.2x2", .grid); modeBtn("rectangle", .single)
            }.padding(.horizontal, 8)
            Rectangle().fill(Theme.border).frame(width: 1, height: 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    if viewMode == .single { ForEach(manager.userVisibleTabs) { t in singleTabBtn(t) } }
                }.padding(.horizontal, 6)
            }
            Spacer(minLength: 0)
            Button(action: { manager.showNewTabSheet = true }) {
                Image(systemName: "plus").font(Theme.scaled(10, weight: .medium)).foregroundColor(Theme.textDim).frame(width: 28, height: 28)
            }.buttonStyle(.plain).padding(.trailing, 6)
        }
        .frame(height: 34).background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func modeBtn(_ icon: String, _ mode: ViewMode) -> some View {
        let label = mode == .grid ? "Grid" : "Single"
        let selected = viewMode == mode
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode } }) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                Text(label).font(Theme.mono(8, weight: selected ? .bold : .regular))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim).padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Theme.accent.opacity(0.12) : .clear))
        }.buttonStyle(.plain)
    }
    private func singleTabBtn(_ t: TerminalTab) -> some View {
        let a = manager.activeTabId == t.id
        return Button(action: { manager.selectTab(t.id) }) {
            HStack(spacing: 4) {
                Circle().fill(t.isProcessing ? Theme.yellow : t.workerColor).frame(width: 5, height: 5)
                Text(t.projectName).font(Theme.monoSmall).foregroundColor(a ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                if manager.userVisibleTabs.filter({ $0.projectPath == t.projectPath }).count > 1 {
                    Text(t.workerName).font(Theme.monoTiny).foregroundColor(t.workerColor)
                }
            }.padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(a ? Theme.bgSelected : .clear))
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Event Stream View
// ═══════════════════════════════════════════════════════

struct EventStreamView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var tab: TerminalTab
    @ObservedObject private var settings = AppSettings.shared
    let compact: Bool
    @State private var inputText = ""
    @FocusState private var isFocused: Bool
    @State private var autoScroll = true
    @State private var lastBlockCount = 0
    @State private var blockFilter = BlockFilter()
    @State private var showFilterBar = false
    @State private var showFilePanel = false
    @State private var elapsedSeconds: Int = 0
    @State private var selectedCommandIndex: Int = 0
    @State private var planSelectionDraft: [String: String] = [:]
    @State private var planSelectionSignature: String = ""
    let elapsedTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // ═══════════════════════════════════════════
    // MARK: - Slash Commands
    // ═══════════════════════════════════════════

    private struct SlashCommand {
        let name: String
        let description: String
        let usage: String
        let category: String
        let action: (TerminalTab, SessionManager, [String]) -> Void

        init(_ name: String, _ desc: String, usage: String = "", category: String = "일반", action: @escaping (TerminalTab, SessionManager, [String]) -> Void) {
            self.name = name; self.description = desc; self.usage = usage; self.category = category; self.action = action
        }
    }

    private static let allSlashCommands: [SlashCommand] = [
        // ── 일반 ──
        SlashCommand("help", "사용 가능한 명령어 목록", category: "일반") { tab, _, args in
            let cmds = EventStreamView.allSlashCommands
            if let query = args.first?.lowercased() {
                let filtered = cmds.filter { $0.name.contains(query) || $0.description.contains(query) }
                if filtered.isEmpty { tab.appendBlock(.status(message: "⚠️ '\(query)' 관련 명령어를 찾을 수 없습니다")); return }
                let lines = filtered.map { "/\($0.name)\($0.usage.isEmpty ? "" : " \($0.usage)") — \($0.description)" }
                tab.appendBlock(.status(message: "🔍 검색 결과\n" + lines.joined(separator: "\n")))
            } else {
                var grouped: [String: [SlashCommand]] = [:]
                for c in cmds { grouped[c.category, default: []].append(c) }
                let order = ["일반", "모델/설정", "세션", "화면", "Git", "도구"]
                var text = "📜 명령어 목록 (/help <키워드>로 검색)\n"
                for cat in order {
                    guard let list = grouped[cat] else { continue }
                    text += "\n[\(cat)]\n"
                    for c in list { text += "  /\(c.name)\(c.usage.isEmpty ? "" : " \(c.usage)") — \(c.description)\n" }
                }
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("clear", "이벤트 스트림 초기화", category: "일반") { tab, _, _ in
            tab.clearBlocks()
            tab.appendBlock(.status(message: "🗑️ 로그가 초기화되었습니다"))
        },
        SlashCommand("cancel", "현재 작업 취소", category: "일반") { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            else { tab.appendBlock(.status(message: "ℹ️ 실행 중인 작업이 없습니다")) }
        },
        SlashCommand("stop", "진행 중인 명령어 강제 중지 (SIGKILL)", category: "일반") { tab, _, _ in
            if tab.isProcessing || tab.isRunning { tab.forceStop() }
            else { tab.appendBlock(.status(message: "ℹ️ 실행 중인 작업이 없습니다")) }
        },
        SlashCommand("copy", "마지막 응답을 클립보드에 복사", category: "일반") { tab, _, _ in
            if let last = tab.blocks.last(where: { if case .thought = $0.blockType { return true }; if case .completion = $0.blockType { return true }; return false }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.content, forType: .string)
                tab.appendBlock(.status(message: "📋 클립보드에 복사되었습니다 (\(last.content.count)자)"))
            } else { tab.appendBlock(.status(message: "⚠️ 복사할 응답이 없습니다")) }
        },
        SlashCommand("export", "대화 로그를 파일로 저장", category: "일반") { tab, _, _ in
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
            let dateStr = { let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"; return f.string(from: Date()) }()
            let path = "\(tab.projectPath)/workman_log_\(dateStr).txt"
            do { try text.write(toFile: path, atomically: true, encoding: .utf8)
                tab.appendBlock(.status(message: "📁 로그 저장: \(path)"))
            } catch { tab.appendBlock(.status(message: "⚠️ 저장 실패: \(error.localizedDescription)")) }
        },

        // ── 모델/설정 ──
        SlashCommand("model", "모델 변경", usage: "<opus|sonnet|haiku>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let model = ClaudeModel.allCases.first(where: { $0.rawValue.lowercased().contains(arg) }) else {
                let current = tab.selectedModel
                tab.appendBlock(.status(message: "🤖 현재 모델: \(current.icon) \(current.rawValue)\n사용법: /model <opus|sonnet|haiku>"))
                return
            }
            tab.selectedModel = model
            tab.appendBlock(.status(message: "🤖 모델 변경: \(model.icon) \(model.rawValue)"))
        },
        SlashCommand("effort", "노력 수준 변경", usage: "<low|medium|high|max>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let effort = EffortLevel.allCases.first(where: { $0.rawValue.lowercased() == arg }) else {
                let current = tab.effortLevel
                tab.appendBlock(.status(message: "💪 현재 노력 수준: \(current.icon) \(current.rawValue)\n사용법: /effort <low|medium|high|max>"))
                return
            }
            tab.effortLevel = effort
            tab.appendBlock(.status(message: "💪 노력 수준 변경: \(effort.icon) \(effort.rawValue)"))
        },
        SlashCommand("output", "출력 모드 변경", usage: "<full|realtime|result>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                tab.appendBlock(.status(message: "📺 현재 출력 모드: \(tab.outputMode.icon) \(tab.outputMode.rawValue)\n사용법: /output <full|realtime|result>"))
                return
            }
            let modeMap: [String: OutputMode] = ["full": .full, "전체": .full, "realtime": .realtime, "실시간": .realtime, "result": .resultOnly, "결과만": .resultOnly, "결과": .resultOnly]
            guard let mode = modeMap[arg] else { tab.appendBlock(.status(message: "⚠️ 알 수 없는 모드: \(arg)")); return }
            tab.outputMode = mode
            tab.appendBlock(.status(message: "📺 출력 모드 변경: \(mode.icon) \(mode.rawValue)"))
        },
        SlashCommand("permission", "권한 모드 변경", usage: "<bypass|auto|default|plan|edits>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                let c = tab.permissionMode
                tab.appendBlock(.status(message: "🛡️ 현재 권한: \(c.icon) \(c.displayName) — \(c.desc)\n사용법: /permission <bypass|auto|default|plan|edits>"))
                return
            }
            let map: [String: PermissionMode] = ["bypass": .bypassPermissions, "auto": .auto, "default": .defaultMode, "plan": .plan, "edits": .acceptEdits, "edit": .acceptEdits]
            guard let mode = map[arg] else { tab.appendBlock(.status(message: "⚠️ 알 수 없는 모드: \(arg)")); return }
            tab.permissionMode = mode
            tab.appendBlock(.status(message: "🛡️ 권한 변경: \(mode.icon) \(mode.displayName) — \(mode.desc)"))
        },
        SlashCommand("budget", "최대 예산 설정 (USD)", usage: "<금액|off>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first else {
                let b = tab.maxBudgetUSD
                tab.appendBlock(.status(message: "💰 현재 예산: \(b > 0 ? "$\(String(format: "%.2f", b))" : "무제한")\n사용법: /budget <금액|off>"))
                return
            }
            if arg == "off" || arg == "0" { tab.maxBudgetUSD = 0; tab.appendBlock(.status(message: "💰 예산 제한 해제")); return }
            guard let v = Double(arg), v > 0 else { tab.appendBlock(.status(message: "⚠️ 올바른 금액을 입력하세요")); return }
            tab.maxBudgetUSD = v
            tab.appendBlock(.status(message: "💰 최대 예산 설정: $\(String(format: "%.2f", v))"))
        },
        SlashCommand("system", "시스템 프롬프트 설정", usage: "<프롬프트|clear>", category: "모델/설정") { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                let s = tab.systemPrompt.isEmpty ? "(없음)" : tab.systemPrompt
                tab.appendBlock(.status(message: "📝 시스템 프롬프트:\n\(s)"))
            } else if text == "clear" {
                tab.systemPrompt = ""
                tab.appendBlock(.status(message: "📝 시스템 프롬프트 초기화"))
            } else {
                tab.systemPrompt = text
                tab.appendBlock(.status(message: "📝 시스템 프롬프트 설정:\n\(text)"))
            }
        },
        SlashCommand("worktree", "워크트리 모드 토글", category: "모델/설정") { tab, _, _ in
            tab.useWorktree.toggle()
            tab.appendBlock(.status(message: "🌳 워크트리 모드: \(tab.useWorktree ? "켜짐" : "꺼짐")"))
        },
        SlashCommand("chrome", "크롬 연동 토글", category: "모델/설정") { tab, _, _ in
            tab.enableChrome.toggle()
            tab.appendBlock(.status(message: "🌐 크롬 연동: \(tab.enableChrome ? "켜짐" : "꺼짐")"))
        },
        SlashCommand("brief", "간결 모드 토글", category: "모델/설정") { tab, _, _ in
            tab.enableBrief.toggle()
            tab.appendBlock(.status(message: "✂️ 간결 모드: \(tab.enableBrief ? "켜짐" : "꺼짐")"))
        },

        // ── 세션 ──
        SlashCommand("stats", "현재 세션 통계", category: "세션") { tab, _, _ in
            let elapsed = Int(Date().timeIntervalSince(tab.startTime))
            let mins = elapsed / 60; let secs = elapsed % 60
            let stats = """
            📊 세션 통계
            ├ 작업자: \(tab.workerName) (\(tab.projectName))
            ├ 모델: \(tab.selectedModel.icon) \(tab.selectedModel.rawValue) · \(tab.effortLevel.icon) \(tab.effortLevel.rawValue)
            ├ 경과: \(mins)m \(secs)s
            ├ 토큰: \(tab.tokensUsed) (입력 \(tab.inputTokensUsed) / 출력 \(tab.outputTokensUsed))
            ├ 비용: $\(String(format: "%.4f", tab.totalCost))
            ├ 프롬프트: \(tab.completedPromptCount)회
            ├ 명령: \(tab.commandCount)개 · 에러: \(tab.errorCount)개
            ├ 블록: \(tab.blocks.count)개
            └ 파일 변경: \(tab.fileChanges.count)개
            """
            tab.appendBlock(.status(message: stats))
        },
        SlashCommand("restart", "세션 재시작", category: "세션") { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            tab.clearBlocks()
            tab.claudeActivity = .idle
            tab.start()
        },
        SlashCommand("continue", "이전 대화 이어서 진행", category: "세션") { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: "🔗 다음 프롬프트는 이전 대화를 이어서 진행합니다"))
        },
        SlashCommand("resume", "이전 세션 이어서 진행", category: "세션") { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: "🔗 resume 모드 활성화 — 다음 프롬프트가 이전 세션을 이어갑니다"))
        },
        SlashCommand("fork", "현재 대화를 분기하여 새 세션 시작", category: "세션") { tab, _, _ in
            tab.forkSession = true
            tab.appendBlock(.status(message: "🍴 fork 모드 활성화 — 다음 프롬프트가 대화를 분기합니다"))
        },

        // ── 화면 ──
        SlashCommand("scroll", "자동 스크롤 현재 상태 안내", category: "화면") { tab, _, _ in
            tab.appendBlock(.status(message: "📜 스크롤 팁: 스크롤을 위로 올리면 자동 스크롤이 멈추고, 맨 아래로 내리면 다시 켜집니다"))
        },
        SlashCommand("errors", "에러만 필터링하여 표시", category: "화면") { tab, _, _ in
            let errors = tab.blocks.filter { block in
                if block.isError { return true }
                switch block.blockType {
                case .error: return true
                case .toolError: return true
                default: return false
                }
            }
            if errors.isEmpty { tab.appendBlock(.status(message: "✅ 에러 없음!")); return }
            let text = errors.enumerated().map { (i, e) in "  \(i+1). \(e.content.prefix(200))" }.joined(separator: "\n")
            tab.appendBlock(.status(message: "🚨 에러 목록 (\(errors.count)개)\n\(text)"))
        },
        SlashCommand("files", "변경된 파일 목록", category: "화면") { tab, _, _ in
            if tab.fileChanges.isEmpty { tab.appendBlock(.status(message: "📁 변경된 파일 없음")); return }
            let text = tab.fileChanges.map { "  \($0.action == "Write" ? "📝" : "✏️") \($0.path)" }.joined(separator: "\n")
            tab.appendBlock(.status(message: "📁 변경된 파일 (\(tab.fileChanges.count)개)\n\(text)"))
        },
        SlashCommand("tokens", "토큰 사용량 상세", category: "화면") { tab, _, _ in
            let tracker = TokenTracker.shared
            let text = """
            🔢 토큰 사용량
            ├ 이 세션: \(tracker.formatTokens(tab.tokensUsed)) (입력 \(tracker.formatTokens(tab.inputTokensUsed)) / 출력 \(tracker.formatTokens(tab.outputTokensUsed)))
            ├ 오늘 전체: \(tracker.formatTokens(tracker.todayTokens))
            ├ 이번 주: \(tracker.formatTokens(tracker.weekTokens))
            ├ 비용 (세션): $\(String(format: "%.4f", tab.totalCost))
            ├ 비용 (오늘): $\(String(format: "%.4f", tracker.todayCost))
            └ 비용 (이번 주): $\(String(format: "%.4f", tracker.weekCost))
            """
            tab.appendBlock(.status(message: text))
        },
        SlashCommand("config", "현재 설정 요약", category: "화면") { tab, _, _ in
            var lines = [
                "⚙️ 설정 요약",
                "├ 모델: \(tab.selectedModel.icon) \(tab.selectedModel.rawValue)",
                "├ 노력: \(tab.effortLevel.icon) \(tab.effortLevel.rawValue)",
                "├ 출력: \(tab.outputMode.icon) \(tab.outputMode.rawValue)",
                "├ 권한: \(tab.permissionMode.icon) \(tab.permissionMode.displayName)",
                "├ 예산: \(tab.maxBudgetUSD > 0 ? "$\(String(format: "%.2f", tab.maxBudgetUSD))" : "무제한")",
                "├ 워크트리: \(tab.useWorktree ? "✅" : "❌")",
                "├ 크롬: \(tab.enableChrome ? "✅" : "❌")",
                "├ 간결: \(tab.enableBrief ? "✅" : "❌")",
            ]
            if !tab.systemPrompt.isEmpty { lines.append("├ 시스템: \(tab.systemPrompt.prefix(50))...") }
            if !tab.allowedTools.isEmpty { lines.append("├ 허용 도구: \(tab.allowedTools)") }
            if !tab.disallowedTools.isEmpty { lines.append("├ 차단 도구: \(tab.disallowedTools)") }
            lines.append("└ 프로젝트: \(tab.projectPath)")
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },

        // ── Git ──
        SlashCommand("git", "Git 상태 확인", category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let g = tab.gitInfo
                if !g.isGitRepo { tab.appendBlock(.status(message: "⚠️ Git 저장소가 아닙니다")); return }
                let text = """
                🔀 Git 상태
                ├ 브랜치: \(g.branch)
                ├ 변경 파일: \(g.changedFiles)개
                ├ 마지막 커밋: \(g.lastCommit)
                └ 커밋 시간: \(g.lastCommitAge)
                """
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("branch", "현재 브랜치 표시", category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tab.appendBlock(.status(message: "🌿 브랜치: \(tab.gitInfo.branch.isEmpty ? "(없음)" : tab.gitInfo.branch)"))
            }
        },

        // ── 도구 ──
        SlashCommand("allow", "허용 도구 설정", usage: "<tool1,tool2,...|clear>", category: "도구") { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: "✅ 허용 도구: \(tab.allowedTools.isEmpty ? "(전체)" : tab.allowedTools)"))
            } else if text == "clear" {
                tab.allowedTools = ""
                tab.appendBlock(.status(message: "✅ 도구 제한 해제 (전체 허용)"))
            } else {
                tab.allowedTools = text
                tab.appendBlock(.status(message: "✅ 허용 도구 설정: \(text)"))
            }
        },
        SlashCommand("deny", "차단 도구 설정", usage: "<tool1,tool2,...|clear>", category: "도구") { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: "🚫 차단 도구: \(tab.disallowedTools.isEmpty ? "(없음)" : tab.disallowedTools)"))
            } else if text == "clear" {
                tab.disallowedTools = ""
                tab.appendBlock(.status(message: "🚫 도구 차단 해제"))
            } else {
                tab.disallowedTools = text
                tab.appendBlock(.status(message: "🚫 도구 차단 설정: \(text)"))
            }
        },
        SlashCommand("pr", "PR 번호로 리뷰 시작", usage: "<PR번호>", category: "도구") { tab, _, args in
            guard let num = args.first else {
                tab.appendBlock(.status(message: "⚠️ 사용법: /pr <PR번호>"))
                return
            }
            tab.fromPR = num
            tab.appendBlock(.status(message: "🔍 PR #\(num) — 다음 프롬프트에서 이 PR을 컨텍스트로 사용합니다"))
        },
        SlashCommand("name", "세션 이름 설정", usage: "<이름>", category: "세션") { tab, _, args in
            let n = args.joined(separator: " ")
            if n.isEmpty { tab.appendBlock(.status(message: "📛 현재 이름: \(tab.sessionName.isEmpty ? "(없음)" : tab.sessionName)")); return }
            tab.sessionName = n
            tab.appendBlock(.status(message: "📛 세션 이름: \(n)"))
        },
    ]

    private var isCommandMode: Bool { inputText.hasPrefix("/") }

    /// 입력 중인 명령어와 아직 인자를 입력하지 않았을 때만 필터
    private var hasTypedArgs: Bool {
        guard isCommandMode else { return false }
        let afterSlash = String(inputText.dropFirst())
        return afterSlash.contains(" ") && afterSlash.split(separator: " ").count > 1
    }

    private var matchingCommands: [SlashCommand] {
        guard isCommandMode, !hasTypedArgs else { return [] }
        let typed = String(inputText.dropFirst()).lowercased().trimmingCharacters(in: .whitespaces)
        if typed.isEmpty { return Self.allSlashCommands }
        return Self.allSlashCommands.filter { $0.name.hasPrefix(typed) }
    }

    var body: some View {
        if tab.isRawMode {
            rawTerminalBody
        } else {
            normalBody
        }
    }

    // MARK: - Raw Terminal Body (NSView 기반 진짜 CLI)

    private var rawTerminalBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { tab.forceStop() }) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 10, height: 10)
                }.buttonStyle(.plain).help("세션 종료")
                Text("claude — \(tab.projectName)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))

            CLITerminalView(tab: tab, fontSize: 13 * settings.fontSizeScale)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }

    // MARK: - Normal Body (WorkMan UI)

    private var normalBody: some View {
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
                    .onChange(of: tab.blocks.count) { _, newCount in
                        if autoScroll && newCount != lastBlockCount {
                            lastBlockCount = newCount
                            scrollToEnd(proxy)
                        }
                    }
                    .onChange(of: tab.isProcessing) { _, processing in
                        // 처리 완료 시 최종 결과로 스크롤
                        if !processing && autoScroll {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { scrollToEnd(proxy) }
                        }
                    }
                    .onChange(of: tab.claudeActivity) { _, _ in
                        // 활동 상태 변경될 때마다 스크롤 (tool 전환 등)
                        if autoScroll { scrollToEnd(proxy) }
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
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true } }
        .onAppear { syncPlanSelectionState(with: activePlanSelectionRequest) }
        .onChange(of: activePlanSelectionRequest?.signature ?? "") { _, _ in
            syncPlanSelectionState(with: activePlanSelectionRequest)
        }
        .onReceive(elapsedTimer) { _ in
            if tab.isProcessing || tab.claudeActivity != .idle {
                elapsedSeconds = Int(Date().timeIntervalSince(tab.startTime))
            }
        }
        // [Feature 5] 승인 모달
        .sheet(item: $tab.pendingApproval) { approval in
            ApprovalSheet(approval: approval)
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 2] Status Bar
    // ═══════════════════════════════════════════

    private var statusBar: some View {
        HStack(spacing: 8) {
            // Worker + Activity
            HStack(spacing: 4) {
                Circle().fill(tab.workerColor).frame(width: 6, height: 6)
                Text(tab.workerName).font(Theme.mono(9, weight: .semibold)).foregroundColor(tab.workerColor)
                Text(activityLabel).font(Theme.mono(9)).foregroundColor(activityLabelColor)
            }

            Rectangle().fill(Theme.border).frame(width: 1, height: 12)

            // Elapsed time
            HStack(spacing: 0) {
                Text(formatElapsed(elapsedSeconds)).font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
            }

            // File count
            if !tab.fileChanges.isEmpty {
                Rectangle().fill(Theme.border).frame(width: 1, height: 12)
                HStack(spacing: 3) {
                    Image(systemName: "doc.fill").font(Theme.mono(8)).foregroundColor(Theme.green)
                    Text("\(Set(tab.fileChanges.map(\.fileName)).count) files").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.green)
                }
            }

            // Error count
            if tab.errorCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill").font(Theme.mono(7)).foregroundColor(Theme.red)
                    Text("\(tab.errorCount) errors").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.red)
                }
            }

            // Commands
            if tab.commandCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "terminal").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                    Text("\(tab.commandCount) cmds").font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            // Toggle buttons
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilterBar.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "line.3.horizontal.decrease.circle\(showFilterBar ? ".fill" : "")")
                        .font(Theme.mono(8))
                    Text("필터").font(Theme.mono(8, weight: showFilterBar ? .bold : .regular))
                }
                .foregroundColor(showFilterBar || blockFilter.isActive ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilterBar ? Theme.accent.opacity(0.08) : .clear).cornerRadius(4)
            }.buttonStyle(.plain).help("로그 필터")

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilePanel.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text.magnifyingglass").font(Theme.mono(8))
                    Text("파일").font(Theme.mono(8, weight: showFilePanel ? .bold : .regular))
                }
                .foregroundColor(showFilePanel ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilePanel ? Theme.accent.opacity(0.08) : .clear).cornerRadius(4)
            }.buttonStyle(.plain).help("파일 변경")
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Theme.bgSurface.opacity(0.5))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private var activityLabel: String {
        switch tab.claudeActivity {
        case .idle: return "대기"; case .thinking: return "생각 중"; case .reading: return "읽는 중"
        case .writing: return "작성 중"; case .searching: return "검색 중"; case .running: return "실행 중"
        case .done: return "완료"; case .error: return "에러"
        }
    }

    private var activityLabelColor: Color {
        switch tab.claudeActivity {
        case .thinking: return Theme.purple; case .reading: return Theme.accent; case .writing: return Theme.green
        case .searching: return Theme.cyan; case .running: return Theme.yellow; case .done: return Theme.green
        case .error: return Theme.red; case .idle: return Theme.textDim
        }
    }

    private func formatElapsed(_ secs: Int) -> String {
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs / 60)m \(secs % 60)s" }
        return "\(secs / 3600)h \((secs % 3600) / 60)m"
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 6] Filter Bar
    // ═══════════════════════════════════════════

    private var filterBar: some View {
        HStack(spacing: 4) {
            Text("Filter").font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.textDim)
            ForEach(["Bash", "Read", "Write", "Edit", "Grep", "Glob"], id: \.self) { tool in
                filterChip(tool, color: toolColor(tool))
            }
            Rectangle().fill(Theme.border).frame(width: 1, height: 12)
            Button(action: { blockFilter.onlyErrors.toggle() }) {
                Text("Errors").font(Theme.mono(8, weight: blockFilter.onlyErrors ? .bold : .regular))
                    .foregroundColor(blockFilter.onlyErrors ? Theme.red : Theme.textDim)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(blockFilter.onlyErrors ? Theme.red.opacity(0.1) : .clear).cornerRadius(3)
            }.buttonStyle(.plain)
            Spacer()
            if blockFilter.isActive {
                Button(action: { blockFilter = BlockFilter() }) {
                    Text("Clear").font(Theme.mono(8)).foregroundColor(Theme.accent)
                }.buttonStyle(.plain)
            }
            // Search
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                TextField("검색...", text: $blockFilter.searchText)
                    .textFieldStyle(.plain).font(Theme.mono(9)).frame(width: 80)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Theme.bgSurface.opacity(0.3))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func filterChip(_ tool: String, color: Color) -> some View {
        let active = blockFilter.toolTypes.contains(tool)
        return Button(action: {
            if active { blockFilter.toolTypes.remove(tool) }
            else { blockFilter.toolTypes.insert(tool) }
        }) {
            Text(tool).font(Theme.mono(8, weight: active ? .bold : .regular))
                .foregroundColor(active ? color : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(active ? color.opacity(0.1) : .clear).cornerRadius(3)
        }.buttonStyle(.plain)
    }

    private func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow; case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green; case "Grep", "Glob": return Theme.cyan
        default: return Theme.textSecondary
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 4] File Change Panel
    // ═══════════════════════════════════════════

    private var fileChangePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.text").font(Theme.mono(9)).foregroundColor(Theme.accent)
                Text("FILES").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                Spacer()
                Text("\(Set(tab.fileChanges.map(\.fileName)).count)")
                    .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.accent)
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
                                .font(Theme.mono(8)).foregroundColor(Theme.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(latest.fileName).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                Text("\(latest.action) x\(records.count)")
                                    .font(Theme.mono(7)).foregroundColor(Theme.textDim)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        } // if let records
                    }

                    if tab.fileChanges.isEmpty {
                        Text("변경된 파일 없음").font(Theme.monoSmall).foregroundColor(Theme.textDim)
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

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("streamEnd", anchor: .bottom)
    }

    private var filteredBlocks: [StreamBlock] {
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

    // MARK: - Input Bars

    private var fullInputBar: some View {
        VStack(spacing: 0) {
            // Settings
            HStack(spacing: 0) {
                // Model
                settingGroup("Model") {
                    ForEach(ClaudeModel.allCases) { m in
                        settingChip(m.displayName, isSelected: tab.selectedModel == m, color: modelColor(m)) { tab.selectedModel = m }
                    }
                }

                settingSep

                // Effort
                settingGroup("Effort") {
                    ForEach(EffortLevel.allCases) { l in
                        let name = l.rawValue.prefix(1).uppercased() + l.rawValue.dropFirst()
                        settingChip(name, isSelected: tab.effortLevel == l, color: Theme.accent) { tab.effortLevel = l }
                    }
                }

                settingSep

                // Output
                settingGroup("Output") {
                    ForEach(OutputMode.allCases) { m in
                        settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                    }
                }

                settingSep

                // Permission
                settingGroup("권한") {
                    ForEach(PermissionMode.allCases) { m in
                        settingChip(m.displayName, isSelected: tab.permissionMode == m, color: permissionColor(m)) { tab.permissionMode = m }
                            .help(m.desc)
                    }
                }

                Spacer(minLength: 4)

                if tab.totalCost > 0 {
                    Text(String(format: "$%.4f", tab.totalCost))
                        .font(Theme.mono(9, weight: .semibold)).foregroundColor(Theme.yellow)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.yellow.opacity(0.06)).cornerRadius(4)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Theme.bgSurface.opacity(0.6))

            // 설정 ↔ 입력 구분선
            Rectangle().fill(Theme.border).frame(height: 1)

            if let workflowTab = workflowDisplayTab, !workflowTab.workflowTimelineStages.isEmpty {
                workflowProgressBar(workflowTab)
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // Input (auto-growing)
            HStack(alignment: .bottom, spacing: 8) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 16)
                    Text(tab.projectName).font(Theme.monoSmall).foregroundColor(Theme.textDim)
                    Text(">").font(Theme.mono(12, weight: .semibold)).foregroundColor(Theme.accent)
                }.padding(.bottom, 4)

                // Auto-growing TextEditor
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if inputText.isEmpty {
                        Text(tab.isProcessing ? "실행 중..." : "명령을 입력하세요")
                            .font(Theme.monoNormal).foregroundColor(Theme.textDim.opacity(0.5))
                            .padding(.horizontal, 4).padding(.vertical, 8)
                    }
                    // Hidden text for height calculation
                    Text(inputText.isEmpty ? " " : inputText)
                        .font(Theme.monoNormal).foregroundColor(.clear)
                        .padding(.horizontal, 4).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Actual editor
                    TextEditor(text: $inputText)
                        .font(Theme.monoNormal).foregroundColor(Theme.textPrimary)
                        .focused($isFocused)
                        .disabled(tab.isProcessing)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 0).padding(.vertical, 4)
                }
                .frame(minHeight: 32, maxHeight: 120)
                .onKeyPress(.return, phases: .down) { event in
                    if event.modifiers.contains(.shift) {
                        return .ignored // Shift+Enter → 줄바꿈 (기본 동작)
                    }
                    submit()
                    return .handled // Enter → 전송
                }
                .onKeyPress(phases: .down) { event in
                    guard isCommandMode else { return .ignored }
                    return handleCommandKeyNavigation(event)
                }
                .onChange(of: inputText) { _, _ in selectedCommandIndex = 0 }

                if tab.isProcessing {
                    Button(action: { tab.cancelProcessing() }) {
                        Label("Stop", systemImage: "stop.fill").font(Theme.mono(9, weight: .medium))
                            .foregroundColor(Theme.red).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.red.opacity(0.1)).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.bottom, 4)
                } else {
                    Button(action: { submit() }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: Theme.iconSize(20)))
                            .foregroundColor(inputText.isEmpty ? Theme.textDim : Theme.accent)
                    }.buttonStyle(.plain).disabled(inputText.isEmpty).padding(.bottom, 4)
                }
            }.padding(.horizontal, 14).padding(.vertical, 4)
        }
        .background(Theme.bgInput)
        .overlay(
            VStack(spacing: 0) {
                Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1)
                Spacer()
                Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1)
            }
        )
    }

    private var compactInputBar: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("입력...").font(Theme.monoSmall).foregroundColor(Theme.textDim.opacity(0.5))
                        .padding(.horizontal, 4).padding(.vertical, 6)
                }
                Text(inputText.isEmpty ? " " : inputText)
                    .font(Theme.monoSmall).foregroundColor(.clear)
                    .padding(.horizontal, 4).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $inputText)
                    .font(Theme.monoSmall).foregroundColor(Theme.textPrimary)
                    .focused($isFocused).disabled(tab.isProcessing)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 0).padding(.vertical, 2)
            }
            .frame(minHeight: 28, maxHeight: 100)
            .onKeyPress(.return, phases: .down) { event in
                if event.modifiers.contains(.shift) { return .ignored }
                submit(); return .handled
            }
            .onKeyPress(phases: .down) { event in
                guard isCommandMode else { return .ignored }
                return handleCommandKeyNavigation(event)
            }

            if tab.isProcessing {
                Button(action: { tab.cancelProcessing() }) {
                    Image(systemName: "stop.fill").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.red)
                }.buttonStyle(.plain).padding(.bottom, 4)
            } else {
                Button(action: { submit() }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: Theme.iconSize(14)))
                        .foregroundColor(inputText.isEmpty ? Theme.textDim : Theme.accent)
                }.buttonStyle(.plain).disabled(inputText.isEmpty).padding(.bottom, 4)
            }
        }.padding(.horizontal, 8).padding(.vertical, 3).background(Theme.bgInput)
    }

    private func submit() {
        let p = inputText.trimmingCharacters(in: .whitespaces); guard !p.isEmpty else { return }

        // Slash command handling
        if p.hasPrefix("/") {
            let parts = String(p.dropFirst()).split(separator: " ", maxSplits: 1).map(String.init)
            let cmdName = parts.first?.lowercased() ?? ""
            let args = parts.count > 1 ? parts[1].split(separator: " ").map(String.init) : []

            // 정확히 매칭되는 명령어 먼저 찾기
            var cmd = Self.allSlashCommands.first(where: { $0.name == cmdName })

            // 정확한 매칭이 없으면 → 추천 목록에서 선택된 항목 사용
            if cmd == nil {
                let matches = matchingCommands
                if !matches.isEmpty {
                    let idx = min(selectedCommandIndex, matches.count - 1)
                    cmd = matches[idx]
                }
            }

            if let cmd = cmd {
                inputText = ""; selectedCommandIndex = 0
                tab.appendBlock(.userPrompt, content: "/\(cmd.name)" + (args.isEmpty ? "" : " " + args.joined(separator: " ")))
                cmd.action(tab, manager, args)
                return
            } else {
                inputText = ""; selectedCommandIndex = 0
                tab.appendBlock(.userPrompt, content: p)
                tab.appendBlock(.status(message: "⚠️ 알 수 없는 명령어: /\(cmdName)\n/help 로 사용 가능한 명령어를 확인하세요"))
                return
            }
        }

        inputText = ""; tab.sendPrompt(p)
        AchievementManager.shared.addXP(5); AchievementManager.shared.incrementCommand()
    }

    // ═══════════════════════════════════════════
    // MARK: - Command Suggestions View
    // ═══════════════════════════════════════════

    private var commandSuggestionsView: some View {
        let commands = matchingCommands
        let clampedIndex = min(selectedCommandIndex, max(0, commands.count - 1))
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            HStack(spacing: 4) {
                Image(systemName: "command").font(Theme.mono(8)).foregroundColor(Theme.accent)
                Text("명령어").font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.accent)
                if commands.count < Self.allSlashCommands.count {
                    Text("\(commands.count)개 일치").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("↑↓ 선택  Tab 완성  Enter 실행  Esc 닫기").font(Theme.mono(7)).foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 12).padding(.vertical, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(commands.enumerated()), id: \.offset) { idx, cmd in
                            let isSelected = idx == clampedIndex
                            HStack(spacing: 6) {
                                Text("/\(cmd.name)")
                                    .font(Theme.mono(11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Theme.accent : Theme.textPrimary)
                                if !cmd.usage.isEmpty {
                                    Text(cmd.usage).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                                }
                                Spacer()
                                Text(cmd.description).font(Theme.mono(9)).foregroundColor(isSelected ? Theme.textSecondary : Theme.textDim)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(isSelected ? Theme.accent.opacity(0.12) : .clear)
                            .contentShape(Rectangle())
                            .id(idx)
                            .onTapGesture {
                                inputText = "/\(cmd.name) "
                                selectedCommandIndex = idx
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
                .onChange(of: selectedCommandIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(min(newIdx, commands.count - 1), anchor: .center) }
                }
            }
        }
        .background(Theme.bgSurface)
    }

    private func handleCommandKeyNavigation(_ key: KeyPress) -> KeyPress.Result {
        let commands = matchingCommands

        // Escape → 명령어 모드 종료
        if key.key == .escape {
            inputText = ""
            selectedCommandIndex = 0
            return .handled
        }

        guard !commands.isEmpty else { return .ignored }

        if key.key == .upArrow {
            selectedCommandIndex = max(0, selectedCommandIndex - 1)
            return .handled
        } else if key.key == .downArrow {
            selectedCommandIndex = min(commands.count - 1, selectedCommandIndex + 1)
            return .handled
        } else if key.key == .tab {
            let idx = min(selectedCommandIndex, commands.count - 1)
            inputText = "/\(commands[idx].name) "
            return .handled
        }
        return .ignored
    }

    private var workflowDisplayTab: TerminalTab? {
        if let sourceId = tab.automationSourceTabId,
           let sourceTab = manager.tabs.first(where: { $0.id == sourceId }) {
            return sourceTab
        }
        return tab.workflowTimelineStages.isEmpty ? nil : tab
    }

    private var activePlanSelectionRequest: PlanSelectionRequest? {
        guard tab.permissionMode == .plan, !tab.isProcessing else { return nil }

        let lastUserPromptIndex = tab.blocks.lastIndex { block in
            if case .userPrompt = block.blockType { return true }
            return false
        }

        guard let lastUserPromptIndex else { return nil }
        let responseBlocks = tab.blocks.suffix(from: tab.blocks.index(after: lastUserPromptIndex))
        let responseText = responseBlocks.compactMap { block -> String? in
            if case .thought = block.blockType {
                return block.content
            }
            return nil
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !responseText.isEmpty else { return nil }
        return PlanSelectionRequest.parse(from: responseText)
    }

    private func syncPlanSelectionState(with request: PlanSelectionRequest?) {
        guard let request else {
            planSelectionSignature = ""
            planSelectionDraft = [:]
            return
        }

        guard planSelectionSignature != request.signature else { return }
        planSelectionSignature = request.signature
        planSelectionDraft = [:]
    }

    private func planSelectionPanel(_ request: PlanSelectionRequest) -> some View {
        let selectedCount = request.groups.reduce(into: 0) { count, group in
            if planSelectionDraft[group.id] != nil { count += 1 }
        }
        let isComplete = selectedCount == request.groups.count

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: Theme.iconSize(compact ? 8 : 10)))
                    .foregroundColor(Theme.purple)
                Text("플랜 선택")
                    .font(Theme.mono(compact ? 9 : 10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(selectedCount)/\(request.groups.count)")
                    .font(Theme.mono(compact ? 8 : 9, weight: .semibold))
                    .foregroundColor(isComplete ? Theme.green : Theme.textDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isComplete ? Theme.green : Theme.bgSelected).opacity(0.12))
                    .cornerRadius(4)
                Spacer()
                if !planSelectionDraft.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            planSelectionDraft = [:]
                        }
                    }) {
                        Text("초기화")
                            .font(Theme.mono(compact ? 8 : 9))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let promptLine = request.promptLine {
                Text(promptLine)
                    .font(Theme.mono(compact ? 9 : 10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }

            ForEach(request.groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .font(Theme.mono(compact ? 9 : 10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(group.options) { option in
                            let isSelected = planSelectionDraft[group.id] == option.key
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    planSelectionDraft[group.id] = option.key
                                }
                            }) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(option.key)
                                        .font(Theme.mono(compact ? 8 : 9, weight: .bold))
                                        .foregroundColor(isSelected ? Theme.bg : Theme.purple)
                                        .frame(width: compact ? 18 : 20, height: compact ? 18 : 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(isSelected ? Theme.purple : Theme.purple.opacity(0.12))
                                        )
                                    Text(option.label)
                                        .font(Theme.mono(compact ? 9 : 10))
                                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: Theme.iconSize(compact ? 8 : 9)))
                                            .foregroundColor(Theme.green)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Theme.purple.opacity(0.1) : Theme.bgSurface.opacity(0.65))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Theme.purple.opacity(0.35) : Theme.border.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: {
                    inputText = request.responseText(from: planSelectionDraft)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFocused = true }
                }) {
                    Text("입력창에 넣기")
                        .font(Theme.mono(compact ? 8 : 9, weight: .medium))
                        .foregroundColor(isComplete ? Theme.textPrimary : Theme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.bgSurface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isComplete ? Theme.border.opacity(0.5) : Theme.border.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)

                Button(action: {
                    let response = request.responseText(from: planSelectionDraft)
                    guard !response.isEmpty else { return }
                    inputText = ""
                    tab.sendPrompt(response)
                    AchievementManager.shared.addXP(5)
                    AchievementManager.shared.incrementCommand()
                }) {
                    Text("선택 보내기")
                        .font(Theme.mono(compact ? 8 : 9, weight: .bold))
                        .foregroundColor(isComplete ? Theme.bg : Theme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isComplete ? Theme.purple : Theme.bgSelected.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)

                Spacer()
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .background(Theme.bgSurface.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.purple.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.top, 8)
        .padding(.bottom, compact ? 2 : 4)
    }

    private func workflowProgressBar(_ workflowTab: TerminalTab) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.accent)
                Text("인수 흐름")
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(Theme.textDim)
                if let summary = workflowTab.workflowProgressSummary {
                    Text(summary)
                        .font(Theme.mono(8, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workflowTab.workflowTimelineStages) { stage in
                        workflowStageChip(stage)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.bgSurface.opacity(0.45))
    }

    private func workflowStageChip(_ stage: WorkflowStageRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(stage.role.displayName)
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(stage.state.tint)
                Text(stage.state.label)
                    .font(Theme.mono(7, weight: .semibold))
                    .foregroundColor(stage.state.tint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(stage.state.tint.opacity(0.12))
                    .cornerRadius(4)
            }

            Text(stage.workerName)
                .font(Theme.mono(9, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Text(stage.handoffLabel)
                .font(Theme.mono(7))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.bgCard.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stage.state.tint.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Setting Helpers

    private func settingGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.mono(8, weight: .medium))
                .foregroundColor(Theme.textDim)
                .fixedSize()
            HStack(spacing: 2) {
                content()
            }
        }
        .padding(.horizontal, 6)
    }

    private var settingSep: some View {
        Rectangle().fill(Theme.textDim.opacity(0.25)).frame(width: 1, height: 18).padding(.horizontal, 4)
    }

    private func settingChip(_ label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.12)) { action() } }) {
            Text(label)
                .font(Theme.mono(9, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? color : Theme.textDim)
                .fixedSize()
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? color.opacity(0.14) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? color.opacity(0.3) : .clear, lineWidth: 0.5)
                )
        }.buttonStyle(.plain)
    }

    private func modelColor(_ m: ClaudeModel) -> Color {
        switch m {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
        }
    }

    private func approvalColor(_ m: ApprovalMode) -> Color {
        switch m {
        case .auto: return Theme.yellow
        case .ask: return Theme.orange
        case .safe: return Theme.green
        }
    }

    private func permissionColor(_ m: PermissionMode) -> Color {
        switch m {
        case .acceptEdits: return Theme.green
        case .bypassPermissions: return Theme.yellow
        case .auto: return Theme.cyan
        case .defaultMode: return Theme.orange
        case .plan: return Theme.purple
        }
    }
}

private struct PlanSelectionRequest {
    struct Group: Identifiable {
        let id: String
        let title: String
        let options: [Option]
    }

    struct Option: Identifiable {
        let id: String
        let key: String
        let label: String
    }

    let signature: String
    let promptLine: String?
    let groups: [Group]

    static func parse(from text: String) -> PlanSelectionRequest? {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        let lowered = normalizedText.lowercased()
        let requestMarkers = ["선호", "선택", "알려주세요", "골라", "정해주세요", "말씀해주세요", "choose", "pick", "prefer"]
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
                    currentTitle = "선택"
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

    func responseText(from selections: [String: String]) -> String {
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

        guard trimmed.count >= 3 else { return nil }
        let characters = Array(trimmed)
        let marker = characters[0]
        let separator = characters[1]
        guard marker.isLetter, separator == ")" || separator == "." || separator == ":" else { return nil }

        let key = String(marker).uppercased()
        let label = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return nil }

        return Option(
            id: "plan-option-\(key)-\(label)",
            key: key,
            label: label
        )
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Event Block View
// ═══════════════════════════════════════════════════════

struct EventBlockView: View {
    @ObservedObject var block: StreamBlock
    @ObservedObject private var settings = AppSettings.shared
    let compact: Bool

    var body: some View {
        switch block.blockType {
        case .sessionStart:
            sessionStartBlock
        case .userPrompt:
            userPromptBlock
        case .thought:
            thoughtBlock
        case .toolUse(let name, _):
            toolUseBlock(name: name)
        case .toolOutput:
            toolOutputBlock
        case .toolError:
            toolErrorBlock
        case .toolEnd(let success):
            toolEndBlock(success: success)
        case .fileChange(_, let action):
            fileChangeBlock(action: action)
        case .status(let msg):
            statusBlock(msg)
        case .completion(let cost, let duration):
            completionBlock(cost: cost, duration: duration)
        case .error(let msg):
            errorBlock(msg)
        case .text:
            textBlock
        }
    }

    // MARK: - Block Styles

    private var sessionStartBlock: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.circle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.green)
            Text(block.content).font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var userPromptBlock: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(">").font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.accent)
            Text(block.content).font(Theme.mono(compact ? 11 : 13)).foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.06)))
    }

    private var thoughtBlock: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(Theme.textDim).frame(width: 4, height: 4).padding(.top, 6)
            MarkdownTextView(text: block.content, compact: compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }.padding(.vertical, 2)
    }

    private func toolUseBlock(name: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(toolColor(name)).frame(width: 6, height: 6)
            Text("\(name)").font(Theme.mono(compact ? 10 : 11, weight: .bold)).foregroundColor(toolColor(name))
            Text("(\(block.content))").font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.textSecondary).lineLimit(1)
            if !block.isComplete { ProgressView().scaleEffect(0.4).frame(width: 10, height: 10) }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(toolColor(name).opacity(0.06)))
    }

    private var toolOutputBlock: some View {
        ToolOutputBlockView(block: block, compact: compact)
    }

    private var toolErrorBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("  x ").font(Theme.mono(11)).foregroundColor(Theme.red)
            Text(block.content)
                .font(Theme.mono(compact ? 10 : 11))
                .foregroundColor(Theme.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 8)
        .background(Theme.red.opacity(0.04))
    }

    private func toolEndBlock(success: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: success ? "checkmark" : "xmark")
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(success ? Theme.green : Theme.red)
        }
        .padding(.leading, 16).padding(.vertical, 1)
    }

    private func fileChangeBlock(action: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: action == "Write" ? "doc.badge.plus" : "pencil.line")
                .font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
            Text(action).font(Theme.mono(10, weight: .semibold)).foregroundColor(Theme.green)
            Text(block.content).font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, 3).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.06)))
    }

    private func statusBlock(_ msg: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.textDim)
            Text(msg).font(Theme.monoTiny).foregroundColor(Theme.textDim).italic()
        }.padding(.vertical, 1)
    }

    private func completionBlock(cost: Double?, duration: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 완료 헤더
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(14))).foregroundColor(Theme.green)
                Text("완료").font(Theme.mono(12, weight: .bold)).foregroundColor(Theme.green)
                Spacer()
                HStack(spacing: 8) {
                    if let d = duration {
                        HStack(spacing: 0) {
                            Text("\(d/1000).\(d%1000/100)s").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        }
                    }
                    if let c = cost, c > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "dollarsign.circle").font(.system(size: Theme.iconSize(8))).foregroundColor(Theme.yellow)
                            Text(String(format: "$%.4f", c)).font(Theme.mono(9, weight: .semibold)).foregroundColor(Theme.yellow)
                        }
                    }
                }
            }

            // 결과 내용 (마크다운 렌더링)
            if !block.content.isEmpty && block.content != "완료" {
                Rectangle().fill(Theme.green.opacity(0.15)).frame(height: 1)
                MarkdownTextView(text: block.content, compact: compact)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface.opacity(0.6)))
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Theme.green.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.green.opacity(0.15), lineWidth: 0.5))
        )
    }

    private func errorBlock(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.red)
            Text(msg).font(Theme.mono(11)).foregroundColor(Theme.red)
            if !block.content.isEmpty { Text(block.content).font(Theme.monoSmall).foregroundColor(Theme.red.opacity(0.7)) }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.05)))
    }

    private var textBlock: some View {
        Text(block.content).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textTerminal)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow
        case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green
        case "Grep", "Glob": return Theme.cyan
        case "Agent": return Theme.purple
        default: return Theme.textSecondary
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Tool Output Block View (truncated)
// ═══════════════════════════════════════════════════════

struct ToolOutputBlockView: View {
    @ObservedObject var block: StreamBlock
    let compact: Bool
    private let maxCollapsedLines = 8

    @State private var isExpanded = false

    private var lines: [String] {
        block.content.components(separatedBy: "\n")
    }

    private var isTruncatable: Bool {
        lines.count > maxCollapsedLines
    }

    private var displayText: String {
        if isExpanded || !isTruncatable {
            return block.content
        }
        let head = lines.prefix(4)
        let tail = lines.suffix(3)
        let hidden = lines.count - 7
        return (head + ["    ... \(hidden)줄 생략 ..."] + tail).joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text("  | ").font(Theme.mono(11)).foregroundColor(Theme.textDim)
                Text(displayText)
                    .font(Theme.mono(compact ? 10 : 11))
                    .foregroundColor(Theme.textTerminal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }.padding(.leading, 8)

            if isTruncatable {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: Theme.iconSize(7)))
                        Text(isExpanded ? "접기" : "전체 보기 (\(lines.count)줄)")
                            .font(Theme.mono(9))
                    }
                    .foregroundColor(Theme.textDim)
                    .padding(.leading, 28)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Markdown Text View
// ═══════════════════════════════════════════════════════

struct MarkdownTextView: View {
    let text: String
    let compact: Bool

    // Pre-compiled regex patterns (avoid recompilation on every inlineMarkdown call)
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let codeRegex = try! NSRegularExpression(pattern: "`([^`]+)`")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, mdBlock in
                switch mdBlock {
                case .heading(let level, let content):
                    Text(content)
                        .font(Theme.mono(headingSize(level), weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, level <= 2 ? 6 : 3)
                case .codeBlock(let code):
                    Text(code)
                        .font(Theme.mono(compact ? 10 : 11))
                        .foregroundColor(Theme.cyan)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 0.5))
                        .textSelection(.enabled)
                case .bullet(let content):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.accent)
                            .frame(width: 10)
                        inlineMarkdown(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .separator:
                    Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)
                case .table(let rows):
                    tableView(rows)
                case .paragraph(let content):
                    inlineMarkdown(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Inline markdown (bold, code, italic)

    private func inlineMarkdown(_ text: String) -> Text {
        var result = Text("")
        let nsText = text as NSString
        var pos = 0

        while pos < nsText.length {
            let searchRange = NSRange(location: pos, length: nsText.length - pos)

            // Find earliest match of either pattern
            let boldMatch = Self.boldRegex.firstMatch(in: text, range: searchRange)
            let codeMatch = Self.codeRegex.firstMatch(in: text, range: searchRange)

            // Pick whichever comes first
            let match: NSTextCheckingResult?
            let isBold: Bool
            if let b = boldMatch, let c = codeMatch {
                if b.range.location <= c.range.location {
                    match = b; isBold = true
                } else {
                    match = c; isBold = false
                }
            } else if let b = boldMatch {
                match = b; isBold = true
            } else if let c = codeMatch {
                match = c; isBold = false
            } else {
                match = nil; isBold = false
            }

            guard let m = match else {
                // No more matches — emit rest as plain text
                let rest = nsText.substring(from: pos)
                result = result + Text(rest).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textSecondary)
                break
            }

            // Emit text before the match
            if m.range.location > pos {
                let before = nsText.substring(with: NSRange(location: pos, length: m.range.location - pos))
                result = result + Text(before).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textSecondary)
            }

            // Emit the matched content (capture group 1)
            let inner = nsText.substring(with: m.range(at: 1))
            if isBold {
                result = result + Text(inner).font(Theme.mono(compact ? 11 : 12, weight: .bold)).foregroundColor(Theme.textPrimary)
            } else {
                result = result + Text(inner).font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.cyan)
            }

            pos = m.range.location + m.range.length
        }
        return result
    }

    // MARK: - Table

    private func tableView(_ rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell.trimmingCharacters(in: .whitespaces))
                            .font(Theme.mono(compact ? 9 : 10, weight: rowIdx == 0 ? .bold : .regular))
                            .foregroundColor(rowIdx == 0 ? Theme.textPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                        if colIdx < row.count - 1 {
                            Rectangle().fill(Theme.border.opacity(0.3)).frame(width: 1)
                        }
                    }
                }
                if rowIdx == 0 {
                    Rectangle().fill(Theme.border).frame(height: 1)
                } else if rowIdx < rows.count - 1 {
                    Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 0.5))
    }

    // MARK: - Block Parser

    private enum MdBlock {
        case heading(Int, String)
        case codeBlock(String)
        case bullet(String)
        case separator
        case table([[String]])
        case paragraph(String)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return compact ? 14 : 16
        case 2: return compact ? 13 : 14
        case 3: return compact ? 12 : 13
        default: return compact ? 11 : 12
        }
    }

    private func parseBlocks() -> [MdBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MdBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(code.joined(separator: "\n")))
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("###") {
                blocks.append(.heading(3, String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix("##") {
                blocks.append(.heading(2, String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix("#") {
                blocks.append(.heading(1, String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }

            // Separator
            if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") {
                blocks.append(.separator)
                i += 1; continue
            }

            // Table (detect | at start)
            if trimmed.hasPrefix("|") && trimmed.contains("|") {
                var tableRows: [[String]] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    guard tl.hasPrefix("|") else { break }
                    // skip separator rows like |---|---|
                    if tl.contains("---") { i += 1; continue }
                    let cells = tl.components(separatedBy: "|").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    if !cells.isEmpty { tableRows.append(cells) }
                    i += 1
                }
                if !tableRows.isEmpty { blocks.append(.table(tableRows)) }
                continue
            }

            // Bullet
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                blocks.append(.bullet(content))
                i += 1; continue
            }

            // Empty line
            if trimmed.isEmpty {
                i += 1; continue
            }

            // Paragraph (collect consecutive non-empty lines)
            var para: [String] = [line]
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("```") || next.hasPrefix("|") || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("---") { break }
                para.append(lines[i])
                i += 1
            }
            blocks.append(.paragraph(para.joined(separator: "\n")))
        }
        return blocks
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Processing Indicator
// ═══════════════════════════════════════════════════════

struct ProcessingIndicator: View {
    let activity: ClaudeActivity
    let workerColor: Color
    let workerName: String
    @ObservedObject private var settings = AppSettings.shared
    @State private var dotPhase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(workerColor).frame(width: 8, height: 8)
            Text(workerName).font(Theme.mono(10, weight: .semibold)).foregroundColor(workerColor)
            Text(statusText).font(Theme.monoSmall).foregroundColor(Theme.textDim)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.textDim)
                        .frame(width: 3, height: 3)
                        .opacity(i <= dotPhase ? 0.8 : 0.2)
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in dotPhase = (dotPhase + 1) % 3 }
    }

    private var statusText: String {
        switch activity {
        case .thinking: return "생각 중"
        case .reading: return "읽는 중"
        case .writing: return "작성 중"
        case .searching: return "검색 중"
        case .running: return "실행 중"
        default: return "처리 중"
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Grid Panel View
// ═══════════════════════════════════════════════════════

struct GridPanelView: View {
    @EnvironmentObject var manager: SessionManager

    private var visibleGroups: [SessionManager.ProjectGroup] {
        if let selectedPath = manager.selectedGroupPath {
            let tabs = manager.visibleTabs
            guard let first = tabs.first else { return [] }
            return [SessionManager.ProjectGroup(id: selectedPath, projectName: first.projectName, tabs: tabs, hasActiveTab: tabs.contains(where: { $0.id == manager.activeTabId }))]
        }
        return manager.projectGroups
    }

    private var isFiltered: Bool { manager.selectedGroupPath != nil }

    var body: some View {
        if manager.visibleTabs.isEmpty {
            EmptySessionView()
        } else if manager.focusSingleTab, let tab = manager.activeTab {
            // 개별 워커 포커스: 한 명만 풀사이즈로
            EventStreamView(tab: tab, compact: false)
        } else {
            let groups = visibleGroups
            let tabCount = groups.reduce(0) { $0 + $1.tabs.count }
            let cols = tabCount <= 1 ? 1 : tabCount <= 4 ? 2 : 3
            GeometryReader { geo in
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
}

// 선택된 그룹 내 개별 탭 패널
struct GridSinglePanel: View {
    @ObservedObject var tab: TerminalTab
    @ObservedObject private var settings = AppSettings.shared
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 12)
                Text(tab.workerName).font(Theme.mono(9, weight: .bold)).foregroundColor(tab.workerColor)
                Text(tab.projectName).font(Theme.mono(9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                Spacer()
                if tab.isProcessing { ProgressView().scaleEffect(0.35).frame(width: 8, height: 8) }
                Text(tab.selectedModel.icon).font(Theme.monoTiny)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(isSelected ? Theme.bgSelected : Theme.bgCard)

            EventStreamView(tab: tab, compact: true)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: isSelected ? 1.5 : 0.5))
    }
}

struct GridGroupPanel: View {
    let group: SessionManager.ProjectGroup
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedWorkerIndex = 0

    private var activeTab: TerminalTab? {
        guard !group.tabs.isEmpty else { return nil }
        let idx = min(max(0, selectedWorkerIndex), group.tabs.count - 1)
        return group.tabs[idx]
    }

    var body: some View {
        Group {
            if let activeTab = activeTab {
                VStack(spacing: 0) {
                    // Header: project name + worker tabs
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(activeTab.workerColor).frame(width: 3, height: 12)
                        Text(group.projectName).font(Theme.mono(10, weight: .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        Spacer()

                        if group.tabs.count > 1 {
                            HStack(spacing: 2) {
                                ForEach(Array(group.tabs.enumerated()), id: \.element.id) { i, tab in
                                    Button(action: { selectedWorkerIndex = i; manager.selectTab(tab.id) }) {
                                        Text(tab.workerName).font(Theme.mono(7, weight: selectedWorkerIndex == i ? .bold : .regular))
                                            .foregroundColor(selectedWorkerIndex == i ? tab.workerColor : Theme.textDim)
                                            .padding(.horizontal, 4).padding(.vertical, 2)
                                            .background(selectedWorkerIndex == i ? tab.workerColor.opacity(0.1) : .clear)
                                            .cornerRadius(3)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        if activeTab.isProcessing { ProgressView().scaleEffect(0.35).frame(width: 8, height: 8) }
                        Text(activeTab.selectedModel.icon).font(Theme.monoTiny)
                    }

                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(group.hasActiveTab ? Theme.bgSelected : Theme.bgCard)

                    EventStreamView(tab: activeTab, compact: true)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(group.hasActiveTab ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: group.hasActiveTab ? 1.5 : 0.5))
                .onTapGesture { manager.selectTab(activeTab.id) }
            } else {
                EmptyView()
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - [Feature 5] Approval Sheet
// ═══════════════════════════════════════════════════════

struct ApprovalSheet: View {
    let approval: TerminalTab.PendingApproval
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill").font(.system(size: Theme.iconSize(20))).foregroundColor(Theme.yellow)
                Text("승인 필요").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
            }
            Text(approval.reason).font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
            Text(approval.command).font(Theme.mono(11)).foregroundColor(Theme.red)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.05)))
                .textSelection(.enabled)
            HStack {
                Button(action: { approval.onDeny?(); dismiss() }) {
                    Text("거부").font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.red)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Theme.red.opacity(0.1)).cornerRadius(6)
                }.buttonStyle(.plain).keyboardShortcut(.escape)
                Spacer()
                Button(action: { approval.onApprove?(); dismiss() }) {
                    Text("승인").font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.textOnAccent)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Theme.accent).cornerRadius(6)
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }
        }.padding(24).frame(width: 420).background(Theme.bgCard)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Supporting Views
// ═══════════════════════════════════════════════════════

struct EmptySessionView: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "hammer.fill").font(.system(size: Theme.iconSize(28))).foregroundColor(Theme.textDim.opacity(0.3))
            Text("Cmd+T to start").font(Theme.mono(10)).foregroundColor(Theme.textDim)
            Spacer()
        }.frame(maxWidth: .infinity).background(Theme.bgTerminal)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - New Tab Sheet (멀티 터미널 지원)
// ═══════════════════════════════════════════════════════

struct NewTabSheet: View {
    @EnvironmentObject var manager: SessionManager; @Environment(\.dismiss) var dismiss
    @State private var projectName = ""
    @State private var projectPath = ""
    @State private var terminalCount = 1
    @State private var tasks: [String] = [""]

    // 폴더 신뢰 확인
    @State private var trustConfirmed = false

    // 고급 옵션
    @State private var showAdvanced = false
    @State private var permissionMode: PermissionMode = .bypassPermissions
    @State private var systemPrompt = ""
    @State private var maxBudget: String = ""
    @State private var allowedTools = ""
    @State private var disallowedTools = ""
    @State private var additionalDir = ""
    @State private var additionalDirs: [String] = []
    @State private var continueSession = false
    @State private var useWorktree = false
    @State private var selectedModel: ClaudeModel = .sonnet
    @State private var effortLevel: EffortLevel = .medium

    var body: some View {
        if !trustConfirmed && !projectPath.isEmpty {
            trustPromptView
        } else {
            sessionConfigView
        }
    }

    // MARK: - 폴더 신뢰 확인 화면

    private var trustPromptView: some View {
        VStack(spacing: 0) {
            // 터미널 스타일 헤더
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: Theme.iconSize(28))).foregroundColor(Theme.yellow)

                Text("폴더 신뢰 확인")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }.padding(.top, 20).padding(.bottom, 12)

            // 경로 표시
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.accent)
                Text(projectPath)
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.accent).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.06)))
            .padding(.horizontal, 24)

            // 안내 텍스트
            VStack(alignment: .leading, spacing: 8) {
                Text("이 프로젝트를 직접 만들었거나 신뢰할 수 있나요?")
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                Text("(직접 작성한 코드, 잘 알려진 오픈소스, 또는 팀 프로젝트 등)")
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)

                Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.yellow)
                    Text("Claude Code가 이 폴더의 파일을 읽고, 수정하고, 실행할 수 있습니다.")
                        .font(Theme.mono(9)).foregroundColor(Theme.yellow)
                }
            }
            .padding(16).padding(.horizontal, 8)

            Spacer(minLength: 8)

            // 선택 버튼
            VStack(spacing: 6) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { trustConfirmed = true } }) {
                    HStack(spacing: 8) {
                        Text("❯").font(Theme.mono(12, weight: .bold)).foregroundColor(Theme.green)
                        Text("네, 이 폴더를 신뢰합니다")
                            .font(Theme.mono(11, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark.shield.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.green.opacity(0.3), lineWidth: 1)))
                }.buttonStyle(.plain).keyboardShortcut(.return)

                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Text(" ").font(Theme.mono(12, weight: .bold))
                        Text("아니오, 나가기")
                            .font(Theme.mono(11)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "xmark.circle").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.textDim)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 1)))
                }.buttonStyle(.plain).keyboardShortcut(.escape)
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }
        .frame(width: max(440, 440 * AppSettings.shared.fontSizeScale), height: max(340, 340 * AppSettings.shared.fontSizeScale))
        .background(Theme.bgCard)
    }

    // MARK: - 세션 설정 화면

    private var sessionConfigView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Header
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.system(size: Theme.iconSize(14))).foregroundColor(Theme.accent)
                        Text("New Session").font(Theme.mono(13, weight: .semibold)).foregroundColor(Theme.textPrimary)
                    }

                    // Project info
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PROJECT PATH").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                        HStack {
                            TextField("/path/to/project", text: $projectPath).textFieldStyle(.roundedBorder).font(Theme.monoSmall)
                            Button("Browse") {
                                let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                                if p.runModal() == .OK, let u = p.url {
                                    projectPath = u.path
                                    if projectName.isEmpty { projectName = u.lastPathComponent }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("PROJECT NAME").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                        TextField("e.g. my-project", text: $projectName).textFieldStyle(.roundedBorder).font(Theme.monoSmall)
                    }

                    // Model & Effort
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("MODEL").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                            HStack(spacing: 3) {
                                ForEach(ClaudeModel.allCases) { m in
                                    Button(action: { selectedModel = m }) {
                                        Text("\(m.icon) \(m.displayName)")
                                            .font(Theme.mono(9, weight: selectedModel == m ? .bold : .regular))
                                            .foregroundColor(selectedModel == m ? Theme.textPrimary : Theme.textDim)
                                            .padding(.horizontal, 8).padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 5)
                                                .fill(selectedModel == m ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                                                .overlay(RoundedRectangle(cornerRadius: 5)
                                                    .stroke(selectedModel == m ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.3), lineWidth: 1)))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("EFFORT").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                            HStack(spacing: 3) {
                                ForEach(EffortLevel.allCases) { l in
                                    Button(action: { effortLevel = l }) {
                                        Text("\(l.icon)")
                                            .font(.system(size: Theme.iconSize(10)))
                                            .padding(.horizontal, 6).padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 5)
                                                .fill(effortLevel == l ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                                                .overlay(RoundedRectangle(cornerRadius: 5)
                                                    .stroke(effortLevel == l ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.3), lineWidth: 1)))
                                    }.buttonStyle(.plain).help(l.rawValue.capitalized)
                                }
                            }
                        }
                    }

                    // Permission mode
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PERMISSION").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                        HStack(spacing: 3) {
                            ForEach(PermissionMode.allCases) { m in
                                Button(action: { permissionMode = m }) {
                                    Text("\(m.icon) \(m.displayName)")
                                        .font(Theme.mono(9, weight: permissionMode == m ? .bold : .regular))
                                        .foregroundColor(permissionMode == m ? Theme.textPrimary : Theme.textDim)
                                        .padding(.horizontal, 7).padding(.vertical, 5)
                                        .background(RoundedRectangle(cornerRadius: 5)
                                            .fill(permissionMode == m ? Theme.purple.opacity(0.1) : Theme.bgSurface)
                                            .overlay(RoundedRectangle(cornerRadius: 5)
                                                .stroke(permissionMode == m ? Theme.purple.opacity(0.4) : Theme.border.opacity(0.3), lineWidth: 1)))
                                }.buttonStyle(.plain).help(m.desc)
                            }
                        }
                    }

                    // Terminal count
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TERMINALS").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                            Spacer()
                            Text("\(terminalCount)개").font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.accent)
                        }
                        HStack(spacing: 4) {
                            ForEach([1, 2, 3, 4, 5], id: \.self) { n in
                                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { setTerminalCount(n) } }) {
                                    VStack(spacing: 2) {
                                        HStack(spacing: 1) {
                                            ForEach(0..<n, id: \.self) { i in
                                                let colorIdx = (manager.userVisibleTabCount + i) % Theme.workerColors.count
                                                RoundedRectangle(cornerRadius: 1).fill(Theme.workerColors[colorIdx])
                                                    .frame(width: n <= 3 ? 10 : 6, height: 14)
                                            }
                                        }
                                        Text("\(n)").font(Theme.mono(9, weight: terminalCount == n ? .bold : .regular))
                                            .foregroundColor(terminalCount == n ? Theme.accent : Theme.textDim)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(terminalCount == n ? Theme.accent.opacity(0.1) : Theme.bgSurface)
                                        .overlay(RoundedRectangle(cornerRadius: 6)
                                            .stroke(terminalCount == n ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.5), lineWidth: 1)))
                                }.buttonStyle(.plain)
                            }
                        }

                        if terminalCount > 1 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("각 터미널에 보낼 작업 (선택)").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                                ForEach(tasks.indices, id: \.self) { i in
                                    HStack(spacing: 6) {
                                        let colorIdx = (manager.userVisibleTabCount + i) % Theme.workerColors.count
                                        Circle().fill(Theme.workerColors[colorIdx]).frame(width: 8, height: 8)
                                        Text("#\(i + 1)").font(Theme.mono(8, weight: .bold))
                                            .foregroundColor(Theme.textDim).frame(width: 18)
                                        TextField("작업 내용 (비워두면 빈 터미널)", text: $tasks[i])
                                            .textFieldStyle(.roundedBorder).font(Theme.mono(10))
                                    }
                                }
                            }.padding(.top, 4)
                        }
                    }

                    // ── 고급 옵션 토글 ──
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                                .font(Theme.scaled(8, weight: .bold)).foregroundColor(Theme.textDim)
                            Text("고급 옵션").font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            if hasAdvancedOptions {
                                Text("설정됨").font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.green)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Theme.green.opacity(0.1)).cornerRadius(3)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface.opacity(0.5))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
                    }.buttonStyle(.plain)

                    if showAdvanced {
                        advancedOptionsView
                    }
                }.padding(24)
            }

            // Buttons
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button(action: {
                    if !projectPath.isEmpty && !trustConfirmed {
                        trustConfirmed = false // trigger trust prompt
                    } else {
                        createSessions(); dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: Theme.iconSize(9)))
                        Text(terminalCount > 1 ? "Create \(terminalCount)개" : "Create")
                            .font(Theme.mono(11, weight: .medium))
                    }
                    .foregroundColor(Theme.textOnAccent).padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Theme.accent).cornerRadius(6)
                }
                .buttonStyle(.plain).keyboardShortcut(.return)
                .disabled(projectPath.isEmpty && projectName.isEmpty)
            }.padding(.horizontal, 24).padding(.vertical, 12)
            .background(Theme.bgCard)
            .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
        }
        .frame(width: max(500, 500 * AppSettings.shared.fontSizeScale), height: max(580, 580 * AppSettings.shared.fontSizeScale))
        .background(Theme.bgCard)
    }

    // MARK: - 고급 옵션

    private var hasAdvancedOptions: Bool {
        !systemPrompt.isEmpty || maxBudget != "" || !allowedTools.isEmpty ||
        !disallowedTools.isEmpty || !additionalDirs.isEmpty || continueSession || useWorktree
    }

    private var advancedOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 시스템 프롬프트
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.purple)
                    Text("시스템 프롬프트").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                TextField("추가 지시사항 (--append-system-prompt)", text: $systemPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder).font(Theme.mono(10)).lineLimit(2...4)
            }

            // 예산 제한
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.yellow)
                        Text("예산 한도 (USD)").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    }
                    TextField("0 = 무제한", text: $maxBudget)
                        .textFieldStyle(.roundedBorder).font(Theme.mono(10)).frame(width: 100)
                }
                Spacer()

                // 세션 이어하기
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $continueSession) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.up.right").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.cyan)
                            Text("이전 대화 이어하기").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small)
                }
            }

            // 워크트리
            Toggle(isOn: $useWorktree) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
                    Text("Git 워크트리 생성").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("--worktree").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }.toggleStyle(.switch).controlSize(.small)

            // 도구 제한
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.orange)
                    Text("허용 도구").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("(쉼표 구분)").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField("예: Bash,Read,Edit,Write", text: $allowedTools)
                    .textFieldStyle(.roundedBorder).font(Theme.mono(10))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.shield.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.red)
                    Text("차단 도구").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("(쉼표 구분)").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField("예: Bash(rm:*)", text: $disallowedTools)
                    .textFieldStyle(.roundedBorder).font(Theme.mono(10))
            }

            // 추가 디렉토리
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.accent)
                    Text("추가 디렉토리 접근").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                HStack(spacing: 4) {
                    TextField("경로 추가", text: $additionalDir)
                        .textFieldStyle(.roundedBorder).font(Theme.mono(10))
                    Button(action: {
                        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                        if p.runModal() == .OK, let u = p.url { additionalDir = u.path }
                    }) {
                        Image(systemName: "folder").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.accent)
                    }.buttonStyle(.plain)
                    Button(action: {
                        if !additionalDir.isEmpty {
                            additionalDirs.append(additionalDir); additionalDir = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                    }.buttonStyle(.plain).disabled(additionalDir.isEmpty)
                }
                if !additionalDirs.isEmpty {
                    ForEach(additionalDirs.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill").font(.system(size: Theme.iconSize(8))).foregroundColor(Theme.accent.opacity(0.6))
                            Text(additionalDirs[i]).font(Theme.mono(9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                            Spacer()
                            Button(action: { additionalDirs.remove(at: i) }) {
                                Image(systemName: "xmark").font(Theme.scaled(7, weight: .bold)).foregroundColor(Theme.red)
                            }.buttonStyle(.plain)
                        }.padding(.leading, 8)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
    }

    private func setTerminalCount(_ n: Int) {
        terminalCount = n
        while tasks.count < n { tasks.append("") }
        while tasks.count > n { tasks.removeLast() }
    }

    private func createSessions() {
        let name = projectName.isEmpty ? (projectPath as NSString).lastPathComponent : projectName
        let path = projectPath.isEmpty ? NSHomeDirectory() : projectPath
        let capacity = manager.manualLaunchCapacity
        if capacity <= 0 {
            manager.notifyManualLaunchCapacity(requested: terminalCount)
            return
        }

        let launchCount = min(terminalCount, capacity)
        if launchCount < terminalCount {
            manager.notifyManualLaunchCapacity(requested: terminalCount)
        }

        for i in 0..<launchCount {
            let prompt = i < tasks.count ? tasks[i].trimmingCharacters(in: .whitespaces) : ""
            let tab = manager.addTab(
                projectName: name,
                projectPath: path,
                initialPrompt: prompt.isEmpty ? nil : prompt,
                manualLaunch: true,
                autoStart: false
            )
            tab.selectedModel = selectedModel
            tab.effortLevel = effortLevel
            tab.permissionMode = permissionMode
            tab.systemPrompt = systemPrompt
            tab.maxBudgetUSD = Double(maxBudget) ?? 0
            tab.allowedTools = allowedTools
            tab.disallowedTools = disallowedTools
            tab.additionalDirs = additionalDirs
            tab.continueSession = continueSession
            tab.useWorktree = useWorktree
            tab.start()
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - CLITerminalView (NSView 기반 진짜 터미널)
// ═══════════════════════════════════════════════════════

struct CLITerminalView: NSViewRepresentable {
    @ObservedObject var tab: TerminalTab
    var fontSize: CGFloat

    func makeNSView(context: Context) -> CLITerminalHostView {
        CLITerminalHostView(tab: tab, fontSize: fontSize)
    }

    func updateNSView(_ nsView: CLITerminalHostView, context: Context) {
        nsView.refreshOutput()
    }
}

/// NSTextView 서브클래스: 키보드 입력을 PTY로 전달
class CLITerminalTextView: NSTextView {
    weak var termTab: TerminalTab?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let tab = termTab else { return }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+C → 텍스트 복사 (기본 동작)
        if mods == .command && event.charactersIgnoringModifiers == "c" {
            if selectedRange().length > 0 { super.keyDown(with: event); return }
            // 선택 없으면 Ctrl+C로 처리
            tab.sendRawSignal(3); return
        }
        // Cmd+V → 클립보드 붙여넣기 → PTY로 전송
        if mods == .command && event.charactersIgnoringModifiers == "v" {
            if let text = NSPasteboard.general.string(forType: .string) { tab.writeRawInput(text) }
            return
        }
        // Cmd+A → 전체 선택 (기본 동작)
        if mods == .command && event.charactersIgnoringModifiers == "a" {
            super.keyDown(with: event); return
        }

        // Ctrl+키 → 제어 문자
        if mods.contains(.control), let chars = event.charactersIgnoringModifiers?.lowercased(), let c = chars.first,
           let ascii = c.asciiValue, ascii >= 0x61 && ascii <= 0x7A {
            tab.sendRawSignal(UInt8(ascii - 0x60)); return
        }

        // 특수 키
        switch event.keyCode {
        case 36:  tab.writeRawInput("\r")           // Return
        case 51:  tab.writeRawInput("\u{7f}")       // Backspace
        case 53:  tab.writeRawInput("\u{1b}")       // Escape
        case 48:  tab.writeRawInput("\t")           // Tab
        case 123: tab.writeRawInput("\u{1b}[D")     // Left
        case 124: tab.writeRawInput("\u{1b}[C")     // Right
        case 125: tab.writeRawInput("\u{1b}[B")     // Down
        case 126: tab.writeRawInput("\u{1b}[A")     // Up
        case 115: tab.writeRawInput("\u{1b}[H")     // Home
        case 119: tab.writeRawInput("\u{1b}[F")     // End
        case 116: tab.writeRawInput("\u{1b}[5~")    // Page Up
        case 121: tab.writeRawInput("\u{1b}[6~")    // Page Down
        case 117: tab.writeRawInput("\u{1b}[3~")    // Delete
        default:
            if let chars = event.characters, !chars.isEmpty {
                tab.writeRawInput(chars)
            }
        }
    }

    // 기본 텍스트 삽입 비활성화 (keyDown에서 직접 처리)
    override func insertText(_ string: Any, replacementRange: NSRange) {}
    override func insertNewline(_ sender: Any?) {}
    override func insertTab(_ sender: Any?) {}
    override func deleteBackward(_ sender: Any?) {}

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command {
            switch event.charactersIgnoringModifiers {
            case "c": if selectedRange().length > 0 { return super.performKeyEquivalent(with: event) }
                      termTab?.sendRawSignal(3); return true
            case "v": if let text = NSPasteboard.general.string(forType: .string) { termTab?.writeRawInput(text) }; return true
            case "a": return super.performKeyEquivalent(with: event)
            default: break
            }
        }
        return false
    }
}

/// 터미널 호스트 뷰: NSScrollView + CLITerminalTextView
class CLITerminalHostView: NSView {
    let scrollView: NSScrollView
    let textView: CLITerminalTextView
    weak var tab: TerminalTab?
    var fontSize: CGFloat
    private var lastRenderedLength = 0

    private static let termBg = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)

    init(tab: TerminalTab, fontSize: CGFloat) {
        self.tab = tab
        self.fontSize = fontSize
        self.scrollView = NSScrollView()
        self.textView = CLITerminalTextView()
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let bg = Self.termBg
        textView.termTab = tab
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = bg
        textView.insertionPointColor = NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1)
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = bg
        scrollView.drawsBackground = true
        scrollView.scrollerStyle = .overlay
        scrollView.autoresizingMask = [.width, .height]

        addSubview(scrollView)

        // 자동 포커스
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.window?.makeFirstResponder(self?.textView)
        }
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(textView)
    }

    func refreshOutput() {
        guard let tab = tab else { return }
        let output = tab.rawOutput
        guard output.count != lastRenderedLength else { return }
        lastRenderedLength = output.count

        let attributed = CLIAnsiParser.parse(output, fontSize: fontSize)
        textView.textStorage?.setAttributedString(attributed)

        // 자동 스크롤
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.textView else { return }
            tv.scrollToEndOfDocument(nil)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - ANSI 컬러 파서
// ═══════════════════════════════════════════════════════

enum CLIAnsiParser {
    static let defaultFg = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)

    static let colorMap: [Int: NSColor] = [
        30: NSColor(red: 0.2,  green: 0.2,  blue: 0.2,  alpha: 1),
        31: NSColor(red: 0.9,  green: 0.3,  blue: 0.3,  alpha: 1),
        32: NSColor(red: 0.3,  green: 0.85, blue: 0.4,  alpha: 1),
        33: NSColor(red: 0.9,  green: 0.8,  blue: 0.3,  alpha: 1),
        34: NSColor(red: 0.4,  green: 0.5,  blue: 0.9,  alpha: 1),
        35: NSColor(red: 0.8,  green: 0.4,  blue: 0.8,  alpha: 1),
        36: NSColor(red: 0.3,  green: 0.8,  blue: 0.85, alpha: 1),
        37: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
        90: NSColor(red: 0.5,  green: 0.5,  blue: 0.5,  alpha: 1),
        91: NSColor(red: 1.0,  green: 0.4,  blue: 0.4,  alpha: 1),
        92: NSColor(red: 0.4,  green: 1.0,  blue: 0.5,  alpha: 1),
        93: NSColor(red: 1.0,  green: 0.9,  blue: 0.4,  alpha: 1),
        94: NSColor(red: 0.5,  green: 0.6,  blue: 1.0,  alpha: 1),
        95: NSColor(red: 0.9,  green: 0.5,  blue: 0.9,  alpha: 1),
        96: NSColor(red: 0.4,  green: 0.9,  blue: 1.0,  alpha: 1),
        97: NSColor.white,
    ]

    static func parse(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        var fg = defaultFg
        var bold = false
        var dim = false
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            let font = bold ? boldFont : defaultFont
            var color = fg
            if dim { color = color.withAlphaComponent(0.6) }
            result.append(NSAttributedString(string: buffer, attributes: [
                .font: font, .foregroundColor: color,
            ]))
            buffer = ""
        }

        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]

            guard c == "\u{1B}" else {
                buffer.append(c)
                i = text.index(after: i)
                continue
            }

            flush()
            let next = text.index(after: i)
            guard next < text.endIndex else { i = next; break }

            switch text[next] {
            case "[":
                // CSI sequence
                var j = text.index(after: next)
                var params = ""
                while j < text.endIndex {
                    let jc = text[j]
                    if jc >= "@" && jc <= "~" {
                        if jc == "m" { // SGR — 색상/스타일
                            let codes = params.split(separator: ";").compactMap { Int($0) }
                            for code in codes.isEmpty ? [0] : codes {
                                switch code {
                                case 0:  fg = defaultFg; bold = false; dim = false
                                case 1:  bold = true
                                case 2:  dim = true
                                case 22: bold = false; dim = false
                                case 39: fg = defaultFg
                                default: if let c = colorMap[code] { fg = c }
                                }
                            }
                        }
                        // 다른 CSI 명령은 무시 (커서 이동 등)
                        i = text.index(after: j); break
                    }
                    params.append(jc)
                    j = text.index(after: j)
                }
                if j >= text.endIndex { i = j; break }

            case "]":
                // OSC sequence — BEL 또는 ST까지 스킵
                var j = text.index(after: next)
                while j < text.endIndex {
                    if text[j] == "\u{07}" { j = text.index(after: j); break }
                    if text[j] == "\u{1B}" {
                        let jn = text.index(after: j)
                        if jn < text.endIndex && text[jn] == "\\" { j = text.index(after: jn); break }
                    }
                    j = text.index(after: j)
                }
                i = j

            default:
                // 기타 2바이트 ESC 시퀀스 스킵
                i = text.index(after: next)
            }
        }

        flush()

        // BEL 등 제어 문자 최종 정리
        let cleaned = NSMutableAttributedString(attributedString: result)
        let fullRange = NSRange(location: 0, length: cleaned.length)
        cleaned.mutableString.replaceOccurrences(of: "\u{07}", with: "", range: fullRange)
        return cleaned
    }
}
