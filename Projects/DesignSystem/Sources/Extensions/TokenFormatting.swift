import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - Token Formatting
// ═══════════════════════════════════════════════════════

public extension Int {
    /// Compact token count display: "500", "1.5k", "2.0M"
    var tokenFormatted: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1000 { return String(format: "%.1fk", Double(self) / 1000) }
        return "\(self)"
    }
}
