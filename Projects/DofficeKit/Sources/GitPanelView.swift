import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Git Panel View (Full Git Client)
// ═══════════════════════════════════════════════════════

public struct GitPanelView: View {
    static let commitRowHeight: CGFloat = 48

    @EnvironmentObject var manager: SessionManager
    @StateObject var git = GitDataProvider()
    @ObservedObject var settings = AppSettings.shared

    // Selection & navigation
    @State var selectedCommitId: String?
    @State var hoveredCommitId: String?
    @State var selectedFileForDiff: GitFileChange?
    @State var selectedKeyboardIndex: Int = 0

    // Action sheet (Claude-based operations)
    @State var showActionSheet = false
    @State var actionType: GitAction = .commit
    @State var actionInput: String = ""

    // Right panel tabs
    @State var rightTab: RightPanelTab = .changes

    // Left sidebar section collapse state
    @State var sidebarBranchesExpanded = true

    public init() {}
    @State var sidebarTagsExpanded = false
    @State var sidebarStashesExpanded = false
    @State var sidebarRemotesExpanded = false

    // Inline commit
    @State var commitMessage: String = ""

    // File selection for selective commit
    @State var selectedFilesForCommit: Set<String> = []

    // Confirmation alerts
    @State var showDiscardAlert = false
    @State var fileToDiscard: GitFileChange?
    @State var showDeleteBranchAlert = false
    @State var branchToDelete: String?
    @State var showForcePushWarning = false

    // Conflict resolution
    @State var showConflictList = false

    // Search
    @State var searchText: String = ""

    // Diff view mode
    @State var showDiffViewer = false


    // Blame & file history
    @State var showBlameView = false
    @State var showFileHistory = false
    @State var fileHistoryFile: GitFileChange?

    // Amend
    @State var showAmendAlert = false
    @State var amendMessage: String = ""

    // Cherry-pick / Revert / Reset confirmations
    @State var showCherryPickAlert = false
    @State var showRevertAlert = false
    @State var showResetAlert = false
    @State var resetMode: String = "mixed"
    @State var commitForAction: GitCommitNode?
    // Toast notification
    @State var toastMessage: String?
    @State var toastIcon: String = "checkmark.circle.fill"
    @State var toastColor: Color = .green
    @State var toastVisible = false
    var toastDismissWork: DispatchWorkItem? = nil

    public enum GitAction: String, CaseIterable {
        case commit = "커밋", push = "푸시", pull = "풀"
        case branch = "브랜치", stash = "스태시"
        case merge = "병합", checkout = "체크아웃"

        public var displayName: String {
            switch self {
            case .commit: return NSLocalizedString("git.commit", comment: "")
            case .push: return NSLocalizedString("git.push", comment: "")
            case .pull: return NSLocalizedString("git.pull", comment: "")
            case .branch: return NSLocalizedString("git.branch", comment: "")
            case .stash: return NSLocalizedString("git.stash", comment: "")
            case .merge: return NSLocalizedString("git.merge", comment: "")
            case .checkout: return NSLocalizedString("git.checkout", comment: "")
            }
        }
    }
    public enum RightPanelTab: String { case changes, info, blame, fileHistory }

    var activeTab: TerminalTab? { manager.activeTab }
    var projectPath: String { activeTab?.projectPath ?? "" }

    // Derived data — use localizedCaseInsensitiveContains to avoid repeated lowercased() allocations
    var allTags: [GitCommitNode.GitRef] {
        git.commits.flatMap { c in c.refs.filter { $0.type == .tag } }
    }
    var localBranches: [GitBranchInfo] { git.branches.filter { !$0.isRemote } }
    var remoteBranches: [GitBranchInfo] { git.branches.filter { $0.isRemote } }
    var remoteNames: [String] {
        Array(Set(remoteBranches.compactMap { br -> String? in
            let parts = br.name.split(separator: "/", maxSplits: 1)
            return parts.count >= 1 ? String(parts[0]) : nil
        })).sorted()
    }

