import SwiftUI
import DesignSystem

extension NewTabSheet {
    // MARK: - 세션 설정 화면

    var sessionConfigView: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "plus.circle.fill",
                iconColor: Theme.accent,
                title: NSLocalizedString("session.new", comment: ""),
                subtitle: NSLocalizedString("terminal.new.subtitle", comment: "")
            )

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: Theme.sp4) {
                    sessionConfigQuickStartSection
                    sessionConfigProjectSection
                    sessionConfigExecutionSection
                    sessionConfigTerminalSection
                    sessionConfigAdvancedToggle
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            sessionConfigBottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSavePreset) {
            SavePresetSheet(draft: currentDraftSnapshot())
                .dofficeSheetPresentation()
        }
    }

    @ViewBuilder
    var sessionConfigQuickStartSection: some View {
        configSection(title: NSLocalizedString("terminal.quickstart", comment: ""), subtitle: NSLocalizedString("terminal.quickstart.subtitle", comment: "")) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    quickStartActionsRow
                    quickStartActionsColumn
                }

                optionGroup(title: NSLocalizedString("terminal.recommended.presets", comment: "")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(NewSessionPreset.allCases) { preset in
                            selectionChip(
                                title: preset.title,
                                subtitle: preset.subtitle,
                                symbol: preset.symbol,
                                tint: preset.tint,
                                selected: activePresetId == preset.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    activePresetId = preset.id
                                }
                                applyPreset(preset)
                            }
                        }
                    }
                }

                // 사용자 저장 프리셋
                if !CustomPresetStore.shared.presets.isEmpty {
                    optionGroup(title: NSLocalizedString("terminal.my.presets", comment: "")) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                            ForEach(CustomPresetStore.shared.presets) { preset in
                                selectionChip(
                                    title: preset.name,
                                    subtitle: String(format: NSLocalizedString("terminal.preset.custom.subtitle", comment: ""), preset.draft.terminalCount, preset.draft.selectedModel),
                                    symbol: preset.icon,
                                    tint: preset.tintColor,
                                    selected: activePresetId == "custom-\(preset.id)"
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        activePresetId = "custom-\(preset.id)"
                                    }
                                    applyDraft(preset.draft)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        CustomPresetStore.shared.delete(preset)
                                    } label: {
                                        Label(NSLocalizedString("terminal.preset.delete", comment: ""), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                if !favoriteProjects.isEmpty {
                    optionGroup(title: NSLocalizedString("terminal.favorite.projects", comment: "")) {
                        projectSuggestionScroller(projects: favoriteProjects)
                    }
                }

                if !recentProjects.isEmpty {
                    optionGroup(title: NSLocalizedString("terminal.recent.projects", comment: "")) {
                        projectSuggestionScroller(projects: recentProjects)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var sessionConfigProjectSection: some View {
        configSection(title: NSLocalizedString("terminal.config.project", comment: ""), subtitle: NSLocalizedString("terminal.config.project.subtitle", comment: "")) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(NSLocalizedString("terminal.project.path", comment: ""))
                    HStack(spacing: 8) {
                        TextField("/path/to/project", text: $projectPath)
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .appFieldStyle(emphasized: true)
                            .accessibilityLabel(NSLocalizedString("terminal.project.path.a11y", comment: ""))
                            .accessibilityHint(NSLocalizedString("terminal.project.path.a11y.hint", comment: ""))

                        Button("Browse") {
                            let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                            if p.runModal() == .OK, let u = p.url {
                                projectPath = normalizedProjectPath(u.path)
                                if projectName.isEmpty { projectName = u.lastPathComponent }
                            }
                        }
                        .buttonStyle(.plain)
                        .font(Theme.mono(9, weight: .bold))
                        .appButtonSurface(tone: .neutral, compact: true)
                        .accessibilityLabel(NSLocalizedString("terminal.project.folder.find.a11y", comment: ""))
                    }
                    .onChange(of: projectPath) { _, _ in
                        pathError = nil
                    }
                    if let error = pathError {
                        Text(error)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.red)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(NSLocalizedString("terminal.project.name", comment: ""))
                    TextField("e.g. my-project", text: $projectName)
                        .textFieldStyle(.plain)
                        .font(Theme.monoSmall)
                        .appFieldStyle()
                        .accessibilityLabel(NSLocalizedString("terminal.project.name.a11y", comment: ""))
                }
            }
        }
    }

    @ViewBuilder
    var sessionConfigExecutionSection: some View {
        configSection(title: NSLocalizedString("terminal.config.execution", comment: ""), subtitle: NSLocalizedString("terminal.config.execution.subtitle", comment: "")) {
            VStack(alignment: .leading, spacing: 14) {
                optionGroup(title: "Agent") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(AgentProvider.allCases) { provider in
                            let installed = provider.installChecker.isInstalled
                            selectionChip(
                                title: provider.displayName + (installed ? "" : " (미설치)"),
                                subtitle: installed ? providerSubtitle(provider) : provider.installCommand,
                                symbol: providerSymbol(provider),
                                tint: installed ? providerChipTint(provider) : Theme.textMuted,
                                selected: selectedProvider == provider
                            ) {
                                selectProvider(provider)
                            }
                            .opacity(installed ? 1.0 : 0.5)
                        }
                    }
                }

                optionGroup(title: NSLocalizedString("terminal.config.model", comment: "")) {
                    if selectedProvider == .claude {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            ForEach(selectedProvider.models) { model in
                                selectionChip(
                                    title: model.displayName,
                                    subtitle: model.isRecommended ? NSLocalizedString("terminal.config.model.recommended", comment: "") : nil,
                                    symbol: "circle.fill",
                                    tint: modelTint(model),
                                    selected: selectedModel == model
                                ) {
                                    selectedModel = model
                                }
                            }
                        }
                    } else {
                        Menu {
                            ForEach(selectedProvider.models) { model in
                                Button(model.displayName) {
                                    selectedModel = model
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: Theme.iconSize(10), weight: .semibold))
                                    .foregroundColor(modelTint(selectedModel))
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedModel.displayName)
                                        .font(Theme.mono(9, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Codex 모델 선택")
                                        .font(Theme.mono(7))
                                        .foregroundColor(Theme.textDim)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(modelTint(selectedModel).opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(modelTint(selectedModel).opacity(0.24), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }
                }

                if selectedProvider == .claude {
                    optionGroup(title: "Effort") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(EffortLevel.allCases) { level in
                                selectionChip(
                                    title: effortTitle(level),
                                    subtitle: nil,
                                    symbol: effortSymbol(level),
                                    tint: effortTint(level),
                                    selected: effortLevel == level
                                ) {
                                    effortLevel = level
                                }
                            }
                        }
                    }

                    optionGroup(title: NSLocalizedString("terminal.config.permission", comment: "")) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                            ForEach(PermissionMode.allCases) { mode in
                                selectionChip(
                                    title: mode.displayName,
                                    subtitle: mode.desc,
                                    symbol: permissionSymbol(mode),
                                    tint: permissionTint(mode),
                                    selected: permissionMode == mode
                                ) {
                                    permissionMode = mode
                                }
                            }
                        }
                    }
                } else {
                    optionGroup(title: "Sandbox") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            ForEach(CodexSandboxMode.allCases) { mode in
                                selectionChip(
                                    title: mode.displayName,
                                    subtitle: mode.shortLabel,
                                    symbol: "square.3.layers.3d.down.right",
                                    tint: codexSandboxColor(mode),
                                    selected: codexSandboxMode == mode
                                ) {
                                    codexSandboxMode = mode
                                }
                            }
                        }
                    }

                    optionGroup(title: "Approval") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            ForEach(CodexApprovalPolicy.allCases) { mode in
                                selectionChip(
                                    title: mode.displayName,
                                    subtitle: mode.shortLabel,
                                    symbol: "hand.raised.fill",
                                    tint: codexApprovalColor(mode),
                                    selected: codexApprovalPolicy == mode
                                ) {
                                    codexApprovalPolicy = mode
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var quickStartActionsRow: some View {
        HStack(spacing: 8) {
            lastDraftButton
            if !projectPath.isEmpty {
                favoriteProjectButton
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    var quickStartActionsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            lastDraftButton
            if !projectPath.isEmpty {
                favoriteProjectButton
            }
        }
    }

    var lastDraftButton: some View {
        Button(action: { applyLastDraftIfAvailable() }) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Text(NSLocalizedString("terminal.load.last.settings", comment: ""))
            }
            .font(Theme.mono(9, weight: .bold))
            .appButtonSurface(tone: .neutral, compact: true)
        }
        .buttonStyle(.plain)
        .disabled(preferences.lastDraft == nil)
        .accessibilityLabel(NSLocalizedString("terminal.load.last.a11y", comment: ""))
    }

    var favoriteProjectButton: some View {
        Button(action: {
            preferences.toggleFavorite(projectName: resolvedProjectName, projectPath: projectPath)
        }) {
            HStack(spacing: 6) {
                Image(systemName: isCurrentProjectFavorite ? "star.fill" : "star")
                Text(isCurrentProjectFavorite ? NSLocalizedString("terminal.favorite.on", comment: "") : NSLocalizedString("terminal.favorite.off", comment: ""))
            }
            .font(Theme.mono(9, weight: .bold))
            .appButtonSurface(tone: .yellow, compact: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrentProjectFavorite ? NSLocalizedString("terminal.favorite.a11y.on", comment: "") : NSLocalizedString("terminal.favorite.a11y.off", comment: ""))
    }

    @ViewBuilder
    var sessionConfigTerminalSection: some View {
        configSection(title: NSLocalizedString("terminal.config.terminal", comment: ""), subtitle: NSLocalizedString("terminal.config.terminal.subtitle", comment: "")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionLabel(NSLocalizedString("terminal.config.terminal.count", comment: ""))
                    Spacer()
                    Text(String(format: NSLocalizedString("terminal.count.items", comment: ""), terminalCount))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                }

                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 4, 5], id: \.self) { n in
                        Button(action: {
                            withAnimation(sheetAnimation) {
                                setTerminalCount(n)
                            }
                        }) {
                            VStack(spacing: 4) {
                                HStack(spacing: 2) {
                                    ForEach(0..<n, id: \.self) { i in
                                        let colorIdx = (manager.userVisibleTabCount + i) % Theme.workerColors.count
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.workerColors[colorIdx])
                                            .frame(width: n <= 3 ? 10 : 7, height: 12)
                                    }
                                }
                                Text("\(n)")
                                    .font(Theme.mono(9, weight: terminalCount == n ? .bold : .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(terminalCount == n ? Theme.accent.opacity(0.08) : Theme.bgSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(terminalCount == n ? Theme.accent.opacity(0.24) : Theme.border.opacity(0.22), lineWidth: 1)
                            )
                            .foregroundColor(terminalCount == n ? Theme.accent : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: NSLocalizedString("terminal.config.terminal.n.a11y", comment: ""), n))
                        .accessibilityValue(terminalCount == n ? NSLocalizedString("terminal.config.terminal.selected", comment: "") : NSLocalizedString("terminal.config.terminal.unselected", comment: ""))
                    }
                }

                if terminalCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("terminal.config.task.per.terminal", comment: ""))
                            .font(Theme.mono(9, weight: .medium))
                            .foregroundColor(Theme.textDim)
                        ForEach(tasks.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                let colorIdx = (manager.userVisibleTabCount + i) % Theme.workerColors.count
                                Circle().fill(Theme.workerColors[colorIdx]).frame(width: 8, height: 8)
                                Text("#\(i + 1)")
                                    .font(Theme.mono(8, weight: .bold))
                                    .foregroundColor(Theme.textDim)
                                    .frame(width: 18)
                                TextField(NSLocalizedString("terminal.config.task.placeholder", comment: ""), text: $tasks[i])
                                    .textFieldStyle(.plain)
                                    .font(Theme.mono(10))
                                    .appFieldStyle()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var sessionConfigAdvancedToggle: some View {
        Button(action: {
            withAnimation(sheetAnimation) {
                showAdvanced.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                    .font(.system(size: Theme.iconSize(9), weight: .bold))
                    .foregroundColor(Theme.textDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("terminal.config.advanced", comment: ""))
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(NSLocalizedString("terminal.config.advanced.desc", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                if hasAdvancedOptions {
                    Text(NSLocalizedString("terminal.config.advanced.set", comment: ""))
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.green.opacity(0.10)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appPanelStyle(padding: 14, radius: 14, fill: Theme.bgCard.opacity(0.96), strokeOpacity: 0.18, shadow: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showAdvanced ? NSLocalizedString("terminal.config.advanced.collapse.a11y", comment: "") : NSLocalizedString("terminal.config.advanced.expand.a11y", comment: ""))

        if showAdvanced {
            advancedOptionsView
        }
    }

    @ViewBuilder
    var sessionConfigBottomBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(Theme.mono(10, weight: .bold))
                    .appButtonSurface(tone: .neutral)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
            .accessibilityLabel(NSLocalizedString("terminal.cancel.new.a11y", comment: ""))

            Button(action: { showSavePreset = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: Theme.iconSize(9)))
                    Text(NSLocalizedString("terminal.save.preset", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                }
                .appButtonSurface(tone: .neutral, compact: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("terminal.save.preset.a11y", comment: ""))

            Spacer()
            Button(action: { handleCreateButtonTapped() }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: Theme.iconSize(9), weight: .bold))
                    Text(isCreatingSessions
                         ? NSLocalizedString("status.running", comment: "")
                         : (terminalCount > 1 ? String(format: NSLocalizedString("terminal.create.count", comment: ""), terminalCount) : "Create"))
                        .font(Theme.mono(10, weight: .bold))
                }
                .appButtonSurface(tone: .accent, prominent: true)
            }
            .buttonStyle(.plain).keyboardShortcut(.return)
            .disabled((projectPath.isEmpty && projectName.isEmpty) || isCreatingSessions)
            .accessibilityLabel(terminalCount > 1 ? String(format: NSLocalizedString("terminal.create.sessions.a11y", comment: ""), terminalCount) : NSLocalizedString("terminal.create.session.a11y", comment: ""))
        }.padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.bg)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
    }

    // MARK: - 고급 옵션

    var hasAdvancedOptions: Bool {
        !systemPrompt.isEmpty || maxBudget != "" || !allowedTools.isEmpty ||
        !disallowedTools.isEmpty || !additionalDirs.isEmpty || continueSession || useWorktree
    }

    var advancedOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 시스템 프롬프트
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.purple)
                    Text(NSLocalizedString("terminal.system.prompt", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                TextField(NSLocalizedString("terminal.system.prompt.placeholder", comment: ""), text: $systemPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .lineLimit(2...4)
                    .appFieldStyle()
            }

            // 예산 제한
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.yellow)
                        Text(NSLocalizedString("terminal.budget.limit", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    }
                    TextField(NSLocalizedString("terminal.budget.unlimited", comment: ""), text: $maxBudget)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(10))
                        .frame(width: 100)
                        .appFieldStyle()
                }
                Spacer()

                // 세션 이어하기
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $continueSession) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.up.right").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.cyan)
                            Text(NSLocalizedString("terminal.resume.conversation", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small)
                }
            }

            // 워크트리
            Toggle(isOn: $useWorktree) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
                    Text(NSLocalizedString("terminal.git.worktree", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("--worktree").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }.toggleStyle(.switch).controlSize(.small)

            // 도구 제한
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.orange)
                    Text(NSLocalizedString("terminal.allowed.tools", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text(NSLocalizedString("terminal.tools.comma.sep", comment: "")).font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField(NSLocalizedString("terminal.allowed.tools.placeholder", comment: ""), text: $allowedTools)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .appFieldStyle()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.shield.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.red)
                    Text(NSLocalizedString("terminal.blocked.tools", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text(NSLocalizedString("terminal.tools.comma.sep", comment: "")).font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField(NSLocalizedString("terminal.blocked.tools.placeholder", comment: ""), text: $disallowedTools)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .appFieldStyle()
            }

            // 추가 디렉토리
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus").font(.system(size: Theme.iconSize(9))).foregroundStyle(Theme.accentBackground)
                    Text(NSLocalizedString("terminal.additional.dirs", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                HStack(spacing: 4) {
                    TextField(NSLocalizedString("terminal.additional.dir.placeholder", comment: ""), text: $additionalDir)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(10))
                        .appFieldStyle()
                    Button(action: {
                        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                        if p.runModal() == .OK, let u = p.url { additionalDir = u.path }
                    }) {
                        Image(systemName: "folder").font(.system(size: Theme.iconSize(10))).foregroundStyle(Theme.accentBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("terminal.additional.dir.select.a11y", comment: ""))
                    Button(action: {
                        if !additionalDir.isEmpty {
                            additionalDirs.append(additionalDir); additionalDir = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(additionalDir.isEmpty)
                    .accessibilityLabel(NSLocalizedString("terminal.additional.dir.add.a11y", comment: ""))
                }
                if !additionalDirs.isEmpty {
                    ForEach(additionalDirs.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill").font(.system(size: Theme.iconSize(8))).foregroundColor(Theme.accent.opacity(0.6))
                            Text(additionalDirs[i]).font(Theme.mono(9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                            Spacer()
                            Button(action: { additionalDirs.remove(at: i) }) {
                                Image(systemName: "xmark").font(Theme.scaled(7, weight: .bold)).foregroundColor(Theme.red)
                            }.buttonStyle(.plain)
                        }.padding(.leading, 8)
                    }
                }
            }
        }
        .appPanelStyle(padding: 16, radius: 14, fill: Theme.bgCard.opacity(0.96), strokeOpacity: 0.18, shadow: false)
    }

    func configSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.mono(11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }

            content()
        }
        .appPanelStyle(fill: Theme.bgCard.opacity(0.98), strokeOpacity: Theme.borderDefault)
    }

    func optionGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            content()
        }
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.mono(9, weight: .bold))
            .foregroundColor(Theme.textDim)
    }

    func selectionChip(
        title: String,
        subtitle: String?,
        symbol: String,
        tint: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: Theme.iconSize(10), weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? tint.opacity(0.10) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? tint.opacity(0.24) : Theme.border.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityValue(selected ? NSLocalizedString("terminal.option.selected.a11y", comment: "") : NSLocalizedString("terminal.option.unselected.a11y", comment: ""))
        .accessibilityHint(NSLocalizedString("terminal.option.select.a11y.hint", comment: ""))
    }

    func modelTint(_ model: ClaudeModel) -> Color {
        switch model {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
        case .gpt54: return Theme.accent
        case .gpt54Mini: return Theme.cyan
        case .gpt53Codex: return Theme.orange
        case .gpt52Codex: return Theme.orange
        case .gpt52: return Theme.green
        case .gpt51CodexMax: return Theme.red
        case .gpt51CodexMini: return Theme.yellow
        case .gemini25Pro: return Theme.cyan
        case .gemini25Flash: return Theme.green
        }
    }

    func effortTitle(_ level: EffortLevel) -> String {
        switch level {
        case .low: return NSLocalizedString("terminal.effort.low", comment: "")
        case .medium: return NSLocalizedString("terminal.effort.medium", comment: "")
        case .high: return NSLocalizedString("terminal.effort.high", comment: "")
        case .max: return NSLocalizedString("terminal.effort.max", comment: "")
        }
    }

    func effortSymbol(_ level: EffortLevel) -> String {
        switch level {
        case .low: return "tortoise.fill"
        case .medium: return "figure.walk"
        case .high: return "figure.run"
        case .max: return "flame.fill"
        }
    }

    func effortTint(_ level: EffortLevel) -> Color {
        switch level {
        case .low: return Theme.green
        case .medium: return Theme.accent
        case .high: return Theme.orange
        case .max: return Theme.red
        }
    }

    func permissionSymbol(_ mode: PermissionMode) -> String {
        switch mode {
        case .acceptEdits: return "square.and.pencil"
        case .bypassPermissions: return "bolt.fill"
        case .auto: return "gearshape.2.fill"
        case .defaultMode: return "shield.fill"
        case .plan: return "list.bullet.clipboard.fill"
        }
    }

    func permissionTint(_ mode: PermissionMode) -> Color {
        switch mode {
        case .acceptEdits: return Theme.orange
        case .bypassPermissions: return Theme.yellow
        case .auto: return Theme.cyan
        case .defaultMode: return Theme.textSecondary
        case .plan: return Theme.purple
        }
    }

    func codexSandboxColor(_ mode: CodexSandboxMode) -> Color {
        switch mode {
        case .readOnly: return Theme.green
        case .workspaceWrite: return Theme.cyan
        case .dangerFullAccess: return Theme.red
        }
    }

    func codexApprovalColor(_ mode: CodexApprovalPolicy) -> Color {
        switch mode {
        case .untrusted: return Theme.green
        case .onRequest: return Theme.orange
        case .never: return Theme.yellow
        }
    }

    var resolvedProjectName: String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !projectPath.isEmpty { return (projectPath as NSString).lastPathComponent }
        return ""
    }

    func projectSuggestionScroller(projects: [NewSessionProjectRecord]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(projects) { project in
                    Button(action: { applyProjectSuggestion(project) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: project.isFavorite ? "star.fill" : "folder.fill")
                                    .font(.system(size: Theme.iconSize(9), weight: .semibold))
                                    .foregroundColor(project.isFavorite ? Theme.yellow : Theme.accent)
                                Text(project.name)
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                            }
                            Text(project.path)
                                .font(Theme.mono(7))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(1)
                            Text(project.lastUsedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(Theme.mono(7, weight: .medium))
                                .foregroundColor(Theme.textDim)
                        }
                        .frame(width: 180, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: NSLocalizedString("terminal.project.a11y.label", comment: ""), project.name))
                    .accessibilityValue(project.isFavorite ? NSLocalizedString("terminal.project.a11y.favorite", comment: "") : NSLocalizedString("terminal.project.a11y.recent", comment: ""))
                    .accessibilityHint(NSLocalizedString("terminal.project.a11y.hint", comment: ""))
                }
            }
            .padding(.vertical, 1)
        }
    }

    func applyProjectSuggestion(_ project: NewSessionProjectRecord) {
        projectName = project.name
        projectPath = project.path
    }

    func applyPreset(_ preset: NewSessionPreset) {
        switch preset {
        case .balanced:
            selectedModel = .sonnet
            effortLevel = .medium
            permissionMode = .bypassPermissions
            setTerminalCount(1)
            continueSession = false
            useWorktree = false
        case .planFirst:
            selectedModel = .sonnet
            effortLevel = .medium
            permissionMode = .plan
            setTerminalCount(1)
            continueSession = false
            useWorktree = false
        case .safeReview:
            selectedModel = .sonnet
            effortLevel = .high
            permissionMode = .defaultMode
            setTerminalCount(1)
            continueSession = true
            useWorktree = false
        case .parallelBuild:
            selectedModel = .sonnet
            effortLevel = .high
            permissionMode = .bypassPermissions
            setTerminalCount(3)
            continueSession = false
            useWorktree = true
        }
    }

    func applyCustomPreset(_ preset: CustomSessionPreset) {
        applyDraft(preset.draft)
    }

    func currentDraftSnapshot() -> NewSessionDraftSnapshot {
        NewSessionDraftSnapshot(
            selectedModel: selectedModel.rawValue,
            effortLevel: effortLevel.rawValue,
            permissionMode: permissionMode.rawValue,
            codexSandboxMode: codexSandboxMode.rawValue,
            codexApprovalPolicy: codexApprovalPolicy.rawValue,
            terminalCount: terminalCount,
            systemPrompt: systemPrompt,
            maxBudget: maxBudget,
            allowedTools: allowedTools,
            disallowedTools: disallowedTools,
            additionalDirs: additionalDirs,
            continueSession: continueSession,
            useWorktree: useWorktree
        )
    }

    func applyDraft(_ draft: NewSessionDraftSnapshot) {
        if let model = ClaudeModel(rawValue: draft.selectedModel) {
            selectedModel = model
        }
        if let level = EffortLevel(rawValue: draft.effortLevel) {
            effortLevel = level
        }
        if let mode = PermissionMode(rawValue: draft.permissionMode) {
            permissionMode = mode
        }
        if let mode = CodexSandboxMode(rawValue: draft.codexSandboxMode) {
            codexSandboxMode = mode
        }
        if let mode = CodexApprovalPolicy(rawValue: draft.codexApprovalPolicy) {
            codexApprovalPolicy = mode
        }
        setTerminalCount(max(1, min(5, draft.terminalCount)))
        systemPrompt = draft.systemPrompt
        maxBudget = draft.maxBudget
        allowedTools = draft.allowedTools
        disallowedTools = draft.disallowedTools
        additionalDirs = draft.additionalDirs
        continueSession = draft.continueSession
        useWorktree = draft.useWorktree
    }

    func applyLastDraftIfAvailable() {
        guard let draft = preferences.lastDraft else { return }
        applyDraft(draft)
    }

    func bootstrapFromLastDraftIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        if let draft = preferences.lastDraft {
            applyDraft(draft)
        }
    }

    func setTerminalCount(_ n: Int) {
        terminalCount = n
        while tasks.count < n { tasks.append("") }
        while tasks.count > n { tasks.removeLast() }
    }

    func normalizedProjectPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expanded, isDirectory: true)
        let standardized = baseURL.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: standardized) else { return standardized }
        return baseURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    var isCurrentProjectTrusted: Bool {
        let normalized = normalizedProjectPath(projectPath)
        guard !normalized.isEmpty else { return true }
        return preferences.isTrusted(projectPath: normalized)
    }

    func validateSelectedProjectPath() -> Bool {
        let normalized = normalizedProjectPath(projectPath)
        if !normalized.isEmpty {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: normalized, isDirectory: &isDir) || !isDir.boolValue {
                pathError = NSLocalizedString("terminal.path.error", comment: "")
                return false
            }
        }
        pathError = nil
        return true
    }

    func handleCreateButtonTapped() {
        guard !isCreatingSessions else { return }
        guard validateSelectedProjectPath() else { return }
        guard ensureProviderAvailable(selectedProvider) else { return }

        if !projectPath.isEmpty && !isCurrentProjectTrusted {
            withAnimation(sheetAnimation) {
                showTrustPrompt = true
            }
            return
        }

        launchSessionsAfterConfirmation()
    }

    func approveFolderTrustAndLaunch() {
        guard !isCreatingSessions else { return }

        preferences.trust(projectPath: projectPath)
        withAnimation(sheetAnimation) {
            showTrustPrompt = false
        }

        launchSessionsAfterConfirmation()
    }

    func launchSessionsAfterConfirmation() {
        guard !isCreatingSessions else { return }
        guard ensureProviderAvailable(selectedProvider) else { return }

        let normalizedPath = normalizedProjectPath(projectPath)
        let path = normalizedPath.isEmpty ? NSHomeDirectory() : normalizedPath
        let name = projectName.isEmpty ? (path as NSString).lastPathComponent : projectName

        // Capture references before dismiss — @EnvironmentObject becomes
        // invalid once the sheet is removed from the view hierarchy.
        let mgr = manager
        let prefs = preferences

        let capacity = mgr.manualLaunchCapacity
        if capacity <= 0 {
            mgr.notifyManualLaunchCapacity(requested: terminalCount)
            return
        }

        let launchCount = min(terminalCount, capacity)
        if launchCount < terminalCount {
            mgr.notifyManualLaunchCapacity(requested: terminalCount)
        }

        let prompts = Array(tasks.prefix(launchCount)).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let draft = currentDraftSnapshot()
        let chosenProvider = self.selectedProvider
        let selectedModel = self.selectedModel
        let effortLevel = self.effortLevel
        let permissionMode = self.permissionMode
        let codexSandboxMode = self.codexSandboxMode
        let codexApprovalPolicy = self.codexApprovalPolicy
        let systemPrompt = self.systemPrompt
        let maxBudget = self.maxBudget
        let allowedTools = self.allowedTools
        let disallowedTools = self.disallowedTools
        let additionalDirs = self.additionalDirs
        let continueSession = self.continueSession
        let useWorktree = self.useWorktree

        // Remember launch and create tabs BEFORE dismiss so all view
        // properties are still valid.
        prefs.rememberLaunch(
            projectName: name,
            projectPath: path,
            draft: draft
        )

        var tabsToStart: [TerminalTab] = []
        tabsToStart.reserveCapacity(launchCount)

        for i in 0..<launchCount {
            let prompt = i < prompts.count ? prompts[i] : ""
            let tab = mgr.addTab(
                projectName: name,
                projectPath: path,
                provider: chosenProvider,
                initialPrompt: prompt.isEmpty ? nil : prompt,
                manualLaunch: true,
                autoStart: false
            )
            tab.selectedModel = selectedModel
            tab.isClaude = selectedModel.provider == .claude
            tab.effortLevel = effortLevel
            tab.permissionMode = permissionMode
            tab.codexSandboxMode = codexSandboxMode
            tab.codexApprovalPolicy = codexApprovalPolicy
            tab.systemPrompt = systemPrompt
            tab.maxBudgetUSD = Double(maxBudget) ?? 0
            tab.allowedTools = allowedTools
            tab.disallowedTools = disallowedTools
            tab.additionalDirs = additionalDirs
            tab.continueSession = continueSession
            tab.useWorktree = useWorktree
            tabsToStart.append(tab)
        }

        isCreatingSessions = true
        dismiss()

        // Start tabs asynchronously — tab objects are already created and
        // retained by the manager, so they are safe to access after dismiss.
        for (index, tab) in tabsToStart.enumerated() {
            let delay = min(Double(index) * 0.18, 0.72)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                autoreleasepool {
                    tab.start()
                }
            }
        }
    }
}
