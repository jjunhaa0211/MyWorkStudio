import SwiftUI
import DesignSystem

extension TerminalTab {
    // MARK: - Block Management

    private func shouldMergeBlock(existing: StreamBlock.BlockType, new: StreamBlock.BlockType) -> Bool {
        switch (existing, new) {
        case (.toolOutput, .toolOutput), (.toolError, .toolError):
            return true
        default:
            return false
        }
    }

    @discardableResult
    public func appendBlock(_ type: StreamBlock.BlockType, content: String = "") -> StreamBlock {
        // toolEnd가 오면 직전 toolUse 블록을 완료 처리
        if case .toolEnd = type {
            if let toolIdx = blocks.lastIndex(where: {
                if case .toolUse = $0.blockType { return true }
                return false
            }), !blocks[toolIdx].isComplete {
                blocks[toolIdx].isComplete = true
            }
        }

        if let lastIndex = blocks.indices.last,
           !blocks[lastIndex].isComplete,
           shouldMergeBlock(existing: blocks[lastIndex].blockType, new: type),
           blocks[lastIndex].content.count < 50000 {  // Prevent unbounded growth
            blocks[lastIndex].content += "\n" + content
            return blocks[lastIndex]
        }
        let block = StreamBlock(type: type, content: content)
        blocks.append(block)
        trimBlocksIfNeeded()
        return block
    }

    public var isAutomationTab: Bool {
        automationSourceTabId != nil
    }

