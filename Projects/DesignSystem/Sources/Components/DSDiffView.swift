import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSDiffView (Code Diff Viewer)
// ═══════════════════════════════════════════════════════

public struct DSDiffLine: Identifiable {
    public let id: Int
    public let type: LineType
    public let content: String
    public let lineNumber: Int?

    public enum LineType {
        case added, removed, context, header

        public var bgColor: Color {
            switch self {
            case .added: return Theme.green.opacity(0.08)
            case .removed: return Theme.red.opacity(0.08)
            case .context: return .clear
            case .header: return Theme.bgSurface
            }
        }

        public var textColor: Color {
            switch self {
            case .added: return Theme.green
            case .removed: return Theme.red
            case .context: return Theme.textPrimary
            case .header: return Theme.textDim
            }
        }

        public var prefix: String {
            switch self {
            case .added: return "+"
            case .removed: return "-"
            case .context: return " "
            case .header: return ""
            }
        }
    }

    public init(id: Int, type: LineType, content: String, lineNumber: Int? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.lineNumber = lineNumber
    }
}

public struct DSDiffView: View {
    public let lines: [DSDiffLine]
    public let fileName: String?
    public var maxHeight: CGFloat? = 400

    public init(_ lines: [DSDiffLine], fileName: String? = nil, maxHeight: CGFloat? = 400) {
        self.lines = lines
        self.fileName = fileName
        self.maxHeight = maxHeight
    }

    /// Parse a unified diff string into DSDiffLines
    public static func parse(_ diff: String) -> [DSDiffLine] {
        var result: [DSDiffLine] = []
        for (i, line) in diff.components(separatedBy: "\n").enumerated() {
            let type: DSDiffLine.LineType
            if line.hasPrefix("@@") { type = .header }
            else if line.hasPrefix("+") { type = .added }
            else if line.hasPrefix("-") { type = .removed }
            else { type = .context }
            let content = (type == .context || type == .added || type == .removed) ? String(line.dropFirst()) : line
            result.append(DSDiffLine(id: i, type: type, content: content, lineNumber: i + 1))
        }
        return result
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let fileName {
                HStack(spacing: Theme.sp2) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textDim)
                    Text(fileName)
                        .font(Theme.code(9, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(addedCount) additions, \(removedCount) deletions")
                        .font(Theme.code(8))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, Theme.sp3)
                .padding(.vertical, 6)
                .background(Theme.bgSurface)
            }

            ScrollView([.vertical, .horizontal]) {
                VStack(spacing: 0) {
                    ForEach(lines) { line in
                        HStack(spacing: 0) {
                            // Line number
                            Text(line.lineNumber.map { "\($0)" } ?? "")
                                .font(Theme.code(9))
                                .foregroundColor(Theme.textMuted)
                                .frame(width: 36, alignment: .trailing)
                                .padding(.trailing, Theme.sp2)

                            // Prefix
                            Text(line.type.prefix)
                                .font(Theme.code(10, weight: .bold))
                                .foregroundColor(line.type.textColor)
                                .frame(width: 14)

                            // Content
                            Text(line.content.isEmpty ? " " : line.content)
                                .font(Theme.code(10))
                                .foregroundColor(line.type.textColor)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 1)
                        .background(line.type.bgColor)
                    }
                }
                .padding(.vertical, Theme.sp1)
            }
            .frame(maxHeight: maxHeight)
        }
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgTertiary.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Diff view\(fileName.map { " for \($0)" } ?? "") with \(addedCount) additions and \(removedCount) deletions"))
    }

    private var addedCount: Int { lines.filter { $0.type == .added }.count }
    private var removedCount: Int { lines.filter { $0.type == .removed }.count }
}
