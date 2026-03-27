import SwiftUI

// MARK: - List Row (통합 리스트 행 컴포넌트)

public struct DSListRow<Leading: View, Trailing: View>: View {
    public let leading: Leading
    public let title: String
    public var subtitle: String = ""
    public let trailing: Trailing
    public var isSelected: Bool = false

    public init(title: String, subtitle: String = "", isSelected: Bool = false, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Theme.sp3) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(isSelected ? Theme.bgSelected : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .stroke(isSelected ? Theme.border : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Key-Value Row (for stats, metadata display)

public struct AppKeyValueRow: View {
    public let key: String
    public let value: String
    public var valueColor: Color = Theme.textPrimary
    public var mono: Bool = false

    public init(key: String, value: String, valueColor: Color = Theme.textPrimary, mono: Bool = false) {
        self.key = key
        self.value = value
        self.valueColor = valueColor
        self.mono = mono
    }

    public var body: some View {
        HStack {
            Text(key)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textDim)
            Spacer()
            Text(value)
                .font(mono ? Theme.code(10, weight: .medium) : Theme.mono(10, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Section Header (Vercel panel headers)

public struct AppSectionHeader: View {
    public let title: String
    public var count: Int? = nil
    public var action: (() -> Void)? = nil
    public var actionLabel: String = ""

    public init(title: String, count: Int? = nil, action: (() -> Void)? = nil, actionLabel: String = "") {
        self.title = title
        self.count = count
        self.action = action
        self.actionLabel = actionLabel
    }

    public var body: some View {
        HStack(spacing: Theme.sp2) {
            Text(title.uppercased())
                .font(Theme.chrome(9, weight: .semibold))
                .foregroundColor(Theme.textDim)
                .tracking(0.5)
            if let count {
                Text("\(count)")
                    .font(Theme.chrome(8, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
            }
            Spacer()
            if let action, !actionLabel.isEmpty {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Theme.chrome(9, weight: .medium))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
    }
}
