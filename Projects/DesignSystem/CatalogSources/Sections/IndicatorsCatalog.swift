import SwiftUI
import DesignSystem

struct IndicatorsCatalog: View {
    @State private var animatedProgress: Double = 0.0
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Indicators & States")

            catalogSection("DSProgressBar — Static") {
                VStack(spacing: 16) {
                    progressSample("0%", 0.0, Theme.accent)
                    progressSample("25%", 0.25, Theme.accent)
                    progressSample("50%", 0.5, Theme.green)
                    progressSample("75%", 0.75, Theme.yellow)
                    progressSample("100%", 1.0, Theme.red)
                }
                .frame(maxWidth: 400)
            }

            catalogSection("DSProgressBar — Animated") {
                VStack(spacing: 12) {
                    DSProgressBar(value: animatedProgress, tint: Theme.accent, height: 6)
                        .frame(maxWidth: 400)

                    HStack(spacing: 8) {
                        Text("\(Int(animatedProgress * 100))%")
                            .font(Theme.code(10, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 40)

                        Button(action: {
                            isAnimating.toggle()
                            if isAnimating {
                                startAnimation()
                            }
                        }) {
                            Text(isAnimating ? "Stop" : "Animate")
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: isAnimating ? .red : .accent, compact: true)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            isAnimating = false
                            withAnimation(.easeOut(duration: 0.2)) { animatedProgress = 0 }
                        }) {
                            Text("Reset")
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .neutral, compact: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            catalogSection("DSProgressBar — Heights") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("2pt").font(Theme.code(9)).foregroundColor(Theme.textDim).frame(width: 30)
                        DSProgressBar(value: 0.6, tint: Theme.accent, height: 2)
                    }
                    HStack(spacing: 12) {
                        Text("4pt").font(Theme.code(9)).foregroundColor(Theme.textDim).frame(width: 30)
                        DSProgressBar(value: 0.6, tint: Theme.green, height: 4)
                    }
                    HStack(spacing: 12) {
                        Text("8pt").font(Theme.code(9)).foregroundColor(Theme.textDim).frame(width: 30)
                        DSProgressBar(value: 0.6, tint: Theme.purple, height: 8)
                    }
                }
                .frame(maxWidth: 400)
            }

            catalogSection("AppEmptyStateView") {
                AppEmptyStateView(
                    title: "No sessions yet",
                    message: "Press Cmd+T to start a new Claude Code session.",
                    symbol: "plus.circle.fill",
                    tint: Theme.accent
                )
                .frame(maxWidth: 400)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
        }
    }

    private func progressSample(_ label: String, _ value: Double, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.code(10, weight: .medium))
                .foregroundColor(Theme.textDim)
                .frame(width: 40, alignment: .trailing)
            DSProgressBar(value: value, tint: tint)
        }
    }

    private func startAnimation() {
        guard isAnimating else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            animatedProgress = min(animatedProgress + 0.05, 1.0)
        }
        if animatedProgress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) { animatedProgress = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { startAnimation() }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { startAnimation() }
        }
    }
}
