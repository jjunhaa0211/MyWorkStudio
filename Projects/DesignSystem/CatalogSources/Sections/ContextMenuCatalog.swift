import SwiftUI
import DesignSystem

struct ContextMenuCatalog: View {
    @State private var lastAction = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Context Menu")

            catalogSection("dsContextMenu() — Right-click the card") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project: my-app").font(Theme.mono(11, weight: .semibold)).foregroundColor(Theme.textPrimary)
                    Text("Right-click for options").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    if !lastAction.isEmpty {
                        Text("Action: \(lastAction)").font(Theme.code(9)).foregroundColor(Theme.green)
                    }
                }
                .frame(maxWidth: 300, alignment: .leading)
                .appPanelStyle()
                .dsContextMenu([
                    DSMenuItem("Open in Terminal", icon: "terminal.fill") { lastAction = "Open Terminal" },
                    DSMenuItem("Copy Path", icon: "doc.on.doc") { lastAction = "Copy Path" },
                    DSMenuItem("Reveal in Finder", icon: "folder.fill") { lastAction = "Reveal" },
                    DSMenuItem("Delete", icon: "trash", isDestructive: true) { lastAction = "Delete" },
                ])
            }
        }
    }
}
