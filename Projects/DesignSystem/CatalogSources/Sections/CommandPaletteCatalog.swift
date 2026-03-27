import SwiftUI
import DesignSystem

struct CommandPaletteCatalog: View {
    @State private var showPalette = false
    @State private var lastAction = ""

    private var sampleItems: [DSCommandItem] {
        [
            DSCommandItem(title: "New Session", subtitle: "Start a new Claude session", icon: "plus.circle.fill", tint: Theme.green) { lastAction = "New Session" },
            DSCommandItem(title: "Settings", subtitle: "Open preferences", icon: "gearshape.fill", tint: Theme.accent) { lastAction = "Settings" },
            DSCommandItem(title: "Toggle Dark Mode", subtitle: "Switch theme", icon: "moon.fill", tint: Theme.purple) { lastAction = "Dark Mode" },
            DSCommandItem(title: "Export Log", subtitle: "Save session log to file", icon: "square.and.arrow.up", tint: Theme.orange) { lastAction = "Export" },
            DSCommandItem(title: "Git Push", subtitle: "Push changes to remote", icon: "arrow.up.circle.fill", tint: Theme.cyan) { lastAction = "Git Push" },
            DSCommandItem(title: "Clear Terminal", subtitle: "Clear output buffer", icon: "trash", tint: Theme.red) { lastAction = "Clear" },
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Command Palette")

            catalogSection("DSCommandPalette — Click to open") {
                VStack(alignment: .leading, spacing: 12) {
                    DSButton("Open Palette", icon: "command", tone: .accent, prominent: true) { showPalette = true }
                    if !lastAction.isEmpty {
                        Text("Last action: \(lastAction)")
                            .font(Theme.code(10)).foregroundColor(Theme.green)
                    }
                }
            }
        }
        .overlay {
            if showPalette {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showPalette = false }

                    DSCommandPalette(isPresented: $showPalette, items: sampleItems)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showPalette)
    }
}
