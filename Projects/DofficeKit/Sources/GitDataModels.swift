import SwiftUI
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Git Data Models
// ═══════════════════════════════════════════════════════

public struct GitCommitNode: Identifiable, Equatable {
    public let id: String            // full SHA
    public let shortHash: String
    public let message: String
    public let body: String          // full message body (for co-authors, etc.)
    public let author: String
    public let authorEmail: String
    public let date: Date
    public let parentHashes: [String]
    public let coAuthors: [String]
    public let refs: [GitRef]
    public var lane: Int = 0         // column for graph drawing
    public var activeLanes: Set<Int> = [] // which lanes are active at this row (for drawing vertical lines)
    /// 자식 커밋들이 사용하는 레인 (브랜치 분기 곡선용)
    public var childLanes: Set<Int> = []
    /// 첫 번째 부모의 레인 (-1이면 부모 없음)
    public var firstParentLane: Int = -1

    public struct GitRef: Equatable {
        public let name: String
        public let type: RefType
        public enum RefType: Equatable { case branch, remoteBranch, tag, head }
    }
}

public struct GitFileChange: Identifiable, Hashable {
    public let id: String
    public let path: String
    public let fileName: String
    public let status: ChangeStatus
    public let isStaged: Bool

    public init(path: String, fileName: String, status: ChangeStatus, isStaged: Bool) {
        self.id = "\(isStaged ? "S" : "U")_\(status.rawValue)_\(path)"
        self.path = path
        self.fileName = fileName
        self.status = status
        self.isStaged = isStaged
    }

    public enum ChangeStatus: String, Hashable {
        case modified = "M", added = "A", deleted = "D"
        case renamed = "R", copied = "C", untracked = "?"
        case typeChanged = "T", conflict = "U"

        public var icon: String {
            switch self {
            case .modified: return "pencil.circle.fill"
            case .added: return "plus.circle.fill"
            case .deleted: return "minus.circle.fill"
            case .renamed: return "arrow.right.circle.fill"
            case .copied: return "doc.on.doc.fill"
            case .untracked: return "questionmark.circle.fill"
            case .typeChanged: return "arrow.triangle.2.circlepath"
            case .conflict: return "exclamationmark.triangle.fill"
            }
        }

        public var color: Color {
            switch self {
            case .modified: return Theme.yellow
            case .added: return Theme.green
            case .deleted: return Theme.red
            case .renamed: return Theme.cyan
            case .copied: return Theme.accent
            case .untracked: return Theme.textDim
            case .typeChanged: return Theme.orange
            case .conflict: return Theme.red
            }
        }
    }
}

public struct GitBranchInfo: Identifiable {
    public var id: String { name }
    public let name: String
    public let isRemote: Bool
    public let isCurrent: Bool
    public let upstream: String?
    public let ahead: Int
    public let behind: Int
}

public struct GitStashEntry: Identifiable {
    public let id: Int
    public let message: String
}

// ═══════════════════════════════════════════════════════
// MARK: - Blame Model
// ═══════════════════════════════════════════════════════

public struct BlameLine: Identifiable {
    public let id: Int              // line number (1-based)
    public let hash: String         // commit SHA
    public let shortHash: String
    public let author: String
    public let date: Date
    public let content: String      // actual line content
}

// ═══════════════════════════════════════════════════════
// MARK: - Diff Models
// ═══════════════════════════════════════════════════════

public struct GitDiffResult {
    public let filePath: String
    public let hunks: [DiffHunk]
    public let isBinary: Bool
    public let stats: (additions: Int, deletions: Int)

    public static func == (lhs: GitDiffResult, rhs: GitDiffResult) -> Bool {
        lhs.filePath == rhs.filePath && lhs.hunks == rhs.hunks && lhs.isBinary == rhs.isBinary
    }
}

public struct DiffHunk: Equatable {
    public let header: String // @@ -1,3 +1,4 @@
    public let lines: [DiffLine]
}

public struct DiffLine: Equatable {
    public let type: LineType
    public let content: String
    public let oldLineNum: Int?
    public let newLineNum: Int?

    public enum LineType: Equatable {
        case context, addition, deletion
    }
}
