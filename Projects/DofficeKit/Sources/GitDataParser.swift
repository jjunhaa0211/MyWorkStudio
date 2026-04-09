import Foundation
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Git Data Parser (nonisolated, runs on background)
// ═══════════════════════════════════════════════════════

public enum GitDataParser {

    private static let gitDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Input Validation

    /// Sanitize a file path to prevent command injection.
    /// Removes null bytes, backticks, dollar signs, and other shell metacharacters.
    public static func sanitizePath(_ path: String) -> String {
        var safe = path
        // Remove characters that could be used for injection
        let forbidden: [Character] = ["\0", "`", "$", ";", "&", "|", "\n", "\r"]
        safe.removeAll { forbidden.contains($0) }
        // Remove leading dashes that could be interpreted as flags
        while safe.hasPrefix("-") {
            safe = String(safe.dropFirst())
        }
        return safe
    }

    /// Validate a branch name against git's rules.
    public static func isValidBranchName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        // Must not contain shell metacharacters
        let forbidden: [Character] = [" ", "~", "^", ":", "\\", "\0", "\t", "\n", "`", "$", ";", "&", "|"]
        for ch in forbidden {
            if name.contains(ch) { return false }
        }
        if name.contains("..") || name.contains("@{") { return false }
        if name.hasPrefix("-") || name.hasPrefix(".") { return false }
        if name.hasSuffix(".") || name.hasSuffix(".lock") || name.hasSuffix("/") { return false }
        return true
    }

    /// Validate a ref name (tags, etc.)
    public static func isValidRefName(_ name: String) -> Bool {
        return isValidBranchName(name)
    }

    // MARK: - Commits

    public static func parseCommits(path: String, limit: Int = 150) -> [GitCommitNode] {
        // Use %x00 (NUL) as record separator between commits to handle multi-line bodies
        let fieldSep = "<<F>>"
        // Format: hash, shortHash, subject, author, email, date, parents, refs
        // Body is fetched separately per-record to avoid multi-line breakage
        let format = "%x00%H\(fieldSep)%h\(fieldSep)%s\(fieldSep)%an\(fieldSep)%ae\(fieldSep)%aI\(fieldSep)%P\(fieldSep)%D\(fieldSep)%b"
        let raw = TerminalTab.shellSync("git -C \"\(path)\" log --all --topo-order --format='\(format)' -n \(limit) 2>/dev/null") ?? ""

        var commits: [GitCommitNode] = []
        // Split by NUL character to separate commits (handles multi-line bodies)
        let records = raw.components(separatedBy: "\0").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            // Find the first field separator to split fields
            let parts = trimmed.components(separatedBy: fieldSep)
            guard parts.count >= 8 else { continue }

            let hash = parts[0].trimmingCharacters(in: .init(charactersIn: "'"))
            let shortHash = parts[1]
            let subject = parts[2]
            let author = parts[3]
            let email = parts[4]
            let dateStr = parts[5]
            let parents = parts[6].split(separator: " ").map(String.init)
            // Everything from parts[7] onward is refs + body (body may contain fieldSep theoretically)
            let refStr = parts[7].trimmingCharacters(in: .init(charactersIn: "'"))
            let body = parts.count > 8 ? parts[8...].joined(separator: fieldSep).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let date = gitDateFormatter.date(from: dateStr) ?? Date()
            let refs = parseRefs(refStr)
            let coAuthors = parseCoAuthors(body)

            commits.append(GitCommitNode(
                id: hash, shortHash: shortHash, message: subject, body: body,
                author: author, authorEmail: email, date: date,
                parentHashes: parents, coAuthors: coAuthors, refs: refs
            ))
        }

        return assignLanes(commits)
    }

    private static func parseRefs(_ str: String) -> [GitCommitNode.GitRef] {
        guard !str.isEmpty else { return [] }
        return str.components(separatedBy: ", ").compactMap { r in
            let trimmed = r.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("HEAD -> ") {
                return .init(name: String(trimmed.dropFirst(8)), type: .head)
            } else if trimmed.hasPrefix("tag: ") {
                return .init(name: String(trimmed.dropFirst(5)), type: .tag)
            } else if trimmed.contains("/") {
                return .init(name: trimmed, type: .remoteBranch)
            } else if !trimmed.isEmpty && trimmed != "HEAD" {
                return .init(name: trimmed, type: .branch)
            }
            return nil
        }
    }

    private static func parseCoAuthors(_ body: String) -> [String] {
        body.components(separatedBy: "\n")
            .filter { $0.lowercased().contains("co-authored-by:") }
            .compactMap { line in
                let parts = line.components(separatedBy: ":")
                guard parts.count >= 2 else { return nil }
                return parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
    }

    // MARK: - Lane Assignment

    private static func assignLanes(_ commits: [GitCommitNode]) -> [GitCommitNode] {
        var result = commits
        var activeLanes: [String?] = [] // SHA expected in each lane
        // O(1) lookup: SHA → lane index (avoids O(n) firstIndex(of:) per commit)
        var shaToLane: [String: Int] = [:]
        // O(1) lookup: set of empty lane indices
        var emptyLanes: [Int] = []

        for i in 0..<result.count {
            let commit = result[i]

            // Find lane where this commit was expected — O(1) via dictionary
            var myLane = shaToLane[commit.id]

            if myLane == nil {
                if let emptyIdx = emptyLanes.popLast() {
                    myLane = emptyIdx
                } else {
                    myLane = activeLanes.count
                    activeLanes.append(nil)
                }
            } else {
                shaToLane.removeValue(forKey: commit.id)
            }

            guard let lane = myLane else { continue }
            result[i].lane = lane

            // Record which lanes are active at this position (for graph drawing)
            var activeSet = Set<Int>()
            activeSet.reserveCapacity(activeLanes.count)
            for (idx, sha) in activeLanes.enumerated() {
                if sha != nil { activeSet.insert(idx) }
            }
            activeSet.insert(lane)
            result[i].activeLanes = activeSet

            // Update lanes: replace current lane with first parent, add others
            if commit.parentHashes.isEmpty {
                activeLanes[lane] = nil
                emptyLanes.append(lane)
            } else {
                let firstParent = commit.parentHashes[0]
                // Remove old mapping if exists
                if let oldSha = activeLanes[lane] { shaToLane.removeValue(forKey: oldSha) }
                activeLanes[lane] = firstParent
                shaToLane[firstParent] = lane

                for pIdx in commit.parentHashes.indices.dropFirst() {
                    let parentHash = commit.parentHashes[pIdx]
                    if shaToLane[parentHash] == nil { // O(1) check
                        if let emptyIdx = emptyLanes.popLast() {
                            activeLanes[emptyIdx] = parentHash
                            shaToLane[parentHash] = emptyIdx
                        } else {
                            shaToLane[parentHash] = activeLanes.count
                            activeLanes.append(parentHash)
                        }
                    }
                }
            }

            // Collapse trailing nils
            while activeLanes.last == nil && activeLanes.count > 1 {
                let removedIdx = activeLanes.count - 1
                activeLanes.removeLast()
                emptyLanes.removeAll { $0 == removedIdx }
            }
        }

        // 첫 번째 부모 레인 + 자식 레인 계산
        let laneMap = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0.lane) })
        for i in 0..<result.count {
            let commit = result[i]
            if let firstParent = commit.parentHashes.first, let pLane = laneMap[firstParent] {
                result[i].firstParentLane = pLane
            }
            // 자식 관계: 이 커밋을 부모로 가진 커밋들의 레인을 기록
            for parentHash in commit.parentHashes {
                if let parentIdx = result.firstIndex(where: { $0.id == parentHash }) {
                    result[parentIdx].childLanes.insert(commit.lane)
                }
            }
        }

        return result
    }

    // MARK: - Working Directory

    public static func parseWorkingDir(path: String) -> (staged: [GitFileChange], unstaged: [GitFileChange]) {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" status --porcelain 2>/dev/null") ?? ""
        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []

        for line in raw.components(separatedBy: "\n") where line.count >= 3 {
            let chars = Array(line)
            let indexStatus = chars[0]
            let workStatus = chars[1]
            let filePath = String(line.dropFirst(3))
            let fileName = (filePath as NSString).lastPathComponent

            if indexStatus != " " && indexStatus != "?" {
                let s = GitFileChange.ChangeStatus(rawValue: String(indexStatus)) ?? .modified
                staged.append(GitFileChange(path: filePath, fileName: fileName, status: s, isStaged: true))
            }
            if workStatus != " " || indexStatus == "?" {
                let s: GitFileChange.ChangeStatus = indexStatus == "?" ? .untracked : (GitFileChange.ChangeStatus(rawValue: String(workStatus)) ?? .modified)
                unstaged.append(GitFileChange(path: filePath, fileName: fileName, status: s, isStaged: false))
            }
        }
        return (staged, unstaged)
    }

    // MARK: - Branches

    public static func parseBranches(path: String) -> [GitBranchInfo] {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" branch -a --format='%(refname:short)|%(upstream:short)|%(upstream:track)' 2>/dev/null") ?? ""
        let current = TerminalTab.shellSync("git -C \"\(path)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return raw.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: "'"))
            let parts = trimmed.components(separatedBy: "|")
            guard let name = parts.first, !name.isEmpty else { return nil }
            let upstream = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
            let isRemote = name.hasPrefix("origin/") || name.contains("/")

            var ahead = 0, behind = 0
            if parts.count > 2 {
                let track = parts[2]
                if let r = track.range(of: "ahead (\\d+)", options: .regularExpression) {
                    ahead = Int(track[r].components(separatedBy: " ").last ?? "") ?? 0
                }
                if let r = track.range(of: "behind (\\d+)", options: .regularExpression) {
                    behind = Int(track[r].components(separatedBy: " ").last ?? "") ?? 0
                }
            }

            return GitBranchInfo(name: name, isRemote: isRemote, isCurrent: name == current, upstream: upstream, ahead: ahead, behind: behind)
        }
    }

    // MARK: - Stashes

    public static func parseStashes(path: String) -> [GitStashEntry] {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" stash list --format='%gd|%gs' 2>/dev/null") ?? ""
        return raw.components(separatedBy: "\n").enumerated().compactMap { idx, line in
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: "'"))
            guard !trimmed.isEmpty else { return nil }
            let parts = trimmed.components(separatedBy: "|")
            return GitStashEntry(id: idx, message: parts.count > 1 ? parts[1] : trimmed)
        }
    }

    // MARK: - Conflict Detection

    public static func parseConflicts(path: String) -> [GitFileChange] {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" diff --name-only --diff-filter=U 2>/dev/null") ?? ""
        return raw.components(separatedBy: "\n").compactMap { line -> GitFileChange? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let fileName = (trimmed as NSString).lastPathComponent
            return GitFileChange(path: trimmed, fileName: fileName, status: .conflict, isStaged: false)
        }
    }

    // MARK: - Diff Parsing

    /// Parse raw git diff output into a structured GitDiffResult.
    public static func parseDiff(filePath: String, rawDiff: String) -> GitDiffResult {
        // Check for binary
        if rawDiff.contains("Binary files") {
            return GitDiffResult(filePath: filePath, hunks: [], isBinary: true, stats: (0, 0))
        }

        var hunks: [DiffHunk] = []
        var totalAdditions = 0
        var totalDeletions = 0

        let lines = rawDiff.components(separatedBy: "\n")
        var currentHunkHeader: String?
        var currentHunkLines: [DiffLine] = []
        var oldLineNum = 0
        var newLineNum = 0

        for line in lines {
            if line.hasPrefix("@@") {
                // Save previous hunk
                if let header = currentHunkHeader {
                    hunks.append(DiffHunk(header: header, lines: currentHunkLines))
                }
                currentHunkHeader = line
                currentHunkLines = []

                // Parse line numbers from header: @@ -oldStart,oldCount +newStart,newCount @@
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    let oldPart = parts[1] // e.g., "-1,3"
                    let newPart = parts[2] // e.g., "+1,4"
                    let oldStart = oldPart.dropFirst().components(separatedBy: ",").first.flatMap { Int($0) } ?? 1
                    let newStart = newPart.dropFirst().components(separatedBy: ",").first.flatMap { Int($0) } ?? 1
                    oldLineNum = oldStart
                    newLineNum = newStart
                }
            } else if currentHunkHeader != nil {
                if line.hasPrefix("+") && !line.hasPrefix("+++") {
                    currentHunkLines.append(DiffLine(
                        type: .addition,
                        content: String(line.dropFirst()),
                        oldLineNum: nil,
                        newLineNum: newLineNum
                    ))
                    newLineNum += 1
                    totalAdditions += 1
                } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                    currentHunkLines.append(DiffLine(
                        type: .deletion,
                        content: String(line.dropFirst()),
                        oldLineNum: oldLineNum,
                        newLineNum: nil
                    ))
                    oldLineNum += 1
                    totalDeletions += 1
                } else if line.hasPrefix(" ") {
                    currentHunkLines.append(DiffLine(
                        type: .context,
                        content: String(line.dropFirst()),
                        oldLineNum: oldLineNum,
                        newLineNum: newLineNum
                    ))
                    oldLineNum += 1
                    newLineNum += 1
                } else if line == "\\ No newline at end of file" {
                    // Skip this meta-line
                } else if !line.hasPrefix("diff") && !line.hasPrefix("index") && !line.hasPrefix("---") && !line.hasPrefix("+++") && !line.isEmpty {
                    // Context line without leading space (some edge cases)
                    currentHunkLines.append(DiffLine(
                        type: .context,
                        content: line,
                        oldLineNum: oldLineNum,
                        newLineNum: newLineNum
                    ))
                    oldLineNum += 1
                    newLineNum += 1
                }
            }
        }

        // Save last hunk
        if let header = currentHunkHeader {
            hunks.append(DiffHunk(header: header, lines: currentHunkLines))
        }

        return GitDiffResult(
            filePath: filePath,
            hunks: hunks,
            isBinary: false,
            stats: (additions: totalAdditions, deletions: totalDeletions)
        )
    }

    // MARK: - Blame Parsing

    public static func parseBlame(_ raw: String) -> [BlameLine] {
        guard !raw.isEmpty else { return [] }
        var lines: [BlameLine] = []
        var currentHash = ""
        var currentAuthor = ""
        var currentDate = Date()
        var lineNum = 0

        for line in raw.components(separatedBy: "\n") {
            if line.isEmpty { continue }

            // Header line: <hash> <orig-line> <final-line> [<num-lines>]
            let headerParts = line.split(separator: " ")
            if headerParts.count >= 3,
               headerParts[0].count == 40,
               headerParts[0].allSatisfy({ $0.isHexDigit }) {
                currentHash = String(headerParts[0])
                lineNum = Int(headerParts[2]) ?? (lineNum + 1)
            } else if line.hasPrefix("author ") {
                currentAuthor = String(line.dropFirst(7))
            } else if line.hasPrefix("author-time ") {
                if let ts = TimeInterval(line.dropFirst(12)) {
                    currentDate = Date(timeIntervalSince1970: ts)
                }
            } else if line.hasPrefix("\t") {
                // Content line
                let content = String(line.dropFirst())
                lines.append(BlameLine(
                    id: lineNum,
                    hash: currentHash,
                    shortHash: String(currentHash.prefix(7)),
                    author: currentAuthor,
                    date: currentDate,
                    content: content
                ))
            }
        }
        return lines
    }

    // MARK: - Commit Records Parsing (shared)

    public static func parseCommitRecords(_ raw: String) -> [GitCommitNode] {
        let fieldSep = "<<F>>"
        var commits: [GitCommitNode] = []
        let records = raw.components(separatedBy: "\0").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = trimmed.components(separatedBy: fieldSep)
            guard parts.count >= 8 else { continue }

            let hash = parts[0].trimmingCharacters(in: .init(charactersIn: "'"))
            let shortHash = parts[1]
            let subject = parts[2]
            let author = parts[3]
            let email = parts[4]
            let dateStr = parts[5]
            let parents = parts[6].split(separator: " ").map(String.init)
            let refStr = parts[7].trimmingCharacters(in: .init(charactersIn: "'"))
            let body = parts.count > 8 ? parts[8...].joined(separator: fieldSep).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let date = gitDateFormatter.date(from: dateStr) ?? Date()
            let refs = parseRefs(refStr)
            let coAuthors = parseCoAuthors(body)

            commits.append(GitCommitNode(
                id: hash, shortHash: shortHash, message: subject, body: body,
                author: author, authorEmail: email, date: date,
                parentHashes: parents, coAuthors: coAuthors, refs: refs
            ))
        }
        return commits
    }
}
