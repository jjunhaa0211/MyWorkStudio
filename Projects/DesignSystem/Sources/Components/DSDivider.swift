import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSDivider (Labeled Divider)
// ═══════════════════════════════════════════════════════

public struct DSDivider: View {
    public let label: String?
    public var color: Color

    public init(_ label: String? = nil, color: Color = Theme.border) {
        self.label = label
        self.color = color
    }

    public var body: some View {
        if let label, !label.isEmpty {
            HStack(spacing: Theme.sp3) {
                line
                Text(label)
                    .font(Theme.chrome(8, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .layoutPriority(1)
                line
            }
        } else {
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

/// Vertical divider
public struct DSVerticalDivider: View {
    public var height: CGFloat? = nil
    public var color: Color

    public init(height: CGFloat? = nil, color: Color = Theme.border) {
        self.height = height
        self.color = color
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: height)
    }
}
