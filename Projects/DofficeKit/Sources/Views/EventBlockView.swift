import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Event Block View
// ═══════════════════════════════════════════════════════

public struct EventBlockView: View {
    var block: StreamBlock
    @StateObject private var settings = AppSettings.shared
    public let compact: Bool
    public var onResendPrompt: ((String) -> Void)?
    public var onQuickAction: ((String) -> Void)?
    public var onRevert: (() -> Void)?
    public var onRetry: (() -> Void)?
    public var hasFileChanges: Bool = false
    @State private var thoughtCollapsed = false
    @State private var showCopied = false
    @State private var showRevertConfirm = false

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

    private var isSecret: Bool { block.presentationStyle == .secret }

    private var userPromptBlock: some View {
        let secretColors: [Color] = [Theme.purple, Theme.purple.opacity(0.7)]
        let normalColors: [Color] = [Theme.accent, Theme.accent.opacity(0.78)]
        let bgColors = isSecret ? secretColors : normalColors
        let shadowColor = isSecret ? Theme.purple.opacity(0.25) : Theme.accent.opacity(0.18)

        return VStack(alignment: .trailing, spacing: 4) {
            HStack(alignment: .bottom, spacing: 0) {
                Spacer(minLength: compact ? 40 : 72)
                HStack(spacing: 6) {
                    if isSecret {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: Theme.iconSize(compact ? 9 : 10)))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(block.content)
                        .font(Theme.mono(compact ? 11 : 13))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: bgColors,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: shadowColor, radius: 6, x: 0, y: 3)
                )
                .overlay(
                    isSecret
                        ? RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.purple.opacity(0.4), lineWidth: 1)
                        : nil
                )
            }

            HStack(spacing: 8) {
                Text(block.timestamp, style: .time)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textMuted)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(block.content, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: Theme.iconSize(7)))
                        .foregroundColor(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Copy")

                if let onResend = onResendPrompt {
                    Button {
                        onResend(block.content)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: Theme.iconSize(7)))
                            .foregroundColor(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("block.resend", value: "Edit & Resend", comment: ""))
                }
            }
        }
        .padding(.top, 10).padding(.bottom, 2)
    }

    // MARK: - AI Thought

    private var thoughtBlock: some View {
        let accentColor: Color = Theme.purple
        let barColors: [Color] = isSecret
            ? [Theme.purple.opacity(0.8), Theme.purple.opacity(0.4)]
            : [Theme.purple.opacity(0.6), Theme.accent.opacity(0.4)]
        let bgFill = isSecret ? Theme.purple.opacity(0.08) : Theme.bgSurface.opacity(0.45)
        let borderColor = isSecret ? Theme.purple.opacity(0.3) : Theme.border.opacity(0.3)
        let headerLabel = isSecret ? "BTW" : NSLocalizedString("block.thinking", value: "Thinking", comment: "")
        let headerIcon = isSecret ? "eye.slash.fill" : "brain"

        return HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: barColors,
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
                        Image(systemName: headerIcon)
                            .font(.system(size: Theme.iconSize(9)))
                            .foregroundColor(accentColor)
                        Text(headerLabel)
                            .font(Theme.mono(compact ? 9 : 10, weight: .bold))
                            .foregroundColor(accentColor)
                        Image(systemName: thoughtCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: Theme.iconSize(7), weight: .bold))
                            .foregroundColor(Theme.textDim)
                        Spacer()
                        if thoughtCollapsed {
                            Text("\(block.content.components(separatedBy: "\n").count) lines")
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textMuted)
                        }
                        Text(block.timestamp, style: .time)
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textMuted.opacity(0.6))
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
                .fill(bgFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSecret ? 1 : 0.5)
                )
        )
        .overlay(alignment: .topTrailing) {
            if !thoughtCollapsed && block.content.count > 20 {
                copyButton(text: block.content)
                    .padding(.top, 6).padding(.trailing, compact ? 44 : 76)
            }
        }
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
                Text(block.timestamp, style: .time)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textMuted)
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
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)

                // 경로 복사
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(block.content, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("block.copy.path", value: "Copy path", comment: ""))

                // Finder에서 열기
                Button {
                    let url = URL(fileURLWithPath: block.content)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("block.reveal.finder", value: "Reveal in Finder", comment: ""))
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

            // 빠른 후속 액션 버튼
            if let quickAction = onQuickAction {
                HStack(spacing: 6) {
                    quickActionButton(label: NSLocalizedString("block.action.continue", value: "이어서", comment: ""), icon: "arrow.right.circle", color: Theme.accent) {
                        quickAction("이어서 진행해줘")
                    }
                    quickActionButton(label: NSLocalizedString("block.action.explain", value: "설명", comment: ""), icon: "questionmark.circle", color: Theme.purple) {
                        quickAction("방금 한 작업을 설명해줘")
                    }
                    quickActionButton(label: NSLocalizedString("block.action.fix", value: "수정", comment: ""), icon: "wrench", color: Theme.orange) {
                        quickAction("에러가 있으면 수정해줘")
                    }
                    quickActionButton(label: NSLocalizedString("block.action.retry", value: "재시도", comment: ""), icon: "arrow.counterclockwise", color: Theme.red) {
                        quickAction("방금 요청을 다시 시도해줘")
                    }

                    if hasFileChanges, onRevert != nil {
                        quickActionButton(label: NSLocalizedString("block.action.revert", value: "되돌리기", comment: ""), icon: "arrow.uturn.backward", color: Theme.orange) {
                            showRevertConfirm = true
                        }
                    }
                }
                .padding(.top, 4)
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
        .alert(NSLocalizedString("history.revert.confirm.title", comment: ""), isPresented: $showRevertConfirm) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("history.revert.action", comment: ""), role: .destructive) {
                onRevert?()
            }
        } message: {
            Text(NSLocalizedString("history.revert.confirm.message", comment: ""))
        }
    }

    private func quickActionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(8)))
                Text(label)
                    .font(Theme.mono(8, weight: .bold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                if let onRetry = onRetry {
                    Button(action: { onRetry() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: Theme.iconSize(8)))
                            Text(NSLocalizedString("block.action.retry", value: "재시도", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                        }
                        .foregroundColor(Theme.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.red.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
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
            if isSecret {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(Theme.purple.opacity(0.6))
                    Text("BTW")
                        .font(Theme.mono(compact ? 8 : 9, weight: .bold))
                        .foregroundColor(Theme.purple.opacity(0.6))
                }
                .padding(.bottom, 4)
            }
            MarkdownTextView(text: block.content, compact: compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(isSecret ? 10 : 0)
        .background(
            isSecret
                ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.purple.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.purple.opacity(0.2), lineWidth: 0.5)
                    )
                : nil
        )
        .overlay(alignment: .bottomTrailing) {
            Text(block.timestamp, style: .time)
                .font(Theme.mono(7))
                .foregroundColor(Theme.textMuted.opacity(0.5))
                .padding(.trailing, 4).padding(.bottom, 2)
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
