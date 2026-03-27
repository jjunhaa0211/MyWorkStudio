import SwiftUI
import DesignSystem

struct ColorsCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Color Tokens")

            // Background Surfaces
            catalogSection("Background Surfaces") {
                HStack(spacing: 12) {
                    colorSwatch("bg", Theme.bg)
                    colorSwatch("bgCard", Theme.bgCard)
                    colorSwatch("bgSurface", Theme.bgSurface)
                    colorSwatch("bgTertiary", Theme.bgTertiary)
                }
                HStack(spacing: 12) {
                    colorSwatch("bgTerminal", Theme.bgTerminal)
                    colorSwatch("bgInput", Theme.bgInput)
                    colorSwatch("bgHover", Theme.bgHover)
                    colorSwatch("bgSelected", Theme.bgSelected)
                }
                HStack(spacing: 12) {
                    colorSwatch("bgPressed", Theme.bgPressed)
                    colorSwatch("bgDisabled", Theme.bgDisabled)
                }
            }

            // Text Hierarchy
            catalogSection("Text Hierarchy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary — Main content text")
                        .font(Theme.mono(12)).foregroundColor(Theme.textPrimary)
                    Text("Secondary — Supporting text")
                        .font(Theme.mono(12)).foregroundColor(Theme.textSecondary)
                    Text("Dim — Labels, captions")
                        .font(Theme.mono(12)).foregroundColor(Theme.textDim)
                    Text("Muted — Disabled, placeholder")
                        .font(Theme.mono(12)).foregroundColor(Theme.textMuted)
                }
            }

            // Borders
            catalogSection("Borders") {
                HStack(spacing: 12) {
                    borderSwatch("border", Theme.border)
                    borderSwatch("borderStrong", Theme.borderStrong)
                    borderSwatch("borderActive", Theme.borderActive)
                    borderSwatch("borderSubtle", Theme.borderSubtle)
                }
            }

            // Semantic Colors
            catalogSection("Semantic Colors") {
                HStack(spacing: 12) {
                    colorSwatch("accent", Theme.accent)
                    colorSwatch("green", Theme.green)
                    colorSwatch("red", Theme.red)
                    colorSwatch("yellow", Theme.yellow)
                }
                HStack(spacing: 12) {
                    colorSwatch("purple", Theme.purple)
                    colorSwatch("orange", Theme.orange)
                    colorSwatch("cyan", Theme.cyan)
                    colorSwatch("pink", Theme.pink)
                }
            }

            // Worker Colors
            catalogSection("Worker Colors (Pixel World)") {
                HStack(spacing: 8) {
                    ForEach(Array(Theme.workerColors.enumerated()), id: \.offset) { i, color in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(width: 40, height: 40)
                            Text("#\(i)")
                                .font(Theme.code(8))
                                .foregroundColor(Theme.textDim)
                        }
                    }
                }
            }
        }
    }

    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 80, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            Text(name)
                .font(Theme.code(9, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Text(color.hexString)
                .font(Theme.code(8))
                .foregroundColor(Theme.textDim)
        }
    }

    private func borderSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.bgCard)
                .frame(width: 80, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 2))
            Text(name)
                .font(Theme.code(9, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
