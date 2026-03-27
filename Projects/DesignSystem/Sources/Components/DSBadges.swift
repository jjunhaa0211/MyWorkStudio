import SwiftUI

// MARK: - Status Badge (Vercel-style: tight, border-accented)

public struct AppStatusBadge: View {
    public let title: String
    public let symbol: String
    public let tint: Color
    public var compact: Bool = true

    public init(title: String, symbol: String, tint: Color, compact: Bool = true) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: compact ? Theme.chromeIconSize(8) : Theme.iconSize(9), weight: .medium))
            Text(title)
                .font(compact ? Theme.chrome(8, weight: .medium) : Theme.mono(9, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, compact ? Theme.sp1 + 2 : Theme.sp2)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                .fill(Theme.accentBg(tint))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                .stroke(Theme.accentBorder(tint), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Status Dot (Vercel deployments style: tiny colored circle)

public struct AppStatusDot: View {
    public let color: Color
    public var size: CGFloat = 6

    public init(color: Color, size: CGFloat = 6) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Inline Code Block

public struct AppInlineCode: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(Theme.code(10))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, Theme.sp1 + 1)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.borderSubtle, lineWidth: 1))
    }
}
