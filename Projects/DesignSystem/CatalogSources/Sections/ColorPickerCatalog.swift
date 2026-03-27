import SwiftUI
import DesignSystem

struct ColorPickerCatalog: View {
    @State private var selectedHex = "3291ff"

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Color Picker")

            catalogSection("DSColorPicker — Default Presets") {
                DSColorPicker(selectedHex: $selectedHex, label: "Accent Color")
                    .frame(maxWidth: 300)
            }

            catalogSection("Preview") {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: selectedHex))
                        .frame(width: 60, height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(selectedHex)").font(Theme.code(12, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("Selected color").font(Theme.mono(9)).foregroundColor(Theme.textDim)
                    }
                }
            }
        }
    }
}