    public func cancelProcessing() {
        if isRawMode {
            // Raw mode: Ctrl+C 전송 + 상태 리셋
            sendRawSignal(3) // ETX (Ctrl+C)
            isProcessing = false
            claudeActivity = .idle
            return
        }

        // 1) 먼저 프로세스를 취소 목록에 등록하고 종료 시그널을 보낸 후
        // 2) 파이프 핸들러를 정리합니다.
        // 순서가 중요: 핸들러를 먼저 nil로 만들면 핸들러 콜백이 아직 실행 중일 때
        // procId 검증 없이 접근하게 될 수 있습니다.
        if let proc = currentProcess {
            let pid = proc.processIdentifier
            let procId = ObjectIdentifier(proc)
            cancelledProcessIds.insert(procId)

            // SIGTERM 먼저 전송
            proc.terminate()

            // 1초 후 SIGKILL 후속 (forceStop과 동일 패턴)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if proc.isRunning {
                    kill(-pid, SIGKILL)
                    kill(pid, SIGKILL)
                }
            }
        }

        // 프로세스 취소 등록 후 파이프 핸들러 정리
        currentOutPipe?.fileHandleForReading.readabilityHandler = nil
        currentErrPipe?.fileHandleForReading.readabilityHandler = nil
        currentOutPipe = nil
        currentErrPipe = nil

        currentProcess = nil
        isProcessing = false; claudeActivity = .idle
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: NSLocalizedString("tab.cancelled", comment: "")))
    }

    public func startSleepWork(task: String, tokenBudget: Int?) {
        sleepWorkTask = task
        sleepWorkTokenBudget = tokenBudget
        sleepWorkStartTokens = tokensUsed
        sleepWorkCompleted = false
        sleepWorkExceeded = false
        AuditLog.shared.log(.sleepWorkStart, tabId: id, projectName: projectName, detail: "\(NSLocalizedString("models.budget.label", comment: "")): \(tokenBudget.map { "\($0) tokens" } ?? NSLocalizedString("models.budget.unlimited", comment: ""))")
        sendPrompt(task)
    }

    public func forceStop() {
        // Raw mode PTY 정리
        if isRawMode && rawMasterFD >= 0 {
            close(rawMasterFD)
            rawMasterFD = -1
            isRawMode = false
        }

        // 파이프 핸들러 즉시 정리
        currentOutPipe?.fileHandleForReading.readabilityHandler = nil
        currentErrPipe?.fileHandleForReading.readabilityHandler = nil
        currentOutPipe = nil
        currentErrPipe = nil

        if let proc = currentProcess {
            let procId = ObjectIdentifier(proc)
            cancelledProcessIds.insert(procId)

            if proc.isRunning {
                proc.terminate()
                let pid = proc.processIdentifier
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    if proc.isRunning {
                        // 프로세스 그룹 전체에 SIGKILL (자식 프로세스 포함)
                        kill(-pid, SIGKILL)
                        kill(pid, SIGKILL)
                    }
                }
            }
        }
        currentProcess = nil
        isProcessing = false; claudeActivity = .idle; isRunning = false
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: NSLocalizedString("tab.force.stopped", comment: "")))
    }

    /// 작업을 강제 중지하고 git 변경사항을 작업 전 상태로 롤백
    public func cancelAndRevert() {
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
            appendBlock(.status(message: NSLocalizedString("tab.cancel.revert.done", comment: "")), content: String(format: NSLocalizedString("tab.cancel.revert.backup", comment: ""), recoveryBundleURL.path))
        } else {
            appendBlock(.status(message: NSLocalizedString("tab.cancel.revert.done", comment: "")))
        }
    }

    public func clearBlocks() { blocks.removeAll() }

    // MARK: - 프롬프트 히스토리 (되돌리기)

    func finalizePromptHistory() {
        guard !promptHistory.isEmpty else { return }
        let lastIndex = promptHistory.count - 1
        let changesForThisPrompt = Array(fileChanges.suffix(from: min(pendingHistoryFileChangeStartIndex, fileChanges.count)))
        promptHistory[lastIndex].fileChanges = changesForThisPrompt
        promptHistory[lastIndex].isCompleted = true
        // 히스토리 100개 제한
        if promptHistory.count > 100 {
            promptHistory.removeFirst(promptHistory.count - 100)
        }
        objectWillChange.send()
    }

    public func revertToBeforePrompt(_ entry: PromptHistoryEntry) {
        guard let commitHash = entry.gitCommitHashBefore, gitInfo.isGitRepo else {
            appendBlock(.status(message: NSLocalizedString("history.no.git.diff", comment: "")))
            return
        }
        let p = projectPath
        let escapedHash = shellEscape(commitHash)
        for file in entry.fileChanges where file.action == "Write" || file.action == "Edit" {
            _ = Self.shellSync("git -C \"\(p)\" checkout \(escapedHash) -- \(shellEscape(file.path)) 2>/dev/null")
        }
        // 새로 생성된 파일 삭제
        let newFiles = entry.fileChanges.filter { $0.action == "Write" }
        for file in newFiles {
            _ = Self.shellSync("git -C \"\(p)\" clean -f -- \(shellEscape(file.path)) 2>/dev/null")
        }
        appendBlock(.status(message: NSLocalizedString("history.reverted", comment: "")))
        refreshGitInfo()
    }

    public func loadDiffForHistoryEntry(_ entry: PromptHistoryEntry) -> String {
        guard let before = entry.gitCommitHashBefore else {
            // git 커밋이 없으면 변경된 파일 목록만 반환
            if entry.fileChanges.isEmpty { return NSLocalizedString("history.no.git.diff", comment: "") }
            return entry.fileChanges.map { "\($0.action): \($0.path)" }.joined(separator: "\n")
        }
        let p = projectPath
        // 현재 워킹 트리와 before 커밋 사이의 diff (인젝션 방지)
        let escapedHash = shellEscape(before)
        let escapedPaths = entry.fileChanges.map { shellEscape($0.path) }.joined(separator: " ")
        let diff = Self.shellSync("git -C \"\(p)\" diff \(escapedHash) -- \(escapedPaths) 2>/dev/null")
        if let diff = diff, !diff.isEmpty { return diff }
        // diff가 비어있으면 파일 목록 반환
        if entry.fileChanges.isEmpty { return NSLocalizedString("history.no.git.diff", comment: "") }
        return entry.fileChanges.map { "\($0.action): \($0.path)" }.joined(separator: "\n")
    }

    private static let maxTimelineEvents = 500

    func trimTimelineIfNeeded() {
        if timeline.count > Self.maxTimelineEvents {
            timeline.removeFirst(timeline.count - Self.maxTimelineEvents)
        }
    }

    func trimBlocksIfNeeded() {
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

    func recordFileChange(path: String, action: String) {
        let record = FileChangeRecord(
            path: path,
            fileName: (path as NSString).lastPathComponent,
            action: action,
            timestamp: Date()
        )

        let lastIndex = fileChanges.count - 1
        if lastIndex >= 0,
           fileChanges[lastIndex].path == record.path,
           fileChanges[lastIndex].action == record.action {
            fileChanges[lastIndex] = record
        } else {
            fileChanges.append(record)
        }

        let overflow = fileChanges.count - Self.maxRetainedFileChanges
        if overflow > 0 {
            fileChanges.removeFirst(overflow)
        }
    }

    // Legacy compat
    public func send(_ text: String) { sendPrompt(text) }
    public func sendCommand(_ command: String) { sendPrompt(command) }
    public func sendKey(_ key: UInt8) { if key == 3 { cancelProcessing() } }
    public func stop() { cancelProcessing(); isRunning = false }

}
