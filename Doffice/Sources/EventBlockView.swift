import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Event Block View
// ═══════════════════════════════════════════════════════

public struct EventBlockView: View {
    var block: StreamBlock
    @StateObject private var settings = AppSettings.shared
    public let compact: Bool
    @State private var thoughtCollapsed = true
    @State private var showCopied = false

    public var body: some View {
        switch block.blockType {
        case .sessionStart:
            sessionStartBlock
        case .userPrompt:
            userPromptBlock
        case .thought:
            thoughtBlock
        case .toolUse(let name, _):
            toolUseBlock(name: name)
        case .toolOutput:
            toolOutputBlock
        case .toolError:
            toolErrorBlock
        case .toolEnd(let success):
            toolEndBlock(success: success)
        case .fileChange(_, let action):
            fileChangeBlock(action: action)
        case .status(let msg):
            statusBlock(msg)
        case .completion(let cost, let duration):
            completionBlock(cost: cost, duration: duration)
        case .error(let msg):
            errorBlock(msg)
        case .text:
            textBlock
        }
    }

    // ── Helpers ──

    private var fs: CGFloat { compact ? 11 : 12 }
    private var fsSm: CGFloat { compact ? 9 : 10 }

    // MARK: - Session Start

    private var sessionStartBlock: some View {
        Text(block.content)
            .font(Theme.mono(fsSm))
            .foregroundColor(Theme.textDim)
            .padding(.vertical, 4).padding(.horizontal, 12)
            .background(Capsule(style: .continuous).fill(Theme.bgSurface))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }

    // MARK: - User Prompt

    private var userPromptBlock: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: compact ? 40 : 72)
            Text(block.content)
                .font(Theme.mono(compact ? 11 : 13))
                .foregroundStyle(.white)
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent.opacity(0.78)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Theme.accent.opacity(0.18), radius: 6, x: 0, y: 3)
                )
        }
        .padding(.top, 10).padding(.bottom, 2)
    }

    // MARK: - AI Thought

    private var thoughtBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [Theme.purple.opacity(0.6), Theme.accent.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { thoughtCollapsed.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "brain")
                            .font(.system(size: Theme.iconSize(9)))
                            .foregroundColor(Theme.purple)
                        Text(NSLocalizedString("block.thinking", value: "Thinking", comment: ""))
                            .font(Theme.mono(compact ? 9 : 10, weight: .bold))
                            .foregroundColor(Theme.purple)
                        Image(systemName: thoughtCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: Theme.iconSize(7), weight: .bold))
                            .foregroundColor(Theme.textDim)
                        Spacer()
                        if thoughtCollapsed {
                            Text("\(block.content.components(separatedBy: "\n").count) lines")
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                if !thoughtCollapsed {
                    MarkdownTextView(text: block.content, compact: compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bgSurface.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.border.opacity(0.3), lineWidth: 0.5)
                )
        )
        .padding(.trailing, compact ? 40 : 72)
        .padding(.vertical, 2)
    }

    // MARK: - Tool Use

    private func toolUseBlock(name: String) -> some View {
        let color = toolColor(name)
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2.5)
                .padding(.vertical, 4)

            HStack(spacing: 5) {
                Image(systemName: toolIcon(name))
                    .font(.system(size: Theme.iconSize(8), weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 14)
                Text(name)
                    .font(Theme.mono(fsSm, weight: .bold))
                    .foregroundColor(color)
                Text(block.content)
                    .font(Theme.mono(fsSm))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                if !block.isComplete {
                    ProgressView().scaleEffect(0.35).frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.04))
        )
        .padding(.leading, 6)
    }

    // MARK: - Tool Output

    private var toolOutputBlock: some View {
        ToolOutputBlockView(block: block, compact: compact)
            .padding(.leading, 6)
    }

    // MARK: - Tool Error

    private var toolErrorBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.red)
                .frame(width: 2.5)
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Theme.iconSize(9)))
                    .foregroundColor(Theme.red.opacity(0.8))
                    .padding(.top, 1)
                Text(block.content)
                    .font(Theme.mono(fsSm))
                    .foregroundColor(Theme.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.red.opacity(0.04))
        )
        .padding(.leading, 6)
    }

    // MARK: - Tool End

    private func toolEndBlock(success: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: success ? "checkmark" : "xmark")
                .font(.system(size: Theme.iconSize(7), weight: .bold))
                .foregroundColor(success ? Theme.green.opacity(0.7) : Theme.red.opacity(0.7))
        }
        .padding(.leading, 14).padding(.vertical, 1)
    }

    // MARK: - File Change

    private func fileChangeBlock(action: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.green)
                .frame(width: 2.5)
                .padding(.vertical, 4)

            HStack(spacing: 6) {
                Image(systemName: action == "Write" ? "doc.badge.plus" : "pencil.line")
                    .font(.system(size: Theme.iconSize(9), weight: .medium))
                    .foregroundColor(Theme.green)
                Text(action)
                    .font(Theme.mono(fsSm, weight: .semibold))
                    .foregroundColor(Theme.green)
                Text(block.content)
                    .font(Theme.mono(fsSm))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.vertical, 3).padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.green.opacity(0.04))
        )
        .padding(.leading, 6)
    }

    // MARK: - Status

    private func statusBlock(_ msg: String) -> some View {
        Text(msg)
            .font(Theme.mono(8))
            .foregroundColor(Theme.textMuted)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    // MARK: - Completion

    private func completionBlock(cost: Double?, duration: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: Theme.iconSize(14)))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.green, Theme.green.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Text(NSLocalizedString("terminal.complete", comment: ""))
                    .font(Theme.mono(compact ? 10 : 12, weight: .bold))
                    .foregroundColor(Theme.green)
                Spacer()
                HStack(spacing: 10) {
                    if let d = duration {
                        Label("\(d/1000).\(d%1000/100)s", systemImage: "clock")
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                    if let c = cost, c > 0 {
                        Text(String(format: "$%.4f", c))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.yellow)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Theme.yellow.opacity(0.12))
                            )
                    }
                }
            }

            if !block.content.isEmpty && block.content != NSLocalizedString("slash.status.completed", comment: "") {
                MarkdownTextView(text: block.content, compact: compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.green.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Theme.green.opacity(0.3), Theme.green.opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.top, 6)
    }

    // MARK: - Error

    private func errorBlock(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Theme.iconSize(12)))
                .foregroundColor(Theme.red)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(msg).font(Theme.mono(fs, weight: .medium)).foregroundColor(Theme.red)
                if !block.content.isEmpty {
                    Text(block.content)
                        .font(Theme.mono(fsSm))
                        .foregroundColor(Theme.red.opacity(0.65))
                        .lineSpacing(2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.red.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.red.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownTextView(text: block.content, compact: compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .overlay(alignment: .topTrailing) {
            if block.content.count > 20 {
                copyButton(text: block.content)
            }
        }
    }

    // MARK: - Copy Button Helper

    private func copyButton(text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showCopied = false }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: Theme.iconSize(8)))
            }
            .foregroundColor(showCopied ? Theme.green : Theme.textDim)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.bgCard.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lookup

    private func toolIcon(_ name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil.line"
        case "Grep": return "magnifyingglass"
        case "Glob": return "folder"
        case "Agent": return "person.2"
        case "WebSearch": return "globe"
        case "WebFetch": return "arrow.down.circle"
        default: return "wrench.and.screwdriver"
        }
    }

    private func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow
        case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green
        case "Grep", "Glob": return Theme.cyan
        case "Agent": return Theme.purple
        case "WebSearch", "WebFetch": return Theme.orange
        default: return Theme.textSecondary
        }
    }
}
