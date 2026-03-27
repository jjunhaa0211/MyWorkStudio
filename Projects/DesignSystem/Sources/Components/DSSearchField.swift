import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSSearchField
// ═══════════════════════════════════════════════════════

public struct DSSearchField: View {
    @Binding public var text: String
    public var placeholder: String
    public var onSubmit: (() -> Void)? = nil

    public init(_ placeholder: String = "Search...", text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: Theme.sp2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Theme.chromeIconSize(10), weight: .medium))
                .foregroundColor(Theme.textDim)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textPrimary)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button(action: { withAnimation(.easeOut(duration: 0.12)) { text = "" } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.chromeIconSize(10)))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgInput))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
        .animation(.easeOut(duration: 0.12), value: text.isEmpty)
    }
}
