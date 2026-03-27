import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSCodeBlock (Code Display with Copy)
// ═══════════════════════════════════════════════════════

public struct DSCodeBlock: View {
    public let code: String
    public var language: String? = nil
    public var showLineNumbers: Bool = false
    public var maxHeight: CGFloat? = nil

    @State private var copied = false

    public init(_ code: String, language: String? = nil, showLineNumbers: Bool = false, maxHeight: CGFloat? = nil) {
        self.code = code
        self.language = language
        self.showLineNumbers = showLineNumbers
        self.maxHeight = maxHeight
    }

    private var lines: [String] { code.components(separatedBy: "\n") }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            if language != nil || true {
                HStack(spacing: Theme.sp2) {
                    if let language {
                        Text(language)
                            .font(Theme.code(8, weight: .bold))
                            .foregroundColor(Theme.textDim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
                    }
                    Spacer()
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9, weight: .medium))
                            Text(copied ? "Copied" : "Copy")
                                .font(Theme.code(8, weight: .medium))
                        }
                        .foregroundColor(copied ? Theme.green : Theme.textDim)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, 6)
                .background(Theme.bgSurface)
            }

            // Code content
            ScrollView(maxHeight != nil ? [.vertical, .horizontal] : [.horizontal]) {
                HStack(alignment: .top, spacing: 0) {
                    if showLineNumbers {
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { i, _ in
                                Text("\(i + 1)")
                                    .font(Theme.code(10))
                                    .foregroundColor(Theme.textMuted)
                                    .frame(minWidth: 28, alignment: .trailing)
                                    .padding(.vertical, 1)
                            }
                        }
                        .padding(.trailing, Theme.sp2)
                        .padding(.leading, Theme.sp3)

                        Rectangle()
                            .fill(Theme.border)
                            .frame(width: 1)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(Theme.code(10))
                                .foregroundColor(Theme.textPrimary)
                                .padding(.vertical, 1)
                        }
                    }
                    .padding(.horizontal, Theme.sp3)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.sp2)
            }
            .frame(maxHeight: maxHeight)
        }
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgTertiary.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
        .textSelection(.enabled)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.15)) { copied = false }
        }
    }
}
