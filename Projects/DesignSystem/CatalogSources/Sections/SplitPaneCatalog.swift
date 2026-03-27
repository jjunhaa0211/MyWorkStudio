import SwiftUI
import DesignSystem

struct SplitPaneCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Split Pane")

            catalogSection("DSSplitPane — Draggable") {
                DSSplitPane(minLeading: 120, minTrailing: 120, initialRatio: 0.4) {
                    VStack {
                        Text("Leading Panel").font(Theme.mono(11, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        Text("Drag the divider →").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bgCard)
                } trailing: {
                    VStack {
                        Text("Trailing Panel").font(Theme.mono(11, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        Text("← Drag the divider").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bgSurface)
                }
                .frame(height: 200)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
