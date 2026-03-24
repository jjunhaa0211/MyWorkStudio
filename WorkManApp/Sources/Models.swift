import SwiftUI
import Darwin
import UserNotifications
import ScreenCaptureKit

// ═══════════════════════════════════════════════════════
// MARK: - Stream Event Architecture
// ═══════════════════════════════════════════════════════

/// 실시간 이벤트 블록 - 각 블록은 UI에서 독립적으로 렌더링됨
class StreamBlock: ObservableObject, Identifiable {
    let id = UUID()
    let timestamp = Date()
    let blockType: BlockType
    @Published var content: String = ""
    @Published var isComplete: Bool = false
    @Published var isError: Bool = false
    @Published var exitCode: Int?

    enum BlockType: Equatable {
        case sessionStart(model: String, sessionId: String)
        case thought                    // 💭 AI 사고 텍스트
        case toolUse(name: String, input: String) // ⏺ 도구 실행 (Bash, Read, Edit 등)
        case toolOutput                 // ⎿ 도구 결과 (stdout)
        case toolError                  // ✗ 도구 에러 (stderr)
        case toolEnd(success: Bool)     // 도구 완료
        case text                       // 일반 텍스트 응답
        case fileChange(path: String, action: String) // 파일 변경
        case status(message: String)    // 상태 메시지
        case completion(cost: Double?, duration: Int?) // 완료
        case error(message: String)     // 에러
        case userPrompt                 // 사용자 입력
    }

    init(type: BlockType, content: String = "") {
        self.blockType = type
        self.content = content
    }

    func append(_ text: String) {
        content += text
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Enums
// ═══════════════════════════════════════════════════════

enum ClaudeActivity: String {
    case idle = "idle"
    case thinking = "thinking"
    case reading = "reading"
    case writing = "writing"
    case searching = "searching"
    case running = "running bash"
    case done = "done"
    case error = "error"
}

enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus = "opus", sonnet = "sonnet", haiku = "haiku"
    var id: String { rawValue }
    var icon: String { switch self { case .opus: return "🟣"; case .sonnet: return "🔵"; case .haiku: return "🟢" } }
    var displayName: String { rawValue.capitalized }

    static func detect(from value: String) -> ClaudeModel? {
        let lowered = value.lowercased()
        return allCases.first { lowered.contains($0.rawValue) }
    }
}

enum EffortLevel: String, CaseIterable, Identifiable {
    case low, medium, high, max
    var id: String { rawValue }
    var icon: String { switch self { case .low: return "🐢"; case .medium: return "🚶"; case .high: return "🏃"; case .max: return "🚀" } }
}

enum OutputMode: String, CaseIterable, Identifiable {
    case full = "전체", realtime = "실시간", resultOnly = "결과만"
    var id: String { rawValue }
    var icon: String { switch self { case .full: return "📋"; case .realtime: return "⚡"; case .resultOnly: return "📌" } }
}

enum WorkerState: String {
    case idle, walking, coding, pairing, success, error
    case thinking, reading, writing, searching, running
}

// 권한 모드 (--permission-mode)
enum PermissionMode: String, CaseIterable, Identifiable {
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
    case auto = "auto"
    case defaultMode = "default"
    case plan = "plan"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .acceptEdits: return "✏️"
        case .bypassPermissions: return "⚡"
        case .auto: return "🤖"
        case .defaultMode: return "🛡️"
        case .plan: return "📋"
        }
    }
    var displayName: String {
        switch self {
        case .acceptEdits: return "수정만 허용"
        case .bypassPermissions: return "전체 허용"
        case .auto: return "자동"
        case .defaultMode: return "기본"
        case .plan: return "계획만"
        }
    }
    var desc: String {
        switch self {
        case .acceptEdits: return "파일 수정 권한 자동 승인"
        case .bypassPermissions: return "모든 권한 자동 승인"
        case .auto: return "상황에 따라 자동 판단"
        case .defaultMode: return "위험 명령 승인 필요"
        case .plan: return "계획만 세우고 실행 안함"
        }
    }
}

// 승인 모드 (UI용 - legacy)
enum ApprovalMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case ask = "Ask"
    case safe = "Safe"
    var id: String { rawValue }
    var icon: String { switch self { case .auto: return "⚡"; case .ask: return "🛡️"; case .safe: return "🔒" } }
    var desc: String { switch self { case .auto: return "모든 명령 자동 실행"; case .ask: return "위험 명령 승인 필요"; case .safe: return "읽기 전용" } }
}

// 로그 필터
struct BlockFilter {
    var toolTypes: Set<String> = []   // 비어있으면 전부 표시
    var onlyErrors: Bool = false
    var searchText: String = ""

    var isActive: Bool { !toolTypes.isEmpty || onlyErrors || !searchText.isEmpty }

    func matches(_ block: StreamBlock) -> Bool {
        // 에러 필터
        if onlyErrors {
            switch block.blockType {
            case .toolError, .error: break
            case .toolEnd(let success): if success { return false }
            default: return false
            }
        }
        // 도구 필터
        if !toolTypes.isEmpty {
            switch block.blockType {
            case .toolUse(let name, _): if !toolTypes.contains(name) { return false }
            case .toolOutput, .toolError, .toolEnd: break // 도구 결과는 항상 표시
            case .userPrompt, .thought, .completion, .error, .status, .sessionStart: break
            case .fileChange(_, let action):
                if !toolTypes.contains(action) && !toolTypes.contains("Write") && !toolTypes.contains("Edit") { return false }
            case .text: break
            }
        }
        // 검색 필터
        if !searchText.isEmpty {
            if !block.content.localizedCaseInsensitiveContains(searchText) { return false }
        }
        return true
    }
}

// 파일 변경 추적
struct FileChangeRecord: Identifiable {
    let id = UUID()
    let path: String
    let fileName: String
    let action: String // Write, Edit, Read
    let timestamp: Date
    var success: Bool = true
}

enum ParallelTaskState: String {
    case running
    case completed
    case failed

    var label: String {
        switch self {
        case .running: return "진행"
        case .completed: return "완료"
        case .failed: return "실패"
        }
    }

    var tint: Color {
        switch self {
        case .running: return Theme.cyan
        case .completed: return Theme.green
        case .failed: return Theme.red
        }
    }
}

struct ParallelTaskRecord: Identifiable, Equatable {
    let id: String
    let label: String
    let assigneeCharacterId: String
    var state: ParallelTaskState
}

enum WorkflowStageState: String {
    case queued
    case running
    case completed
    case failed
    case skipped

    var label: String {
        switch self {
        case .queued: return "대기"
        case .running: return "진행"
        case .completed: return "완료"
        case .failed: return "재작업"
        case .skipped: return "건너뜀"
        }
    }

    var tint: Color {
        switch self {
        case .queued: return Theme.textDim
        case .running: return Theme.cyan
        case .completed: return Theme.green
        case .failed: return Theme.red
        case .skipped: return Theme.textSecondary
        }
    }
}

struct WorkflowStageRecord: Identifiable, Equatable {
    let id: String
    let role: WorkerJob
    var workerName: String
    var assigneeCharacterId: String
    var state: WorkflowStageState
    var handoffLabel: String
    var detail: String
    var updatedAt: Date
}

struct GitInfo { var branch = "", changedFiles = 0, lastCommit = "", lastCommitAge = "", isGitRepo = false }
struct SessionSummary { var filesModified: [String] = [], duration: TimeInterval = 0, tokenCount = 0, cost: Double = 0, lastLines: [String] = [], commandCount: Int = 0, errorCount: Int = 0, timestamp = Date() }

class SessionGroup: ObservableObject, Identifiable {
    let id: String; @Published var name: String; @Published var color: Color; @Published var tabIds: [String]
    init(id: String = UUID().uuidString, name: String, color: Color, tabIds: [String] = []) {
        self.id = id; self.name = name; self.color = color; self.tabIds = tabIds
    }
}

