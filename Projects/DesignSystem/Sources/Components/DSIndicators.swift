import SwiftUI

// MARK: - Empty State (Vercel: minimal, informative)

public struct AppEmptyStateView: View {
    public let title: String
    public let message: String
    public let symbol: String
    public var tint: Color = Theme.textDim

    public init(title: String, message: String, symbol: String, tint: Color = Theme.textDim) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: Theme.sp3) {
            Image(systemName: symbol)
                .font(.system(size: Theme.iconSize(20), weight: .light))
                .foregroundColor(tint.opacity(0.5))
            VStack(spacing: Theme.sp1) {
                Text(title)
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Text(message)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.sp8)
        .padding(.horizontal, Theme.sp4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress Bar (통합 프로그레스 바)

public struct DSProgressBar: View {
    public let value: Double  // 0.0 ~ 1.0
    public var tint: Color = Theme.accent
    public var height: CGFloat = 4

    public init(value: Double, tint: Color = Theme.accent, height: CGFloat = 4) {
        self.value = value
        self.tint = tint
        self.height = height
    }

    private var clampedValue: Double { min(max(value, 0), 1) }

    public var body: some View {
        Capsule()
            .fill(Theme.bgSurface)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * clampedValue)
                }
            }
            .clipShape(Capsule())
            .accessibilityValue(Text("\(Int(clampedValue * 100))%"))
            .accessibilityLabel(Text("Progress"))
    }
}
