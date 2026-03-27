import SwiftUI
import DesignSystem

struct BadgeCountCatalog: View {
    @State private var count = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Notification Badges")

            catalogSection("dsBadge() — Dot") {
                HStack(spacing: 24) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.textSecondary)
                        .dsBadge()
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.textSecondary)
                        .dsBadge(tint: Theme.accent)
                    Image(systemName: "gear")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.textSecondary)
                        .dsBadge(tint: Theme.yellow)
                }
            }

            catalogSection("dsBadge(count:) — Counter") {
                HStack(spacing: 24) {
                    DSButton("Messages", icon: "envelope.fill", tone: .neutral) {}
                        .dsBadge(count: count)
                    DSButton("Alerts", icon: "exclamationmark.triangle", tone: .neutral) {}
                        .dsBadge(count: 42, tint: Theme.orange)
                    DSButton("Updates", icon: "arrow.clockwise", tone: .neutral) {}
                        .dsBadge(count: 128, tint: Theme.green)
                }
            }

            catalogSection("Interactive Counter") {
                HStack(spacing: 8) {
                    DSButton("-", tone: .red, compact: true) { if count > 0 { count -= 1 } }
                    Text("\(count)").font(Theme.mono(12, weight: .bold)).foregroundColor(Theme.textPrimary).frame(width: 30)
                    DSButton("+", tone: .green, compact: true) { count += 1 }

                    Spacer().frame(width: 20)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textSecondary)
                        .dsBadge(count: count)
                }
            }
        }
    }
}
