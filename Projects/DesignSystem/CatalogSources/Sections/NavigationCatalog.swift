import SwiftUI
import DesignSystem

struct NavigationCatalog: View {
    @State private var tabIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Navigation")

            catalogSection("DSTabBar") {
                VStack(spacing: 16) {
                    DSTabBar(tabs: [
                        ("terminal.fill", "Terminal"),
                        ("arrow.triangle.branch", "Git"),
                        ("globe", "Browser")
                    ], selectedIndex: $tabIndex)
                }
            }

            catalogSection("DSFilterChip") {
                HStack(spacing: 8) {
                    DSFilterChip(label: "All", isSelected: true, count: 12) {}
                    DSFilterChip(label: "Active", isSelected: false, count: 5) {}
                    DSFilterChip(label: "Idle", isSelected: false, count: 7) {}
                    DSFilterChip(label: "Error", isSelected: false, count: 0) {}
                }
            }

            catalogSection("sidebarRowStyle()") {
                VStack(spacing: 2) {
                    sidebarRow("Dashboard", "square.grid.2x2.fill", false, false)
                    sidebarRow("Sessions", "terminal.fill", true, false)
                    sidebarRow("Settings", "gearshape.fill", false, true)
                    sidebarRow("Help", "questionmark.circle", false, false)
                }
                .frame(maxWidth: 250)
            }
        }
    }

    private func sidebarRow(_ title: String, _ icon: String, _ selected: Bool, _ hovered: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(selected ? Theme.accent : Theme.textDim)
            Text(title)
                .font(Theme.mono(11, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
            Spacer()
        }
        .sidebarRowStyle(isSelected: selected, isHovered: hovered)
    }
}
