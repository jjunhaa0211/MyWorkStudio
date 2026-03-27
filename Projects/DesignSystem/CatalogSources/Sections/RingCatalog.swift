import SwiftUI
import DesignSystem

struct RingCatalog: View {
    @State private var isActive = true

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Ring Indicators")

            catalogSection("DSRing — Sizes") {
                HStack(spacing: 24) {
                    VStack(spacing: 6) { DSRing(tint: Theme.accent, size: 16); Text("16pt").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 6) { DSRing(tint: Theme.green, size: 24); Text("24pt").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 6) { DSRing(tint: Theme.purple, size: 36); Text("36pt").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                    VStack(spacing: 6) { DSRing(tint: Theme.orange, size: 48); Text("48pt").font(Theme.code(8)).foregroundColor(Theme.textDim) }
                }
            }

            catalogSection("DSActivityIndicator") {
                VStack(alignment: .leading, spacing: 12) {
                    DSActivityIndicator("Processing request...", tint: Theme.accent)
                    DSActivityIndicator("Compiling...", tint: Theme.green)
                    DSActivityIndicator("Idle", tint: Theme.textDim, isActive: false)
                }
            }

            catalogSection("Interactive") {
                VStack(spacing: 12) {
                    DSRing(tint: Theme.accent, size: 40, isAnimating: isActive)
                    DSButton(isActive ? "Stop" : "Start", tone: isActive ? .red : .green, compact: true) { isActive.toggle() }
                }
            }
        }
    }
}
