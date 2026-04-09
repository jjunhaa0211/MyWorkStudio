import SwiftUI
import ScreenCaptureKit
import DesignSystem

extension TerminalTab {
    // MARK: - Chrome Window Capture (ScreenCaptureKit)

    public static func captureBrowserWindow() async -> CGImage? {
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
    public var statusPresentation: TabStatusPresentation {
        if startError != nil || claudeActivity == .error {
            return TabStatusPresentation(category: .attention, label: NSLocalizedString("status.error", comment: ""), symbol: "exclamationmark.triangle.fill", tint: Theme.red, sortPriority: 0)
        }
        if isCompleted {
            return TabStatusPresentation(category: .completed, label: NSLocalizedString("status.completed", comment: ""), symbol: "checkmark.circle.fill", tint: Theme.green, sortPriority: 3)
        }
        if isProcessing {
            switch claudeActivity {
            case .thinking:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.thinking", comment: ""), symbol: "brain.head.profile", tint: Theme.purple, sortPriority: 1)
            case .reading:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.reading", comment: ""), symbol: "book.fill", tint: Theme.accent, sortPriority: 1)
            case .writing:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.writing", comment: ""), symbol: "square.and.pencil", tint: Theme.green, sortPriority: 1)
            case .searching:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.searching", comment: ""), symbol: "magnifyingglass", tint: Theme.cyan, sortPriority: 1)
            case .running:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.running", comment: ""), symbol: "terminal.fill", tint: Theme.yellow, sortPriority: 1)
            case .done:
                return TabStatusPresentation(category: .completed, label: NSLocalizedString("status.completed", comment: ""), symbol: "checkmark.circle.fill", tint: Theme.green, sortPriority: 3)
            case .error:
                return TabStatusPresentation(category: .attention, label: NSLocalizedString("status.error", comment: ""), symbol: "exclamationmark.triangle.fill", tint: Theme.red, sortPriority: 0)
            case .idle:
                return TabStatusPresentation(category: .active, label: NSLocalizedString("status.active", comment: ""), symbol: "bolt.circle.fill", tint: Theme.green.opacity(0.85), sortPriority: 2)
            }
        }
        if isRunning {
            return TabStatusPresentation(category: .active, label: NSLocalizedString("status.waiting", tableName: nil, bundle: .main, comment: ""), symbol: "pause.circle.fill", tint: Theme.green.opacity(0.75), sortPriority: 2)
        }
        return TabStatusPresentation(category: .idle, label: NSLocalizedString("status.idle", comment: ""), symbol: "moon.zzz.fill", tint: Theme.textDim, sortPriority: 4)
    }

    public var sidebarSearchTokens: String {
        [
            projectName,
            projectPath,
            workerName,
            branch ?? "",
            statusPresentation.label,
            claudeActivity.rawValue,
            gitInfo.branch
        ]
        .joined(separator: " ")
        .lowercased()
    }

    public var assignedCharacter: WorkerCharacter? {
        Self.characterLookup(characterId ?? "")
    }

    public var workerJob: WorkerJob {
        assignedCharacter?.jobRole ?? .developer
    }

    public var isWorkerOnVacation: Bool {
        assignedCharacter?.isOnVacation ?? false
    }

    /// 현재 진행 중인 자동화 역할 정보 (기획자, 리뷰어, QA 등)
    public var activeAutomationStage: WorkflowStageRecord? {
        workflowStages.first(where: { $0.state == .running })
    }

    /// 자동화가 진행 중인지 여부 (소스 탭이 자동화 대기 상태)
    public var isAwaitingAutomation: Bool {
        officeSeatLockReason != nil || activeAutomationStage != nil
    }

    public var hasCodeChanges: Bool {
        fileChanges.contains { $0.action == "Write" || $0.action == "Edit" }
    }

    public var latestUserPromptText: String? {
        blocks.reversed().first {
            if case .userPrompt = $0.blockType { return true }
            return false
        }?.content
    }

    public var workflowRequirementText: String {
        let source = workflowSourceRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty { return source }
        return latestUserPromptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public var lastCompletionSummary: String {
        lastResultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func resetWorkflowTracking(request: String) {
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

    public func upsertWorkflowStage(
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

    public func updateWorkflowStage(
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

    public var workflowTimelineStages: [WorkflowStageRecord] {
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

    public var officeParallelTasks: [ParallelTaskRecord] {
        let workflowTasks = workflowBubbleTasks
        if workflowTasks.isEmpty {
            return Array(parallelTasks.prefix(4))
        }

        let extraTasks = parallelTasks.filter { task in
            !workflowTasks.contains(where: { $0.assigneeCharacterId == task.assigneeCharacterId && $0.label == task.label })
        }
        return Array((workflowTasks + extraTasks).prefix(4))
    }

    public var workflowProgressSummary: String? {
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

    public var officeParallelSummary: String? {
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
