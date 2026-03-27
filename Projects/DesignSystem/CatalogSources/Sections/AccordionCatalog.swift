import SwiftUI
import DesignSystem

struct AccordionCatalog: View {
    @State private var controlled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Accordion / Collapsible")

            catalogSection("DSAccordion — Basic") {
                VStack(spacing: 8) {
                    DSAccordion("General Settings", icon: "gearshape.fill", tint: Theme.accent, defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            AppKeyValueRow(key: "Language", value: "Korean")
                            AppKeyValueRow(key: "Theme", value: "Dark")
                            AppKeyValueRow(key: "Font Scale", value: "1.5x")
                        }
                    }

                    DSAccordion("Advanced", icon: "wrench.and.screwdriver.fill", tint: Theme.orange) {
                        Text("Advanced options content here")
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textDim)
                            .padding(.vertical, 4)
                    }

                    DSAccordion("Danger Zone", icon: "exclamationmark.triangle.fill", tint: Theme.red) {
                        DSCallout(.warning, message: "These actions are destructive and cannot be undone.")
                    }
                }
                .frame(maxWidth: 450)
            }

            catalogSection("DSControlledAccordion — External State") {
                VStack(spacing: 8) {
                    DSButton(controlled ? "Collapse" : "Expand", icon: controlled ? "chevron.up" : "chevron.down", tone: .accent, compact: true) {
                        withAnimation(.easeInOut(duration: 0.2)) { controlled.toggle() }
                    }

                    DSControlledAccordion("Controlled Section", icon: "slider.horizontal.3", isExpanded: $controlled) {
                        Text("This section is controlled by the button above.")
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: 450)
            }
        }
    }
}
