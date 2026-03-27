import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Color Tokens
// ═══════════════════════════════════════════════════════
//
// 도피스 디자인 시스템 컬러 토큰 (Vercel Geist 재해석)
//
// 철학:
// - 순수 블랙/그레이스케일 surface 계층
// - 색상은 상태 표시에만 절제하여 사용
// - 4-layer background depth system
// - 5-step text hierarchy

public enum ColorTokens {
    // ── Background Surfaces (4-layer depth system) ──

    /// Layer 0: App background (deepest)
    public static func bg(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.bgHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "000000") : Color(hex: "fafafa")
    }

    /// Layer 1: Card / elevated panel
    public static func bgCard(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.bgCardHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff")
    }

    /// Layer 2: Raised surface / nested element
    public static func bgSurface(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.bgSurfaceHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "111111") : Color(hex: "f5f5f5")
    }

    /// Layer 3: Tertiary surface (badges, code blocks)
    public static func bgTertiary(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.bgTertiaryHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb")
    }

    // ── Functional backgrounds ──

    public static func bgTerminal(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.bgHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "0a0a0a") : Color(hex: "fafafa")
    }

    public static func bgInput(dark: Bool) -> Color { dark ? Color(hex: "000000") : Color(hex: "ffffff") }
    public static func bgHover(dark: Bool) -> Color { dark ? Color(hex: "1a1a1a") : Color(hex: "f0f0f0") }
    public static func bgSelected(dark: Bool) -> Color { dark ? Color(hex: "1a1a1a") : Color(hex: "eaeaea") }
    public static func bgPressed(dark: Bool) -> Color { dark ? Color(hex: "222222") : Color(hex: "e5e5e5") }
    public static func bgDisabled(dark: Bool) -> Color { dark ? Color(hex: "0a0a0a") : Color(hex: "f5f5f5") }
    public static func bgOverlay(dark: Bool) -> Color { dark ? Color(hex: "000000").opacity(0.7) : Color(hex: "000000").opacity(0.4) }

    // ── Borders (single-weight system: always 1px, vary opacity) ──

    public static func border(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.borderHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "282828") : Color(hex: "e5e5e5")
    }

    public static func borderStrong(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.borderStrongHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0")
    }

    public static func borderActive(dark: Bool) -> Color { dark ? Color(hex: "555555") : Color(hex: "999999") }
    public static func borderSubtle(dark: Bool) -> Color { dark ? Color(hex: "1e1e1e") : Color(hex: "eeeeee") }
    public static let focusRing = Color(hex: "0070f3").opacity(0.5)

    // ── Text (5-step hierarchy) ──

    public static func textPrimary(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.textPrimaryHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "ededed") : Color(hex: "171717")
    }

    public static func textSecondary(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.textSecondaryHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "a1a1a1") : Color(hex: "636363")
    }

    public static func textDim(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.textDimHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "707070") : Color(hex: "8f8f8f")
    }

    public static func textMuted(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.textMutedHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "484848") : Color(hex: "b0b0b0")
    }

    public static func textTerminal(dark: Bool) -> Color { dark ? Color(hex: "ededed") : Color(hex: "171717") }

    // ── System ──

    public static func textOnAccent(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if custom?.accentHex != nil {
            return accent(dark: dark, custom: custom).contrastingTextColor
        }
        return .white
    }

    public static func overlay(dark: Bool) -> Color { dark ? .white : .black }
    public static func overlayBg(dark: Bool) -> Color { dark ? .black : .white }

    // ── Semantic Accents ──

    public static func accent(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.accentHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "3291ff") : Color(hex: "0070f3")
    }

    public static func green(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.greenHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "3ecf8e") : Color(hex: "18a058")
    }

    public static func red(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.redHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "f14c4c") : Color(hex: "e5484d")
    }

    public static func yellow(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.yellowHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "f5a623") : Color(hex: "ca8a04")
    }

    public static func purple(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.purpleHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf")
    }

    public static func orange(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.orangeHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "f97316") : Color(hex: "e5560a")
    }

    public static func cyan(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.cyanHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "06b6d4") : Color(hex: "0891b2")
    }

    public static func pink(dark: Bool, custom: CustomThemeConfig? = nil) -> Color {
        if let hex = custom?.pinkHex, !hex.isEmpty { return Color(hex: hex) }
        return dark ? Color(hex: "e54d9e") : Color(hex: "d23197")
    }

    // ── Accent helpers ──

    public static func accentBg(_ color: Color, dark: Bool) -> Color { color.opacity(dark ? 0.12 : 0.08) }
    public static func accentBorder(_ color: Color, dark: Bool) -> Color { color.opacity(dark ? 0.25 : 0.2) }

    // ── WCAG Contrast Helpers ──

    /// Check if two colors meet WCAG AA contrast ratio (4.5:1 for normal text)
    public static func meetsContrastAA(foreground: Color, background: Color) -> Bool {
        contrastRatio(foreground, background) >= 4.5
    }

    /// Check if two colors meet WCAG AAA contrast ratio (7:1)
    public static func meetsContrastAAA(foreground: Color, background: Color) -> Bool {
        contrastRatio(foreground, background) >= 7.0
    }

    /// Calculate WCAG contrast ratio between two colors
    public static func contrastRatio(_ c1: Color, _ c2: Color) -> Double {
        let l1 = c1.luminance
        let l2 = c2.luminance
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // ── Worker Colors (pixel world) ──

    public static func workerColors(dark: Bool) -> [Color] {
        dark ? [
            Color(hex: "ee7878"), Color(hex: "68d498"), Color(hex: "eebb50"),
            Color(hex: "70b0ee"), Color(hex: "c08ce6"), Color(hex: "ee9858"),
            Color(hex: "58ccbb"), Color(hex: "ee78bb")
        ] : [
            Color(hex: "d04848"), Color(hex: "259248"), Color(hex: "b88000"),
            Color(hex: "2260d0"), Color(hex: "6a40d0"), Color(hex: "c86020"),
            Color(hex: "0a8888"), Color(hex: "c84080")
        ]
    }
}
