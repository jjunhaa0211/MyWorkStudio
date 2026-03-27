import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSAccordion (Collapsible Section)
// ═══════════════════════════════════════════════════════

public struct DSAccordion<Content: View>: View {
    public let title: String
    public var icon: String? = nil
    public var tint: Color = Theme.textSecondary
    public var defaultExpanded: Bool = false
    public let content: Content

    @State private var isExpanded: Bool

    public init(
        _ title: String,
        icon: String? = nil,
        tint: Color = Theme.textSecondary,
        defaultExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.defaultExpanded = defaultExpanded
        self._isExpanded = State(initialValue: defaultExpanded)
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                HStack(spacing: Theme.sp2) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 12)

                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: Theme.chromeIconSize(10), weight: .medium))
                            .foregroundColor(tint)
                    }

                    Text(title)
                        .font(Theme.chrome(10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, Theme.sp2 + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(isExpanded ? "expanded" : "collapsed"))

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.leading, Theme.sp5 + 4)
                    .padding(.trailing, Theme.sp3)
                    .padding(.bottom, Theme.sp2)
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgCard))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .stroke(Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

/// Controlled accordion (external state)
public struct DSControlledAccordion<Content: View>: View {
    public let title: String
    public var icon: String? = nil
    @Binding public var isExpanded: Bool
    public let content: Content

    public init(_ title: String, icon: String? = nil, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                HStack(spacing: Theme.sp2) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 12)

                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: Theme.chromeIconSize(10), weight: .medium))
                            .foregroundColor(Theme.accent)
                    }

                    Text(title)
                        .font(Theme.chrome(10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, Theme.sp2 + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.leading, Theme.sp5 + 4)
                    .padding(.trailing, Theme.sp3)
                    .padding(.bottom, Theme.sp2)
            }
        }
    }
}
