import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Typography System
// ═══════════════════════════════════════════════════════
//
// UI text: system sans-serif (.default)
// Code/terminal/git hash: monospaced (.monospaced)
// Pixel world labels: monospaced bold (preserved)
//
// Scale hierarchy:
//   display: 18   title: 14   heading: 12   body: 11
//   small: 10     micro: 9    tiny: 8

public enum Typography {
    // ── Font Cache ──
    private static var _fontCache: [String: Font] = [:]

    private static let maxCacheSize = 64

    private static func cachedFont(key: String, create: () -> Font) -> Font {
        if let cached = _fontCache[key] { return cached }
        if _fontCache.count >= maxCacheSize {
            // Simple eviction: clear half when full
            let keysToRemove = Array(_fontCache.keys.prefix(_fontCache.count / 2))
            for k in keysToRemove { _fontCache.removeValue(forKey: k) }
        }
        let font = create()
        _fontCache[key] = font
        return font
    }

    /// Clear font cache (call when font settings change)
    public static func invalidateCache() {
        _fontCache.removeAll()
    }

    // ── Convenience Fonts ──

    public static func monoTiny(scale: CGFloat) -> Font { .system(size: round(8 * scale), design: .monospaced) }
    public static func monoSmall(scale: CGFloat) -> Font { .system(size: round(10 * scale), design: .monospaced) }
    public static func monoNormal(scale: CGFloat) -> Font { .system(size: round(12 * scale), design: .monospaced) }
    public static func monoBold(scale: CGFloat) -> Font { .system(size: round(11 * scale), weight: .semibold, design: .monospaced) }
    public static func pixel(chromeScale: CGFloat) -> Font { .system(size: round(8 * chromeScale), weight: .bold, design: .monospaced) }

    /// Primary UI text (Geist Sans equivalent)
    public static func mono(_ baseSize: CGFloat, weight: Font.Weight = .regular, scale: CGFloat, customFont: String? = nil) -> Font {
        let key = "mono-\(baseSize)-\(weight.hashValue)-\(scale)"
        return cachedFont(key: key) {
            if let fontName = customFont, !fontName.isEmpty {
                return Font.custom(fontName, size: round(baseSize * scale)).weight(weight)
            }
            return .system(size: round(baseSize * scale), weight: weight, design: .default)
        }
    }

    /// Code, terminal, git hashes — always monospaced
    public static func code(_ baseSize: CGFloat, weight: Font.Weight = .regular, scale: CGFloat) -> Font {
        let key = "code-\(baseSize)-\(weight.hashValue)-\(scale)"
        return cachedFont(key: key) {
            .system(size: round(baseSize * scale), weight: weight, design: .monospaced)
        }
    }

    /// General scaled font
    public static func scaled(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, scale: CGFloat, customFont: String? = nil) -> Font {
        let key = "scaled-\(baseSize)-\(weight.hashValue)-\(design.hashValue)-\(scale)"
        return cachedFont(key: key) {
            if let fontName = customFont, !fontName.isEmpty, design == .default {
                return Font.custom(fontName, size: round(baseSize * scale)).weight(weight)
            }
            return .system(size: round(baseSize * scale), weight: weight, design: design)
        }
    }

    /// Chrome-only font (sidebar, toolbar — less aggressive scaling)
    public static func chrome(_ baseSize: CGFloat, weight: Font.Weight = .regular, chromeScale: CGFloat, customFont: String? = nil) -> Font {
        let key = "chrome-\(baseSize)-\(weight.hashValue)-\(chromeScale)"
        return cachedFont(key: key) {
            if let fontName = customFont, !fontName.isEmpty {
                return Font.custom(fontName, size: round(baseSize * chromeScale)).weight(weight)
            }
            return .system(size: round(baseSize * chromeScale), weight: weight, design: .default)
        }
    }
}