class ClaudeInstallChecker {
    static let shared = ClaudeInstallChecker()
    var isInstalled = false, version = "", path = ""
    func check() {
        if let p = TerminalTab.shellSync("which claude 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            isInstalled = true; path = p
            version = TerminalTab.shellSync("claude --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Token Tracker (일간/주간 토큰 추적)
// ═══════════════════════════════════════════════════════

class TokenTracker: ObservableObject {
    static let shared = TokenTracker()
    static let recommendedDailyLimit = 500_000
    static let recommendedWeeklyLimit = 2_500_000
    private let saveKey = "WorkManTokenHistory"
    private let automationDailyReserve = 100_000
    private let automationWeeklyReserve = 300_000
    private let globalDailyReserve = 12_000
    private let globalWeeklyReserve = 40_000
    private let emergencyDailyReserve = 6_000
    private let emergencyWeeklyReserve = 20_000
    private let persistenceQueue = DispatchQueue(label: "workman.token-tracker", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    struct DayRecord: Codable {
        var date: String // "yyyy-MM-dd"
        var inputTokens: Int
        var outputTokens: Int
        var cost: Double
        var totalTokens: Int { inputTokens + outputTokens }
    }

    @Published var history: [DayRecord] = []

    // 사용자 설정 한도
    @AppStorage("dailyTokenLimit") var dailyTokenLimit: Int = TokenTracker.recommendedDailyLimit
    @AppStorage("weeklyTokenLimit") var weeklyTokenLimit: Int = TokenTracker.recommendedWeeklyLimit

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() { load() }

    private var todayKey: String { dateFormatter.string(from: Date()) }

    // MARK: - Record

    func recordTokens(input: Int, output: Int) {
        guard input > 0 || output > 0 else { return }
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].inputTokens += input
            history[idx].outputTokens += output
        } else {
            history.append(DayRecord(date: key, inputTokens: input, outputTokens: output, cost: 0))
        }
        scheduleSave()
        print("[TokenTracker] +\(input)in +\(output)out → today: \(todayTokens), week: \(weekTokens)")
    }

    func recordCost(_ cost: Double) {
        guard cost > 0 else { return }
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].cost += cost
        } else {
            history.append(DayRecord(date: key, inputTokens: 0, outputTokens: 0, cost: cost))
        }
        scheduleSave()
        print("[TokenTracker] cost +$\(String(format: "%.4f", cost)) → today: $\(String(format: "%.4f", todayCost))")
    }

    // MARK: - Queries

    var todayRecord: DayRecord {
        history.first(where: { $0.date == todayKey }) ?? DayRecord(date: todayKey, inputTokens: 0, outputTokens: 0, cost: 0)
    }

    var todayTokens: Int { todayRecord.totalTokens }
    var todayCost: Double { todayRecord.cost }

    var weekTokens: Int {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        return history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }.reduce(0) { $0 + $1.totalTokens }
    }

