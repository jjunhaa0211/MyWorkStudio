import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSColorPicker (Preset + Custom Hex)
// ═══════════════════════════════════════════════════════

public struct DSColorPicker: View {
    @Binding public var selectedHex: String
    public var presets: [String]
    public var label: String? = nil

    @State private var hexInput: String = ""

    public static let defaultPresets = [
        "3291ff", "3ecf8e", "f14c4c", "f5a623",
        "8e4ec6", "f97316", "06b6d4", "e54d9e",
        "ededed", "707070", "333333", "000000"
    ]

    public init(selectedHex: Binding<String>, presets: [String]? = nil, label: String? = nil) {
        self._selectedHex = selectedHex
        self.presets = presets ?? Self.defaultPresets
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp2) {
            if let label {
                Text(label)
                    .font(Theme.chrome(9, weight: .medium))
                    .foregroundColor(Theme.textDim)
            }

            // Preset grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: min(presets.count, 8)), spacing: 6) {
                ForEach(presets, id: \.self) { hex in
                    Button(action: {
                        selectedHex = hex
                        hexInput = hex
                    }) {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(selectedHex == hex ? Theme.textPrimary : Theme.border, lineWidth: selectedHex == hex ? 2 : 1)
                                    .allowsHitTesting(false)
                            )
                            .overlay {
                                if selectedHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color(hex: hex).contrastingTextColor)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Hex input
            HStack(spacing: 6) {
                Text("#")
                    .font(Theme.code(10, weight: .bold))
                    .foregroundColor(Theme.textDim)
                TextField("hex", text: $hexInput)
                    .textFieldStyle(.plain)
                    .font(Theme.code(10))
                    .frame(width: 70)
                    .onSubmit {
                        let cleaned = hexInput.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        if Color.isValidHex(cleaned) {
                            selectedHex = cleaned
                        }
                    }

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: selectedHex))
                    .frame(width: 20, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
            }
            .appFieldStyle()
        }
        .onAppear { hexInput = selectedHex }
        .onChange(of: selectedHex) { _, new in hexInput = new }
    }
}
