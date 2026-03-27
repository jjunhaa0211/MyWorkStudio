import SwiftUI
import DesignSystem

struct TooltipCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Tooltips")

            catalogSection("dsTooltip() — Edges") {
                HStack(spacing: 40) {
                    DSIconButton("arrow.up.circle.fill", size: 14, tint: Theme.accent) {}
                        .dsTooltip("Top tooltip", edge: .top)
                    DSIconButton("arrow.down.circle.fill", size: 14, tint: Theme.green) {}
                        .dsTooltip("Bottom tooltip", edge: .bottom)
                    DSIconButton("arrow.left.circle.fill", size: 14, tint: Theme.orange) {}
                        .dsTooltip("Leading tooltip", edge: .leading)
                    DSIconButton("arrow.right.circle.fill", size: 14, tint: Theme.purple) {}
                        .dsTooltip("Trailing tooltip", edge: .trailing)
                }
                .padding(.vertical, 40)
            }

            catalogSection("dsTooltip() — On Buttons") {
                HStack(spacing: 12) {
                    DSButton("Save", icon: "square.and.arrow.down", tone: .accent, compact: true) {}
                        .dsTooltip("Save current changes (\u{2318}S)")
                    DSButton("Delete", icon: "trash", tone: .red, compact: true) {}
                        .dsTooltip("Delete selected items")
                }
            }
        }
    }
}
