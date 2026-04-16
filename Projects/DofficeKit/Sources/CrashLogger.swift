import Foundation

/// 파일 기반 구조화 로깅 시스템
/// ~/Library/Logs/Doffice/ 에 로그 파일을 기록하여 사용자 버그 리포트에 활용
public final class CrashLogger {
    public static let shared = CrashLogger()

    public enum Level: String, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case fatal = "FATAL"
    }

    private let logDir: URL
    private let queue = DispatchQueue(label: "doffice.crash-logger", qos: .utility)
    private var fileHandle: FileHandle?
    private var currentLogDate: String = ""
    private let maxLogFiles = 7
    private let maxFileSize: UInt64 = 10 * 1024 * 1024 // 10MB

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        if let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            logDir = libraryDir.appendingPathComponent("Logs/Doffice", isDirectory: true)
        } else {
            logDir = FileManager.default.temporaryDirectory.appendingPathComponent("DofficeLog", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        rotateOldLogs()
    }

    // MARK: - Public API

    public func debug(_ message: String, file: String = #fileID, line: Int = #line) {
        write(.debug, message, file: file, line: line)
    }

    public func info(_ message: String, file: String = #fileID, line: Int = #line) {
        write(.info, message, file: file, line: line)
    }

    public func warning(_ message: String, file: String = #fileID, line: Int = #line) {
        write(.warning, message, file: file, line: line)
    }

    public func error(_ message: String, file: String = #fileID, line: Int = #line) {
        write(.error, message, file: file, line: line)
    }

    public func fatal(_ message: String, file: String = #fileID, line: Int = #line) {
        write(.fatal, message, file: file, line: line)
        flush()
    }

    /// 크래시 발생 시 호출 — 동기적으로 별도 파일에 기록
    /// Signal handler context에서 호출되므로 queue/lock을 사용하지 않고
    /// 별도 crash 파일에 직접 기록하여 기존 로그 파일과의 data race를 방지합니다.
    public func logCrash(signal: String, additionalInfo: String = "") {
        let timestamp = timestampFormatter.string(from: Date())
        var lines = [
            "",
            "════════════════════════════════════════════",
            "[\(timestamp)] CRASH SIGNAL: \(signal)",
            "════════════════════════════════════════════",
            "App Version: \(appVersion)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Uptime: \(formattedUptime)",
            "Memory: \(memoryUsage)",
        ]
        if !additionalInfo.isEmpty {
            lines.append("Info: \(additionalInfo)")
        }
        lines.append(Thread.callStackSymbols.prefix(20).joined(separator: "\n"))
        lines.append("════════════════════════════════════════════")
        lines.append("")

        let entry = lines.joined(separator: "\n")

        // Signal handler에서는 queue를 사용할 수 없으므로 별도 crash 파일에 직접 기록
        if let data = entry.data(using: .utf8) {
            let crashFile = logDir.appendingPathComponent("crash_\(dateFormatter.string(from: Date())).log")
            if !FileManager.default.fileExists(atPath: crashFile.path) {
                FileManager.default.createFile(atPath: crashFile.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            if let handle = FileHandle(forWritingAtPath: crashFile.path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.synchronizeFile()
                handle.closeFile()
            }
        }
    }

    /// NSException 발생 시 호출 — queue를 통해 thread-safe하게 기록
    public func logException(_ exception: NSException) {
        let timestamp = timestampFormatter.string(from: Date())
        var lines = [
            "",
            "════════════════════════════════════════════",
            "[\(timestamp)] UNCAUGHT EXCEPTION",
            "════════════════════════════════════════════",
            "Name: \(exception.name.rawValue)",
            "Reason: \(exception.reason ?? "unknown")",
            "App Version: \(appVersion)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
        ]
        if let symbols = exception.callStackSymbols as [String]? {
            lines.append("Stack trace:")
            lines.append(contentsOf: symbols.prefix(30))
        }
        lines.append("════════════════════════════════════════════")
        lines.append("")

        let entry = lines.joined(separator: "\n")
        // NSException handler는 signal handler가 아니므로 queue를 통해 안전하게 기록
        // async: 메인 스레드에서 호출 시 UI 블로킹 방지
        queue.async { [weak self] in
            guard let self = self, let data = entry.data(using: .utf8) else { return }
            self.ensureFileHandle()
            self.fileHandle?.write(data)
            self.fileHandle?.synchronizeFile()
        }
    }

    public func flush() {
        queue.sync {
            fileHandle?.synchronizeFile()
        }
    }

    /// 최근 로그 파일 경로들 반환 (DiagnosticReport에서 사용)
    public func recentLogFiles() -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "log" }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return aDate > bDate
            }
    }

    public var logDirectory: URL { logDir }

    // MARK: - Private

    private func write(_ level: Level, _ message: String, file: String, line: Int) {
        let timestamp = timestampFormatter.string(from: Date())
        let sourceFile = URL(fileURLWithPath: file).lastPathComponent
        let entry = "[\(timestamp)] [\(level.rawValue)] [\(sourceFile):\(line)] \(message)\n"

        queue.async { [weak self] in
            guard let self, let data = entry.data(using: .utf8) else { return }
            self.ensureFileHandle()
            self.fileHandle?.write(data)

            // 파일 크기 체크
            if let size = self.fileHandle?.offsetInFile, size > self.maxFileSize {
                self.fileHandle?.closeFile()
                self.fileHandle = nil
            }
        }
    }

    private func ensureFileHandle() {
        let today = dateFormatter.string(from: Date())
        if today != currentLogDate {
            fileHandle?.closeFile()
            fileHandle = nil
            currentLogDate = today
        }

        if fileHandle == nil {
            let logFile = logDir.appendingPathComponent("doffice_\(currentLogDate.isEmpty ? dateFormatter.string(from: Date()) : currentLogDate).log")
            if !FileManager.default.fileExists(atPath: logFile.path) {
                FileManager.default.createFile(atPath: logFile.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            fileHandle = FileHandle(forWritingAtPath: logFile.path)
            fileHandle?.seekToEndOfFile()

            // 새 로그 파일 시작 헤더
            let header = "# Doffice Log — \(currentLogDate) | v\(appVersion) | macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
            if let data = header.data(using: .utf8) {
                fileHandle?.write(data)
            }
        }
    }

    private func rotateOldLogs() {
        queue.async { [weak self] in
            guard let self else { return }
            let files = self.recentLogFiles()
            if files.count > self.maxLogFiles {
                for file in files.dropFirst(self.maxLogFiles) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var formattedUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private var memoryUsage: String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return "N/A" }
        let mb = Double(info.resident_size) / 1024 / 1024
        return String(format: "%.1f MB", mb)
    }
}
