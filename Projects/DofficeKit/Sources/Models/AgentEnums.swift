import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Enums
// ═══════════════════════════════════════════════════════

public enum ClaudeActivity: String {
    case idle = "idle"
    case thinking = "thinking"
    case reading = "reading"
    case writing = "writing"
    case searching = "searching"
    case running = "running bash"
    case done = "done"
    case error = "error"
}

public enum AgentProvider: String, CaseIterable, Identifiable {
    case claude
    case codex
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        }
    }

    public var executableName: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .gemini: return "gemini"
        }
    }

    public var defaultModel: AgentModel {
        switch self {
        case .claude: return .sonnet
        case .codex: return .gpt54
        case .gemini: return .gemini25Pro
        }
    }

    public var models: [AgentModel] {
        AgentModel.allCases.filter { $0.provider == self }
    }

    public var installChecker: CLIInstallChecker {
        switch self {
        case .claude: return ClaudeInstallChecker.shared
        case .codex: return CodexInstallChecker.shared
        case .gemini: return GeminiInstallChecker.shared
        }
    }

    public var installTitle: String {
        switch self {
        case .claude: return NSLocalizedString("tab.claude.not.installed", comment: "")
        case .codex: return "Codex CLI not found"
        case .gemini: return "Gemini CLI not found"
        }
    }

    public var installCommand: String {
        switch self {
        case .claude:
            return "npm install -g @anthropic-ai/claude-code"
        case .codex:
            return "npm install -g @openai/codex"
        case .gemini:
            return "npm install -g @google/gemini-cli"
        }
    }

    public var installDetail: String {
        switch self {
        case .claude:
            return NSLocalizedString("tab.claude.not.installed.detail", comment: "")
        case .codex:
            return "Codex CLI를 찾을 수 없습니다.\n\n설치 후 `which codex`로 경로를 확인해주세요."
        case .gemini:
            return "Gemini CLI를 찾을 수 없습니다.\n\n설치: \(installCommand)\n설치 후 `which gemini`로 경로를 확인해주세요."
        }
    }

    public var selectionUnavailableTitle: String {
        switch self {
        case .claude:
            return "Claude CLI를 확인해주세요"
        case .codex:
            return "Codex 모델을 확인해주세요"
        case .gemini:
            return "Gemini CLI를 확인해주세요"
        }
    }

    public var selectionUnavailableDetail: String {
        switch self {
        case .claude:
            return "Claude를 선택하려면 터미널에서 `which claude`로 설치 여부를 확인해주세요."
        case .codex:
            return "Codex를 선택하려면 터미널에서 `which codex`로 설치 여부를 확인하고, 사용할 수 있는 모델이 보이는지 확인해주세요."
        case .gemini:
            return "Gemini를 선택하려면 터미널에서 `which gemini`로 설치 여부를 확인해주세요."
        }
    }

    @discardableResult
    public func refreshAvailability(force: Bool = true) -> Bool {
        installChecker.check(force: force)
        return installChecker.isInstalled
    }

    public var shellLabel: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .gemini: return "gemini"
        }
    }
}

public enum AgentModel: String, CaseIterable, Identifiable {
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"
    case gpt54 = "gpt-5.4"
    case gpt54Mini = "gpt-5.4-mini"
    case gpt53Codex = "gpt-5.3-codex"
    case gpt52Codex = "gpt-5.2-codex"
    case gpt52 = "gpt-5.2"
    case gpt51CodexMax = "gpt-5.1-codex-max"
    case gpt51CodexMini = "gpt-5.1-codex-mini"
    case gemini25Pro = "gemini-2.5-pro"
    case gemini25Flash = "gemini-2.5-flash"

    public var id: String { rawValue }

    public var provider: AgentProvider {
        switch self {
        case .opus, .sonnet, .haiku:
            return .claude
        case .gpt54, .gpt54Mini, .gpt53Codex, .gpt52Codex, .gpt52, .gpt51CodexMax, .gpt51CodexMini:
            return .codex
        case .gemini25Pro, .gemini25Flash:
            return .gemini
        }
    }

    public var icon: String {
        switch self {
        case .opus: return "🟣"
        case .sonnet: return "🔵"
        case .haiku: return "🟢"
        case .gpt54: return "◉"
        case .gpt54Mini: return "◌"
        case .gpt53Codex: return "⌘"
        case .gpt52Codex: return "⌘"
        case .gpt52: return "○"
        case .gpt51CodexMax: return "◆"
        case .gpt51CodexMini: return "◇"
        case .gemini25Pro: return "💎"
        case .gemini25Flash: return "⚡"
        }
    }

    public var displayName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .gpt54: return "GPT-5.4"
        case .gpt54Mini: return "GPT-5.4-Mini"
        case .gpt53Codex: return "GPT-5.3-Codex"
        case .gpt52Codex: return "GPT-5.2-Codex"
        case .gpt52: return "GPT-5.2"
        case .gpt51CodexMax: return "GPT-5.1-Codex-Max"
        case .gpt51CodexMini: return "GPT-5.1-Codex-Mini"
        case .gemini25Pro: return "Gemini 2.5 Pro"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        }
    }

    public var isRecommended: Bool {
        switch self {
        case .sonnet, .gpt54, .gemini25Pro:
            return true
        default:
            return false
        }
    }

    public static func detect(from value: String) -> AgentModel? {
        let lowered = value.lowercased()
        return allCases.first { lowered.contains($0.rawValue) }
    }
}

public typealias ClaudeModel = AgentModel

