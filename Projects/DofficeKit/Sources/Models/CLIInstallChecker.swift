import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - CLI Install Checker
// ═══════════════════════════════════════════════════════

public final class CLIInstallChecker {
    private let executableName: String
    private let knownExecutablePaths: [String]
    private let installHint: String
    private let lock = NSLock()
    private var _isInstalled = false
    private var _version = ""
    private var _path = ""
    private var _errorInfo = ""
    private var lastCheckedAt: Date?
    private let cacheTTL: TimeInterval = 30

    public init(executableName: String, knownExecutablePaths: [String], installHint: String) {
        self.executableName = executableName
        self.knownExecutablePaths = knownExecutablePaths
        self.installHint = installHint
    }

    public var isInstalled: Bool { lock.lock(); defer { lock.unlock() }; return _isInstalled }
    public var version: String { lock.lock(); defer { lock.unlock() }; return _version }
    public var path: String { lock.lock(); defer { lock.unlock() }; return _path }
    public var errorInfo: String { lock.lock(); defer { lock.unlock() }; return _errorInfo }

    public func check(force: Bool = false) {
        // 캐시 유효성만 lock 안에서 확인하고, 실제 셸 실행은 lock 밖에서 수행.
        // shellSync()는 서브프로세스를 실행하여 3초+ 블로킹될 수 있으므로
        // lock을 보유한 채 실행하면 다른 스레드에서 isInstalled/path 등을 읽을 때
        // 불필요한 lock contention이 발생합니다.
        lock.lock()
        if !force,
           let lastCheckedAt,
           Date().timeIntervalSince(lastCheckedAt) < cacheTTL {
            lock.unlock()
            return
        }
        lastCheckedAt = Date()
        let exe = executableName
        let knownPaths = knownExecutablePaths
        let hint = installHint
        lock.unlock()

        // 1) Try `which <cli>` with our enriched PATH
        if let p = TerminalTab.shellSync("which \(exe) 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            let ver = TerminalTab.shellSync("\(exe) --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lock.lock()
            _isInstalled = true; _path = p; _errorInfo = ""; _version = ver
            lock.unlock()
            return
        }

        // 2) Check well-known installation paths directly
        let allPATHDirs = TerminalTab.buildFullPATH().split(separator: ":").map(String.init)
        let allCandidates = knownPaths + allPATHDirs.map { $0 + "/\(exe)" }

        for candidate in allCandidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                let ver = TerminalTab.shellSync("\"\(candidate)\" --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                lock.lock()
                _isInstalled = true; _path = candidate; _errorInfo = ""; _version = ver
                lock.unlock()
                return
            }
        }

        // 3) Fallback: try login shell with timeout (prevents hang)
        if let p = TerminalTab.shellSyncLoginWithTimeout("which \(exe) 2>/dev/null", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            let ver = TerminalTab.shellSyncLoginWithTimeout("\"\(p)\" --version 2>/dev/null", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lock.lock()
            _isInstalled = true; _path = p; _errorInfo = ""; _version = ver
            lock.unlock()
            return
        }

        // Not found
        lock.lock()
        _isInstalled = false
        _version = ""
        _path = ""
        _errorInfo = hint
        lock.unlock()
    }
}

public enum ClaudeInstallChecker {
    public static let shared = CLIInstallChecker(
        executableName: "claude",
        knownExecutablePaths: [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            NSHomeDirectory() + "/.npm-global/bin/claude",
        ],
        installHint: "Claude CLI not found. Install with: \(AgentProvider.claude.installCommand)"
    )
}

public enum CodexInstallChecker {
    public static let shared = CLIInstallChecker(
        executableName: "codex",
        knownExecutablePaths: [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            NSHomeDirectory() + "/.npm-global/bin/codex",
        ],
        installHint: "Codex CLI not found. Install Codex Desktop or add the codex binary to PATH."
    )
}

public enum GeminiInstallChecker {
    public static let shared = CLIInstallChecker(
        executableName: "gemini",
        knownExecutablePaths: [
            "/usr/local/bin/gemini",
            "/opt/homebrew/bin/gemini",
            NSHomeDirectory() + "/.npm-global/bin/gemini",
            NSHomeDirectory() + "/.local/bin/gemini",
        ],
        installHint: "Gemini CLI not found. Install with: \(AgentProvider.gemini.installCommand)"
    )
}
