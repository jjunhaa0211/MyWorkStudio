import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSTooltip (Hover Tooltip)
// ═══════════════════════════════════════════════════════

public struct DSTooltipModifier: ViewModifier {
    public let text: String
    public let edge: Edge

    @State private var isHovered = false

    public init(_ text: String, edge: Edge = .top) {
        self.text = text
        self.edge = edge
    }

    public func body(content: Content) -> some View {
        content
            .onHover { isHovered = $0 }
            .overlay(alignment: alignment) {
                if isHovered {
                    Text(text)
                        .font(Theme.mono(9, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                                .fill(Theme.bgCard)
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                                .stroke(Theme.border, lineWidth: 1)
                                .allowsHitTesting(false)
                        )
                        .fixedSize()
                        .offset(tooltipOffset)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(999)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private var alignment: Alignment {
        switch edge {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private var tooltipOffset: CGSize {
        switch edge {
        case .top: return CGSize(width: 0, height: -8)
        case .bottom: return CGSize(width: 0, height: 8)
        case .leading: return CGSize(width: -8, height: 0)
        case .trailing: return CGSize(width: 8, height: 0)
        }
    }
}

public extension View {
    func dsTooltip(_ text: String, edge: Edge = .top) -> some View {
        modifier(DSTooltipModifier(text, edge: edge))
    }
}
