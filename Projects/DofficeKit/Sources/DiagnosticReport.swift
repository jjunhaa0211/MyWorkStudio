import Foundation
import AppKit

/// 버그 리포트를 zip 파일로 내보내는 유틸리티
/// 메뉴 > "문제 신고" 또는 Command Palette에서 사용
public final class DiagnosticReport {

    public static let shared = DiagnosticReport()
    private init() {}

    /// 진단 리포트를 zip으로 만들어 저장할 위치를 사용자에게 묻고 저장
    @MainActor
    public func exportInteractively() {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("diagnostic.export.title", comment: "Export Diagnostic Report")
        panel.nameFieldStringValue = "doffice-diagnostic-\(dateStamp).zip"
        panel.allowedContentTypes = [.zip]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try export(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("diagnostic.export.error", comment: "Export Failed")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// 프로그래밍 방식으로 특정 경로에 리포트 저장
    public func export(to zipURL: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("doffice-diag-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. 시스템 정보
        let systemInfo = gatherSystemInfo()
        try systemInfo.write(to: tempDir.appendingPathComponent("system-info.txt"), atomically: true, encoding: .utf8)

        // 2. 최근 로그 파일 복사
        let logsDir = tempDir.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        for logFile in CrashLogger.shared.recentLogFiles().prefix(3) {
            let dest = logsDir.appendingPathComponent(logFile.lastPathComponent)
            try? FileManager.default.copyItem(at: logFile, to: dest)
        }

        // 3. 감사 로그 (최근 200개)
        if let auditData = AuditLog.shared.exportJSON() {
            try auditData.write(to: tempDir.appendingPathComponent("audit-log.json"))
        }

        // 4. 세션 상태 요약 (민감 정보 제외)
        let sessionSummary = gatherSessionSummary()
        try sessionSummary.write(to: tempDir.appendingPathComponent("session-summary.txt"), atomically: true, encoding: .utf8)

        // 5. UserDefaults 일부 (설정만)
        let settingsDump = gatherSettings()
        try settingsDump.write(to: tempDir.appendingPathComponent("settings.txt"), atomically: true, encoding: .utf8)

        // zip으로 압축
        try? FileManager.default.removeItem(at: zipURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, zipURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "DiagnosticReport", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create zip archive"])
        }
    }

    // MARK: - Gather Info

    private func gatherSystemInfo() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let mem = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        let cores = ProcessInfo.processInfo.processorCount

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let appMem = result == KERN_SUCCESS ? String(format: "%.1f MB", Double(info.resident_size) / 1024 / 1024) : "N/A"

        return """
        Doffice Diagnostic Report
        ========================
        Generated: \(Date())

        App Version: \(version) (\(build))
        macOS: \(os)
        Physical RAM: \(mem) GB
        CPU Cores: \(cores)
        App Memory: \(appMem)
        Uptime: \(formattedUptime)
        Locale: \(Locale.current.identifier)
        """
    }

    private func gatherSessionSummary() -> String {
        let sessions = SessionStore.shared.load()
        var lines = ["Session Summary (\(sessions.count) sessions)", ""]

        for (i, session) in sessions.prefix(20).enumerated() {
            lines.append("[\(i + 1)] \(session.projectName)")
            lines.append("    Path: \(session.projectPath)")
            lines.append("    Worker: \(session.workerName)")
            lines.append("    Tokens: \(session.tokensUsed)")
            if let errorCount = session.errorCount, errorCount > 0 {
                lines.append("    Errors: \(errorCount)")
            }
            if session.wasProcessing == true {
                lines.append("    ** Was processing when saved **")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func gatherSettings() -> String {
        let keys = [
            "isDarkMode", "fontSizeScale", "officeViewMode", "officePreset",
            "backgroundTheme", "rawTerminalMode", "hasCompletedOnboarding",
            "viewModeRaw", "officeExpanded", "auditLogEnabled",
        ]
        var lines = ["App Settings", ""]
        for key in keys {
            let value = PersistenceService.shared.object(forKey: key)
            lines.append("\(key) = \(value ?? "nil" as Any)")
        }
        return lines.joined(separator: "\n")
    }

    private var dateStamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    private var formattedUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
