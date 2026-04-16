import Foundation
import Darwin

// ═══════════════════════════════════════════════════════
// MARK: - Claude Usage Fetcher (실제 Claude 플랜 사용량 조회)
// ═══════════════════════════════════════════════════════

public enum ClaudeUsageFetcher {

    // MARK: - Structured Usage Data

    public struct UsageSection: Identifiable {
        public let id = UUID()
        public let label: String
        public let percent: Int
        public let resetInfo: String
    }

    public struct UsageData {
        public let sections: [UsageSection]
        public let extraInfo: String
        public let rawText: String

        public var isEmpty: Bool { sections.isEmpty }
    }

    /// 비동기 래퍼 — 백그라운드에서 fetch 후 메인 스레드 콜백
    public static func fetchAsync(completion: @escaping (UsageData) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = fetchStructured()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// 구조화된 결과 반환
    public static func fetchStructured() -> UsageData {
        let raw = fetch()
        return parseUsageStructured(raw)
    }

    /// Claude CLI를 인터랙티브 PTY로 실행하여 /usage 결과를 캡처
    public static func fetch() -> String {
        guard let claudePath = findClaude() else {
            return "❌ Claude CLI를 찾을 수 없습니다."
        }

        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0
        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            return "❌ PTY 열기 실패"
        }

        // 터미널 크기 설정 (충분히 넓게)
        var winSize = winsize(ws_row: 50, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0)
        let _ = ioctl(masterFD, TIOCSWINSZ, &winSize)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["PATH"] = TerminalTab.buildFullPATH()
        process.environment?["TERM"] = "xterm-256color"
        process.environment?["COLUMNS"] = "120"
        process.environment?["LINES"] = "50"

        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        do {
            try process.run()
        } catch {
            close(masterFD)
            close(slaveFD)
            return "❌ Claude 실행 실패: \(error.localizedDescription)"
        }
        close(slaveFD)

        defer {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            close(masterFD)
        }

        // 시작 대기 — Claude CLI 프롬프트가 나올 때까지 (최대 5초, 폴링 0.15초)
        var startupData = Data()
        let bootStart = Date()
        while Date().timeIntervalSince(bootStart) < 5.0 {
            Thread.sleep(forTimeInterval: 0.15)
            var buf = [UInt8](repeating: 0, count: 4096)
            _ = withTemporarilyNonBlocking(masterFD, work: {
                while true {
                    let n = Darwin.read(masterFD, &buf, buf.count)
                    if n <= 0 { break }
                    startupData.append(buf, count: n)
                }
            })
            let partial = String(data: startupData, encoding: .utf8) ?? ""
            // Claude CLI가 프롬프트를 표시했으면 준비 완료
            if partial.contains(">") || partial.contains("❯") || partial.contains("claude") { break }
        }

        // /usage 입력
        writeSlow(masterFD, "/usage")
        Thread.sleep(forTimeInterval: 0.2)
        _ = Darwin.write(masterFD, "\r", 1)  // Enter

        // 데이터 수집 — 최대 10초, 결과 감지 시 조기 종료
        var allData = Data()
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 10.0 {
            Thread.sleep(forTimeInterval: 0.3)
            var buf = [UInt8](repeating: 0, count: 8192)
            _ = withTemporarilyNonBlocking(masterFD, work: {
                while true {
                    let n = Darwin.read(masterFD, &buf, buf.count)
                    if n <= 0 { break }
                    allData.append(buf, count: n)
                }
            })

            let partial = String(data: allData, encoding: .utf8) ?? ""
            if partial.contains("% used") { break }
            if partial.contains("Esc") && partial.contains("cancel") { break }
            if partial.contains("usage") && partial.contains("Reset") { break }
        }

        // 정리
        _ = Darwin.write(masterFD, "\u{1b}", 1) // Esc
        Thread.sleep(forTimeInterval: 0.3)
        _ = Darwin.write(masterFD, "\u{03}", 1) // Ctrl+C
        Thread.sleep(forTimeInterval: 0.2)
        writeSlow(masterFD, "/exit\r")
        Thread.sleep(forTimeInterval: 0.3)

        let raw = String(data: allData, encoding: .utf8) ?? ""
        return parseUsageOutput(raw)
    }