    var weekCost: Double {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        return history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }.reduce(0) { $0 + $1.cost }
    }

    private var safeDailyLimit: Int { max(1, dailyTokenLimit) }
    private var safeWeeklyLimit: Int { max(1, weeklyTokenLimit) }

    private func cappedReserve(_ configured: Int, limit: Int, maxRatio: Double) -> Int {
        let ratioCap = max(1, Int(Double(max(1, limit)) * maxRatio))
        return min(configured, ratioCap)
    }

    private var effectiveGlobalDailyReserve: Int {
        cappedReserve(globalDailyReserve, limit: safeDailyLimit, maxRatio: 0.05)
    }

    private var effectiveGlobalWeeklyReserve: Int {
        cappedReserve(globalWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.05)
    }

    private var effectiveAutomationDailyReserve: Int {
        cappedReserve(automationDailyReserve, limit: safeDailyLimit, maxRatio: 0.18)
    }

    private var effectiveAutomationWeeklyReserve: Int {
        cappedReserve(automationWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.18)
    }

    private var effectiveEmergencyDailyReserve: Int {
        cappedReserve(emergencyDailyReserve, limit: safeDailyLimit, maxRatio: 0.03)
    }

    private var effectiveEmergencyWeeklyReserve: Int {
        cappedReserve(emergencyWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.03)
    }

    var dailyRemaining: Int { max(0, safeDailyLimit - todayTokens) }
    var weeklyRemaining: Int { max(0, safeWeeklyLimit - weekTokens) }

    var dailyUsagePercent: Double { Double(todayTokens) / Double(safeDailyLimit) }
    var weeklyUsagePercent: Double { Double(weekTokens) / Double(safeWeeklyLimit) }

    private func protectionUsageSummary() -> String {
        "오늘 \(formatTokens(todayTokens))/\(formatTokens(safeDailyLimit)), 이번 주 \(formatTokens(weekTokens))/\(formatTokens(safeWeeklyLimit)) 사용 중입니다."
    }

    func startBlockReason(isAutomation: Bool) -> String? {
        if dailyRemaining <= effectiveGlobalDailyReserve ||
            weeklyRemaining <= effectiveGlobalWeeklyReserve ||
            dailyUsagePercent >= 0.985 ||
            weeklyUsagePercent >= 0.985 {
            return "전체 토큰 보호선을 넘겨 새 작업을 잠시 막았습니다. \(protectionUsageSummary()) 설정 > 토큰에서 한도를 올리거나 토큰 이력을 초기화하면 바로 다시 입력할 수 있습니다."
        }

        if isAutomation &&
            (dailyRemaining <= effectiveAutomationDailyReserve ||
             weeklyRemaining <= effectiveAutomationWeeklyReserve ||
             dailyUsagePercent >= 0.82 ||
             weeklyUsagePercent >= 0.82) {
            return "자동 보조 작업은 토큰 보호를 위해 잠시 제한되었습니다. \(protectionUsageSummary())"
        }

        return nil
    }

    func runningStopReason(isAutomation: Bool, currentTabTokens: Int, tokenLimit: Int) -> String? {
        if currentTabTokens >= tokenLimit {
            return "세션 토큰 한도에 도달해 자동 중단했습니다."
        }

        if dailyRemaining <= effectiveEmergencyDailyReserve ||
            weeklyRemaining <= effectiveEmergencyWeeklyReserve {
            return "전체 토큰 보호선을 넘겨 현재 작업을 중단했습니다. \(protectionUsageSummary())"
        }

        if isAutomation &&
            (dailyRemaining <= effectiveGlobalDailyReserve ||
             weeklyRemaining <= effectiveGlobalWeeklyReserve ||
             dailyUsagePercent >= 0.94 ||
             weeklyUsagePercent >= 0.94) {
            return "자동 보조 작업 토큰 보호선에 도달해 중단했습니다. \(protectionUsageSummary())"
        }

        return nil
    }

    // MARK: - Persistence

    private func scheduleSave(delay: TimeInterval = 0.75) {
        saveWorkItem?.cancel()
        let snapshot = history
        let key = saveKey
        let workItem = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        saveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let loaded = try? JSONDecoder().decode([DayRecord].self, from: data) else { return }
        // 최근 30일만 유지
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date())!
        history = loaded.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    func clearOldEntries() {
        let key = todayKey
        history = history.filter { $0.date == key }
        scheduleSave(delay: 0)
    }

    func clearAllEntries() {
        history.removeAll()
        saveWorkItem?.cancel()
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    func applyRecommendedMinimumLimits() {
        if dailyTokenLimit < Self.recommendedDailyLimit {
            dailyTokenLimit = Self.recommendedDailyLimit
        }
        if weeklyTokenLimit < Self.recommendedWeeklyLimit {
            weeklyTokenLimit = Self.recommendedWeeklyLimit
        }
    }

    func formatTokens(_ c: Int) -> String {
        if c >= 1_000_000 { return String(format: "%.1fM", Double(c) / 1_000_000) }
        if c >= 1000 { return String(format: "%.1fk", Double(c) / 1000) }
        return "\(c)"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Tab (이벤트 스트림 기반)
// ═══════════════════════════════════════════════════════

class TerminalTab: ObservableObject, Identifiable {
    private static let maxRetainedBlocks = 420
    private static let maxRetainedFileChanges = 240

    private struct ToolUseContext {
        let id: String
        let name: String
        let input: [String: Any]
        let preview: String
    }

    private struct PermissionDenialCandidate {
        let toolUseId: String?
        let toolName: String
        let toolInput: [String: Any]
        let message: String
    }

    let id: String
    @Published var projectName: String
    @Published var projectPath: String
    @Published var workerName: String
    @Published var workerColor: Color

    // 이벤트 스트림 (핵심!)
    @Published var blocks: [StreamBlock] = []
    @Published var isProcessing: Bool = false
    @Published var isRunning: Bool = true

    // Claude 설정
    @Published var selectedModel: ClaudeModel = .sonnet
    @Published var effortLevel: EffortLevel = .medium
    @Published var outputMode: OutputMode = .full

    // 상태
    @Published var claudeActivity: ClaudeActivity = .idle
    @Published var tokensUsed: Int = 0
    @Published var inputTokensUsed: Int = 0
    @Published var outputTokensUsed: Int = 0
    @Published var totalCost: Double = 0
    @Published var tokenLimit: Int = 45000
    @Published var isClaude: Bool = true
    @Published var isCompleted: Bool = false
    @Published var gitInfo = GitInfo()
    @Published var summary: SessionSummary?
    @Published var startError: String?
    @Published var approvalMode: ApprovalMode = .auto
    @Published var fileChanges: [FileChangeRecord] = []
    @Published var commandCount: Int = 0
    @Published var errorCount: Int = 0
    var readCommandCount: Int = 0
    @Published var pendingApproval: PendingApproval?
    @Published var lastResultText: String = ""
    @Published var lastPromptText: String = ""
    @Published var completedPromptCount: Int = 0
    @Published var parallelTasks: [ParallelTaskRecord] = []

    struct PendingApproval: Identifiable {
        let id = UUID()
        let command: String
        let reason: String
        var onApprove: (() -> Void)?
        var onDeny: (() -> Void)?
    }

    var detectedPid: Int?
    @Published var branch: String?
    @Published var sessionCount: Int = 1
    @Published var groupId: String?
    var startTime = Date()
    @Published var lastActivityTime = Date()

    // 3분 미활동 → 휴게실
    var isOnBreak: Bool { !isProcessing && Date().timeIntervalSince(lastActivityTime) > 180 }

    // Conversation continuity
    private var sessionId: String?
    private var currentProcess: Process?
    private var activeToolBlockIndex: Int?
    private var seenToolUseIds: Set<String> = []  // 중복 방지
    private var toolUseContexts: [String: ToolUseContext] = [:]
    private var pendingPermissionDenial: PermissionDenialCandidate?
    private var lastPermissionFingerprint: String?
    @Published var scrollTrigger: Int = 0          // 스크롤 트리거
    private var budgetStopIssued = false

    // Legacy compat
    var outputText: String { blocks.map { $0.content }.joined(separator: "\n") }
    var masterFD: Int32 = -1

    // ── Raw Terminal Mode (PTY) ──
    @Published var rawOutput: String = ""
    @Published var rawScrollTrigger: Int = 0
    var isRawMode: Bool = false
    private var rawMasterFD: Int32 = -1

    var initialPrompt: String?
    var characterId: String?  // CharacterRegistry 연동
    var automationSourceTabId: String?
    var automationReportPath: String?
    @Published var workflowSourceRequest: String = ""
    @Published var workflowPlanSummary: String = ""
    @Published var workflowDesignSummary: String = ""
    @Published var workflowReviewSummary: String = ""
    @Published var workflowQASummary: String = ""
    @Published var workflowSRESummary: String = ""
    @Published var officeSeatLockReason: String?
    @Published var workflowStages: [WorkflowStageRecord] = []
    @Published var reviewerAttemptCount: Int = 0
    @Published var qaAttemptCount: Int = 0
    @Published var automatedRevisionCount: Int = 0

    // ── 고급 CLI 옵션 ──
    @Published var permissionMode: PermissionMode = .bypassPermissions
    @Published var systemPrompt: String = ""
    @Published var maxBudgetUSD: Double = 0       // 0 = 무제한
    @Published var allowedTools: String = ""       // 쉼표 구분
    @Published var disallowedTools: String = ""    // 쉼표 구분
    @Published var additionalDirs: [String] = []
    @Published var continueSession: Bool = false   // --continue
    @Published var useWorktree: Bool = false        // --worktree

    // ── 추가 CLI 옵션 (v1.5) ──
    @Published var fallbackModel: String = ""          // --fallback-model
    @Published var sessionName: String = ""            // --name
    @Published var jsonSchema: String = ""             // --json-schema
    @Published var mcpConfigPaths: [String] = []       // --mcp-config
    @Published var customAgent: String = ""            // --agent
    @Published var customAgentsJSON: String = ""       // --agents (JSON)
    @Published var pluginDirs: [String] = []           // --plugin-dir
    @Published var customTools: String = ""            // --tools (빌트인 도구 제한)
    @Published var enableChrome: Bool = true           // --chrome
    @Published var forkSession: Bool = false           // --fork-session
    @Published var fromPR: String = ""                 // --from-pr
    @Published var enableBrief: Bool = false           // --brief
    @Published var tmuxMode: Bool = false              // --tmux
    @Published var strictMcpConfig: Bool = false       // --strict-mcp-config
    @Published var settingSources: String = ""         // --setting-sources
    @Published var settingsFileOrJSON: String = ""     // --settings
    @Published var betaHeaders: String = ""            // --betas

    // ── 세션 연속성 (--resume으로 멀티턴 유지) ──

    // ── 크롬 윈도우 캡처 ──
    @Published var chromeScreenshot: CGImage?

    init(id: String = UUID().uuidString, projectName: String, projectPath: String, workerName: String, workerColor: Color) {
        self.id = id; self.projectName = projectName; self.projectPath = projectPath
        self.workerName = workerName; self.workerColor = workerColor
    }

    private func sessionStartSummary(modelLabel: String? = nil) -> String {
        let resolvedModel = modelLabel.flatMap { ClaudeModel.detect(from: $0) } ?? selectedModel
        let resolvedLabel = modelLabel ?? resolvedModel.displayName
        return "\(resolvedModel.icon) \(resolvedLabel) · \(effortLevel.icon) \(effortLevel.rawValue) · v\(ClaudeInstallChecker.shared.version)"
    }

    private func sanitizeTerminalText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let ansiPattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
        return normalized
            .replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateReportedModel(_ reportedModel: String) {
        if let resolvedModel = ClaudeModel.detect(from: reportedModel) {
            selectedModel = resolvedModel
        }
        if let first = blocks.first, case .sessionStart = first.blockType {
            let displayLabel = ClaudeModel.detect(from: reportedModel)?.displayName ?? reportedModel
            first.content = sessionStartSummary(modelLabel: displayLabel)
        }
    }

    var persistedSessionId: String? { sessionId }

    func applySavedSessionConfiguration(_ saved: SavedSession) {
        if let raw = saved.selectedModel, let model = ClaudeModel(rawValue: raw) {
            selectedModel = model
        }
        if let raw = saved.effortLevel, let level = EffortLevel(rawValue: raw) {
            effortLevel = level
        }
        if let raw = saved.outputMode, let mode = OutputMode(rawValue: raw) {
            outputMode = mode
        }
        if let raw = saved.permissionMode, let mode = PermissionMode(rawValue: raw) {
            permissionMode = mode
        }

        tokenLimit = saved.tokenLimit ?? tokenLimit
        systemPrompt = saved.systemPrompt ?? ""
        maxBudgetUSD = saved.maxBudgetUSD ?? 0
        allowedTools = saved.allowedTools ?? ""
        disallowedTools = saved.disallowedTools ?? ""
        additionalDirs = saved.additionalDirs ?? []
        continueSession = saved.continueSession ?? false
        useWorktree = saved.useWorktree ?? false
        fallbackModel = saved.fallbackModel ?? ""
        sessionName = saved.sessionName ?? ""
        jsonSchema = saved.jsonSchema ?? ""
        mcpConfigPaths = saved.mcpConfigPaths ?? []
        customAgent = saved.customAgent ?? ""
        customAgentsJSON = saved.customAgentsJSON ?? ""
        pluginDirs = saved.pluginDirs ?? []
        customTools = saved.customTools ?? ""
        enableChrome = saved.enableChrome ?? true
        forkSession = saved.forkSession ?? false
        fromPR = saved.fromPR ?? ""
        enableBrief = saved.enableBrief ?? false
        tmuxMode = saved.tmuxMode ?? false
        strictMcpConfig = saved.strictMcpConfig ?? false
        settingSources = saved.settingSources ?? ""
        settingsFileOrJSON = saved.settingsFileOrJSON ?? ""
        betaHeaders = saved.betaHeaders ?? ""

        branch = saved.branch
        if let savedCharacterId = saved.characterId,
           let savedCharacter = CharacterRegistry.shared.character(with: savedCharacterId),
           savedCharacter.isHired,
           !savedCharacter.isOnVacation {
            characterId = savedCharacterId
        }
        if let savedSessionId = saved.sessionId, !savedSessionId.isEmpty {
            sessionId = savedSessionId
        }
    }

    func restoreSavedSessionSnapshot(_ saved: SavedSession) {
        tokensUsed = saved.tokensUsed
        inputTokensUsed = saved.inputTokensUsed ?? 0
        if let savedOutputTokens = saved.outputTokensUsed {
            outputTokensUsed = savedOutputTokens
        } else {
            outputTokensUsed = max(0, saved.tokensUsed - inputTokensUsed)
        }
        totalCost = saved.totalCost ?? 0
        commandCount = saved.commandCount ?? commandCount
        errorCount = saved.errorCount ?? errorCount
        completedPromptCount = saved.completedPromptCount ?? completedPromptCount
        lastResultText = saved.lastResultText ?? ""
        lastPromptText = saved.lastPrompt ?? ""
        fileChanges = saved.fileChanges?.map(\.fileChangeRecord) ?? []
        startTime = saved.startTime
        lastActivityTime = saved.lastActivityTime ?? saved.startTime
        initialPrompt = nil
        isCompleted = false
        isClaude = true
        isRunning = true
        startError = nil

        if let summaryFiles = saved.summaryFiles {
            summary = SessionSummary(
                filesModified: summaryFiles,
                duration: saved.summaryDuration ?? 0,
                tokenCount: saved.summaryTokens ?? saved.tokensUsed,
                cost: saved.totalCost ?? 0,
                lastLines: [],
                commandCount: saved.commandCount ?? 0,
                errorCount: saved.errorCount ?? 0,
                timestamp: saved.lastActivityTime ?? saved.startTime
            )
        }
    }

    func appendRestorationNotice(from saved: SavedSession, recoveryBundleURL: URL?) {
        var details: [String] = ["자동으로 다시 실행하지 않았습니다."]

        if let lastPrompt = saved.lastPrompt, !lastPrompt.isEmpty {
            details.append("마지막 입력: \(String(lastPrompt.prefix(180)))")
        } else if let initialPrompt = saved.initialPrompt, !initialPrompt.isEmpty {
            details.append("초기 입력: \(String(initialPrompt.prefix(180)))")
        }

        if let recoveryBundleURL {
            details.append("복구 폴더: \(recoveryBundleURL.path)")
        }

        if saved.sessionId != nil && (saved.continueSession ?? false) {
            details.append("다음 입력부터 이전 대화를 이어서 보낼 수 있습니다.")
        }

        let title = saved.wasProcessing == true ? "중단된 세션 복원" : "이전 세션 복원"
        appendBlock(.status(message: title), content: details.joined(separator: "\n"))
    }

    var workerState: WorkerState {
        if isCompleted { return .success }
        if isProcessing {
            switch claudeActivity {
            case .thinking: return .thinking
            case .reading: return .reading
            case .writing: return .writing
            case .searching: return .searching
            case .running: return .running
            case .done: return .success
            case .error: return .error
            case .idle: return .coding
            }
        }
        return sessionCount > 1 ? .pairing : .idle
    }

    // MARK: - Start

    func start() {
        isRunning = true; isClaude = true; startTime = Date()
        let checker = ClaudeInstallChecker.shared; checker.check()
        if !checker.isInstalled {
            appendBlock(.error(message: "Claude Code 미설치"), content: "npm install -g @anthropic-ai/claude-code")
            startError = "Claude Code not installed"
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .workmanClaudeNotInstalled, object: nil)
            }
            return
        }

        // Raw terminal mode: PTY 기반 인터랙티브 실행
        if AppSettings.shared.rawTerminalMode {
            startRawTerminal()
            return
        }

        appendBlock(.sessionStart(model: selectedModel.displayName, sessionId: ""),
                     content: sessionStartSummary())
        refreshGitInfo()

        // 초기 프롬프트가 있으면 자동 실행
        if let prompt = initialPrompt, !prompt.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendPrompt(prompt)
            }
        }
    }

    // MARK: - Raw Terminal (PTY)

    private func startRawTerminal() {
        isRawMode = true
        isProcessing = true
        claudeActivity = .running

        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0 else {
            appendBlock(.error(message: "PTY 생성 실패"), content: "posix_openpt failed")
            return
        }
        guard grantpt(master) == 0, unlockpt(master) == 0,
              let slaveNamePtr = ptsname(master) else {
            close(master)
            appendBlock(.error(message: "PTY 설정 실패"), content: "grantpt/unlockpt failed")
            return
        }
        let slaveName = String(cString: slaveNamePtr)
        let slave = open(slaveName, O_RDWR)
        guard slave >= 0 else {
            close(master)
            appendBlock(.error(message: "PTY slave 열기 실패"))
            return
        }

        // 터미널 크기 설정
        var ws = winsize(ws_row: 50, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(master, TIOCSWINSZ, &ws)

        rawMasterFD = master

        let path = FileManager.default.fileExists(atPath: projectPath) ? projectPath : NSHomeDirectory()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-f", "-c", "claude"]
        proc.currentDirectoryURL = URL(fileURLWithPath: path)
        proc.standardInput = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        proc.standardOutput = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        proc.standardError = FileHandle(fileDescriptor: slave, closeOnDealloc: false)

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.buildFullPATH()
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        proc.environment = env

        currentProcess = proc

        // master FD에서 읽기 (백그라운드)
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let bufferSize = 8192
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            while true {
                let bytesRead = Darwin.read(master, buffer, bufferSize)
                if bytesRead <= 0 { break }
                let data = Data(bytes: buffer, count: bytesRead)
                if let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.appendRawChunk(text)
                    }
                }
            }

            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.claudeActivity = .idle
            }
        }

        do {
            try proc.run()
            close(slave) // parent에서 slave 닫기
        } catch {
            close(slave)
            close(master)
            rawMasterFD = -1
            appendBlock(.error(message: "Claude 실행 실패"), content: error.localizedDescription)
        }
    }

    func writeRawInput(_ text: String) {
        guard rawMasterFD >= 0, let data = text.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = Darwin.write(rawMasterFD, base, ptr.count)
        }
    }

    func sendRawSignal(_ signal: UInt8) {
        guard rawMasterFD >= 0 else { return }
        var byte = signal
        Darwin.write(rawMasterFD, &byte, 1)
    }

    /// ANSI 코드를 보존하면서 \r 줄 덮어쓰기 처리
    private func appendRawChunk(_ text: String) {
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\r" {
                if i + 1 < chars.count && chars[i + 1] == "\n" {
                    rawOutput.append("\n")
                    i += 2
                } else {
                    // \r 단독: 현재 줄 시작으로 이동 (덮어쓰기)
                    if let lastNL = rawOutput.lastIndex(of: "\n") {
                        rawOutput = String(rawOutput[...lastNL])
                    } else {
                        rawOutput = ""
                    }
                    i += 1
                }
            } else {
                rawOutput.append(c)
                i += 1
            }
        }

        // 메모리 보호: 200KB 초과 시 줄 단위로 앞부분 제거
        if rawOutput.count > 200_000 {
            let cutTarget = rawOutput.count - 150_000
            if let cutIdx = rawOutput.index(rawOutput.startIndex, offsetBy: cutTarget, limitedBy: rawOutput.endIndex),
               let nlIdx = rawOutput[cutIdx...].firstIndex(of: "\n") {
                rawOutput = String(rawOutput[rawOutput.index(after: nlIdx)...])
            }
        }

        rawScrollTrigger += 1
    }

    // MARK: - Send Prompt (stream-json 이벤트 스트림)

    func sendPrompt(_ prompt: String, permissionOverride: PermissionMode? = nil, bypassWorkflowRouting: Bool = false) {
        guard !prompt.isEmpty else { return }

        // Raw terminal mode: PTY에 직접 전송
        if isRawMode {
            writeRawInput(prompt + "\n")
            return
        }

        if !bypassWorkflowRouting,
           permissionOverride == nil,
           SessionManager.shared.routePromptIfNeeded(for: self, prompt: prompt) {
            return
        }

        if !bypassWorkflowRouting, permissionOverride == nil {
            SessionManager.shared.prepareDirectDeveloperWorkflowIfNeeded(for: self, prompt: prompt)
        }

        guard !isProcessing else { return }

        if let reason = TokenTracker.shared.startBlockReason(isAutomation: isAutomationTab) {
            appendBlock(.status(message: "토큰 보호 모드"), content: reason)
            claudeActivity = .idle
            return
        }

        pendingApproval = nil
        pendingPermissionDenial = nil
        lastPermissionFingerprint = nil
        toolUseContexts.removeAll()
        parallelTasks.removeAll()
        isCompleted = false
        budgetStopIssued = false

        appendBlock(.userPrompt, content: prompt)
        initialPrompt = nil
        lastPromptText = prompt
        isProcessing = true
        claudeActivity = .thinking
        lastActivityTime = Date()

        let path = FileManager.default.fileExists(atPath: projectPath) ? projectPath : NSHomeDirectory()
        let effectivePermissionMode = permissionOverride ?? permissionMode

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var cmd = "claude -p --output-format stream-json --verbose"

            // 권한 모드
            cmd += " --permission-mode \(effectivePermissionMode.rawValue)"
            cmd += " --model \(self.selectedModel.rawValue)"
            cmd += " --effort \(self.effortLevel.rawValue)"

            // 세션 이어하기
            if self.continueSession && self.sessionId == nil {
                cmd += " --continue"
            } else if let sid = self.sessionId {
                cmd += " --resume \(self.shellEscape(sid))"
            }

            // 세션 이름
            if !self.sessionName.isEmpty {
                cmd += " --name \(self.shellEscape(self.sessionName))"
            }
            // 시스템 프롬프트
            if !self.systemPrompt.isEmpty {
                cmd += " --append-system-prompt \(self.shellEscape(self.systemPrompt))"
            }
            // 예산 제한
            if self.maxBudgetUSD > 0 {
                cmd += " --max-budget-usd \(String(format: "%.2f", self.maxBudgetUSD))"
            }
            // 대체 모델
            if !self.fallbackModel.isEmpty {
                cmd += " --fallback-model \(self.shellEscape(self.fallbackModel))"
            }
            // JSON 스키마
            if !self.jsonSchema.isEmpty {
                cmd += " --json-schema \(self.shellEscape(self.jsonSchema))"
            }
            // 도구 제한
            let effectiveAllowedTools = self.effectiveAllowedTools()
            if !effectiveAllowedTools.isEmpty {
                cmd += " --allowed-tools \(self.shellEscape(effectiveAllowedTools))"
            }
            let effectiveDisallowedTools = self.effectiveDisallowedTools()
            if !effectiveDisallowedTools.isEmpty {
                cmd += " --disallowed-tools \(self.shellEscape(effectiveDisallowedTools))"
            }
            // 빌트인 도구
            if !self.customTools.trimmingCharacters(in: .whitespaces).isEmpty {
                cmd += " --tools \(self.shellEscape(self.customTools.trimmingCharacters(in: .whitespaces)))"
            }
            // 추가 디렉토리
            for dir in self.additionalDirs where !dir.isEmpty {
                cmd += " --add-dir \(self.shellEscape(dir))"
            }
            // MCP 설정
            for mcpPath in self.mcpConfigPaths where !mcpPath.isEmpty {
                cmd += " --mcp-config \(self.shellEscape(mcpPath))"
            }
            if self.strictMcpConfig { cmd += " --strict-mcp-config" }
            // 에이전트
            if !self.customAgent.isEmpty {
                cmd += " --agent \(self.shellEscape(self.customAgent))"
            }
            if !self.customAgentsJSON.isEmpty {
                cmd += " --agents \(self.shellEscape(self.customAgentsJSON))"
            }
            // 플러그인
            for pluginDir in self.pluginDirs where !pluginDir.isEmpty {
                cmd += " --plugin-dir \(self.shellEscape(pluginDir))"
            }
            // 크롬
            if self.enableChrome { cmd += " --chrome" }
            // 워크트리
            if self.useWorktree { cmd += " --worktree" }
            if self.tmuxMode { cmd += " --tmux" }
            // 포크
            if self.forkSession { cmd += " --fork-session" }
            // PR
            if !self.fromPR.isEmpty { cmd += " --from-pr \(self.shellEscape(self.fromPR))" }
            // Brief
            if self.enableBrief { cmd += " --brief" }
            // 베타
            if !self.betaHeaders.isEmpty { cmd += " --betas \(self.shellEscape(self.betaHeaders))" }
            // 설정 소스
            if !self.settingSources.isEmpty { cmd += " --setting-sources \(self.shellEscape(self.settingSources))" }
            if !self.settingsFileOrJSON.isEmpty { cmd += " --settings \(self.shellEscape(self.settingsFileOrJSON))" }

            // 프롬프트
            cmd += " -- \(self.shellEscape(prompt))"

            let proc = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-f", "-c", cmd]
            proc.currentDirectoryURL = URL(fileURLWithPath: path)
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = Self.buildFullPATH()
            env["TERM"] = "dumb"; env["NO_COLOR"] = "1"
            proc.environment = env
            proc.standardOutput = outPipe
            proc.standardError = errPipe
            self.currentProcess = proc

            // stderr 캡처 (에러 진단용)
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let rawText = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    let text = self?.sanitizeTerminalText(rawText) ?? rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    // JSON 스트림이 아닌 진짜 에러만 표시
                    if !text.isEmpty && !text.hasPrefix("{") && !text.contains("node:") {
                        self?.appendBlock(.error(message: "stderr"), content: text)
                    }
                }
            }

            var jsonBuffer = ""
            let bufferQueue = DispatchQueue(label: "com.workman.jsonBuffer")

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                bufferQueue.sync {
                    jsonBuffer += chunk

                    while let nl = jsonBuffer.range(of: "\n") {
                        let line = String(jsonBuffer[jsonBuffer.startIndex..<nl.lowerBound])
                        jsonBuffer = String(jsonBuffer[nl.upperBound...])
                        guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                              let ld = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any] else { continue }

                        DispatchQueue.main.async { [weak self] in
                            self?.handleStreamEvent(json)
                        }
                    }
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.appendBlock(.error(message: error.localizedDescription))
                }
            }

            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentProcess = nil
                // result 이벤트에서 이미 isProcessing=false 했지만,
                // 프로세스가 비정상 종료한 경우만 여기서 처리
                if self.isProcessing {
                    self.isProcessing = false
                    self.claudeActivity = self.claudeActivity == .error ? .error : .done
                    self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
                }
                if let denial = self.pendingPermissionDenial, self.pendingApproval == nil {
                    self.presentPermissionApprovalIfNeeded(denial)
                }
            }
        }
    }

    // MARK: - Stream Event Handler (핵심 파서)

    private func handleStreamEvent(_ json: [String: Any]) {
        let type = json["type"] as? String ?? ""

        switch type {
        case "system":
            if let sid = json["session_id"] as? String { sessionId = sid }
            if let model = json["model"] as? String {
                updateReportedModel(model)
            }

        case "assistant":
            guard let msg = json["message"] as? [String: Any],
                  let content = msg["content"] as? [[String: Any]] else { return }

            // usage가 message 안에 있을 수도, 최상위에 있을 수도 있음
            let usageObj = msg["usage"] as? [String: Any] ?? json["usage"] as? [String: Any]
            if let usage = usageObj {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                // 3개 @Published를 개별 갱신하지 않고 한 번에 처리
                let newInput = inputTokensUsed + input
                let newOutput = outputTokensUsed + output
                inputTokensUsed = newInput
                outputTokensUsed = newOutput
                tokensUsed = newInput + newOutput
                TokenTracker.shared.recordTokens(input: input, output: output)
                enforceTokenBudgetIfNeeded()
            }

            for block in content {
                let blockType = block["type"] as? String ?? ""

                if blockType == "text" {
                    let text = block["text"] as? String ?? ""
                    if !text.isEmpty {
                        // Assistant response text is visible output, so the office actor
                        // should return to the workstation instead of lingering in a
                        // remote "thinking" spot.
                        claudeActivity = .writing
                        appendBlock(.thought, content: text)
                    }
                }
                else if blockType == "tool_use" {
                    // 중복 방지: tool_use ID로 이미 처리된 것은 스킵
                    let toolUseId = block["id"] as? String ?? UUID().uuidString
                    guard !seenToolUseIds.contains(toolUseId) else { continue }
                    seenToolUseIds.insert(toolUseId)

                    let toolName = block["name"] as? String ?? ""
                    let toolInput = block["input"] as? [String: Any] ?? [:]
                    let toolPreview = toolPreview(toolName: toolName, toolInput: toolInput)
                    toolUseContexts[toolUseId] = ToolUseContext(id: toolUseId, name: toolName, input: toolInput, preview: toolPreview)

                    switch toolName {
                    case "Bash":
                        claudeActivity = .running
                        commandCount += 1
                        let cmd = toolInput["command"] as? String ?? ""
                        let desc = toolInput["description"] as? String
                        let header = desc != nil ? "\(cmd)  // \(desc!)" : cmd
                        appendBlock(.toolUse(name: "Bash", input: cmd), content: header)
                    case "Read":
                        claudeActivity = .reading
                        let file = toolInput["file_path"] as? String ?? ""
                        appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
                        readCommandCount += 1
                        AchievementManager.shared.recordFileRead(sessionReadCount: readCommandCount)
                    case "Write":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        recordFileChange(path: file, action: "Write")
                        appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                        AchievementManager.shared.recordFileEdit()
                    case "Edit":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        recordFileChange(path: file, action: "Edit")
                        appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                        AchievementManager.shared.recordFileEdit()
                    case "Grep":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Grep", input: pattern), content: pattern)
                    case "Glob":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Glob", input: pattern), content: pattern)
                    case "Task":
                        claudeActivity = .thinking
                        let taskLabel = registerParallelTask(toolUseId: toolUseId, input: toolInput)
                        appendBlock(.toolUse(name: "Task", input: taskLabel), content: taskLabel)
                    default:
                        appendBlock(.toolUse(name: toolName, input: ""), content: toolPreview.isEmpty ? toolName : toolPreview)
                    }

                    activeToolBlockIndex = blocks.count - 1
                }
            }

        case "user":
            handleUserToolResult(json)

        case "result":
            let cost = json["total_cost_usd"] as? Double ?? 0
            let duration = json["duration_ms"] as? Int ?? 0
            let resultText = json["result"] as? String ?? ""
            let permissionDenials = json["permission_denials"] as? [[String: Any]] ?? []
            totalCost += cost
            TokenTracker.shared.recordCost(cost)

            // result 이벤트에서 토큰 파싱 — total_*를 우선 사용 (이중 카운팅 방지)
            let hasTotals = json["total_input_tokens"] as? Int != nil
            if hasTotals,
               let totalInput = json["total_input_tokens"] as? Int,
               let totalOutput = json["total_output_tokens"] as? Int {
                // 권위적 전체 값 → 현재 누적과의 차이만 TokenTracker에 기록
                let diffIn = max(0, totalInput - inputTokensUsed)
                let diffOut = max(0, totalOutput - outputTokensUsed)
                if diffIn > 0 || diffOut > 0 {
                    TokenTracker.shared.recordTokens(input: diffIn, output: diffOut)
                }
                inputTokensUsed = totalInput
                outputTokensUsed = totalOutput
                tokensUsed = totalInput + totalOutput
                enforceTokenBudgetIfNeeded()
            } else if let usage = json["usage"] as? [String: Any] {
                // total_*가 없을 때만 증분 usage 사용
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                if input > 0 || output > 0 {
                    inputTokensUsed += input
                    outputTokensUsed += output
                    tokensUsed = inputTokensUsed + outputTokensUsed
                    TokenTracker.shared.recordTokens(input: input, output: output)
                    enforceTokenBudgetIfNeeded()
                }
            }

            if let sid = json["session_id"] as? String { sessionId = sid }
            if let latestDenial = permissionDenials.last {
                pendingPermissionDenial = permissionDenialCandidate(from: latestDenial)
            }

            appendBlock(.completion(cost: cost, duration: duration),
                        content: "완료")

            // 즉시 완료 상태로 전환 (프로세스 종료 기다리지 않음)
            isProcessing = false
            claudeActivity = .done
            lastResultText = resultText
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            generateSummary()
            seenToolUseIds.removeAll()
            if let denial = pendingPermissionDenial {
                presentPermissionApprovalIfNeeded(denial)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.claudeActivity == .done { self?.claudeActivity = .idle }
            }

            if permissionDenials.isEmpty {
                sendCompletionNotification()
                NotificationCenter.default.post(
                    name: .workmanTabCycleCompleted,
                    object: self,
                    userInfo: [
                        "tabId": id,
                        "completedPromptCount": completedPromptCount,
                        "resultText": resultText
                    ]
                )
            }

        default:
            break
        }
    }

    private func handleUserToolResult(_ json: [String: Any]) {
        let toolUseId = extractToolUseId(from: json)

        if let result = json["tool_use_result"] as? [String: Any] {
            let stdout = result["stdout"] as? String ?? ""
            let stderr = result["stderr"] as? String ?? ""
            let interrupted = result["interrupted"] as? Bool ?? false
            let isError = (result["is_error"] as? Bool) ?? isToolResultError(from: json)
            let cleanedStdout = sanitizeTerminalText(stdout)
            let cleanedStderr = sanitizeTerminalText(stderr)

            if !cleanedStdout.isEmpty {
                appendBlock(.toolOutput, content: cleanedStdout)
            }
            if !cleanedStderr.isEmpty {
                errorCount += 1
                appendBlock(.toolError, content: cleanedStderr)
            } else if isError, let message = extractToolResultText(from: json) {
                let cleanedMessage = sanitizeTerminalText(message)
                errorCount += 1
                appendBlock(.toolError, content: cleanedMessage)
                recordPermissionDenialIfNeeded(message: cleanedMessage, toolUseId: toolUseId)
            }

            if interrupted {
                appendBlock(.toolEnd(success: false), content: "중단됨")
            } else {
                appendBlock(.toolEnd(success: !isError))
            }

            if let toolUseId {
                updateParallelTask(toolUseId: toolUseId, succeeded: !isError && !interrupted)
            }

            activeToolBlockIndex = nil
            return
        }

        if let message = extractToolResultText(from: json) {
            let cleanedMessage = sanitizeTerminalText(message)
            let isError = isToolResultError(from: json) || cleanedMessage.lowercased().contains("error:")
            if isError {
                errorCount += 1
                appendBlock(.toolError, content: cleanedMessage)
                recordPermissionDenialIfNeeded(message: cleanedMessage, toolUseId: toolUseId)
                appendBlock(.toolEnd(success: false))
            } else if !cleanedMessage.isEmpty {
                appendBlock(.toolOutput, content: cleanedMessage)
                appendBlock(.toolEnd(success: true))
            }

            if let toolUseId {
                updateParallelTask(toolUseId: toolUseId, succeeded: !isError)
            }

            activeToolBlockIndex = nil
        }
    }

    private func extractToolUseId(from json: [String: Any]) -> String? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }
        return content.first(where: { ($0["type"] as? String) == "tool_result" })?["tool_use_id"] as? String
    }

    private func extractToolResultText(from json: [String: Any]) -> String? {
        if let raw = json["tool_use_result"] as? String {
            return cleanedToolResultText(raw)
        }

        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }

        for item in content where (item["type"] as? String) == "tool_result" {
            if let text = item["content"] as? String {
                return cleanedToolResultText(text)
            }
        }
        return nil
    }

    private func isToolResultError(from json: [String: Any]) -> Bool {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return false }
        return content.contains {
            ($0["type"] as? String) == "tool_result" && (($0["is_error"] as? Bool) ?? false)
        }
    }

    private func cleanedToolResultText(_ text: String) -> String {
        text.replacingOccurrences(of: "^Error:\\s*", with: "", options: .regularExpression)
    }

    private func recordPermissionDenialIfNeeded(message: String, toolUseId: String?) {
        guard isPermissionDenialMessage(message) else { return }

        let context = toolUseId.flatMap { toolUseContexts[$0] }
        pendingPermissionDenial = PermissionDenialCandidate(
            toolUseId: toolUseId,
            toolName: context?.name ?? "Tool",
            toolInput: context?.input ?? [:],
            message: message
        )
    }

    private func permissionDenialCandidate(from denial: [String: Any]) -> PermissionDenialCandidate {
        let toolUseId = denial["tool_use_id"] as? String
        let context = toolUseId.flatMap { toolUseContexts[$0] }
        let toolName = denial["tool_name"] as? String ?? context?.name ?? "Tool"
        let toolInput = denial["tool_input"] as? [String: Any] ?? context?.input ?? [:]
        let message = pendingPermissionDenial?.message
            ?? permissionDenialMessage(toolName: toolName, toolInput: toolInput)
            ?? "Claude requested permissions to use \(toolName), but you haven't granted it yet."

        return PermissionDenialCandidate(
            toolUseId: toolUseId,
            toolName: toolName,
            toolInput: toolInput,
            message: message
        )
    }

    private func presentPermissionApprovalIfNeeded(_ denial: PermissionDenialCandidate) {
        let command = approvalCommandText(for: denial)
        let fingerprint = [denial.toolName, command].joined(separator: "|")
        guard pendingApproval == nil, lastPermissionFingerprint != fingerprint else { return }

        let retryMode = retryPermissionMode(for: denial.toolName)
        let retrySummary = retryMode == .acceptEdits
            ? "이번 한 번만 수정 권한으로 재시도합니다."
            : "이번 한 번만 전체 권한으로 재시도합니다."

        lastPermissionFingerprint = fingerprint
        pendingApproval = PendingApproval(
            command: command,
            reason: "\(approvalReasonPrefix(for: denial.toolName)) 권한이 필요합니다. 승인하면 \(retrySummary)",
            onApprove: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: "권한 승인됨 · 다시 시도합니다"))
                self?.sendPrompt(self?.approvalRetryPrompt(for: denial.toolName) ?? "Permission granted. Please continue the previous task.", permissionOverride: retryMode)
            },
            onDeny: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: "권한 요청이 거부되었습니다"))
            }
        )
    }

    private func retryPermissionMode(for toolName: String) -> PermissionMode {
        switch toolName {
        case "Write", "Edit", "NotebookEdit":
            return .acceptEdits
        default:
            return .bypassPermissions
        }
    }

    private func approvalRetryPrompt(for toolName: String) -> String {
        switch retryPermissionMode(for: toolName) {
        case .acceptEdits:
            return "Permission granted. You may now make the required file edits. Please continue the previous task."
        default:
            return "Permission granted. You may now use the required tool. Please continue the previous task."
        }
    }

    private func approvalReasonPrefix(for toolName: String) -> String {
        switch toolName {
        case "Write", "Edit", "NotebookEdit":
            return "파일 수정"
        case "Bash":
            return "명령 실행"
        case "WebFetch":
            return "웹 가져오기"
        case "WebSearch":
            return "웹 검색"
        default:
            return toolName
        }
    }

    private func approvalCommandText(for denial: PermissionDenialCandidate) -> String {
        let detail = toolPreview(toolName: denial.toolName, toolInput: denial.toolInput)
        if detail.isEmpty {
            return denial.message
        }
        return "\(denial.toolName) · \(detail)"
    }

    private func permissionDenialMessage(toolName: String, toolInput: [String: Any]) -> String? {
        switch toolName {
        case "Write", "Edit", "NotebookEdit":
            if let filePath = toolInput["file_path"] as? String {
                return "Claude requested permissions to write to \(filePath), but you haven't granted it yet."
            }
        case "Bash":
            if let command = toolInput["command"] as? String {
                return "Claude requested permissions to run \(command), but you haven't granted it yet."
            }
        case "WebFetch":
            return "Claude requested permissions to use WebFetch, but you haven't granted it yet."
        case "WebSearch":
            return "Claude requested permissions to use WebSearch, but you haven't granted it yet."
        default:
            return "Claude requested permissions to use \(toolName), but you haven't granted it yet."
        }
        return nil
    }

    private func isPermissionDenialMessage(_ message: String) -> Bool {
        message.lowercased().contains("requested permissions")
    }

    private func toolPreview(toolName: String, toolInput: [String: Any]) -> String {
        switch toolName {
        case "Bash":
            return toolInput["command"] as? String ?? ""
        case "Read", "Write", "Edit", "NotebookEdit":
            return toolInput["file_path"] as? String ?? ""
        case "Grep", "Glob":
            return toolInput["pattern"] as? String ?? ""
        case "Task":
            return parallelTaskLabel(from: toolInput)
        case "WebFetch":
            return toolInput["url"] as? String ?? ""
        case "WebSearch":
            return toolInput["query"] as? String ?? ""
        default:
            return ""
        }
    }

    private func registerParallelTask(toolUseId: String, input: [String: Any]) -> String {
        let label = parallelTaskLabel(from: input)
        let assigneeId = parallelTaskAssigneeId(seed: toolUseId)

        if let index = parallelTasks.firstIndex(where: { $0.id == toolUseId }) {
            parallelTasks[index].state = .running
            return parallelTasks[index].label
        }

        parallelTasks.append(
            ParallelTaskRecord(
                id: toolUseId,
                label: label,
                assigneeCharacterId: assigneeId,
                state: .running
            )
        )
        return label
    }

    private func updateParallelTask(toolUseId: String, succeeded: Bool) {
        guard let index = parallelTasks.firstIndex(where: { $0.id == toolUseId }) else { return }
        parallelTasks[index].state = succeeded ? .completed : .failed
    }

    private func finalizeParallelTasks(as state: ParallelTaskState) {
        guard parallelTasks.contains(where: { $0.state == .running }) else { return }
        parallelTasks = parallelTasks.map { task in
            guard task.state == .running else { return task }
            var updated = task
            updated.state = state
            return updated
        }
    }

    private func parallelTaskLabel(from input: [String: Any]) -> String {
        let candidates: [String?] = [
            input["description"] as? String,
            input["subtask"] as? String,
            input["title"] as? String,
            input["name"] as? String,
            input["prompt"] as? String
        ]

        for candidate in candidates {
            guard let candidate else { continue }
            let cleaned = candidate
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return String(cleaned.prefix(18))
            }
        }

        return "병렬 작업"
    }

    private func parallelTaskAssigneeId(seed: String) -> String {
        let registry = CharacterRegistry.shared
        let preferredPool = registry.hiredCharacters.filter {
            !$0.isOnVacation && $0.id != characterId
        }
        let pool = preferredPool

        guard !pool.isEmpty else {
            return characterId ?? "parallel-\(id)"
        }

        let alreadyUsed = Set(parallelTasks.map(\.assigneeCharacterId))
        let available = pool.filter { !alreadyUsed.contains($0.id) }
        let effectivePool = available.isEmpty ? pool : available
        let hash = abs(seed.hashValue)
        return effectivePool[hash % effectivePool.count].id
    }

    // MARK: - Block Management

    @discardableResult
    func appendBlock(_ type: StreamBlock.BlockType, content: String = "") -> StreamBlock {
        let block = StreamBlock(type: type, content: content)
        blocks.append(block)
        trimBlocksIfNeeded()
        return block
    }

    var isAutomationTab: Bool {
        automationSourceTabId != nil
    }

    func cancelProcessing() {
        if isRawMode {
            // Raw mode: Ctrl+C 전송
            sendRawSignal(3) // ETX (Ctrl+C)
            return
        }
        currentProcess?.terminate(); currentProcess = nil
        isProcessing = false; claudeActivity = .idle
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: "취소됨"))
    }

    func forceStop() {
        // Raw mode PTY 정리
        if isRawMode && rawMasterFD >= 0 {
            close(rawMasterFD)
            rawMasterFD = -1
            isRawMode = false
        }
        if let proc = currentProcess, proc.isRunning {
            proc.terminate()
            let pid = proc.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if proc.isRunning { kill(pid, SIGKILL) }
            }
        }
        currentProcess = nil
        isProcessing = false; claudeActivity = .idle; isRunning = false
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: "강제 중지됨"))
    }

    /// 작업을 강제 중지하고 git 변경사항을 작업 전 상태로 롤백
    func cancelAndRevert() {
        forceStop()
        let recoveryBundleURL = SessionStore.shared.writeRecoveryBundle(for: self, reason: "작업 취소 전 변경사항 백업")
        guard gitInfo.isGitRepo else { return }
        let p = projectPath
        // 작업 중 변경된 파일만 복원
        let changedPaths = Set(fileChanges.map(\.path))
        for filePath in changedPaths {
            _ = Self.shellSync("git -C \"\(p)\" checkout -- \"\(filePath)\" 2>/dev/null")
        }
        // 새로 생성된 파일 (Write action) 삭제
        let newFiles = fileChanges.filter { $0.action == "Write" }.map(\.path)
        for filePath in newFiles {
            _ = Self.shellSync("git -C \"\(p)\" clean -f -- \"\(filePath)\" 2>/dev/null")
        }
        if let recoveryBundleURL {
            appendBlock(.status(message: "작업 취소 및 변경사항 롤백 완료"), content: "백업 폴더: \(recoveryBundleURL.path)")
        } else {
            appendBlock(.status(message: "작업 취소 및 변경사항 롤백 완료"))
        }
    }

    func clearBlocks() { blocks.removeAll() }

    private func trimBlocksIfNeeded() {
        let overflow = blocks.count - Self.maxRetainedBlocks
        guard overflow > 0 else { return }

        let preserveSessionStart: Bool
        if let first = blocks.first, case .sessionStart = first.blockType {
            preserveSessionStart = true
        } else {
            preserveSessionStart = false
        }

        let removalStart = preserveSessionStart ? 1 : 0
        let removableCount = min(overflow, max(0, blocks.count - removalStart))
        guard removableCount > 0 else { return }

        let removalEnd = removalStart + removableCount
        blocks.removeSubrange(removalStart..<removalEnd)

        if let activeToolBlockIndex {
            if activeToolBlockIndex < removalEnd {
                self.activeToolBlockIndex = nil
            } else {
                self.activeToolBlockIndex = activeToolBlockIndex - removableCount
            }
        }
    }

    private func recordFileChange(path: String, action: String) {
        let record = FileChangeRecord(
            path: path,
            fileName: (path as NSString).lastPathComponent,
            action: action,
            timestamp: Date()
        )

        if let last = fileChanges.last,
           last.path == record.path,
           last.action == record.action {
            fileChanges[fileChanges.count - 1] = record
        } else {
            fileChanges.append(record)
        }

        let overflow = fileChanges.count - Self.maxRetainedFileChanges
        if overflow > 0 {
            fileChanges.removeFirst(overflow)
        }
    }

    // Legacy compat
    func send(_ text: String) { sendPrompt(text) }
    func sendCommand(_ command: String) { sendPrompt(command) }
    func sendKey(_ key: UInt8) { if key == 3 { cancelProcessing() } }
    func stop() { cancelProcessing(); isRunning = false }

    // MARK: - Notifications

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(workerName) — \(projectName) 완료"

        let elapsed = Int(Date().timeIntervalSince(startTime))
        let timeStr: String
        if elapsed < 60 { timeStr = "\(elapsed)초" }
        else if elapsed < 3600 { timeStr = "\(elapsed / 60)분 \(elapsed % 60)초" }
        else { timeStr = "\(elapsed / 3600)시간 \((elapsed % 3600) / 60)분" }

        let fileCount = Set(fileChanges.map(\.fileName)).count
        var details: [String] = []
        details.append("⏱ \(timeStr)")
        if totalCost > 0 { details.append("💰 $\(String(format: "%.4f", totalCost))") }
        if tokensUsed > 0 { details.append("🔤 \(tokensUsed >= 1000 ? String(format: "%.1fk", Double(tokensUsed)/1000) : "\(tokensUsed)") tokens") }
        if fileCount > 0 { details.append("📄 \(fileCount)개 파일 수정") }
        if commandCount > 0 { details.append("⚙ \(commandCount)개 명령") }
        if errorCount > 0 { details.append("⚠ \(errorCount)개 에러") }

        content.body = details.joined(separator: " · ")
        content.sound = .default
        content.categoryIdentifier = "SESSION_COMPLETE"

        if gitInfo.isGitRepo && !gitInfo.branch.isEmpty {
            content.subtitle = "🌿 \(gitInfo.branch)"
        }

        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        NSSound(named: "Glass")?.play()
    }

    // MARK: - Git Info

    func refreshGitInfo() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let p = self.projectPath
            let br = Self.shellSync("git -C \"\(p)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ch = Self.shellSync("git -C \"\(p)\" status --porcelain 2>/dev/null")?.components(separatedBy: "\n").filter { !$0.isEmpty }.count ?? 0
            let log = Self.shellSync("git -C \"\(p)\" log -1 --format='%s|||%cr' 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
            var msg = ""; var age = ""
            if let l = log { let pp = l.components(separatedBy: "|||"); if pp.count >= 2 { msg = pp[0]; age = pp[1] } }
            DispatchQueue.main.async {
                self.gitInfo = GitInfo(branch: br, changedFiles: ch, lastCommit: String(msg.prefix(40)), lastCommitAge: age, isGitRepo: !br.isEmpty)
                self.branch = br
            }
        }
    }

    func generateSummary() {
        let files = blocks.compactMap { b -> String? in
            if case .fileChange(let path, _) = b.blockType { return (path as NSString).lastPathComponent }
            return nil
        }
        summary = SessionSummary(filesModified: Array(Set(files)), duration: Date().timeIntervalSince(startTime),
                                 tokenCount: tokensUsed, cost: totalCost, commandCount: commandCount, errorCount: errorCount, timestamp: Date())
    }

    func exportLog() -> URL? {
        let name = "\(projectName)_\(DateFormatter.localizedString(from: startTime, dateStyle: .short, timeStyle: .short)).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        var s = "# \(projectName) Session\n\n"
        for b in blocks {
            switch b.blockType {
            case .userPrompt: s += "\n## ❯ \(b.content)\n\n"
            case .thought: s += "\(b.content)\n\n"
            case .toolUse(let name, _): s += "⏺ **\(name)**(`\(b.content)`)\n"
            case .toolOutput: s += "```\n\(b.content)\n```\n"
            case .toolError: s += "⚠️ ```\n\(b.content)\n```\n"
            case .completion: s += "\n---\n✅ \(b.content)\n"
            default: s += "\(b.content)\n"
            }
        }
        try? s.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func shellEscape(_ str: String) -> String { "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func effectiveAllowedTools() -> String {
        let raw = allowedTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if shouldBlockParallelSubagents {
            return raw.filter { $0.caseInsensitiveCompare("Task") != .orderedSame }.joined(separator: ",")
        }
        return raw.joined(separator: ",")
    }

    private func effectiveDisallowedTools() -> String {
        var raw = disallowedTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if shouldBlockParallelSubagents &&
            !raw.contains(where: { $0.caseInsensitiveCompare("Task") == .orderedSame }) {
            raw.append("Task")
        }

        return raw.joined(separator: ",")
    }

    private var shouldBlockParallelSubagents: Bool {
        isAutomationTab || !AppSettings.shared.allowParallelSubagents
    }

    private func enforceTokenBudgetIfNeeded() {
        guard isProcessing, !budgetStopIssued else { return }
        guard let reason = TokenTracker.shared.runningStopReason(
            isAutomation: isAutomationTab,
            currentTabTokens: tokensUsed,
            tokenLimit: tokenLimit
        ) else { return }

        budgetStopIssued = true
        currentProcess?.terminate()
        currentProcess = nil
        isProcessing = false
        claudeActivity = .error
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: "토큰 보호로 중단"), content: reason)
    }

    /// GUI 앱에서도 claude CLI를 찾을 수 있도록 PATH를 완전히 구성
    static func buildFullPATH() -> String {
        let home = NSHomeDirectory()
        var paths: [String] = []

        // Homebrew (Apple Silicon + Intel)
        paths += ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]

        // npm global 설치 경로들
        paths += ["/usr/local/opt/node/bin", home + "/.npm-global/bin"]

        // nvm 설치 경로 — glob 직접 해결
        let nvmBase = home + "/.nvm/versions/node"
        if let nodeDirs = try? FileManager.default.contentsOfDirectory(atPath: nvmBase) {
            for dir in nodeDirs.sorted().reversed() {
                let binPath = nvmBase + "/" + dir + "/bin"
                if FileManager.default.fileExists(atPath: binPath) {
                    paths.append(binPath)
                }
            }
        }

        // fnm 설치 경로
        let fnmBase = home + "/Library/Application Support/fnm/node-versions"
        if let fnmDirs = try? FileManager.default.contentsOfDirectory(atPath: fnmBase) {
            for dir in fnmDirs.sorted().reversed() {
                let binPath = fnmBase + "/" + dir + "/installation/bin"
                if FileManager.default.fileExists(atPath: binPath) {
                    paths.append(binPath)
                }
            }
        }

        // volta
        paths.append(home + "/.volta/bin")

        // pnpm
        paths.append(home + "/Library/pnpm")
        paths.append(home + "/.local/share/pnpm")

        // 일반적인 경로들
        paths += [home + "/.local/bin", home + "/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

        // 기존 PATH 유지
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
        if !existing.isEmpty { paths.append(existing) }

        return paths.joined(separator: ":")
    }

    static func shellSync(_ command: String) -> String? {
        let p = Process(); let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-f", "-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = buildFullPATH()
        p.environment = env
        do { try p.run(); p.waitUntilExit()
            let d = pipe.fileHandleForReading.readDataToEndOfFile()
            let o = String(data: d, encoding: .utf8); return o?.isEmpty == true ? nil : o
        } catch { return nil }
    }

    // MARK: - Chrome Window Capture (ScreenCaptureKit)

    static func captureBrowserWindow() async -> CGImage? {
        // Check screen recording permission before attempting capture
        // to avoid repeatedly triggering the system permission dialog
        guard CGPreflightScreenCaptureAccess() else { return nil }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let browserApps = ["Google Chrome", "Arc", "Safari", "Microsoft Edge", "Firefox", "Brave Browser"]

            // 브라우저 윈도우 찾기
            for window in content.windows {
                guard let app = window.owningApplication,
                      browserApps.contains(app.applicationName),
                      window.frame.width > 200 && window.frame.height > 200 else { continue }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = Int(window.frame.width / 4)   // 축소 (성능)
                config.height = Int(window.frame.height / 4)
                config.capturesAudio = false
                config.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                return image
            }
        } catch {
            // 권한 없거나 에러 → 무시
        }
        return nil
    }
}

