import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSChart (Simple Bar & Line Charts)
// ═══════════════════════════════════════════════════════

public struct DSBarChart: View {
    public struct DataPoint: Identifiable {
        public let id: String
        public let value: Double
        public var label: String?
        public var tint: Color

        public init(_ id: String, value: Double, label: String? = nil, tint: Color = Theme.accent) {
            self.id = id; self.value = value; self.label = label; self.tint = tint
        }
    }

    public let data: [DataPoint]
    public var height: CGFloat = 120
    public var showLabels: Bool = true

    public init(_ data: [DataPoint], height: CGFloat = 120, showLabels: Bool = true) {
        self.data = data
        self.height = height
        self.showLabels = showLabels
    }

    private var maxValue: Double { data.map(\.value).max() ?? 1 }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data) { point in
                    VStack(spacing: 2) {
                        if showLabels {
                            Text(formatValue(point.value))
                                .font(Theme.code(7, weight: .bold))
                                .foregroundColor(point.tint)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(point.tint)
                            .frame(height: max(2, height * CGFloat(point.value / maxValue)))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(point.label ?? point.id): \(formatValue(point.value))")
                }
            }
            .frame(height: height)

            if showLabels {
                HStack(spacing: 4) {
                    ForEach(data) { point in
                        Text(point.label ?? point.id)
                            .font(Theme.code(7))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Bar chart with \(data.count) items"))
    }

    private func formatValue(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        if v == floor(v) { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }
}

public struct DSMiniSparkline: View {
    public let values: [Double]
    public var tint: Color
    public var height: CGFloat

    public init(_ values: [Double], tint: Color = Theme.accent, height: CGFloat = 24) {
        self.values = values
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let maxVal = values.max() ?? 1
            let minVal = values.min() ?? 0
            let range = max(maxVal - minVal, 0.001)
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (i, val) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - (CGFloat((val - minVal) / range) * size.height)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            context.stroke(path, with: .color(tint), lineWidth: 1.5)

            // Fill gradient
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(tint.opacity(0.1)))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
