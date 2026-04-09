import SwiftUI
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Git Data Provider
// ═══════════════════════════════════════════════════════

@MainActor
public class GitDataProvider: ObservableObject {
    // MARK: - Published State

    @Published public var commits: [GitCommitNode] = []
    @Published public var workingDirStaged: [GitFileChange] = []
    @Published public var workingDirUnstaged: [GitFileChange] = []
    @Published public var branches: [GitBranchInfo] = []
    @Published public var stashes: [GitStashEntry] = []
    @Published public var currentBranch: String = ""
    @Published public var isLoading = false
    @Published public var selectedCommitFiles: [GitFileChange] = []
    @Published public var maxLaneCount: Int = 1

    // Diff support
    @Published public var diffResult: GitDiffResult?

    // Search
    @Published public var searchQuery: String = ""

    // Conflict detection
    @Published public var conflictFiles: [GitFileChange] = []

    // Error reporting
    @Published public var lastError: String?

    // Pagination
    @Published public var commitPage: Int = 0
    public let commitsPerPage = 200
    private var allCommitsLoaded = false

    // Precomputed lookup: SHA -> lane (for O(1) parent lane lookup in graph drawing)
    public var commitLaneMap: [String: Int] = [:]

    private var projectPath: String = ""
    private var refreshTimer: AnyCancellable?
    @Published public var isCommitting = false

    // Git availability check (cached)
    private static var gitAvailable: Bool?
    private static func checkGitAvailable() -> Bool {
        if let cached = gitAvailable { return cached }
        let result = TerminalTab.shellSync("git --version 2>/dev/null")
        gitAvailable = result?.contains("git version") ?? false
        return gitAvailable ?? false
    }

    // Lane colors — computed each time to respect dark/light mode changes
    public static var laneColors: [Color] {
        [Theme.accent, Theme.green, Theme.purple, Theme.orange,
         Theme.cyan, Theme.pink, Theme.yellow, Theme.red]
    }

    // MARK: - Filtered Commits (search)

