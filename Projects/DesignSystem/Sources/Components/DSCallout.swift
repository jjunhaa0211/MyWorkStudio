import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSCallout (Inline Alert / Callout Box)
// ═══════════════════════════════════════════════════════

public enum DSCalloutVariant {
    case info, success, warning, error, neutral

    public var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .neutral: return "text.quote"
        }
    }

    public var tint: Color {
        switch self {
        case .info: return Theme.accent
        case .success: return Theme.green
        case .warning: return Theme.yellow
        case .error: return Theme.red
        case .neutral: return Theme.textDim
        }
    }
}

public struct DSCallout<Content: View>: View {
    public let variant: DSCalloutVariant
    public let title: String?
    public let content: Content

    public init(
        _ variant: DSCalloutVariant = .info,
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.title = title
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.sp3) {
            Image(systemName: variant.icon)
                .font(.system(size: Theme.iconSize(11), weight: .medium))
                .foregroundColor(variant.tint)
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                content
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(Theme.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(variant.tint.opacity(Theme.isCustomMode ? 0.06 : 0.05))
        )
        .overlay(
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(variant.tint.opacity(0.6))
                    .frame(width: 3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .stroke(variant.tint.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Convenience for simple text callouts
public extension DSCallout where Content == Text {
    init(_ variant: DSCalloutVariant = .info, title: String? = nil, message: String) {
        self.variant = variant
        self.title = title
        self.content = Text(message)
    }
}
