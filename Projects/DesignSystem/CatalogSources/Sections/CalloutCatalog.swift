import SwiftUI
import DesignSystem

struct CalloutCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Callouts & Alerts")

            catalogSection("DSCallout — Variants") {
                VStack(spacing: 12) {
                    DSCallout(.info, title: "Information", message: "This is an informational callout for general notices.")
                    DSCallout(.success, title: "Success", message: "Your changes have been saved successfully.")
                    DSCallout(.warning, title: "Warning", message: "This action cannot be undone. Please proceed with caution.")
                    DSCallout(.error, title: "Error", message: "Failed to save changes. Please try again.")
                    DSCallout(.neutral, message: "A neutral callout without a title for simple quotes or notes.")
                }
                .frame(maxWidth: 500)
            }

            catalogSection("DSCallout — Custom Content") {
                DSCallout(.info, title: "Tip") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Use keyboard shortcuts for faster navigation:")
                        HStack(spacing: 8) {
                            DSKeyboardShortcut("Cmd+T")
                            Text("New session")
                                .font(Theme.mono(9))
                                .foregroundColor(Theme.textDim)
                        }
                        HStack(spacing: 8) {
                            DSKeyboardShortcut("Cmd+K")
                            Text("Command palette")
                                .font(Theme.mono(9))
                                .foregroundColor(Theme.textDim)
                        }
                    }
                }
                .frame(maxWidth: 500)
            }
        }
    }
}
