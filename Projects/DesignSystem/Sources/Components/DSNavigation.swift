import SwiftUI

// MARK: - Tab Bar (설정, 필터 등에서 사용)

public struct DSTabBar: View {
    public let tabs: [(String, String)]  // (icon, label)
    @Binding public var selectedIndex: Int

    public init(tabs: [(String, String)], selectedIndex: Binding<Int>) {
        self.tabs = tabs
        self._selectedIndex = selectedIndex
    }

    public var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(tabs.enumerated()), id: \.element.1) { index, tab in
                Button(action: { selectedIndex = index }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.0)
                            .font(.system(size: Theme.chromeIconSize(9), weight: .medium))
                        Text(tab.1)
                            .font(Theme.chrome(9, weight: index == selectedIndex ? .semibold : .regular))
                    }
                    .foregroundColor(index == selectedIndex ? Theme.textPrimary : Theme.textDim)
                    .padding(.horizontal, Theme.sp3)
                    .padding(.vertical, Theme.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .fill(index == selectedIndex ? Theme.bgSurface : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .stroke(index == selectedIndex ? Theme.border : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Filter Chip (통합 필터 칩)

public struct DSFilterChip: View {
    public let label: String
    public let isSelected: Bool
    public var count: Int? = nil
    public let action: () -> Void

    public init(label: String, isSelected: Bool, count: Int? = nil, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(Theme.chrome(9, weight: isSelected ? .semibold : .regular))
                if let count {
                    Text("\(count)")
                        .font(Theme.chrome(8, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .foregroundColor(isSelected ? Theme.textPrimary : Theme.textDim)
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp1 + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isSelected ? Theme.bgSurface : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(isSelected ? Theme.border : Theme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(label))
    }
}
