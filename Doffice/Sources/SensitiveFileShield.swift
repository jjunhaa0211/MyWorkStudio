import Foundation

struct SensitiveFileMatch {
    let filePath: String
    let action: String  // Read, Write, Edit
    let patternMatched: String
}

class SensitiveFileShield: ObservableObject {
    static let shared = SensitiveFileShield()

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "sensitiveFileShieldEnabled") }
    }
    @Published var patterns: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(patterns) {
                UserDefaults.standard.set(data, forKey: "sensitiveFilePatterns")
            }
        }
    }
    @Published var whitelist: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(whitelist) {
                UserDefaults.standard.set(data, forKey: "sensitiveFileWhitelist")
            }
        }
    }

    static let defaultPatterns: [String] = [
        ".env", ".env.*", ".env.local", ".env.production",
        "credentials.json", "serviceAccountKey.json",
        "id_rsa", "id_ed25519", "id_dsa",
        "*.pem", "*.key", "*.p12", "*.pfx", "*.jks", "*.keystore",
        "secrets.*", "secret.yaml", "secret.yml",
        ".aws/credentials", ".aws/config",
        ".ssh/*", ".netrc", ".npmrc",
        "*.cert", "*.crt",
        "token.json", "oauth_token*",
        ".git-credentials",
    ]

    private var cachedPatternRegexes: [(pattern: String, regex: NSRegularExpression)] = []
    private var cachedWhitelistRegexes: [(pattern: String, regex: NSRegularExpression)] = []
    private var patternCacheSignature: Int = 0
    private var whitelistCacheSignature: Int = 0

    private init() {
        self.enabled = UserDefaults.standard.object(forKey: "sensitiveFileShieldEnabled") as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: "sensitiveFilePatterns"),
           let p = try? JSONDecoder().decode([String].self, from: data) {
            self.patterns = p
        } else {
            self.patterns = Self.defaultPatterns
        }
        if let data = UserDefaults.standard.data(forKey: "sensitiveFileWhitelist"),
           let w = try? JSONDecoder().decode([String].self, from: data) {
            self.whitelist = w
        } else {
            self.whitelist = []
        }
    }

    func check(filePath: String, action: String) -> SensitiveFileMatch? {
        guard enabled else { return nil }
        let filename = (filePath as NSString).lastPathComponent
        let normalizedPath = filePath.replacingOccurrences(of: NSHomeDirectory(), with: "~")

        rebuildCachesIfNeeded()

        // Check whitelist first
        for (_, regex) in cachedWhitelistRegexes {
            if regex.firstMatch(in: filePath, range: NSRange(filePath.startIndex..., in: filePath)) != nil { return nil }
            if regex.firstMatch(in: normalizedPath, range: NSRange(normalizedPath.startIndex..., in: normalizedPath)) != nil { return nil }
        }

        // Check patterns
        for (pattern, regex) in cachedPatternRegexes {
            if regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) != nil ||
               regex.firstMatch(in: normalizedPath, range: NSRange(normalizedPath.startIndex..., in: normalizedPath)) != nil {
                return SensitiveFileMatch(filePath: filePath, action: action, patternMatched: pattern)
            }
        }
        return nil
    }

    private func rebuildCachesIfNeeded() {
        var pH = Hasher(); pH.combine(patterns); let pSig = pH.finalize()
        if pSig != patternCacheSignature {
            patternCacheSignature = pSig
            cachedPatternRegexes = patterns.compactMap { p in
                guard let regex = globToRegex(p) else { return nil }
                return (p, regex)
            }
        }
        var wH = Hasher(); wH.combine(whitelist); let wSig = wH.finalize()
        if wSig != whitelistCacheSignature {
            whitelistCacheSignature = wSig
            cachedWhitelistRegexes = whitelist.compactMap { p in
                guard let regex = globToRegex(p) else { return nil }
                return (p, regex)
            }
        }
    }

    private func globToRegex(_ pattern: String) -> NSRegularExpression? {
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".") + "$"
        return try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive])
    }
}