extension TerminalTab {
    var assignedCharacter: WorkerCharacter? {
        CharacterRegistry.shared.character(with: characterId)
    }

    var workerJob: WorkerJob {
        assignedCharacter?.jobRole ?? .developer
    }

    var isWorkerOnVacation: Bool {
        assignedCharacter?.isOnVacation ?? false
    }

    var hasCodeChanges: Bool {
        fileChanges.contains { $0.action == "Write" || $0.action == "Edit" }
    }

    var latestUserPromptText: String? {
        blocks.reversed().first {
            if case .userPrompt = $0.blockType { return true }
            return false
        }?.content
    }

    var workflowRequirementText: String {
        let source = workflowSourceRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty { return source }
        return latestUserPromptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var lastCompletionSummary: String {
        lastResultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resetWorkflowTracking(request: String) {
        workflowSourceRequest = request
        workflowPlanSummary = ""
        workflowDesignSummary = ""
        workflowReviewSummary = ""
        workflowQASummary = ""
        workflowSRESummary = ""
        automationReportPath = nil
        workflowStages.removeAll()
        reviewerAttemptCount = 0
        qaAttemptCount = 0
        automatedRevisionCount = 0
    }

    func upsertWorkflowStage(
        role: WorkerJob,
        workerName: String,
        assigneeCharacterId: String?,
        state: WorkflowStageState,
        handoffLabel: String,
        detail: String
    ) {
        let effectiveAssignee = assigneeCharacterId ?? characterId ?? "workflow-\(role.rawValue)-\(id)"
        let stageId = role.rawValue
        if let index = workflowStages.firstIndex(where: { $0.id == stageId }) {
            workflowStages[index].workerName = workerName
            workflowStages[index].assigneeCharacterId = effectiveAssignee
            workflowStages[index].state = state
            workflowStages[index].handoffLabel = handoffLabel
            workflowStages[index].detail = detail
            workflowStages[index].updatedAt = Date()
            return
        }

        workflowStages.append(
            WorkflowStageRecord(
                id: stageId,
                role: role,
                workerName: workerName,
                assigneeCharacterId: effectiveAssignee,
                state: state,
                handoffLabel: handoffLabel,
                detail: detail,
                updatedAt: Date()
            )
        )
    }

    func updateWorkflowStage(
        role: WorkerJob,
        state: WorkflowStageState,
        detail: String? = nil,
        handoffLabel: String? = nil
    ) {
        guard let index = workflowStages.firstIndex(where: { $0.role == role }) else { return }
        workflowStages[index].state = state
        if let detail {
            workflowStages[index].detail = detail
        }
        if let handoffLabel {
            workflowStages[index].handoffLabel = handoffLabel
        }
        workflowStages[index].updatedAt = Date()
    }

    private func workflowStageOrder(for role: WorkerJob) -> Int {
        switch role {
        case .planner: return 0
        case .designer: return 1
        case .developer: return 2
        case .reviewer: return 3
        case .qa: return 4
        case .reporter: return 5
        case .sre: return 6
        case .boss: return 7
        }
    }

    var workflowTimelineStages: [WorkflowStageRecord] {
        workflowStages.sorted { lhs, rhs in
            let lhsOrder = workflowStageOrder(for: lhs.role)
            let rhsOrder = workflowStageOrder(for: rhs.role)
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.updatedAt < rhs.updatedAt
        }
    }

    private var workflowBubbleTasks: [ParallelTaskRecord] {
        let visibleStages = workflowTimelineStages.filter { $0.state != .skipped }
        guard !visibleStages.isEmpty else { return [] }

        let active = visibleStages.filter { $0.state == .running || $0.state == .failed }
        let completed = visibleStages
            .filter { $0.state == .completed }
            .sorted { $0.updatedAt > $1.updatedAt }
        let queued = visibleStages.filter { $0.state == .queued }

        let ordered = active + completed + queued
        return Array(ordered.prefix(4)).map { stage in
            let parallelState: ParallelTaskState
            switch stage.state {
            case .failed:
                parallelState = .failed
            case .completed:
                parallelState = .completed
            case .queued, .running, .skipped:
                parallelState = .running
            }
            return ParallelTaskRecord(
                id: "workflow-\(stage.id)",
                label: stage.workerName,
                assigneeCharacterId: stage.assigneeCharacterId,
                state: parallelState
            )
        }
    }

    var officeParallelTasks: [ParallelTaskRecord] {
        let workflowTasks = workflowBubbleTasks
        if workflowTasks.isEmpty {
            return Array(parallelTasks.prefix(4))
        }

        let extraTasks = parallelTasks.filter { task in
            !workflowTasks.contains(where: { $0.assigneeCharacterId == task.assigneeCharacterId && $0.label == task.label })
        }
        return Array((workflowTasks + extraTasks).prefix(4))
    }

    var workflowProgressSummary: String? {
        guard !workflowStages.isEmpty else { return nil }

        if let running = workflowTimelineStages.last(where: { $0.state == .running }) {
            return "\(running.role.displayName) 진행 중 · \(running.workerName)"
        }
        if let failed = workflowTimelineStages.last(where: { $0.state == .failed }) {
            return "\(failed.role.displayName) 피드백 반영 중"
        }
        if let completed = workflowTimelineStages.last(where: { $0.state == .completed }) {
            return "\(completed.role.displayName) 완료"
        }
        if let queued = workflowTimelineStages.last(where: { $0.state == .queued }) {
            return "\(queued.role.displayName) 대기 중"
        }
        return nil
    }

    var officeParallelSummary: String? {
        if let workflowSummary = workflowProgressSummary {
            return workflowSummary
        }

        guard !parallelTasks.isEmpty else { return nil }
        let completed = parallelTasks.filter { $0.state == .completed }.count
        let failed = parallelTasks.filter { $0.state == .failed }.count
        let running = parallelTasks.filter { $0.state == .running }.count

        if running > 0 {
            return "병렬 \(completed)/\(parallelTasks.count) 완료"
        }
        if failed > 0 {
            return "병렬 \(failed)개 실패"
        }
        return "병렬 작업 완료"
    }
}
