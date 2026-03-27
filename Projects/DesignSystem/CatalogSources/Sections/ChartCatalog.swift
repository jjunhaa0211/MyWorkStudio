import SwiftUI
import DesignSystem

struct ChartCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Charts")

            catalogSection("DSBarChart — Token Usage") {
                DSBarChart([
                    .init("Mon", value: 12500, tint: Theme.accent),
                    .init("Tue", value: 28000, tint: Theme.accent),
                    .init("Wed", value: 45000, tint: Theme.green),
                    .init("Thu", value: 32000, tint: Theme.accent),
                    .init("Fri", value: 18000, tint: Theme.accent),
                    .init("Sat", value: 8000, tint: Theme.textDim),
                    .init("Sun", value: 5000, tint: Theme.textDim),
                ], height: 140)
                .frame(maxWidth: 450)
            }

            catalogSection("DSMiniSparkline") {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tokens").font(Theme.code(8)).foregroundColor(Theme.textDim)
                        DSMiniSparkline([10, 15, 12, 25, 20, 35, 28, 42, 38, 50], tint: Theme.accent, height: 32)
                            .frame(width: 120)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sessions").font(Theme.code(8)).foregroundColor(Theme.textDim)
                        DSMiniSparkline([5, 3, 8, 2, 6, 4, 9, 7, 3, 5], tint: Theme.green, height: 32)
                            .frame(width: 120)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Errors").font(Theme.code(8)).foregroundColor(Theme.textDim)
                        DSMiniSparkline([1, 0, 2, 0, 0, 3, 1, 0, 0, 1], tint: Theme.red, height: 32)
                            .frame(width: 120)
                    }
                }
            }
        }
    }
}
