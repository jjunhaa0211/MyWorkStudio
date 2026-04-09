import Foundation

public struct DangerousPattern {
    public let regex: String
    public let severity: DangerousSeverity
    public let description: String

    public init(regex: String, severity: DangerousSeverity, description: String) {
        self.regex = regex
        self.severity = severity
        self.description = description
    }
}

public enum DangerousSeverity: String {
    case critical = "치명적"
    case high = "높음"
    case medium = "주의"

    public var displayName: String {
        switch self {
        case .critical: return NSLocalizedString("danger.critical", comment: "")
        case .high: return NSLocalizedString("danger.high", comment: "")
        case .medium: return NSLocalizedString("danger.medium", comment: "")
        }
    }
}

public struct DangerousCommandMatch {
    public let pattern: DangerousPattern
    public let matchedText: String
}

public class DangerousCommandDetector: ObservableObject {
    public static let shared = DangerousCommandDetector()

    @Published public var enabled: Bool {
        didSet { PersistenceService.shared.set(enabled, forKey: "dangerousCommandDetectionEnabled") }
    }
    @Published public var customPatterns: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(customPatterns) {
                PersistenceService.shared.set(data, forKey: "customDangerousPatterns")
            }
        }
    }

    public static let builtInPatterns: [DangerousPattern] = [
        DangerousPattern(regex: #"rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|.*--no-preserve-root)"#, severity: .critical, description: "강제 삭제 명령"),
        DangerousPattern(regex: #"rm\s+-[a-zA-Z]*r[a-zA-Z]*\s+(/|~|\$HOME)"#, severity: .critical, description: "루트/홈 디렉토리 재귀 삭제"),
        DangerousPattern(regex: #"git\s+push\s+.*--force"#, severity: .high, description: "Git 강제 푸시"),
        DangerousPattern(regex: #"git\s+reset\s+--hard"#, severity: .high, description: "Git 하드 리셋"),
        DangerousPattern(regex: #"git\s+clean\s+-[a-zA-Z]*f"#, severity: .medium, description: "Git 추적되지 않는 파일 삭제"),
        DangerousPattern(regex: #"DROP\s+(TABLE|DATABASE)"#, severity: .critical, description: "데이터베이스 삭제"),
        DangerousPattern(regex: #"DELETE\s+FROM\s+\w+\s*;"#, severity: .high, description: "테이블 전체 삭제"),
        DangerousPattern(regex: #"chmod\s+(777|a\+rwx)"#, severity: .medium, description: "과도한 권한 설정"),
        DangerousPattern(regex: #"curl\s+.*\|\s*(sudo\s+)?(ba)?sh"#, severity: .critical, description: "원격 스크립트 실행"),
        DangerousPattern(regex: #"wget\s+.*\|\s*(sudo\s+)?(ba)?sh"#, severity: .critical, description: "원격 스크립트 실행"),
        DangerousPattern(regex: #"mkfs\."#, severity: .critical, description: "파일시스템 포맷"),
        DangerousPattern(regex: #"dd\s+if="#, severity: .high, description: "디스크 직접 쓰기"),
        DangerousPattern(regex: #">\s*/dev/sd"#, severity: .critical, description: "디바이스 직접 쓰기"),
        DangerousPattern(regex: #":\(\)\{.*\|.*&\s*\}\s*;"#, severity: .critical, description: "포크 폭탄"),
        DangerousPattern(regex: #"sudo\s+rm\s+"#, severity: .high, description: "sudo 삭제"),
        DangerousPattern(regex: #"npm\s+publish"#, severity: .medium, description: "패키지 퍼블리시"),
        DangerousPattern(regex: #"docker\s+system\s+prune\s+-a"#, severity: .medium, description: "Docker 전체 정리"),
        DangerousPattern(regex: #"kubectl\s+delete\s+(namespace|ns|deployment|pod)"#, severity: .high, description: "Kubernetes 리소스 삭제"),
    ]

    private var cachedRegexes: [(pattern: DangerousPattern, regex: NSRegularExpression)] = []
    private var cacheSignature: Int = 0

    private init() {
        self.enabled = PersistenceService.shared.object(forKey: "dangerousCommandDetectionEnabled") as? Bool ?? true
        if let data = PersistenceService.shared.data(forKey: "customDangerousPatterns"),
           let patterns = try? JSONDecoder().decode([String].self, from: data) {
            self.customPatterns = patterns
        } else {
            self.customPatterns = []
        }
    }

    public func check(command: String) -> DangerousCommandMatch? {
        guard enabled else { return nil }
        rebuildCacheIfNeeded()
        for (pattern, regex) in cachedRegexes {
            if let match = regex.firstMatch(in: command, range: NSRange(command.startIndex..., in: command)) {
                let matched = (command as NSString).substring(with: match.range)
                return DangerousCommandMatch(pattern: pattern, matchedText: matched)
            }
        }
        return nil
    }

    private func rebuildCacheIfNeeded() {
        var hasher = Hasher()
        hasher.combine(customPatterns)
        let sig = hasher.finalize()
        guard sig != cacheSignature else { return }
        cacheSignature = sig
        let allPatterns = Self.builtInPatterns + customPatterns.map {
            DangerousPattern(regex: $0, severity: .medium, description: "사용자 정의 패턴")
        }
        cachedRegexes = allPatterns.compactMap { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive]) else { return nil }
            return (pattern, regex)
        }
    }
}