    public var filteredCommits: [GitCommitNode] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return commits }
        return commits.filter {
            $0.message.localizedCaseInsensitiveContains(query) ||
            $0.author.localizedCaseInsensitiveContains(query) ||
            $0.shortHash.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Lifecycle

    public func start(projectPath: String) {
        guard !projectPath.isEmpty else { return }
        self.projectPath = projectPath
        commitPage = 0
        allCommitsLoaded = false

        guard Self.checkGitAvailable() else {
            lastError = NSLocalizedString("git.not.installed", comment: "")
            return
        }

        refreshAll()
        refreshTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshAll() }
    }

    deinit {
        refreshTimer?.cancel()
    }

    public func stop() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - Full Refresh

    public func refreshAll() {
        guard !projectPath.isEmpty, !isLoading else { return }
        guard Self.checkGitAvailable() else {
            lastError = NSLocalizedString("git.not.installed", comment: "")
            isLoading = false
            return
        }
        isLoading = true
        lastError = nil
        let path = projectPath
        let page = commitPage
        let perPage = commitsPerPage
        let totalLimit = (page + 1) * perPage

        DispatchQueue.global(qos: .userInitiated).async {
            let commits = GitDataParser.parseCommits(path: path, limit: totalLimit)
            let (staged, unstaged) = GitDataParser.parseWorkingDir(path: path)
            let branches = GitDataParser.parseBranches(path: path)
            let stashes = GitDataParser.parseStashes(path: path)
            let conflicts = GitDataParser.parseConflicts(path: path)
            let currentBr = TerminalTab.shellSync("git -C \"\(path)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let maxLane = (commits.map { $0.lane }.max() ?? 0) + 1
            var laneMap: [String: Int] = [:]
            for c in commits { laneMap[c.id] = c.lane }
            let fullyLoaded = commits.count < totalLimit

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.commits = commits
                self.workingDirStaged = staged
                self.workingDirUnstaged = unstaged
                self.branches = branches
                self.stashes = stashes
                self.conflictFiles = conflicts
                self.currentBranch = currentBr
                self.maxLaneCount = maxLane
                self.commitLaneMap = laneMap
                self.allCommitsLoaded = fullyLoaded
                self.isLoading = false
            }
        }
    }

    // MARK: - Pagination

    public func loadMoreCommits() {
        guard !allCommitsLoaded, !isLoading else { return }
        commitPage += 1
        isLoading = true
        lastError = nil
        let path = projectPath
        let totalLimit = (commitPage + 1) * commitsPerPage

        DispatchQueue.global(qos: .userInitiated).async {
            let commits = GitDataParser.parseCommits(path: path, limit: totalLimit)
            let maxLane = (commits.map { $0.lane }.max() ?? 0) + 1
            var laneMap: [String: Int] = [:]
            for c in commits { laneMap[c.id] = c.lane }
            let fullyLoaded = commits.count < totalLimit

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.commits = commits
                self.maxLaneCount = maxLane
                self.commitLaneMap = laneMap
                self.allCommitsLoaded = fullyLoaded
                self.isLoading = false
            }
        }
    }

    // MARK: - Commit Files

    public func fetchCommitFiles(hash: String) {
        // Validate hash is hex-only (prevent command injection)
        guard hash.allSatisfy({ $0.isHexDigit }) else { return }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async {
            let raw = TerminalTab.shellSync("git -C \"\(path)\" diff-tree --no-commit-id --name-status -r \(hash) 2>/dev/null") ?? ""
            let files = raw.components(separatedBy: "\n").compactMap { line -> GitFileChange? in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let statusStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let filePath = String(parts[1])
                let status = GitFileChange.ChangeStatus(rawValue: String(statusStr.prefix(1))) ?? .modified
                return GitFileChange(path: filePath, fileName: (filePath as NSString).lastPathComponent, status: status, isStaged: true)
            }
            DispatchQueue.main.async { [weak self] in self?.selectedCommitFiles = files }
        }
    }

    // MARK: - Diff Support

    /// Fetch raw diff string for a file.
    public func fetchFileDiff(projectPath: String? = nil, path filePath: String, staged: Bool, hash: String? = nil) -> String {
        let root = projectPath ?? self.projectPath
        guard !root.isEmpty else { return "" }
        let safePath = GitDataParser.sanitizePath(filePath)

        if let hash = hash {
            // Commit diff
            guard hash.allSatisfy({ $0.isHexDigit }) else { return "" }
            return TerminalTab.shellSync("git -C \"\(root)\" diff \(hash)^..\(hash) -- \"\(safePath)\" 2>/dev/null") ?? ""
        }

        if staged {
            return TerminalTab.shellSync("git -C \"\(root)\" diff --cached -- \"\(safePath)\" 2>/dev/null") ?? ""
        }

        // Check if untracked by looking at status
        let statusRaw = TerminalTab.shellSync("git -C \"\(root)\" status --porcelain -- \"\(safePath)\" 2>/dev/null") ?? ""
        let isUntracked = statusRaw.hasPrefix("??")

        if isUntracked {
            // Read file content for untracked files
            let fullPath = root.hasSuffix("/") ? "\(root)\(safePath)" : "\(root)/\(safePath)"
            return TerminalTab.shellSync("cat \"\(fullPath)\" 2>/dev/null") ?? ""
        }

        return TerminalTab.shellSync("git -C \"\(root)\" diff -- \"\(safePath)\" 2>/dev/null") ?? ""
    }

    /// Fetch and parse diff into structured result. Updates `diffResult` on main thread.
    public func fetchParsedDiff(path filePath: String, staged: Bool, hash: String? = nil) {
        let root = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let rawDiff: String
            let safePath = GitDataParser.sanitizePath(filePath)

            if let hash = hash {
                guard hash.allSatisfy({ $0.isHexDigit }) else {
                    DispatchQueue.main.async { [weak self] in self?.diffResult = nil }
                    return
                }
                rawDiff = TerminalTab.shellSync("git -C \"\(root)\" diff \(hash)^..\(hash) -- \"\(safePath)\" 2>/dev/null") ?? ""
            } else if staged {
                rawDiff = TerminalTab.shellSync("git -C \"\(root)\" diff --cached -- \"\(safePath)\" 2>/dev/null") ?? ""
            } else {
                let statusRaw = TerminalTab.shellSync("git -C \"\(root)\" status --porcelain -- \"\(safePath)\" 2>/dev/null") ?? ""
                if statusRaw.hasPrefix("??") {
                    let fullPath = root.hasSuffix("/") ? "\(root)\(safePath)" : "\(root)/\(safePath)"
                    let content = TerminalTab.shellSync("cat \"\(fullPath)\" 2>/dev/null") ?? ""
                    let lines = content.components(separatedBy: "\n")
                    let diffLines = lines.enumerated().map { idx, line in
                        DiffLine(type: .addition, content: line, oldLineNum: nil, newLineNum: idx + 1)
                    }
                    let hunk = DiffHunk(header: "@@ -0,0 +1,\(lines.count) @@", lines: diffLines)
                    let result = GitDiffResult(
                        filePath: filePath,
                        hunks: [hunk],
                        isBinary: false,
                        stats: (additions: lines.count, deletions: 0)
                    )
                    DispatchQueue.main.async { [weak self] in self?.diffResult = result }
                    return
                }
                rawDiff = TerminalTab.shellSync("git -C \"\(root)\" diff -- \"\(safePath)\" 2>/dev/null") ?? ""
            }

            let result = GitDataParser.parseDiff(filePath: filePath, rawDiff: rawDiff)
            DispatchQueue.main.async { [weak self] in self?.diffResult = result }
        }
    }

    // MARK: - Staging Operations

    public func stageFile(path filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" add -- \"\(safePath)\" 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func unstageFile(path filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" restore --staged -- \"\(safePath)\" 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func stageAll() {
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" add -A 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func unstageAll() {
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" reset HEAD 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func discardFile(path filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" checkout -- \"\(safePath)\" 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    // MARK: - Direct Git Operations

    public func commitDirectly(message: String, completion: ((Bool) -> Void)? = nil) {
        guard !message.isEmpty else {
            lastError = "Commit message cannot be empty"
            completion?(false)
            return
        }
        let path = projectPath
        // Escape double quotes in commit message to prevent injection
        let safeMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" commit -m \"\(safeMessage)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func commitSelectedFiles(message: String, selectedPaths: [String], completion: ((Bool) -> Void)? = nil) {
        guard !isCommitting else {
            completion?(false)
            return
        }
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            lastError = "Commit message cannot be empty"
            completion?(false)
            return
        }
        isCommitting = true

        let stagedPaths = Set(workingDirStaged.map(\.path))
        let unstagedOnlyPaths = Set(workingDirUnstaged.map(\.path)).subtracting(stagedPaths)
        let eligiblePaths = stagedPaths.union(unstagedOnlyPaths)
        let effectiveSelection = Set(selectedPaths).intersection(eligiblePaths)

        guard !effectiveSelection.isEmpty else {
            lastError = "No files selected to commit"
            completion?(false)
            return
        }

        let pathsToStage = Array(effectiveSelection.intersection(unstagedOnlyPaths)).sorted()
        let pathsToRestore = Array(stagedPaths.subtracting(effectiveSelection)).sorted()
        let path = projectPath
        let safeMessage = trimmedMessage
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            func quotedPaths(_ paths: [String]) -> String {
                paths.map { "\"\(GitDataParser.sanitizePath($0))\"" }.joined(separator: " ")
            }

            func run(_ command: String) -> String {
                TerminalTab.shellSync(command) ?? ""
            }

            func failed(_ output: String) -> Bool {
                output.contains("fatal:") || output.contains("error:")
            }

            var commandError: String?
            var restoreWarning: String?
            var commitSucceeded = false

            if !pathsToStage.isEmpty {
                let output = run("git -C \"\(path)\" add -- \(quotedPaths(pathsToStage)) 2>&1")
                if failed(output) { commandError = output }
            }

            if commandError == nil, !pathsToRestore.isEmpty {
                let output = run("git -C \"\(path)\" restore --staged -- \(quotedPaths(pathsToRestore)) 2>&1")
                if failed(output) { commandError = output }
            }

            if commandError == nil {
                let output = run("git -C \"\(path)\" commit -m \"\(safeMessage)\" 2>&1")
                commitSucceeded = !failed(output)
                if !commitSucceeded { commandError = output }
            }

            if !pathsToRestore.isEmpty {
                let output = run("git -C \"\(path)\" add -- \(quotedPaths(pathsToRestore)) 2>&1")
                if failed(output) { restoreWarning = output }
            }

            if !commitSucceeded, !pathsToStage.isEmpty {
                let output = run("git -C \"\(path)\" restore --staged -- \(quotedPaths(pathsToStage)) 2>&1")
                if commandError == nil, failed(output) { commandError = output }
            }

            DispatchQueue.main.async {
                self?.isCommitting = false
                if let commandError {
                    self?.lastError = commandError
                } else if let restoreWarning {
                    self?.lastError = "Commit succeeded, but some staged selections could not be restored.\n\(restoreWarning)"
                }
                self?.refreshAll()
                completion?(commitSucceeded)
            }
        }
    }

    public func createBranch(name: String, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidBranchName(name) else {
            lastError = "Invalid branch name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" checkout -b \"\(name)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func deleteBranch(name: String, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidBranchName(name) else {
            lastError = "Invalid branch name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        let flag = force ? "-D" : "-d"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" branch \(flag) \"\(name)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func createTag(name: String, message: String? = nil, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidRefName(name) else {
            lastError = "Invalid tag name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        let tagMessage = message
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: String?
            if let message = tagMessage, !message.isEmpty {
                let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = TerminalTab.shellSync("git -C \"\(path)\" tag -a \"\(name)\" -m \"\(safeMsg)\" 2>&1")
            } else {
                result = TerminalTab.shellSync("git -C \"\(path)\" tag \"\(name)\" 2>&1")
            }
            let failed = result.map { $0.contains("fatal") || $0.contains("error") } ?? false
            DispatchQueue.main.async {
                if failed { self?.lastError = result ?? "" }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func deleteTag(name: String, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidRefName(name) else {
            lastError = "Invalid tag name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" tag -d \"\(name)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func stashSave(message: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let path = projectPath
        let stashMessage = message
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: String?
            if let message = stashMessage, !message.isEmpty {
                let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = TerminalTab.shellSync("git -C \"\(path)\" stash push -m \"\(safeMsg)\" 2>&1")
            } else {
                result = TerminalTab.shellSync("git -C \"\(path)\" stash push 2>&1")
            }
            let failed = result?.contains("fatal") ?? false
            DispatchQueue.main.async {
                if failed { self?.lastError = result ?? "" }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func stashApply(index: Int, completion: ((Bool) -> Void)? = nil) {
        guard index >= 0 else {
            lastError = "Invalid stash index"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" stash apply stash@{\(index)} 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func stashDrop(index: Int, completion: ((Bool) -> Void)? = nil) {
        guard index >= 0 else {
            lastError = "Invalid stash index"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" stash drop stash@{\(index)} 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Cherry-pick

    public func cherryPick(hash: String, completion: ((Bool) -> Void)? = nil) {
        guard hash.allSatisfy({ $0.isHexDigit }) else {
            lastError = "Invalid commit hash"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" cherry-pick \(hash) 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error") || result.contains("conflict")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Revert Commit

    public func revertCommit(hash: String, completion: ((Bool) -> Void)? = nil) {
        guard hash.allSatisfy({ $0.isHexDigit }) else {
            lastError = "Invalid commit hash"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" revert --no-edit \(hash) 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error") || result.contains("conflict")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Amend Commit

    public func amendCommit(message: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: String
            if let message = message, !message.isEmpty {
                let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = TerminalTab.shellSync("git -C \"\(path)\" commit --amend -m \"\(safeMsg)\" 2>&1") ?? ""
            } else {
                result = TerminalTab.shellSync("git -C \"\(path)\" commit --amend --no-edit 2>&1") ?? ""
            }
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Blame

    @Published public var blameLines: [BlameLine] = []
    @Published public var blameFilePath: String = ""

    public func fetchBlame(filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        blameFilePath = filePath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let raw = TerminalTab.shellSync("git -C \"\(path)\" blame --porcelain -- \"\(safePath)\" 2>/dev/null") ?? ""
            let lines = GitDataParser.parseBlame(raw)
            DispatchQueue.main.async {
                self?.blameLines = lines
            }
        }
    }

    // MARK: - File History

    @Published public var fileHistory: [GitCommitNode] = []
    @Published public var fileHistoryPath: String = ""

    public func fetchFileHistory(filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        fileHistoryPath = filePath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fieldSep = "<<F>>"
            let format = "%x00%H\(fieldSep)%h\(fieldSep)%s\(fieldSep)%an\(fieldSep)%ae\(fieldSep)%aI\(fieldSep)%P\(fieldSep)%D\(fieldSep)%b"
            let raw = TerminalTab.shellSync("git -C \"\(path)\" log --follow --format='\(format)' -n 50 -- \"\(safePath)\" 2>/dev/null") ?? ""
            let commits = GitDataParser.parseCommitRecords(raw)
            DispatchQueue.main.async {
                self?.fileHistory = commits
            }
        }
    }

    // MARK: - Reset to Commit

    public func resetToCommit(hash: String, mode: String = "mixed", completion: ((Bool) -> Void)? = nil) {
        guard hash.allSatisfy({ $0.isHexDigit }) else {
            lastError = "Invalid commit hash"
            completion?(false)
            return
        }
        guard ["soft", "mixed", "hard"].contains(mode) else {
            lastError = "Invalid reset mode"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" reset --\(mode) \(hash) 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }
}

