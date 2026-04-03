import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 도피스 컴포넌트 시스템
//
// 원칙:
// - 밀도 높은 개발 툴 UI에 맞게 표면은 단단하게, 강조는 선명하게
// - 보더와 하이라이트, 아주 얕은 그림자를 함께 써서 입체감을 만든다
// - prominent 버튼은 강하게, 나머지는 유리처럼 얇은 레이어 느낌으로 처리한다
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
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(fill)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Theme.panelBackground)
                        .opacity(0.84)
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Theme.topHighlight.opacity(0.5), lineWidth: 1)
                        .blur(radius: 0.2)
                        .mask(
                            LinearGradient(colors: [.white, .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        )
                }
            )
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border.opacity(max(strokeOpacity, 0.55)), lineWidth: 1).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: Theme.panelShadow.opacity(shadow ? 1 : 0.72), radius: shadow ? 18 : 12, x: 0, y: shadow ? 12 : 6)
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
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(emphasized ? Theme.borderActive : Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.topHighlight.opacity(0.45), lineWidth: 1)
                    .blur(radius: 0.4)
                    .mask(
                        LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                    )
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: emphasized ? Theme.ambientAccent.opacity(0.5) : Theme.panelShadow.opacity(0.18), radius: emphasized ? 14 : 8, x: 0, y: emphasized ? 8 : 4)
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
        let borderColor = prominent ? tint.opacity(0.3) : (tone == .neutral ? Theme.border : Theme.accentBorder(tint))
        let base = content
            .padding(.horizontal, compact ? Theme.sp2 + 1 : Theme.sp4)
            .padding(.vertical, compact ? Theme.sp2 - 1 : Theme.sp2 + 1)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: r).fill(bgFill)
                    RoundedRectangle(cornerRadius: r)
                        .stroke(Theme.topHighlight.opacity(prominent ? 0.45 : 0.25), lineWidth: 1)
                        .blur(radius: 0.3)
                        .mask(
                            LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )
                }
            )
            .overlay(RoundedRectangle(cornerRadius: r).stroke(borderColor, lineWidth: 1).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: r))
            .shadow(color: prominent ? Theme.liftShadow.opacity(0.75) : Theme.panelShadow.opacity(0.12), radius: prominent ? 16 : 8, x: 0, y: prominent ? 8 : 4)

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
                    .fill(isSelected ? Theme.accentSoftBackground : AnyShapeStyle(isHovered ? Theme.bgHover : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(isSelected ? Theme.accentBorder(Theme.accent) : .clear, lineWidth: 1)
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
