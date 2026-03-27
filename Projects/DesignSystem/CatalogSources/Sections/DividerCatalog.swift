import SwiftUI
import DesignSystem

struct DividerCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Dividers")

            catalogSection("DSDivider — Horizontal") {
                VStack(spacing: 16) {
                    DSDivider()
                    DSDivider("OR")
                    DSDivider("Section Break")
                    DSDivider("2024-03-27", color: Theme.accent)
                }
                .frame(maxWidth: 400)
            }

            catalogSection("DSVerticalDivider") {
                HStack(spacing: 16) {
                    Text("Left").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                    DSVerticalDivider(height: 20)
                    Text("Center").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                    DSVerticalDivider(height: 20)
                    Text("Right").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
