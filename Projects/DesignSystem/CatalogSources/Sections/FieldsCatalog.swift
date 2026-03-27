import SwiftUI
import DesignSystem

struct FieldsCatalog: View {
    @State private var text1 = ""
    @State private var text2 = "Hello, 도피스!"
    @State private var text3 = ""
    @State private var isToggled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Form Fields & Surfaces")

            catalogSection("appFieldStyle() — Text Fields") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default").font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField("Placeholder text...", text: $text1)
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .appFieldStyle()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Emphasized (focused)").font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField("Emphasized field", text: $text2)
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .appFieldStyle(emphasized: true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disabled").font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField("Cannot edit", text: $text3)
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .appFieldStyle()
                            .disabled(true)
                            .opacity(0.4)
                    }
                }
                .frame(maxWidth: 400)
            }

            catalogSection("appPanelStyle() — Surfaces") {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Panel")
                            .font(Theme.mono(11, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text("Background: bgCard, border: Theme.border")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appPanelStyle()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surface Panel")
                            .font(Theme.mono(11, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text("Background: bgSurface")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appPanelStyle(fill: Theme.bgSurface)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compact Panel (8pt padding)")
                            .font(Theme.mono(11, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appPanelStyle(padding: 8, radius: Theme.cornerMedium)
                }
                .frame(maxWidth: 400)
            }

            catalogSection("sidebarRowStyle()") {
                VStack(spacing: 2) {
                    row("Default", false, false)
                    row("Selected", true, false)
                    row("Hovered", false, true)
                }
                .frame(maxWidth: 300)
            }

            catalogSection("appDivider()") {
                VStack(spacing: 0) {
                    Text("Above divider").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .appDivider()
                    Text("Below divider").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxWidth: 300)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
        }
    }

    private func row(_ label: String, _ selected: Bool, _ hovered: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(selected ? Theme.accent : Theme.textDim).frame(width: 6, height: 6)
            Text(label)
                .font(Theme.mono(10, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
            Spacer()
        }
        .sidebarRowStyle(isSelected: selected, isHovered: hovered)
    }
}
