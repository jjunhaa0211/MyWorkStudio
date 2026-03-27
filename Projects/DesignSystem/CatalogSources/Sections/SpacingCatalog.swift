import SwiftUI
import DesignSystem

struct SpacingCatalog: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            catalogTitle("Spacing & Layout")

            catalogSection("4px Grid") {
                HStack(spacing: 16) {
                    spacingBlock("sp1", Theme.sp1)
                    spacingBlock("sp2", Theme.sp2)
                    spacingBlock("sp3", Theme.sp3)
                    spacingBlock("sp4", Theme.sp4)
                    spacingBlock("sp5", Theme.sp5)
                    spacingBlock("sp6", Theme.sp6)
                    spacingBlock("sp8", Theme.sp8)
                }
            }

            catalogSection("Corner Radii") {
                HStack(spacing: 16) {
                    cornerBlock("Small (5)", Theme.cornerSmall)
                    cornerBlock("Medium (6)", Theme.cornerMedium)
                    cornerBlock("Large (8)", Theme.cornerLarge)
                    cornerBlock("XL (12)", Theme.cornerXL)
                }
            }

            catalogSection("Row Heights") {
                VStack(spacing: 8) {
                    rowSample("rowCompact (28pt)", Theme.rowCompact)
                    rowSample("rowDefault (36pt)", Theme.rowDefault)
                    rowSample("rowComfortable (44pt)", Theme.rowComfortable)
                }
            }

            catalogSection("Animation Tokens") {
                VStack(alignment: .leading, spacing: 12) {
                    animRow("fast", "0.12s — Micro interactions")
                    animRow("normal", "0.2s — Standard transitions")
                    animRow("slow", "0.35s — Deliberate transitions")
                }
            }
        }
    }

    private func spacingBlock(_ label: String, _ value: CGFloat) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.accent.opacity(0.3))
                .frame(width: value, height: value)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.accent, lineWidth: 1))
            Text(label)
                .font(Theme.code(9, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Text("\(Int(value))pt")
                .font(Theme.code(8))
                .foregroundColor(Theme.textDim)
        }
    }

    private func cornerBlock(_ label: String, _ radius: CGFloat) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: radius)
                .fill(Theme.bgSurface)
                .frame(width: 64, height: 48)
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 1))
            Text(label)
                .font(Theme.code(9))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func rowSample(_ label: String, _ height: CGFloat) -> some View {
        HStack {
            Text(label)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .frame(height: height)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border, lineWidth: 1))
    }

    private func animRow(_ name: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Text("DSAnimation.\(name)")
                .font(Theme.code(9, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(width: 160, alignment: .leading)
            Text(desc)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
