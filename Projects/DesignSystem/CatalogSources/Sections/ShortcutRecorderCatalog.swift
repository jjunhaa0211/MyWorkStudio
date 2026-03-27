import SwiftUI
import DesignSystem

struct ShortcutRecorderCatalog: View {
    @State private var shortcut1 = "Cmd+S"
    @State private var shortcut2 = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Shortcut Recorder")

            catalogSection("DSShortcutRecorder — With Value") {
                DSShortcutRecorder(shortcut: $shortcut1)
                    .frame(maxWidth: 300)
                Text("Current: \(shortcut1.isEmpty ? "None" : shortcut1)")
                    .font(Theme.code(10)).foregroundColor(Theme.textDim)
            }

            catalogSection("DSShortcutRecorder — Empty") {
                DSShortcutRecorder(shortcut: $shortcut2, placeholder: "Press keys to record...")
                    .frame(maxWidth: 300)
            }
        }
    }
}
