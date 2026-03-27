import SwiftUI
import DesignSystem

struct SkeletonCatalog: View {
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Skeleton Loading")

            catalogSection("DSSkeleton — Shapes") {
                HStack(spacing: 24) {
                    VStack(spacing: 6) {
                        DSSkeleton(.rectangle, width: 80, height: 48)
                        Text("Rectangle").font(Theme.code(9)).foregroundColor(Theme.textDim)
                    }
                    VStack(spacing: 6) {
                        DSSkeleton(.circle, height: 48)
                        Text("Circle").font(Theme.code(9)).foregroundColor(Theme.textDim)
                    }
                    VStack(spacing: 6) {
                        DSSkeleton(.capsule, width: 80, height: 12)
                        Text("Capsule").font(Theme.code(9)).foregroundColor(Theme.textDim)
                    }
                }
            }

            catalogSection("DSSkeletonRow — List Loading") {
                VStack(spacing: 4) {
                    DSSkeletonRow(hasAvatar: true, lines: 2)
                    DSSkeletonRow(hasAvatar: true, lines: 2)
                    DSSkeletonRow(hasAvatar: true, lines: 1)
                }
                .frame(maxWidth: 400)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }

            catalogSection("Loading → Content Transition") {
                VStack(spacing: 12) {
                    DSButton(isLoading ? "Show Content" : "Show Loading", tone: .accent, compact: true) {
                        withAnimation(.easeInOut(duration: 0.3)) { isLoading.toggle() }
                    }

                    if isLoading {
                        VStack(spacing: 4) {
                            DSSkeletonRow(lines: 2)
                            DSSkeletonRow(lines: 1)
                        }
                    } else {
                        VStack(spacing: 8) {
                            AppKeyValueRow(key: "Status", value: "Active", valueColor: Theme.green)
                            AppKeyValueRow(key: "Model", value: "Sonnet 4", mono: true)
                        }
                    }
                }
                .frame(maxWidth: 400)
            }
        }
    }
}
