import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSSegmentedControl
// ═══════════════════════════════════════════════════════

public struct DSSegmentedControl<T: Hashable & CustomStringConvertible>: View {
    public let options: [T]
    @Binding public var selected: T
    public var tint: Color

    public init(_ options: [T], selected: Binding<T>, tint: Color = Theme.accent) {
        self.options = options
        self._selected = selected
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 1) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = option }
                }) {
                    Text(option.description)
                        .font(Theme.chrome(9, weight: selected == option ? .bold : .regular))
                        .foregroundColor(selected == option ? tint : Theme.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.sp2)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                                .fill(selected == option ? tint.opacity(0.1) : .clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == option ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
    }
}
