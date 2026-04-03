import Foundation
import AppKit
import SwiftUI
import Darwin
import DesignSystem
import DofficeKit

enum SmokeTestHarness {
    private static let launchArgument = "--smoke-test"
    private static let environmentKey = "DOFFICE_SMOKE_TEST"
    private static let timeoutArgumentPrefix = "--smoke-timeout="

    private static var didScheduleTimeout = false
    private static var didFinish = false

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        || ProcessInfo.processInfo.environment[environmentKey] == "1"
    }

    private static var timeout: TimeInterval {
        for argument in ProcessInfo.processInfo.arguments {
            if argument.hasPrefix(timeoutArgumentPrefix),
               let value = TimeInterval(argument.dropFirst(timeoutArgumentPrefix.count)),
               value > 0 {
                return value
            }
        }
        return 20
    }

    static func beginLaunchMonitoring() {
        guard isEnabled, !didScheduleTimeout else { return }
        didScheduleTimeout = true
        runPreflight()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            fail("Smoke test timed out before the main view became interactive.")
        }
    }

    static func completeMainViewSmoke(manager: SessionManager, settings: AppSettings) {
        guard isEnabled, !didFinish else { return }
        let summary = [
            "tabs=\(manager.userVisibleTabs.count)",
            "installedPlugins=\(PluginManager.shared.plugins.count)",
            "theme=\(settings.themeMode)"
        ].joined(separator: ", ")
        finish(code: EXIT_SUCCESS, message: "Smoke test passed (\(summary)).")
    }

    static func fail(_ message: String) {
        guard isEnabled, !didFinish else { return }
        finish(code: EXIT_FAILURE, message: message, isError: true)
    }

    private static func runPreflight() {
        _ = Theme.bg
        _ = Theme.bgGradient
        _ = Theme.accentBackground
        _ = Theme.accentSoftBackground
        _ = PluginManager.shared.plugins.count
        _ = SessionManager.shared.userVisibleTabs.count
        _ = DSButton("Smoke", icon: "bolt.fill", tone: .accent, prominent: true) {}
        _ = DSStatCard(title: "Sessions", value: "0", subtitle: "Smoke", icon: "terminal")
        _ = AppStatusBadge(title: "Ready", symbol: "checkmark.circle.fill", tint: Theme.green)
    }

    private static func finish(code: Int32, message: String, isError: Bool = false) {
        didFinish = true
        let line = "[SmokeTest] \(message)\n"
        if isError {
            FileHandle.standardError.write(Data(line.utf8))
        } else {
            FileHandle.standardOutput.write(Data(line.utf8))
        }
        fflush(stdout)
        fflush(stderr)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(code)
        }
    }
}
