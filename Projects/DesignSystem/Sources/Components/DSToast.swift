import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - DSToast (Notification Toast System)
// ═══════════════════════════════════════════════════════

public enum DSToastStyle {
    case success, error, warning, info

    public var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .success: return Theme.green
        case .error: return Theme.red
        case .warning: return Theme.yellow
        case .info: return Theme.accent
        }
    }
}

public struct DSToastView: View {
    public let message: String
    public let style: DSToastStyle
    public var detail: String? = nil

    public init(message: String, style: DSToastStyle = .info, detail: String? = nil) {
        self.message = message
        self.style = style
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: Theme.sp3) {
            Image(systemName: style.icon)
                .font(.system(size: Theme.iconSize(12), weight: .medium))
                .foregroundColor(style.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.sp4)
        .padding(.vertical, Theme.sp3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .fill(Theme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(style.tint.opacity(0.3), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .frame(maxWidth: 360)
        .accessibilityElement(children: .combine)
    }
}

/// Toast modifier — attach to any view, control with binding
public struct DSToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let style: DSToastStyle
    let duration: Double

    public func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                DSToastView(message: message, style: style)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.easeOut(duration: 0.2)) { isPresented = false }
                        }
                    }
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
    }
}

public extension View {
    func dsToast(isPresented: Binding<Bool>, message: String, style: DSToastStyle = .info, duration: Double = 3.0) -> some View {
        modifier(DSToastModifier(isPresented: isPresented, message: message, style: style, duration: duration))
    }
}
