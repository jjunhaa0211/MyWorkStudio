import SwiftUI
import DesignSystem

// MARK: - Markdown Text View
// ═══════════════════════════════════════════════════════

public struct MarkdownTextView: View {
    public let text: String
    public let compact: Bool

    public init(text: String, compact: Bool = false) {
        // 대용량 텍스트 보호: UI 프리징 방지
        if text.count > Self.maxBlockContentLength {
            self.text = String(text.prefix(Self.maxBlockContentLength)) + "\n\n… (truncated: \(text.count - Self.maxBlockContentLength) chars)"
        } else {
            self.text = text
        }
        self.compact = compact
    }

    // Pre-compiled regex patterns (avoid recompilation on every inlineMarkdown call)
    private static let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`")

    /// Maximum number of block-level elements rendered before truncation.
    private static let maxRenderedBlocks = 500
    /// 단일 블록 내 최대 문자 수 — 초과 시 잘라서 렌더링
    private static let maxBlockContentLength = 30_000

    public var body: some View {
        let parsed = parseBlocks()
        let truncated = parsed.count > Self.maxRenderedBlocks
        let blocks = truncated ? Array(parsed.prefix(Self.maxRenderedBlocks)) : parsed
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, mdBlock in
                switch mdBlock {
                case .heading(let level, let content):
                    Text(content)
                        .font(Theme.mono(headingSize(level), weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, level <= 2 ? 6 : 3)
                case .codeBlock(let code, let language):
                    codeBlockView(code: code, language: language)
                case .bullet(let content):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").font(Theme.mono(compact ? 10 : 11)).foregroundStyle(Theme.accentBackground)
                            .frame(width: 10)
                        inlineMarkdown(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .separator:
                    Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)
                case .table(let rows):
                    tableView(rows)
                case .paragraph(let content):
                    inlineMarkdown(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if truncated {
                Text("⋯ \(parsed.count - Self.maxRenderedBlocks) more blocks")
                    .font(Theme.mono(compact ? 10 : 11))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Code Block with Copy Button

    @State private var copiedBlockId: String?

    private func codeBlockView(code: String, language: String?) -> some View {
        let blockId = "\(code.hashValue)"
        let isCopied = copiedBlockId == blockId
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                if let lang = language, !lang.isEmpty {
                    Text(lang.uppercased())
                        .font(Theme.mono(7, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copiedBlockId = blockId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedBlockId == blockId { copiedBlockId = nil }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: Theme.iconSize(8)))
                        Text(isCopied ? "Copied!" : "Copy")
                            .font(Theme.mono(8, weight: .medium))
                    }
                    .foregroundColor(isCopied ? Theme.green : Theme.textDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.top, 2).padding(.trailing, 4)

            Text(code)
                .font(Theme.mono(compact ? 10 : 11))
                .foregroundColor(Theme.cyan)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bg))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Inline markdown (bold, code, italic)

    private func inlineMarkdown(_ text: String) -> Text {
        // Fast path: skip regex work when no markdown syntax is present
        if !text.contains("**") && !text.contains("`") {
            return Text(text)
                .font(Theme.mono(compact ? 11 : 12))
                .foregroundColor(Theme.textSecondary)
        }

        var result = Text("")
        let nsText = text as NSString
        var pos = 0

        // Cache font/color values used repeatedly in the loop
        let plainFont = Theme.mono(compact ? 11 : 12)
        let plainColor = Theme.textSecondary
        let boldFont = Theme.mono(compact ? 11 : 12, weight: .bold)
        let boldColor = Theme.textPrimary
        let codeFont = Theme.mono(compact ? 10 : 11)
        let codeColor = Theme.cyan

        while pos < nsText.length {
            let searchRange = NSRange(location: pos, length: nsText.length - pos)

            // Find earliest match of either pattern
            let boldMatch = Self.boldRegex?.firstMatch(in: text, range: searchRange)
            let codeMatch = Self.codeRegex?.firstMatch(in: text, range: searchRange)

            // Pick whichever comes first
            let match: NSTextCheckingResult?
            let isBold: Bool
            if let b = boldMatch, let c = codeMatch {
                if b.range.location <= c.range.location {
                    match = b; isBold = true
                } else {
                    match = c; isBold = false
                }
            } else if let b = boldMatch {
                match = b; isBold = true
            } else if let c = codeMatch {
                match = c; isBold = false
            } else {
                match = nil; isBold = false
            }

            guard let m = match else {
                // No more matches — emit rest as plain text
                let rest = nsText.substring(from: pos)
                result = result + Text(rest).font(plainFont).foregroundColor(plainColor)
                break
            }

            // Emit text before the match
            if m.range.location > pos {
                let before = nsText.substring(with: NSRange(location: pos, length: m.range.location - pos))
                result = result + Text(before).font(plainFont).foregroundColor(plainColor)
            }

            // Emit the matched content (capture group 1)
            let inner = nsText.substring(with: m.range(at: 1))
            if isBold {
                result = result + Text(inner).font(boldFont).foregroundColor(boldColor)
            } else {
                result = result + Text(inner).font(codeFont).foregroundColor(codeColor)
            }

            pos = m.range.location + m.range.length
        }
        return result
    }

    // MARK: - Table

    private func tableView(_ rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell.trimmingCharacters(in: .whitespaces))
                            .font(Theme.mono(compact ? 9 : 10, weight: rowIdx == 0 ? .bold : .regular))
                            .foregroundColor(rowIdx == 0 ? Theme.textPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                        if colIdx < row.count - 1 {
                            Rectangle().fill(Theme.border.opacity(0.3)).frame(width: 1)
                        }
                    }
                }
                if rowIdx == 0 {
                    Rectangle().fill(Theme.border).frame(height: 1)
                } else if rowIdx < rows.count - 1 {
                    Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Block Parser

    private enum MdBlock {
        case heading(Int, String)
        case codeBlock(String, String?) // code, language
        case bullet(String)
        case separator
        case table([[String]])
        case paragraph(String)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return compact ? 14 : 16
        case 2: return compact ? 13 : 14
        case 3: return compact ? 12 : 13
        default: return compact ? 11 : 12
        }
    }

    private func parseBlocks() -> [MdBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MdBlock] = []
        blocks.reserveCapacity(min(lines.count, Self.maxRenderedBlocks + 1))
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let language: String? = lang.isEmpty ? nil : lang
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(code.joined(separator: "\n"), language))
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("###") {
                blocks.append(.heading(3, String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix("##") {
                blocks.append(.heading(2, String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix("#") {
                blocks.append(.heading(1, String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }

            // Separator
            if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") {
                blocks.append(.separator)
                i += 1; continue
            }

            // Table (detect | at start)
            if trimmed.hasPrefix("|") && trimmed.contains("|") {
                var tableRows: [[String]] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    guard tl.hasPrefix("|") else { break }
                    // skip separator rows like |---|---|
                    if tl.contains("---") { i += 1; continue }
                    let cells = tl.components(separatedBy: "|").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    if !cells.isEmpty { tableRows.append(cells) }
                    i += 1
                }
                if !tableRows.isEmpty { blocks.append(.table(tableRows)) }
                continue
            }

            // Bullet
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                blocks.append(.bullet(content))
                i += 1; continue
            }

            // Empty line
            if trimmed.isEmpty {
                i += 1; continue
            }

            // Paragraph (collect consecutive non-empty lines)
            var para: [String] = [line]
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("```") || next.hasPrefix("|") || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("---") { break }
                para.append(lines[i])
                i += 1
            }
            blocks.append(.paragraph(para.joined(separator: "\n")))
        }
        return blocks
    }
}
