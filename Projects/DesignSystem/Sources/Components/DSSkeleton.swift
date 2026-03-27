import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSSkeleton (Loading Placeholder)
// ═══════════════════════════════════════════════════════

public struct DSSkeleton: View {
    public enum Shape {
        case rectangle, circle, capsule
    }

    public let shape: Shape
    public let width: CGFloat?
    public let height: CGFloat
    @State private var shimmerPhase: CGFloat = -1

    public init(_ shape: Shape = .rectangle, width: CGFloat? = nil, height: CGFloat = 12) {
        self.shape = shape
        self.width = width
        self.height = height
    }

    private var cornerRadius: CGFloat {
        switch shape {
        case .rectangle: return Theme.cornerSmall
        case .circle, .capsule: return height / 2
        }
    }

    private var resolvedWidth: CGFloat? {
        if shape == .circle { return height }
        return width
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.bgTertiary)
            .overlay(
                LinearGradient(
                    colors: [.clear, Theme.bgSurface.opacity(0.5), .clear],
                    startPoint: .init(x: shimmerPhase - 0.3, y: 0.5),
                    endPoint: .init(x: shimmerPhase + 0.3, y: 0.5)
                )
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .frame(width: resolvedWidth, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 2
                }
            }
            .accessibilityHidden(true)
    }
}

/// Pre-built skeleton patterns
public struct DSSkeletonRow: View {
    public let hasAvatar: Bool
    public let lines: Int

    public init(hasAvatar: Bool = false, lines: Int = 2) {
        self.hasAvatar = hasAvatar
        self.lines = lines
    }

    public var body: some View {
        HStack(spacing: Theme.sp3) {
            if hasAvatar {
                DSSkeleton(.circle, height: 28)
            }
            VStack(alignment: .leading, spacing: 6) {
                DSSkeleton(.capsule, width: 120, height: 10)
                if lines > 1 {
                    DSSkeleton(.capsule, width: 200, height: 8)
                }
                if lines > 2 {
                    DSSkeleton(.capsule, width: 160, height: 8)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.sp2)
    }
}
