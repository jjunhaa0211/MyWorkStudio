import SwiftUI

// MARK: - Stat Card (통합 stat/metric 카드)

public struct DSStatCard: View {
    public let title: String
    public let value: String
    public var subtitle: String = ""
    public var icon: String = ""
    public var tint: Color = Theme.textPrimary

    public init(title: String, value: String, subtitle: String = "", icon: String = "", tint: Color = Theme.textPrimary) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp2) {
            HStack(spacing: Theme.sp1) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(Theme.textDim)
                }
                Text(title)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
            Text(value)
                .font(Theme.mono(16, weight: .semibold))
                .foregroundColor(tint)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.sp3)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }
}
