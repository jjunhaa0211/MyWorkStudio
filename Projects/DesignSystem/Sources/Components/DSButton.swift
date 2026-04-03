import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSButton (Standardized Button Component)
// ═══════════════════════════════════════════════════════

public struct DSButton: View {
    public let title: String
    public let icon: String?
    public let tone: AppChromeTone
    public let prominent: Bool
    public let compact: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        tone: AppChromeTone = .accent,
        prominent: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.prominent = prominent
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 5 : 7) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: Theme.iconSize(compact ? 9 : 10), weight: .semibold))
                }
                Text(title)
                    .font(Theme.mono(compact ? 9 : 10.5, weight: .bold))
                    .tracking(compact ? 0.1 : 0.2)
            }
            .frame(minHeight: compact ? 28 : 34)
            .appButtonSurface(tone: tone, prominent: prominent, compact: compact)
        }
        .buttonStyle(.plain)
    }
}

/// Icon-only button variant
public struct DSIconButton: View {
    public let icon: String
    public let size: CGFloat
    public let tint: Color
    public let action: () -> Void

    public init(
        _ icon: String,
        size: CGFloat = 10,
        tint: Color = Theme.textDim,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(size), weight: .medium))
                .foregroundColor(tint)
                .frame(width: size * 2.7, height: size * 2.7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .fill(Theme.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .shadow(color: Theme.panelShadow.opacity(0.16), radius: 6, x: 0, y: 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(icon))
    }
}

/// Button group for consistent spacing
public struct DSButtonGroup<Content: View>: View {
    public let spacing: CGFloat
    public let content: Content

    public init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: spacing) { content }
    }
}
