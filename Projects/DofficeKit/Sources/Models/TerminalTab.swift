import SwiftUI
import Darwin
import UserNotifications
import ScreenCaptureKit
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Tab (이벤트 스트림 기반)
// ═══════════════════════════════════════════════════════

public class TerminalTab: ObservableObject, Identifiable {
    static let maxRetainedBlocks = 420
    static let maxRetainedFileChanges = 240
    /// Pre-compiled ANSI escape regex for sanitizeTerminalText (avoid per-call recompilation).
    private static let ansiRegex: NSRegularExpression? = {
        do {
            return try NSRegularExpression(pattern: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]")
        } catch {
            CrashLogger.shared.error("ANSI regex compilation failed: \(error.localizedDescription)")
            return nil
        }
    }()

    /// Decoupled character lookup (set by App layer to bridge CharacterRegistry)
    public static var characterLookup: ((String) -> WorkerCharacter?) = { _ in nil }
    /// Decoupled hired-characters provider (set by App layer to bridge CharacterRegistry)
    public static var hiredCharactersProvider: (() -> [WorkerCharacter]) = { [] }

    struct ToolUseContext {
        let id: String
        let name: String
        let input: [String: Any]
        let preview: String
    }

    struct PermissionDenialCandidate {
        let toolUseId: String?
        let toolName: String
        let toolInput: [String: Any]
        let message: String
    }

    struct QueuedPromptRequest {
        let prompt: String
        let permissionOverride: PermissionMode?
        let bypassWorkflowRouting: Bool
        let presentationStyle: StreamBlock.PresentationStyle
        let appendUserBlock: Bool
    }

    public let id: String
    public var projectName: String
    public var projectPath: String
    @Published public var workerName: String
    @Published public var workerColor: Color

    // 이벤트 스트림 (핵심!)
    // blocks는 스트림 중 초당 수십 회 변경되므로 @Published 대신 수동 throttle 적용
    public var blocks: [StreamBlock] = []
    private var blockUpdateThrottleTimer: Timer?
    private var blockUpdatePending = false
    private var lastBlockNotifyTime: CFAbsoluteTime = 0

