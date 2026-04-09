import SwiftUI
import DesignSystem

extension TerminalTab {
    // MARK: - Codex

    func codexConfigOverride(_ key: String, value: String) -> String {
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

    func sendPromptWithCodex(_ prompt: String, path: String, images: [URL], allowResumeFallback: Bool = true) {
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

    func handleCodexStreamEvent(_ json: [String: Any]) {
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

    func handleCodexItem(_ item: [String: Any], started: Bool) {
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

}
