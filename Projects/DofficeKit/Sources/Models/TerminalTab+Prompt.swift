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

    public func sendPrompt(_ prompt: String, permissionOverride: PermissionMode? = nil, bypassWorkflowRouting: Bool = false) {
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

        guard !isProcessing else { return }

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

        appendBlock(.userPrompt, content: prompt)
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

    // MARK: - Codex

    private func codexConfigOverride(_ key: String, value: String) -> String {
        "-c \(shellEscape("\(key)=\"\(value)\""))"
    }

    static func isCodexMissingRolloutResumeError(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("thread/resume failed: no rollout found for thread id")
            || normalized.contains("error: thread/resume: thread/resume failed: no rollout found")
    }

    static func isIgnorableCodexStderr(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("failed to refresh available models: timeout waiting for child process to exit")
            || normalized.contains("codex_core::shell_snapshot: failed to delete shell snapshot")
    }

    private func sendPromptWithCodex(_ prompt: String, path: String, images: [URL], allowResumeFallback: Bool = true) {
        let projectDirURL = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: projectDirURL.path) {
            DispatchQueue.main.async {
                self.appendBlock(.error(message: NSLocalizedString("tab.project.path.missing", comment: "")), content: String(format: NSLocalizedString("tab.project.path.missing.detail", comment: ""), path))
                self.isProcessing = false
                self.claudeActivity = .idle
            }
            return
        }

        let codexExecutable = resolvedExecutableCommand(for: .codex)
        var cmd: String
        let resumeSessionId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldResume = !(resumeSessionId ?? "").isEmpty
        if shouldResume {
            cmd = "\(codexExecutable) exec resume --json"
        } else {
            cmd = "\(codexExecutable) exec --json"
        }

        cmd += " \(codexConfigOverride("sandbox_mode", value: codexSandboxMode.rawValue))"
        cmd += " \(codexConfigOverride("approval_policy", value: codexApprovalPolicy.rawValue))"
        cmd += " --skip-git-repo-check"
        cmd += " -m \(shellEscape(selectedModel.rawValue))"

        for dir in additionalDirs where !dir.isEmpty {
            cmd += " --add-dir \(shellEscape(dir))"
        }
        for imageURL in images {
            cmd += " -i \(shellEscape(imageURL.path))"
        }

        if shouldResume, let sid = resumeSessionId, !sid.isEmpty {
            cmd += " \(shellEscape(sid))"
        }
        cmd += " \(shellEscape(prompt))"

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-f", "-c", cmd]
        proc.currentDirectoryURL = projectDirURL
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.buildFullPATH()
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        proc.environment = env
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        DispatchQueue.main.async { [weak self] in
            self?.currentProcess = proc
            self?.currentOutPipe = outPipe
            self?.currentErrPipe = errPipe
        }

        let procId = ObjectIdentifier(proc)
        var jsonBuffer = ""
        let bufferQueue = DispatchQueue(label: "com.doffice.codex.jsonBuffer")
        let stderrStateQueue = DispatchQueue(label: "com.doffice.codex.stderrState")
        var sawMissingRolloutResumeError = false
        var sawTurnCompleted = false
        var lastImportantStderr: String?

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let rawText = String(data: data, encoding: .utf8) else { return }
            let sanitized = self?.sanitizeTerminalText(rawText) ?? rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            stderrStateQueue.sync {
                if !sanitized.isEmpty {
                    if Self.isCodexMissingRolloutResumeError(sanitized) {
                        sawMissingRolloutResumeError = true
                    }
                    if !Self.isIgnorableCodexStderr(sanitized) {
                        lastImportantStderr = sanitized
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                else { return }
                let text = sanitized
                guard !text.isEmpty,
                      !text.contains(" WARN "),
                      !text.hasPrefix("{") else { return }
                if shouldResume && allowResumeFallback && Self.isCodexMissingRolloutResumeError(text) {
                    return
                }
                if Self.isIgnorableCodexStderr(text) {
                    return
                }
                self.appendBlock(.error(message: "stderr"), content: text)
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8) else { return }
            bufferQueue.sync {
                jsonBuffer += chunk

                if jsonBuffer.utf8.count > 1_048_576 {
                    jsonBuffer = ""
                    return
                }

                while let nl = jsonBuffer.range(of: "\n") {
                    let line = String(jsonBuffer[..<nl.lowerBound])
                    jsonBuffer = String(jsonBuffer[nl.upperBound...])
                    guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continue
                    }
                    if (json["type"] as? String) == "turn.completed" {
                        sawTurnCompleted = true
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self,
                              self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                        else { return }
                        self.handleCodexStreamEvent(json)
                    }
                }
            }
        }

        do {
            try proc.run()

            let watchdog = DispatchWorkItem { [weak proc] in
                guard let p = proc, p.isRunning else { return }
                print("[Doffice] ⚠️ Codex process watchdog: 30분 타임아웃 도달, 강제 종료")
                p.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

            proc.waitUntilExit()
            watchdog.cancel()
        } catch {
            print("[도피스] Codex 프로세스 실행 실패: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.appendBlock(.error(message: "Codex launch failed"), content: error.localizedDescription)
                self?.isProcessing = false
                self?.claudeActivity = .error
                self?.currentProcess = nil
                self?.currentOutPipe = nil
                self?.currentErrPipe = nil
            }
            return
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        let shouldRetryWithoutResume = stderrStateQueue.sync {
            shouldResume && allowResumeFallback && sawMissingRolloutResumeError
        }
        let importantStderr = stderrStateQueue.sync { lastImportantStderr }
        let didCompleteTurn = bufferQueue.sync { sawTurnCompleted }
        let exitCode = proc.terminationStatus

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.cancelledProcessIds.contains(procId) {
                self.cancelledProcessIds.remove(procId)
                return
            }
            let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
            guard isStillCurrentProcess else { return }

            self.currentProcess = nil
            self.currentOutPipe = nil
            self.currentErrPipe = nil
            if shouldRetryWithoutResume {
                self.sessionId = nil
                self.claudeActivity = .thinking
                self.appendBlock(
                    .status(message: "Codex session restart"),
                    content: "이전 Codex 세션을 이어갈 수 없어 새 세션으로 다시 시도합니다."
                )
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.sendPromptWithCodex(prompt, path: path, images: images, allowResumeFallback: false)
                }
                return
            }
            if self.isProcessing {
                self.isProcessing = false
                if exitCode != 0 && !didCompleteTurn {
                    self.claudeActivity = .error
                    if let importantStderr, !importantStderr.isEmpty {
                        self.appendBlock(.error(message: "Codex execution failed"), content: importantStderr)
                    } else {
                        self.appendBlock(.error(message: "Codex execution failed"), content: "Codex exited with status \(exitCode).")
                    }
                    self.finalizeParallelTasks(as: .failed)
                } else {
                    self.claudeActivity = self.claudeActivity == .error ? .error : .done
                    self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
                }
            }
        }
    }

    // MARK: - Codex Stream Event Handler

    private func handleCodexStreamEvent(_ json: [String: Any]) {
        guard isRunning, !json.isEmpty else { return }
        let type = json["type"] as? String ?? ""

        switch type {
        case "thread.started":
            if let sid = json["thread_id"] as? String, !sid.isEmpty {
                sessionId = sid; sessionProvider = provider
            }

        case "item.started":
            guard let item = json["item"] as? [String: Any] else { return }
            handleCodexItem(item, started: true)

        case "item.completed":
            guard let item = json["item"] as? [String: Any] else { return }
            handleCodexItem(item, started: false)

        case "turn.completed":
            if let usage = json["usage"] as? [String: Any] {
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

            appendBlock(.completion(cost: nil, duration: nil), content: "완료")
            timeline.append(TimelineEvent(timestamp: Date(), type: .completed, detail: "작업 완료"))
            isProcessing = false
            claudeActivity = .done
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            generateSummary()
            sendCompletionNotification()
            PluginHost.shared.fireEvent(.onSessionComplete, context: ["tabId": id])
            NotificationCenter.default.post(
                name: .dofficeTabCycleCompleted,
                object: self,
                userInfo: [
                    "tabId": id,
                    "completedPromptCount": completedPromptCount,
                    "resultText": lastResultText
                ]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.claudeActivity == .done { self?.claudeActivity = .idle }
            }

        case "exec_approval_request":
            claudeActivity = .error
            errorCount += 1
            appendBlock(.error(message: "Codex approval required"), content: "현재 Codex exec JSON 모드에서는 실시간 승인 응답을 지원하지 않습니다. 승인 정책이나 샌드박스 설정을 조정해 다시 시도해주세요.")

        case "error":
            let message = (json["message"] as? String) ?? "Codex execution failed"
            claudeActivity = .error
            errorCount += 1
            appendBlock(.error(message: message), content: message)

        default:
            break
        }
    }

    private func handleCodexItem(_ item: [String: Any], started: Bool) {
        let itemType = item["type"] as? String ?? ""

        switch itemType {
        case "agent_message":
            guard !started else { return }
            let text = item["text"] as? String ?? ""
            guard !text.isEmpty else { return }
            claudeActivity = .writing
            lastResultText = text
            appendBlock(.thought, content: text)

        case "command_execution":
            let command = item["command"] as? String ?? ""
            if started {
                claudeActivity = .running
                commandCount += 1
                appendBlock(.toolUse(name: "Bash", input: command), content: command)
                timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(command.prefix(40)))"))
            } else {
                let output = sanitizeTerminalText(item["aggregated_output"] as? String ?? "")
                let exitCode = item["exit_code"] as? Int ?? 0
                if !output.isEmpty {
                    appendBlock(.toolOutput, content: output)
                }
                if exitCode != 0 {
                    errorCount += 1
                    appendBlock(.toolError, content: "exit \(exitCode)")
                    claudeActivity = .error
                }
            }

        case "file_change":
            guard !started else { return }
            let changes = item["changes"] as? [[String: Any]] ?? []
            claudeActivity = .writing
            for change in changes {
                let path = change["path"] as? String ?? ""
                guard !path.isEmpty else { continue }
                let kind = (change["kind"] as? String ?? "update").lowercased()
                let action: String
                switch kind {
                case "add":
                    action = "Write"
                case "delete":
                    action = "Delete"
                default:
                    action = "Edit"
                }
                recordFileChange(path: path, action: action)
                appendBlock(.fileChange(path: path, action: action), content: (path as NSString).lastPathComponent)
                timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "\(action): \((path as NSString).lastPathComponent)"))
            }

        default:
            break
        }
    }

    // MARK: - Gemini CLI

    private func sendPromptWithGemini(_ prompt: String, path: String, images: [URL]) {
        let projectDirURL = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: projectDirURL.path) {
            DispatchQueue.main.async {
                self.appendBlock(.error(message: NSLocalizedString("tab.project.path.missing", comment: "")), content: String(format: NSLocalizedString("tab.project.path.missing.detail", comment: ""), path))
                self.isProcessing = false
                self.claudeActivity = .idle
            }
            return
        }

        // Gemini CLI: pipe prompt via stdin, capture plain text stdout
        // NOTE: Gemini CLI hangs with -m flag for most models,
        // so we only pass it when not using the default model.
        let geminiCmd = resolvedExecutableCommand(for: .gemini)
        var cmd = "printf '%s\\n' \(shellEscape(prompt)) | \(geminiCmd)"

        // Gemini CLI yolo mode
        if permissionMode == .bypassPermissions {
            cmd += " --yolo"
        }

        // Suppress stderr noise
        cmd += " 2>/dev/null"

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-f", "-c", cmd]
        proc.currentDirectoryURL = projectDirURL
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.buildFullPATH()
        proc.environment = env
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        DispatchQueue.main.async { [weak self] in
            self?.currentProcess = proc
            self?.currentOutPipe = outPipe
            self?.currentErrPipe = errPipe
        }
        let procId = ObjectIdentifier(proc)

        // Stream stdout — Gemini CLI outputs plain text (not JSON)
        // Accumulate all output into a single response block for clean rendering
        var textBuffer = ""
        var responseBlockId: UUID?
        let bufferQueue = DispatchQueue(label: "com.doffice.gemini.textBuffer")

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            bufferQueue.sync {
                textBuffer += chunk

                if textBuffer.utf8.count > 1_048_576 {
                    textBuffer = ""
                    return
                }

                // Collect complete lines
                var newLines: [String] = []
                while let nl = textBuffer.range(of: "\n") {
                    let line = String(textBuffer[..<nl.lowerBound])
                    textBuffer = String(textBuffer[nl.upperBound...])

                    // Strip ANSI escape codes
                    let cleaned = line
                        .replacingOccurrences(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)

                    // Skip interactive prompt markers
                    let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == ">" || trimmed == " >" || trimmed.isEmpty { continue }

                    // Strip "✦ " prefix
                    let content = trimmed.hasPrefix("✦") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : cleaned
                    if !content.isEmpty {
                        newLines.append(content)
                    }
                }

                guard !newLines.isEmpty else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                    else { return }
                    self.claudeActivity = .writing

                    // Append to existing response block or create new one
                    if let blockId = responseBlockId,
                       let idx = self.blocks.lastIndex(where: { $0.id == blockId }) {
                        self.blocks[idx].content += "\n" + newLines.joined(separator: "\n")
                    } else {
                        let block = StreamBlock(type: .text, content: newLines.joined(separator: "\n"))
                        responseBlockId = block.id
                        self.blocks.append(block)
                    }
                }
            }
        }

        // stderr is suppressed via 2>/dev/null in the command,
        // but handle any remaining output silently
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData // drain to prevent pipe blocking
        }

        do {
            try proc.run()

            let watchdog = DispatchWorkItem { [weak proc] in
                guard let p = proc, p.isRunning else { return }
                p.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

            proc.waitUntilExit()
            watchdog.cancel()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.appendBlock(.error(message: "Gemini launch failed"), content: error.localizedDescription)
                self?.isProcessing = false
                self?.claudeActivity = .error
                self?.currentProcess = nil
                self?.currentOutPipe = nil
                self?.currentErrPipe = nil
            }
            return
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.cancelledProcessIds.contains(procId) {
                self.cancelledProcessIds.remove(procId)
                return
            }
            let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
            guard isStillCurrentProcess else { return }

            self.currentProcess = nil
            self.currentOutPipe = nil
            self.currentErrPipe = nil
            if self.isProcessing {
                self.isProcessing = false
                self.claudeActivity = self.claudeActivity == .error ? .error : .done
                self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
            }
        }
    }

    // MARK: - Gemini Stream Event Handler

    private func handleGeminiStreamEvent(_ json: [String: Any]) {
        guard isRunning, !json.isEmpty else { return }
        let type = json["type"] as? String ?? ""

        switch type {
        case "init":
            if let sid = json["session_id"] as? String { sessionId = sid; sessionProvider = provider }
            if let model = json["model"] as? String {
                updateReportedModel(model)
            }

        case "message":
            let role = json["role"] as? String ?? ""
            let content = json["content"] as? String ?? ""
            guard !content.isEmpty else { return }

            if role == "assistant" {
                claudeActivity = .writing
                // delta=true 이면 스트리밍 조각 → 마지막 thought 블록에 연결
                let isDelta = json["delta"] as? Bool ?? false
                if isDelta,
                   !blocks.isEmpty,
                   case .thought = blocks[blocks.count - 1].blockType {
                    blocks[blocks.count - 1].content += content
                } else {
                    appendBlock(.thought, content: content)
                }
            }

        case "tool_use":
            let toolName = json["tool_name"] as? String ?? ""
            let toolId = json["tool_id"] as? String ?? UUID().uuidString
            let params = json["parameters"] as? [String: Any] ?? [:]

            guard !seenToolUseIds.contains(toolId) else { return }
            seenToolUseIds.insert(toolId)

            switch toolName {
            case "shell", "bash", "execute_command":
                claudeActivity = .running
                commandCount += 1
                let cmd = params["command"] as? String ?? params["cmd"] as? String ?? ""
                appendBlock(.toolUse(name: "Bash", input: cmd), content: cmd)
                timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(cmd.prefix(40)))"))
            case "read_file":
                claudeActivity = .reading
                let file = params["file_path"] as? String ?? ""
                appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
            case "write_file", "create_file":
                claudeActivity = .writing
                let file = params["file_path"] as? String ?? ""
                recordFileChange(path: file, action: "Write")
                appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Write: \((file as NSString).lastPathComponent)"))
            case "edit_file", "replace_in_file":
                claudeActivity = .writing
                let file = params["file_path"] as? String ?? ""
                recordFileChange(path: file, action: "Edit")
                appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Edit: \((file as NSString).lastPathComponent)"))
            case "glob", "list_directory", "grep", "search":
                claudeActivity = .searching
                let pattern = params["pattern"] as? String ?? params["dir_path"] as? String ?? toolName
                appendBlock(.toolUse(name: toolName, input: pattern), content: pattern)
            default:
                claudeActivity = .running
                let preview = toolPreview(toolName: toolName, toolInput: params)
                appendBlock(.toolUse(name: toolName, input: preview), content: preview)
            }

        case "tool_result":
            let output = json["output"] as? String ?? ""
            let status = json["status"] as? String ?? ""
            if status == "error" {
                appendBlock(.toolError, content: output)
                errorCount += 1
            } else if !output.isEmpty {
                appendBlock(.toolOutput, content: String(output.prefix(2000)))
            }

        case "result":
            let stats = json["stats"] as? [String: Any] ?? [:]
            let totalTokens = stats["total_tokens"] as? Int ?? 0
            let inputTokens = stats["input_tokens"] as? Int ?? 0
            let outputTokens = stats["output_tokens"] as? Int ?? 0
            let durationMs = stats["duration_ms"] as? Int ?? 0

            let diffIn = max(0, inputTokens - inputTokensUsed)
            let diffOut = max(0, outputTokens - outputTokensUsed)
            if diffIn > 0 || diffOut > 0 {
                TokenTracker.shared.recordTokens(input: diffIn, output: diffOut)
            }
            inputTokensUsed = inputTokens
            outputTokensUsed = outputTokens
            tokensUsed = totalTokens

            appendBlock(.completion(cost: 0, duration: durationMs), content: "완료")
            timeline.append(TimelineEvent(timestamp: Date(), type: .completed, detail: "작업 완료"))

            isProcessing = false
            claudeActivity = .done
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            finalizePromptHistory()
            generateSummary()
            sendCompletionNotification()
            seenToolUseIds.removeAll()

            NotificationCenter.default.post(
                name: .dofficeTabCycleCompleted,
                object: self,
                userInfo: [
                    "tabId": id,
                    "completedPromptCount": completedPromptCount,
                    "resultText": lastResultText
                ]
            )

        default:
            break
        }
    }
}
