import SwiftUI
import DesignSystem

struct ButtonsCatalog: View {
    @State private var clickCount = 0
    @State private var lastClicked = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Button Styles")

            if !lastClicked.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(Theme.green)
                    Text("Clicked: \(lastClicked) (total: \(clickCount))")
                        .font(Theme.code(10, weight: .medium))
                        .foregroundColor(Theme.green)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.2), lineWidth: 1))
            }

            catalogSection("Tones — Default") {
                HStack(spacing: 12) {
                    sampleButton("Neutral", .neutral)
                    sampleButton("Accent", .accent)
                    sampleButton("Green", .green)
                    sampleButton("Red", .red)
                    sampleButton("Yellow", .yellow)
                    sampleButton("Purple", .purple)
                }
            }

            catalogSection("Prominent") {
                HStack(spacing: 12) {
                    sampleButton("Accent", .accent, prominent: true)
                    sampleButton("Green", .green, prominent: true)
                    sampleButton("Red", .red, prominent: true)
                    sampleButton("Purple", .purple, prominent: true)
                }
            }

            catalogSection("Compact") {
                HStack(spacing: 12) {
                    sampleButton("Tag", .accent, compact: true)
                    sampleButton("Close", .red, compact: true)
                    sampleButton("Save", .green, compact: true)
                }
            }

            catalogSection("Prominent + Compact") {
                HStack(spacing: 12) {
                    sampleButton("Run", .accent, prominent: true, compact: true)
                    sampleButton("Delete", .red, prominent: true, compact: true)
                    sampleButton("Apply", .green, prominent: true, compact: true)
                }
            }

            catalogSection("Disabled State") {
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Disabled")
                            .font(Theme.mono(10, weight: .bold))
                            .appButtonSurface(tone: .accent, prominent: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.4)

                    Button(action: {}) {
                        Text("Disabled")
                            .font(Theme.mono(10, weight: .bold))
                            .appButtonSurface(tone: .neutral)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.4)
                }
            }
        }
    }

    private func sampleButton(_ label: String, _ tone: AppChromeTone, prominent: Bool = false, compact: Bool = false) -> some View {
        Button(action: {
            clickCount += 1
            lastClicked = "\(label) (\(tone))"
        }) {
            Text(label)
                .font(Theme.mono(compact ? 9 : 10, weight: .bold))
                .appButtonSurface(tone: tone, prominent: prominent, compact: compact)
        }
        .buttonStyle(.plain)
    }
}
