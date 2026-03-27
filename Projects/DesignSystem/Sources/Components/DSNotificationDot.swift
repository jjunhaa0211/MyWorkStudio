import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSNotificationDot (Badge Counter / Dot)
// ═══════════════════════════════════════════════════════

public struct DSBadgeModifier: ViewModifier {
    public let count: Int?
    public var tint: Color
    public var showZero: Bool

    public init(count: Int? = nil, tint: Color = Theme.red, showZero: Bool = false) {
        self.count = count
        self.tint = tint
        self.showZero = showZero
    }

    private var shouldShow: Bool {
        guard let count else { return true }  // nil = dot only
        return count > 0 || showZero
    }

    public func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if shouldShow {
                badge
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let count, count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 4 : 2)
                .frame(minWidth: 16, minHeight: 16)
                .background(Capsule().fill(tint))
                .overlay(Capsule().stroke(Theme.bgCard, lineWidth: 1.5).allowsHitTesting(false))
        } else {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Theme.bgCard, lineWidth: 1.5).allowsHitTesting(false))
        }
    }
}

public extension View {
    /// Add a notification dot
    func dsBadge(tint: Color = Theme.red) -> some View {
        modifier(DSBadgeModifier(tint: tint))
    }

    /// Add a notification badge with count
    func dsBadge(count: Int, tint: Color = Theme.red, showZero: Bool = false) -> some View {
        modifier(DSBadgeModifier(count: count, tint: tint, showZero: showZero))
    }
}
