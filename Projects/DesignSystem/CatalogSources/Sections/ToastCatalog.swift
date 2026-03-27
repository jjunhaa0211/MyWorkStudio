import SwiftUI
import DesignSystem

struct ToastCatalog: View {
    @State private var showSuccess = false
    @State private var showError = false
    @State private var showWarning = false
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Toast Notifications")

            catalogSection("DSToastView — Static") {
                VStack(spacing: 12) {
                    DSToastView(message: "Changes saved successfully", style: .success)
                    DSToastView(message: "Failed to connect", style: .error, detail: "Check your network settings")
                    DSToastView(message: "API limit approaching", style: .warning)
                    DSToastView(message: "Session resumed", style: .info)
                }
            }

            catalogSection("dsToast() — Interactive") {
                HStack(spacing: 8) {
                    DSButton("Success", icon: "checkmark", tone: .green, compact: true) { showSuccess = true }
                    DSButton("Error", icon: "xmark", tone: .red, compact: true) { showError = true }
                    DSButton("Warning", icon: "exclamationmark.triangle", tone: .yellow, compact: true) { showWarning = true }
                    DSButton("Info", icon: "info.circle", tone: .accent, compact: true) { showInfo = true }
                }
            }
        }
        .dsToast(isPresented: $showSuccess, message: "Operation completed!", style: .success)
        .dsToast(isPresented: $showError, message: "Something went wrong", style: .error)
        .dsToast(isPresented: $showWarning, message: "Careful!", style: .warning)
        .dsToast(isPresented: $showInfo, message: "FYI: new update available", style: .info)
    }
}
