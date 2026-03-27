import SwiftUI
import DesignSystem

struct SegmentedCatalog: View {
    @State private var selected1 = "Daily"
    @State private var selected2 = "All"

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Segmented Control")

            catalogSection("DSSegmentedControl — Basic") {
                DSSegmentedControl(["Daily", "Weekly", "Monthly"], selected: $selected1)
                    .frame(maxWidth: 350)
                Text("Selected: \(selected1)")
                    .font(Theme.code(10)).foregroundColor(Theme.textDim)
            }

            catalogSection("DSSegmentedControl — Filter") {
                DSSegmentedControl(["All", "Active", "Idle", "Error"], selected: $selected2, tint: Theme.green)
                    .frame(maxWidth: 400)
            }
        }
    }
}
