import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 도피스 컴포넌트 시스템 (Vercel-grade)
//
// 원칙:
// - 그림자 없음. depth = surface color + border
// - 보더는 항상 1px, Theme.border 사용
// - 배경은 surface 계층으로만 표현
// - prominent 버튼만 채색, 나머지는 border-only
// - hover/selected/pressed는 bgHover/bgSelected/bgPressed 사용
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: - Panel Modifier (카드, 섹션, 패널)

private struct AppPanelModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat
    let fill: Color
    let strokeOpacity: Double  // kept for API compat, border uses Theme.border
    let shadow: Bool           // ignored — no shadows in this system

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Field Modifier (텍스트 입력, 셀렉트)

private struct AppFieldModifier: ViewModifier {
    let emphasized: Bool
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp2)
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.bgInput))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(emphasized ? Theme.accent : Theme.border, lineWidth: 1).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Button Surface Modifier

private struct AppButtonSurfaceModifier: ViewModifier {
    let tone: AppChromeTone
    let prominent: Bool
    let compact: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let tint = tone.color
        let r: CGFloat = Theme.cornerMedium
        let bgFill: AnyShapeStyle = {
            if prominent {
                return tone == .accent ? Theme.accentBackground : AnyShapeStyle(tint)
            }
            return tone == .neutral ? AnyShapeStyle(Color.clear) :
                   (tone == .accent ? Theme.accentSoftBackground : AnyShapeStyle(Theme.accentBg(tint)))
        }()
        let base = content
            .padding(.horizontal, compact ? Theme.sp2 : Theme.sp3)
            .padding(.vertical, compact ? Theme.sp1 + 1 : Theme.sp2 - 1)
            .background(RoundedRectangle(cornerRadius: r).fill(bgFill))
            .overlay(RoundedRectangle(cornerRadius: r).stroke(prominent ? tint.opacity(0.2) : Theme.border, lineWidth: 1).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: r))

        // 구체 타입으로 foreground 적용 — AnyShapeStyle 타입 소거는 macOS 버튼에서 전파 안 됨
        let ct = AppSettings.shared.customTheme
        if !prominent, tone == .accent, Theme.isCustomMode, ct.useGradient,
           let s = ct.gradientStartHex, !s.isEmpty,
           let e = ct.gradientEndHex, !e.isEmpty {
            base.foregroundStyle(
                LinearGradient(colors: [Color(hex: s), Color(hex: e)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        } else if prominent {
            base.foregroundColor(Theme.textOnAccent)
        } else if tone == .neutral {
            base.foregroundColor(Theme.textSecondary)
        } else if tone == .accent {
            base.foregroundColor(Theme.accent)
        } else {
            base.foregroundColor(tint)
        }
    }
}

// MARK: - View Extensions

public extension View {
    func appPanelStyle(
        padding: CGFloat = Theme.panelPadding,
        radius: CGFloat = Theme.cornerLarge,
        fill: Color = Theme.bgCard,
        strokeOpacity: Double = Theme.borderDefault,
        shadow: Bool = false
    ) -> some View {
        modifier(AppPanelModifier(padding: padding, radius: radius, fill: fill, strokeOpacity: strokeOpacity, shadow: shadow))
    }

    func appFieldStyle(emphasized: Bool = false, radius: CGFloat = CGFloat(Theme.cornerMedium)) -> some View {
        modifier(AppFieldModifier(emphasized: emphasized, radius: radius))
    }

    func appButtonSurface(
        tone: AppChromeTone = .neutral,
        prominent: Bool = false,
        compact: Bool = false
    ) -> some View {
        modifier(AppButtonSurfaceModifier(tone: tone, prominent: prominent, compact: compact))
    }

    /// Vercel-style divider (subtle horizontal line)
    func appDivider() -> some View {
        self.overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Sidebar hover highlight
    func sidebarRowStyle(isSelected: Bool = false, isHovered: Bool = false) -> some View {
        self
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, Theme.sp1 + 1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isSelected ? Theme.bgSelected : (isHovered ? Theme.bgHover : .clear))
            )
    }

    /// Interactive surface with hover highlight
    func interactiveSurface(
        isSelected: Bool = false,
        radius: CGFloat = Theme.cornerMedium
    ) -> some View {
        self
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(isSelected ? Theme.bgSelected : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(isSelected ? Theme.border : .clear, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}