    private static func findClaude() -> String? {
        for dir in TerminalTab.buildFullPATH().split(separator: ":").map(String.init) {
            let p = dir + "/claude"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    private static func writeSlow(_ fd: Int32, _ text: String) {
        for ch in text {
            var c = [UInt8](String(ch).utf8)
            Darwin.write(fd, &c, c.count)
            Thread.sleep(forTimeInterval: 0.04)
        }
    }

    private static func drainFD(_ fd: Int32) -> Bool {
        var buf = [UInt8](repeating: 0, count: 4096)
        return withTemporarilyNonBlocking(fd, work: {
            while Darwin.read(fd, &buf, buf.count) > 0 {}
        })
    }

    private static func withTemporarilyNonBlocking(_ fd: Int32, work: () -> Void) -> Bool {
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0 else { return false }
        guard fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else { return false }
        defer { _ = fcntl(fd, F_SETFL, flags) }
        work()
        return true
    }

    private static func stripANSI(_ raw: String) -> String {
        // 모든 제어 시퀀스를 바이트 레벨에서 제거
        var result = ""
        var i = raw.startIndex
        while i < raw.endIndex {
            let ch = raw[i]
            if ch == "\u{1b}" {
                // ESC 시퀀스 스킵
                let nextIdx = raw.index(after: i)
                guard nextIdx < raw.endIndex else { break }
                i = nextIdx
                let next = raw[i]
                if next == "[" || next == "]" {
                    // CSI / OSC 시퀀스: 종료 문자까지 스킵
                    i = raw.index(after: i)
                    while i < raw.endIndex {
                        let c = raw[i]
                        i = raw.index(after: i)
                        if next == "[" && c.isLetter { break }
                        if next == "]" && (c == "\u{07}" || c == "\u{1b}") { break }
                    }
                } else {
                    // 단일 ESC + 문자
                    let afterNext = raw.index(after: i)
                    guard afterNext <= raw.endIndex else { break }
                    i = afterNext
                }
            } else if ch.asciiValue ?? 32 < 32 && ch != "\n" {
                // 제어 문자 스킵 (\r, \t 등)
                i = raw.index(after: i)
            } else {
                result.append(ch)
                i = raw.index(after: i)
            }
        }
        return result
    }

    private static func parseUsageStructured(_ displayText: String) -> UsageData {
        let text = stripANSI(displayText)
        let sectionKeys: [(key: String, label: String)] = [
            ("Current session", "현재 세션"),
            ("Current week (all models)", "이번 주 — 전체"),
            ("Current week (Sonnet only)", "이번 주 — Sonnet"),
            ("Current week (Opus only)", "이번 주 — Opus"),
            ("Current day", "오늘"),
        ]
        var sections: [UsageSection] = []
        for (key, label) in sectionKeys {
            guard text.contains(key) else { continue }
            let pctPattern = "(\(NSRegularExpression.escapedPattern(for: key))).*?(\\d+)%\\s*used"
            guard let regex = try? NSRegularExpression(pattern: pctPattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let pctRange = Range(match.range(at: 2), in: text) else { continue }
            let pct = Int(text[pctRange]) ?? 0
            var resetInfo = ""
            if let keyRange = text.range(of: key) {
                let after = String(text[keyRange.upperBound...])
                let resetPattern = "Resets?\\s+(.+?)(?:\\n|$)"
                if let rRegex = try? NSRegularExpression(pattern: resetPattern),
                   let rMatch = rRegex.firstMatch(in: after, range: NSRange(after.startIndex..., in: after)),
                   let rRange = Range(rMatch.range(at: 1), in: after) {
                    resetInfo = String(after[rRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "[^a-zA-Z0-9:/ ().,]", with: "", options: .regularExpression)
                }
            }
            sections.append(UsageSection(label: label, percent: pct, resetInfo: resetInfo))
        }
        var extraInfo = ""
        if text.contains("Extra usage not enabled") {
            extraInfo = "Extra usage 비활성"
        } else if text.contains("extra usage") || text.contains("Extra usage") {
            extraInfo = "Extra usage 활성"
        }
        return UsageData(sections: sections, extraInfo: extraInfo, rawText: displayText)
    }

    private static func parseUsageOutput(_ raw: String) -> String {
        let text = stripANSI(raw)

        // 섹션별 퍼센트 + 리셋 정보 추출
        struct UsageSection {
            let label: String
            let percent: Int
            let resetInfo: String
        }

        let sectionKeys: [(key: String, label: String)] = [
            ("Current session", "현재 세션 (Current Session)"),
            ("Current week (all models)", "이번 주 — 전체 모델 (All Models)"),
            ("Current week (Sonnet only)", "이번 주 — Sonnet 전용"),
            ("Current week (Opus only)", "이번 주 — Opus 전용"),
            ("Current day", "오늘 (Current Day)"),
        ]

        var sections: [UsageSection] = []

        for (key, label) in sectionKeys {
            guard text.contains(key) else { continue }
            // "XX% used" 찾기
            let pctPattern = "(\(NSRegularExpression.escapedPattern(for: key))).*?(\\d+)%\\s*used"
            guard let regex = try? NSRegularExpression(pattern: pctPattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let pctRange = Range(match.range(at: 2), in: text) else { continue }
            let pct = Int(text[pctRange]) ?? 0

            // "Resets ..." 찾기 — key 이후에서 가장 가까운 것
            var resetInfo = ""
            if let keyRange = text.range(of: key) {
                let after = String(text[keyRange.upperBound...])
                let resetPattern = "Resets?\\s+(.+?)(?:\\n|$)"
                if let rRegex = try? NSRegularExpression(pattern: resetPattern),
                   let rMatch = rRegex.firstMatch(in: after, range: NSRange(after.startIndex..., in: after)),
                   let rRange = Range(rMatch.range(at: 1), in: after) {
                    resetInfo = String(after[rRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    // 쓸데없는 문자 정리
                    resetInfo = resetInfo.replacingOccurrences(of: "[^a-zA-Z0-9:/ ().,]", with: "", options: .regularExpression)
                }
            }

            sections.append(UsageSection(label: label, percent: pct, resetInfo: resetInfo))
        }

        // Extra usage 상태
        var extraInfo = ""
        if text.contains("Extra usage not enabled") {
            extraInfo = "❌ Extra usage 비활성 · /extra-usage로 활성화"
        } else if text.contains("extra usage") || text.contains("Extra usage") {
            if let regex = try? NSRegularExpression(pattern: "Extra usage.*?(\\d+)%", options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let pctRange = Range(match.range(at: 1), in: text) {
                extraInfo = "✅ Extra usage 활성: \(text[pctRange])% 사용"
            } else {
                extraInfo = "✅ Extra usage 활성"
            }
        }

        // 파싱 실패 시
        if sections.isEmpty {
            // 원본에서 핵심만 추출
            let cleanLines = text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count > 3 }
                .filter { !$0.contains("Tips") && !$0.contains("Welcome") && !$0.contains("─") && !$0.contains("╭") && !$0.contains("╰") }
            if cleanLines.isEmpty {
                return "📊 Claude 사용량 조회 실패\n\n터미널에서 직접 /usage를 실행해보세요."
            }
            return "📊 Claude 사용량\n\n" + cleanLines.prefix(15).joined(separator: "\n")
        }

        // 예쁜 결과 조립
        var lines = [
            "📊 Claude 플랜 사용량",
            "══════════════════════════════════════",
        ]

        for s in sections {
            let barLen = 32
            let filled = Int(Double(barLen) * Double(s.percent) / 100.0)
            let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barLen - filled)
            let color = s.percent >= 80 ? "🔴" : s.percent >= 50 ? "🟡" : "🟢"

            lines.append("")
            lines.append("\(color) \(s.label)")
            lines.append("  \(bar) \(s.percent)% used")
            if !s.resetInfo.isEmpty {
                lines.append("  ⏰ 리셋: \(s.resetInfo)")
            }
        }

        if !extraInfo.isEmpty {
            lines.append("")
            lines.append(extraInfo)
        }

        lines.append("")
        lines.append("══════════════════════════════════════")

        return lines.joined(separator: "\n")
    }
}