    var displayedCommits: [GitCommitNode] {
        let base = git.commits
        guard !searchText.isEmpty else { return base }
        let q = searchText
        return base.filter {
            $0.message.localizedCaseInsensitiveContains(q) ||
                $0.author.localizedCaseInsensitiveContains(q) ||
                $0.shortHash.localizedCaseInsensitiveContains(q)
        }
    }

    var stagedPaths: Set<String> {
        Set(git.workingDirStaged.map(\.path))
    }

    var unstagedOnlyChanges: [GitFileChange] {
        git.workingDirUnstaged.filter { !stagedPaths.contains($0.path) }
    }

    var pendingPaths: Set<String> {
        stagedPaths.union(git.workingDirUnstaged.map(\.path))
    }

    var pendingFileCount: Int {
        pendingPaths.count
    }

    var selectedCommitPaths: Set<String> {
        selectedFilesForCommit.intersection(pendingPaths)
    }

    var selectedCommitCount: Int {
        selectedCommitPaths.count
    }

    var selectedUnstagedOnlyCount: Int {
        selectedCommitPaths.intersection(Set(unstagedOnlyChanges.map(\.path))).count
    }

    var commitPreviewFiles: [GitFileChange] {
        let previewPaths = selectedCommitCount > 0 ? Array(selectedCommitPaths).sorted() : git.workingDirStaged.map(\.path)
        return previewFiles(for: previewPaths)
    }

    var stashPreviewFiles: [GitFileChange] {
        deduplicatedPreviewFiles(git.workingDirStaged + git.workingDirUnstaged.filter { $0.status != .untracked })
    }

    var stashExcludedFiles: [GitFileChange] {
        git.workingDirUnstaged.filter { $0.status == .untracked }
    }

