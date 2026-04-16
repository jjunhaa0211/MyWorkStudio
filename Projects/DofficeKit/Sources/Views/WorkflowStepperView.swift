import SwiftUI
import DesignSystem

// MARK: - Workflow Stepper
// ═══════════════════════════════════════════════════════

public struct WorkflowStepperView: View {
    public let stages: [WorkflowStageRecord]

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                if index > 0 {
                    Rectangle()
                        .fill(stage.state == .queued ? Theme.textDim.opacity(0.3) : stage.state.tint.opacity(0.6))
                        .frame(width: 12, height: 1.5)
                }
                HStack(spacing: 3) {
                    stateIcon(stage.state)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(stage.state.tint)
                    Text(stage.role.shortLabel)
                        .font(Theme.chrome(8, weight: stage.state == .running ? .bold : .medium))
                        .foregroundColor(stage.state == .running ? stage.state.tint : Theme.textSecondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stage.state == .running ? stage.state.tint.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(stage.state.tint.opacity(stage.state == .queued ? 0.2 : 0.5), lineWidth: 0.5)
                        )
                )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func stateIcon(_ state: WorkflowStageState) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark")
        case .running:
            Image(systemName: "circle.fill")
        case .failed:
            Image(systemName: "xmark")
        case .skipped:
            Image(systemName: "minus")
        case .queued:
            Image(systemName: "circle")
        }
    }
}
