import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSSplitPane (Draggable Split View)
// ═══════════════════════════════════════════════════════

public struct DSSplitPane<Leading: View, Trailing: View>: View {
    public let leading: Leading
    public let trailing: Trailing
    public var minLeading: CGFloat
    public var minTrailing: CGFloat
    public var initialRatio: CGFloat

    @State private var ratio: CGFloat
    @State private var isDragging = false

    public init(
        minLeading: CGFloat = 150,
        minTrailing: CGFloat = 150,
        initialRatio: CGFloat = 0.5,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.minLeading = minLeading
        self.minTrailing = minTrailing
        self.initialRatio = initialRatio
        self._ratio = State(initialValue: initialRatio)
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let dividerWidth: CGFloat = 6
            let availableWidth = totalWidth - dividerWidth
            let leadingWidth = max(minLeading, min(availableWidth - minTrailing, availableWidth * ratio))

            HStack(spacing: 0) {
                leading
                    .frame(width: leadingWidth)

                // Divider handle
                Rectangle()
                    .fill(isDragging ? Theme.accent.opacity(0.3) : Theme.border)
                    .frame(width: 1)
                    .padding(.horizontal, 2.5)
                    .frame(width: dividerWidth)
                    .contentShape(Rectangle())
                    .onHover { hover in
                        if hover { NSCursor.resizeLeftRight.push() }
                        else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isDragging = true
                                let newLeading = value.location.x
                                ratio = max(minLeading / availableWidth, min((availableWidth - minTrailing) / availableWidth, newLeading / availableWidth))
                            }
                            .onEnded { _ in isDragging = false }
                    )
                    .accessibilityLabel("Split pane divider")
                    .accessibilityHint("Drag to resize panes")

                trailing
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
