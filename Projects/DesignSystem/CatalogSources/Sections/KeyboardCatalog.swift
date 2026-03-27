import SwiftUI
import DesignSystem

struct KeyboardCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Keyboard Shortcuts")

            catalogSection("DSKeyboardShortcut — Common") {
                VStack(alignment: .leading, spacing: 12) {
                    shortcutRow("New Session", "Cmd+T")
                    shortcutRow("Command Palette", "Cmd+K")
                    shortcutRow("Close Tab", "Cmd+W")
                    shortcutRow("Settings", "Cmd+,")
                    shortcutRow("Save", "Cmd+S")
                    shortcutRow("Undo", "Cmd+Z")
                    shortcutRow("Find", "Cmd+F")
                }
            }

            catalogSection("DSKeyboardShortcut — Modifiers") {
                VStack(alignment: .leading, spacing: 12) {
                    shortcutRow("Force Quit", "Cmd+Opt+Esc")
                    shortcutRow("Screenshot", "Cmd+Shift+4")
                    shortcutRow("Developer Tools", "Cmd+Opt+I")
                }
            }

            catalogSection("Special Keys") {
                HStack(spacing: 16) {
                    DSKeyboardShortcut("Enter")
                    DSKeyboardShortcut("Tab")
                    DSKeyboardShortcut("Esc")
                    DSKeyboardShortcut("Space")
                    DSKeyboardShortcut("Delete")
                }
            }

            catalogSection("Compact Variant") {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        DSKeyboardShortcut("Cmd+T", compact: true)
                        Text("— compact")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                    HStack(spacing: 4) {
                        DSKeyboardShortcut("Cmd+T")
                        Text("— default")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                }
            }
        }
    }

    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            DSKeyboardShortcut(shortcut)
        }
        .frame(maxWidth: 350)
    }
}
