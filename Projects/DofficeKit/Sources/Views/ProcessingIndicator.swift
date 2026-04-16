import SwiftUI
import Combine
import DesignSystem

// MARK: - Processing Indicator
// ═══════════════════════════════════════════════════════

public struct ProcessingIndicator: View {
    public let activity: ClaudeActivity
    public let workerColor: Color
    public let workerName: String
    public var roleBadge: String?
    public var roleColor: Color?
    public var activityDetail: String?
    public var elapsedSeconds: Int = 0
    @ObservedObject private var settings = AppSettings.shared
    @State private var dotPhase = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    @State private var pulseScale: CGFloat = 1.0

    public var body: some View {
        HStack(spacing: 6) {
            Circle().fill(roleColor ?? workerColor).frame(width: 8, height: 8)
                .scaleEffect(pulseScale)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                .onAppear { pulseScale = 1.2 }
            if let badge = roleBadge {
                Text(badge)
                    .font(Theme.chrome(8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(roleColor ?? workerColor))
            }
            Text(workerName).font(Theme.chrome(10, weight: .semibold)).foregroundColor(roleColor ?? workerColor)
            Text(statusText).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
            if let detail = activityDetail, !detail.isEmpty {
                Text("·").font(Theme.chrome(10)).foregroundColor(Theme.textDim)
                Text(detail)
                    .font(Theme.chrome(10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if elapsedSeconds > 0 {
                Text("\(elapsedSeconds)s")
                    .font(Theme.chrome(9, weight: .medium))
                    .foregroundColor(Theme.textDim)
                    .monospacedDigit()
            }
            // 웨이브 도트 애니메이션
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.textDim)
                        .frame(width: 3, height: 3)
                        .offset(y: i == dotPhase ? -2 : 0)
                        .animation(.easeInOut(duration: 0.25).delay(Double(i) * 0.08), value: dotPhase)
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in dotPhase = (dotPhase + 1) % 3 }
    }

    private var statusText: String {
        switch activity {
        case .thinking: return NSLocalizedString("terminal.status.thinking", comment: "")
        case .reading: return NSLocalizedString("terminal.status.reading", comment: "")
        case .writing: return NSLocalizedString("terminal.status.writing", comment: "")
        case .searching: return NSLocalizedString("terminal.status.searching", comment: "")
        case .running: return NSLocalizedString("terminal.status.running", comment: "")
        default: return NSLocalizedString("misc.processing", comment: "")
        }
    }
}
