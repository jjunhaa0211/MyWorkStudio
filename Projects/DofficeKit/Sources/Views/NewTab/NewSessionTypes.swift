import SwiftUI
import Combine
import DesignSystem

// MARK: - New Tab Sheet (멀티 터미널 지원)
// ═══════════════════════════════════════════════════════

public struct NewSessionProjectRecord: Codable, Identifiable, Hashable {
    public let path: String
    public var name: String
    public var lastUsedAt: Date
    public var isFavorite: Bool

    public var id: String { path }
}

public struct NewSessionDraftSnapshot: Codable {
    public var selectedModel: String
    public var effortLevel: String
    public var permissionMode: String
    public var codexSandboxMode: String
    public var codexApprovalPolicy: String
    public var terminalCount: Int
    public var systemPrompt: String
    public var maxBudget: String
    public var allowedTools: String
    public var disallowedTools: String
    public var additionalDirs: [String]
    public var continueSession: Bool
    public var useWorktree: Bool

    public init(
        selectedModel: String,
        effortLevel: String,
        permissionMode: String,
        codexSandboxMode: String = CodexSandboxMode.workspaceWrite.rawValue,
        codexApprovalPolicy: String = CodexApprovalPolicy.onRequest.rawValue,
        terminalCount: Int,
        systemPrompt: String,
        maxBudget: String,
        allowedTools: String,
        disallowedTools: String,
        additionalDirs: [String],
        continueSession: Bool,
        useWorktree: Bool
    ) {
        self.selectedModel = selectedModel
        self.effortLevel = effortLevel
        self.permissionMode = permissionMode
        self.codexSandboxMode = codexSandboxMode
        self.codexApprovalPolicy = codexApprovalPolicy
        self.terminalCount = terminalCount
        self.systemPrompt = systemPrompt
        self.maxBudget = maxBudget
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.additionalDirs = additionalDirs
        self.continueSession = continueSession
        self.useWorktree = useWorktree
    }

    private enum CodingKeys: String, CodingKey {
        case selectedModel
        case effortLevel
        case permissionMode
        case codexSandboxMode
        case codexApprovalPolicy
        case terminalCount
        case systemPrompt
        case maxBudget
        case allowedTools
        case disallowedTools
        case additionalDirs
        case continueSession
        case useWorktree
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModel = try container.decode(String.self, forKey: .selectedModel)
        effortLevel = try container.decode(String.self, forKey: .effortLevel)
        permissionMode = try container.decode(String.self, forKey: .permissionMode)
        codexSandboxMode = try container.decodeIfPresent(String.self, forKey: .codexSandboxMode) ?? CodexSandboxMode.workspaceWrite.rawValue
        codexApprovalPolicy = try container.decodeIfPresent(String.self, forKey: .codexApprovalPolicy) ?? CodexApprovalPolicy.onRequest.rawValue
        terminalCount = try container.decode(Int.self, forKey: .terminalCount)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        maxBudget = try container.decode(String.self, forKey: .maxBudget)
        allowedTools = try container.decode(String.self, forKey: .allowedTools)
        disallowedTools = try container.decode(String.self, forKey: .disallowedTools)
        additionalDirs = try container.decode([String].self, forKey: .additionalDirs)
        continueSession = try container.decode(Bool.self, forKey: .continueSession)
        useWorktree = try container.decode(Bool.self, forKey: .useWorktree)
    }
}

enum NewSessionPreset: String, CaseIterable, Identifiable {
    case balanced
    case planFirst
    case safeReview
    case parallelBuild

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced: return NSLocalizedString("terminal.preset.balanced", comment: "")
        case .planFirst: return NSLocalizedString("terminal.preset.planfirst", comment: "")
        case .safeReview: return NSLocalizedString("terminal.preset.safereview", comment: "")
        case .parallelBuild: return NSLocalizedString("terminal.preset.parallelbuild", comment: "")
        }
    }

    public var subtitle: String {
        switch self {
        case .balanced: return NSLocalizedString("terminal.preset.balanced.desc", comment: "")
        case .planFirst: return NSLocalizedString("terminal.preset.planfirst.desc", comment: "")
        case .safeReview: return NSLocalizedString("terminal.preset.safereview.desc", comment: "")
        case .parallelBuild: return NSLocalizedString("terminal.preset.parallelbuild.desc", comment: "")
        }
    }

    public var tint: Color {
        switch self {
        case .balanced: return Theme.accent
        case .planFirst: return Theme.purple
        case .safeReview: return Theme.orange
        case .parallelBuild: return Theme.cyan
        }
    }

    public var symbol: String {
        switch self {
        case .balanced: return "hammer.fill"
        case .planFirst: return "list.bullet.clipboard.fill"
        case .safeReview: return "shield.fill"
        case .parallelBuild: return "square.grid.3x1.folder.badge.plus"
        }
    }
}

public final class NewSessionPreferencesStore: ObservableObject {
    public static let shared = NewSessionPreferencesStore()

    @Published public private(set) var favoriteProjects: [NewSessionProjectRecord] = []
    @Published public private(set) var recentProjects: [NewSessionProjectRecord] = []
    @Published public private(set) var lastDraft: NewSessionDraftSnapshot?
    @Published public private(set) var trustedProjectPaths: [String] = []

    private let favoritesKey = "doffice.new-session.favorite-projects"
    private let recentsKey = "doffice.new-session.recent-projects"
    private let lastDraftKey = "doffice.new-session.last-draft"
    private let trustedProjectPathsKey = "doffice.new-session.trusted-project-paths"

    private init() {
        load()
    }

    public func isFavorite(path: String) -> Bool {
        favoriteProjects.contains(where: { $0.path == path })
    }

