import SwiftUI
import UserNotifications

@main
struct WorkManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = SessionManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(manager)
                .environmentObject(settings)
                .frame(minWidth: 1000, minHeight: 650)
                .preferredColorScheme(settings.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        // 오피스 전용 창 (듀얼 모니터용)
        WindowGroup("WorkMan Office", id: "office-window") {
            OfficeWindowView()
                .environmentObject(manager)
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Sessions") {
                    NotificationCenter.default.post(name: .workmanRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .workmanNewTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Session") {
                    NotificationCenter.default.post(name: .workmanCloseTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Toggle Split View") {
                    NotificationCenter.default.post(name: .workmanToggleSplit, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("Export Session Log") {
                    NotificationCenter.default.post(name: .workmanExportLog, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                ForEach(1...9, id: \.self) { index in
                    Button("Session \(index)") {
                        NotificationCenter.default.post(name: .workmanSelectTab, object: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                }
            }
        }
    }
}

extension Notification.Name {
    static let workmanRefresh = Notification.Name("workmanRefresh")
    static let workmanNewTab = Notification.Name("workmanNewTab")
    static let workmanCloseTab = Notification.Name("workmanCloseTab")
    static let workmanSelectTab = Notification.Name("workmanSelectTab")
    static let workmanToggleSplit = Notification.Name("workmanToggleSplit")
    static let workmanExportLog = Notification.Name("workmanExportLog")
    static let workmanClaudeNotInstalled = Notification.Name("workmanClaudeNotInstalled")
    static let workmanTabCycleCompleted = Notification.Name("workmanTabCycleCompleted")
    static let workmanRoleNotice = Notification.Name("workmanRoleNotice")
    static let workmanSessionStoreDidChange = Notification.Name("workmanSessionStoreDidChange")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager = MenuBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        menuBarManager.setup()

        // Claude 설치 확인
        ClaudeInstallChecker.shared.check()
        if ClaudeInstallChecker.shared.isInstalled {
            print("[WorkMan] Claude Code \(ClaudeInstallChecker.shared.version) found at \(ClaudeInstallChecker.shared.path)")
        } else {
            print("[WorkMan] ⚠️ Claude Code not installed")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionManager.shared.saveSessions(immediately: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let manager = SessionManager.shared
        let runningTabs = manager.tabs.filter { $0.isProcessing }

        // 진행 중인 작업이 없으면 바로 종료
        guard !runningTabs.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "진행 중인 작업이 \(runningTabs.count)개 있습니다"
        alert.informativeText = "앱을 종료하면 현재 진행 중인 작업은 완료되지 않습니다.\n자동 롤백은 하지 않고, 복구 폴더를 만든 뒤 안전하게 중단할 수 있습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "백업 후 중단하고 종료")
        alert.addButton(withTitle: "그대로 종료")
        alert.addButton(withTitle: "취소")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // 모든 진행 중인 작업을 백업한 뒤 중단
            for tab in runningTabs {
                _ = SessionStore.shared.writeRecoveryBundle(for: tab, reason: "앱 종료 전 진행 중 작업 백업")
                tab.forceStop()
            }
            manager.saveSessions(immediately: true)
            return .terminateNow
        case .alertSecondButtonReturn:
            // 롤백 없이 그대로 종료
            for tab in runningTabs {
                tab.forceStop()
            }
            manager.saveSessions(immediately: true)
            return .terminateNow
        default:
            // 취소 - 종료하지 않음
            return .terminateCancel
        }
    }

    // Feature 3: 메뉴바에서 창 다시 열기
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 창이 없으면 새로 열기
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
