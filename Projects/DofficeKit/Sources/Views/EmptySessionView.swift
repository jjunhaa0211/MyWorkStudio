import SwiftUI
import DesignSystem

// MARK: - Supporting Views
// ═══════════════════════════════════════════════════════

public struct EmptySessionView: View {
    @ObservedObject private var settings = AppSettings.shared
    public var body: some View {
        VStack {
            Spacer()
            AppEmptyStateView(
                title: NSLocalizedString("terminal.no.session.title", comment: ""),
                message: NSLocalizedString("terminal.no.session.message", comment: ""),
                symbol: "plus.circle.fill",
                tint: Theme.accent
            )
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.bgTerminal)
    }
}
