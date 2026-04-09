import Foundation
import Combine

// ═══════════════════════════════════════════════════════
// MARK: - EventBus
// ═══════════════════════════════════════════════════════

/// 타입 안전 이벤트 시스템.
/// NotificationCenter의 문자열 기반 알림을 점진적으로 대체.
public final class EventBus {

    public static let shared = EventBus()

    // MARK: - Event Types

    public enum Event {
        // ── 탭 라이프사이클 ──
        case newTab
        case closeTab(tabId: String)
        case selectTab(tabId: String)
        case nextTab
        case previousTab
        case tabCycleCompleted

        // ── 세션 ──
        case cancelProcessing
        case clearTerminal
        case restartSession
        case exportLog
        case sessionStoreDidChange
        case sessionSaveFailed(Error)
        case scrollToBlock(blockId: String)

        // ── 오피스 ──
        case toggleOffice
        case toggleTerminal
        case toggleSplit
        case focusCharacterTab(tabId: String)

        // ── 플러그인 ──
        case pluginReload
        case pluginCharactersChanged
        case pluginEffectEvent(event: PluginEventType, context: [String: Any])
        case pluginRequestSessionInfo(webView: AnyObject?)
        case pluginNotify(text: String)

        // ── UI ──
        case refresh
        case claudeNotInstalled
        case roleNotice(role: String, summary: String)
        case commandPalette
        case actionCenter
        case openBrowser(url: URL?)
        case toggleBrowser(url: URL?)
        case diagnosticReport
        case copyConversation
    }

    // MARK: - Internal

    private let subject = PassthroughSubject<Event, Never>()

    private init() {}

    // MARK: - Post

    /// 이벤트 발행. 기존 NotificationCenter와 브릿지하여 점진적 마이그레이션 지원.
    public func post(_ event: Event) {
        subject.send(event)

        // 전환기 브릿지: 기존 NotificationCenter로도 전달
        if let legacy = event.legacyNotification {
            NotificationCenter.default.post(name: legacy.name, object: nil, userInfo: legacy.userInfo)
        }
    }

    // MARK: - Subscribe

    /// 모든 이벤트 구독.
    public func subscribe(_ handler: @escaping (Event) -> Void) -> AnyCancellable {
        subject.sink(receiveValue: handler)
    }

    /// 특정 이벤트만 필터링하여 구독.
    public func on<T>(_ match: @escaping (Event) -> T?, handler: @escaping (T) -> Void) -> AnyCancellable {
        subject.compactMap(match).sink(receiveValue: handler)
    }
}

// MARK: - Legacy Bridge

private extension EventBus.Event {
    struct LegacyNotification {
        let name: Notification.Name
        let userInfo: [String: Any]?
    }

    var legacyNotification: LegacyNotification? {
        switch self {
        case .newTab:
            return LegacyNotification(name: .dofficeNewTab, userInfo: nil)
        case .closeTab(let tabId):
            return LegacyNotification(name: .dofficeCloseTab, userInfo: ["tabId": tabId])
        case .selectTab(let tabId):
            return LegacyNotification(name: .dofficeSelectTab, userInfo: ["tabId": tabId])
        case .nextTab:
            return LegacyNotification(name: .dofficeNextTab, userInfo: nil)
        case .previousTab:
            return LegacyNotification(name: .dofficePreviousTab, userInfo: nil)
        case .tabCycleCompleted:
            return LegacyNotification(name: .dofficeTabCycleCompleted, userInfo: nil)
        case .cancelProcessing:
            return LegacyNotification(name: .dofficeCancelProcessing, userInfo: nil)
        case .clearTerminal:
            return LegacyNotification(name: .dofficeClearTerminal, userInfo: nil)
        case .restartSession:
            return LegacyNotification(name: .dofficeRestartSession, userInfo: nil)
        case .exportLog:
            return LegacyNotification(name: .dofficeExportLog, userInfo: nil)
        case .sessionStoreDidChange:
            return LegacyNotification(name: .dofficeSessionStoreDidChange, userInfo: nil)
        case .sessionSaveFailed:
            return LegacyNotification(name: .dofficeSessionSaveFailed, userInfo: nil)
        case .scrollToBlock(let blockId):
            return LegacyNotification(name: .dofficeScrollToBlock, userInfo: ["blockId": blockId])
        case .toggleOffice:
            return LegacyNotification(name: .dofficeToggleOffice, userInfo: nil)
        case .toggleTerminal:
            return LegacyNotification(name: .dofficeToggleTerminal, userInfo: nil)
        case .toggleSplit:
            return LegacyNotification(name: .dofficeToggleSplit, userInfo: nil)
        case .focusCharacterTab(let tabId):
            return LegacyNotification(name: .dofficeFocusCharacterTab, userInfo: ["tabId": tabId])
        case .pluginReload:
            return LegacyNotification(name: .pluginReload, userInfo: nil)
        case .pluginNotify(let text):
            return LegacyNotification(name: .pluginNotify, userInfo: ["text": text])
        case .refresh:
            return LegacyNotification(name: .dofficeRefresh, userInfo: nil)
        case .claudeNotInstalled:
            return LegacyNotification(name: .dofficeClaudeNotInstalled, userInfo: nil)
        case .roleNotice(let role, let summary):
            return LegacyNotification(name: .dofficeRoleNotice, userInfo: ["role": role, "summary": summary])
        case .commandPalette:
            return LegacyNotification(name: .dofficeCommandPalette, userInfo: nil)
        case .actionCenter:
            return LegacyNotification(name: .dofficeActionCenter, userInfo: nil)
        case .openBrowser(let url):
            var info: [String: Any] = [:]
            if let url { info["url"] = url }
            return LegacyNotification(name: .dofficeOpenBrowser, userInfo: info.isEmpty ? nil : info)
        case .toggleBrowser(let url):
            var info: [String: Any] = [:]
            if let url { info["url"] = url }
            return LegacyNotification(name: .dofficeToggleBrowser, userInfo: info.isEmpty ? nil : info)
        case .diagnosticReport:
            return LegacyNotification(name: .dofficeDiagnosticReport, userInfo: nil)
        case .copyConversation:
            return LegacyNotification(name: .dofficeCopyConversation, userInfo: nil)
        case .pluginEffectEvent, .pluginRequestSessionInfo, .pluginCharactersChanged:
            return nil
        }
    }
}
