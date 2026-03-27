import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSSyntaxTokens (Code Syntax Color Palette)
// ═══════════════════════════════════════════════════════

public enum DSSyntax {
    private static var dark: Bool { AppSettings.shared.isDarkMode }

    // ── Keywords & Control Flow ──
    public static var keyword: Color { dark ? Color(hex: "ff7b72") : Color(hex: "cf222e") }
    public static var control: Color { dark ? Color(hex: "ff7b72") : Color(hex: "cf222e") }

    // ── Types & Declarations ──
    public static var type: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }
    public static var declaration: Color { dark ? Color(hex: "d2a8ff") : Color(hex: "8250df") }

    // ── Strings & Literals ──
    public static var string: Color { dark ? Color(hex: "a5d6ff") : Color(hex: "0a3069") }
    public static var number: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }
    public static var boolean: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }

    // ── Functions & Methods ──
    public static var function: Color { dark ? Color(hex: "d2a8ff") : Color(hex: "8250df") }
    public static var method: Color { dark ? Color(hex: "d2a8ff") : Color(hex: "8250df") }
    public static var parameter: Color { dark ? Color(hex: "ffa657") : Color(hex: "953800") }

    // ── Comments & Documentation ──
    public static var comment: Color { dark ? Color(hex: "8b949e") : Color(hex: "6e7781") }
    public static var docComment: Color { dark ? Color(hex: "8b949e") : Color(hex: "6e7781") }

    // ── Operators & Punctuation ──
    public static var `operator`: Color { dark ? Color(hex: "ff7b72") : Color(hex: "cf222e") }
    public static var punctuation: Color { dark ? Color(hex: "c9d1d9") : Color(hex: "24292f") }

    // ── Properties & Variables ──
    public static var property: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }
    public static var variable: Color { dark ? Color(hex: "ffa657") : Color(hex: "953800") }
    public static var constant: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }

    // ── Special ──
    public static var regex: Color { dark ? Color(hex: "7ee787") : Color(hex: "116329") }
    public static var escape: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }
    public static var annotation: Color { dark ? Color(hex: "d2a8ff") : Color(hex: "8250df") }

    // ── Diff ──
    public static var diffAdded: Color { dark ? Color(hex: "3ecf8e").opacity(0.15) : Color(hex: "18a058").opacity(0.1) }
    public static var diffRemoved: Color { dark ? Color(hex: "f14c4c").opacity(0.15) : Color(hex: "e5484d").opacity(0.1) }
    public static var diffAddedText: Color { dark ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
    public static var diffRemovedText: Color { dark ? Color(hex: "f14c4c") : Color(hex: "e5484d") }

    // ── Terminal / ANSI ──
    public static var termBlack: Color { dark ? Color(hex: "484f58") : Color(hex: "24292f") }
    public static var termRed: Color { dark ? Color(hex: "ff7b72") : Color(hex: "cf222e") }
    public static var termGreen: Color { dark ? Color(hex: "7ee787") : Color(hex: "116329") }
    public static var termYellow: Color { dark ? Color(hex: "e3b341") : Color(hex: "4d2d00") }
    public static var termBlue: Color { dark ? Color(hex: "79c0ff") : Color(hex: "0550ae") }
    public static var termMagenta: Color { dark ? Color(hex: "d2a8ff") : Color(hex: "8250df") }
    public static var termCyan: Color { dark ? Color(hex: "56d4dd") : Color(hex: "1b7c83") }
    public static var termWhite: Color { dark ? Color(hex: "f0f6fc") : Color(hex: "6e7781") }
}
