import SwiftUI
import DesignSystem

struct ToggleCatalog: View {
    @State private var t1 = true
    @State private var t2 = false
    @State private var t3 = true
    @State private var c1 = true
    @State private var c2 = false
    @State private var c3 = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Toggles & Switches")

            catalogSection("DSToggle — Standard") {
                VStack(alignment: .leading, spacing: 12) {
                    DSToggle("Dark Mode", icon: "moon.fill", description: "Enable dark color scheme", isOn: $t1, tint: Theme.accent)
                    DSToggle("Notifications", icon: "bell.fill", isOn: $t2, tint: Theme.green)
                    DSToggle("Performance Mode", icon: "bolt.fill", description: "Reduce animations and effects", isOn: $t3, tint: Theme.orange)
                }
                .frame(maxWidth: 350)
            }

            catalogSection("DSToggleChip — Compact") {
                HStack(spacing: 12) {
                    DSToggleChip("Auto-save", isOn: $c1, tint: Theme.green)
                    DSToggleChip("Line numbers", isOn: $c2, tint: Theme.accent)
                    DSToggleChip("Word wrap", isOn: $c3, tint: Theme.purple)
                }
            }
        }
    }
}
