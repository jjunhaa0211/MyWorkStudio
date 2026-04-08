import SwiftUI
import DesignSystem

// MARK: - Markdown Text View
// ═══════════════════════════════════════════════════════

public struct MarkdownTextView: View {
    public let text: String
    public let compact: Bool

    public init(text: String, compact: Bool = false) {
        self.text = text
        self.compact = compact
    }

    // Pre-compiled regex patterns (avoid recompilation on every inlineMarkdown call)
    private static let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`")

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, mdBlock in
                switch mdBlock {
                case .heading(let level, let content):
                    Text(content)
                        .font(Theme.mono(headingSize(level), weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, level <= 2 ? 6 : 3)
                case .codeBlock(let code):
                    codeBlockView(code: code)
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
        }
    }

    // MARK: - Code Block with Copy Button

    private func codeBlockView(code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: Theme.iconSize(8)))
                        Text("Copy")
                            .font(Theme.mono(8, weight: .medium))
                    }
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.top, 4).padding(.trailing, 4)

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
        var result = Text("")
        let nsText = text as NSString
        var pos = 0

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
                result = result + Text(rest).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textSecondary)
                break
            }

            // Emit text before the match
            if m.range.location > pos {
                let before = nsText.substring(with: NSRange(location: pos, length: m.range.location - pos))
                result = result + Text(before).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textSecondary)
            }

            // Emit the matched content (capture group 1)
            let inner = nsText.substring(with: m.range(at: 1))
            if isBold {
                result = result + Text(inner).font(Theme.mono(compact ? 11 : 12, weight: .bold)).foregroundColor(Theme.textPrimary)
            } else {
                result = result + Text(inner).font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.cyan)
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
        case codeBlock(String)
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
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(code.joined(separator: "\n")))
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