    /// 블록 변경을 UI에 반영 — 스트리밍 중에는 최대 10fps로 throttle
    /// - Important: 반드시 메인 스레드에서 호출해야 합니다.
    public func notifyBlocksChanged() {
        dispatchPrecondition(condition: .onQueue(.main))
        if isProcessing {
            blockUpdatePending = true
            if blockUpdateThrottleTimer == nil {
                blockUpdateThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if self.blockUpdatePending {
                        self.blockUpdatePending = false
                        self.lastBlockNotifyTime = CFAbsoluteTimeGetCurrent()
                        self.objectWillChange.send()
                    }
                }
            }
        } else {
            blockUpdateThrottleTimer?.invalidate()
            blockUpdateThrottleTimer = nil
            blockUpdatePending = false
            lastBlockNotifyTime = CFAbsoluteTimeGetCurrent()
            objectWillChange.send()
        }
    }

    @Published public var isProcessing: Bool = false {
        didSet {
            if !isProcessing {
                // 프로세싱 종료 시 마지막 블록 업데이트 flush + 타이머 정리
                blockUpdateThrottleTimer?.invalidate()
                blockUpdateThrottleTimer = nil
                if blockUpdatePending {
                    blockUpdatePending = false
                    objectWillChange.send()
                }
            }
        }
    }
    @Published public var isRunning: Bool = true

    // 모델/CLI 설정
    @Published public var selectedModel: ClaudeModel = .sonnet
    @Published public var effortLevel: EffortLevel = .medium
    @Published public var outputMode: OutputMode = .full
    @Published public var codexSandboxMode: CodexSandboxMode = .workspaceWrite
    @Published public var codexApprovalPolicy: CodexApprovalPolicy = .onRequest

    // 상태
    @Published public var claudeActivity: ClaudeActivity = .idle
    @Published public var tokensUsed: Int = 0
    public var inputTokensUsed: Int = 0
    public var outputTokensUsed: Int = 0
    public var totalCost: Double = 0
    @Published public var tokenLimit: Int = 0  // 0 = 무제한 (사용자 설정으로 관리)
    @Published public var isClaude: Bool = true
    @Published public var isCompleted: Bool = false
    @Published public var gitInfo = GitInfo()
    @Published public var summary: SessionSummary?
    @Published public var startError: String?
    @Published public var approvalMode: ApprovalMode = .auto
    public var fileChanges: [FileChangeRecord] = []
    public var commandCount: Int = 0
    public var errorCount: Int = 0
    public var readCommandCount: Int = 0
    @Published public var pendingApproval: PendingApproval?
    @Published public var lastResultText: String = ""

    // 보안 경고
    @Published public var dangerousCommandWarning: String?
    @Published public var sensitiveFileWarning: String?

    // 슬립워크
    @Published public var sleepWorkTask: String?
    @Published public var sleepWorkTokenBudget: Int?
    @Published public var sleepWorkStartTokens: Int = 0
    @Published public var sleepWorkCompleted: Bool = false
    @Published public var sleepWorkExceeded: Bool = false  // 2x budget exceeded
    @Published public var lastPromptText: String = ""
    @Published public var attachedImages: [URL] = []  // 첨부된 이미지 경로들
    @Published public var completedPromptCount: Int = 0
    @Published public var parallelTasks: [ParallelTaskRecord] = []
    public var promptHistory: [PromptHistoryEntry] = []
    var pendingHistoryPreHash: String?
    var pendingHistoryFileChangeStartIndex: Int = 0

    // 세션 타임라인
    public struct TimelineEvent: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let type: TimelineEventType
        public let detail: String
    }

    public enum TimelineEventType: String {
        case started, prompt, toolUse, fileChange, error, completed

        public var displayName: String {
            switch self {
            case .started: return NSLocalizedString("timeline.event.started", comment: "")
            case .prompt: return NSLocalizedString("timeline.event.prompt", comment: "")
            case .toolUse: return NSLocalizedString("timeline.event.toolUse", comment: "")
            case .fileChange: return NSLocalizedString("timeline.event.fileChange", comment: "")
            case .error: return NSLocalizedString("timeline.event.error", comment: "")
            case .completed: return NSLocalizedString("timeline.event.completed", comment: "")
            }
        }
    }

    public var timeline: [TimelineEvent] = []

    public struct PendingApproval: Identifiable {
        public let id = UUID()
        public let command: String
        public let reason: String
        public var onApprove: (() -> Void)?
        public var onDeny: (() -> Void)?
    }

    public var detectedPid: Int?
    @Published public var branch: String?
    @Published public var sessionCount: Int = 1
    @Published public var groupId: String?
    public var startTime = Date()
    @Published public var lastActivityTime = Date()

    // 3분 미활동 → 휴게실
    public var isOnBreak: Bool { !isProcessing && Date().timeIntervalSince(lastActivityTime) > 180 }

    // Conversation continuity
    var sessionId: String?
    var sessionProvider: AgentProvider?  // provider that created the sessionId
    var currentProcess: Process?
    var currentOutPipe: Pipe?
    var currentErrPipe: Pipe?
    var cancelledProcessIds: Set<ObjectIdentifier> = []
    var activeToolBlockIndex: Int?
    var seenToolUseIds: Set<String> = []  // 중복 방지
    var toolUseContexts: [String: ToolUseContext] = [:]
    var pendingPermissionDenial: PermissionDenialCandidate?
    var lastPermissionFingerprint: String?
    var activeResponsePresentationStyle: StreamBlock.PresentationStyle = .normal
    var queuedPromptRequests: [QueuedPromptRequest] = []
    @Published public var scrollTrigger: Int = 0          // 스크롤 트리거
    var budgetStopIssued = false

    // Legacy compat
    public var outputText: String { blocks.map { $0.content }.joined(separator: "\n") }
    public var masterFD: Int32 = -1

    // ── Raw Terminal Mode (PTY) ──
    @Published public var rawOutput: String = ""
    @Published public var rawScrollTrigger: Int = 0
    @Published public var isRawMode: Bool = false
    var rawMasterFD: Int32 = -1
    public let vt100 = VT100Terminal(rows: 50, cols: 120)

    public var initialPrompt: String?
    public var characterId: String?  // CharacterRegistry 연동
    public var automationSourceTabId: String?
    public var automationReportPath: String?
    public var manualLaunch: Bool = false
    public var workflowSourceRequest: String = ""
    public var workflowPlanSummary: String = ""
    public var workflowDesignSummary: String = ""
    public var workflowReviewSummary: String = ""
    public var workflowQASummary: String = ""
    public var workflowSRESummary: String = ""
    public var officeSeatLockReason: String?
    public var workflowStages: [WorkflowStageRecord] = []
    public var reviewerAttemptCount: Int = 0
    public var qaAttemptCount: Int = 0
    public var automatedRevisionCount: Int = 0

    // ── 고급 CLI 옵션 ──
    @Published public var permissionMode: PermissionMode = .bypassPermissions
    public var systemPrompt: String = ""
    public var maxBudgetUSD: Double = 0       // 0 = 무제한
    public var allowedTools: String = ""       // 쉼표 구분
    public var disallowedTools: String = ""    // 쉼표 구분
    public var additionalDirs: [String] = []
    public var continueSession: Bool = false   // --continue
    public var useWorktree: Bool = false        // --worktree

    // ── 추가 CLI 옵션 (v1.5) ──
    public var fallbackModel: String = ""          // --fallback-model
    public var sessionName: String = ""            // --name
    public var jsonSchema: String = ""             // --json-schema
    public var mcpConfigPaths: [String] = []       // --mcp-config
    public var customAgent: String = ""            // --agent
    public var customAgentsJSON: String = ""       // --agents (JSON)
    public var pluginDirs: [String] = []           // --plugin-dir
    public var customTools: String = ""            // --tools (빌트인 도구 제한)
    public var enableChrome: Bool = true           // --chrome
    public var forkSession: Bool = false           // --fork-session
    public var fromPR: String = ""                 // --from-pr
    public var enableBrief: Bool = false           // --brief
    public var tmuxMode: Bool = false              // --tmux
    public var strictMcpConfig: Bool = false       // --strict-mcp-config
    public var settingSources: String = ""         // --setting-sources
    public var settingsFileOrJSON: String = ""     // --settings
    public var betaHeaders: String = ""            // --betas

    // ── 세션 연속성 (--resume으로 멀티턴 유지) ──

    // ── 브라우저 탭 모드 ──
    @Published public var isBrowserTab: Bool = false
    @Published public var browserURL: String = ""

    // ── 크롬 윈도우 캡처 ──
    public var chromeScreenshot: CGImage?

    public init(id: String = UUID().uuidString, projectName: String, projectPath: String, workerName: String, workerColor: Color) {
        self.id = id; self.projectName = projectName; self.projectPath = projectPath
        self.workerName = workerName; self.workerColor = workerColor
    }

    deinit {
        currentProcess?.terminate()
        currentProcess = nil
        chromeScreenshot = nil
        if rawMasterFD >= 0 {
            close(rawMasterFD)
            rawMasterFD = -1
        }
    }

    public var provider: AgentProvider { selectedModel.provider }

    func sessionStartSummary(modelLabel: String? = nil) -> String {
        let resolvedModel = modelLabel.flatMap { ClaudeModel.detect(from: $0) } ?? selectedModel
        let resolvedLabel = modelLabel ?? resolvedModel.displayName
        let version = resolvedModel.provider.installChecker.version
        switch resolvedModel.provider {
        case .claude:
            return "\(resolvedModel.icon) \(resolvedLabel) · \(effortLevel.icon) \(effortLevel.rawValue) · v\(version)"
        case .codex:
            return "\(resolvedModel.icon) \(resolvedLabel) · \(codexSandboxMode.icon) \(codexSandboxMode.shortLabel) · \(codexApprovalPolicy.icon) \(codexApprovalPolicy.shortLabel) · v\(version)"
        case .gemini:
            return "\(resolvedModel.icon) \(resolvedLabel) · v\(version)"
        }
    }

    func sanitizeTerminalText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if let regex = Self.ansiRegex {
            let range = NSRange(normalized.startIndex..., in: normalized)
            let cleaned = regex.stringByReplacingMatches(in: normalized, range: range, withTemplate: "")
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Fallback: original behavior if regex compilation failed
        let ansiPattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
        return normalized
            .replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateReportedModel(_ reportedModel: String) {
        if let resolvedModel = ClaudeModel.detect(from: reportedModel) {
            selectedModel = resolvedModel
        }
        if !blocks.isEmpty, case .sessionStart = blocks[0].blockType {
            let displayLabel = ClaudeModel.detect(from: reportedModel)?.displayName ?? reportedModel
            blocks[0].content = sessionStartSummary(modelLabel: displayLabel)
        }
    }

    public var persistedSessionId: String? { sessionId }

    public func applySavedSessionConfiguration(_ saved: SavedSession) {
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
        if let raw = saved.codexSandboxMode, let mode = CodexSandboxMode(rawValue: raw) {
            codexSandboxMode = mode
        }
        if let raw = saved.codexApprovalPolicy, let mode = CodexApprovalPolicy(rawValue: raw) {
            codexApprovalPolicy = mode
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
           let savedCharacter = Self.characterLookup(savedCharacterId),
           savedCharacter.isHired,
           !savedCharacter.isOnVacation {
            characterId = savedCharacterId
        }
        if let savedSessionId = saved.sessionId, !savedSessionId.isEmpty {
            sessionId = savedSessionId
        }
    }

    public func restoreSavedSessionSnapshot(_ saved: SavedSession) {
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
        isClaude = selectedModel.provider == .claude
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

        // 대화 내역 복원 (최근 100개 블록)
        if let chatHistory = saved.chatHistory, !chatHistory.isEmpty {
            let restoredBlocks = chatHistory.map { $0.toBlock() }
            blocks.append(contentsOf: restoredBlocks)
        }
    }

    public func appendRestorationNotice(from saved: SavedSession, recoveryBundleURL: URL?) {
        var details: [String] = [NSLocalizedString("tab.restore.not.rerun", comment: "")]

        if let lastPrompt = saved.lastPrompt, !lastPrompt.isEmpty {
            details.append(String(format: NSLocalizedString("tab.restore.last.input", comment: ""), String(lastPrompt.prefix(180))))
        } else if let initialPrompt = saved.initialPrompt, !initialPrompt.isEmpty {
            details.append(String(format: NSLocalizedString("tab.restore.initial.input", comment: ""), String(initialPrompt.prefix(180))))
        }

        if let recoveryBundleURL {
            details.append(String(format: NSLocalizedString("tab.restore.recovery.folder", comment: ""), recoveryBundleURL.path))
        }

        if saved.sessionId != nil && (saved.continueSession ?? false) {
            details.append(NSLocalizedString("tab.restore.continue.hint", comment: ""))
        }

        let title = saved.wasProcessing == true ? NSLocalizedString("tab.restore.interrupted", comment: "") : NSLocalizedString("tab.restore.previous", comment: "")
        appendBlock(.status(message: title), content: details.joined(separator: "\n"))
    }

    public var workerState: WorkerState {
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

}
