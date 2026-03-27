import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSContextMenu (Themed Context Menu Items)
// ═══════════════════════════════════════════════════════

public struct DSMenuItem {
    public let title: String
    public let icon: String
    public var tint: Color
    public var isDestructive: Bool
    public let action: () -> Void

    public init(_ title: String, icon: String, tint: Color = Theme.textPrimary, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.isDestructive = isDestructive
        self.action = action
    }
}

public struct DSContextMenuModifier: ViewModifier {
    public let items: [DSMenuItem]

    public init(_ items: [DSMenuItem]) {
        self.items = items
    }

    public func body(content: Content) -> some View {
        content.contextMenu {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(role: item.isDestructive ? .destructive : nil, action: item.action) {
                    Label(item.title, systemImage: item.icon)
                }
            }
        }
    }
}

public extension View {
    func dsContextMenu(_ items: [DSMenuItem]) -> some View {
        modifier(DSContextMenuModifier(items))
    }
}
