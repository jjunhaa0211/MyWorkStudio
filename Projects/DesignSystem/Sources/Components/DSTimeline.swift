import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSTimeline (History / Event Timeline)
// ═══════════════════════════════════════════════════════

public struct DSTimelineItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let tint: Color
    public let timestamp: String?

    public init(id: String = UUID().uuidString, title: String, subtitle: String? = nil, icon: String = "circle.fill", tint: Color = Theme.accent, timestamp: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.timestamp = timestamp
    }
}

public struct DSTimeline: View {
    public let items: [DSTimelineItem]

    public init(_ items: [DSTimelineItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: Theme.sp3) {
                    // Timeline rail
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle().fill(Theme.border).frame(width: 1).frame(height: 8)
                        } else {
                            Spacer().frame(height: 8)
                        }

                        ZStack {
                            Circle()
                                .fill(item.tint.opacity(0.15))
                                .frame(width: 22, height: 22)
                            Image(systemName: item.icon)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(item.tint)
                        }

                        if index < items.count - 1 {
                            Rectangle().fill(Theme.border).frame(width: 1)
                                .frame(minHeight: 20)
                        }
                    }
                    .frame(width: 22)

                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.title)
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            if let timestamp = item.timestamp {
                                Text(timestamp)
                                    .font(Theme.code(8))
                                    .foregroundColor(Theme.textMuted)
                            }
                        }
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(Theme.mono(9))
                                .foregroundColor(Theme.textDim)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
