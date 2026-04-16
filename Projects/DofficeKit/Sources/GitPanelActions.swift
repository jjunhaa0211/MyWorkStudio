import SwiftUI
import DesignSystem

extension GitPanelView {
    // ═══════════════════════════════════════════════════════
    // MARK: - Bottom Action Bar
    // ═══════════════════════════════════════════════════════

    var bottomActionBar: some View {
        HStack(spacing: 8) {
            // Stage All button
            Button(action: { git.stageAll(); showSuccessToast(NSLocalizedString("git.staged.all", comment: "")) }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 9))
                    Text(NSLocalizedString("git.stage.all.short", comment: "")).font(Theme.mono(8, weight: .medium))
                }
                .foregroundColor(Theme.green)
                .padding(.horizontal, 8).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.green.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.green.opacity(0.12), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            // File selection count indicator
            if selectedCommitCount > 0 {
                Text(String(format: NSLocalizedString("git.files.selected", comment: ""), selectedCommitCount, pendingFileCount))
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundStyle(Theme.accentBackground)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.1)))
            }

            Spacer()

            // Error indicator
            if let error = git.lastError {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.red)
                    Text(error)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.red)
                        .lineLimit(1)
                }
                .help(error)
            }

            // Push button
            Button(action: { executeGitAction(.push, input: "") }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 8))
                    Text(NSLocalizedString("git.push", comment: "")).font(Theme.mono(8, weight: .medium))
                    if let br = git.branches.first(where: { $0.isCurrent }), br.ahead > 0 {
                        Text("↑\(br.ahead)")
                            .font(Theme.mono(6, weight: .bold))
                            .foregroundColor(Theme.green)
                    }
                }
                .foregroundStyle(Theme.accentBackground)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.accent.opacity(0.12), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            // Pull button
            Button(action: { executeGitAction(.pull, input: "") }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 8))
                    Text(NSLocalizedString("git.pull", comment: "")).font(Theme.mono(8, weight: .medium))
                    if let br = git.branches.first(where: { $0.isCurrent }), br.behind > 0 {
                        Text("↓\(br.behind)")
                            .font(Theme.mono(6, weight: .bold))
                            .foregroundColor(Theme.orange)
                    }
                }
                .foregroundColor(Theme.cyan)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.cyan.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.cyan.opacity(0.12), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2)
        .background(Theme.bgCard)
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Shared Components
    // ═══════════════════════════════════════════════════════

    func sectionHeader(_ title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: Theme.sp1 + 2) {
            Image(systemName: icon).font(.system(size: Theme.iconSize(9))).foregroundColor(color)
            Text(title).font(Theme.mono(9, weight: .semibold)).foregroundColor(color)
            Text("\(count)").font(Theme.mono(8, weight: .medium)).foregroundColor(Theme.textMuted)
                .padding(.horizontal, Theme.sp1).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
            Spacer()
        }
    }

    func fileChangeRow(_ file: GitFileChange, showDiffArrow: Bool = false) -> some View {
        HStack(spacing: Theme.sp2 - 2) {
            Image(systemName: file.status.icon)
                .font(.system(size: 9)).foregroundColor(file.status.color).frame(width: 14)
            Text(file.fileName)
                .font(Theme.code(9, weight: .medium)).foregroundColor(Theme.textPrimary).lineLimit(1)
            Spacer()
            Text(file.status.rawValue)
                .font(Theme.code(7, weight: .bold))
                .foregroundColor(file.status.color)
                .padding(.horizontal, Theme.sp1 + 1).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(file.status.color)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(file.status.color), lineWidth: 1))
            if showDiffArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.vertical, Theme.sp1).padding(.horizontal, Theme.sp2)
        .background(RoundedRectangle(cornerRadius: 4).fill(file.status.color.opacity(0.04)))
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                git.fetchBlame(filePath: file.path)
                showBlameView = true
                showDiffViewer = false
                showFileHistory = false
            }) {
                Label(NSLocalizedString("git.blame", comment: ""), systemImage: "person.text.rectangle")
            }
            Button(action: {
                git.fetchFileHistory(filePath: file.path)
                fileHistoryFile = file
                showFileHistory = true
                showBlameView = false
                showDiffViewer = false
            }) {
                Label(NSLocalizedString("git.file.history", comment: ""), systemImage: "clock.arrow.circlepath")
            }
        }
    }

    var stashSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(NSLocalizedString("git.stash", comment: ""), count: git.stashes.count, icon: "tray.full.fill", color: Theme.cyan)
            ForEach(git.stashes) { s in
                HStack(spacing: 6) {
                    Text("stash@{\(s.id)}").font(Theme.mono(8, weight: .medium)).foregroundColor(Theme.cyan)
                    Text(s.message).font(Theme.mono(8)).foregroundColor(Theme.textSecondary).lineLimit(1)
                    Spacer()
                    Button(action: { git.stashApply(index: s.id) }) {
                        Text(NSLocalizedString("git.stash.apply.short", comment: "")).font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.green)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.green.opacity(0.08)))
                    }.buttonStyle(.plain)
                    Button(action: { git.stashDrop(index: s.id) }) {
                        Text(NSLocalizedString("delete", comment: "")).font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.red)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.red.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
                .padding(.vertical, 3).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.bgSurface))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5)))
    }

    func previewFiles(for paths: [String]) -> [GitFileChange] {
        paths.compactMap { path in
            git.workingDirStaged.first(where: { $0.path == path }) ??
                git.workingDirUnstaged.first(where: { $0.path == path })
        }
        .sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    func deduplicatedPreviewFiles(_ files: [GitFileChange]) -> [GitFileChange] {
        var seen: Set<String> = []
        return files.filter { seen.insert($0.path).inserted }
    }

    func toggleCommitSelection(_ path: String) {
        if selectedFilesForCommit.contains(path) {
            selectedFilesForCommit.remove(path)
        } else {
            selectedFilesForCommit.insert(path)
        }
    }

    func toggleCommitSelection(paths: Set<String>) {
        guard !paths.isEmpty else { return }
        if paths.isSubset(of: selectedCommitPaths) {
            selectedFilesForCommit.subtract(paths)
        } else {
            selectedFilesForCommit.formUnion(paths)
        }
    }

    func normalizeSelectedCommitFiles() {
        selectedFilesForCommit = selectedFilesForCommit.intersection(pendingPaths)
    }

    func performDirectCommit() {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        let complete: (Bool) -> Void = { success in
            if success {
                let short = message.count > 30 ? String(message.prefix(30)) + "..." : message
                showSuccessToast(String(format: NSLocalizedString("git.commit.success", comment: ""), short))
                commitMessage = ""
                selectedFilesForCommit.removeAll()
            } else {
                showErrorToast(String(format: NSLocalizedString("git.commit.failed", comment: ""), git.lastError ?? NSLocalizedString("git.unknown.error", comment: "")))
            }
        }

        if selectedCommitCount > 0 {
            git.commitSelectedFiles(message: message, selectedPaths: Array(selectedCommitPaths), completion: complete)
        } else {
            git.commitDirectly(message: message, completion: complete)
        }
    }

    func commitPreviewSubtitle() -> String {
        if selectedCommitCount > 0 {
            return String(format: NSLocalizedString("git.commit.preview.selected", comment: ""), selectedCommitCount)
        }
        if !git.workingDirStaged.isEmpty {
            return String(format: NSLocalizedString("git.commit.preview.staged", comment: ""), git.workingDirStaged.count)
        }
        return NSLocalizedString("git.commit.preview.empty", comment: "")
    }

    func stashPreviewSubtitle() -> String {
        if stashPreviewFiles.isEmpty {
            return NSLocalizedString("git.stash.preview.empty", comment: "")
        }
        if stashExcludedFiles.isEmpty {
            return String(format: NSLocalizedString("git.stash.preview.count", comment: ""), stashPreviewFiles.count)
        }
        return String(format: NSLocalizedString("git.stash.preview.partial", comment: ""), stashPreviewFiles.count)
    }

    var quickActionGrid: some View {
        let actions: [(String, String, GitAction, Color)] = [
            (NSLocalizedString("git.commit", comment: ""), "checkmark.circle.fill", .commit, Theme.green),
            (NSLocalizedString("git.push", comment: ""), "arrow.up.circle.fill", .push, Theme.accent),
            (NSLocalizedString("git.pull", comment: ""), "arrow.down.circle.fill", .pull, Theme.cyan),
            (NSLocalizedString("git.branch", comment: ""), "arrow.triangle.branch", .branch, Theme.purple),
            (NSLocalizedString("git.stash", comment: ""), "tray.and.arrow.down.fill", .stash, Theme.yellow),
            (NSLocalizedString("git.merge", comment: ""), "arrow.triangle.merge", .merge, Theme.orange),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader(NSLocalizedString("git.quick.actions", comment: ""), count: actions.count, icon: "bolt.fill", color: Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                ForEach(actions, id: \.0) { (label, icon, action, color) in
                    Button(action: {
                        actionType = action; actionInput = ""
                        if action == .push || action == .pull { executeGitAction(action, input: "") }
                        else { showActionSheet = true }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                            Text(label).font(Theme.mono(8, weight: .medium))
                        }
                        .foregroundColor(color).frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.12), lineWidth: 0.5)))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Action Sheet (Claude-based Operations)
    // ═══════════════════════════════════════════════════════

    var actionSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: actionIcon(actionType)).font(.system(size: 16)).foregroundStyle(Theme.accentBackground)
                Text("Git \(actionType.displayName)").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Group {
                switch actionType {
                case .commit:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("git.commit.message", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextEditor(text: $actionInput).font(Theme.monoNormal).frame(height: 80).padding(4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                        actionPreviewSection(
                            title: NSLocalizedString("git.commit.preview.title", comment: ""),
                            subtitle: commitPreviewSubtitle(),
                            files: commitPreviewFiles,
                            accent: Theme.green,
                            emptyMessage: NSLocalizedString("git.commit.preview.no.staged", comment: "")
                        )
                    }
                case .branch:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("git.branch.name", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField("feature/...", text: $actionInput).font(Theme.monoNormal).textFieldStyle(.plain).padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    }
                case .stash:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("git.stash.message.optional", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField(NSLocalizedString("git.stash.message.placeholder", comment: ""), text: $actionInput).font(Theme.monoNormal).textFieldStyle(.plain).padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                        actionPreviewSection(
                            title: NSLocalizedString("git.stash.preview.title", comment: ""),
                            subtitle: stashPreviewSubtitle(),
                            files: stashPreviewFiles,
                            accent: Theme.cyan,
                            emptyMessage: NSLocalizedString("git.stash.preview.no.tracked", comment: "")
                        )
                        if !stashExcludedFiles.isEmpty {
                            actionPreviewSection(
                                title: NSLocalizedString("git.stash.excluded.title", comment: ""),
                                subtitle: NSLocalizedString("git.stash.excluded.hint", comment: ""),
                                files: stashExcludedFiles,
                                accent: Theme.orange,
                                emptyMessage: ""
                            )
                        }
                    }
                case .merge, .checkout:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(actionType == .merge ? NSLocalizedString("git.merge.branch", comment: "") : NSLocalizedString("git.checkout.branch", comment: ""))
                            .font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(git.branches.filter { b in actionType == .merge ? (!b.isCurrent && !b.isRemote) : !b.isCurrent }) { br in
                                    Button(action: { actionInput = br.name }) {
                                        HStack {
                                            Image(systemName: br.isRemote ? "cloud" : "arrow.triangle.branch").font(.system(size: 9))
                                            Text(br.name).font(Theme.mono(10))
                                            Spacer()
                                            if actionInput == br.name {
                                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.green)
                                            }
                                        }
                                        .foregroundColor(actionInput == br.name ? Theme.accent : Theme.textSecondary)
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(actionInput == br.name ? Theme.accent.opacity(0.1) : .clear))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.frame(maxHeight: 150)
                    }
                default: EmptyView()
                }
            }

            HStack {
                Button(NSLocalizedString("cancel", comment: "")) { showActionSheet = false }
                    .font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textDim)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                    .buttonStyle(.plain)
                Spacer()
                Button(action: { executeGitAction(actionType, input: actionInput); showActionSheet = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill").font(.system(size: 9))
                        Text(NSLocalizedString("git.ask.claude", comment: "")).font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(Theme.textOnAccent).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBackground))
                }
                .buttonStyle(.plain)
                .disabled(needsInput && actionInput.isEmpty)
                .opacity(needsInput && actionInput.isEmpty ? 0.5 : 1)
            }
        }
        .padding(20).frame(width: min(520, max(400, (NSScreen.main?.visibleFrame.width ?? 1440) - 200))).background(Theme.bgCard)
    }

    func actionPreviewSection(title: String, subtitle: String, files: [GitFileChange], accent: Color, emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(files.count)")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(accent.opacity(0.10)))
            }

            Text(subtitle)
                .font(Theme.mono(7))
                .foregroundColor(Theme.textDim)

            if files.isEmpty {
                Text(emptyMessage)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textMuted)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(files) { file in
                            actionPreviewFileRow(file)
                        }
                    }
                }
                .frame(maxHeight: min(180, max(50, CGFloat(files.count) * 46)))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
    }

    func actionPreviewFileRow(_ file: GitFileChange) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: file.status.icon)
                .font(.system(size: 9))
                .foregroundColor(file.status.color)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(Theme.code(8, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(file.path)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(file.status.rawValue)
                .font(Theme.code(7, weight: .bold))
                .foregroundColor(file.status.color)
                .padding(.horizontal, Theme.sp1 + 1)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(file.status.color)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(file.status.color), lineWidth: 1))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(file.status.color.opacity(0.04)))
    }

    var needsInput: Bool {
        switch actionType {
        case .commit, .branch, .merge, .checkout: return true
        default: return false
        }
    }

    func actionIcon(_ action: GitAction) -> String {
        switch action {
        case .commit: return "checkmark.circle"
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .branch: return "arrow.triangle.branch"
        case .stash: return "tray.and.arrow.down"
        case .merge: return "arrow.triangle.merge"
        case .checkout: return "arrow.uturn.right"
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Actions & Helpers
    // ═══════════════════════════════════════════════════════

    func executeGitAction(_ action: GitAction, input: String) {
        guard let tab = activeTab else { return }
        let prompt: String
        switch action {
        case .commit: prompt = String(format: NSLocalizedString("git.prompt.commit", comment: ""), input)
        case .push: prompt = NSLocalizedString("git.prompt.push", comment: "")
        case .pull: prompt = NSLocalizedString("git.prompt.pull", comment: "")
        case .branch: prompt = String(format: NSLocalizedString("git.prompt.branch", comment: ""), input)
        case .stash: prompt = input.isEmpty ? NSLocalizedString("git.prompt.stash", comment: "") : String(format: NSLocalizedString("git.prompt.stash.msg", comment: ""), input)
        case .merge: prompt = String(format: NSLocalizedString("git.prompt.merge", comment: ""), input)
        case .checkout: prompt = String(format: NSLocalizedString("git.prompt.checkout", comment: ""), input)
        }
        tab.sendPrompt(prompt)

        // Toast feedback
        let toastMsg: String = {
            switch action {
            case .push: return NSLocalizedString("git.toast.push", comment: "")
            case .pull: return NSLocalizedString("git.toast.pull", comment: "")
            case .commit: return NSLocalizedString("git.toast.commit", comment: "")
            case .branch: return String(format: NSLocalizedString("git.toast.branch", comment: ""), input)
            case .stash: return NSLocalizedString("git.toast.stash", comment: "")
            case .merge: return String(format: NSLocalizedString("git.toast.merge", comment: ""), input)
            case .checkout: return String(format: NSLocalizedString("git.toast.checkout", comment: ""), input)
            }
        }()
        showInfoToast(toastMsg)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak git] in git?.refreshAll() }
    }

    func selectCommit(_ commit: GitCommitNode) {
        selectedCommitId = commit.id
        selectedFileForDiff = nil
        showDiffViewer = false
        rightTab = .changes
        git.fetchCommitFiles(hash: commit.id)
    }

    func badge(_ text: String, color: Color) -> some View {
        Text(text).font(Theme.mono(7, weight: .bold)).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    func metaRow(_ label: String, _ value: String, mono: Bool = false, copyValue: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.textDim)
                .frame(width: 52, alignment: .trailing)
            Text(value).font(mono ? Theme.mono(9, weight: .medium) : Theme.mono(9))
                .foregroundColor(Theme.textPrimary).textSelection(.enabled)
            if let cv = copyValue {
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cv, forType: .string) }) {
                    Image(systemName: "doc.on.doc").font(.system(size: 8)).foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
            Spacer()
        }
    }

    func emptyState(_ msg: String, icon: String) -> some View {
        VStack(spacing: Theme.sp3) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(24), weight: .light))
                .foregroundColor(Theme.textMuted)
            Text(msg)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd HH:mm:ss"; return f
    }()

    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "M.d"; return f
    }()

    public static func relativeDate(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return NSLocalizedString("git.time.now", comment: "") }
        if s < 3600 { return String(format: NSLocalizedString("git.time.minutes", comment: ""), s / 60) }
        if s < 86400 { return String(format: NSLocalizedString("git.time.hours", comment: ""), s / 3600) }
        if s < 604800 { return String(format: NSLocalizedString("git.time.days", comment: ""), s / 86400) }
        return shortDateFormatter.string(from: date)
    }

    public static func formatDate(_ date: Date) -> String { fullDateFormatter.string(from: date) }

    // MARK: - Toast

    func showToast(_ message: String, icon: String = "checkmark.circle.fill", color: Color = Theme.green) {
        toastMessage = message
        toastIcon = icon
        toastColor = color
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                toastVisible = false
            }
        }
    }

    func showSuccessToast(_ message: String) {
        showToast(message, icon: "checkmark.circle.fill", color: Theme.green)
    }

    func showErrorToast(_ message: String) {
        showToast(message, icon: "exclamationmark.triangle.fill", color: Theme.red)
    }

    func showInfoToast(_ message: String) {
        showToast(message, icon: "info.circle.fill", color: Theme.accent)
    }
}

// MARK: - Git Toast View

public struct GitToastView: View {
    @ObservedObject private var settings = AppSettings.shared
    public let message: String
    public let icon: String
    public let color: Color
    public let onDismiss: () -> Void
    @State private var isVisible = false

    public var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(message)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textDim.opacity(0.5))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minWidth: 200, maxWidth: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bgCard.opacity(0.98))
                    .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isVisible = true
            }
        }
    }
}
