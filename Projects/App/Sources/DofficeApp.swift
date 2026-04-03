import SwiftUI
import UserNotifications
import DesignSystem
import DofficeKit

@main
struct DofficeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = SessionManager.shared
    @ObservedObject private var settings = AppSettings.shared

    static var screenBasedMainSize: CGSize {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1920, height: 1080)
        return CGSize(width: screen.width * 0.65, height: screen.height * 0.75)
    }

    static var screenBasedMinSize: (CGFloat, CGFloat) {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1920, height: 1080)
        return (max(800, screen.width * 0.5), max(500, screen.height * 0.5))
    }

    static var screenBasedOfficeSize: CGSize {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1920, height: 1080)
        return CGSize(width: screen.width * 0.5, height: screen.height * 0.55)
    }

    @ViewBuilder
    private var rootView: some View {
        MainView()
            .environmentObject(manager)
            .environmentObject(settings)
            .frame(minWidth: Self.screenBasedMinSize.0, minHeight: Self.screenBasedMinSize.1)
            .preferredColorScheme(settings.colorScheme)
    }

    @SceneBuilder
    private var mainWindowScene: some Scene {
        WindowGroup {
            rootView
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: Self.screenBasedMainSize.width, height: Self.screenBasedMainSize.height)
    }

    @CommandsBuilder
    private var officeCommands: some Commands {
        // 단축키는 ShortcutManager의 NSEvent 모니터가 동적으로 처리
        // 메뉴 항목은 표시용으로 유지하되 단축키 힌트를 동적으로 표시
        CommandGroup(after: .newItem) {
            ForEach(ShortcutAction.allCases) { action in
                Button(action.localizedName) {
                    NotificationCenter.default.post(name: action.notificationName, object: nil)
                }
            }

            Divider()

            ForEach(1...9, id: \.self) { index in
                Button("Session \(index)") {
                    NotificationCenter.default.post(name: .dofficeSelectTab, object: index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }
        }
    }

    @SceneBuilder
    private var officeWindowScene: some Scene {
        WindowGroup("도피스 오피스", id: "office-window") {
            OfficeWindowView()
                .environmentObject(manager)
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: Self.screenBasedOfficeSize.width, height: Self.screenBasedOfficeSize.height)
        .commands {
            officeCommands
        }
    }

    @SceneBuilder
    var body: some Scene {
        mainWindowScene
        officeWindowScene
    }
}

// Notification.Name extensions are now in DesignSystem/Theme.swift

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager = MenuBarManager()
    private var recoveryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if SmokeTestHarness.isEnabled {
            SmokeTestHarness.beginLaunchMonitoring()
            return
        }

        // 번들 ID 변경 시 이전 데이터 마이그레이션
        migrateFromOldBundleIfNeeded()

        // 사용자 언어 설정 적용
        AppSettings.shared.applyLanguage()

        // 앱 아이콘 적용
        let iconStyle = AppSettings.shared.appIconStyle
        if iconStyle != "classic", let iconImage = NSImage(named: "AppIcon\(iconStyle.capitalized)Preview") {
            NSApplication.shared.applicationIconImage = iconImage
        }

        // 동적 단축키 이벤트 모니터 설치
        ShortcutManager.shared.installEventMonitor()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        menuBarManager.setup()

        // 글로벌 크래시 핸들러 — 예기치 않은 종료 시 세션 자동 저장
        setupCrashRecovery()

        // CLI 설치 확인 (백그라운드에서 실행 — 메인 스레드 블로킹 방지)
        DispatchQueue.global(qos: .userInitiated).async {
            ClaudeInstallChecker.shared.check()
            CodexInstallChecker.shared.check()
            DispatchQueue.main.async {
                if ClaudeInstallChecker.shared.isInstalled {
                    print("[도피스] Claude Code \(ClaudeInstallChecker.shared.version) found at \(ClaudeInstallChecker.shared.path)")
                } else {
                    print("[도피스] ⚠️ Claude Code not installed")
                }
                if CodexInstallChecker.shared.isInstalled {
                    print("[도피스] Codex \(CodexInstallChecker.shared.version) found at \(CodexInstallChecker.shared.path)")
                } else {
                    print("[도피스] ⚠️ Codex not installed")
                }
            }
        }

        // 윈도우 복원 실패 시에만 안전 창을 띄운다 (정상 시작 시 불필요한 fallback 방지).
        scheduleMainWindowRecovery()

        // 정상 윈도우가 뜨면 fallback 자동 dismiss
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
            self?.dismissFallbackWindowIfNeeded()
        }
    }

    /// 보이는 창이 하나도 없으면 메인 창을 강제로 생성/표시
    private func ensureMainWindowVisible() {
        // 시트가 열려있으면 메인 윈도우를 건드리지 않음
        if NSApp.windows.contains(where: { $0.isSheet || $0.sheetParent != nil }) {
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        if revealExistingWindows() {
            return
        }

        var requestedWindowOpen = false
        let openSelectors = [
            #selector(NSResponder.newWindowForTab(_:)),
            Selector(("newWindow:"))
        ]
        for selector in openSelectors where NSApp.sendAction(selector, to: nil, from: nil) {
            requestedWindowOpen = true
            break
        }

        if !requestedWindowOpen {
            requestedWindowOpen = NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        }

        if requestedWindowOpen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                if !self.revealExistingWindows() {
                    self.presentFallbackMainWindow()
                }
            }
        } else {
            presentFallbackMainWindow()
        }
    }

    private var mainWindowRecovered = false

    private func scheduleMainWindowRecovery() {
        let recoveryDelays: [TimeInterval] = [1.0, 2.0, 4.0]
        for delay in recoveryDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.mainWindowRecovered else { return }
                self.ensureMainWindowVisible()
            }
        }
    }

    @discardableResult
    private func revealExistingWindows() -> Bool {
        var restoredWindow = false
        for window in NSApp.windows {
            // 시트, 패널, 팝업 등 시스템 관리 윈도우는 건드리지 않음
            guard window.contentView != nil || window.contentViewController != nil,
                  !window.isSheet,
                  window.sheetParent == nil,
                  !(window is NSPanel),
                  window.level == .normal else { continue }

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            moveWindowOnScreenIfNeeded(window)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            restoredWindow = restoredWindow || isUsableWindow(window)
        }
        if restoredWindow {
            mainWindowRecovered = true
            dismissFallbackWindowIfNeeded()
        }
        return restoredWindow
    }

    private func moveWindowOnScreenIfNeeded(_ window: NSWindow) {
        let needsResize = window.frame.width < 320 || window.frame.height < 240
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        let isOffscreen = !visibleFrames.contains(where: { $0.intersects(window.frame) })
        guard needsResize || isOffscreen else { return }
        guard let targetFrame = NSScreen.main?.visibleFrame ?? visibleFrames.first else { return }

        let preferredWidth = needsResize ? targetFrame.width * 0.65 : window.frame.width
        let preferredHeight = needsResize ? targetFrame.height * 0.75 : window.frame.height
        let width = min(preferredWidth, max(900, targetFrame.width - 40))
        let height = min(preferredHeight, max(620, targetFrame.height - 40))
        let origin = NSPoint(
            x: targetFrame.midX - (width / 2),
            y: targetFrame.midY - (height / 2)
        )
        let safeFrame = NSRect(origin: origin, size: NSSize(width: width, height: height))
        window.setFrame(safeFrame, display: false, animate: false)
    }

    private func isUsableWindow(_ window: NSWindow) -> Bool {
        window.isVisible &&
        !window.isMiniaturized &&
        window.frame.width >= 320 &&
        window.frame.height >= 240
    }

    private func presentFallbackMainWindow() {
        if revealExistingWindows() {
            return
        }

        if let recoveryWindow {
            moveWindowOnScreenIfNeeded(recoveryWindow)
            recoveryWindow.orderFrontRegardless()
            recoveryWindow.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = AnyView(
            MainView()
                .environmentObject(SessionManager.shared)
                .environmentObject(AppSettings.shared)
                .frame(minWidth: DofficeApp.screenBasedMinSize.0, minHeight: DofficeApp.screenBasedMinSize.1)
                .preferredColorScheme(AppSettings.shared.colorScheme)
        )
        let hostingController = NSHostingController(rootView: rootView)

        let mainSize = DofficeApp.screenBasedMainSize
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: mainSize.width, height: mainSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("DofficeRecoveryWindow")
        window.title = AppSettings.shared.appDisplayName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)

        mainWindowRecovered = true
        recoveryWindow = window
    }

    private func dismissFallbackWindowIfNeeded() {
        guard let recoveryWindow else { return }
        let hasRegularWindow = NSApp.windows.contains { window in
            window != recoveryWindow &&
            isUsableWindow(window) &&
            (window.contentView != nil || window.contentViewController != nil)
        }
        guard hasRegularWindow else { return }
        recoveryWindow.close()
        self.recoveryWindow = nil
    }

    /// 이전 번들 ID (com.junha.doffice)의 UserDefaults 데이터를 현재 앱으로 마이그레이션
    private func migrateFromOldBundleIfNeeded() {
        let migrationKey = "doffice.migrated.from.doffice"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // 이전 번들의 UserDefaults 읽기
        guard let oldDefaults = UserDefaults(suiteName: "com.junha.doffice") else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let oldDict = oldDefaults.dictionaryRepresentation()
        guard !oldDict.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // 마이그레이션 대상 키 (중요 데이터)
        let keysToMigrate = [
            // 도전과제 & 레벨
            "DofficeAchievements",
            // 캐릭터
            "DofficeCharacters",
            "DofficeCharacterManualUnlocks",
            // 토큰 사용량
            "DofficeTokenHistory",
            // 감사 로그
            "DofficeAuditLog",
            // 앱 설정
            "isDarkMode", "fontSizeScale", "officeViewMode", "officePreset",
            "backgroundTheme", "reviewerMaxPasses", "qaMaxPasses",
            "automationRevisionLimit", "allowParallelSubagents",
            "terminalSidebarLightweight", "rawTerminalMode",
            "autoRefreshOnSettingsChange", "appDisplayName", "companyName",
            "hasCompletedOnboarding",
            // 커피 지원 & 휴게실
            "breakRoomShowSofa", "breakRoomShowCoffeeMachine", "breakRoomShowPlant",
            "breakRoomShowSideTable", "breakRoomShowClock", "breakRoomShowPicture",
            "breakRoomShowNeonSign", "breakRoomShowRug", "breakRoomShowBookshelf",
            "breakRoomShowAquarium", "breakRoomShowArcade", "breakRoomShowWhiteboard",
            "breakRoomShowLamp", "breakRoomShowCat", "breakRoomShowTV",
            "breakRoomShowFan", "breakRoomShowCalendar", "breakRoomShowPoster",
            // 토큰 한도
            "userDailyTokenLimit", "userWeeklyTokenLimit",
            // 뷰 모드
            "viewModeRaw", "officeExpanded", "sidebarWidth",
            // 세션 관련
            "doffice.selectedGroupPath",
            "doffice.sidebarStatusFilter", "doffice.sidebarSortOption",
            // 새 세션 프리셋
            "doffice.new-session.favorite-projects",
            "doffice.new-session.recent-projects",
            "doffice.new-session.last-draft",
            // 자동화 템플릿
            "doffice.automation.templates.v1",
            // 오피스 레이아웃
            "doffice.office.layout.cozy.v1",
            "doffice.office.layout.startup.v1",
            "doffice.office.layout.enterprise.v1",
            // 단축키
            "doffice.customShortcuts",
        ]

        var migratedCount = 0
        for key in keysToMigrate {
            if let value = oldDict[key], UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
                migratedCount += 1
            }
        }

        // @AppStorage 키도 포함: 패턴 매칭으로 나머지 키 마이그레이션
        for (key, value) in oldDict {
            if key.hasPrefix("doffice.") || key.hasPrefix("Doffice"),
               UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
                migratedCount += 1
            }
        }

        // 세션 JSON 파일도 마이그레이션 (Application Support/Doffice → 동일 경로 유지)
        // SessionStore는 이미 "Doffice" 경로를 사용하므로 파일 이동 불필요

        UserDefaults.standard.set(true, forKey: migrationKey)
        if migratedCount > 0 {
            print("[도피스] ✅ 이전 데이터 마이그레이션 완료: \(migratedCount)개 항목")
        }
    }

    /// 시그널 수신 시 안전하게 세션 저장 후 종료
    /// 주의: signal handler 내에서는 async-signal-safe 함수만 호출 가능하므로,
    /// 실제 저장은 DispatchSource를 통해 메인 스레드에서 처리
    private func setupCrashRecovery() {
        let signals: [Int32] = [SIGTERM, SIGINT, SIGHUP]
        for sig in signals {
            // 기본 시그널 핸들러를 무시하고 DispatchSource로 처리
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                SessionManager.shared.saveSessions(immediately: true)
                exit(0)
            }
            source.resume()
            // source가 해제되지 않도록 유지
            _signalSources.append(source)
        }

        // NSException (Objective-C 예외) 핸들러
        NSSetUncaughtExceptionHandler { exception in
            print("[Doffice] Uncaught exception: \(exception.name) — \(exception.reason ?? "unknown")")
            // 예외 핸들러에서는 최소한의 작업만 수행 — 저장은 best-effort
            SessionManager.shared.saveSessions(immediately: true)
        }
    }
    private var _signalSources: [DispatchSourceSignal] = []

    func applicationWillTerminate(_ notification: Notification) {
        SessionManager.shared.saveSessions(immediately: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 이미 보이는 일반 윈도우가 있으면 불필요한 윈도우 재정렬을 하지 않음
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            isUsableWindow(window) &&
            !window.isSheet &&
            window.sheetParent == nil &&
            !(window is NSPanel) &&
            window.level == .normal
        }
        guard !hasVisibleMainWindow else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.ensureMainWindowVisible()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let manager = SessionManager.shared
        let runningTabs = manager.tabs.filter { $0.isProcessing }

        // 진행 중인 작업이 없으면 바로 종료
        guard !runningTabs.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("quit.running.title", comment: ""), runningTabs.count)
        alert.informativeText = NSLocalizedString("quit.running.message", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("quit.backup.and.quit", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("quit.force", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("cancel", comment: ""))

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
            scheduleMainWindowRecovery()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
