import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Custom Theme Config (JSON 직렬화 모델)
// ═══════════════════════════════════════════════════════

public struct CustomThemeConfig: Codable, Equatable {
    public var accentHex: String?          // nil = 기본 accent 사용
    public var useGradient: Bool = false
    public var gradientStartHex: String?
    public var gradientEndHex: String?
    public var fontName: String?           // nil = 시스템 폰트
    public var fontSize: Double?           // nil = 기존 scale 시스템 사용

    // Background colors
    public var bgHex: String?
    public var bgCardHex: String?
    public var bgSurfaceHex: String?
    public var bgTertiaryHex: String?

    // Text colors
    public var textPrimaryHex: String?
    public var textSecondaryHex: String?
    public var textDimHex: String?
    public var textMutedHex: String?

    // Border colors
    public var borderHex: String?
    public var borderStrongHex: String?

    // Semantic colors
    public var greenHex: String?
    public var redHex: String?
    public var yellowHex: String?
    public var purpleHex: String?
    public var orangeHex: String?
    public var cyanHex: String?
    public var pinkHex: String?

    public static let `default` = CustomThemeConfig()

    public init(
        accentHex: String? = nil,
        useGradient: Bool = false,
        gradientStartHex: String? = nil,
        gradientEndHex: String? = nil,
        fontName: String? = nil,
        fontSize: Double? = nil,
        bgHex: String? = nil,
        bgCardHex: String? = nil,
        bgSurfaceHex: String? = nil,
        bgTertiaryHex: String? = nil,
        textPrimaryHex: String? = nil,
        textSecondaryHex: String? = nil,
        textDimHex: String? = nil,
        textMutedHex: String? = nil,
        borderHex: String? = nil,
        borderStrongHex: String? = nil,
        greenHex: String? = nil,
        redHex: String? = nil,
        yellowHex: String? = nil,
        purpleHex: String? = nil,
        orangeHex: String? = nil,
        cyanHex: String? = nil,
        pinkHex: String? = nil
    ) {
        self.accentHex = accentHex
        self.useGradient = useGradient
        self.gradientStartHex = gradientStartHex
        self.gradientEndHex = gradientEndHex
        self.fontName = fontName
        self.fontSize = fontSize
        self.bgHex = bgHex
        self.bgCardHex = bgCardHex
        self.bgSurfaceHex = bgSurfaceHex
        self.bgTertiaryHex = bgTertiaryHex
        self.textPrimaryHex = textPrimaryHex
        self.textSecondaryHex = textSecondaryHex
        self.textDimHex = textDimHex
        self.textMutedHex = textMutedHex
        self.borderHex = borderHex
        self.borderStrongHex = borderStrongHex
        self.greenHex = greenHex
        self.redHex = redHex
        self.yellowHex = yellowHex
        self.purpleHex = purpleHex
        self.orangeHex = orangeHex
        self.cyanHex = cyanHex
        self.pinkHex = pinkHex
    }
}
