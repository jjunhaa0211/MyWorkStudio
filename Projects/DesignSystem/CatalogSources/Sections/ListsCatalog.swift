import SwiftUI
import DesignSystem

struct ListsCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Lists & Rows")

            catalogSection("AppSectionHeader") {
                VStack(spacing: 0) {
                    AppSectionHeader(title: "Sessions", count: 5)
                    AppSectionHeader(title: "Plugins", count: 3, action: {}, actionLabel: "Manage")
                    AppSectionHeader(title: "Workers")
                }
                .frame(maxWidth: 400)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }

            catalogSection("DSListRow") {
                VStack(spacing: 2) {
                    DSListRow(title: "my-project", subtitle: "/Users/junha/develop/my-project") {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Theme.accent)
                    } trailing: {
                        AppStatusDot(color: Theme.green)
                    }

                    DSListRow(title: "api-server", subtitle: "/Users/junha/develop/api", isSelected: true) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Theme.orange)
                    } trailing: {
                        AppStatusBadge(title: "Running", symbol: "bolt.fill", tint: Theme.green)
                    }

                    DSListRow(title: "docs-site", subtitle: "/Users/junha/develop/docs") {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Theme.purple)
                    } trailing: {
                        AppStatusDot(color: Theme.textDim)
                    }
                }
                .frame(maxWidth: 500)
            }

            catalogSection("AppKeyValueRow") {
                VStack(spacing: 0) {
                    AppKeyValueRow(key: "Status", value: "Active", valueColor: Theme.green)
                    AppKeyValueRow(key: "Model", value: "claude-sonnet-4-20250514", mono: true)
                    AppKeyValueRow(key: "Tokens", value: "12,345", valueColor: Theme.accent)
                    AppKeyValueRow(key: "Duration", value: "3m 42s")
                }
                .frame(maxWidth: 400)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
        }
    }
}
