import SwiftUI
import UserNotifications
import DesignSystem

extension TerminalTab {
    // MARK: - Shell Helpers

    func shellEscape(_ str: String) -> String { "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    func resolvedExecutableCommand(for provider: AgentProvider) -> String {
        let checker = provider.installChecker
        checker.check(force: true)
        let executablePath = checker.path.trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = executablePath.isEmpty ? provider.executableName : executablePath
        return shellEscape(executable)
    }

    func effectiveAllowedTools() -> String {
        let raw = allowedTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if shouldBlockParallelSubagents {
            return raw.filter { $0.caseInsensitiveCompare("Task") != .orderedSame }.joined(separator: ",")
        }
        return raw.joined(separator: ",")
    }

    func effectiveDisallowedTools() -> String {
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

    func enforceTokenBudgetIfNeeded() {
        dispatchPrecondition(condition: .onQueue(.main))
        // 슬립워크 예산 체크
        if let budget = sleepWorkTokenBudget, sleepWorkTask != nil {
            let used = tokensUsed - sleepWorkStartTokens
            if used >= budget * 2 {
                sleepWorkExceeded = true
                sleepWorkTask = nil
                budgetStopIssued = true
                currentProcess?.terminate()
                currentProcess = nil
                isProcessing = false
                claudeActivity = .idle
                AuditLog.shared.log(.sleepWorkEnd, tabId: id, projectName: projectName, detail: "예산 2배 초과로 중단: \(used)/\(budget) tokens")
                appendBlock(.status(message: NSLocalizedString("tab.sleepwork.stopped", comment: "")), content: NSLocalizedString("tab.sleepwork.stopped.detail", comment: ""))
                return
            }
        }

        // 비용 경고 체크 (80% 도달)
        if let warning = TokenTracker.shared.costWarningNeeded(tabCost: totalCost) {
            if dangerousCommandWarning == nil {  // 다른 경고가 없을 때만
                sensitiveFileWarning = warning  // 임시로 sensitiveFileWarning 재활용
            }
        }

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
        PluginHost.shared.fireEvent(.onSessionError, context: ["tabId": id])
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: NSLocalizedString("tab.token.protection.stopped", comment: "")), content: reason)
    }

    /// Thread-safe cached login shell PATH (resolved once at first call)
    private static let loginPathQueue = DispatchQueue(label: "doffice.login-path")
    private static var _cachedLoginPath: String?
    private static var _loginPathChecked = false

    /// GUI 앱에서도 claude CLI를 찾을 수 있도록 PATH를 완전히 구성
    public static func buildFullPATH() -> String {
        let home = NSHomeDirectory()
        var paths: [String] = []

        // Homebrew (Apple Silicon + Intel)
        paths += ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]

        // npm global 설치 경로들
        paths += ["/usr/local/opt/node/bin", home + "/.npm-global/bin"]

        // Codex Desktop bundle CLI
        paths.append("/Applications/Codex.app/Contents/Resources")

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

        // Bun runtime
        paths.append(home + "/.bun/bin")

        // Rust / Cargo
        paths.append(home + "/.cargo/bin")

        // Deno
        paths.append(home + "/.deno/bin")

        // MacPorts
        paths.append("/opt/local/bin")

        // 일반적인 경로들
        paths += [home + "/.local/bin", home + "/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

        // 기존 PATH 유지
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
        if !existing.isEmpty { paths.append(existing) }

        // Merge paths from login shell (async, non-blocking)
        // 로그인 셸 PATH는 백그라운드에서 비동기로 가져옴 — 메인 스레드 블로킹 방지
        // Thread-safe: loginPathQueue로 static 변수 접근 보호
        let shouldFetch = loginPathQueue.sync { () -> Bool in
            if _loginPathChecked { return false }
            _loginPathChecked = true
            return true
        }
        if shouldFetch {
            DispatchQueue.global(qos: .utility).async {
                let result = shellSyncLoginWithTimeout("echo $PATH", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let r = result, !r.isEmpty {
                    loginPathQueue.sync { _cachedLoginPath = r }
                }
            }
        }
        let loginPath = loginPathQueue.sync { _cachedLoginPath }
        if let loginPath, !loginPath.isEmpty {
            paths.append(loginPath)
        }

        return paths.joined(separator: ":")
    }

    public static func shellSync(_ command: String) -> String? {
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

    /// Login shell with timeout — prevents hang if user's .zshrc is slow or broken
    public static func shellSyncLoginWithTimeout(_ command: String, timeout: TimeInterval = 3) -> String? {
        let p = Process(); let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-l", "-c", command]
        p.environment = ProcessInfo.processInfo.environment
        do {
            try p.run()
            // 타임아웃: 지정 시간 내에 끝나지 않으면 강제 종료
            let deadline = Date().addingTimeInterval(timeout)
            while p.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if p.isRunning {
                p.terminate()
                return nil
            }
            let d = pipe.fileHandleForReading.readDataToEndOfFile()
            let o = String(data: d, encoding: .utf8)
            return o?.isEmpty == true ? nil : o
        } catch { return nil }
    }

    // MARK: - Notifications

    func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(workerName) — \(projectName) 완료"

        let elapsed = Int(Date().timeIntervalSince(startTime))
        let timeStr: String
        if elapsed < 60 { timeStr = String(format: NSLocalizedString("time.seconds", comment: ""), elapsed) }
        else if elapsed < 3600 { timeStr = String(format: NSLocalizedString("time.minutes.seconds", comment: ""), elapsed / 60, elapsed % 60) }
        else { timeStr = String(format: NSLocalizedString("time.hours.minutes", comment: ""), elapsed / 3600, (elapsed % 3600) / 60) }

        let fileCount = Set(fileChanges.map(\.fileName)).count
        var details: [String] = []
        details.append("⏱ \(timeStr)")
        if totalCost > 0 { details.append("💰 $\(String(format: "%.4f", totalCost))") }
        if tokensUsed > 0 { details.append("🔤 \(tokensUsed >= 1000 ? String(format: "%.1fk", Double(tokensUsed)/1000) : "\(tokensUsed)") tokens") }
        if fileCount > 0 { details.append(String(format: "📄 " + NSLocalizedString("notif.files.modified", comment: ""), fileCount)) }
        if commandCount > 0 { details.append(String(format: "⚙ " + NSLocalizedString("notif.commands", comment: ""), commandCount)) }
        if errorCount > 0 { details.append(String(format: "⚠ " + NSLocalizedString("notif.errors", comment: ""), errorCount)) }

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

    public func refreshGitInfo() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let p = self.projectPath
            let br = Self.shellSync("git -C \"\(p)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ch = Self.shellSync("git -C \"\(p)\" status --porcelain 2>/dev/null")?.components(separatedBy: "\n").filter { !$0.isEmpty }.count ?? 0
            let log = Self.shellSync("git -C \"\(p)\" log -1 --format='%s|||%cr' 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
            var msg = ""; var age = ""
            if let l = log { let pp = l.components(separatedBy: "|||"); if pp.count >= 2 { msg = pp[0]; age = pp[1] } }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.gitInfo = GitInfo(branch: br, changedFiles: ch, lastCommit: String(msg.prefix(40)), lastCommitAge: age, isGitRepo: !br.isEmpty)
                self.branch = br
            }
        }
    }

    public func generateSummary() {
        let files = blocks.compactMap { b -> String? in
            if case .fileChange(let path, _) = b.blockType { return (path as NSString).lastPathComponent }
            return nil
        }
        summary = SessionSummary(filesModified: Array(Set(files)), duration: Date().timeIntervalSince(startTime),
                                 tokenCount: tokensUsed, cost: totalCost, commandCount: commandCount, errorCount: errorCount, timestamp: Date())
    }

    public func exportLog() -> URL? {
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
        do {
            try s.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            CrashLogger.shared.warning("exportLog write failed: \(error.localizedDescription)")
        }
        return url
    }

    /// 대화 내용 전체를 마크다운 형식으로 클립보드에 복사
    @discardableResult
    public func copyConversation() -> Bool {
        var s = "# \(projectName) Session\n\n"
        for b in blocks {
            switch b.blockType {
            case .userPrompt: s += "\n## > \(b.content)\n\n"
            case .thought: s += "_\(b.content)_\n\n"
            case .toolUse(let name, _): s += "**\(name)**\n```\n\(b.content)\n```\n"
            case .toolOutput: s += "```\n\(b.content)\n```\n"
            case .toolError: s += "```\n\(b.content)\n```\n"
            case .completion: s += "\n---\n\(b.content)\n"
            case .text: s += "\(b.content)\n\n"
            case .error(let msg):
                let display = msg.isEmpty ? b.content : msg
                s += "> Error: \(display)\n\n"
            default: if !b.content.isEmpty { s += "\(b.content)\n" }
            }
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setString(s, forType: .string)
    }

    // MARK: - Stream Event Handler (핵심 파서)

    func handleStreamEvent(_ json: [String: Any]) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isRunning else { return }
        // 비정상 데이터로 인한 크래시 방지
        guard !json.isEmpty else { return }
        let type = json["type"] as? String ?? ""

        switch type {
        case "system":
            if let sid = json["session_id"] as? String { sessionId = sid; sessionProvider = provider }
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
                        activityDetail = nil
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
                        activityDetail = String((toolInput["command"] as? String ?? "").prefix(50))
                        commandCount += 1
                        let cmd = toolInput["command"] as? String ?? ""
                        // 보안: 위험 명령 감지
                        if let match = DangerousCommandDetector.shared.check(command: cmd) {
                            dangerousCommandWarning = "⚠️ \(match.pattern.severity.displayName): \(match.pattern.description)\n→ \(match.matchedText)"
                            AuditLog.shared.log(.dangerousCommand, tabId: id, projectName: projectName, detail: cmd, isDangerous: true)
                        }
                        // 감사 로그
                        AuditLog.shared.log(.bashCommand, tabId: id, projectName: projectName, detail: cmd)
                        let desc = toolInput["description"] as? String
                        let header = desc.map { "\(cmd)  // \($0)" } ?? cmd
                        appendBlock(.toolUse(name: "Bash", input: cmd), content: header)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(cmd.prefix(40)))"))
                    case "Read":
                        claudeActivity = .reading
                        let file = toolInput["file_path"] as? String ?? ""
                        activityDetail = (file as NSString).lastPathComponent
                        // 보안: 민감 파일 감지
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Read") {
                            sensitiveFileWarning = String(format: NSLocalizedString("sensitive.file.read", comment: ""), match.patternMatched, file)
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Read: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileRead, tabId: id, projectName: projectName, detail: file)
                        appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
                        readCommandCount += 1
                        NotificationCenter.default.post(name: .init("dofficeAchievementFileRead"), object: readCommandCount)
                    case "Write":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        activityDetail = (file as NSString).lastPathComponent
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Write") {
                            sensitiveFileWarning = String(format: NSLocalizedString("sensitive.file.write", comment: ""), match.patternMatched, file)
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Write: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileWrite, tabId: id, projectName: projectName, detail: file)
                        recordFileChange(path: file, action: "Write")
                        appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Write: \((file as NSString).lastPathComponent)"))
                        NotificationCenter.default.post(name: .init("dofficeAchievementFileEdit"), object: nil)
                    case "Edit":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        activityDetail = (file as NSString).lastPathComponent
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Edit") {
                            sensitiveFileWarning = String(format: NSLocalizedString("sensitive.file.edit", comment: ""), match.patternMatched, file)
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Edit: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileEdit, tabId: id, projectName: projectName, detail: file)
                        recordFileChange(path: file, action: "Edit")
                        appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Edit: \((file as NSString).lastPathComponent)"))
                        NotificationCenter.default.post(name: .init("dofficeAchievementFileEdit"), object: nil)
                    case "Grep":
                        claudeActivity = .searching
                        activityDetail = String((toolInput["pattern"] as? String ?? "").prefix(30))
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Grep", input: pattern), content: pattern)
                        NotificationCenter.default.post(name: .init("dofficeAchievementUnlock"), object: "first_grep")
                    case "Glob":
                        claudeActivity = .searching
                        activityDetail = String((toolInput["pattern"] as? String ?? "").prefix(30))
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Glob", input: pattern), content: pattern)
                        NotificationCenter.default.post(name: .init("dofficeAchievementUnlock"), object: "first_glob")
                    case "Task":
                        claudeActivity = .thinking
                        activityDetail = nil
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

            if let sid = json["session_id"] as? String { sessionId = sid; sessionProvider = provider }
            if let latestDenial = permissionDenials.last {
                pendingPermissionDenial = permissionDenialCandidate(from: latestDenial)
            }

            appendBlock(.completion(cost: cost, duration: duration),
                        content: "완료")
            timeline.append(TimelineEvent(timestamp: Date(), type: .completed, detail: "작업 완료"))

            // 슬립워크 완료 체크
            if sleepWorkTask != nil {
                sleepWorkCompleted = true
                sleepWorkTask = nil
                AuditLog.shared.log(.sleepWorkEnd, tabId: id, projectName: projectName, detail: "슬립워크 완료")
            }

            // 즉시 완료 상태로 전환 (프로세스 종료 기다리지 않음)
            isProcessing = false
            claudeActivity = .done
            activityDetail = nil
            lastResultText = resultText
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            finalizePromptHistory()
            generateSummary()
            seenToolUseIds.removeAll()
            clearPromptDecorations()
            if let denial = pendingPermissionDenial {
                presentPermissionApprovalIfNeeded(denial)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.claudeActivity == .done {
                    self?.claudeActivity = .idle
                    self?.activityDetail = nil
                }
            }

            if permissionDenials.isEmpty {
                sendCompletionNotification()
                PluginHost.shared.fireEvent(.onSessionComplete, context: ["tabId": id])
                NotificationCenter.default.post(
                    name: .dofficeTabCycleCompleted,
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

    // MARK: - Tool Result Handling

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
                timeline.append(TimelineEvent(timestamp: Date(), type: .error, detail: String(cleanedStderr.prefix(50))))
            } else if isError, let message = extractToolResultText(from: json) {
                let cleanedMessage = sanitizeTerminalText(message)
                errorCount += 1
                appendBlock(.toolError, content: cleanedMessage)
                timeline.append(TimelineEvent(timestamp: Date(), type: .error, detail: String(cleanedMessage.prefix(50))))
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
                timeline.append(TimelineEvent(timestamp: Date(), type: .error, detail: String(cleanedMessage.prefix(50))))
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

    // MARK: - Permission Handling

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

    func presentPermissionApprovalIfNeeded(_ denial: PermissionDenialCandidate) {
        let command = approvalCommandText(for: denial)
        let fingerprint = [denial.toolName, command].joined(separator: "|")
        guard pendingApproval == nil, lastPermissionFingerprint != fingerprint else { return }

        let retryMode = retryPermissionMode(for: denial.toolName)
        let retrySummary = retryMode == .acceptEdits
            ? NSLocalizedString("tab.permission.retry.edit", comment: "")
            : NSLocalizedString("tab.permission.retry.full", comment: "")

        lastPermissionFingerprint = fingerprint
        let approvalCommand = command
        pendingApproval = PendingApproval(
            command: approvalCommand,
            reason: String(format: NSLocalizedString("tab.permission.needed", comment: ""), approvalReasonPrefix(for: denial.toolName), retrySummary),
            onApprove: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: NSLocalizedString("tab.permission.approved", comment: "")))
                self?.sendPrompt(self?.approvalRetryPrompt(for: denial.toolName) ?? "Permission granted. Please continue the previous task.", permissionOverride: retryMode)
            },
            onDeny: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: NSLocalizedString("tab.permission.denied", comment: "")))
            }
        )
        // 세션 알림: 승인 필요
        let tabName = workerName.isEmpty ? projectName : workerName
        NotificationCenter.default.post(name: .init("dofficeApprovalNeeded"), object: nil, userInfo: ["tabName": tabName, "tabId": id, "toolName": denial.toolName])
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
            return NSLocalizedString("tab.approval.file.edit", comment: "")
        case "Bash":
            return NSLocalizedString("tab.approval.command.run", comment: "")
        case "WebFetch":
            return NSLocalizedString("tab.approval.web.fetch", comment: "")
        case "WebSearch":
            return NSLocalizedString("tab.approval.web.search", comment: "")
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

    // MARK: - Tool Preview

    func toolPreview(toolName: String, toolInput: [String: Any]) -> String {
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

    // MARK: - Parallel Tasks

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

    func finalizeParallelTasks(as state: ParallelTaskState) {
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

        return NSLocalizedString("tab.parallel.task", comment: "")
    }

    private func parallelTaskAssigneeId(seed: String) -> String {
        let preferredPool = Self.hiredCharactersProvider().filter {
            !$0.isOnVacation && $0.id != characterId
        }
        let pool = preferredPool

        guard !pool.isEmpty else {
            return characterId ?? "parallel-\(id)"
        }

        let alreadyUsed = Set(parallelTasks.map(\.assigneeCharacterId))
        let available = pool.filter { !alreadyUsed.contains($0.id) }
        let effectivePool = available.isEmpty ? pool : available
        let hash = Int(UInt(bitPattern: seed.hashValue) % UInt(effectivePool.count))
        return effectivePool[hash].id
    }
}
