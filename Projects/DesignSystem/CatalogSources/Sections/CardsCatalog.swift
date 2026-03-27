import SwiftUI
import DesignSystem

struct CardsCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Cards & Metrics")

            catalogSection("DSStatCard") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DSStatCard(title: "Total Sessions", value: "42", icon: "terminal.fill", tint: Theme.accent)
                    DSStatCard(title: "Tokens Used", value: "1.2M", subtitle: "This month", icon: "circle.hexagongrid.fill", tint: Theme.green)
                    DSStatCard(title: "Active Workers", value: "8", icon: "person.3.fill", tint: Theme.purple)
                }
            }
        }
    }
}
