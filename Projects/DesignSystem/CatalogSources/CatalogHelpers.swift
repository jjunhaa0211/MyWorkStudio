import SwiftUI
import DesignSystem

func catalogTitle(_ title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(Theme.mono(20, weight: .bold))
            .foregroundColor(Theme.textPrimary)
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

@ViewBuilder
func catalogSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(Theme.mono(13, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
        content()
    }
}
