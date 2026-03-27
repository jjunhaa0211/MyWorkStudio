import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSKeyboardShortcut (Keyboard Shortcut Badge)
// ═══════════════════════════════════════════════════════

public struct DSKeyboardShortcut: View {
    public let keys: [String]
    public var compact: Bool = false

    public init(_ shortcut: String, compact: Bool = false) {
        self.keys = shortcut.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        self.compact = compact
    }

    public init(keys: [String], compact: Bool = false) {
        self.keys = keys
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(symbolize(key))
                    .font(.system(size: compact ? 9 : 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal, compact ? 4 : 5)
                    .padding(.vertical, compact ? 1 : 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.bgSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.border, lineWidth: 1)
                            .allowsHitTesting(false)
                    )
            }
        }
        .accessibilityLabel(Text(keys.joined(separator: " ")))
    }

    private func symbolize(_ key: String) -> String {
        switch key.lowercased() {
        case "cmd", "command": return "⌘"
        case "shift": return "⇧"
        case "opt", "option", "alt": return "⌥"
        case "ctrl", "control": return "⌃"
        case "enter", "return": return "↩"
        case "tab": return "⇥"
        case "delete", "backspace": return "⌫"
        case "esc", "escape": return "⎋"
        case "space": return "␣"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return key.uppercased()
        }
    }
}
