import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Color hex init
// ═══════════════════════════════════════════════════════

public extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        // Expand 3-character shorthand (e.g. "fff" -> "ffffff")
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else {
            self.init(.sRGB, red: 0, green: 0, blue: 0)
            return
        }
        let r = int >> 16
        let g = int >> 8 & 0xFF
        let b = int & 0xFF
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// Color → 6자리 hex 문자열 (# 없음)
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// W3C 상대 휘도 (0 = 검정, 1 = 흰색)
    var luminance: Double {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linearize(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// 배경색 위 텍스트 가독성을 위한 자동 대비 색상
    var contrastingTextColor: Color {
        luminance > 0.179 ? .black : .white
    }

    /// Validate if a string is a valid hex color
    static func isValidHex(_ hex: String) -> Bool {
        var cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 3 { cleaned = cleaned.map { "\($0)\($0)" }.joined() }
        var int: UInt64 = 0
        return Scanner(string: cleaned).scanHexInt64(&int) && cleaned.count == 6
    }
}
