import SwiftUI
import DesignSystem

struct ModalsCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Modal System")

            catalogSection("DSModalHeader") {
                VStack(spacing: 16) {
                    DSModalHeader(
                        icon: "gearshape.fill",
                        iconColor: Theme.accent,
                        title: "Settings",
                        subtitle: "Configure your workspace"
                    )

                    DSModalHeader(
                        icon: "plus.circle.fill",
                        iconColor: Theme.green,
                        title: "New Session",
                        subtitle: "Start a new Claude Code session",
                        onClose: {}
                    )
                }
                .frame(maxWidth: 500)
            }

            catalogSection("DSSection") {
                VStack(spacing: 12) {
                    DSSection(title: "General", subtitle: "Basic configuration") {
                        Text("Section content goes here")
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textSecondary)
                    }

                    DSSection(title: "Advanced") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Item 1").font(Theme.mono(10)).foregroundColor(Theme.textPrimary)
                            Text("Item 2").font(Theme.mono(10)).foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .frame(maxWidth: 500)
            }

            catalogSection("DSModalFooter") {
                DSModalFooter {
                    Button("Cancel") {}
                        .buttonStyle(.plain)
                        .font(Theme.mono(10, weight: .bold))
                        .appButtonSurface(tone: .neutral)
                } trailing: {
                    Button("Save") {}
                        .buttonStyle(.plain)
                        .font(Theme.mono(10, weight: .bold))
                        .appButtonSurface(tone: .accent, prominent: true)
                }
                .frame(maxWidth: 500)
            }
        }
    }
}