    public func toggleFavorite(projectName: String, projectPath: String) {
        guard !projectPath.isEmpty else { return }

        if let index = favoriteProjects.firstIndex(where: { $0.path == projectPath }) {
            favoriteProjects.remove(at: index)
        } else {
            favoriteProjects.insert(
                NewSessionProjectRecord(path: projectPath, name: projectName.isEmpty ? (projectPath as NSString).lastPathComponent : projectName, lastUsedAt: Date(), isFavorite: true),
                at: 0
            )
        }
        favoriteProjects = dedupeProjects(favoriteProjects).prefixArray(8)
        saveFavorites()
    }

    public func suggestedProjects(currentTabs: [TerminalTab], savedSessions: [SavedSession]) -> [NewSessionProjectRecord] {
        var merged: [String: NewSessionProjectRecord] = [:]

        for favorite in favoriteProjects {
            merged[favorite.path] = favorite
        }

        for recent in recentProjects {
            mergeProject(into: &merged, project: recent)
        }

        for tab in currentTabs {
            let record = NewSessionProjectRecord(
                path: tab.projectPath,
                name: tab.projectName,
                lastUsedAt: tab.lastActivityTime,
                isFavorite: isFavorite(path: tab.projectPath)
            )
            mergeProject(into: &merged, project: record)
        }

        for session in savedSessions {
            let record = NewSessionProjectRecord(
                path: session.projectPath,
                name: session.projectName,
                lastUsedAt: session.lastActivityTime ?? session.startTime,
                isFavorite: isFavorite(path: session.projectPath)
            )
            mergeProject(into: &merged, project: record)
        }

        return merged.values.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt > rhs.lastUsedAt }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func rememberLaunch(projectName: String, projectPath: String, draft: NewSessionDraftSnapshot) {
        guard !projectPath.isEmpty else { return }

        let record = NewSessionProjectRecord(
            path: projectPath,
            name: projectName,
            lastUsedAt: Date(),
            isFavorite: isFavorite(path: projectPath)
        )
        recentProjects.removeAll(where: { $0.path == projectPath })
        recentProjects.insert(record, at: 0)
        recentProjects = dedupeProjects(recentProjects).prefixArray(10)
        lastDraft = draft
        saveRecents()
        saveLastDraft()
    }

    public func isTrusted(projectPath: String) -> Bool {
        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { return true }
        return trustedProjectPaths.contains(where: {
            normalized == $0 || normalized.hasPrefix($0 + "/")
        })
    }

    public func trust(projectPath: String) {
        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { return }

        if trustedProjectPaths.contains(where: { normalized == $0 || normalized.hasPrefix($0 + "/") }) {
            return
        }

        trustedProjectPaths.removeAll { $0.hasPrefix(normalized + "/") }
        trustedProjectPaths.insert(normalized, at: 0)
        trustedProjectPaths = Array(trustedProjectPaths.prefix(64))
        saveTrustedProjectPaths()
    }

    private func mergeProject(into merged: inout [String: NewSessionProjectRecord], project: NewSessionProjectRecord) {
        if let existing = merged[project.path] {
            let preferredName = existing.name.count >= project.name.count ? existing.name : project.name
            merged[project.path] = NewSessionProjectRecord(
                path: project.path,
                name: preferredName,
                lastUsedAt: max(existing.lastUsedAt, project.lastUsedAt),
                isFavorite: existing.isFavorite || project.isFavorite
            )
        } else {
            merged[project.path] = project
        }
    }

    private func dedupeProjects(_ projects: [NewSessionProjectRecord]) -> [NewSessionProjectRecord] {
        var seen = Set<String>()
        return projects.filter { project in
            seen.insert(project.path).inserted
        }
    }

    private func normalizeProjectPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expanded, isDirectory: true)
        let standardized = baseURL.standardizedFileURL.path
        // resolvingSymlinksInPath can crash on non-existent paths
        guard FileManager.default.fileExists(atPath: standardized) else { return standardized }
        return baseURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = PersistenceService.shared.data(forKey: favoritesKey),
           let decoded = try? decoder.decode([NewSessionProjectRecord].self, from: data) {
            favoriteProjects = decoded
        }
        if let data = PersistenceService.shared.data(forKey: recentsKey),
           let decoded = try? decoder.decode([NewSessionProjectRecord].self, from: data) {
            recentProjects = decoded
        }
        if let data = PersistenceService.shared.data(forKey: lastDraftKey),
           let decoded = try? decoder.decode(NewSessionDraftSnapshot.self, from: data) {
            lastDraft = decoded
        }
        if let storedPaths = PersistenceService.shared.array(forKey: trustedProjectPathsKey) as? [String] {
            trustedProjectPaths = storedPaths
                .map(normalizeProjectPath)
                .filter { !$0.isEmpty }
        }
    }

    private func saveFavorites() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(favoriteProjects) {
            PersistenceService.shared.set(data, forKey: favoritesKey)
        }
    }

    private func saveRecents() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(recentProjects) {
            PersistenceService.shared.set(data, forKey: recentsKey)
        }
    }

    private func saveLastDraft() {
        let encoder = JSONEncoder()
        if let draft = lastDraft, let data = try? encoder.encode(draft) {
            PersistenceService.shared.set(data, forKey: lastDraftKey)
        }
    }

    private func saveTrustedProjectPaths() {
        PersistenceService.shared.set(trustedProjectPaths, forKey: trustedProjectPathsKey)
    }
}

extension Array {
    func prefixArray(_ maxCount: Int) -> [Element] {
        Array(prefix(maxCount))
    }
}
