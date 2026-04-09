import SwiftUI
import Combine
import DesignSystem

extension EventStreamView {
    // MARK: - Input Bars

    var fullInputBar: some View {
        VStack(spacing: 0) {
            // Settings
            HStack(spacing: 0) {
                settingGroup("Agent") {
                    ForEach(AgentProvider.allCases) { provider in
                        let installed = provider.installChecker.isInstalled
                        settingChip(
                            provider.displayName + (installed ? "" : " ✗"),
                            isSelected: tab.provider == provider,
                            color: installed ? providerColor(provider) : Theme.textMuted
                        ) {
                            selectProvider(provider)
                        }
                        .opacity(installed ? 1.0 : 0.5)
                    }
                }

                settingSep

                settingGroup("Model") {
                    if tab.provider == .claude {
                        ForEach(tab.provider.models) { model in
                            settingChip(model.displayName, isSelected: tab.selectedModel == model, color: modelColor(model)) {
                                tab.selectedModel = model
                            }
                        }
                    } else {
                        settingMenuChip(tab.selectedModel.displayName, color: modelColor(tab.selectedModel)) {
                            ForEach(tab.provider.models) { model in
                                Button(model.displayName) {
                                    tab.selectedModel = model
                                }
                            }
                        }
                    }
                }

                settingSep

                if tab.provider == .claude {
                    settingGroup("Effort") {
                        ForEach(EffortLevel.allCases) { l in
                            let name = l.rawValue.prefix(1).uppercased() + l.rawValue.dropFirst()
                            settingChip(name, isSelected: tab.effortLevel == l, color: Theme.accent) { tab.effortLevel = l }
                        }
                    }

                    settingSep

                    settingGroup("Output") {
                        ForEach(OutputMode.allCases) { m in
                            settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                        }
                    }

                    settingSep

                    settingGroup(NSLocalizedString("terminal.permission.section", comment: "")) {
                        ForEach(PermissionMode.allCases) { m in
                            settingChip(m.displayName, isSelected: tab.permissionMode == m, color: permissionColor(m)) { tab.permissionMode = m }
                                .help(m.desc)
                        }
                    }
                } else if tab.provider == .gemini {
                    settingGroup("Output") {
                        ForEach(OutputMode.allCases) { m in
                            settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                        }
                    }
                } else {
                    settingGroup("Sandbox") {
                        ForEach(CodexSandboxMode.allCases) { mode in
                            settingChip(mode.displayName, isSelected: tab.codexSandboxMode == mode, color: codexSandboxColor(mode)) {
                                tab.codexSandboxMode = mode
                            }
                        }
                    }

                    settingSep

                    settingGroup("Approval") {
                        ForEach(CodexApprovalPolicy.allCases) { mode in
                            settingChip(mode.displayName, isSelected: tab.codexApprovalPolicy == mode, color: codexApprovalColor(mode)) {
                                tab.codexApprovalPolicy = mode
                            }
                        }
                    }

                    settingSep

                    settingGroup("Output") {
                        ForEach(OutputMode.allCases) { m in
                            settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                        }
                    }
                }

                Spacer(minLength: 4)

                if tab.totalCost > 0 {
                    Text(String(format: "$%.4f", tab.totalCost))
                        .font(Theme.chrome(9, weight: .semibold)).foregroundColor(Theme.yellow)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.yellow.opacity(0.06)).cornerRadius(4)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Theme.bgSurface.opacity(0.6))

            // 설정 ↔ 입력 구분선
            Rectangle().fill(Theme.border).frame(height: 1)

            if let workflowTab = workflowDisplayTab, !workflowTab.workflowTimelineStages.isEmpty {
                workflowProgressBar(workflowTab)
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // 슬립워크 상태 바
            if tab.sleepWorkTask != nil {
                sleepWorkStatusBar
            }

            // 첨부 이미지 미리보기
            if !tab.attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tab.attachedImages, id: \.absoluteString) { url in
                            ZStack(alignment: .topTrailing) {
                                if let nsImage = NSImage(contentsOf: url) {
                                    Image(nsImage: nsImage)
                                        .resizable().scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                                } else {
                                    RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                        .frame(width: 48, height: 48)
                                        .overlay(Image(systemName: "photo").foregroundColor(Theme.textDim))
                                }
                                Button(action: { tab.attachedImages.removeAll { $0 == url } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14)).foregroundColor(Theme.red)
                                        .background(Circle().fill(Theme.bgCard).frame(width: 12, height: 12))
                                }.buttonStyle(.plain).offset(x: 4, y: -4)
                            }
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 4)
                }
                .background(Theme.bgSurface.opacity(0.5))
            }

            // Input (auto-growing)
            HStack(alignment: .bottom, spacing: 8) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 16)
                    Text(tab.projectName).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
                    Text(">").font(Theme.chrome(12, weight: .semibold)).foregroundStyle(Theme.accentBackground)
                }.padding(.bottom, 4)

                // Auto-growing TextEditor
                ZStack(alignment: .topLeading) {
                    // Hidden text for height calculation
                    Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : inputText)
                        .font(Theme.monoNormal).foregroundColor(.clear)
                        .padding(.horizontal, 4).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                    // Actual editor
                    TextEditor(text: $inputText)
                        .font(Theme.monoNormal).foregroundColor(Theme.textPrimary)
                        .focused($isFocused)
                        .disabled(tab.isProcessing)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 0).padding(.vertical, 4)
                        .accessibilityLabel(NSLocalizedString("terminal.input.a11y", comment: ""))
                    // Placeholder (on top visually but doesn't intercept clicks)
                    if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(tab.isProcessing ? NSLocalizedString("terminal.input.placeholder.running", comment: "") : NSLocalizedString("terminal.input.placeholder", comment: ""))
                            .font(Theme.monoNormal).foregroundColor(Theme.textDim.opacity(0.5))
                            .padding(.horizontal, 4).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 32, maxHeight: 120)
                .onKeyPress(.return, phases: .down) { event in
                    if event.modifiers.contains(.shift) {
                        return .ignored // Shift+Enter → 줄바꿈 (기본 동작)
                    }
                    submit()
                    return .handled // Enter → 전송
                }
                .onKeyPress(phases: .down) { event in
                    guard isCommandMode else { return .ignored }
                    return handleCommandKeyNavigation(event)
                }
                .onChange(of: inputText) { old, new in
                    selectedCommandIndex = 0
                    // 타이핑 이벤트 발행 (플러그인 이펙트용)
                    if new.count > old.count && new.count - old.count <= 2 {
                        PluginHost.shared.fireEvent(.onPromptKeyPress)
                    }
                    // Detect paste: if many new lines appeared at once
                    let addedLen = new.count - old.count
                    if addedLen > 0 {
                        let added = String(new.suffix(addedLen))
                        let newLines = added.components(separatedBy: .newlines).count - 1
                        if newLines >= 4 {
                            // Collapse pasted text into a placeholder
                            pasteCounter += 1
                            let chunkId = pasteCounter
                            let lineCount = added.components(separatedBy: .newlines).count
                            pastedChunks.append((id: chunkId, text: added))
                            let placeholder = "[Pasted text #\(chunkId) +\(lineCount) lines]"
                            // Replace the pasted portion with placeholder
                            let prefix = String(new.prefix(new.count - addedLen))
                            inputText = prefix + placeholder
                        }
                    }
                }

                // 이미지 첨부
                Button(action: { pickImage() }) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: Theme.iconSize(11)))
                        .foregroundColor(tab.attachedImages.isEmpty ? Theme.textDim : Theme.cyan)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("terminal.help.attach.image", comment: ""))
                .padding(.bottom, 4)

                Button(action: { showSleepWorkSetup = true }) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: Theme.iconSize(11)))
                        .foregroundColor(Theme.purple)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("terminal.help.sleepwork", comment: ""))
                .padding(.bottom, 4)

                if tab.isProcessing {
                    Button(action: { tab.cancelProcessing() }) {
                        Label("Stop", systemImage: "stop.fill").font(Theme.chrome(9, weight: .medium))
                            .foregroundColor(Theme.red).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.red.opacity(0.1)).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.bottom, 4)
                } else {
                    Button(action: { submit() }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: Theme.iconSize(20)))
                            .foregroundColor(inputText.isEmpty ? Theme.textDim : Theme.accent)
                    }.buttonStyle(.plain).disabled(inputText.isEmpty).padding(.bottom, 4)
                }
            }.padding(.horizontal, 14).padding(.vertical, 4)
        }
        .background(Theme.bgInput)
        .overlay(
            VStack(spacing: 0) {
                Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1)
                Spacer()
                Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1)
            }
        )
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    guard let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let ext = url.pathExtension.lowercased()
                    if ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"].contains(ext) {
                        DispatchQueue.main.async { tab.attachedImages.append(url) }
                    }
                }
            }
            return true
        }
    }

    var compactInputBar: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ZStack(alignment: .topLeading) {
                Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : inputText)
                    .font(Theme.monoSmall).foregroundColor(.clear)
                    .padding(.horizontal, 4).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                TextEditor(text: $inputText)
                    .font(Theme.monoSmall).foregroundColor(Theme.textPrimary)
                    .focused($isFocused).disabled(tab.isProcessing)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 0).padding(.vertical, 2)
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(NSLocalizedString("terminal.input.hint", comment: "")).font(Theme.monoSmall).foregroundColor(Theme.textDim.opacity(0.5))
                        .padding(.horizontal, 4).padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 28, maxHeight: 100)
            .onKeyPress(.return, phases: .down) { event in
                if event.modifiers.contains(.shift) { return .ignored }
                submit(); return .handled
            }
            .onKeyPress(phases: .down) { event in
                guard isCommandMode else { return .ignored }
                return handleCommandKeyNavigation(event)
            }

            if tab.isProcessing {
                Button(action: { tab.cancelProcessing() }) {
                    Image(systemName: "stop.fill").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.red)
                }.buttonStyle(.plain).padding(.bottom, 4)
            } else {
                Button(action: { submit() }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: Theme.iconSize(14)))
                        .foregroundColor(inputText.isEmpty ? Theme.textDim : Theme.accent)
                }.buttonStyle(.plain).disabled(inputText.isEmpty).padding(.bottom, 4)
            }
        }.padding(.horizontal, 8).padding(.vertical, 3).background(Theme.bgInput)
    }

    var sleepWorkStatusBar: some View {
        let budget = tab.sleepWorkTokenBudget ?? 0
        let used = tab.tokensUsed - tab.sleepWorkStartTokens
        let ratio = budget > 0 ? Double(used) / Double(budget) : 0
        let color: Color = ratio < 1.0 ? Theme.purple : (ratio < 2.0 ? Theme.yellow : Theme.red)

        return HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.purple)
            Text(NSLocalizedString("terminal.sleepwork.running", comment: "")).font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.purple)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.border.opacity(0.15)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(min(ratio, 2.0) / 2.0)), height: 4)
                }
            }.frame(height: 4).frame(maxWidth: 120)

            if budget > 0 {
                Text("\(formatK(used)) / \(formatK(budget))")
                    .font(Theme.chrome(9, weight: .bold)).foregroundColor(color)
            }

            Spacer()

            Button(action: {
                tab.sleepWorkTask = nil
                tab.cancelProcessing()
            }) {
                Text(NSLocalizedString("terminal.sleepwork.stop", comment: "")).font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.red)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Theme.purple.opacity(0.06))
    }

    func formatK(_ n: Int) -> String {
        if n >= 1000000 { return String(format: "%.1fM", Double(n) / 1000000) }
        if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }

    func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString("terminal.image.attach.title", comment: "")
        panel.message = NSLocalizedString("terminal.image.pick.message", comment: "")
        if panel.runModal() == .OK {
            tab.attachedImages.append(contentsOf: panel.urls)
        }
    }

    func expandPastedChunks(_ text: String) -> String {
        var result = text
        for chunk in pastedChunks {
            let placeholder = "[Pasted text #\(chunk.id) +\(chunk.text.components(separatedBy: .newlines).count) lines]"
            result = result.replacingOccurrences(of: placeholder, with: chunk.text)
        }
        return result
    }

    func submit() {
        let raw = expandPastedChunks(inputText)
        let p = raw.trimmingCharacters(in: .whitespaces); guard !p.isEmpty else { return }
        guard !tab.isProcessing else { return }

        // Slash command handling — /cmd 형태만 (경로 /path/to/file 제외)
        let afterSlash = String(p.dropFirst())
        let looksLikeCommand = p.hasPrefix("/") && !afterSlash.hasPrefix("/") && !afterSlash.contains("/")
        if looksLikeCommand {
            let parts = afterSlash.split(separator: " ", maxSplits: 1).map(String.init)
            let cmdName = parts.first?.lowercased() ?? ""
            let args = parts.count > 1 ? parts[1].split(separator: " ").map(String.init) : []

            // 정확히 매칭되는 명령어만 실행
            if let cmd = Self.allSlashCommands.first(where: { $0.name == cmdName }) {
                inputText = ""; pastedChunks.removeAll(); selectedCommandIndex = 0
                tab.appendBlock(.userPrompt, content: "/\(cmd.name)" + (args.isEmpty ? "" : " " + args.joined(separator: " ")))
                cmd.action(tab, manager, args)
                return
            }
        }

        inputText = ""; pastedChunks.removeAll()
        tab.sendPrompt(p)
        AchievementManager.shared.addXP(5); AchievementManager.shared.incrementCommand()
    }

    // ═══════════════════════════════════════════
}
