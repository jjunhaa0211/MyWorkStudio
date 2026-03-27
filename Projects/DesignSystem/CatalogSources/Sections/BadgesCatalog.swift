import SwiftUI
import DesignSystem

struct BadgesCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Badges & Tags")

            catalogSection("AppStatusBadge") {
                HStack(spacing: 12) {
                    AppStatusBadge(title: "Active", symbol: "circle.fill", tint: Theme.green)
                    AppStatusBadge(title: "Warning", symbol: "exclamationmark.triangle.fill", tint: Theme.yellow)
                    AppStatusBadge(title: "Error", symbol: "xmark.circle.fill", tint: Theme.red)
                    AppStatusBadge(title: "Info", symbol: "info.circle.fill", tint: Theme.accent)
                }
                HStack(spacing: 12) {
                    AppStatusBadge(title: "Processing", symbol: "arrow.clockwise", tint: Theme.purple, compact: false)
                    AppStatusBadge(title: "Complete", symbol: "checkmark.circle.fill", tint: Theme.green, compact: false)
                }
            }

            catalogSection("AppStatusDot") {
                HStack(spacing: 16) {
                    dotSample("Default (6pt)", Theme.green, 6)
                    dotSample("Small (4pt)", Theme.yellow, 4)
                    dotSample("Large (8pt)", Theme.red, 8)
                    dotSample("XL (10pt)", Theme.accent, 10)
                }
            }

            catalogSection("AppInlineCode") {
                HStack(spacing: 12) {
                    AppInlineCode(text: "git commit -m")
                    AppInlineCode(text: "CMD+T")
                    AppInlineCode(text: "v0.0.27")
                }
            }
        }
    }

    private func dotSample(_ label: String, _ color: Color, _ size: CGFloat) -> some View {
        HStack(spacing: 8) {
            AppStatusDot(color: color, size: size)
            Text(label)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
