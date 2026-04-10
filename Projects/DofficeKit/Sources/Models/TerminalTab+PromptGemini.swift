import SwiftUI
import DesignSystem

extension TerminalTab {
    // MARK: - Gemini CLI

    func sendPromptWithGemini(_ prompt: String, path: String, images: [URL]) {
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

                    // Try JSON event parsing first
                    if trimmed.hasPrefix("{"),
                       let jsonData = trimmed.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self,
                                  self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                            else { return }
                            self.handleGeminiStreamEvent(json)
                        }
                        continue
                    }

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
            CrashLogger.shared.error("Gemini launch failed: \(error.localizedDescription)")
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            try? outPipe.fileHandleForReading.close()
            try? errPipe.fileHandleForReading.close()
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
        try? outPipe.fileHandleForReading.close()
        try? errPipe.fileHandleForReading.close()

        // 좀비 프로세스 방지
        let pid = proc.processIdentifier
        if pid > 0 {
            var status: Int32 = 0
            waitpid(pid, &status, WNOHANG)
        }

        // Flush remaining text in buffer (content without trailing newline)
        let remainingText: String = bufferQueue.sync {
            let leftover = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            textBuffer = ""
            return leftover
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.cancelledProcessIds.contains(procId) {
                self.cancelledProcessIds.remove(procId)
                return
            }
            let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
            guard isStillCurrentProcess else { return }

            // Flush remaining buffered text
            if !remainingText.isEmpty {
                let cleaned = remainingText
                    .replacingOccurrences(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
                let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed != ">" && trimmed != " >" {
                    let content = trimmed.hasPrefix("✦") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : cleaned
                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let blockId = responseBlockId,
                           let idx = self.blocks.lastIndex(where: { $0.id == blockId }) {
                            self.blocks[idx].content += "\n" + content
                        } else {
                            self.blocks.append(StreamBlock(type: .text, content: content))
                        }
                    }
                }
            }

            self.currentProcess = nil
            self.currentOutPipe = nil
            self.currentErrPipe = nil
            if self.isProcessing {
                self.isProcessing = false
                self.claudeActivity = self.claudeActivity == .error ? .error : .done
                self.appendBlock(.completion(cost: 0, duration: nil), content: "완료")
                self.completedPromptCount += 1
                self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
                self.finalizePromptHistory()
                self.generateSummary()
                self.sendCompletionNotification()
                self.seenToolUseIds.removeAll()
                self.clearPromptDecorations()
            }
        }
    }

    // MARK: - Gemini Stream Event Handler

    func handleGeminiStreamEvent(_ json: [String: Any]) {
        dispatchPrecondition(condition: .onQueue(.main))
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
            clearPromptDecorations()

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
