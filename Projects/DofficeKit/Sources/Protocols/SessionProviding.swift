import SwiftUI

// MARK: - SessionProviding

/// SessionManager의 핵심 인터페이스.
/// 테스트 시 모킹 가능하도록 프로토콜로 분리.
public protocol SessionProviding: AnyObject {
    var tabs: [TerminalTab] { get }
    var activeTabId: String? { get set }
    var userVisibleTabs: [TerminalTab] { get }
    var activeTab: TerminalTab? { get }
    var userVisibleTabCount: Int { get }

    @discardableResult
    func addTab(projectName: String, projectPath: String, provider: AgentProvider, isClaude: Bool, detectedPid: Int?, sessionCount: Int, branch: String?, initialPrompt: String?, preferredCharacterId: String?, automationSourceTabId: String?, automationReportPath: String?, manualLaunch: Bool, autoStart: Bool, restoredSession: SavedSession?) -> TerminalTab
    func removeTab(_ id: String)
    func selectTab(_ id: String)
    func tab(for id: String) -> TerminalTab?
}

/// SessionManager에서 tab(for:) 기본 구현 제공
public extension SessionProviding {
    func tab(for id: String) -> TerminalTab? {
        tabs.first(where: { $0.id == id })
    }
}
