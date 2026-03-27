import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSToggle (Themed Toggle / Switch)
// ═══════════════════════════════════════════════════════

public struct DSToggle: View {
    @Binding public var isOn: Bool
    public let label: String
    public var icon: String? = nil
    public var description: String? = nil
    public var tint: Color

    public init(_ label: String, icon: String? = nil, description: String? = nil, isOn: Binding<Bool>, tint: Color = Theme.accent) {
        self.label = label
        self.icon = icon
        self.description = description
        self._isOn = isOn
        self.tint = tint
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Theme.sp2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: Theme.chromeIconSize(10), weight: .medium))
                        .foregroundColor(isOn ? tint : Theme.textDim)
                        .frame(width: 16)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    if let description {
                        Text(description)
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .tint(tint)
        .controlSize(.small)
    }
}

/// Compact inline toggle (no label layout, just the switch)
public struct DSToggleChip: View {
    @Binding public var isOn: Bool
    public let label: String
    public var tint: Color

    public init(_ label: String, isOn: Binding<Bool>, tint: Color = Theme.accent) {
        self.label = label
        self._isOn = isOn
        self.tint = tint
    }

    public var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() } }) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isOn ? tint : .clear)
                    .frame(width: 10, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(isOn ? tint : Theme.textDim, lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                    .overlay {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .black))
                                .foregroundColor(.white)
                        }
                    }
                Text(label)
                    .font(Theme.chrome(9, weight: isOn ? .semibold : .regular))
                    .foregroundColor(isOn ? Theme.textPrimary : Theme.textDim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}
