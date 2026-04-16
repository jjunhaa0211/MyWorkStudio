import SwiftUI
import Combine
import DesignSystem

public struct NewTabSheet: View {
    public init() {}
    @EnvironmentObject var manager: SessionManager; @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var settings = AppSettings.shared
    @StateObject var preferences = NewSessionPreferencesStore.shared
@State var projectName = ""
@State var projectPath = ""
@State var terminalCount = 1
@State var tasks: [String] = [""]

@State var showTrustPrompt = false
@State var didBootstrap = false
@State var pathError: String?
@State var isCreatingSessions = false

    // 고급 옵션
@State var showAdvanced = false
@State var permissionMode: PermissionMode = .bypassPermissions
@State var systemPrompt = ""
@State var maxBudget: String = ""
@State var allowedTools = ""
@State var disallowedTools = ""
@State var additionalDir = ""
@State var additionalDirs: [String] = []
@State var continueSession = false
@State var useWorktree = false
@State var showSavePreset = false
@State var activePresetId: String?
@State var unavailableProviderAlert: AgentProvider?
@State var selectedModel: ClaudeModel = .sonnet
@State var effortLevel: EffortLevel = .medium
@State var codexSandboxMode: CodexSandboxMode = .workspaceWrite
@State var codexApprovalPolicy: CodexApprovalPolicy = .onRequest

    var suggestedProjects: [NewSessionProjectRecord] {
        preferences.suggestedProjects(currentTabs: manager.userVisibleTabs, savedSessions: SessionStore.shared.load())
    }

    var favoriteProjects: [NewSessionProjectRecord] {
        suggestedProjects.filter(\.isFavorite).prefixArray(4)
    }

    var recentProjects: [NewSessionProjectRecord] {
        suggestedProjects.filter { !$0.isFavorite }.prefixArray(6)
    }

    var isCurrentProjectFavorite: Bool {
        preferences.isFavorite(path: projectPath)
    }

    var sheetAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.18)
    }

    var selectedProvider: AgentProvider {
        selectedModel.provider
    }

    var sheetVisibleFrame: CGRect {
        NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    var preferredSheetWidth: CGFloat {
        let baseWidth = 640 * min(max(settings.fontSizeScale, 1.0), 1.08)
        return min(max(560, baseWidth), max(560, sheetVisibleFrame.width - 80))
    }

    var preferredSheetHeight: CGFloat {
        let baseHeight = 720 * min(max(settings.fontSizeScale, 1.0), 1.05)
        return min(max(620, baseHeight), max(560, sheetVisibleFrame.height - 90))
    }

    var trustWarningText: String {
        switch selectedProvider {
        case .claude:
            return NSLocalizedString("terminal.trust.warning", comment: "")
        case .codex:
            return "Codex가 이 폴더의 파일을 읽고, 수정하고, 실행할 수 있습니다."
        case .gemini:
            return "Gemini가 이 폴더의 파일을 읽고, 수정하고, 실행할 수 있습니다."
        }
    }

    func providerSubtitle(_ provider: AgentProvider) -> String {
        let checker = provider.installChecker
        let version = checker.version
        let base: String
        switch provider {
        case .claude: base = "Claude Code CLI"
        case .codex: base = "Codex CLI"
        case .gemini: base = "Gemini CLI"
        }
        if checker.isInstalled, !version.isEmpty {
            return "\(base) · \(version)"
        }
        return base
    }

    func providerSymbol(_ provider: AgentProvider) -> String {
        switch provider {
        case .claude: return "bubble.left.and.bubble.right.fill"
        case .codex: return "terminal.fill"
        case .gemini: return "diamond.fill"
        }
    }

    func providerChipTint(_ provider: AgentProvider) -> Color {
        switch provider {
        case .claude: return Theme.accent
        case .codex: return Theme.orange
        case .gemini: return Theme.cyan
        }
    }

    func selectProvider(_ provider: AgentProvider) {
        guard selectedProvider != provider else { return }
        guard ensureProviderAvailable(provider) else { return }
        selectedModel = provider.defaultModel
    }

    func ensureProviderAvailable(_ provider: AgentProvider) -> Bool {
        guard provider.refreshAvailability(force: false) else {
            unavailableProviderAlert = provider
            return false
        }
        return true
    }

    public var body: some View {
        ZStack {
            sessionConfigView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(!showTrustPrompt)

            if showTrustPrompt {
                Color.black.opacity(0.38)
                    .overlay {
                        trustPromptView
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                    .zIndex(1)
            }
        }
        .frame(width: preferredSheetWidth, height: preferredSheetHeight)
        .background(Theme.bg)
        .onAppear {
            isCreatingSessions = false
            bootstrapFromLastDraftIfNeeded()
            // 현재 선택된 프로바이더가 미설치면 설치된 프로바이더로 전환
            if !selectedProvider.installChecker.isInstalled {
                selectedModel = AgentProvider.firstInstalled.defaultModel
            }
        }
        .alert(
            unavailableProviderAlert?.selectionUnavailableTitle ?? "",
            isPresented: Binding(get: { unavailableProviderAlert != nil }, set: { if !$0 { unavailableProviderAlert = nil } }),
            actions: { Button(NSLocalizedString("confirm", comment: "")) { unavailableProviderAlert = nil } },
            message: { Text(unavailableProviderAlert?.selectionUnavailableDetail ?? "") }
        )
    }

}