public enum EffortLevel: String, CaseIterable, Identifiable {
    case low, medium, high, max
    public var id: String { rawValue }
    public var icon: String { switch self { case .low: return "🐢"; case .medium: return "🚶"; case .high: return "🏃"; case .max: return "🚀" } }
}

public enum OutputMode: String, CaseIterable, Identifiable {
    case full = "전체", realtime = "실시간", resultOnly = "결과만"
    public var id: String { rawValue }
    public var icon: String { switch self { case .full: return "📋"; case .realtime: return "⚡"; case .resultOnly: return "📌" } }
    public var displayName: String {
        switch self {
        case .full: return NSLocalizedString("output.mode.full", comment: "")
        case .realtime: return NSLocalizedString("output.mode.realtime", comment: "")
        case .resultOnly: return NSLocalizedString("output.mode.resultOnly", comment: "")
        }
    }
}

public enum CodexSandboxMode: String, CaseIterable, Identifiable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .readOnly: return "읽기 전용"
        case .workspaceWrite: return "작업 폴더"
        case .dangerFullAccess: return "전체 허용"
        }
    }

    public var icon: String {
        switch self {
        case .readOnly: return "👀"
        case .workspaceWrite: return "🛠"
        case .dangerFullAccess: return "⚠️"
        }
    }

    public var shortLabel: String {
        switch self {
        case .readOnly: return "읽기"
        case .workspaceWrite: return "작업"
        case .dangerFullAccess: return "전체"
        }
    }
}

public enum CodexApprovalPolicy: String, CaseIterable, Identifiable {
    case untrusted
    case onRequest = "on-request"
    case never

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .untrusted: return "안전만"
        case .onRequest: return "필요 시"
        case .never: return "묻지 않음"
        }
    }

    public var icon: String {
        switch self {
        case .untrusted: return "🛡️"
        case .onRequest: return "🤝"
        case .never: return "⚡"
        }
    }

    public var shortLabel: String {
        switch self {
        case .untrusted: return "안전"
        case .onRequest: return "요청"
        case .never: return "자동"
        }
    }
}

public enum WorkerState: String {
    case idle, walking, coding, pairing, success, error
    case thinking, reading, writing, searching, running
}

// 권한 모드 (--permission-mode)
public enum PermissionMode: String, CaseIterable, Identifiable {
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
    case auto = "auto"
    case defaultMode = "default"
    case plan = "plan"
    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .acceptEdits: return "✏️"
        case .bypassPermissions: return "⚡"
        case .auto: return "🤖"
        case .defaultMode: return "🛡️"
        case .plan: return "📋"
        }
    }
    public var displayName: String {
        switch self {
        case .acceptEdits: return NSLocalizedString("perm.acceptEdits", comment: "")
        case .bypassPermissions: return NSLocalizedString("perm.bypass", comment: "")
        case .auto: return NSLocalizedString("perm.auto", comment: "")
        case .defaultMode: return NSLocalizedString("perm.default", comment: "")
        case .plan: return NSLocalizedString("perm.plan", comment: "")
        }
    }
    public var desc: String {
        switch self {
        case .acceptEdits: return NSLocalizedString("perm.acceptEdits.desc", comment: "")
        case .bypassPermissions: return NSLocalizedString("perm.bypass.desc", comment: "")
        case .auto: return NSLocalizedString("perm.auto.desc", comment: "")
        case .defaultMode: return NSLocalizedString("perm.default.desc", comment: "")
        case .plan: return NSLocalizedString("perm.plan.desc", comment: "")
        }
    }
}

// 승인 모드 (UI용 - legacy)
public enum ApprovalMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case ask = "Ask"
    case safe = "Safe"
    public var id: String { rawValue }
    public var icon: String { switch self { case .auto: return "⚡"; case .ask: return "🛡️"; case .safe: return "🔒" } }
    public var displayName: String { switch self { case .auto: return NSLocalizedString("output.auto", comment: ""); case .ask: return NSLocalizedString("output.ask", comment: ""); case .safe: return NSLocalizedString("output.safe", comment: "") } }
    public var desc: String { switch self { case .auto: return NSLocalizedString("output.auto.desc", comment: ""); case .ask: return NSLocalizedString("output.ask.desc", comment: ""); case .safe: return NSLocalizedString("output.safe.desc", comment: "") } }
}

// 로그 필터
public struct BlockFilter {
    public var toolTypes: Set<String> = []   // 비어있으면 전부 표시
    public var onlyErrors: Bool = false
    public var searchText: String = ""

    public init(toolTypes: Set<String> = [], onlyErrors: Bool = false, searchText: String = "") {
        self.toolTypes = toolTypes; self.onlyErrors = onlyErrors; self.searchText = searchText
    }

    public var isActive: Bool { !toolTypes.isEmpty || onlyErrors || !searchText.isEmpty }

    public func matches(_ block: StreamBlock) -> Bool {
        // 에러 필터
        if onlyErrors {
            switch block.blockType {
            case .toolError, .error: break
            case .toolEnd(let success): if success { return false }
            default: return false
            }
        }
        // 도구 필터
        if !toolTypes.isEmpty {
            switch block.blockType {
            case .toolUse(let name, _): if !toolTypes.contains(name) { return false }
            case .toolOutput, .toolError, .toolEnd: break // 도구 결과는 항상 표시
            case .userPrompt, .thought, .completion, .error, .status, .sessionStart: break
            case .fileChange(_, let action):
                if !toolTypes.contains(action) && !toolTypes.contains("Write") && !toolTypes.contains("Edit") { return false }
            case .text: break
            }
        }
        // 검색 필터
        if !searchText.isEmpty {
            if !block.content.localizedCaseInsensitiveContains(searchText) { return false }
        }
        return true
    }
}
