import SwiftUI
import Combine
import DesignSystem

// MARK: - Processing Indicator
// ═══════════════════════════════════════════════════════

public struct ProcessingIndicator: View {
    public let activity: ClaudeActivity
    public let workerColor: Color
    public let workerName: String
    @StateObject private var settings = AppSettings.shared
    @State private var dotPhase = 0
    public let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    public var body: some View {
        HStack(spacing: 6) {
            Circle().fill(workerColor).frame(width: 8, height: 8)
            Text(workerName).font(Theme.chrome(10, weight: .semibold)).foregroundColor(workerColor)
            Text(statusText).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.textDim)
                        .frame(width: 3, height: 3)
                        .opacity(i <= dotPhase ? 0.8 : 0.2)
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