    var canRunDirectCommit: Bool {
        !git.isCommitting &&
            !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (selectedCommitCount > 0 || !git.workingDirStaged.isEmpty)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            gitToolbar
            Rectangle().fill(Theme.border).frame(height: 1)

            // Conflict banner
            if !git.conflictFiles.isEmpty {
                conflictBanner
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            if projectPath.isEmpty {
                emptyState(NSLocalizedString("git.select.tab", comment: ""), icon: "arrow.triangle.branch")
            } else if git.lastError == NSLocalizedString("git.no.git", comment: "") {
                emptyState(NSLocalizedString("git.not.installed.detail", comment: ""), icon: "exclamationmark.triangle")
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left sidebar
                        leftSidebar
                            .frame(width: 200)
                        Rectangle().fill(Theme.border).frame(width: 1)

                        // Center: commit graph
                        centerPanel
                            .frame(minWidth: 360)
                        Rectangle().fill(Theme.border).frame(width: 1)

                        // Right detail panel
                        rightPanel
                            .frame(minWidth: 280)
                    }
                }

                // Bottom action bar
                Rectangle().fill(Theme.border).frame(height: 1)
                bottomActionBar
            }
        }
        .background(Theme.bg)
        .overlay(alignment: .top) {
            if toastVisible, let msg = toastMessage {
                GitToastView(message: msg, icon: toastIcon, color: toastColor) {
                    withAnimation(.easeOut(duration: 0.2)) { toastVisible = false }
                }
                .padding(.top, 50)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
        .onAppear { git.start(projectPath: projectPath) }
        .onDisappear { git.stop() }
        .onChange(of: manager.activeTabId) { _, _ in
            git.stop(); selectedCommitId = nil; selectedFileForDiff = nil; showDiffViewer = false
            selectedFilesForCommit.removeAll()
            if !projectPath.isEmpty { git.start(projectPath: projectPath) }
        }
        .onChange(of: git.workingDirStaged.count) { _, _ in
            normalizeSelectedCommitFiles()
        }
        .onChange(of: git.workingDirUnstaged.count) { _, _ in
            normalizeSelectedCommitFiles()
        }
        .sheet(isPresented: $showActionSheet) { actionSheet.dofficeSheetPresentation() }
        .alert(NSLocalizedString("git.discard", comment: ""), isPresented: $showDiscardAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { fileToDiscard = nil }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let f = fileToDiscard {
                    git.discardFile(path: f.path)
                    showToast(String(format: NSLocalizedString("git.changes.discarded", comment: ""), f.fileName), icon: "trash.fill", color: Theme.red)
                    fileToDiscard = nil
                }
            }
        } message: {
            Text(String(format: NSLocalizedString("git.discard.confirm", comment: ""), fileToDiscard?.fileName ?? ""))
        }
        .alert(NSLocalizedString("git.branch.delete", comment: ""), isPresented: $showDeleteBranchAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { branchToDelete = nil }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let b = branchToDelete {
                    git.deleteBranch(name: b) { success in
                        if success {
                            showToast(String(format: NSLocalizedString("git.branch.deleted", comment: ""), b), icon: "trash.fill", color: Theme.red)
                        } else {
                            showErrorToast(NSLocalizedString("git.branch.delete.failed", comment: ""))
                        }
                    }
                }
                branchToDelete = nil
            }
        } message: {
            Text(String(format: NSLocalizedString("git.branch.delete.confirm", comment: ""), branchToDelete ?? ""))
        }
        .alert(NSLocalizedString("git.forcepush.warning.title", comment: ""), isPresented: $showForcePushWarning) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("git.forcepush", comment: ""), role: .destructive) {
                if let tab = activeTab {
                    tab.sendPrompt(NSLocalizedString("git.forcepush.prompt", comment: ""))
                }
            }
        } message: {
            Text(NSLocalizedString("git.forcepush.warning.message", comment: ""))
        }
        // Cherry-pick alert
        .alert("Cherry-pick", isPresented: $showCherryPickAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { commitForAction = nil }
            Button("Cherry-pick", role: .destructive) {
                if let c = commitForAction {
                    git.cherryPick(hash: c.id) { success in
                        if success { showSuccessToast(String(format: NSLocalizedString("git.cherrypick.success", comment: ""), c.shortHash)) }
                        else { showErrorToast(NSLocalizedString("git.cherrypick.failed", comment: "")) }
                    }
                    commitForAction = nil
                }
            }
        } message: {
            Text(String(format: NSLocalizedString("git.cherrypick.confirm", comment: ""), commitForAction?.shortHash ?? ""))
        }
        // Revert alert
        .alert(NSLocalizedString("git.revert", comment: ""), isPresented: $showRevertAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { commitForAction = nil }
            Button(NSLocalizedString("git.revert", comment: ""), role: .destructive) {
                if let c = commitForAction {
                    git.revertCommit(hash: c.id) { success in
                        if success { showSuccessToast(String(format: NSLocalizedString("git.revert.success", comment: ""), c.shortHash)) }
                        else { showErrorToast(NSLocalizedString("git.revert.failed", comment: "")) }
                    }
                    commitForAction = nil
                }
            }
        } message: {
            Text(String(format: NSLocalizedString("git.revert.confirm", comment: ""), commitForAction?.shortHash ?? ""))
        }
        // Reset alert
        .alert("Reset (\(resetMode))", isPresented: $showResetAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { commitForAction = nil }
            Button("Reset", role: .destructive) {
                if let c = commitForAction {
                    git.resetToCommit(hash: c.id, mode: resetMode) { success in
                        if success { showSuccessToast(String(format: NSLocalizedString("git.reset.success", comment: ""), resetMode)) }
                        else { showErrorToast(NSLocalizedString("git.reset.failed", comment: "")) }
                    }
                    commitForAction = nil
                }
            }
        } message: {
            if resetMode == "hard" {
                Text(String(format: NSLocalizedString("git.reset.hard.warning", comment: ""), commitForAction?.shortHash ?? ""))
            } else {
                Text(String(format: NSLocalizedString("git.reset.confirm", comment: ""), commitForAction?.shortHash ?? "", resetMode))
            }
        }
        // Amend alert
        .alert("Amend", isPresented: $showAmendAlert) {
            TextField(NSLocalizedString("git.amend.placeholder", comment: ""), text: $amendMessage)
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { amendMessage = "" }
            Button("Amend") {
                git.amendCommit(message: amendMessage.isEmpty ? nil : amendMessage) { success in
                    if success { showSuccessToast(NSLocalizedString("git.amend.success", comment: "")) }
                    else { showErrorToast(NSLocalizedString("git.amend.failed", comment: "")) }
                }
                amendMessage = ""
            }
        } message: {
            Text(NSLocalizedString("git.amend.confirm", comment: ""))
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Toolbar
    // ═══════════════════════════════════════════════════════

    var gitToolbar: some View {
        HStack(spacing: Theme.sp2) {
            // Branch pill
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                    .foregroundColor(Theme.green)
                Text(git.currentBranch.isEmpty ? "—" : git.currentBranch)
                    .font(Theme.code(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                if let br = git.branches.first(where: { $0.isCurrent }) {
                    if br.ahead > 0 {
                        Text("↑\(br.ahead)").font(Theme.code(8, weight: .bold)).foregroundColor(Theme.green)
                    }
                    if br.behind > 0 {
                        Text("↓\(br.behind)").font(Theme.code(8, weight: .bold)).foregroundColor(Theme.orange)
                    }
                }
            }
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1 + 1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.accentBg(Theme.green)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accentBorder(Theme.green), lineWidth: 1))

            // Stats pills
            if !git.commits.isEmpty {
                statPill(icon: "clock.arrow.circlepath", text: "\(git.commits.count)", color: Theme.textDim)
            }
            if !allTags.isEmpty {
                statPill(icon: "tag.fill", text: "\(allTags.count)", color: Theme.yellow)
            }
            if !git.stashes.isEmpty {
                statPill(icon: "tray.full.fill", text: "\(git.stashes.count)", color: Theme.cyan)
            }
            if !git.conflictFiles.isEmpty {
                statPill(icon: "exclamationmark.triangle.fill", text: "\(git.conflictFiles.count)", color: Theme.red)
            }

            Spacer()

            // Action buttons
            Button(action: { actionType = .commit; actionInput = ""; showActionSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(9)))
                    Text(NSLocalizedString("git.commit", comment: "")).font(Theme.chrome(9, weight: .bold))
                }
                .foregroundColor(Theme.textOnAccent)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green))
            }
            .buttonStyle(.plain)

            toolbarActionBtn(NSLocalizedString("git.push", comment: ""), icon: "arrow.up.circle.fill", color: Theme.accent) {
                executeGitAction(.push, input: "")
            }
            toolbarActionBtn(NSLocalizedString("git.pull", comment: ""), icon: "arrow.down.circle.fill", color: Theme.cyan) {
                executeGitAction(.pull, input: "")
            }

            Rectangle().fill(Theme.border).frame(width: 1, height: 16)

            Button(action: { actionType = .branch; actionInput = ""; showActionSheet = true }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: Theme.iconSize(8)))
                    Text(NSLocalizedString("git.branch", comment: "")).font(Theme.chrome(8, weight: .medium))
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button(action: { actionType = .stash; actionInput = ""; showActionSheet = true }) {
                HStack(spacing: 3) {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: Theme.iconSize(8)))
                    Text(NSLocalizedString("git.stash", comment: "")).font(Theme.chrome(8, weight: .medium))
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.border).frame(width: 1, height: 16)

            Button(action: { git.refreshAll() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                    .foregroundColor(Theme.textDim)
                    .rotationEffect(.degrees(git.isLoading ? 360 : 0))
                    .animation(git.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: git.isLoading)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2 - 1)
        .background(Theme.bgCard)
    }

    func statPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .medium))
            Text(text).font(Theme.chrome(8, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, Theme.sp2 - 2).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(color)))
    }

    func toolbarActionBtn(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(8)))
                Text(label).font(Theme.chrome(8, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1 + 1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.accentBg(color)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accentBorder(color), lineWidth: 1))
        }.buttonStyle(.plain)
    }


}
