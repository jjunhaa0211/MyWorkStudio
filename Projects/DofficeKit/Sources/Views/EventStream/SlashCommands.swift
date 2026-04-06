import SwiftUI
import Combine
import DesignSystem

extension EventStreamView {
    // MARK: - Slash Commands
    // ═══════════════════════════════════════════

    struct SlashCommand {
        let name: String
        let description: String
        let usage: String
        let category: String
        let action: (TerminalTab, SessionManager, [String]) -> Void

        public init(_ name: String, _ desc: String, usage: String = "", category: String = NSLocalizedString("slash.category.general", comment: ""), action: @escaping (TerminalTab, SessionManager, [String]) -> Void) {
            self.name = name; self.description = desc; self.usage = usage; self.category = category; self.action = action
        }
    }

    static let allSlashCommands: [SlashCommand] = [
        // ── 일반 ──
        SlashCommand("help", NSLocalizedString("slash.cmd.help", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, args in
            let cmds = EventStreamView.allSlashCommands
            if let query = args.first?.lowercased() {
                let filtered = cmds.filter { $0.name.contains(query) || $0.description.contains(query) }
                if filtered.isEmpty { tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.cmd.not.found", comment: ""), query))); return }
                let lines = filtered.map { "/\($0.name)\($0.usage.isEmpty ? "" : " \($0.usage)") — \($0.description)" }
                tab.appendBlock(.status(message: NSLocalizedString("terminal.search.result", comment: "") + lines.joined(separator: "\n")))
            } else {
                var grouped: [String: [SlashCommand]] = [:]
                for c in cmds { grouped[c.category, default: []].append(c) }
                let order = [NSLocalizedString("slash.category.general", comment: ""), NSLocalizedString("slash.category.model", comment: ""), NSLocalizedString("slash.category.session", comment: ""), NSLocalizedString("slash.category.display", comment: ""), "Git", NSLocalizedString("slash.category.tools", comment: "")]
                var text = "📜 " + NSLocalizedString("help.command.list", comment: "") + "\n"
                for cat in order {
                    guard let list = grouped[cat] else { continue }
                    text += "\n[\(cat)]\n"
                    for c in list { text += "  /\(c.name)\(c.usage.isEmpty ? "" : " \(c.usage)") — \(c.description)\n" }
                }
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("clear", NSLocalizedString("slash.cmd.clear", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            tab.clearBlocks()
            tab.appendBlock(.status(message: NSLocalizedString("terminal.log.cleared", comment: "")))
        },
        SlashCommand("cancel", NSLocalizedString("slash.cmd.cancel", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            else { tab.appendBlock(.status(message: NSLocalizedString("terminal.no.running.task", comment: ""))) }
        },
        SlashCommand("stop", NSLocalizedString("slash.cmd.stop", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            if tab.isProcessing || tab.isRunning { tab.forceStop() }
            else { tab.appendBlock(.status(message: NSLocalizedString("terminal.no.running.task", comment: ""))) }
        },
        SlashCommand("copy", NSLocalizedString("slash.cmd.copy", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            if let last = tab.blocks.last(where: { if case .thought = $0.blockType { return true }; if case .completion = $0.blockType { return true }; return false }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.content, forType: .string)
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.copied.to.clipboard", comment: ""), last.content.count)))
            } else { tab.appendBlock(.status(message: NSLocalizedString("terminal.no.response.to.copy", comment: ""))) }
        },
        SlashCommand("copyall", NSLocalizedString("slash.cmd.copyall", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
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
            if text.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("terminal.no.response.to.copy", comment: "")))
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.copied.to.clipboard", comment: ""), text.count)))
            }
        },
        SlashCommand("export", NSLocalizedString("slash.cmd.export", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
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
            let path = "\(tab.projectPath)/doffice_log_\(dateStr).txt"
            do { try text.write(toFile: path, atomically: true, encoding: .utf8)
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.log.saved", comment: ""), path)))
            } catch { tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.log.save.failed", comment: ""), error.localizedDescription))) }
        },

        // ── 모델/설정 ──
        SlashCommand("model", NSLocalizedString("slash.cmd.model", comment: ""), usage: "<model>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let model = ClaudeModel.allCases.first(where: { $0.rawValue.lowercased().contains(arg) }) else {
                let current = tab.selectedModel
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.model.current", comment: ""), current.icon, current.rawValue)))
                return
            }
            tab.selectedModel = model
            tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.model.changed", comment: ""), model.icon, model.rawValue)))
        },
        SlashCommand("effort", NSLocalizedString("slash.cmd.effort", comment: ""), usage: "<low|medium|high|max>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let effort = EffortLevel.allCases.first(where: { $0.rawValue.lowercased() == arg }) else {
                let current = tab.effortLevel
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.effort.current", comment: ""), current.icon, current.rawValue)))
                return
            }
            tab.effortLevel = effort
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.effort.changed", comment: ""), effort.icon, effort.rawValue)))
        },
        SlashCommand("output", NSLocalizedString("slash.cmd.output", comment: ""), usage: "<full|realtime|result>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.output.current", comment: ""), tab.outputMode.icon, tab.outputMode.displayName)))
                return
            }
            let modeMap: [String: OutputMode] = ["full": .full, "전체": .full, "realtime": .realtime, "실시간": .realtime, "result": .resultOnly, "결과만": .resultOnly, "결과": .resultOnly]
            guard let mode = modeMap[arg] else { tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.output.unknown", comment: ""), arg))); return }
            tab.outputMode = mode
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.output.changed", comment: ""), mode.icon, mode.rawValue)))
        },
        SlashCommand("permission", NSLocalizedString("slash.cmd.permission", comment: ""), usage: "<bypass|auto|default|plan|edits>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                let c = tab.permissionMode
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.permission.current", comment: ""), c.icon, c.displayName, c.desc)))
                return
            }
            let map: [String: PermissionMode] = ["bypass": .bypassPermissions, "auto": .auto, "default": .defaultMode, "plan": .plan, "edits": .acceptEdits, "edit": .acceptEdits]
            guard let mode = map[arg] else { tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.permission.unknown", comment: ""), arg))); return }
            tab.permissionMode = mode
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.permission.changed", comment: ""), mode.icon, mode.displayName, mode.desc)))
        },
        SlashCommand("budget", NSLocalizedString("slash.cmd.budget", comment: ""), usage: "<금액|off>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first else {
                let b = tab.maxBudgetUSD
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.budget.current", comment: ""), b > 0 ? "$\(String(format: "%.2f", b))" : NSLocalizedString("slash.status.budget.unlimited", comment: ""))))
                return
            }
            if arg == "off" || arg == "0" { tab.maxBudgetUSD = 0; tab.appendBlock(.status(message: NSLocalizedString("slash.status.budget.removed", comment: ""))); return }
            guard let v = Double(arg), v > 0 else { tab.appendBlock(.status(message: NSLocalizedString("slash.status.budget.invalid", comment: ""))); return }
            tab.maxBudgetUSD = v
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.budget.set", comment: ""), String(format: "%.2f", v))))
        },
        SlashCommand("system", NSLocalizedString("slash.cmd.system", comment: ""), usage: "<프롬프트|clear>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                let s = tab.systemPrompt.isEmpty ? NSLocalizedString("slash.status.system.none", comment: "") : tab.systemPrompt
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.system.current", comment: ""), s)))
            } else if text == "clear" {
                tab.systemPrompt = ""
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.system.cleared", comment: "")))
            } else {
                tab.systemPrompt = text
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.system.set", comment: ""), text)))
            }
        },
        SlashCommand("worktree", NSLocalizedString("slash.cmd.worktree", comment: ""), category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, _ in
            tab.useWorktree.toggle()
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.worktree.toggle", comment: ""), tab.useWorktree ? NSLocalizedString("slash.toggle.on", comment: "") : NSLocalizedString("slash.toggle.off", comment: ""))))
        },
        SlashCommand("chrome", NSLocalizedString("slash.cmd.chrome", comment: ""), category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, _ in
            tab.enableChrome.toggle()
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.chrome.toggle", comment: ""), tab.enableChrome ? NSLocalizedString("slash.toggle.on", comment: "") : NSLocalizedString("slash.toggle.off", comment: ""))))
        },
        SlashCommand("brief", NSLocalizedString("slash.cmd.brief", comment: ""), category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, _ in
            tab.enableBrief.toggle()
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.brief.toggle", comment: ""), tab.enableBrief ? NSLocalizedString("slash.toggle.on", comment: "") : NSLocalizedString("slash.toggle.off", comment: ""))))
        },

