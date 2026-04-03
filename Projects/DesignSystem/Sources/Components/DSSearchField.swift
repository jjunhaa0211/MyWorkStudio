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
        HStack(spacing: Theme.sp2 + 1) {
            ZStack {
                Circle()
                    .fill(Theme.accentSoftBackground)
                    .frame(width: 24, height: 24)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Theme.chromeIconSize(10), weight: .semibold))
                    .foregroundColor(text.isEmpty ? Theme.textDim : Theme.accent)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.mono(10.5))
                .foregroundColor(Theme.textPrimary)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button(action: { withAnimation(.easeOut(duration: 0.12)) { text = "" } }) {
                    ZStack {
                        Circle()
                            .fill(Theme.bgTertiary)
                            .frame(width: 20, height: 20)
                        Image(systemName: "xmark")
                            .font(.system(size: Theme.chromeIconSize(8), weight: .bold))
                            .foregroundColor(Theme.textDim)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.sp3 + 1)
        .padding(.vertical, Theme.sp2 + 1)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.controlBackground))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(text.isEmpty ? Theme.border : Theme.borderActive, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(Theme.topHighlight.opacity(0.42), lineWidth: 1)
                .blur(radius: 0.3)
                .mask(
                    LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
                .allowsHitTesting(false)
        )
        .shadow(color: text.isEmpty ? Theme.panelShadow.opacity(0.16) : Theme.ambientAccent.opacity(0.32), radius: 10, x: 0, y: 6)
        .animation(.easeOut(duration: 0.12), value: text.isEmpty)
    }
}
