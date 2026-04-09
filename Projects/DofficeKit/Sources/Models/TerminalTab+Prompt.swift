import SwiftUI
import DesignSystem

extension TerminalTab {
    // MARK: - Start

    public func start() {
        isRunning = true; startTime = Date()

        // Provider별 세션 토큰 한도 적용
        let settings = AppSettings.shared
        switch provider {
        case .claude: if settings.claudeSessionTokenLimit > 0 { tokenLimit = settings.claudeSessionTokenLimit }
        case .codex: if settings.codexSessionTokenLimit > 0 { tokenLimit = settings.codexSessionTokenLimit }
        case .gemini: if settings.geminiSessionTokenLimit > 0 { tokenLimit = settings.geminiSessionTokenLimit }
        }

        // Raw terminal mode: SwiftTerm이 자체 관리
        if AppSettings.shared.rawTerminalMode {
            if !isRawMode { // 이미 raw 모드면 재시작 안 함
                // 이전 Claude 프로세스가 남아있으면 정리
                currentProcess?.terminate()
                currentProcess = nil
                isProcessing = false
                claudeActivity = .idle
                isClaude = false
                startRawTerminal()
            }
            return
        }

        // raw → normal 전환 시 상태 정리
        if isRawMode {
            isRawMode = false
            isProcessing = false
            claudeActivity = .idle
        }
        isClaude = provider == .claude

        let checker = provider.installChecker
        checker.check()
        if !checker.isInstalled {
            appendBlock(.error(message: provider.installTitle), content: provider.installDetail)
            startError = "\(provider.displayName) CLI not installed"
            isRunning = false
            if provider == .claude {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dofficeClaudeNotInstalled, object: nil)
                }
            }
            return
        }

        appendBlock(.sessionStart(model: selectedModel.displayName, sessionId: ""),
                     content: sessionStartSummary())
        timeline.append(TimelineEvent(timestamp: Date(), type: .started, detail: projectName))
        refreshGitInfo()

        // 초기 프롬프트가 있으면 자동 실행
        if let prompt = initialPrompt, !prompt.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendPrompt(prompt)
            }
        }
    }

    // MARK: - Raw Terminal (PTY)

    /// Raw terminal mode: SwiftTerm이 PTY를 관리하므로 상태만 설정
    private func startRawTerminal() {
        isRawMode = true
        isProcessing = false
        claudeActivity = .idle
        // PTY 생성/프로세스 실행은 SwiftTermContainer에서 처리
    }

    public func writeRawInput(_ text: String) {}
    public func sendRawSignal(_ signal: UInt8) {}
    public func updatePTYWindowSize(cols: UInt16, rows: UInt16) {}

    // MARK: - Send Prompt (stream-json 이벤트 스트림)

    public func sendPrompt(
        _ prompt: String,
        permissionOverride: PermissionMode? = nil,
        bypassWorkflowRouting: Bool = false,
        presentationStyle: StreamBlock.PresentationStyle = .normal,
        appendUserBlock: Bool = true
    ) {
        guard !prompt.isEmpty else { return }
        PluginHost.shared.fireEvent(.onPromptSubmit)

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

        // isProcessing 상태 복구: 프로세스 없이 stuck된 경우 자동 리셋
        if isProcessing {
            let hasNoProcess = currentProcess == nil || !(currentProcess?.isRunning ?? false)
            let staleTimeout: TimeInterval = 30
            let isStale = Date().timeIntervalSince(lastActivityTime) > staleTimeout
            if hasNoProcess && isStale {
                CrashLogger.shared.warning("TerminalTab: isProcessing stuck without running process — auto-resetting (tab=\(id))")
                isProcessing = false
                claudeActivity = .idle
                currentProcess = nil
            } else {
                return
            }
        }

        // Apply presentation style for this prompt cycle
        activeResponsePresentationStyle = presentationStyle

        // 이전 프로세스 및 취소 상태 정리
        cancelledProcessIds.removeAll()
        if let prev = currentProcess, prev.isRunning {
            currentOutPipe?.fileHandleForReading.readabilityHandler = nil
            currentErrPipe?.fileHandleForReading.readabilityHandler = nil
            currentOutPipe = nil
            currentErrPipe = nil
            prev.terminate()
            currentProcess = nil
        }

        if let reason = TokenTracker.shared.startBlockReason(isAutomation: isAutomationTab) {
            appendBlock(.status(message: NSLocalizedString("tab.token.protection", comment: "")), content: reason)
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

        // 프로바이더 변경 시 이전 세션 ID 무효화 (Claude ↔ Codex ↔ Gemini 전환)
        if let prevProvider = sessionProvider, prevProvider != provider {
            sessionId = nil
            sessionProvider = nil
        }

        if appendUserBlock {
            appendBlock(.userPrompt, content: prompt, presentationStyle: presentationStyle)
        }
        timeline.append(TimelineEvent(timestamp: Date(), type: .prompt, detail: String(prompt.prefix(50)) + (prompt.count > 50 ? "..." : "")))
        trimTimelineIfNeeded()
        initialPrompt = nil
        lastPromptText = prompt
        isProcessing = true
        claudeActivity = .thinking
        lastActivityTime = Date()

        // 히스토리 스냅샷: 프롬프트 전 git 상태 캡처
        pendingHistoryFileChangeStartIndex = fileChanges.count
        let projPath = projectPath
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let hash = Self.shellSync("git -C \"\(projPath)\" rev-parse HEAD 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.pendingHistoryPreHash = (hash?.isEmpty ?? true) ? nil : hash
                let entry = PromptHistoryEntry(
                    timestamp: Date(),
                    promptText: prompt,
                    gitCommitHashBefore: self.pendingHistoryPreHash
                )
                self.promptHistory.append(entry)
                // promptHistory는 @Published가 아니므로 별도 알림 불필요
                // isProcessing/claudeActivity 변경 시 자연 갱신됨
            }
        }

        let path = FileManager.default.fileExists(atPath: projectPath) ? projectPath : NSHomeDirectory()
        let effectivePermissionMode = permissionOverride ?? permissionMode

        if provider == .codex {
            let images = attachedImages
            DispatchQueue.main.async { [weak self] in
                self?.attachedImages.removeAll()
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.sendPromptWithCodex(prompt, path: path, images: images)
            }
            return
        }

        if provider == .gemini {
            let images = attachedImages
            DispatchQueue.main.async { [weak self] in
                self?.attachedImages.removeAll()
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.sendPromptWithGemini(prompt, path: path, images: images)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var cmd = "\(self.resolvedExecutableCommand(for: .claude)) -p --output-format stream-json --verbose"

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
            // 시스템 프롬프트 — 세션 재개 시에는 이미 컨텍스트에 포함되어 있으므로 첫 호출에만 전달
            if !self.systemPrompt.isEmpty && self.sessionId == nil {
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
            // 플러그인 (수동 + PluginManager 자동 주입)
            var allPluginDirs = self.pluginDirs.filter { !$0.isEmpty }
            let managedPaths = PluginManager.shared.activePluginPaths
            for path in managedPaths where !allPluginDirs.contains(path) {
                allPluginDirs.append(path)
            }
            for pluginDir in allPluginDirs {
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

            // 첨부 이미지
            let images = self.attachedImages
            for imageURL in images {
                cmd += " --image \(self.shellEscape(imageURL.path))"
            }

            // 프롬프트
            cmd += " -- \(self.shellEscape(prompt))"

            // 이미지 첨부 초기화
            DispatchQueue.main.async { [weak self] in self?.attachedImages.removeAll() }

            // 프로젝트 경로 존재 여부 확인
            let projectDirURL = URL(fileURLWithPath: path)
            if !FileManager.default.fileExists(atPath: projectDirURL.path) {
                DispatchQueue.main.async {
                    self.appendBlock(.error(message: NSLocalizedString("tab.project.path.missing", comment: "")), content: String(format: NSLocalizedString("tab.project.path.missing.detail", comment: ""), path))
                    self.isProcessing = false
                    self.claudeActivity = .idle
                }
                return
            }

            let proc = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-f", "-c", cmd]
            proc.currentDirectoryURL = projectDirURL
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = Self.buildFullPATH()
            env["TERM"] = "dumb"; env["NO_COLOR"] = "1"
            proc.environment = env
            proc.standardOutput = outPipe
            proc.standardError = errPipe

            // 프로세스 및 파이프 참조를 메인 스레드에서 안전하게 설정
            DispatchQueue.main.async { [weak self] in
                self?.currentProcess = proc
                self?.currentOutPipe = outPipe
                self?.currentErrPipe = errPipe
            }

            // 프로세스 ID를 캡처하여 이후 검증용으로 사용
            let procId = ObjectIdentifier(proc)

            // stderr 캡처 (에러 진단용)
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let rawText = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                    else { return }
                    let text = self.sanitizeTerminalText(rawText)
                    if !text.isEmpty && !text.hasPrefix("{") && !text.contains("node:") {
                        self.appendBlock(.error(message: "stderr"), content: text)
                    }
                }
            }

            var jsonBuffer = ""
            let bufferQueue = DispatchQueue(label: "com.doffice.jsonBuffer")

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                bufferQueue.sync {
                    jsonBuffer += chunk

                    // 버퍼가 1MB를 초과하면 개행 없는 비정상 스트림 — 버퍼 초기화
                    if jsonBuffer.utf8.count > 1_048_576 {
                        jsonBuffer = ""
                        return
                    }

                    while let nl = jsonBuffer.range(of: "\n") {
                        let line = String(jsonBuffer[jsonBuffer.startIndex..<nl.lowerBound])
                        jsonBuffer = String(jsonBuffer[nl.upperBound...])
                        guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                              let ld = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any] else { continue }

                        DispatchQueue.main.async { [weak self] in
                            guard let self = self,
                                  self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                            else { return }
                            self.handleStreamEvent(json)
                        }
                    }
                }
            }

            do {
                try proc.run()

                // Watchdog: 30분 타임아웃 — CLI가 무한 hang 방지
                // procId를 캡처하여 워치독 발동 시 현재 프로세스인지 검증.
                // 프로세스 메모리가 재사용되면 다른 프로세스를 종료할 수 있으므로 identity 검증이 필수.
                let watchdog = DispatchWorkItem { [weak self, weak proc] in
                    guard let p = proc, p.isRunning else { return }
                    // 이 프로세스가 여전히 현재 활성 프로세스인지 확인
                    let isStillCurrent = self?.currentProcess.map { ObjectIdentifier($0) == procId } ?? false
                    guard isStillCurrent else { return }
                    CrashLogger.shared.warning("Process watchdog: 30min timeout reached, terminating pid=\(p.processIdentifier)")
                    p.terminate()
                    // SIGTERM이 무시될 경우 SIGKILL로 강제 종료
                    let pid = p.processIdentifier
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                        if p.isRunning { kill(pid, SIGKILL) }
                        // Reap zombie process to prevent resource leak
                        var status: Int32 = 0
                        waitpid(pid, &status, WNOHANG)
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

                proc.waitUntilExit()
                watchdog.cancel()
            } catch {
                print("[도피스] 프로세스 실행 실패: \(error)")
                CrashLogger.shared.error("Process launch failed: \(error.localizedDescription)")
                // 실패 시 파이프 핸들러 정리 — 누수 방지
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async { [weak self] in
                    self?.appendBlock(.error(message: NSLocalizedString("tab.process.launch.failed", comment: "")), content: String(format: NSLocalizedString("tab.process.launch.failed.detail", comment: ""), error.localizedDescription))
                    self?.isProcessing = false
                    self?.claudeActivity = .error
                    self?.currentProcess = nil
                }
                return
            }

            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // 취소된 프로세스면 무시
                if self.cancelledProcessIds.contains(procId) {
                    self.cancelledProcessIds.remove(procId)
                    return
                }
                // 이 프로세스가 현재 프로세스인지 확인 (다른 프로세스가 이미 대체했을 수 있음)
                let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
                guard isStillCurrentProcess else { return }

                self.currentProcess = nil
                self.currentOutPipe = nil
                self.currentErrPipe = nil
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

}