        // ── 세션 ──
        SlashCommand("stats", NSLocalizedString("slash.cmd.stats", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            let elapsed = Int(Date().timeIntervalSince(tab.startTime))
            let mins = elapsed / 60; let secs = elapsed % 60
            let stats = [
                NSLocalizedString("slash.status.stats.title", comment: ""),
                String(format: NSLocalizedString("slash.status.stats.worker", comment: ""), tab.workerName, tab.projectName),
                String(format: NSLocalizedString("slash.status.stats.model", comment: ""), tab.selectedModel.icon, tab.selectedModel.rawValue, tab.effortLevel.icon, tab.effortLevel.rawValue),
                String(format: NSLocalizedString("slash.status.stats.elapsed", comment: ""), mins, secs),
                String(format: NSLocalizedString("slash.status.stats.tokens", comment: ""), "\(tab.tokensUsed)", "\(tab.inputTokensUsed)", "\(tab.outputTokensUsed)"),
                String(format: NSLocalizedString("slash.status.stats.cost", comment: ""), String(format: "%.4f", tab.totalCost)),
                String(format: NSLocalizedString("slash.status.stats.prompts", comment: ""), tab.completedPromptCount),
                String(format: NSLocalizedString("slash.status.stats.commands", comment: ""), tab.commandCount, tab.errorCount),
                String(format: NSLocalizedString("slash.status.stats.blocks", comment: ""), tab.blocks.count),
                String(format: NSLocalizedString("slash.status.stats.files", comment: ""), tab.fileChanges.count),
            ].joined(separator: "\n")
            tab.appendBlock(.status(message: stats))
        },
        SlashCommand("restart", NSLocalizedString("slash.cmd.restart", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            tab.clearBlocks()
            tab.claudeActivity = .idle
            tab.start()
        },
        SlashCommand("continue", NSLocalizedString("slash.cmd.continue", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.continue", comment: "")))
        },
        SlashCommand("resume", NSLocalizedString("slash.cmd.resume", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.resume", comment: "")))
        },
        SlashCommand("fork", NSLocalizedString("slash.cmd.fork", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            tab.forkSession = true
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.fork", comment: "")))
        },

        // ── 화면 ──
        SlashCommand("scroll", NSLocalizedString("slash.cmd.scroll", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.scroll.tip", comment: "")))
        },
        SlashCommand("errors", NSLocalizedString("slash.cmd.errors", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            let errors = tab.blocks.filter { block in
                if block.isError { return true }
                switch block.blockType {
                case .error: return true
                case .toolError: return true
                default: return false
                }
            }
            if errors.isEmpty { tab.appendBlock(.status(message: NSLocalizedString("slash.status.no.errors", comment: ""))); return }
            let text = errors.enumerated().map { (i, e) in "  \(i+1). \(e.content.prefix(200))" }.joined(separator: "\n")
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.error.list", comment: ""), errors.count) + "\n\(text)"))
        },
        SlashCommand("files", NSLocalizedString("slash.cmd.files", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            if tab.fileChanges.isEmpty { tab.appendBlock(.status(message: NSLocalizedString("slash.status.no.file.changes", comment: ""))); return }
            let text = tab.fileChanges.map { "  \($0.action == "Write" ? "📝" : "✏️") \($0.path)" }.joined(separator: "\n")
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.file.list", comment: ""), tab.fileChanges.count) + "\n\(text)"))
        },
        SlashCommand("tokens", NSLocalizedString("slash.cmd.tokens", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            let tracker = TokenTracker.shared
            let text = [
                NSLocalizedString("slash.status.tokens.title", comment: ""),
                String(format: NSLocalizedString("slash.status.tokens.session", comment: ""), tracker.formatTokens(tab.tokensUsed), tracker.formatTokens(tab.inputTokensUsed), tracker.formatTokens(tab.outputTokensUsed)),
                String(format: NSLocalizedString("slash.status.tokens.today", comment: ""), tracker.formatTokens(tracker.todayTokens)),
                String(format: NSLocalizedString("slash.status.tokens.week", comment: ""), tracker.formatTokens(tracker.weekTokens)),
                String(format: NSLocalizedString("slash.status.tokens.cost.session", comment: ""), String(format: "%.4f", tab.totalCost)),
                String(format: NSLocalizedString("slash.status.tokens.cost.today", comment: ""), String(format: "%.4f", tracker.todayCost)),
                String(format: NSLocalizedString("slash.status.tokens.cost.week", comment: ""), String(format: "%.4f", tracker.weekCost)),
            ].joined(separator: "\n")
            tab.appendBlock(.status(message: text))
        },
        SlashCommand("usage", NSLocalizedString("slash.cmd.usage", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.usage.checking", comment: "")))
            DispatchQueue.global(qos: .userInitiated).async { [weak tab] in
                let result = ClaudeUsageFetcher.fetch()
                DispatchQueue.main.async {
                    guard let tab = tab else { return }
                    // 마지막 "조회 중" 블록 제거
                    if let lastIdx = tab.blocks.indices.last,
                       tab.blocks[lastIdx].content.contains(NSLocalizedString("slash.checking", comment: "")) {
                        tab.blocks.remove(at: lastIdx)
                    }
                    tab.appendBlock(.status(message: result))
                }
            }
        },
        SlashCommand("config", NSLocalizedString("slash.cmd.config", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            var lines = [
                NSLocalizedString("slash.status.config.title", comment: ""),
                String(format: NSLocalizedString("slash.status.config.model", comment: ""), tab.selectedModel.icon, tab.selectedModel.rawValue),
                String(format: NSLocalizedString("slash.status.config.effort", comment: ""), tab.effortLevel.icon, tab.effortLevel.rawValue),
                String(format: NSLocalizedString("slash.status.config.output", comment: ""), tab.outputMode.icon, tab.outputMode.displayName),
                String(format: NSLocalizedString("slash.status.config.permission", comment: ""), tab.permissionMode.icon, tab.permissionMode.displayName),
                String(format: NSLocalizedString("slash.status.config.budget", comment: ""), tab.maxBudgetUSD > 0 ? "$\(String(format: "%.2f", tab.maxBudgetUSD))" : NSLocalizedString("slash.status.budget.unlimited", comment: "")),
                String(format: NSLocalizedString("slash.status.config.worktree", comment: ""), tab.useWorktree ? "✅" : "❌"),
                String(format: NSLocalizedString("slash.status.config.chrome", comment: ""), tab.enableChrome ? "✅" : "❌"),
                String(format: NSLocalizedString("slash.status.config.brief", comment: ""), tab.enableBrief ? "✅" : "❌"),
            ]
            if !tab.systemPrompt.isEmpty { lines.append(String(format: NSLocalizedString("slash.status.config.system", comment: ""), String(tab.systemPrompt.prefix(50)))) }
            if !tab.allowedTools.isEmpty { lines.append(String(format: NSLocalizedString("slash.status.config.allow", comment: ""), tab.allowedTools)) }
            if !tab.disallowedTools.isEmpty { lines.append(String(format: NSLocalizedString("slash.status.config.deny", comment: ""), tab.disallowedTools)) }
            lines.append(String(format: NSLocalizedString("slash.status.config.project", comment: ""), tab.projectPath))
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },

        // ── Git ──
        SlashCommand("git", NSLocalizedString("slash.status.git.desc", comment: ""), category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak tab] in
                guard let tab else { return }
                let g = tab.gitInfo
                if !g.isGitRepo { tab.appendBlock(.status(message: NSLocalizedString("slash.status.git.not.repo", comment: ""))); return }
                let text = [
                    NSLocalizedString("slash.status.git.title", comment: ""),
                    String(format: NSLocalizedString("slash.status.git.branch", comment: ""), g.branch),
                    String(format: NSLocalizedString("slash.status.git.changed.files", comment: ""), g.changedFiles),
                    String(format: NSLocalizedString("slash.status.git.last.commit", comment: ""), g.lastCommit),
                    String(format: NSLocalizedString("slash.status.git.commit.age", comment: ""), g.lastCommitAge),
                ].joined(separator: "\n")
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("branch", NSLocalizedString("slash.cmd.branch", comment: ""), category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak tab] in
                guard let tab else { return }
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.branch.current", comment: ""), tab.gitInfo.branch.isEmpty ? NSLocalizedString("slash.status.deny.none", comment: "") : tab.gitInfo.branch)))
            }
        },

        // ── 도구 ──
        SlashCommand("allow", NSLocalizedString("slash.cmd.allow", comment: ""), usage: "<tool1,tool2,...|clear>", category: NSLocalizedString("slash.category.tools", comment: "")) { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.allow.current", comment: ""), tab.allowedTools.isEmpty ? NSLocalizedString("slash.status.allow.all", comment: "") : tab.allowedTools)))
            } else if text == "clear" {
                tab.allowedTools = ""
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.allow.cleared", comment: "")))
            } else {
                tab.allowedTools = text
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.allow.set", comment: ""), text)))
            }
        },
        SlashCommand("deny", NSLocalizedString("slash.cmd.deny", comment: ""), usage: "<tool1,tool2,...|clear>", category: NSLocalizedString("slash.category.tools", comment: "")) { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.deny.current", comment: ""), tab.disallowedTools.isEmpty ? NSLocalizedString("slash.status.deny.none", comment: "") : tab.disallowedTools)))
            } else if text == "clear" {
                tab.disallowedTools = ""
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.deny.cleared", comment: "")))
            } else {
                tab.disallowedTools = text
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.deny.set", comment: ""), text)))
            }
        },
        SlashCommand("pr", NSLocalizedString("slash.cmd.pr", comment: ""), usage: "<PR번호>", category: NSLocalizedString("slash.category.tools", comment: "")) { tab, _, args in
            guard let num = args.first else {
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.pr.usage", comment: "")))
                return
            }
            tab.fromPR = num
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.pr.context", comment: ""), num)))
        },
        SlashCommand("name", NSLocalizedString("slash.cmd.name", comment: ""), usage: "<이름>", category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, args in
            let n = args.joined(separator: " ")
            if n.isEmpty { tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.name.current", comment: ""), tab.sessionName.isEmpty ? NSLocalizedString("slash.status.deny.none", comment: "") : tab.sessionName))); return }
            tab.sessionName = n
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.name.set", comment: ""), n)))
        },
        SlashCommand("compare", NSLocalizedString("slash.cmd.compare", comment: ""), usage: "<세션1이름> <세션2이름>", category: NSLocalizedString("slash.category.session", comment: "")) { tab, manager, args in
            let allTabs = manager.userVisibleTabs

            if allTabs.count < 2 {
                tab.appendBlock(.status(message: NSLocalizedString("slash.compare.need.two", comment: "")))
                return
            }

            let tab1: TerminalTab
            let tab2: TerminalTab

            if args.count >= 2 {
                let name1 = args[0].lowercased()
                let name2 = args[1].lowercased()
                guard let t1 = allTabs.first(where: { $0.workerName.lowercased().contains(name1) }),
                      let t2 = allTabs.first(where: { $0.workerName.lowercased().contains(name2) && $0.id != t1.id }) else {
                    tab.appendBlock(.status(message: NSLocalizedString("slash.compare.not.found", comment: "") + allTabs.map(\.workerName).joined(separator: ", ")))
                    return
                }
                tab1 = t1; tab2 = t2
            } else {
                // 인자 없으면 처음 2개 비교
                guard allTabs.count >= 2 else {
                    tab.appendBlock(.status(message: NSLocalizedString("slash.compare.need.two", comment: "")))
                    return
                }
                tab1 = allTabs[0]; tab2 = allTabs[1]
            }

            let dur1 = Int(Date().timeIntervalSince(tab1.startTime))
            let dur2 = Int(Date().timeIntervalSince(tab2.startTime))

            func fmtDur(_ s: Int) -> String {
                if s < 60 { return String(format: NSLocalizedString("slash.status.duration.seconds", comment: ""), s) }
                if s < 3600 { return String(format: NSLocalizedString("slash.status.duration.minutes", comment: ""), s/60, s%60) }
                return String(format: NSLocalizedString("slash.status.duration.hours", comment: ""), s/3600, s%3600/60)
            }

            func fmtTokens(_ n: Int) -> String {
                if n >= 1000 { return String(format: "%.1fK", Double(n)/1000) }
                return "\(n)"
            }

            let cmpProcessing = NSLocalizedString("slash.status.compare.status.processing", comment: "")
            let cmpComplete = NSLocalizedString("slash.status.compare.status.complete", comment: "")
            let cmpWaiting = NSLocalizedString("slash.status.compare.status.waiting", comment: "")
            let lines = [
                NSLocalizedString("slash.status.compare.title", comment: ""),
                "══════════════════════════════════════════════════",
                "",
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.item", comment: ""), tab1.workerName, tab2.workerName),
                "─────────────────────┼──────────────────────┼──────────────────────",
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.project", comment: ""), String(tab1.projectName.prefix(18)), String(tab2.projectName.prefix(18))),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.status", comment: ""), tab1.isProcessing ? cmpProcessing : (tab1.isCompleted ? cmpComplete : cmpWaiting), tab2.isProcessing ? cmpProcessing : (tab2.isCompleted ? cmpComplete : cmpWaiting)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.model", comment: ""), tab1.selectedModel.rawValue, tab2.selectedModel.rawValue),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.tokens.in", comment: ""), fmtTokens(tab1.inputTokensUsed), fmtTokens(tab2.inputTokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.tokens.out", comment: ""), fmtTokens(tab1.outputTokensUsed), fmtTokens(tab2.outputTokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.tokens.total", comment: ""), fmtTokens(tab1.tokensUsed), fmtTokens(tab2.tokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.cost", comment: ""), String(format: "$%.4f", tab1.totalCost), String(format: "$%.4f", tab2.totalCost)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.commands", comment: ""), "\(tab1.commandCount)", "\(tab2.commandCount)"),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.file.changes", comment: ""), String(format: NSLocalizedString("slash.status.file.count", comment: ""), tab1.fileChanges.count), String(format: NSLocalizedString("slash.status.file.count", comment: ""), tab2.fileChanges.count)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.errors", comment: ""), "\(tab1.errorCount)", "\(tab2.errorCount)"),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.elapsed", comment: ""), fmtDur(dur1), fmtDur(dur2)),
                "",
                "══════════════════════════════════════════════════",
            ]

            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
        SlashCommand("timeline", NSLocalizedString("slash.cmd.timeline", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            if tab.timeline.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("slash.timeline.empty", comment: "")))
                return
            }
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            var lines = [NSLocalizedString("slash.status.timeline.title", comment: ""), "═══════════════════════════════"]
            for event in tab.timeline.suffix(30) {
                let time = df.string(from: event.timestamp)
                let icon: String
                switch event.type {
                case .started: icon = "🟢"
                case .prompt: icon = "💬"
                case .toolUse: icon = "🔧"
                case .fileChange: icon = "📝"
                case .error: icon = "❌"
                case .completed: icon = "✅"
                }
                lines.append("\(time) \(icon) \(event.type.displayName): \(event.detail)")
            }
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
        SlashCommand("sleepwork", NSLocalizedString("slash.cmd.sleepwork", comment: ""), usage: "<작업내용> [토큰예산]", category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, args in
            if args.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("slash.sleepwork.usage", comment: "")))
                return
            }
            let taskText = args.dropLast().joined(separator: " ")
            let budgetText = args.last ?? ""
            var budget: Int? = nil
            let bt = budgetText.lowercased()
            if bt.hasSuffix("k"), let n = Double(bt.dropLast()) { budget = Int(n * 1000) }
            else if bt.hasSuffix("m"), let n = Double(bt.dropLast()) { budget = Int(n * 1_000_000) }
            else if let n = Int(bt) { budget = n }

            let task = taskText.isEmpty ? budgetText : taskText  // if only 1 arg, treat as task
            if task.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("slash.sleepwork.enter.task", comment: "")))
                return
            }
            tab.startSleepWork(task: task, tokenBudget: budget)
        },
        SlashCommand("search", NSLocalizedString("slash.cmd.search", comment: ""), usage: "<검색어>", category: NSLocalizedString("slash.category.display", comment: "")) { tab, manager, args in
            let query = args.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                tab.appendBlock(.status(message: NSLocalizedString("slash.search.usage", comment: "")))
                return
            }
            let allTabs = manager.userVisibleTabs
            var results: [(tabName: String, blockContent: String, lineNum: Int)] = []

            for t in allTabs {
                for (idx, block) in t.blocks.enumerated() {
                    if block.content.localizedCaseInsensitiveContains(query) {
                        let snippet = block.content.components(separatedBy: "\n")
                            .first(where: { $0.localizedCaseInsensitiveContains(query) }) ?? String(block.content.prefix(80))
                        results.append((t.workerName, String(snippet.prefix(80)), idx))
                    }
                }
            }

            if results.isEmpty {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.search.no.results", comment: ""), query)))
                return
            }

            var lines = [String(format: NSLocalizedString("slash.status.search.results", comment: ""), query, results.count), "═══════════════════════════════"]
            for r in results.prefix(20) {
                lines.append("[\(r.tabName)] \(r.blockContent)")
            }
            if results.count > 20 {
                lines.append(String(format: NSLocalizedString("slash.status.search.more", comment: ""), results.count - 20))
            }
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
    ]

    /// /cmd 형태만 명령 모드 (경로 /path/to 제외)
    var isCommandMode: Bool {
        guard inputText.hasPrefix("/") else { return false }
        let after = String(inputText.dropFirst())
        return !after.hasPrefix("/") && !after.contains("/")
    }

    var hasTypedArgs: Bool {
        guard isCommandMode else { return false }
        let afterSlash = String(inputText.dropFirst())
        return afterSlash.contains(" ") && afterSlash.split(separator: " ").count > 1
    }

}
