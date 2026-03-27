import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSAvatar
// ═══════════════════════════════════════════════════════

public struct DSAvatar: View {
    public enum Content {
        case initials(String)
        case icon(String)
        case image(Image)
    }

    public enum Size: CGFloat {
        case xs = 20, sm = 28, md = 36, lg = 48, xl = 64
    }

    public let content: Content
    public let size: Size
    public var tint: Color
    public var statusColor: Color? = nil

    public init(_ content: Content, size: Size = .md, tint: Color = Theme.accent, status: Color? = nil) {
        self.content = content
        self.size = size
        self.tint = tint
        self.statusColor = status
    }

    /// Convenience: initials from name
    public init(name: String, size: Size = .md, tint: Color = Theme.accent, status: Color? = nil) {
        let initials = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        self.content = .initials(initials.isEmpty ? "?" : initials)
        self.size = size
        self.tint = tint
        self.statusColor = status
    }

    private var dim: CGFloat { size.rawValue }
    private var fontSize: CGFloat {
        switch size {
        case .xs: return 8
        case .sm: return 10
        case .md: return 13
        case .lg: return 18
        case .xl: return 24
        }
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.15))

            Circle()
                .stroke(tint.opacity(0.25), lineWidth: 1)
                .allowsHitTesting(false)

            switch content {
            case .initials(let text):
                Text(text.uppercased())
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
            case .icon(let systemName):
                Image(systemName: systemName)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(tint)
            case .image(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            }
        }
        .frame(width: dim, height: dim)
        .overlay(alignment: .bottomTrailing) {
            if let statusColor {
                Circle()
                    .fill(statusColor)
                    .frame(width: dim * 0.3, height: dim * 0.3)
                    .overlay(Circle().stroke(Theme.bgCard, lineWidth: 1.5).allowsHitTesting(false))
                    .offset(x: 1, y: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        switch content {
        case .initials(let t): return t
        case .icon(let n): return n
        case .image: return "Avatar"
        }
    }
}

/// Avatar stack for showing multiple users
public struct DSAvatarStack: View {
    public let avatars: [(String, Color)]  // (name, tint)
    public var size: DSAvatar.Size = .sm
    public var maxVisible: Int = 4

    public init(_ avatars: [(String, Color)], size: DSAvatar.Size = .sm, maxVisible: Int = 4) {
        self.avatars = avatars
        self.size = size
        self.maxVisible = maxVisible
    }

    public var body: some View {
        HStack(spacing: -(size.rawValue * 0.3)) {
            ForEach(Array(avatars.prefix(maxVisible).enumerated()), id: \.offset) { i, item in
                DSAvatar(name: item.0, size: size, tint: item.1)
                    .zIndex(Double(maxVisible - i))
            }
            if avatars.count > maxVisible {
                DSAvatar(.initials("+\(avatars.count - maxVisible)"), size: size, tint: Theme.textDim)
            }
        }
    }
}
