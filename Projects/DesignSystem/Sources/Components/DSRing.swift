import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSRing (Activity Ring / Pulse Indicator)
// ═══════════════════════════════════════════════════════

public struct DSRing: View {
    public let tint: Color
    public var size: CGFloat
    public var lineWidth: CGFloat
    public var isAnimating: Bool

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    public init(tint: Color = Theme.accent, size: CGFloat = 24, lineWidth: CGFloat = 2, isAnimating: Bool = true) {
        self.tint = tint
        self.size = size
        self.lineWidth = lineWidth
        self.isAnimating = isAnimating
    }

    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)

            // Active arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))

            // Pulse dot
            if isAnimating {
                Circle()
                    .fill(tint.opacity(0.3))
                    .scaleEffect(pulseScale)
                    .frame(width: size * 0.4, height: size * 0.4)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                pulseScale = 1.4
            }
        }
        .onChange(of: isAnimating) { _, animating in
            if !animating { rotation = 0; pulseScale = 1.0 }
        }
        .accessibilityLabel(Text(isAnimating ? "Loading" : "Idle"))
    }
}

/// Inline activity indicator with label
public struct DSActivityIndicator: View {
    public let label: String
    public var tint: Color
    public var isActive: Bool

    public init(_ label: String, tint: Color = Theme.accent, isActive: Bool = true) {
        self.label = label
        self.tint = tint
        self.isActive = isActive
    }

    public var body: some View {
        HStack(spacing: 8) {
            DSRing(tint: tint, size: 14, lineWidth: 1.5, isAnimating: isActive)
            Text(label)
                .font(Theme.mono(10, weight: .medium))
                .foregroundColor(isActive ? Theme.textPrimary : Theme.textDim)
        }
    }
}
